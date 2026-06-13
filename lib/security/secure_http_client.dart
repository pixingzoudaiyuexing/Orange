import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'secure_config.dart';
import 'secure_crypto_service.dart';
import 'secure_http_errors.dart';
import 'secure_request.dart';
import 'secure_response.dart';

abstract interface class SecureTransport {
  Future<SecureTransportResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
    required Duration timeout,
  });
}

class SecureTransportResponse {
  final int statusCode;
  final String body;
  final Map<String, String> headers;

  const SecureTransportResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
  });
}

class DefaultSecureTransport implements SecureTransport {
  final http.Client _client;

  DefaultSecureTransport({http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<SecureTransportResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
    required Duration timeout,
  }) async {
    final response =
        await _client.post(uri, headers: headers, body: body).timeout(timeout);
    return SecureTransportResponse(
      statusCode: response.statusCode,
      body: response.body,
      headers: response.headers,
    );
  }

  void close() {
    _client.close();
  }
}

class SecureHttpClient {
  final SecureConfig config;
  final SecureTransport transport;
  final SecureCryptoService cryptoService;
  final String Function() requestIdFactory;
  final DateTime Function() now;

  String? _preferredBaseUrl;

  SecureHttpClient({
    required this.config,
    SecureTransport? transport,
    SecureCryptoService? cryptoService,
    String Function()? requestIdFactory,
    DateTime Function()? now,
  })  : transport = transport ?? DefaultSecureTransport(),
        cryptoService = cryptoService ?? SecureCryptoService(),
        requestIdFactory = requestIdFactory ?? (() => const Uuid().v4()),
        now = now ?? DateTime.now;

  Future<SecureResponse> get(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
  }) {
    return request(method: 'GET', path: path, query: query, headers: headers);
  }

  Future<SecureResponse> post(
    String path, {
    Object? body,
    Map<String, String>? query,
    Map<String, String>? headers,
  }) {
    return request(
      method: 'POST',
      path: path,
      body: body,
      query: query,
      headers: headers,
    );
  }

  Future<SecureResponse> put(
    String path, {
    Object? body,
    Map<String, String>? query,
    Map<String, String>? headers,
  }) {
    return request(
      method: 'PUT',
      path: path,
      body: body,
      query: query,
      headers: headers,
    );
  }

  Future<SecureResponse> delete(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
  }) {
    return request(
      method: 'DELETE',
      path: path,
      query: query,
      headers: headers,
    );
  }

  Future<SecureResponse> request({
    required String method,
    required String path,
    Object? body,
    Map<String, String>? query,
    Map<String, String>? headers,
  }) async {
    config.validate();
    final secureRequest = SecureRequest(
      method: method,
      path: path,
      body: body,
      query: query,
      headers: headers,
    );
    final requestId = requestIdFactory();
    final timestamp = now().toUtc().millisecondsSinceEpoch.toString();
    final encryptedPayload = cryptoService.encryptRequest(
      payload: secureRequest.toPayloadJson(),
      publicKeyPem: config.publicKey,
    );
    final wireBody = jsonEncode({
      'keyId': config.keyId,
      'encryptedKey': encryptedPayload.encryptedKey,
      'iv': encryptedPayload.iv,
      'ciphertext': encryptedPayload.ciphertext,
    });
    final wireHeaders = {
      'content-type': 'application/json',
      'x-secure-version': '2',
      'x-key-id': config.keyId,
      'x-request-id': requestId,
      'x-timestamp': timestamp,
      'x-app-version': config.appVersion,
      'x-platform': config.platform,
    };

    SecureHttpException? lastError;
    for (final baseUrl in config.orderedBaseUrls(_preferredBaseUrl)) {
      final proxyUri = _secureProxyUri(baseUrl);
      try {
        final response = await transport.post(
          proxyUri,
          headers: wireHeaders,
          body: wireBody,
          timeout: config.timeout,
        );
        if (response.statusCode != 200) {
          throw _httpStatusError(response, requestId);
        }
        final secureResponse = _decodeWireResponse(
          response.body,
          requestId: requestId,
          responseKey: encryptedPayload.key,
        );
        _preferredBaseUrl = baseUrl;
        return secureResponse;
      } on SecureHttpException catch (error) {
        lastError = error;
        if (!_shouldTryNextBaseUrl(error)) {
          rethrow;
        }
      } catch (error) {
        lastError = SecureHttpException(
          code: SecureHttpErrorCode.network,
          message: 'Secure request failed',
          requestId: requestId,
          safeDebugMessage: error.runtimeType.toString(),
        );
      }
    }

    throw lastError ??
        SecureHttpException(
          code: SecureHttpErrorCode.network,
          message: 'All security middleware endpoints failed',
          requestId: requestId,
        );
  }

  SecureResponse _decodeWireResponse(
    String body, {
    required String requestId,
    required Uint8List responseKey,
  }) {
    try {
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) {
        throw const FormatException('wire response is not an object');
      }
      final responseRequestId = json['requestId'];
      if (responseRequestId != requestId) {
        throw SecureHttpException(
          code: SecureHttpErrorCode.requestIdMismatch,
          message: 'Secure response requestId mismatch',
          requestId: requestId,
          safeDebugMessage: 'response requestId does not match request',
        );
      }
      final iv = json['iv'];
      final ciphertext = json['ciphertext'];
      if (iv is! String || ciphertext is! String) {
        throw SecureHttpException(
          code: SecureHttpErrorCode.invalidResponse,
          message: 'Secure response is missing encrypted fields',
          requestId: requestId,
          safeDebugMessage: 'missing iv or ciphertext',
        );
      }
      final decrypted = cryptoService.decryptResponse(
        iv: iv,
        ciphertext: ciphertext,
        key: responseKey,
      );
      return SecureResponse.fromJson(decrypted, requestId: requestId);
    } on SecureHttpException {
      rethrow;
    } catch (error) {
      throw SecureHttpException(
        code: SecureHttpErrorCode.invalidResponse,
        message: 'Secure response format is invalid',
        requestId: requestId,
        safeDebugMessage: error.runtimeType.toString(),
      );
    }
  }

  SecureHttpException _httpStatusError(
    SecureTransportResponse response,
    String requestId,
  ) {
    try {
      final json = jsonDecode(response.body);
      if (json is Map<String, dynamic> && json['code'] is String) {
        return SecureHttpException(
          code: SecureHttpErrorCode.secureV2Error,
          message: 'Secure middleware rejected the request',
          requestId: json['requestId'] as String? ?? requestId,
          statusCode: response.statusCode,
          safeDebugMessage: json['code'] as String,
        );
      }
    } catch (_) {
      // Fall through to generic HTTP status error.
    }
    return SecureHttpException(
      code: SecureHttpErrorCode.httpStatus,
      message: 'Secure middleware returned non-200 status',
      requestId: requestId,
      statusCode: response.statusCode,
      safeDebugMessage: 'status=${response.statusCode}',
    );
  }

  bool _shouldTryNextBaseUrl(SecureHttpException error) {
    return error.code == SecureHttpErrorCode.network ||
        (error.code == SecureHttpErrorCode.httpStatus &&
            (error.statusCode == null || error.statusCode! >= 500));
  }

  Uri _secureProxyUri(String baseUrl) {
    final base = Uri.parse(baseUrl);
    final normalizedPath = base.path.endsWith('/')
        ? '${base.path}secure-v2/proxy'
        : '${base.path}/secure-v2/proxy';
    return Uri(
      scheme: base.scheme,
      userInfo: base.userInfo,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: normalizedPath,
    );
  }
}
