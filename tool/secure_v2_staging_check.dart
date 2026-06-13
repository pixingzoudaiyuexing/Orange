import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/security/security.dart';

Future<void> main() async {
  final env = Platform.environment;
  final missing = [
    'SECURITY_BASE_URL',
    'SECURE_V2_KEY_ID',
    'SECURE_V2_PUBLIC_KEY',
    'TEST_USER_EMAIL',
    'TEST_USER_PASSWORD',
  ].where((key) => (env[key] ?? '').trim().isEmpty).toList();

  if (missing.isNotEmpty) {
    stderr.writeln(
      'Missing required environment variables: ${missing.join(', ')}',
    );
    stderr.writeln('Example:');
    stderr.writeln(
      '  export SECURITY_BASE_URL=https://anquan.mengtuyun.online',
    );
    stderr.writeln('  export SECURE_V2_KEY_ID=staging-2026-01');
    stderr.writeln(
      r'  export SECURE_V2_PUBLIC_KEY="$(cat secure-v2-public.pem)"',
    );
    stderr.writeln('  export TEST_USER_EMAIL="user@example.com"');
    stderr.writeln('  export TEST_USER_PASSWORD="replace-me"');
    exitCode = 64;
    return;
  }

  const masker = SensitiveLogMasker();
  final client = SecureHttpClient(
    config: SecureConfig(
      securityBaseUrl: env['SECURITY_BASE_URL']!.trim(),
      backupSecurityBaseUrls: _splitUrls(env['BACKUP_SECURITY_BASE_URLS']),
      keyId: env['SECURE_V2_KEY_ID']!.trim(),
      publicKey: env['SECURE_V2_PUBLIC_KEY']!.trim(),
      appVersion: env['APP_VERSION']?.trim().isNotEmpty == true
          ? env['APP_VERSION']!.trim()
          : 'staging-check',
      platform: env['APP_PLATFORM']?.trim().isNotEmpty == true
          ? env['APP_PLATFORM']!.trim()
          : 'macos',
    ),
  );

  try {
    _runLocalNegativeChecks();

    final login = await client.post(
      '/api/v1/passport/auth/login',
      body: {
        'email': env['TEST_USER_EMAIL']!.trim(),
        'password': env['TEST_USER_PASSWORD']!,
      },
    );
    _printSafe('login', login, masker);

    final authData = _extractAuthData(login.body);
    if (authData == null || authData.isEmpty) {
      throw StateError('Login response did not contain data.auth_data');
    }

    final authHeaders = {'authorization': _authorizationFromAuthData(authData)};
    final userInfo = await client.get(
      '/api/v1/user/info',
      headers: authHeaders,
    );
    _printSafe('user-info', userInfo, masker);

    final subscribe = await client.get(
      '/api/v1/user/getSubscribe',
      headers: authHeaders,
    );
    _printSafe('subscribe', subscribe, masker);

    stdout.writeln('secure-v2 staging check completed');
  } on Object catch (error) {
    stderr.writeln(
      'secure-v2 staging check failed: ${masker.maskText('$error')}',
    );
    exitCode = 1;
  }
}

List<String> _splitUrls(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const [];
  }
  return raw
      .split(',')
      .map((url) => url.trim())
      .where((url) => url.isNotEmpty)
      .toList(growable: false);
}

void _runLocalNegativeChecks() {
  final unsafePaths = [
    'https://backend.example.com/api/v1/user/info',
    '/api/v1/user/../admin',
    r'/api/v1/user\info',
    '/api/v1/user/info?x=1',
  ];
  for (final path in unsafePaths) {
    var rejected = false;
    try {
      SecureRequest(method: 'GET', path: path);
    } on SecureHttpException {
      rejected = true;
    }
    if (!rejected) {
      throw StateError('Unsafe path was not rejected: $path');
    }
  }
}

void _printSafe(
  String label,
  SecureResponse response,
  SensitiveLogMasker masker,
) {
  final safeBody = masker.mask(response.body);
  stdout.writeln(
    jsonEncode({
      'step': label,
      'status': response.status,
      'requestId': response.requestId,
      'body': safeBody,
    }),
  );
}

String? _extractAuthData(Object? body) {
  if (body is! Map) {
    return null;
  }

  final data = body['data'];
  if (data is Map) {
    final authData = data['auth_data'];
    if (authData is String && authData.trim().isNotEmpty) {
      return authData.trim();
    }
  }

  final authData = body['auth_data'];
  if (authData is String && authData.trim().isNotEmpty) {
    return authData.trim();
  }

  return null;
}

String _authorizationFromAuthData(String authData) {
  final value = authData.trim();
  // wyx2685/v2board decrypts auth_data directly from Authorization.
  return value;
}
