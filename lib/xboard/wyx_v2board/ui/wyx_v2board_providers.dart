import 'dart:io';

import 'package:fl_clash/config/remote_config.dart';
import 'package:fl_clash/security/security.dart';
import 'package:fl_clash/security/secure_remote_config_adapter.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../wyx_v2board.dart';

final _logger = FileLogger('wyx_v2board_providers.dart');

final remoteConfigRepositoryProvider = FutureProvider<RemoteConfigRepository>((
  ref,
) async {
  final repository = await RemoteConfigRepository.create();
  await repository.loadInitialConfig();
  final refreshResult = await repository.refreshRemoteConfig();
  if (!refreshResult.isSuccess) {
    _logger.warning(
      'RemoteConfig refresh failed, using fallback config: '
      '${refreshResult.error?.code.name}',
    );
  }
  return repository;
});

final wyxV2BoardAdapterProvider = FutureProvider<WyxV2BoardAdapterApi>((
  ref,
) async {
  final packageInfo = await PackageInfo.fromPlatform();
  final xboardSecureConfig = _secureConfigFromXBoardConfig(
    appVersion: packageInfo.version,
    platform: _platformName(),
  );
  if (xboardSecureConfig != null) {
    _logger.info('Using secure-v2 config from XBoard local RemoteConfig');
    return WyxV2BoardAdapter.withSecureHttpClient(
      SecureHttpClient(config: xboardSecureConfig),
    );
  }

  final repository = await ref.watch(remoteConfigRepositoryProvider.future);
  final client = repository.createSecureHttpClient(
    appVersion: packageInfo.version,
    platform: _platformName(),
  );
  return WyxV2BoardAdapter.withSecureHttpClient(client);
});

SecureConfig? _secureConfigFromXBoardConfig({
  required String appVersion,
  required String platform,
}) {
  if (!XBoardConfig.isInitialized) {
    return null;
  }

  final panels = XBoardConfig.panelList;
  if (panels.isEmpty) {
    return null;
  }

  final secureV2 = panels.first.metadata?['secure_v2'];
  if (secureV2 is! Map) {
    return null;
  }
  if (secureV2['enabled'] == false) {
    return null;
  }

  final securityBaseUrl =
      _readString(secureV2, 'security_base_url') ??
      _readString(secureV2, 'securityBaseUrl');
  final keyId =
      _readString(secureV2, 'key_id') ?? _readString(secureV2, 'keyId');
  final publicKey =
      _readString(secureV2, 'public_key') ?? _readString(secureV2, 'publicKey');
  final backupSecurityBaseUrls =
      _readStringList(secureV2, 'backup_security_base_urls') ??
      _readStringList(secureV2, 'backupSecurityBaseUrls') ??
      const <String>[];

  if (securityBaseUrl == null || keyId == null || publicKey == null) {
    _logger.warning('XBoard secure_v2 config is incomplete, using fallback');
    return null;
  }

  return SecureConfig(
    securityBaseUrl: securityBaseUrl,
    backupSecurityBaseUrls: backupSecurityBaseUrls,
    keyId: keyId,
    publicKey: publicKey,
    appVersion: appVersion,
    platform: platform,
  );
}

String? _readString(Map<dynamic, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

List<String>? _readStringList(Map<dynamic, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    return null;
  }
  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String _platformName() {
  if (Platform.isWindows) {
    return 'windows';
  }
  if (Platform.isMacOS) {
    return 'macos';
  }
  if (Platform.isAndroid) {
    return 'android';
  }
  if (Platform.isLinux) {
    return 'linux';
  }
  if (Platform.isIOS) {
    return 'ios';
  }
  return Platform.operatingSystem;
}
