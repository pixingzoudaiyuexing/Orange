import 'secure_http_errors.dart';

class SecureConfig {
  final String securityBaseUrl;
  final List<String> backupSecurityBaseUrls;
  final String keyId;
  final String publicKey;
  final String appVersion;
  final String platform;
  final Duration timeout;

  const SecureConfig({
    required this.securityBaseUrl,
    required this.backupSecurityBaseUrls,
    required this.keyId,
    required this.publicKey,
    required this.appVersion,
    required this.platform,
    this.timeout = const Duration(seconds: 15),
  });

  List<String> orderedBaseUrls([String? preferredBaseUrl]) {
    final urls = <String>[];
    if (preferredBaseUrl != null && _isConfiguredBaseUrl(preferredBaseUrl)) {
      urls.add(preferredBaseUrl);
    }
    if (securityBaseUrl.isNotEmpty && !urls.contains(securityBaseUrl)) {
      urls.add(securityBaseUrl);
    }
    for (final url in backupSecurityBaseUrls) {
      if (url.isNotEmpty && !urls.contains(url)) {
        urls.add(url);
      }
    }
    return urls;
  }

  void validate() {
    if (keyId.trim().isEmpty) {
      throw const SecureHttpException(
        code: SecureHttpErrorCode.invalidConfig,
        message: 'Missing secure-v2 keyId',
        safeDebugMessage: 'keyId is empty',
      );
    }
    if (publicKey.trim().isEmpty) {
      throw const SecureHttpException(
        code: SecureHttpErrorCode.invalidConfig,
        message: 'Missing secure-v2 public key',
        safeDebugMessage: 'publicKey is empty',
      );
    }
    if (securityBaseUrl.trim().isEmpty) {
      throw const SecureHttpException(
        code: SecureHttpErrorCode.invalidConfig,
        message: 'Missing security base URL',
        safeDebugMessage: 'securityBaseUrl is empty',
      );
    }
    final urls = orderedBaseUrls();
    if (urls.isEmpty) {
      throw const SecureHttpException(
        code: SecureHttpErrorCode.invalidConfig,
        message: 'Missing security base URL',
        safeDebugMessage: 'securityBaseUrl is empty',
      );
    }
    for (final url in urls) {
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw SecureHttpException(
          code: SecureHttpErrorCode.invalidConfig,
          message: 'Invalid security base URL',
          safeDebugMessage: 'security base URL must be HTTPS',
        );
      }
    }
  }

  bool _isConfiguredBaseUrl(String url) {
    return url == securityBaseUrl || backupSecurityBaseUrls.contains(url);
  }
}
