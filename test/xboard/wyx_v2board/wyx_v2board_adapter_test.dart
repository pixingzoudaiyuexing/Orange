import 'package:fl_clash/security/security.dart';
import 'package:fl_clash/xboard/wyx_v2board/wyx_v2board.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WyxV2BoardAdapter', () {
    test('login parses token and auth_data, then saves authData', () async {
      final client = _FakeWyxSecureClient({
        _key('POST', WyxV2BoardApi.login): _ok({
          'data': {
            'token': 'subscribe-token',
            'auth_data': 'jwt-auth-data',
            'is_admin': 0,
          },
        }),
      });
      final adapter = WyxV2BoardAdapter(client: client);

      final result = await adapter.login('user@example.com', 'secret');

      expect(result.session.token, 'subscribe-token');
      expect(result.session.authData, 'jwt-auth-data');
      expect(result.session.isAdmin, false);
      expect(adapter.currentSession?.authData, 'jwt-auth-data');
      expect(client.calls.single.body, {
        'email': 'user@example.com',
        'password': 'secret',
      });
    });

    test(
      'user-info uses raw auth_data as Authorization without Bearer',
      () async {
        final client = _FakeWyxSecureClient({
          _key('POST', WyxV2BoardApi.login): _loginOk(),
          _key('GET', WyxV2BoardApi.userInfo): _ok({
            'data': {
              'email': 'user@example.com',
              'transfer_enable': 1024,
              'banned': 0,
              'balance': 0,
              'commission_balance': 0,
              'uuid': 'uuid-1',
            },
          }),
        });
        final adapter = WyxV2BoardAdapter(client: client);

        await adapter.login('user@example.com', 'secret');
        final user = await adapter.getUserInfo();

        final userInfoCall = client.calls.last;
        expect(userInfoCall.path, WyxV2BoardApi.userInfo);
        expect(userInfoCall.headers['authorization'], 'jwt-auth-data');
        expect(
          userInfoCall.headers['authorization'],
          isNot(startsWith('Bearer ')),
        );
        expect(user.email, 'user@example.com');
        expect(user.transferEnable, 1024);
      },
    );

    test(
      'getSubscribeInfo parses subscribe_url and plan JSON content',
      () async {
        final client = _FakeWyxSecureClient({
          _key('POST', WyxV2BoardApi.login): _loginOk(),
          _key('GET', WyxV2BoardApi.subscribeInfo): _ok({
            'data': {
              'plan_id': 3,
              'token': 'subscribe-token',
              'expired_at': 1782888435,
              'u': 100,
              'd': 200,
              'transfer_enable': 1000,
              'email': 'user@example.com',
              'subscribe_url':
                  'https://example.com/api/v1/client/subscribe?token=abc',
              'plan': {
                'id': 3,
                'name': 'Plus',
                'transfer_enable': 350,
                'show': 1,
                'renew': 1,
                'content': '[{"feature":"350GB traffic","support":true}]',
              },
            },
          }),
        });
        final adapter = WyxV2BoardAdapter(client: client);

        await adapter.login('user@example.com', 'secret');
        final subscribe = await adapter.getSubscribeInfo();

        expect(subscribe.subscribeUrl, contains('/api/v1/client/subscribe'));
        expect(subscribe.token, 'subscribe-token');
        expect(subscribe.usedTraffic, 300);
        expect(subscribe.plan?.name, 'Plus');
        expect(subscribe.plan?.features.single.feature, '350GB traffic');
        expect(subscribe.toString(), isNot(contains('subscribe-token')));
        expect(subscribe.toString(), isNot(contains('token=abc')));
      },
    );

    test(
      'getMihomoSubscriptionProfile requests middleware proxy without subscribe_url',
      () async {
        const yaml = '''
proxies:
  - name: hk-01
    type: vless
proxy-groups:
  - name: CloudGap
    type: select
    proxies:
      - hk-01
rules:
  - MATCH,CloudGap
''';
        final client = _FakeWyxSecureClient({
          _key('POST', WyxV2BoardApi.login): _loginOk(),
          _key('POST', WyxV2BoardApi.subscriptionMihomo): _ok({
            'data': {
              'provider': 'mihomo',
              'format': 'yaml',
              'content': yaml,
              'content_type': 'text/yaml',
              'ua_used': 'Clash.Meta',
              'source': 'middleware_subscription_proxy',
            },
          }),
        });
        final adapter = WyxV2BoardAdapter(client: client);

        await adapter.login('user@example.com', 'secret');
        final profile = await adapter.getMihomoSubscriptionProfile();

        final call = client.calls.last;
        expect(call.method, 'POST');
        expect(call.path, WyxV2BoardApi.subscriptionMihomo);
        expect(call.headers['authorization'], 'jwt-auth-data');
        expect(call.body, {
          'backend_type': 'wyx_v2board',
          'provider': 'mihomo',
          'format': 'clash',
          'user_agent_preference': ['Clash.Meta', 'mihomo', 'ClashforWindows'],
        });
        expect(call.toString(), isNot(contains('subscribe_url')));
        expect(call.toString(), isNot(contains('token=')));
        expect(profile.content, yaml);
        expect(profile.uaUsed, 'Clash.Meta');
        expect(profile.toString(), contains('contentLength:'));
        expect(profile.toString(), isNot(contains(yaml)));
      },
    );

    test('getMihomoSubscriptionProfile rejects empty content', () async {
      final client = _FakeWyxSecureClient({
        _key('POST', WyxV2BoardApi.login): _loginOk(),
        _key('POST', WyxV2BoardApi.subscriptionMihomo): _ok({
          'data': {'provider': 'mihomo', 'format': 'yaml', 'content': ''},
        }),
      });
      final adapter = WyxV2BoardAdapter(client: client);

      await adapter.login('user@example.com', 'secret');

      await expectLater(
        adapter.getMihomoSubscriptionProfile(),
        throwsA(
          isA<WyxV2BoardException>().having(
            (error) => error.code,
            'code',
            WyxV2BoardErrorCode.invalidResponse,
          ),
        ),
      );
    });

    test('plan.content parse failures do not crash', () async {
      final client = _FakeWyxSecureClient({
        _key('POST', WyxV2BoardApi.login): _loginOk(),
        _key('GET', WyxV2BoardApi.planList): _ok({
          'data': [
            {
              'id': 1,
              'name': 'Basic',
              'transfer_enable': 100,
              'show': 1,
              'renew': 1,
              'content': '{not-json',
            },
          ],
        }),
      });
      final adapter = WyxV2BoardAdapter(client: client);

      await adapter.login('user@example.com', 'secret');
      final plans = await adapter.getPlanList();

      expect(plans, hasLength(1));
      expect(plans.single.name, 'Basic');
      expect(plans.single.features, isEmpty);
    });

    test(
      'getNodeList parses node arrays without logging raw server details',
      () async {
        final client = _FakeWyxSecureClient({
          _key('POST', WyxV2BoardApi.login): _loginOk(),
          _key('GET', WyxV2BoardApi.nodeList): _ok({
            'data': [
              {
                'id': 9,
                'name': 'Hong Kong 01',
                'type': 'vless',
                'rate': 1.5,
                'server': 'node.example.com',
              },
            ],
          }),
        });
        final adapter = WyxV2BoardAdapter(client: client);

        await adapter.login('user@example.com', 'secret');
        final nodes = await adapter.getNodeList();

        expect(nodes.single.id, 9);
        expect(nodes.single.type, 'vless');
        expect(nodes.single.rate, 1.5);
        expect(nodes.single.raw['server'], 'node.example.com');
        expect(nodes.single.toString(), isNot(contains('node.example.com')));
      },
    );

    test('getNoticeList parses notices', () async {
      final client = _FakeWyxSecureClient({
        _key('POST', WyxV2BoardApi.login): _loginOk(),
        _key('GET', WyxV2BoardApi.noticeList): _ok({
          'data': [
            {
              'id': 1,
              'title': 'Maintenance',
              'content': 'Window',
              'show': 1,
              'tags': ['ops'],
            },
          ],
        }),
      });
      final adapter = WyxV2BoardAdapter(client: client);

      await adapter.login('user@example.com', 'secret');
      final notices = await adapter.getNoticeList();

      expect(notices.single.title, 'Maintenance');
      expect(notices.single.show, true);
      expect(notices.single.tags, ['ops']);
    });

    test('getInviteInfo uses GET for wyx invite route', () async {
      final client = _FakeWyxSecureClient({
        _key('POST', WyxV2BoardApi.login): _loginOk(),
        _key('GET', WyxV2BoardApi.inviteInfo): _ok({
          'data': {
            'code': 'INVITE',
            'invited_count': 0,
            'commission_balance': 0,
          },
        }),
      });
      final adapter = WyxV2BoardAdapter(client: client);

      await adapter.login('user@example.com', 'secret');
      final invite = await adapter.getInviteInfo();

      final inviteCall = client.calls.last;
      expect(inviteCall.method, 'GET');
      expect(inviteCall.path, WyxV2BoardApi.inviteInfo);
      expect(invite.code, 'INVITE');
    });

    test('getOrderList parses orders from paginated data', () async {
      final client = _FakeWyxSecureClient({
        _key('POST', WyxV2BoardApi.login): _loginOk(),
        _key('GET', WyxV2BoardApi.orderList): _ok({
          'data': {
            'data': [
              {
                'trade_no': 'trade-1',
                'plan_id': 3,
                'period': 'month_price',
                'status': 0,
                'total_amount': 2990,
                'plan': {'name': 'Plus'},
              },
            ],
          },
        }),
      });
      final adapter = WyxV2BoardAdapter(client: client);

      await adapter.login('user@example.com', 'secret');
      final orders = await adapter.getOrderList();

      expect(orders.single.tradeNo, 'trade-1');
      expect(orders.single.planName, 'Plus');
      expect(orders.single.totalAmount, 2990);
    });

    test('403 becomes unauthenticated error', () async {
      final client = _FakeWyxSecureClient({
        _key('POST', WyxV2BoardApi.login): _loginOk(),
        _key('GET', WyxV2BoardApi.userInfo): const SecureResponse(
          status: 403,
          headers: {},
          body: {'message': '未登录或登陆已过期'},
          requestId: 'request-403',
        ),
      });
      final adapter = WyxV2BoardAdapter(client: client);

      await adapter.login('user@example.com', 'secret');

      await expectLater(
        adapter.getUserInfo(),
        throwsA(
          isA<WyxV2BoardException>()
              .having(
                (error) => error.code,
                'code',
                WyxV2BoardErrorCode.unauthenticated,
              )
              .having((error) => error.requestId, 'requestId', 'request-403'),
        ),
      );
    });

    test('SensitiveLogMasker masks adapter sensitive fields', () {
      const masker = SensitiveLogMasker();
      final masked =
          masker.mask({
                'token': 'subscribe-token',
                'auth_data': 'jwt-auth-data',
                'authorization': 'jwt-auth-data',
                'subscribe_url': 'https://example.com/sub?token=abc',
                'password': 'secret',
                'email': 'user@example.com',
              })
              as Map;

      expect(masked['token'], isNot('subscribe-token'));
      expect(masked['auth_data'], isNot('jwt-auth-data'));
      expect(masked['authorization'], isNot('jwt-auth-data'));
      expect(masked['subscribe_url'], isNot(contains('token=abc')));
      expect(masked['password'], isNot('secret'));
      expect(masked['email'], 'u***@example.com');
    });
  });
}

String _key(String method, String path) => '$method $path';

SecureResponse _loginOk() {
  return _ok({
    'data': {
      'token': 'subscribe-token',
      'auth_data': 'jwt-auth-data',
      'is_admin': 0,
    },
  });
}

SecureResponse _ok(Object? body) {
  return SecureResponse(
    status: 200,
    headers: const {},
    body: body,
    requestId: 'request-ok',
  );
}

class _FakeWyxSecureClient implements WyxV2BoardSecureClient {
  final Map<String, SecureResponse> responses;
  final List<_RecordedCall> calls = [];

  _FakeWyxSecureClient(this.responses);

  @override
  Future<SecureResponse> get(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
  }) async {
    calls.add(
      _RecordedCall(
        method: 'GET',
        path: path,
        query: query ?? const {},
        headers: headers ?? const {},
      ),
    );
    return responses[_key('GET', path)] ?? _missing(path);
  }

  @override
  Future<SecureResponse> post(
    String path, {
    Object? body,
    Map<String, String>? query,
    Map<String, String>? headers,
  }) async {
    calls.add(
      _RecordedCall(
        method: 'POST',
        path: path,
        body: body,
        query: query ?? const {},
        headers: headers ?? const {},
      ),
    );
    return responses[_key('POST', path)] ?? _missing(path);
  }

  SecureResponse _missing(String path) {
    return SecureResponse(
      status: 404,
      headers: const {},
      body: {'message': 'missing fake response for $path'},
      requestId: 'missing',
    );
  }
}

class _RecordedCall {
  final String method;
  final String path;
  final Object? body;
  final Map<String, String> query;
  final Map<String, String> headers;

  const _RecordedCall({
    required this.method,
    required this.path,
    this.body,
    required this.query,
    required this.headers,
  });

  @override
  String toString() {
    return '_RecordedCall(method: $method, path: $path, '
        'headers: [MASKED], query: $query, body: $body)';
  }
}
