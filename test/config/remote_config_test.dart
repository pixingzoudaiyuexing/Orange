import 'dart:convert';

import 'package:fl_clash/config/remote_config.dart';
import 'package:flutter_test/flutter_test.dart';

const _testPublicKey = '''
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA3sYvKsy3sPL0jBfWx3dV
RNeWv3omvegNUZNgTnpRh0MmFMnjGHP++5Bci1e9AFOwLfmhFoa30r6nJlV+vtGx
MXOk0uvN4BlybTMKWtCL+OXrIXj7jBMyfBLdhfHy4VyvgMTMC0aQuEtoX5MtIaJe
LS4wKkGj2FM3JHZU3poQtOyKvN8oqUiYhZl5LguJ09YHVt0WtAIIdwEjqmqjmWh7
R3/v0nxdwDozZdOFHlZiaNN3ykcvOzQeANjbki2EvQEbwjzT6Y9vyLFwt9PqQXgH
ssgoLYepgO3Do4CF038WM7UxFzHLTIDD0bHOQ2XkHJvNEk2I3xtOAw8xSBX2ePw2
MQIDAQAB
-----END PUBLIC KEY-----
''';

const _validSignature =
    'kcH0P12ZBpq7LOLAMCDJrSNn5hNxTj42Ka4SRIT5k2oKmG4hMLTe9/5y'
    'a6vJv/8bhRmCXlgfqJlmI/Vup5Db0EPOwqCxxkp6IqLpEmlNfhjIsjFJ'
    'woDlQSJZ7Yxh/DzHi7QY1LoHUznNn1a8FwBsf8NgaB/RvriWgDspqqW'
    '4Bh5yX3JFTVQFxK88SwQwUXg0zpOuy0Yega24VDxBEhrJ275xhjCP1'
    'rZAzrmRbi1CFkLKlTZjJn+CX0mppCwZejHnseO8AszSyRwkXhuse2N'
    'nZqrwQvF2l600dpwrpM7avkc2WIhJ7LLhMYyGDHfKlXX2k6NCurdKk'
    'zA26zWHIHDNag==';

void main() {
  group('RemoteConfigService', () {
    test('uses the first successful config URL', () async {
      final cache = MemoryRemoteConfigCache();
      final service = _service(
        cache: cache,
        responses: {
          'https://cdn1.example.com/config.json': _response(_documentJson()),
        },
      );

      final result = await service.fetch(
        configUrls: ['https://cdn1.example.com/config.json'],
        defaultConfig: _document(version: 1),
      );

      expect(result.sourceUrl, 'https://cdn1.example.com/config.json');
      expect(result.config.version, 12);
      expect(cache.lastKnownGood?.version, 12);
    });

    test('tries the second URL when the first fails', () async {
      final service = _service(
        responses: {
          'https://cdn1.example.com/config.json': const RemoteConfigHttpResponse(
            statusCode: 500,
            body: '',
            headers: {},
          ),
          'https://cdn2.example.com/config.json': _response(_documentJson()),
        },
      );

      final result = await service.fetch(
        configUrls: [
          'https://cdn1.example.com/config.json',
          'https://cdn2.example.com/config.json',
        ],
        defaultConfig: _document(version: 1),
      );

      expect(result.sourceUrl, 'https://cdn2.example.com/config.json');
      expect(result.config.version, 12);
    });

    test('uses last-known-good when all remote URLs fail', () async {
      final cache = MemoryRemoteConfigCache()
        ..lastKnownGood = _document(version: 8);
      final service = _service(cache: cache, responses: {});

      final result = await service.fetch(
        configUrls: ['https://cdn1.example.com/config.json'],
        defaultConfig: _document(version: 1),
      );

      expect(result.fromCache, true);
      expect(result.config.version, 8);
    });

    test('uses bootstrap default when remote and cache are unavailable', () async {
      final service = _service(responses: {});

      final result = await service.fetch(
        configUrls: ['https://cdn1.example.com/config.json'],
        defaultConfig: _document(version: 1),
      );

      expect(result.fromDefault, true);
      expect(result.config.version, 1);
    });

    test('rejects invalid signature and does not update cache', () async {
      final cache = MemoryRemoteConfigCache();
      final service = _service(
        cache: cache,
        verifier: _FakeVerifier(isValid: false),
        responses: {
          'https://cdn1.example.com/config.json': _response(_documentJson()),
        },
      );

      final result = await service.fetch(
        configUrls: ['https://cdn1.example.com/config.json'],
        defaultConfig: _document(version: 1),
      );

      expect(result.fromDefault, true);
      expect(cache.lastKnownGood, isNull);
    });

    test('updates when remote version is greater than cached version', () async {
      final cache = MemoryRemoteConfigCache()
        ..lastKnownGood = _document(version: 10);
      final service = _service(
        cache: cache,
        responses: {
          'https://cdn1.example.com/config.json': _response(
            _documentJson(version: 12),
          ),
        },
      );

      final result = await service.fetch(
        configUrls: ['https://cdn1.example.com/config.json'],
        defaultConfig: _document(version: 1),
      );

      expect(result.config.version, 12);
      expect(cache.lastKnownGood?.version, 12);
    });

    test('rejects rollback by default', () async {
      final cache = MemoryRemoteConfigCache()
        ..lastKnownGood = _document(version: 12);
      final service = _service(
        cache: cache,
        responses: {
          'https://cdn1.example.com/config.json': _response(
            _documentJson(version: 10),
          ),
        },
      );

      final result = await service.fetch(
        configUrls: ['https://cdn1.example.com/config.json'],
        defaultConfig: _document(version: 1),
      );

      expect(result.fromCache, true);
      expect(result.config.version, 12);
    });

    test('rejects expired remote config', () async {
      final service = _service(
        responses: {
          'https://cdn1.example.com/config.json': _response(
            _documentJson(expiresAt: DateTime.utc(2026, 6, 1)),
          ),
        },
      );

      final result = await service.fetch(
        configUrls: ['https://cdn1.example.com/config.json'],
        defaultConfig: _document(version: 1),
      );

      expect(result.fromDefault, true);
    });

    test('recognizes force update and maintenance flags', () async {
      final repository = _repository(
        initialConfig: _document(
          version: 12,
          forceUpdate: true,
          maintenance: true,
          maintenanceMessage: 'maintenance window',
        ),
      );

      await repository.loadInitialConfig();

      expect(repository.getUpdateInfo().forceUpdate, true);
      expect(repository.getMaintenanceInfo().maintenance, true);
      expect(repository.getMaintenanceInfo().message, 'maintenance window');
    });

    test('rejects forbidden BACKEND_DOMAIN field', () async {
      final service = _service(
        responses: {
          'https://cdn1.example.com/config.json': _response(
            _documentJson(
              extraConfig: {'BACKEND_DOMAIN': 'https://bad.example.com'},
            ),
          ),
        },
      );

      final result = await service.fetch(
        configUrls: ['https://cdn1.example.com/config.json'],
        defaultConfig: _document(version: 1),
      );

      expect(result.fromDefault, true);
    });

    test('rejects forbidden SEC_PASSWORD and privateKey fields', () async {
      for (final field in ['SEC_PASSWORD', 'privateKey']) {
        final service = _service(
          responses: {
            'https://cdn1.example.com/config.json': _response(
              _documentJson(extraConfig: {field: 'secret'}),
            ),
          },
        );

        final result = await service.fetch(
          configUrls: ['https://cdn1.example.com/config.json'],
          defaultConfig: _document(version: 1),
        );

        expect(result.fromDefault, true);
      }
    });

    test('invalid JSON falls back without crashing', () async {
      final service = _service(
        responses: {
          'https://cdn1.example.com/config.json': const RemoteConfigHttpResponse(
            statusCode: 200,
            body: '{bad json',
            headers: {},
          ),
        },
      );

      final result = await service.fetch(
        configUrls: ['https://cdn1.example.com/config.json'],
        defaultConfig: _document(version: 1),
      );

      expect(result.fromDefault, true);
    });

    test('rejects non-HTTPS config URLs', () async {
      final service = _service(
        responses: {
          'http://cdn1.example.com/config.json': _response(_documentJson()),
        },
      );

      final result = await service.fetch(
        configUrls: ['http://cdn1.example.com/config.json'],
        defaultConfig: _document(version: 1),
      );

      expect(result.fromDefault, true);
      expect(result.fallbackError?.code, RemoteConfigErrorCode.invalidUrl);
    });

    test('uses verified baseline on HTTP 304 response', () async {
      final cache = MemoryRemoteConfigCache()
        ..lastKnownGood = _document(version: 9);
      final service = _service(
        cache: cache,
        responses: {
          'https://cdn1.example.com/config.json': const RemoteConfigHttpResponse(
            statusCode: 304,
            body: '',
            headers: {},
          ),
        },
      );

      final result = await service.fetch(
        configUrls: ['https://cdn1.example.com/config.json'],
        defaultConfig: _document(version: 1),
      );

      expect(result.fromCache, true);
      expect(result.config.version, 9);
    });

    test('preferred URL is tried first and ETag is sent', () async {
      final cache = MemoryRemoteConfigCache();
      await cache.savePreferredConfigUrl('https://cdn2.example.com/config.json');
      await cache.saveEtag('https://cdn2.example.com/config.json', '"abc"');
      final client = _FakeHttpClient({
        'https://cdn2.example.com/config.json': _response(_documentJson()),
        'https://cdn1.example.com/config.json': _response(_documentJson()),
      });
      final service = _service(cache: cache, client: client);

      await service.fetch(
        configUrls: [
          'https://cdn1.example.com/config.json',
          'https://cdn2.example.com/config.json',
        ],
        defaultConfig: _document(version: 1),
      );

      expect(client.requestedUrls.first, 'https://cdn2.example.com/config.json');
      expect(client.lastHeaders?['if-none-match'], '"abc"');
    });

    test('reports generatedAt warning without rejecting valid config', () async {
      final service = _service(
        responses: {
          'https://cdn1.example.com/config.json': _response(
            _documentJson(generatedAt: DateTime.utc(2030, 1, 1)),
          ),
        },
      );

      final result = await service.fetch(
        configUrls: ['https://cdn1.example.com/config.json'],
        defaultConfig: _document(version: 1),
      );

      expect(result.generatedAtWarning, true);
      expect(result.config.version, 12);
    });
  });

  group('ConfigSignatureVerifier', () {
    test('verifies RSA-PSS-SHA256 signature over canonical config payload', () {
      final document = _document(signature: _validSignature);
      final verifier = ConfigSignatureVerifier(_testPublicKey);

      expect(verifier.verify(document), true);
      expect(verifier.verify(document.copyWith(version: 13)), false);
      expect(verifier.verify(document.copyWith(signature: 'bad-signature')), false);
    });
  });

  group('RemoteConfigRepository', () {
    test('loads cache first and exposes config sections', () async {
      final repository = _repository(initialConfig: _document(version: 7));

      final config = await repository.loadInitialConfig();

      expect(config.version, 7);
      expect(repository.getSecurityConfig().secureProtocol, 'secure-v2');
      expect(repository.getFeatureFlags().enableNotice, true);
      expect(repository.getUpdateInfo().updateUrl, 'https://www.example.com/download');
    });

    test('reports refresh failure while keeping fallback config available', () async {
      final cache = MemoryRemoteConfigCache();
      final repository = RemoteConfigRepository(
        bootstrap: BootstrapConfig(
          configUrls: const ['https://cdn1.example.com/config.json'],
          configVerifyPublicKey: _testPublicKey,
          configVersion: 1,
          defaultConfig: _document(version: 1),
        ),
        cache: cache,
        service: _service(
          cache: cache,
          verifier: _FakeVerifier(isValid: false),
          responses: {
            'https://cdn1.example.com/config.json': _response(_documentJson()),
          },
        ),
      );

      await repository.loadInitialConfig();
      final result = await repository.refreshRemoteConfig();

      expect(result.isSuccess, false);
      expect(result.error?.code, RemoteConfigErrorCode.invalidSignature);
      expect(repository.getCurrentConfig().version, 1);
    });
  });
}

RemoteConfigService _service({
  MemoryRemoteConfigCache? cache,
  RemoteConfigHttpClient? client,
  ConfigSignatureVerifier? verifier,
  Map<String, RemoteConfigHttpResponse> responses = const {},
}) {
  final resolvedCache = cache ?? MemoryRemoteConfigCache();
  return RemoteConfigService(
    httpClient: client ?? _FakeHttpClient(responses),
    cache: resolvedCache,
    verifier: verifier ?? _FakeVerifier(),
    now: () => DateTime.utc(2026, 6, 13),
  );
}

RemoteConfigRepository _repository({RemoteConfigDocument? initialConfig}) {
  final cache = MemoryRemoteConfigCache()..lastKnownGood = initialConfig;
  return RemoteConfigRepository(
    bootstrap: BootstrapConfig(
      configUrls: const ['https://cdn1.example.com/config.json'],
      configVerifyPublicKey: _testPublicKey,
      configVersion: 1,
      defaultConfig: _document(version: 1),
    ),
    cache: cache,
    service: _service(cache: cache),
  );
}

RemoteConfigHttpResponse _response(Map<String, dynamic> json) {
  return RemoteConfigHttpResponse(
    statusCode: 200,
    body: jsonEncode(json),
    headers: const {'etag': '"abc"'},
  );
}

Map<String, dynamic> _documentJson({
  int version = 12,
  DateTime? generatedAt,
  DateTime? expiresAt,
  Map<String, dynamic>? extraConfig,
}) {
  final config = _document(
    version: version,
    generatedAt: generatedAt,
    expiresAt: expiresAt,
  ).toJson();
  if (extraConfig != null) {
    (config['config'] as Map<String, dynamic>).addAll(extraConfig);
  }
  return config;
}

RemoteConfigDocument _document({
  int version = 12,
  String signature = _validSignature,
  DateTime? generatedAt,
  DateTime? expiresAt,
  bool forceUpdate = false,
  bool maintenance = false,
  String maintenanceMessage = '',
}) {
  return RemoteConfigDocument(
    version: version,
    minClientVersion: '1.0.0',
    latestClientVersion: '1.0.5',
    forceUpdate: forceUpdate,
    maintenance: maintenance,
    maintenanceMessage: maintenanceMessage,
    generatedAt: generatedAt ?? DateTime.utc(2026, 6, 13),
    expiresAt: expiresAt ?? DateTime.utc(2026, 7, 13),
    config: const ClientConfig(
      brandName: 'BrandName',
      security: RemoteSecurityConfig(
        securityBaseUrl: 'https://security.example.com',
        backupSecurityBaseUrls: [
          'https://security-backup1.example.com',
          'https://security-backup2.example.com',
        ],
        secureProtocol: 'secure-v2',
        keyId: 'main-2026-01',
        publicKey: '''
-----BEGIN PUBLIC KEY-----
TEST_SECURE_V2_PUBLIC_KEY_ONLY
-----END PUBLIC KEY-----
''',
      ),
      urls: RemoteUrlsConfig(
        websiteUrl: 'https://www.example.com',
        supportUrl: 'https://support.example.com',
        privacyUrl: 'https://www.example.com/privacy',
        termsUrl: 'https://www.example.com/terms',
        updateUrl: 'https://www.example.com/download',
      ),
      features: RemoteFeatureFlags(
        enableRegister: true,
        enableInvite: true,
        enablePlanPurchase: true,
        enableNotice: true,
        enableAutoUpdate: true,
        enableTunMode: true,
        enableSystemProxy: true,
      ),
      platforms: {
        'windows': RemotePlatformConfig(
          downloadUrl: 'https://download.example.com/windows/latest.exe',
        ),
        'macos': RemotePlatformConfig(
          downloadUrl: 'https://download.example.com/macos/latest.dmg',
        ),
        'android': RemotePlatformConfig(
          downloadUrl: 'https://download.example.com/android/latest.apk',
        ),
        'linux': RemotePlatformConfig(
          downloadUrl: 'https://download.example.com/linux/latest.AppImage',
        ),
      },
      notice: RemoteNoticeConfig(
        title: '',
        content: '',
        level: 'info',
      ),
    ),
    signature: signature,
  );
}

class _FakeHttpClient implements RemoteConfigHttpClient {
  final Map<String, RemoteConfigHttpResponse> responses;
  final List<String> requestedUrls = [];
  Map<String, String>? lastHeaders;

  _FakeHttpClient(this.responses);

  @override
  Future<RemoteConfigHttpResponse> get(
    Uri uri, {
    required Duration timeout,
    Map<String, String>? headers,
  }) async {
    final url = uri.toString();
    requestedUrls.add(url);
    lastHeaders = headers;
    final response = responses[url];
    if (response == null) {
      throw const RemoteConfigException(
        RemoteConfigErrorCode.network,
        'network failed',
      );
    }
    return response;
  }
}

class _FakeVerifier extends ConfigSignatureVerifier {
  final bool isValid;

  _FakeVerifier({this.isValid = true}) : super(_testPublicKey);

  @override
  void verifyOrThrow(RemoteConfigDocument document) {
    if (!isValid) {
      throw const RemoteConfigException(
        RemoteConfigErrorCode.invalidSignature,
        'invalid signature',
      );
    }
  }

  @override
  bool verify(RemoteConfigDocument document) => isValid;
}
