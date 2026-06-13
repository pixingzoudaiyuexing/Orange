import '../config/remote_config.dart';
import 'secure_config.dart';
import 'secure_crypto_service.dart';
import 'secure_http_client.dart';

extension RemoteSecurityConfigSecureConfig on RemoteSecurityConfig {
  SecureConfig toSecureConfig({
    required String appVersion,
    required String platform,
    Duration timeout = const Duration(seconds: 15),
  }) {
    return SecureConfig(
      securityBaseUrl: securityBaseUrl,
      backupSecurityBaseUrls: backupSecurityBaseUrls,
      keyId: keyId,
      publicKey: publicKey,
      appVersion: appVersion,
      platform: platform,
      timeout: timeout,
    );
  }
}

extension RemoteConfigRepositorySecureHttpClient on RemoteConfigRepository {
  SecureHttpClient createSecureHttpClient({
    required String appVersion,
    required String platform,
    SecureTransport? transport,
    SecureCryptoService? cryptoService,
  }) {
    return SecureHttpClient(
      config: getSecurityConfig().toSecureConfig(
        appVersion: appVersion,
        platform: platform,
      ),
      transport: transport,
      cryptoService: cryptoService,
    );
  }
}
