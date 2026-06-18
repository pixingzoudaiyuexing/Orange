import 'dart:convert';

import 'package:fl_clash/xboard/config/core/config_settings.dart';
import 'package:fl_clash/xboard/config/fetchers/remote_config_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WyxV2Board production RemoteConfig source', () {
    test('treats cos as a plain HTTPS JSON source', () async {
      final manager = RemoteConfigManager.fromSettings(
        const RemoteConfigSettings(
          sources: [
            RemoteSourceConfig(
              name: 'cos',
              url: 'https://cos.example.com/config/remote_config.json?v=1',
            ),
          ],
        ),
        plainJsonHttpClient: _FakeConfigHttpClient(
          jsonEncode({
            'version': 1,
            'updated_at': '2026-06-18T00:00:00.000Z',
            'panelType': 'v2board',
            'panel_type': 'v2board',
            'backend_type': 'wyx_v2board',
            'panels': {
              'mihomo': [
                {
                  'name': 'production-wyx-v2board',
                  'description': 'Production wyx_v2board via secure-v2',
                  'url': 'https://security.example.com',
                  'panelType': 'v2board',
                  'panel_type': 'v2board',
                  'backend_type': 'wyx_v2board',
                  'metadata': {
                    'backend_type': 'wyx_v2board',
                    'secure_v2': {
                      'enabled': true,
                      'security_base_url': 'https://security.example.com',
                      'key_id': 'production-key-id',
                      'public_key':
                          '-----BEGIN PUBLIC KEY-----\nTEST_PUBLIC_KEY_ONLY\n-----END PUBLIC KEY-----',
                    },
                  },
                  'online_support': {'enabled': false},
                  'links': {'website': 'https://www.example.com'},
                },
              ],
            },
          }),
        ),
      );

      final result = await manager.fetchAllConfigs();

      expect(result.hasSuccess, true);
      expect(result.firstSuccessfulSource, 'cos');
      expect(result.firstSuccessfulData?['panelType'], 'v2board');
      expect(
        result
            .firstSuccessfulData?['panels']['mihomo'][0]['metadata']['secure_v2']['security_base_url'],
        'https://security.example.com',
      );
    });
  });
}

class _FakeConfigHttpClient implements IHttpClient {
  final String body;

  _FakeConfigHttpClient(this.body);

  @override
  Future<String?> getString(String url, {Duration? timeout}) async => body;
}
