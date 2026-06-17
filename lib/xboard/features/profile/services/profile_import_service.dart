import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/security/security.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/xboard/features/profile/profile.dart';
import 'package:fl_clash/xboard/features/subscription/services/encrypted_subscription_service.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_downloader.dart';
import 'package:fl_clash/xboard/features/subscription/utils/utils.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/config/utils/config_file_loader.dart';

// 初始化文件级日志器
final _logger = FileLogger('profile_import_service.dart');
const _masker = SensitiveLogMasker();
const wyxV2BoardProfileSource = 'wyx_v2board';
const wyxV2BoardProfileLabel = 'wyx_v2board subscription';

abstract class ProfileImportServiceApi {
  Future<ImportResult> importSubscription(
    String url, {
    Function(ImportStatus, double, String?)? onProgress,
    bool persistUrl = true,
    String? source,
    bool allowEncryptedService = true,
  });

  Future<ImportResult> importSubscriptionWithRetry(
    String url, {
    Function(ImportStatus, double, String?)? onProgress,
    int retries = XBoardProfileImportService.maxRetries,
    bool persistUrl = true,
    String? source,
    bool allowEncryptedService = true,
  });

  bool get isImporting;
}

final xboardProfileImportServiceProvider = Provider<ProfileImportServiceApi>((
  ref,
) {
  return XBoardProfileImportService(ref);
});

typedef ProfileDownloader =
    Future<Profile> Function(
      String url, {
      required bool persistUrl,
      String? source,
      required bool allowEncryptedService,
    });

typedef ProfileApplyRunner = Future<void> Function();

typedef ProfileEffectCleaner = FutureOr<void> Function(String profileId);

class XBoardProfileImportService implements ProfileImportServiceApi {
  final Ref _ref;
  final ProfileDownloader? _profileDownloader;
  final ProfileApplyRunner? _profileApplyRunner;
  final ProfileEffectCleaner? _profileEffectCleaner;
  bool _isImporting = false;
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  static const Duration downloadTimeout = Duration(seconds: 30);
  XBoardProfileImportService(
    this._ref, {
    ProfileDownloader? profileDownloader,
    ProfileApplyRunner? profileApplyRunner,
    ProfileEffectCleaner? profileEffectCleaner,
  }) : _profileDownloader = profileDownloader,
       _profileApplyRunner = profileApplyRunner,
       _profileEffectCleaner = profileEffectCleaner;

  @override
  Future<ImportResult> importSubscription(
    String url, {
    Function(ImportStatus, double, String?)? onProgress,
    bool persistUrl = true,
    String? source,
    bool allowEncryptedService = true,
  }) async {
    if (_isImporting) {
      return ImportResult.failure(
        errorMessage: '正在导入中，请稍候',
        errorType: ImportErrorType.unknownError,
      );
    }
    _isImporting = true;
    final stopwatch = Stopwatch()..start();
    try {
      _logger.info(
        '开始导入订阅配置: ${_maskSensitiveText(url)}, '
        'persistUrl: $persistUrl, source: ${source ?? "default"}',
      );

      // 1. 先下载并验证新配置（不删除旧配置）
      onProgress?.call(ImportStatus.downloading, 0.3, '下载配置文件');
      final profile = await _downloadAndValidateProfile(
        url,
        persistUrl: persistUrl,
        source: source,
        allowEncryptedService: allowEncryptedService,
      );
      onProgress?.call(ImportStatus.validating, 0.6, '验证配置格式');

      // 2. 先应用新配置，成功后再清理旧配置，避免失败时丢失旧可用配置。
      onProgress?.call(ImportStatus.adding, 0.7, '应用订阅配置');
      await _addAndApplyProfile(profile);

      // 3. 应用成功后再清理旧配置。
      onProgress?.call(ImportStatus.cleaning, 0.9, '替换旧的订阅配置');
      if (persistUrl) {
        await _cleanOldUrlProfiles(excludeProfileId: profile.id);
      } else {
        await _cleanOldGeneratedProfiles(
          source: source,
          excludeProfileId: profile.id,
        );
        _restoreGeneratedProfileLabel(profileId: profile.id, source: source);
      }

      stopwatch.stop();
      onProgress?.call(ImportStatus.success, 1.0, '导入成功');
      _logger.info('订阅配置导入成功，耗时: ${stopwatch.elapsedMilliseconds}ms');
      return ImportResult.success(
        profile: profile,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      _logger.error('订阅配置导入失败', _maskSensitiveText(e));
      final errorType = _classifyError(e);
      final userMessage = _getUserFriendlyErrorMessage(e, errorType);
      onProgress?.call(ImportStatus.failed, 0.0, userMessage);
      return ImportResult.failure(
        errorMessage: userMessage,
        errorType: errorType,
        duration: stopwatch.elapsed,
      );
    } finally {
      _isImporting = false;
    }
  }

  @override
  Future<ImportResult> importSubscriptionWithRetry(
    String url, {
    Function(ImportStatus, double, String?)? onProgress,
    int retries = maxRetries,
    bool persistUrl = true,
    String? source,
    bool allowEncryptedService = true,
  }) async {
    for (int attempt = 1; attempt <= retries; attempt++) {
      _logger.debug('导入尝试 $attempt/$retries');
      final result = await importSubscription(
        url,
        onProgress: onProgress,
        persistUrl: persistUrl,
        source: source,
        allowEncryptedService: allowEncryptedService,
      );
      if (result.isSuccess) {
        return result;
      }
      if (result.errorType != ImportErrorType.networkError &&
          result.errorType != ImportErrorType.downloadError) {
        return result;
      }
      if (attempt == retries) {
        return result;
      }
      _logger.debug('等待 ${retryDelay.inSeconds} 秒后重试');
      onProgress?.call(
        ImportStatus.downloading,
        0.0,
        '第 $attempt 次尝试失败，等待重试...',
      );
      await Future.delayed(retryDelay);
    }
    return ImportResult.failure(
      errorMessage: '多次重试后仍然失败',
      errorType: ImportErrorType.networkError,
    );
  }

  Future<void> _cleanOldUrlProfiles({String? excludeProfileId}) async {
    try {
      final profiles = globalState.config.profiles;
      final urlProfiles = profiles
          .where(
            (profile) =>
                profile.type == ProfileType.url &&
                profile.id != excludeProfileId,
          )
          .toList();

      for (final profile in urlProfiles) {
        _logger.debug('删除旧的URL配置: ${profile.label ?? profile.id}');
        _ref.read(profilesProvider.notifier).deleteProfileById(profile.id);
        await _clearProfileEffect(profile.id);
      }

      _logger.info('清理了 ${urlProfiles.length} 个旧的URL配置');
    } catch (e) {
      _logger.warning('清理旧配置时出错', e);
      throw Exception('清理旧配置失败: $e');
    }
  }

  Future<void> _cleanOldGeneratedProfiles({
    String? source,
    String? excludeProfileId,
  }) async {
    try {
      final label = _profileLabel(source);
      final profiles = globalState.config.profiles;
      final generatedProfiles = profiles
          .where(
            (profile) =>
                profile.url.isEmpty &&
                profile.label == label &&
                profile.id != excludeProfileId,
          )
          .toList();

      for (final profile in generatedProfiles) {
        _logger.debug('删除旧的本地订阅配置: ${profile.label ?? profile.id}');
        _ref.read(profilesProvider.notifier).deleteProfileById(profile.id);
        await _clearProfileEffect(profile.id);
      }

      _logger.info('清理了 ${generatedProfiles.length} 个旧的本地订阅配置');
    } catch (e) {
      _logger.warning('清理旧本地订阅配置时出错', _maskSensitiveText(e));
      throw Exception('清理旧配置失败');
    }
  }

  void _restoreGeneratedProfileLabel({
    required String profileId,
    String? source,
  }) {
    final label = _profileLabel(source);
    final profiles = globalState.config.profiles;
    final profile = profiles.getProfile(profileId);
    if (profile == null || profile.url.isNotEmpty || profile.label == label) {
      return;
    }
    final hasDuplicate = profiles.any(
      (item) => item.id != profileId && item.label == label,
    );
    if (hasDuplicate) {
      return;
    }
    _ref
        .read(profilesProvider.notifier)
        .updateProfile(profileId, (item) => item.copyWith(label: label));
  }

  Future<Profile> _downloadAndValidateProfile(
    String url, {
    required bool persistUrl,
    String? source,
    required bool allowEncryptedService,
  }) async {
    try {
      _logger.info('开始下载配置: ${_maskSensitiveText(url)}');

      // 先检查用户配置是否禁用了加密订阅
      final preferEncrypt = await ConfigFileLoaderHelper.getPreferEncrypt();

      // 用户启用加密，检查URL是否需要使用加密订阅服务
      if (allowEncryptedService &&
          preferEncrypt &&
          SubscriptionUrlHelper.shouldUseEncryptedService(url)) {
        _logger.info('🔐 检测到加密订阅URL且用户启用加密，使用加密解密服务');
        return await _downloadEncryptedProfile(
          url,
          persistUrl: persistUrl,
          source: source,
        );
      }

      // 使用 XBoard 订阅下载服务
      _logger.info('📄 使用 XBoard 订阅下载服务（并发竞速）');
      final downloader = _profileDownloader;
      if (downloader != null) {
        final profile =
            await downloader(
              url,
              persistUrl: persistUrl,
              source: source,
              allowEncryptedService: allowEncryptedService,
            ).timeout(
              downloadTimeout,
              onTimeout: () {
                throw TimeoutException('下载超时', downloadTimeout);
              },
            );
        _logger.info('配置下载和验证成功: ${profile.label ?? profile.id}');
        return profile;
      }

      final profile =
          await SubscriptionDownloader.downloadSubscription(
            url,
            enableRacing: true,
            persistUrl: persistUrl,
            label: _profileLabel(source),
            options: source == wyxV2BoardProfileSource && !persistUrl
                ? SubscriptionDownloader.wyxV2BoardOptions
                : null,
          ).timeout(
            downloadTimeout,
            onTimeout: () {
              throw TimeoutException('下载超时', downloadTimeout);
            },
          );

      _logger.info('配置下载和验证成功: ${profile.label ?? profile.id}');
      return profile;
    } on TimeoutException catch (e) {
      throw Exception('下载超时: ${e.message}');
    } on SocketException catch (e) {
      throw Exception('网络连接失败: ${e.message}');
    } on HttpException catch (e) {
      throw Exception('HTTP请求失败: ${e.message}');
    } catch (e) {
      if (e.toString().contains('validateConfig')) {
        throw Exception('配置文件格式错误: $e');
      }
      throw Exception('下载配置失败: $e');
    }
  }

  /// 下载加密的订阅配置
  Future<Profile> _downloadEncryptedProfile(
    String url, {
    required bool persistUrl,
    String? source,
  }) async {
    try {
      _logger.info('📦 开始下载加密订阅配置流程');
      _logger.debug('🔗 目标URL: ${_maskSensitiveText(url)}');

      // 从本地配置读取订阅偏好设置（竞速自动跟随加密选项）
      final preferEncrypt = await ConfigFileLoaderHelper.getPreferEncrypt();

      _logger.info(
        '📝 本地配置: preferEncrypt=$preferEncrypt (竞速: ${preferEncrypt ? "启用" : "禁用"})',
      );

      // 优先从登录数据获取token，如果失败再从URL解析
      String? token;
      SubscriptionResult result;

      try {
        _logger.debug('🔑 尝试从登录数据获取token');
        result = await EncryptedSubscriptionService.getSubscriptionSmart(
          null,
          preferEncrypt: preferEncrypt,
          enableRace: preferEncrypt, // 竞速自动等于加密选项
        );

        if (!result.success) {
          // 如果从登录数据获取失败，尝试从URL提取token
          _logger.warning(
            '⚠️ 从登录数据获取失败，尝试从URL提取token: '
            '${_maskSensitiveText(result.error)}',
          );
          token = SubscriptionUrlHelper.extractTokenFromUrl(url);
          if (token == null) {
            throw Exception('无法从URL中提取token且登录数据获取失败');
          }

          _logger.debug('🔑 从URL提取到token: [MASKED]');
          result = await EncryptedSubscriptionService.getSubscriptionSmart(
            token,
            preferEncrypt: preferEncrypt,
            enableRace: preferEncrypt, // 竞速自动等于加密选项
          );
        } else {
          _logger.info('✅ 成功从登录数据获取订阅');
        }
      } catch (e) {
        // 最后的fallback：从URL提取token
        _logger.warning('⚠️ 登录方式失败，fallback到URL解析', e);
        token = SubscriptionUrlHelper.extractTokenFromUrl(url);
        if (token == null) {
          throw Exception('所有token获取方式都失败');
        }

        _logger.debug('🔄 Fallback - 从URL提取到token: [MASKED]');
        result = await EncryptedSubscriptionService.getSubscriptionSmart(
          token,
          preferEncrypt: preferEncrypt,
          enableRace: preferEncrypt, // 竞速自动等于加密选项
        );
      }

      if (!result.success) {
        throw Exception('加密订阅获取失败: ${result.error}');
      }

      _logger.info('🎉 加密订阅获取成功！加密模式: ${result.encryptionUsed}');
      if (result.keyUsed != null) {
        _logger.debug('🔑 使用解密密钥: ${result.keyUsed?.substring(0, 8)}...');
      }

      // 验证解密后的配置内容
      _logger.debug('📄 验证解密后的配置内容，长度: ${result.content!.length}');
      if (result.content!.trim().isEmpty) {
        throw Exception('解密后的配置内容为空');
      }

      // 记录配置内容的基本统计信息
      final lines = result.content!.split('\n');
      final nonEmptyLines = lines
          .where((line) => line.trim().isNotEmpty)
          .length;
      _logger.debug('📄 配置内容统计: 总行数 ${lines.length}, 非空行数 $nonEmptyLines');

      // 移除冗余的格式检查，让ClashMeta核心进行权威验证
      _logger.debug('⚡ 跳过客户端格式验证，将由ClashMeta核心进行权威验证');

      // 创建Profile并保存解密的配置内容
      _logger.debug('💾 开始保存解密的配置内容到Profile...');
      final profile = Profile.normal(
        label: _profileLabel(source),
        url: persistUrl ? url : '',
      );
      final profileWithContent = await profile.saveFileWithString(
        result.content!,
      );
      _logger.info('✅ 配置内容已成功保存并通过ClashMeta核心验证');

      // 获取订阅信息并更新Profile
      _logger.info('📊 开始获取加密订阅的订阅信息...');
      final subscriptionInfo = await ProfileSubscriptionInfoService.instance
          .getSubscriptionInfo(
            subscriptionUserInfo: result.subscriptionUserInfo,
          );
      _logger.info(
        '📊 Profile订阅信息获取完成: upload=${subscriptionInfo.upload}, download=${subscriptionInfo.download}, total=${subscriptionInfo.total}',
      );

      // 返回带有订阅信息的Profile
      final updatedProfile = profileWithContent.copyWith(
        subscriptionInfo: subscriptionInfo,
      );

      _logger.info(
        '🎉 加密配置验证和保存成功！最终Profile订阅信息: ${updatedProfile.subscriptionInfo}',
      );
      _logger.debug('✅ 完整的加密订阅处理流程已成功完成');
      return updatedProfile;
    } catch (e) {
      _logger.error('💥 加密配置下载失败', _maskSensitiveText(e));
      _logger.debug('❌ 加密订阅处理流程异常终止');
      throw Exception('加密订阅处理失败');
    }
  }

  Future<void> _addAndApplyProfile(Profile profile) async {
    final previousProfileId = globalState.config.currentProfileId;
    final previousGroups = List<Group>.from(globalState.appState.groups);
    final previousProviders = List<ExternalProvider>.from(
      globalState.appState.providers,
    );
    var profileAdded = false;
    try {
      _ref.read(profilesProvider.notifier).setProfile(profile);
      profileAdded = true;

      _ref.read(currentProfileIdProvider.notifier).value = profile.id;
      _logger.info('✅ 已设置为待应用配置: ${profile.label ?? profile.id}');

      _logger.info('📋 使用 silence 模式应用配置...');
      await (_profileApplyRunner?.call() ??
          globalState.appController.applyProfile(silence: true));

      _logger.info('✅ 配置应用成功');
      _logger.info('配置添加成功: ${profile.label ?? profile.id}');
    } catch (e) {
      _logger.error('❌ 配置应用失败', _maskSensitiveText(e));
      if (profileAdded) {
        _ref.read(profilesProvider.notifier).deleteProfileById(profile.id);
        await _clearProfileEffect(profile.id);
      }
      _ref.read(currentProfileIdProvider.notifier).value = previousProfileId;
      _ref.read(groupsProvider.notifier).value = previousGroups;
      _ref.read(providersProvider.notifier).value = previousProviders;
      throw Exception('应用配置失败');
    }
  }

  Future<void> _clearProfileEffect(String profileId) async {
    try {
      final cleaner = _profileEffectCleaner;
      if (cleaner != null) {
        await cleaner(profileId);
        return;
      }
      if (globalState.config.currentProfileId == profileId) {
        final profiles = globalState.config.profiles;
        final currentProfileIdNotifier = _ref.read(
          currentProfileIdProvider.notifier,
        );
        if (profiles.isNotEmpty) {
          final updateId = profiles.first.id;
          currentProfileIdNotifier.value = updateId;
        } else {
          currentProfileIdNotifier.value = null;
          globalState.appController.updateStatus(false);
        }
      }
      await globalState.appController.clearEffect(profileId);
    } catch (e) {
      _logger.warning('清理配置缓存时出错', e);
    }
  }

  ImportErrorType _classifyError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('timeout') ||
        errorString.contains('连接失败') ||
        errorString.contains('network')) {
      return ImportErrorType.networkError;
    }
    if (errorString.contains('下载') ||
        errorString.contains('http') ||
        errorString.contains('响应')) {
      return ImportErrorType.downloadError;
    }
    if (errorString.contains('validateconfig') ||
        errorString.contains('格式错误') ||
        errorString.contains('解析') ||
        errorString.contains('配置文件格式错误') ||
        errorString.contains('clash配置') ||
        errorString.contains('invalid config')) {
      return ImportErrorType.validationError;
    }
    if (errorString.contains('存储') ||
        errorString.contains('文件') ||
        errorString.contains('保存')) {
      return ImportErrorType.storageError;
    }
    return ImportErrorType.unknownError;
  }

  String _getUserFriendlyErrorMessage(
    dynamic error,
    ImportErrorType errorType,
  ) {
    final errorString = error.toString();

    switch (errorType) {
      case ImportErrorType.networkError:
        return '网络连接失败，请检查网络设置后重试';
      case ImportErrorType.downloadError:
        // 特殊处理User-Agent相关错误
        if (errorString.contains('Invalid HTTP header field value')) {
          return '配置文件下载失败：HTTP请求头格式错误，请稍后重试';
        }
        if (errorString.contains('FormatException')) {
          return '配置文件下载失败：请求格式错误，请稍后重试';
        }
        return '配置文件下载失败，请检查订阅链接是否正确';
      case ImportErrorType.validationError:
        return '配置文件格式验证失败，请联系服务提供商检查配置格式';
      case ImportErrorType.storageError:
        return '保存配置失败，请检查存储空间';
      case ImportErrorType.unknownError:
        // 简化未知错误的显示，避免显示技术细节
        if (errorString.contains('Invalid HTTP header field value') ||
            errorString.contains('FormatException')) {
          return '导入失败：应用配置错误，请稍后重试或重启应用';
        }
        return '导入失败，请稍后重试或联系技术支持';
    }
  }

  @override
  bool get isImporting => _isImporting;
}

String _profileLabel(String? source) {
  if (source == wyxV2BoardProfileSource) {
    return wyxV2BoardProfileLabel;
  }
  if (source == null || source.isEmpty) {
    return 'subscription';
  }
  return '$source subscription';
}

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
