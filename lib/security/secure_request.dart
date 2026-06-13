import 'secure_http_errors.dart';

class SecureRequest {
  final String method;
  final String path;
  final Map<String, String> headers;
  final Map<String, String> query;
  final Object? body;

  SecureRequest({
    required String method,
    required this.path,
    Map<String, String>? headers,
    Map<String, String>? query,
    this.body,
  })  : method = method.toUpperCase(),
        headers = Map.unmodifiable(_filterHeaders(headers ?? const {})),
        query = Map.unmodifiable(query ?? const {}) {
    _validateMethod(this.method);
    _validatePath(path);
  }

  Map<String, dynamic> toPayloadJson() {
    final payload = <String, dynamic>{
      'method': method,
      'path': path,
      'headers': headers,
      'query': query,
    };
    if (body != null) {
      payload['body'] = body;
    } else {
      payload['body'] = <String, dynamic>{};
    }
    return payload;
  }

  static void _validateMethod(String method) {
    const allowedMethods = {'GET', 'POST', 'PUT', 'DELETE'};
    if (!allowedMethods.contains(method)) {
      throw SecureHttpException(
        code: SecureHttpErrorCode.invalidMethod,
        message: 'Secure request method is not allowed',
        safeDebugMessage: 'method=$method',
      );
    }
  }

  static void _validatePath(String path) {
    final uri = Uri.tryParse(path);
    if (path.isEmpty ||
        uri == null ||
        uri.hasScheme ||
        uri.host.isNotEmpty ||
        !path.startsWith('/api/v1/') ||
        path.contains('..') ||
        path.contains(r'\') ||
        path.contains('?') ||
        path.contains('#')) {
      throw const SecureHttpException(
        code: SecureHttpErrorCode.invalidPath,
        message: 'Secure request path is invalid',
        safeDebugMessage: 'path rejected by secure-v2 client validation',
      );
    }
  }
}

Map<String, String> _filterHeaders(Map<String, String> headers) {
  const allowedHeaders = {
    'authorization',
    'content-type',
    'accept',
    'user-agent',
    'x-device-id',
    'x-app-version',
    'x-platform',
  };
  const forbiddenHeaders = {
    'host',
    'connection',
    'content-length',
    'transfer-encoding',
    'x-forwarded-host',
    'x-forwarded-proto',
    'x-real-ip',
    'cf-connecting-ip',
    'x-vercel-forwarded-for',
    'forwarded',
  };

  final filtered = <String, String>{};
  for (final entry in headers.entries) {
    final key = entry.key.toLowerCase().trim();
    if (forbiddenHeaders.contains(key)) {
      continue;
    }
    if (allowedHeaders.contains(key)) {
      filtered[key] = entry.value;
    }
  }
  return filtered;
}
