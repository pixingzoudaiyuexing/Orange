import 'dart:io';

import 'package:fl_clash/config/remote_config.dart';
import 'package:fl_clash/security/secure_remote_config_adapter.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../wyx_v2board.dart';

final _logger = FileLogger('wyx_v2board_providers.dart');

final remoteConfigRepositoryProvider =
    FutureProvider<RemoteConfigRepository>((ref) async {
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

final wyxV2BoardAdapterProvider =
    FutureProvider<WyxV2BoardAdapterApi>((ref) async {
  final repository = await ref.watch(remoteConfigRepositoryProvider.future);
  final packageInfo = await PackageInfo.fromPlatform();
  final client = repository.createSecureHttpClient(
    appVersion: packageInfo.version,
    platform: _platformName(),
  );
  return WyxV2BoardAdapter.withSecureHttpClient(client);
});

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
