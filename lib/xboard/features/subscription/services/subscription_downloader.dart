import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fl_clash/clash/core.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/security/security.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/infrastructure/http/user_agent_config.dart';
import 'package:socks5_proxy/socks_client.dart';
import 'package:yaml/yaml.dart';

// 初始化文件级日志器
final _logger = FileLogger('subscription_downloader.dart');
const _masker = SensitiveLogMasker();

/// XBoard 订阅下载服务
///
/// 并发下载（直连 + 所有代理），第一个成功就获胜
class SubscriptionDownloader {
  static const Duration _downloadTimeout = Duration(seconds: 30);
  static const List<SubscriptionDownloadOptions> wyxV2BoardOptions = [
    SubscriptionDownloadOptions(userAgent: 'Clash.Meta'),
    SubscriptionDownloadOptions(userAgent: 'Mihomo'),
    SubscriptionDownloadOptions(userAgent: 'ClashforWindows/0.20.39'),
  ];

  /// 下载订阅并返回 Profile（并发竞速）
  ///
  /// [url] 订阅URL
  /// [enableRacing] 是否启用竞速（默认 true，false时只使用直连）
  static Future<Profile> downloadSubscription(
    String url, {
    bool enableRacing = true,
    bool persistUrl = true,
    String? label,
    List<SubscriptionDownloadOptions>? options,
  }) async {
    try {
      _logger.info(
        '开始下载订阅: ${_maskSensitiveText(url)}, persistUrl: $persistUrl',
      );

      final optionList =
          options ??
          [
            SubscriptionDownloadOptions(
              userAgent: await UserAgentConfig.get(
                UserAgentScenario.subscription,
              ),
            ),
          ];
      _DownloadResult? result;
      SubscriptionConfigNormalizeResult? normalized;
      Object? lastError;

      for (var index = 0; index < optionList.length; index++) {
        final option = optionList[index];
        try {
          _logger.info(
            '订阅下载尝试 ${index + 1}/${optionList.length}: '
            'ua=${option.safeUserAgentLabel}',
          );
          result = await _downloadWithOption(
            url,
            enableRacing: enableRacing,
            option: option,
          );
          normalized = normalizeSubscriptionConfig(result.content);
          _logContentSummary(result, normalized);
          for (final repairedGroup in normalized.repairedGroups) {
            _logger.warning('修复缺失 proxy-group 引用：$repairedGroup');
          }
          if (normalized.hasUsableNodeSource) {
            break;
          }
          lastError = Exception('订阅接口未返回 Clash/Mihomo 节点');
          _logger.warning(
            '订阅下载结果不包含可用节点，尝试下一个 User-Agent: '
            'ua=${option.safeUserAgentLabel}',
          );
        } catch (error) {
          lastError = error;
          _logger.warning(
            '订阅下载尝试失败: ua=${option.safeUserAgentLabel}, '
            'error=${_maskSensitiveText(error)}',
          );
        }
      }

      if (result == null || normalized == null) {
        throw lastError ?? Exception('订阅下载失败');
      }
      if (!normalized.hasUsableNodeSource) {
        final summary = SubscriptionContentSummary.from(result.content);
        if (summary.hasBase64LikeContent ||
            summary.protocolCounts.values.any((count) => count > 0)) {
          throw Exception('订阅接口未返回 Clash/Mihomo 格式，请检查 User-Agent 或订阅转换');
        }
        throw Exception('订阅接口未返回 Clash/Mihomo 节点');
      }

      final validationMessage = await clashCore.validateConfig(
        normalized.content,
      );
      if (validationMessage.isNotEmpty) {
        throw Exception('配置验证失败: $validationMessage');
      }
      _logger.info('✅ 订阅配置验证通过');

      // 创建并保存 Profile
      final profile = Profile.normal(label: label, url: persistUrl ? url : '');
      final savedProfile = await profile.saveFileWithString(normalized.content);

      // 更新订阅信息
      final finalProfile = savedProfile.copyWith(
        label: label ?? result.label ?? savedProfile.id,
        subscriptionInfo: result.subscriptionInfo,
        lastUpdateDate: DateTime.now(),
      );

      _logger.info('✅ 订阅下载成功: ${finalProfile.label}');
      return finalProfile;
    } on TimeoutException catch (e) {
      _logger.error('订阅下载超时', e);
      throw Exception('下载超时: ${e.message}');
    } on SocketException catch (e) {
      _logger.error('网络连接失败', e);
      throw Exception('网络连接失败: ${e.message}');
    } on HttpException catch (e) {
      _logger.error('HTTP请求失败', e);
      throw Exception('HTTP请求失败: ${e.message}');
    } catch (e) {
      _logger.error('订阅下载失败', _maskSensitiveText(e));
      rethrow;
    }
  }

  /// 等待第一个成功的任务（忽略失败的）
  static Future<_DownloadResult> _waitForFirstSuccess(
    List<Future<_DownloadResult>> tasks,
  ) async {
    final completer = Completer<_DownloadResult>();
    int failedCount = 0;
    final errors = <Object>[];

    for (final task in tasks) {
      task
          .then((result) {
            if (!completer.isCompleted) {
              completer.complete(result);
            }
          })
          .catchError((e) {
            failedCount++;
            errors.add(e);

            // 如果所有任务都失败了，抛出第一个错误
            if (failedCount == tasks.length && !completer.isCompleted) {
              _logger.error('所有下载任务都失败了', errors.first);
              completer.completeError(errors.first);
            }
          });
    }

    return completer.future;
  }

  static Future<_DownloadResult> _downloadWithOption(
    String url, {
    required bool enableRacing,
    required SubscriptionDownloadOptions option,
  }) async {
    if (!enableRacing) {
      _logger.info('竞速已禁用，使用直连下载');
      return await _downloadWithMethod(
        url,
        useProxy: false,
        cancelToken: _CancelToken(),
        taskIndex: 0,
        option: option,
      );
    }

    final proxies = XBoardConfig.allProxyUrls;
    _logger.info('开始并发下载 (${proxies.length + 1}种方式)');

    final cancelTokens = <_CancelToken>[];
    final tasks = <Future<_DownloadResult>>[];

    try {
      final directToken = _CancelToken();
      cancelTokens.add(directToken);
      tasks.add(
        _downloadWithMethod(
          url,
          useProxy: false,
          cancelToken: directToken,
          taskIndex: 0,
          option: option,
        ),
      );

      for (int i = 0; i < proxies.length; i++) {
        final proxyToken = _CancelToken();
        cancelTokens.add(proxyToken);
        tasks.add(
          _downloadWithMethod(
            url,
            useProxy: true,
            proxyUrl: proxies[i],
            cancelToken: proxyToken,
            taskIndex: i + 1,
            option: option,
          ),
        );
      }

      final result = await _waitForFirstSuccess(tasks);
      _logger.info('🏆 ${result.connectionType} 获胜！');
      for (final token in cancelTokens) {
        token.cancel();
      }
      return result;
    } catch (_) {
      for (final token in cancelTokens) {
        token.cancel();
      }
      rethrow;
    }
  }

  /// 使用指定方式下载完整订阅内容
  static Future<_DownloadResult> _downloadWithMethod(
    String url, {
    required bool useProxy,
    String? proxyUrl,
    required _CancelToken cancelToken,
    required int taskIndex,
    required SubscriptionDownloadOptions option,
  }) async {
    final connectionType = useProxy ? '代理($proxyUrl)' : '直连';
    _logger.info('[任务$taskIndex] 开始下载: $connectionType');

    try {
      final result = await _downloadWithProxy(
        url,
        useProxy: useProxy,
        proxyUrl: proxyUrl,
        cancelToken: cancelToken,
        option: option,
      );

      _logger.info(
        '[任务$taskIndex] 下载成功: $connectionType，大小: ${result.bytes.length} bytes',
      );

      return _DownloadResult(
        content: result.content,
        connectionType: connectionType,
        label: result.label,
        subscriptionInfo: result.subscriptionInfo,
        bytes: result.bytes,
        statusCode: result.statusCode,
        contentType: result.contentType,
        userAgentLabel: result.userAgentLabel,
      );
    } catch (e) {
      if (cancelToken.isCancelled) {
        _logger.info('[任务$taskIndex] 已取消: $connectionType');
      } else {
        _logger.warning(
          '[任务$taskIndex] 下载失败: $connectionType - '
          '${_maskSensitiveText(e)}',
        );
      }
      rethrow;
    }
  }

  /// 使用代理下载订阅内容
  static Future<_DownloadRawResult> _downloadWithProxy(
    String url, {
    required bool useProxy,
    String? proxyUrl,
    required _CancelToken cancelToken,
    required SubscriptionDownloadOptions option,
  }) async {
    HttpClient? client;

    try {
      // 检查是否已取消
      if (cancelToken.isCancelled) {
        throw Exception('任务已取消');
      }

      // 创建 HttpClient。证书校验使用系统默认策略，发布版不能绕过 TLS。
      client = HttpClient();
      client.connectionTimeout = _downloadTimeout;

      // 如果使用代理，配置 SOCKS5 代理
      if (useProxy && proxyUrl != null) {
        final proxyConfig = _parseProxyConfig(proxyUrl);
        final proxySettings = ProxySettings(
          InternetAddress(proxyConfig['host']!),
          int.parse(proxyConfig['port']!),
          username: proxyConfig['username'],
          password: proxyConfig['password'],
        );

        SocksTCPClient.assignToHttpClient(client, [proxySettings]);
      }

      // 发起请求
      final uri = Uri.parse(url);
      final request = await client.getUrl(uri);

      // 检查是否已取消
      if (cancelToken.isCancelled) {
        client.close(force: true);
        throw Exception('任务已取消');
      }

      // 设置请求头
      request.headers.set(HttpHeaders.userAgentHeader, option.userAgent);
      request.headers.set(HttpHeaders.acceptHeader, option.accept);

      // 检查是否已取消
      if (cancelToken.isCancelled) {
        client.close(force: true);
        throw Exception('任务已取消');
      }

      // 获取响应
      final response = await request.close().timeout(
        _downloadTimeout,
        onTimeout: () {
          throw TimeoutException('下载超时', _downloadTimeout);
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 400) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      // 检查是否已取消
      if (cancelToken.isCancelled) {
        client.close(force: true);
        throw Exception('任务已取消');
      }

      // 读取响应内容
      final bytes = await response.fold<List<int>>(<int>[], (
        previous,
        element,
      ) {
        if (cancelToken.isCancelled) {
          throw Exception('任务已取消');
        }
        return previous..addAll(element);
      });
      final content = utf8.decode(bytes);

      // 解析响应头
      final disposition = response.headers.value('content-disposition');
      final userinfo = response.headers.value('subscription-userinfo');
      final contentType = response.headers.contentType?.toString();

      String? label;
      if (disposition != null) {
        // 从 content-disposition 提取文件名
        final match = RegExp(
          r'filename="?([^";\n]+)"?',
        ).firstMatch(disposition);
        if (match != null) {
          label = match.group(1)?.trim();
        }
      }

      final subscriptionInfo = userinfo != null
          ? SubscriptionInfo.formHString(userinfo)
          : null;

      return _DownloadRawResult(
        content: content,
        label: label,
        subscriptionInfo: subscriptionInfo,
        bytes: bytes,
        statusCode: response.statusCode,
        contentType: contentType,
        userAgentLabel: option.safeUserAgentLabel,
      );
    } finally {
      if (cancelToken.isCancelled) {
        client?.close(force: true);
      } else {
        client?.close();
      }
    }
  }

  /// 解析代理配置
  ///
  /// 输入格式:
  /// - `socks5://user:pass@host:port`
  /// - `socks5://host:port`
  /// - `http://user:pass@host:port`
  ///
  /// 返回: { host, port, username?, password? }
  static Map<String, String?> _parseProxyConfig(String proxyUrl) {
    String url = proxyUrl.trim();

    // 去除协议前缀
    if (url.toLowerCase().startsWith('socks5://')) {
      url = url.substring(9);
    } else if (url.toLowerCase().startsWith('http://')) {
      url = url.substring(7);
    } else if (url.toLowerCase().startsWith('https://')) {
      url = url.substring(8);
    }

    String? username;
    String? password;
    String hostPort = url;

    // 解析认证信息 user:pass@host:port
    if (url.contains('@')) {
      final atIndex = url.lastIndexOf('@');
      final authPart = url.substring(0, atIndex);
      hostPort = url.substring(atIndex + 1);

      if (authPart.contains(':')) {
        final colonIndex = authPart.indexOf(':');
        username = authPart.substring(0, colonIndex);
        password = authPart.substring(colonIndex + 1);
      }
    }

    // 解析 host:port
    final colonIndex = hostPort.lastIndexOf(':');
    if (colonIndex == -1) {
      throw FormatException('代理配置格式错误，缺少端口号: $proxyUrl');
    }

    final host = hostPort.substring(0, colonIndex);
    final port = hostPort.substring(colonIndex + 1);

    if (host.isEmpty || port.isEmpty) {
      throw FormatException('代理配置格式错误: $proxyUrl');
    }

    return {
      'host': host,
      'port': port,
      'username': username,
      'password': password,
    };
  }
}

SubscriptionConfigNormalizeResult normalizeSubscriptionConfig(String content) {
  try {
    final yaml = loadYaml(content);
    final root = _yamlToDart(yaml);
    if (root is! Map<String, Object?>) {
      return SubscriptionConfigNormalizeResult(content: content);
    }

    final proxies = _listOfMaps(root['proxies']);
    final proxyGroups = _listOfMaps(root['proxy-groups']);
    final proxyProviders = _mapOfMaps(root['proxy-providers']);
    final ruleProviders = _mapOfMaps(root['rule-providers']);

    final proxyNames = proxies
        .map((proxy) => proxy['name'])
        .whereType<String>()
        .where((name) => name.trim().isNotEmpty)
        .toSet();
    final groupNames = proxyGroups
        .map((group) => group['name'])
        .whereType<String>()
        .where((name) => name.trim().isNotEmpty)
        .toSet();
    final providerNames = proxyProviders.keys
        .where((name) => name.trim().isNotEmpty)
        .toSet();
    final hasUseReferences = proxyGroups.any(
      (group) => _stringList(group['use']).isNotEmpty,
    );

    SubscriptionConfigNormalizeResult result(String output) {
      return SubscriptionConfigNormalizeResult(
        content: output,
        repairedGroups: const [],
        proxyCount: proxyNames.length,
        proxyGroupCount: groupNames.length,
        proxyProviderCount: providerNames.length,
        ruleProviderCount: ruleProviders.length,
        groupNames: groupNames.toList()..sort(),
        providerNames: providerNames.toList()..sort(),
        hasUseReferences: hasUseReferences,
        hasUsableNodeSource: _hasUsableNodeSource(
          proxyNames: proxyNames,
          providerNames: providerNames,
          proxyGroups: proxyGroups,
        ),
      );
    }

    if (proxyGroups.isEmpty || (proxyNames.isEmpty && providerNames.isEmpty)) {
      return result(content);
    }

    final missingGroupNames = <String>{};
    for (final group in proxyGroups) {
      final refs = _stringList(group['proxies']);
      for (final ref in refs) {
        if (_isBuiltInProxyRef(ref)) {
          continue;
        }
        if (!proxyNames.contains(ref) && !groupNames.contains(ref)) {
          missingGroupNames.add(ref);
        }
      }
    }

    if (missingGroupNames.isEmpty) {
      return result(content);
    }

    final sortedMissing = missingGroupNames.toList()..sort();
    for (final name in sortedMissing) {
      final repairedGroup = <String, Object?>{
        'name': name,
        'type': 'url-test',
        'url': 'http://www.gstatic.com/generate_204',
        'interval': 300,
      };
      if (providerNames.isNotEmpty) {
        repairedGroup['use'] = providerNames.toList()..sort();
      }
      if (proxyNames.isNotEmpty) {
        repairedGroup['proxies'] = proxyNames.toList()..sort();
      }
      proxyGroups.add(repairedGroup);
      groupNames.add(name);
    }
    root['proxy-groups'] = proxyGroups;

    return SubscriptionConfigNormalizeResult(
      content: _toYamlString(root),
      repairedGroups: sortedMissing,
      proxyCount: proxyNames.length,
      proxyGroupCount: groupNames.length,
      proxyProviderCount: providerNames.length,
      ruleProviderCount: ruleProviders.length,
      groupNames: groupNames.toList()..sort(),
      providerNames: providerNames.toList()..sort(),
      hasUseReferences: proxyGroups.any(
        (group) => _stringList(group['use']).isNotEmpty,
      ),
      hasUsableNodeSource: _hasUsableNodeSource(
        proxyNames: proxyNames,
        providerNames: providerNames,
        proxyGroups: proxyGroups,
      ),
    );
  } catch (error) {
    _logger.warning('订阅配置 normalize 跳过，YAML 解析失败');
    return SubscriptionConfigNormalizeResult(content: content);
  }
}

class SubscriptionConfigNormalizeResult {
  final String content;
  final List<String> repairedGroups;
  final int proxyCount;
  final int proxyGroupCount;
  final int proxyProviderCount;
  final int ruleProviderCount;
  final List<String> groupNames;
  final List<String> providerNames;
  final bool hasUseReferences;
  final bool hasUsableNodeSource;

  const SubscriptionConfigNormalizeResult({
    required this.content,
    this.repairedGroups = const [],
    this.proxyCount = 0,
    this.proxyGroupCount = 0,
    this.proxyProviderCount = 0,
    this.ruleProviderCount = 0,
    this.groupNames = const [],
    this.providerNames = const [],
    this.hasUseReferences = false,
    this.hasUsableNodeSource = false,
  });
}

Object? _yamlToDart(Object? value) {
  if (value is YamlMap) {
    return {
      for (final entry in value.entries)
        entry.key.toString(): _yamlToDart(entry.value),
    };
  }
  if (value is YamlList) {
    return value.map(_yamlToDart).toList();
  }
  return value;
}

List<Map<String, Object?>> _listOfMaps(Object? value) {
  if (value is! List) {
    return <Map<String, Object?>>[];
  }
  return value
      .whereType<Map>()
      .map(
        (item) => item.map(
          (key, dynamic value) => MapEntry(key.toString(), value as Object?),
        ),
      )
      .toList();
}

Map<String, Map<String, Object?>> _mapOfMaps(Object? value) {
  if (value is! Map) {
    return const {};
  }
  return value.map((key, dynamic value) {
    final mapValue = value is Map
        ? value.map(
            (innerKey, dynamic innerValue) =>
                MapEntry(innerKey.toString(), innerValue as Object?),
          )
        : <String, Object?>{};
    return MapEntry(key.toString(), mapValue);
  });
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<String>()
      .where((item) => item.trim().isNotEmpty)
      .toList(growable: false);
}

bool _isBuiltInProxyRef(String value) {
  return const {'DIRECT', 'REJECT', 'REJECT-DROP', 'PASS'}.contains(value);
}

bool _hasUsableNodeSource({
  required Set<String> proxyNames,
  required Set<String> providerNames,
  required List<Map<String, Object?>> proxyGroups,
}) {
  if (proxyNames.isEmpty && providerNames.isEmpty) {
    return false;
  }
  for (final group in proxyGroups) {
    final proxyRefs = _stringList(group['proxies']);
    final hasProxyRef = proxyRefs.any(proxyNames.contains);
    final useRefs = _stringList(group['use']);
    final hasProviderRef = useRefs.any(providerNames.contains);
    if (hasProxyRef || hasProviderRef) {
      return true;
    }
  }
  return false;
}

String _toYamlString(Object? value, {int indent = 0}) {
  final buffer = StringBuffer();
  _writeYamlValue(buffer, value, indent: indent);
  return buffer.toString();
}

void _writeYamlValue(
  StringBuffer buffer,
  Object? value, {
  required int indent,
}) {
  if (value is Map) {
    for (final entry in value.entries) {
      final key = _yamlScalar(entry.key.toString());
      final item = entry.value;
      if (item is Map || item is List) {
        buffer.writeln('${_indent(indent)}$key:');
        _writeYamlValue(buffer, item, indent: indent + 2);
      } else {
        buffer.writeln('${_indent(indent)}$key: ${_yamlScalar(item)}');
      }
    }
    return;
  }
  if (value is List) {
    for (final item in value) {
      if (item is Map) {
        if (item.isEmpty) {
          buffer.writeln('${_indent(indent)}- {}');
          continue;
        }
        var first = true;
        for (final entry in item.entries) {
          final key = _yamlScalar(entry.key.toString());
          final child = entry.value;
          if (first) {
            if (child is Map || child is List) {
              buffer.writeln('${_indent(indent)}- $key:');
              _writeYamlValue(buffer, child, indent: indent + 4);
            } else {
              buffer.writeln('${_indent(indent)}- $key: ${_yamlScalar(child)}');
            }
            first = false;
          } else if (child is Map || child is List) {
            buffer.writeln('${_indent(indent + 2)}$key:');
            _writeYamlValue(buffer, child, indent: indent + 4);
          } else {
            buffer.writeln('${_indent(indent + 2)}$key: ${_yamlScalar(child)}');
          }
        }
      } else if (item is List) {
        buffer.writeln('${_indent(indent)}-');
        _writeYamlValue(buffer, item, indent: indent + 2);
      } else {
        buffer.writeln('${_indent(indent)}- ${_yamlScalar(item)}');
      }
    }
    return;
  }
  buffer.writeln('${_indent(indent)}${_yamlScalar(value)}');
}

String _indent(int indent) => ' ' * indent;

String _yamlScalar(Object? value) {
  if (value == null) {
    return 'null';
  }
  if (value is num || value is bool) {
    return '$value';
  }
  final text = '$value';
  if (text.isEmpty) {
    return "''";
  }
  if (RegExp(r'^[A-Za-z0-9_.@%+=,\/:-]+$').hasMatch(text) &&
      !_yamlReservedScalars.contains(text.toLowerCase())) {
    return text;
  }
  return jsonEncode(text);
}

const _yamlReservedScalars = {
  'true',
  'false',
  'null',
  '~',
  'yes',
  'no',
  'on',
  'off',
};

String _maskSensitiveText(Object? value) {
  final masked = _masker.maskText('$value');
  return masked.replaceAllMapped(
    RegExp(r'https?:\/\/[^\s",)]+', caseSensitive: false),
    (match) {
      final text = match.group(0)!;
      return text.startsWith('https://') ? 'https********' : 'http********';
    },
  );
}

void _logContentSummary(
  _DownloadResult result,
  SubscriptionConfigNormalizeResult normalized,
) {
  final summary = SubscriptionContentSummary.from(result.content);
  _logger.info(
    '订阅响应摘要: status=${result.statusCode}, '
    'contentType=${result.contentType ?? "unknown"}, '
    'length=${result.bytes.length}, '
    'ua=${result.userAgentLabel}, '
    'topKeys=${summary.topLevelKeys.join(",")}, '
    'hasBase64Like=${summary.hasBase64LikeContent}, '
    'protocolCounts=${summary.protocolCounts}',
  );
  _logger.info(
    '订阅配置结构摘要: proxies=${normalized.proxyCount}, '
    'proxy-groups=${normalized.proxyGroupCount}, '
    'proxy-providers=${normalized.proxyProviderCount}, '
    'rule-providers=${normalized.ruleProviderCount}, '
    'groups=${normalized.groupNames.join(",")}, '
    'providers=${normalized.providerNames.join(",")}, '
    'hasUse=${normalized.hasUseReferences}',
  );
}

class SubscriptionDownloadOptions {
  final String userAgent;
  final String accept;

  const SubscriptionDownloadOptions({
    required this.userAgent,
    this.accept = 'text/yaml, application/yaml, text/plain, */*',
  });

  String get safeUserAgentLabel {
    if (userAgent.startsWith('ClashforWindows')) {
      return 'ClashforWindows';
    }
    if (userAgent.startsWith('clash-verge')) {
      return 'clash-verge';
    }
    return userAgent;
  }
}

class SubscriptionContentSummary {
  final List<String> topLevelKeys;
  final bool hasBase64LikeContent;
  final Map<String, int> protocolCounts;

  const SubscriptionContentSummary({
    required this.topLevelKeys,
    required this.hasBase64LikeContent,
    required this.protocolCounts,
  });

  factory SubscriptionContentSummary.from(String content) {
    final keys = <String>[];
    try {
      final root = _yamlToDart(loadYaml(content));
      if (root is Map<String, Object?>) {
        keys.addAll(root.keys.take(12));
      }
    } catch (_) {}

    final lower = content.toLowerCase();
    final counts = {
      'vmess': RegExp(r'vmess:\/\/|type:\s*vmess').allMatches(lower).length,
      'vless': RegExp(r'vless:\/\/|type:\s*vless').allMatches(lower).length,
      'trojan': RegExp(r'trojan:\/\/|type:\s*trojan').allMatches(lower).length,
      'hysteria': RegExp(
        r'hysteria:\/\/|hysteria2:\/\/|type:\s*hysteria',
      ).allMatches(lower).length,
      'ss': RegExp(r'(^|\n)ss:\/\/|type:\s*ss(\n|$)').allMatches(lower).length,
    };

    return SubscriptionContentSummary(
      topLevelKeys: keys,
      hasBase64LikeContent: _looksLikeBase64Subscription(content),
      protocolCounts: counts,
    );
  }
}

bool _looksLikeBase64Subscription(String content) {
  final text = content.trim();
  if (text.isEmpty ||
      text.contains('\nproxies:') ||
      text.startsWith('proxies:')) {
    return false;
  }
  if (text.contains('://')) {
    return false;
  }
  final compact = text.replaceAll(RegExp(r'\s+'), '');
  if (compact.length < 80 || compact.length % 4 != 0) {
    return false;
  }
  return RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(compact);
}

/// 取消令牌
class _CancelToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

/// 下载结果（含连接类型）
class _DownloadResult {
  final String content;
  final String connectionType;
  final String? label;
  final SubscriptionInfo? subscriptionInfo;
  final List<int> bytes;
  final int statusCode;
  final String? contentType;
  final String userAgentLabel;

  _DownloadResult({
    required this.content,
    required this.connectionType,
    this.label,
    this.subscriptionInfo,
    required this.bytes,
    required this.statusCode,
    required this.contentType,
    required this.userAgentLabel,
  });
}

/// 下载原始结果
class _DownloadRawResult {
  final String content;
  final String? label;
  final SubscriptionInfo? subscriptionInfo;
  final List<int> bytes;
  final int statusCode;
  final String? contentType;
  final String userAgentLabel;

  _DownloadRawResult({
    required this.content,
    this.label,
    this.subscriptionInfo,
    required this.bytes,
    required this.statusCode,
    required this.contentType,
    required this.userAgentLabel,
  });
}
