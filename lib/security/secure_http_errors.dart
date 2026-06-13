enum SecureHttpErrorCode {
  network,
  invalidConfig,
  invalidPath,
  invalidMethod,
  invalidHeader,
  encryptionFailed,
  decryptionFailed,
  invalidResponse,
  requestIdMismatch,
  httpStatus,
  secureV2Error,
}

class SecureHttpException implements Exception {
  final SecureHttpErrorCode code;
  final String message;
  final String? requestId;
  final int? statusCode;
  final String safeDebugMessage;

  const SecureHttpException({
    required this.code,
    required this.message,
    this.requestId,
    this.statusCode,
    this.safeDebugMessage = '',
  });

  @override
  String toString() {
    return 'SecureHttpException('
        'code: $code, '
        'message: $message, '
        'requestId: $requestId, '
        'statusCode: $statusCode, '
        'safeDebugMessage: $safeDebugMessage'
        ')';
  }
}
