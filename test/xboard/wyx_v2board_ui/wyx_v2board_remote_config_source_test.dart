import 'dart:convert';

import 'package:fl_clash/xboard/config/core/config_settings.dart';
import 'package:fl_clash/xboard/config/fetchers/remote_config_manager.dart';
import 'package:fl_clash/xboard/config/parsers/configuration_parser.dart';
import 'package:fl_clash/xboard/config/services/online_support_service.dart';
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
            'subscription': {
              'fetch_mode': 'secure_proxy',
              'provider': 'mihomo',
            },
          }),
        ),
      );

      final result = await manager.fetchAllConfigs();

      expect(result.hasSuccess, true);
      expect(result.firstSuccessfulSource, 'cos');
      expect(result.firstSuccessfulData?['panelType'], 'v2board');
      expect(
        result.firstSuccessfulData?['subscription']['fetch_mode'],
        'secure_proxy',
      );
      expect(
        result
            .firstSuccessfulData?['panels']['mihomo'][0]['metadata']['secure_v2']['security_base_url'],
        'https://security.example.com',
      );
    });

    test('parses clean secure_proxy subscription structure', () {
      final parser = ConfigurationParser();

      final parsed = parser.parseFromJson({
        'version': 1,
        'panelType': 'v2board',
        'panels': {
          'mihomo': [
            {
              'name': 'production-wyx-v2board',
              'description': 'Production wyx_v2board via secure-v2',
              'url': 'https://security.example.com',
            },
          ],
        },
        'subscription': {'fetch_mode': 'secure_proxy', 'provider': 'mihomo'},
      }, 'mihomo');

      expect(parsed.subscription?.usesSecureProxy, true);
      expect(parsed.subscription?.fetchMode, 'secure_proxy');
      expect(parsed.subscription?.provider, 'mihomo');
      expect(parsed.subscription?.urls, isEmpty);
      expect(parsed.toString(), contains('subscription: 0'));
    });

    test(
      'parses recommended Crisp online_support structure from panel item',
      () {
        final parser = ConfigurationParser();

        final parsed = parser.parseFromJson({
          'version': 1,
          'panelType': 'v2board',
          'panels': {
            'mihomo': [
              {
                'name': 'production-wyx-v2board',
                'description': 'Production wyx_v2board via secure-v2',
                'url': 'https://security.example.com',
                'panelType': 'v2board',
                'panel_type': 'v2board',
                'backend_type': 'wyx_v2board',
                'online_support': {
                  'enabled': true,
                  'provider': 'crisp',
                  'crisp': {'website_id': 'TEST_CRISP_WEBSITE_ID'},
                  'fallback_url': 'https://www.example.com/support',
                },
              },
            ],
          },
        }, 'mihomo');

        expect(parsed.onlineSupport, hasLength(1));
        expect(parsed.onlineSupport.first.enabled, true);
        expect(parsed.onlineSupport.first.provider, 'crisp');
        expect(
          parsed.onlineSupport.first.crispWebsiteId,
          'TEST_CRISP_WEBSITE_ID',
        );
        expect(
          parsed.onlineSupport.first.fallbackUrl,
          'https://www.example.com/support',
        );

        final supportService = OnlineSupportService(parsed.onlineSupport);
        expect(supportService.getCrispWebsiteId(), 'TEST_CRISP_WEBSITE_ID');
        expect(
          supportService.getCrispFallbackUrl(),
          'https://www.example.com/support',
        );
        expect(supportService.getApiBaseUrl(), isNull);
        expect(supportService.getWebSocketBaseUrl(), isNull);
      },
    );

    test('does not support legacy flat top-level Crisp structure', () {
      final parser = ConfigurationParser();

      final parsed = parser.parseFromJson({
        'version': 1,
        'panelType': 'v2board',
        'panels': {
          'mihomo': [
            {
              'name': 'production-wyx-v2board',
              'description': 'Production wyx_v2board via secure-v2',
              'url': 'https://security.example.com',
            },
          ],
        },
        'online_support': {
          'enabled': true,
          'type': 'crisp',
          'website_id': 'TEST_CRISP_WEBSITE_ID',
          'fallback_url': 'https://www.example.com/support',
        },
      }, 'mihomo');

      expect(parsed.onlineSupport, isEmpty);
    });

    test('does not support legacy flat panel Crisp structure', () {
      final parser = ConfigurationParser();

      final parsed = parser.parseFromJson({
        'version': 1,
        'panelType': 'v2board',
        'panels': {
          'mihomo': [
            {
              'name': 'production-wyx-v2board',
              'description': 'Production wyx_v2board via secure-v2',
              'url': 'https://security.example.com',
              'online_support': {
                'enabled': true,
                'provider': 'crisp',
                'website_id': 'TEST_CRISP_WEBSITE_ID',
                'fallback_url': 'https://www.example.com/support',
              },
            },
          ],
        },
      }, 'mihomo');

      expect(parsed.onlineSupport, isEmpty);
      final supportService = OnlineSupportService(parsed.onlineSupport);
      expect(supportService.getCrispWebsiteId(), isNull);
      expect(supportService.getApiBaseUrl(), isNull);
      expect(supportService.getWebSocketBaseUrl(), isNull);
    });

    test('ignores Crisp config when website_id is missing', () {
      final parser = ConfigurationParser();

      final parsed = parser.parseFromJson({
        'version': 1,
        'panelType': 'v2board',
        'panels': {
          'mihomo': [
            {
              'name': 'production-wyx-v2board',
              'description': 'Production wyx_v2board via secure-v2',
              'url': 'https://security.example.com',
              'online_support': {
                'enabled': true,
                'provider': 'crisp',
                'crisp': <String, dynamic>{},
                'fallback_url': 'https://www.example.com/support',
              },
            },
          ],
        },
      }, 'mihomo');

      expect(parsed.onlineSupport, isEmpty);
    });
  });
}

class _FakeConfigHttpClient implements IHttpClient {
  final String body;

  _FakeConfigHttpClient(this.body);

  @override
  Future<String?> getString(String url, {Duration? timeout}) async => body;
}
