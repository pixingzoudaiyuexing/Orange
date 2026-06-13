import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config_cache.dart';
import 'config_errors.dart';
import 'config_models.dart';
import 'config_signature_verifier.dart';

abstract interface class RemoteConfigHttpClient {
  Future<RemoteConfigHttpResponse> get(
    Uri uri, {
    required Duration timeout,
    Map<String, String>? headers,
  });
}

class RemoteConfigHttpResponse {
  final int statusCode;
  final String body;
  final Map<String, String> headers;

  const RemoteConfigHttpResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
  });
}

class SafeRemoteConfigHttpClient implements RemoteConfigHttpClient {
  final http.Client _client;

  SafeRemoteConfigHttpClient({http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<RemoteConfigHttpResponse> get(
    Uri uri, {
    required Duration timeout,
    Map<String, String>? headers,
  }) async {
    final response = await _client.get(uri, headers: headers).timeout(timeout);
    return RemoteConfigHttpResponse(
      statusCode: response.statusCode,
      body: response.body,
      headers: response.headers,
    );
  }

  void close() {
    _client.close();
  }
}

class RemoteConfigFetchResult {
  final RemoteConfigDocument config;
  final String sourceUrl;
  final bool fromCache;
  final bool fromDefault;
  final RemoteConfigException? fallbackError;
  final bool generatedAtWarning;

  const RemoteConfigFetchResult({
    required this.config,
    required this.sourceUrl,
    this.fromCache = false,
    this.fromDefault = false,
    this.fallbackError,
    this.generatedAtWarning = false,
  });
}

class RemoteConfigService {
  final RemoteConfigHttpClient httpClient;
  final RemoteConfigCache cache;
  final ConfigSignatureVerifier verifier;
  final Duration timeout;
  final int preferredFailureLimit;
  final DateTime Function() now;

  const RemoteConfigService({
    required this.httpClient,
    required this.cache,
    required this.verifier,
    this.timeout = const Duration(seconds: 5),
    this.preferredFailureLimit = 2,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  Future<RemoteConfigFetchResult> fetch({
    required List<String> configUrls,
    required RemoteConfigDocument defaultConfig,
    RemoteConfigDocument? currentConfig,
  }) async {
    final urls = await _orderedUrls(configUrls);
    final baseline = currentConfig ?? await cache.readLastKnownGood();
    RemoteConfigException? lastError;

    for (final url in urls) {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme || uri.scheme != 'https') {
        lastError = const RemoteConfigException(
          RemoteConfigErrorCode.invalidUrl,
          'Remote config URL must be HTTPS',
        );
        continue;
      }

      try {
        final etag = await cache.readEtag(url);
        final response = await httpClient.get(
          uri,
          timeout: timeout,
          headers: etag == null ? null : {'if-none-match': etag},
        );
        if (response.statusCode == 304 && baseline != null) {
          await cache.savePreferredConfigUrl(url);
          return RemoteConfigFetchResult(
            config: baseline,
            sourceUrl: url,
            fromCache: true,
          );
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw RemoteConfigException(
            RemoteConfigErrorCode.network,
            'Remote config request failed with HTTP ${response.statusCode}',
          );
        }

        final document = _parseDocument(response.body);
        verifier.verifyOrThrow(document);
        _validateDocument(document, baseline);
        await cache.saveLastKnownGood(document);
        await cache.savePreferredConfigUrl(url);
        final responseEtag = response.headers['etag'];
        if (responseEtag != null && responseEtag.isNotEmpty) {
          await cache.saveEtag(url, responseEtag);
        }
        return RemoteConfigFetchResult(
          config: document,
          sourceUrl: url,
          generatedAtWarning: _hasGeneratedAtWarning(document),
        );
      } on RemoteConfigException catch (error) {
        lastError = error;
        await _recordPreferredFailure(url);
      } catch (_) {
        lastError = const RemoteConfigException(
          RemoteConfigErrorCode.network,
          'Remote config request failed',
        );
        await _recordPreferredFailure(url);
      }
    }

    final cached = await cache.readLastKnownGood();
    if (cached != null) {
      return RemoteConfigFetchResult(
        config: cached,
        sourceUrl: 'last-known-good',
        fromCache: true,
        fallbackError: lastError,
      );
    }

    return RemoteConfigFetchResult(
      config: defaultConfig,
      sourceUrl: 'bootstrap-default',
      fromDefault: true,
      fallbackError: lastError,
    );
  }

  RemoteConfigDocument _parseDocument(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return RemoteConfigDocument.fromJson(json);
    } catch (error) {
      if (error is RemoteConfigException) {
        rethrow;
      }
      throw const RemoteConfigException(
        RemoteConfigErrorCode.invalidJson,
        'Remote config JSON is invalid',
      );
    }
  }

  void _validateDocument(
    RemoteConfigDocument document,
    RemoteConfigDocument? baseline,
  ) {
    document.validateSafeFields();

    if (!document.expiresAt.isAfter(now().toUtc())) {
      throw const RemoteConfigException(
        RemoteConfigErrorCode.expired,
        'Remote config has expired',
      );
    }

    if (baseline != null &&
        document.version < baseline.version &&
        !document.allowRollback) {
      throw const RemoteConfigException(
        RemoteConfigErrorCode.rollbackRejected,
        'Remote config rollback is rejected',
      );
    }
  }

  bool _hasGeneratedAtWarning(RemoteConfigDocument document) {
    final current = now().toUtc();
    return document.generatedAt.isAfter(current.add(const Duration(days: 1))) ||
        document.generatedAt.isBefore(DateTime.utc(2020));
  }

  Future<List<String>> _orderedUrls(List<String> configUrls) async {
    final ordered = <String>[];
    final preferred = await cache.readPreferredConfigUrl();
    final preferredFailures = await cache.readPreferredConfigUrlFailures();
    if (preferred != null &&
        configUrls.contains(preferred) &&
        preferredFailures < preferredFailureLimit) {
      ordered.add(preferred);
    }
    ordered.addAll(configUrls.where((url) => !ordered.contains(url)));
    return ordered;
  }

  Future<void> _recordPreferredFailure(String url) async {
    final preferred = await cache.readPreferredConfigUrl();
    if (preferred != url) {
      return;
    }
    await cache.incrementPreferredConfigUrlFailures();
    final failures = await cache.readPreferredConfigUrlFailures();
    if (failures >= preferredFailureLimit) {
      await cache.clearPreferredConfigUrl();
    }
  }
}
