import 'bootstrap_config.dart';
import 'config_cache.dart';
import 'config_errors.dart';
import 'config_models.dart';
import 'config_signature_verifier.dart';
import 'remote_config_service.dart';

class RemoteConfigRepository {
  final BootstrapConfig bootstrap;
  final RemoteConfigCache cache;
  final RemoteConfigService service;

  RemoteConfigDocument? _currentConfig;

  RemoteConfigRepository({
    required this.cache,
    required this.service,
    BootstrapConfig? bootstrap,
  }) : bootstrap = bootstrap ?? bootstrapConfig;

  static Future<RemoteConfigRepository> create({
    BootstrapConfig? bootstrap,
    RemoteConfigHttpClient? httpClient,
  }) async {
    final resolvedBootstrap = bootstrap ?? bootstrapConfig;
    final cache = await SharedPreferencesRemoteConfigCache.create();
    final service = RemoteConfigService(
      httpClient: httpClient ?? SafeRemoteConfigHttpClient(),
      cache: cache,
      verifier: ConfigSignatureVerifier(
        resolvedBootstrap.configVerifyPublicKey,
      ),
    );
    return RemoteConfigRepository(
      bootstrap: resolvedBootstrap,
      cache: cache,
      service: service,
    );
  }

  Future<RemoteConfigDocument> loadInitialConfig() async {
    final cached = await cache.readLastKnownGood();
    _currentConfig = cached ?? bootstrap.defaultConfig;
    return _currentConfig!;
  }

  Future<RemoteConfigResult<RemoteConfigDocument>> refreshRemoteConfig() async {
    try {
      final result = await service.fetch(
        configUrls: bootstrap.configUrls,
        defaultConfig: bootstrap.defaultConfig,
        currentConfig: _currentConfig,
      );
      _currentConfig = result.config;
      if (result.fallbackError != null) {
        return RemoteConfigResult.failure(
          result.fallbackError!,
          result.sourceUrl,
        );
      }
      return RemoteConfigResult.success(result.config, result.sourceUrl);
    } on RemoteConfigException catch (error) {
      return RemoteConfigResult.failure(error, 'remote');
    } catch (_) {
      return RemoteConfigResult.failure(
        const RemoteConfigException(
          RemoteConfigErrorCode.noRemoteConfig,
          'Remote config refresh failed',
        ),
        'remote',
      );
    }
  }

  RemoteConfigDocument getCurrentConfig() {
    return _currentConfig ?? bootstrap.defaultConfig;
  }

  RemoteSecurityConfig getSecurityConfig() {
    return getCurrentConfig().config.security;
  }

  RemoteFeatureFlags getFeatureFlags() {
    return getCurrentConfig().config.features;
  }

  UpdateInfo getUpdateInfo() {
    final config = getCurrentConfig();
    return UpdateInfo(
      minClientVersion: config.minClientVersion,
      latestClientVersion: config.latestClientVersion,
      forceUpdate: config.forceUpdate,
      updateUrl: config.config.urls.updateUrl,
    );
  }

  MaintenanceInfo getMaintenanceInfo() {
    final config = getCurrentConfig();
    return MaintenanceInfo(
      maintenance: config.maintenance,
      message: config.maintenanceMessage,
    );
  }

  Future<void> clearCacheForDebug() async {
    var debugMode = false;
    assert(() {
      debugMode = true;
      return true;
    }());
    if (!debugMode) {
      return;
    }
    await cache.clear();
    _currentConfig = bootstrap.defaultConfig;
  }
}
