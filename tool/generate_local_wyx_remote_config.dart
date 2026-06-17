import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final env = Platform.environment;
  final securityBaseUrl = _requiredEnv(env, 'SECURITY_BASE_URL');
  final keyId = _requiredEnv(env, 'SECURE_V2_KEY_ID');
  final publicKeyFile = _requiredEnv(env, 'SECURE_V2_PUBLIC_KEY_FILE');

  if (securityBaseUrl == null || keyId == null || publicKeyFile == null) {
    stderr.writeln('Missing required environment variables.');
    stderr.writeln('Example:');
    stderr.writeln('  export SECURITY_BASE_URL="https://security.example.com"');
    stderr.writeln('  export SECURE_V2_KEY_ID="staging-2026-01"');
    stderr.writeln(
      '  export SECURE_V2_PUBLIC_KEY_FILE="./secure-v2-public.pem"',
    );
    exitCode = 64;
    return;
  }

  final securityBaseUri = Uri.tryParse(securityBaseUrl);
  if (securityBaseUri == null ||
      securityBaseUri.scheme != 'https' ||
      securityBaseUri.host.isEmpty) {
    stderr.writeln('SECURITY_BASE_URL must be a valid HTTPS URL.');
    exitCode = 64;
    return;
  }

  final publicKey = await _readPublicKey(publicKeyFile);
  if (publicKey == null) {
    exitCode = 65;
    return;
  }

  final secureV2 = {
    'enabled': true,
    'security_base_url': securityBaseUrl,
    'key_id': keyId,
    'public_key': publicKey,
  };
  final outputDir = Directory('local_config');
  await outputDir.create(recursive: true);
  final outputFile = File('${outputDir.path}/remote_config.json');
  final now = DateTime.now().toUtc();

  final config = <String, Object?>{
    'version': 1,
    'updated_at': now.toIso8601String(),
    'panelType': 'v2board',
    'panel_type': 'v2board',
    'backend_type': 'wyx_v2board',
    'app': {'title': 'YourAppName', 'website': 'example.com'},
    'panels': {
      'mihomo': [
        {
          'name': 'local-wyx-v2board-staging',
          'description': 'Local wyx_v2board staging via secure-v2',
          'url': securityBaseUrl,
          'panelType': 'v2board',
          'panel_type': 'v2board',
          'backend_type': 'wyx_v2board',
          'secure_v2': secureV2,
          'metadata': {'backend_type': 'wyx_v2board', 'secure_v2': secureV2},
          'online_support': {'enabled': false},
          'links': {
            'website': 'https://example.com',
            'support': 'https://support.example.com',
          },
        },
      ],
    },
    'onlineSupport': <Object?>[],
    'links': {
      'website': 'https://example.com',
      'support': 'https://support.example.com',
    },
    'subscription': {'prefer_encrypt': false},
    'metadata': {
      'sources': ['local'],
      'lastUpdated': now.toIso8601String(),
      'version': 'local-1',
      'statistics': {'panels': 1},
    },
  };

  const encoder = JsonEncoder.withIndent('  ');
  await outputFile.writeAsString('${encoder.convert(config)}\n');

  stdout.writeln('Generated local RemoteConfig: ${outputFile.path}');
  stdout.writeln(
    'secure-v2 config: baseUrl=${securityBaseUri.origin}, keyId=$keyId, '
    'publicKeyLength=${publicKey.length}',
  );
}

String? _requiredEnv(Map<String, String> env, String name) {
  final value = env[name]?.trim();
  if (value == null || value.isEmpty) {
    stderr.writeln('$name is required.');
    return null;
  }
  return value;
}

Future<String?> _readPublicKey(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    stderr.writeln('SECURE_V2_PUBLIC_KEY_FILE does not exist: $path');
    return null;
  }

  final publicKey = (await file.readAsString()).trim();
  if (publicKey.contains('PRIVATE KEY')) {
    stderr.writeln('SECURE_V2_PUBLIC_KEY_FILE must not contain a private key.');
    return null;
  }
  if (!publicKey.contains('-----BEGIN PUBLIC KEY-----') ||
      !publicKey.contains('-----END PUBLIC KEY-----')) {
    stderr.writeln(
      'SECURE_V2_PUBLIC_KEY_FILE must contain an RSA PUBLIC KEY PEM.',
    );
    return null;
  }
  return publicKey;
}
