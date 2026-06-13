import 'package:fl_clash/security/security.dart';

enum WyxV2BoardErrorCode {
  loginFailed,
  unauthenticated,
  backendError,
  secureTransport,
  invalidResponse,
  notImplemented,
}

class WyxV2BoardException implements Exception {
  final WyxV2BoardErrorCode code;
  final String message;
  final int? statusCode;
  final String? requestId;
  final String safeDebugMessage;

  const WyxV2BoardException({
    required this.code,
    required this.message,
    this.statusCode,
    this.requestId,
    this.safeDebugMessage = '',
  });

  factory WyxV2BoardException.fromSecureHttp(SecureHttpException error) {
    return WyxV2BoardException(
      code: WyxV2BoardErrorCode.secureTransport,
      message: 'Secure request failed',
      statusCode: error.statusCode,
      requestId: error.requestId,
      safeDebugMessage: error.safeDebugMessage.isEmpty
          ? error.code.name
          : error.safeDebugMessage,
    );
  }

  @override
  String toString() {
    return 'WyxV2BoardException('
        'code: $code, '
        'message: $message, '
        'statusCode: $statusCode, '
        'requestId: $requestId, '
        'safeDebugMessage: $safeDebugMessage'
        ')';
  }
}
