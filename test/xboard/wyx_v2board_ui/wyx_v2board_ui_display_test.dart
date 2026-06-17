import 'package:fl_clash/security/security.dart';
import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import 'package:fl_clash/xboard/features/auth/auth.dart';
import 'package:fl_clash/xboard/features/invite/providers/invite_provider.dart';
import 'package:fl_clash/xboard/features/notice/providers/notice_provider.dart';
import 'package:fl_clash/xboard/features/online_support/pages/online_support_page.dart';
import 'package:fl_clash/xboard/features/online_support/providers/chat_provider.dart';
import 'package:fl_clash/xboard/features/online_support/providers/websocket_auto_connector.dart';
import 'package:fl_clash/xboard/features/online_support/services/api_service.dart';
import 'package:fl_clash/xboard/features/online_support/services/websocket_service.dart';
import 'package:fl_clash/xboard/features/payment/widgets/plan_description_widget.dart';
import 'package:fl_clash/xboard/features/subscription/providers/xboard_subscription_provider.dart';
import 'package:fl_clash/xboard/infrastructure/infrastructure.dart';
import 'package:fl_clash/xboard/services/services.dart';
import 'package:fl_clash/xboard/features/subscription/widgets/subscription_usage_card.dart';
import 'package:fl_clash/xboard/wyx_v2board/ui/wyx_v2board_backend.dart';
import 'package:fl_clash/xboard/wyx_v2board/ui/wyx_v2board_domain_mapper.dart';
import 'package:fl_clash/xboard/wyx_v2board/ui/wyx_v2board_providers.dart';
import 'package:fl_clash/xboard/wyx_v2board/ui/wyx_v2board_ui_controller.dart';
import 'package:fl_clash/xboard/wyx_v2board/ui/wyx_v2board_ui_helpers.dart';
import 'package:fl_clash/xboard/wyx_v2board/wyx_v2board.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WyxV2Board UI display helpers', () {
    test('builds safe home display data without exposing subscribe_url', () {
      final subscription = _domainSubscription(
        subscribeUrl: 'https://security.example/sub?token=secret-token',
      );
      final user = _domainUser(banned: true);

      final display = WyxHomeDisplayData.from(
        user: user,
        subscription: subscription,
      );

      expect(display.planName, 'Pro');
      expect(display.usedBytes, 300);
      expect(display.remainingBytes, 700);
      expect(display.deviceLimitText, '3 台设备');
      expect(display.aliveIpText, '2 台在线');
      expect(display.statusText, '账号异常');
      expect(display.expiredText, '长期有效');
      expect(display.toSafeMap().toString(), isNot(contains('secret-token')));
      expect(display.toSafeMap().toString(), isNot(contains('subscribe')));
    });

    test('builds staging package data for home display', () {
      final subscription = _domainSubscription(
        subscribeUrl: 'https://security.example/sub?token=secret-token',
        planName: 'Plus 专业型月循环周期',
        transferLimit: 375809638400,
        uploadedBytes: 54438,
        downloadedBytes: 79883,
        expiredAt: DateTime.parse('2026-07-01T06:47:15.000Z'),
        aliveIp: 0,
        resetDay: 17,
      );
      final user = _domainUser(banned: false);

      final display = WyxHomeDisplayData.from(
        user: user,
        subscription: subscription,
      );

      expect(display.planName, 'Plus 专业型月循环周期');
      expect(display.totalBytes, 375809638400);
      expect(display.usedBytes, 134321);
      expect(display.remainingBytes, 375809504079);
      expect(display.totalText, '350 GB');
      expect(display.usedText, '131 KB');
      expect(display.remainingText, '350 GB');
      expect(display.expiredText, '2026-07-01');
      expect(display.aliveIpText, '0 台在线');
      expect(display.resetDayText, '每月 17 日');
      expect(display.statusText, '账号正常');
      expect(display.toSafeMap().toString(), isNot(contains('token=')));
      expect(display.toSafeMap().toString(), isNot(contains('subscribe')));
    });

    test('uses fallback plan name when plan object is absent', () {
      const subscribe = WyxSubscribeInfo(
        planId: 3,
        planName: 'Plus 专业型月循环周期',
        token: 'subscribe-token',
        upload: 54438,
        download: 79883,
        transferEnable: 375809638400,
        email: 'user@example.com',
        uuid: 'uuid-1',
        aliveIp: 0,
        subscribeUrl: 'https://security.example/sub?token=secret-token',
      );

      final subscription = WyxV2BoardDomainMapper.subscription(subscribe);
      final display = WyxHomeDisplayData.from(
        user: _domainUser(banned: false),
        subscription: subscription,
      );

      expect(subscription.planName, 'Plus 专业型月循环周期');
      expect(display.planName, isNot('暂无套餐'));
      expect(display.planName, 'Plus 专业型月循环周期');
    });

    test('maps secure and adapter errors to safe Chinese messages', () {
      expect(
        WyxV2BoardUiErrorMapper.message(
          const WyxV2BoardException(
            code: WyxV2BoardErrorCode.loginFailed,
            message: 'password=super-secret',
          ),
        ),
        '邮箱或密码错误',
      );
      expect(
        WyxV2BoardUiErrorMapper.message(
          const SecureHttpException(
            code: SecureHttpErrorCode.invalidConfig,
            message: 'missing publicKey',
            safeDebugMessage: 'publicKey missing',
          ),
        ),
        '安全配置缺少公钥，请联系客服',
      );
      expect(
        WyxV2BoardUiErrorMapper.message(
          const SecureHttpException(
            code: SecureHttpErrorCode.secureV2Error,
            message: 'SECURE_V2_PATH_NOT_ALLOWED',
            safeDebugMessage: 'SECURE_V2_PATH_NOT_ALLOWED',
          ),
        ),
        '请求被安全网关拦截，请联系客服',
      );
    });

    test('builds node summaries without raw server details', () {
      const node = WyxNodeInfo(
        id: 1,
        name: 'Hong Kong 01',
        type: 'vless',
        rate: 1.5,
        country: 'HK',
        tags: ['streaming', 'premium'],
        raw: {'server': 'hidden-node.example.com'},
      );

      final summary = WyxNodeDisplayData.from(node);

      expect(summary.name, 'Hong Kong 01');
      expect(summary.type, 'vless');
      expect(summary.rate, '1.5x');
      expect(summary.region, 'HK');
      expect(summary.toString(), isNot(contains('hidden-node.example.com')));
    });
  });

  group('PlanDescriptionWidget', () {
    test('parses JSON feature strings and hides unsupported items', () {
      const content =
          '[{"feature":"每月 350GB 流量","support":true},'
          '{"feature":"不支持项目","support":false},'
          '{"feature":"高速节点 + 隧道节点","support":true}]';

      final display = PlanDescriptionDisplayData.from(content: content);

      expect(display.items, contains('每月 350GB 流量'));
      expect(display.items, contains('高速节点 + 隧道节点'));
      expect(display.items, isNot(contains('不支持项目')));
      expect(display.text, isNull);
      expect(display.items.join('\n'), isNot(contains('"feature"')));
      expect(display.items.join('\n'), isNot(contains('[{')));
    });

    test('keeps plain text descriptions readable', () {
      final display = PlanDescriptionDisplayData.from(
        content: '适合日常使用，支持高速线路。',
      );

      expect(display.items, isEmpty);
      expect(display.text, '适合日常使用，支持高速线路。');
    });

    test('empty description with no features is safe', () {
      final display = PlanDescriptionDisplayData.from(content: '');

      expect(display.isEmpty, true);
      expect(display.items, isEmpty);
      expect(display.text, '');
    });

    testWidgets('renders feature list without raw JSON text', (tester) async {
      const content =
          '[{"feature":"协议：Vless, AnyTLS","support":true},'
          '{"feature":"带宽：无限制","support":true}]';

      await tester.pumpWidget(
        _localizedApp(
          const Scaffold(body: PlanDescriptionWidget(content: content)),
        ),
      );

      expect(find.text('协议：Vless, AnyTLS'), findsOneWidget);
      expect(find.text('带宽：无限制'), findsOneWidget);
      expect(find.textContaining('"feature"'), findsNothing);
      expect(find.textContaining('[{'), findsNothing);
    });
  });

  group('SubscriptionUsageCard', () {
    testWidgets(
      'shows wyx package when profile subscription is not imported yet',
      (tester) async {
        final subscription = _domainSubscription(
          planName: 'Plus 专业型月循环周期',
          transferLimit: 375809638400,
          uploadedBytes: 54438,
          downloadedBytes: 79883,
          expiredAt: DateTime.parse('2026-07-01T06:47:15.000Z'),
          aliveIp: 0,
          resetDay: 17,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              xboardUserProvider.overrideWith(() {
                return _StaticAuthNotifier(
                  UserAuthState(
                    isAuthenticated: true,
                    isInitialized: true,
                    email: 'user@example.com',
                    userInfo: _domainUser(banned: false),
                    subscriptionInfo: subscription,
                  ),
                );
              }),
            ],
            child: MaterialApp(
              locale: const Locale('zh', 'CN'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.delegate.supportedLocales,
              home: Scaffold(
                body: SubscriptionUsageCard(
                  userInfo: _domainUser(banned: false),
                  subscriptionInfo: subscription,
                  profileSubscriptionInfo: null,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Plus 专业型月循环周期'), findsOneWidget);
        expect(find.text('无可用套餐'), findsNothing);
        expect(find.text('请购买套餐后使用'), findsNothing);
        expect(find.textContaining('350 GB'), findsWidgets);
        expect(find.textContaining('剩余 350 GB'), findsOneWidget);
        expect(find.textContaining('token='), findsNothing);
        expect(find.textContaining('subscribe'), findsNothing);
      },
    );
  });

  group('Online support disabled state', () {
    test('disabled services do not connect or enter loading state', () {
      final container = ProviderContainer(
        overrides: [
          apiServiceProvider.overrideWithValue(
            CustomerSupportApiService.disabled(),
          ),
          wsServiceProvider.overrideWithValue(
            CustomerSupportWebSocketService.disabled(),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(webSocketAutoConnectorProvider);

      expect(container.read(wsServiceProvider).isEnabled, false);
      expect(container.read(wsServiceProvider).isConnected, false);
      expect(container.read(chatProvider).isLoading, false);
      expect(container.read(chatProvider).isError, false);
    });

    testWidgets('disabled page shows friendly prompt', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiServiceProvider.overrideWithValue(
              CustomerSupportApiService.disabled(),
            ),
            wsServiceProvider.overrideWithValue(
              CustomerSupportWebSocketService.disabled(),
            ),
          ],
          child: _localizedApp(const OnlineSupportPage()),
        ),
      );
      await tester.pump();

      expect(find.text('在线客服暂未开放'), findsOneWidget);
      expect(find.text('请通过官网、Telegram 或工单联系客服'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('WyxV2Board UI providers', () {
    test('login success publishes home state and raw auth session', () async {
      final adapter = _FakeWyxAdapter();
      final storage = _MemoryStorage();
      final container = _container(adapter: adapter, storage: storage);
      addTearDown(container.dispose);

      final success = await container
          .read(xboardUserProvider.notifier)
          .login('user@example.com', 'secret-password');

      final authState = container.read(xboardUserProvider);
      final session =
          (await container.read(storageServiceProvider).getWyxAuthSession())
              .dataOrNull;

      expect(success, true);
      expect(authState.isAuthenticated, true);
      expect(authState.email, 'user@example.com');
      expect(authState.userInfo?.email, 'user@example.com');
      expect(authState.subscriptionInfo?.planName, 'Pro');
      expect(session?['authData'], 'raw-auth-data');
      expect(session?['token'], 'subscribe-token');
      expect(session.toString(), isNot(contains('secret-password')));
      expect(adapter.lastPassword, 'secret-password');
    });

    test('login failure exposes safe Chinese error', () async {
      final adapter = _FakeWyxAdapter(
        loginError: const WyxV2BoardException(
          code: WyxV2BoardErrorCode.loginFailed,
          message: 'password=secret-token',
        ),
      );
      final container = _container(adapter: adapter);
      addTearDown(container.dispose);

      final success = await container
          .read(xboardUserProvider.notifier)
          .login('user@example.com', 'bad-password');

      final authState = container.read(xboardUserProvider);
      expect(success, false);
      expect(authState.isAuthenticated, false);
      expect(authState.errorMessage, '邮箱或密码错误');
      expect(authState.errorMessage, isNot(contains('bad-password')));
      expect(authState.errorMessage, isNot(contains('secret-token')));
    });

    test(
      'loads plans, notices, nodes, and keeps notice failure isolated',
      () async {
        final adapter = _FakeWyxAdapter();
        final container = _container(adapter: adapter);
        addTearDown(container.dispose);

        await container
            .read(xboardUserProvider.notifier)
            .login('user@example.com', 'secret-password');
        await container.read(xboardSubscriptionProvider.notifier).loadPlans();
        await container.read(noticeProvider.notifier).fetchNotices();
        final nodes = await container
            .read(wyxV2BoardUiControllerProvider.notifier)
            .loadNodes();

        expect(container.read(xboardSubscriptionProvider).single.name, 'Pro');
        expect(
          container.read(noticeProvider).visibleNotices.single.title,
          '公告',
        );
        expect(nodes.single.name, 'Hong Kong 01');

        adapter.noticeError = const WyxV2BoardException(
          code: WyxV2BoardErrorCode.backendError,
          message: 'maintenance',
        );
        await container.read(noticeProvider.notifier).fetchNotices();

        expect(
          container.read(xboardUserProvider).userInfo?.email,
          'user@example.com',
        );
        expect(container.read(noticeProvider).error, contains('maintenance'));
      },
    );

    test(
      'invite info uses wyx GET adapter and maps 405 to friendly text',
      () async {
        final adapter = _FakeWyxAdapter();
        final container = _container(adapter: adapter);
        addTearDown(container.dispose);

        await container.read(inviteProvider.notifier).loadInviteData();

        expect(adapter.inviteCalls, 1);
        expect(
          container.read(inviteProvider).inviteData?.codes.single.code,
          'INVITE',
        );
        expect(container.read(inviteProvider).errorMessage, isNull);

        adapter.inviteError = const WyxV2BoardException(
          code: WyxV2BoardErrorCode.backendError,
          statusCode: 405,
          message:
              'The POST method is not supported for this route. Supported methods: GET, HEAD.',
        );

        await container.read(inviteProvider.notifier).loadInviteData();

        final error = container.read(inviteProvider).errorMessage;
        expect(error, '邀请码加载失败，请稍后重试');
        expect(error, isNot(contains('POST')));
        expect(error, isNot(contains('method')));
      },
    );

    test(
      'keeps wyx node fallback after refresh failure and clears on logout',
      () async {
        final adapter = _FakeWyxAdapter(
          nodes: List.generate(
            27,
            (index) => _wyxNode(
              id: index + 1,
              name: index == 0 ? '日本｜隧道C' : '节点 ${index + 1}',
            ),
          ),
        );
        final container = _container(adapter: adapter);
        addTearDown(container.dispose);

        await container
            .read(xboardUserProvider.notifier)
            .login('user@example.com', 'secret-password');
        final loadedNodes = await container
            .read(wyxV2BoardUiControllerProvider.notifier)
            .loadNodes();

        expect(loadedNodes, hasLength(27));
        expect(loadedNodes.first.name, '日本｜隧道C');

        adapter.nodeError = const WyxV2BoardException(
          code: WyxV2BoardErrorCode.backendError,
          message: 'temporary failure',
        );

        await expectLater(
          container.read(wyxV2BoardUiControllerProvider.notifier).loadNodes(),
          throwsA(isA<WyxV2BoardException>()),
        );

        final stateAfterFailure = container.read(
          wyxV2BoardUiControllerProvider,
        );
        expect(stateAfterFailure.nodes, hasLength(27));
        expect(stateAfterFailure.nodes.first.name, '日本｜隧道C');
        expect(
          stateAfterFailure.nodes.first.toString(),
          isNot(contains('hidden-node.example.com')),
        );

        await container.read(xboardUserProvider.notifier).logout();

        expect(container.read(wyxV2BoardUiControllerProvider).nodes, isEmpty);
      },
    );

    test('logout clears auth session and published home state', () async {
      final adapter = _FakeWyxAdapter();
      final storage = _MemoryStorage();
      final container = _container(adapter: adapter, storage: storage);
      addTearDown(container.dispose);

      await container
          .read(xboardUserProvider.notifier)
          .login('user@example.com', 'secret-password');
      await container.read(xboardUserProvider.notifier).logout();

      expect(adapter.isLoggedIn, false);
      expect(container.read(xboardUserProvider).isAuthenticated, false);
      expect(container.read(userInfoProvider), isNull);
      expect(container.read(subscriptionInfoProvider), isNull);
      expect(
        (await container.read(storageServiceProvider).getWyxAuthSession())
            .dataOrNull,
        isNull,
      );
      expect(
        (await container.read(storageServiceProvider).getDomainUser())
            .dataOrNull,
        isNull,
      );
      expect(
        (await container.read(storageServiceProvider).getDomainSubscription())
            .dataOrNull,
        isNull,
      );
    });
  });
}

ProviderContainer _container({
  _FakeWyxAdapter? adapter,
  _MemoryStorage? storage,
}) {
  return ProviderContainer(
    overrides: [
      isWyxV2BoardBackendProvider.overrideWith((ref) async => true),
      storageServiceProvider.overrideWithValue(
        XBoardStorageService(storage ?? _MemoryStorage()),
      ),
      wyxV2BoardAdapterProvider.overrideWith(
        (ref) async => adapter ?? _FakeWyxAdapter(),
      ),
    ],
  );
}

class _FakeWyxAdapter implements WyxV2BoardAdapterApi {
  WyxAuthSession? _session;
  Object? loginError;
  Object? noticeError;
  Object? inviteError;
  Object? nodeError;
  List<WyxNodeInfo>? nodes;
  int inviteCalls = 0;
  String? lastPassword;

  _FakeWyxAdapter({this.loginError, this.nodes});

  @override
  WyxAuthSession? get currentSession => _session;

  @override
  bool get isLoggedIn => _session?.authData.isNotEmpty == true;

  @override
  void restoreSession(WyxAuthSession session) {
    _session = session;
  }

  @override
  Future<WyxLoginResult> login(String email, String password) async {
    lastPassword = password;
    final error = loginError;
    if (error != null) {
      throw error;
    }
    _session = const WyxAuthSession(
      token: 'subscribe-token',
      authData: 'raw-auth-data',
      isAdmin: false,
    );
    return WyxLoginResult(session: _session!);
  }

  @override
  void logout() {
    _session = null;
  }

  @override
  Future<WyxUserInfo> getUserInfo() async {
    return const WyxUserInfo(
      email: 'user@example.com',
      transferEnable: 1000,
      deviceLimit: 3,
      banned: false,
      balance: 0,
      commissionBalance: 0,
      uuid: 'uuid-1',
    );
  }

  @override
  Future<WyxSubscribeInfo> getSubscribeInfo() async {
    return const WyxSubscribeInfo(
      planId: 3,
      token: 'subscribe-token',
      upload: 100,
      download: 200,
      transferEnable: 1000,
      deviceLimit: 3,
      email: 'user@example.com',
      uuid: 'uuid-1',
      aliveIp: 2,
      subscribeUrl: '',
      resetDay: 15,
      plan: WyxPlanInfo(
        id: 3,
        name: 'Pro',
        transferEnable: 1000,
        show: true,
        renew: true,
        features: [],
      ),
    );
  }

  @override
  Future<String?> getSubscribeUrl() async {
    return (await getSubscribeInfo()).subscribeUrl;
  }

  @override
  Future<List<WyxNodeInfo>> getNodeList() async {
    final error = nodeError;
    if (error != null) {
      throw error;
    }
    return nodes ?? [_wyxNode(id: 1, name: 'Hong Kong 01')];
  }

  @override
  Future<List<WyxPlanInfo>> getPlanList() async {
    return const [
      WyxPlanInfo(
        id: 3,
        groupId: 1,
        transferEnable: 1000,
        name: 'Pro',
        deviceLimit: 3,
        show: true,
        renew: true,
        features: [],
        monthPrice: 990,
      ),
    ];
  }

  @override
  Future<List<WyxNotice>> getNoticeList() async {
    final error = noticeError;
    if (error != null) {
      throw error;
    }
    return [
      WyxNotice(
        id: 1,
        title: '公告',
        content: '维护通知',
        show: true,
        tags: const [],
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    ];
  }

  @override
  Future<List<WyxOrderInfo>> getOrderList() async => const [];

  @override
  Future<WyxInviteInfo> getInviteInfo() async {
    inviteCalls += 1;
    final error = inviteError;
    if (error != null) {
      throw error;
    }
    return const WyxInviteInfo(
      code: 'INVITE',
      invitedCount: 0,
      commissionBalance: 0,
      safeData: {'source': 'test'},
    );
  }

  @override
  Future<WyxOrderInfo> getOrderDetail(String orderId) async {
    return const WyxOrderInfo();
  }

  @override
  Future<String> getPaymentRedirectUrl(String orderId) async {
    return '';
  }

  @override
  Future<Object?> checkCoupon(String code) async {
    return null;
  }

  @override
  Future<Object?> getClientAppConfig() async {
    return null;
  }

  @override
  Future<Object?> getClientAppVersion() async {
    return null;
  }
}

Widget _localizedApp(Widget child) {
  return MaterialApp(
    locale: const Locale('zh', 'CN'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.delegate.supportedLocales,
    home: child,
  );
}

WyxNodeInfo _wyxNode({required int id, required String name}) {
  return WyxNodeInfo(
    id: id,
    name: name,
    type: 'vless',
    rate: 1.5,
    country: 'JP',
    tags: const ['premium'],
    raw: {'server': 'hidden-node.example.com'},
  );
}

class _MemoryStorage implements StorageInterface {
  final Map<String, Object?> _values = {};

  @override
  Future<Result<bool>> clear() async {
    _values.clear();
    return Result.success(true);
  }

  @override
  Future<Result<bool>> containsKey(String key) async {
    return Result.success(_values.containsKey(key));
  }

  @override
  Future<Result<bool?>> getBool(String key) async {
    return Result.success(_values[key] as bool?);
  }

  @override
  Future<Result<double?>> getDouble(String key) async {
    return Result.success(_values[key] as double?);
  }

  @override
  Future<Result<int?>> getInt(String key) async {
    return Result.success(_values[key] as int?);
  }

  @override
  Future<Result<Set<String>>> getKeys() async {
    return Result.success(_values.keys.toSet());
  }

  @override
  Future<Result<String?>> getString(String key) async {
    return Result.success(_values[key] as String?);
  }

  @override
  Future<Result<List<String>?>> getStringList(String key) async {
    return Result.success(_values[key] as List<String>?);
  }

  @override
  Future<Result<bool>> remove(String key) async {
    _values.remove(key);
    return Result.success(true);
  }

  @override
  Future<Result<bool>> setBool(String key, bool value) async {
    _values[key] = value;
    return Result.success(true);
  }

  @override
  Future<Result<bool>> setDouble(String key, double value) async {
    _values[key] = value;
    return Result.success(true);
  }

  @override
  Future<Result<bool>> setInt(String key, int value) async {
    _values[key] = value;
    return Result.success(true);
  }

  @override
  Future<Result<bool>> setString(String key, String value) async {
    _values[key] = value;
    return Result.success(true);
  }

  @override
  Future<Result<bool>> setStringList(String key, List<String> value) async {
    _values[key] = value;
    return Result.success(true);
  }
}

class _StaticAuthNotifier extends XBoardUserAuthNotifier {
  final UserAuthState _initialState;

  _StaticAuthNotifier(this._initialState);

  @override
  UserAuthState build() => _initialState;
}

DomainUser _domainUser({
  bool banned = false,
  int transferLimit = 1000,
  int uploadedBytes = 100,
  int downloadedBytes = 200,
}) {
  return DomainUser(
    email: 'user@example.com',
    uuid: 'uuid-1',
    avatarUrl: '',
    transferLimit: transferLimit,
    uploadedBytes: uploadedBytes,
    downloadedBytes: downloadedBytes,
    balanceInCents: 0,
    commissionBalanceInCents: 0,
    banned: banned,
    metadata: const {'device_limit': 3, 'alive_ip': 2},
  );
}

DomainSubscription _domainSubscription({
  String subscribeUrl = '',
  String planName = 'Pro',
  int transferLimit = 1000,
  int uploadedBytes = 100,
  int downloadedBytes = 200,
  DateTime? expiredAt,
  int aliveIp = 2,
  int resetDay = 15,
}) {
  return DomainSubscription(
    subscribeUrl: subscribeUrl,
    email: 'user@example.com',
    uuid: 'uuid-1',
    planId: 3,
    planName: planName,
    token: 'subscribe-token',
    transferLimit: transferLimit,
    uploadedBytes: uploadedBytes,
    downloadedBytes: downloadedBytes,
    deviceLimit: 3,
    expiredAt: expiredAt,
    metadata: const {'allow_new_period': 'month'},
  ).copyWith(
    metadata: {
      'alive_ip': aliveIp,
      'reset_day': resetDay,
      'allow_new_period': 'month',
    },
  );
}
