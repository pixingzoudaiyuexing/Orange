import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart' hide Result;
import 'package:fl_clash/providers/providers.dart';
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
import 'package:fl_clash/xboard/features/profile/profile.dart';
import 'package:fl_clash/xboard/features/latency/services/auto_latency_service.dart';
import 'package:fl_clash/xboard/features/shared/widgets/node_selector_bar.dart';
import 'package:fl_clash/xboard/features/subscription/services/subscription_downloader.dart';
import 'package:fl_clash/xboard/features/subscription/providers/xboard_subscription_provider.dart';
import 'package:fl_clash/xboard/infrastructure/infrastructure.dart';
import 'package:fl_clash/xboard/services/services.dart';
import 'package:fl_clash/xboard/features/subscription/widgets/subscription_usage_card.dart';
import 'package:fl_clash/xboard/wyx_v2board/ui/wyx_v2board_backend.dart';
import 'package:fl_clash/xboard/wyx_v2board/ui/wyx_v2board_domain_mapper.dart';
import 'package:fl_clash/xboard/wyx_v2board/ui/wyx_v2board_providers.dart';
import 'package:fl_clash/xboard/wyx_v2board/ui/wyx_v2board_ui_controller.dart';
import 'package:fl_clash/xboard/wyx_v2board/ui/wyx_v2board_ui_helpers.dart';
import 'package:fl_clash/xboard/wyx_v2board/ui/wyx_v2board_ui_state.dart';
import 'package:fl_clash/xboard/wyx_v2board/wyx_v2board.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/controller.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String fixtureSubscribeUrl() => Uri.https('security.example', '/sub', {
    'token': 'fixture-subscribe-token',
  }).toString();

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

    test(
      'login imports wyx subscription as non-persistent profile source',
      () async {
        final subscribeUrl = fixtureSubscribeUrl();
        final adapter = _FakeWyxAdapter(subscribeUrl: subscribeUrl);
        final storage = _MemoryStorage();
        final importService = _FakeProfileImportService();
        final container = _container(
          adapter: adapter,
          storage: storage,
          importService: importService,
        );
        addTearDown(container.dispose);

        final success = await container
            .read(xboardUserProvider.notifier)
            .login('user@example.com', 'secret-password');
        await _waitFor(() => importService.calls.isNotEmpty);

        final call = importService.calls.single;
        final authState = container.read(xboardUserProvider);
        final storedSubscription =
            (await container
                    .read(storageServiceProvider)
                    .getDomainSubscription())
                .dataOrNull;
        final importState = container.read(profileImportProvider);

        expect(success, true);
        expect(call.url, subscribeUrl);
        expect(call.persistUrl, false);
        expect(call.source, wyxV2BoardProfileSource);
        expect(call.allowEncryptedService, false);
        expect(importService.applyProfileCalled, true);
        expect(importState.currentUrl, isEmpty);
        expect(importState.lastResult?.profile?.url, isEmpty);
        expect(importState.lastResult?.profile?.label, wyxV2BoardProfileLabel);
        expect(authState.subscriptionInfo?.subscribeUrl, isEmpty);
        expect(authState.subscriptionInfo?.token, isNull);
        expect(storedSubscription?.subscribeUrl, isEmpty);
        expect(storedSubscription?.token, isNull);
        expect(
          authState.subscriptionInfo.toString(),
          isNot(contains('token=')),
        );
        expect(
          authState.subscriptionInfo.toString(),
          isNot(contains('fixture-subscribe-token')),
        );
      },
    );

    test(
      'wyx subscription profile import failure does not fail login',
      () async {
        final subscribeUrl = fixtureSubscribeUrl();
        final adapter = _FakeWyxAdapter(subscribeUrl: subscribeUrl);
        final importService = _FakeProfileImportService(shouldFail: true);
        final container = _container(
          adapter: adapter,
          importService: importService,
        );
        addTearDown(container.dispose);

        final success = await container
            .read(xboardUserProvider.notifier)
            .login('user@example.com', 'secret-password');
        await _waitFor(() => importService.calls.isNotEmpty);

        expect(success, true);
        expect(container.read(xboardUserProvider).isAuthenticated, true);
        expect(
          container.read(xboardUserProvider).subscriptionInfo?.planName,
          'Pro',
        );
        expect(
          container.read(profileImportProvider).status,
          ImportStatus.failed,
        );
        expect(
          container.read(profileImportProvider).message,
          isNot(contains('fixture-subscribe-token')),
        );
      },
    );

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

    test(
      'loadNodes while unauthenticated does not call node endpoint',
      () async {
        final adapter = _FakeWyxAdapter();
        final container = _container(adapter: adapter);
        addTearDown(container.dispose);

        final nodes = await container
            .read(wyxV2BoardUiControllerProvider.notifier)
            .loadNodes();

        expect(nodes, isEmpty);
        expect(adapter.nodeCalls, 0);
        expect(
          container.read(wyxV2BoardUiControllerProvider).nodesLoaded,
          true,
        );
        expect(
          container.read(wyxV2BoardUiControllerProvider).errorMessage,
          isNull,
        );
      },
    );

    test(
      'restored session imports profile when wyx profile or groups are missing',
      () async {
        final adapter = _FakeWyxAdapter(subscribeUrl: fixtureSubscribeUrl());
        final storage = _MemoryStorage();
        final importService = _FakeProfileImportService();
        final env = _installProfileImportTestGlobalState(
          profiles: const [],
          currentProfileId: null,
          groups: const [],
        );
        addTearDown(env.restore);
        final container = _container(
          adapter: adapter,
          storage: storage,
          importService: importService,
        );
        addTearDown(container.dispose);
        await container
            .read(storageServiceProvider)
            .saveWyxAuthSession(
              authData: 'raw-auth-data',
              token: 'subscribe-token',
              isAdmin: false,
            );
        await container
            .read(storageServiceProvider)
            .saveUserEmail('user@example.com');

        final restored = await container
            .read(wyxV2BoardUiControllerProvider.notifier)
            .restoreSession();
        await _waitFor(() => importService.calls.isNotEmpty);

        expect(restored, true);
        expect(importService.calls.single.persistUrl, false);
        expect(importService.calls.single.source, wyxV2BoardProfileSource);
        expect(importService.calls.single.url, startsWith('https://'));
        expect(
          importService.calls.single.toString(),
          isNot(contains('fixture-subscribe-token')),
        );
      },
    );

    test(
      'restored session does not import when wyx profile and groups are ready',
      () async {
        final adapter = _FakeWyxAdapter(subscribeUrl: fixtureSubscribeUrl());
        final storage = _MemoryStorage();
        final importService = _FakeProfileImportService();
        const profile = Profile(
          id: 'wyx-profile',
          label: wyxV2BoardProfileLabel,
          url: '',
          autoUpdateDuration: Duration(hours: 24),
        );
        final env = _installProfileImportTestGlobalState(
          profiles: const [profile],
          currentProfileId: profile.id,
          groups: const [
            Group(
              type: GroupType.Selector,
              name: 'Proxy',
              now: '真实 Clash 节点',
              all: [Proxy(name: '真实 Clash 节点', type: 'VLESS')],
            ),
          ],
        );
        addTearDown(env.restore);
        final container = _container(
          adapter: adapter,
          storage: storage,
          importService: importService,
        );
        addTearDown(container.dispose);
        await container
            .read(storageServiceProvider)
            .saveWyxAuthSession(
              authData: 'raw-auth-data',
              token: 'subscribe-token',
              isAdmin: false,
            );

        final restored = await container
            .read(wyxV2BoardUiControllerProvider.notifier)
            .restoreSession();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(restored, true);
        expect(importService.calls, isEmpty);
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

  group('Wyx subscription profile import', () {
    test('normalizes missing proxy-group references before apply', () {
      const content = '''
proxies:
  - name: "日本｜隧道C"
    type: vless
    server: hidden.example.com
    port: 443
proxy-groups:
  - name: CloudGap
    type: select
    proxies:
      - 自动选择
      - DIRECT
rules:
  - MATCH,CloudGap
''';

      final normalized = normalizeSubscriptionConfig(content);

      expect(normalized.proxyCount, 1);
      expect(normalized.proxyGroupCount, 2);
      expect(normalized.proxyProviderCount, 0);
      expect(normalized.hasUsableNodeSource, true);
      expect(normalized.repairedGroups, ['自动选择']);
      expect(normalized.content, contains('name: "自动选择"'));
      expect(normalized.content, contains('type: url-test'));
      expect(
        normalized.content,
        contains('http://www.gstatic.com/generate_204'),
      );
      expect(normalized.content, contains('interval: 300'));
      expect(normalized.content, contains('"日本｜隧道C"'));
      expect(normalized.content, isNot(contains('token=')));
    });

    test(
      'supports proxy-providers without inline proxies and keeps use refs',
      () {
        const content = '''
proxy-providers:
  airport-provider:
    type: http
    url: https://example.invalid/sub
    path: ./providers/airport.yaml
    interval: 3600
proxy-groups:
  - name: CloudGap
    type: select
    use:
      - airport-provider
rules:
  - MATCH,CloudGap
''';

        final normalized = normalizeSubscriptionConfig(content);

        expect(normalized.proxyCount, 0);
        expect(normalized.proxyProviderCount, 1);
        expect(normalized.proxyGroupCount, 1);
        expect(normalized.ruleProviderCount, 0);
        expect(normalized.providerNames, ['airport-provider']);
        expect(normalized.groupNames, ['CloudGap']);
        expect(normalized.hasUseReferences, true);
        expect(normalized.hasUsableNodeSource, true);
        expect(normalized.repairedGroups, isEmpty);
        expect(normalized.content, contains('use:'));
        expect(normalized.content, contains('airport-provider'));
      },
    );

    test('wyx downloader uses Clash and Mihomo User-Agent fallback list', () {
      expect(
        SubscriptionDownloader.wyxV2BoardOptions
            .map((option) => option.userAgent)
            .toList(),
        ['Clash.Meta', 'Mihomo', 'ClashforWindows/0.20.39'],
      );
    });

    test('v2ray base64 content is not treated as Clash YAML', () {
      const base64Content =
          'dm1lc3M6Ly9leUpoWkdRaU9pSm9hV1JrWlc0dVpYaGhiWEJzWlM1amIyMGlMQ0p3'
          'YjNKMElqb2lORFF6SWl3aWFXUWlPaUp6WldOeVpYUWlmUT09';

      final normalized = normalizeSubscriptionConfig(base64Content);
      final summary = SubscriptionContentSummary.from(base64Content);

      expect(normalized.hasUsableNodeSource, false);
      expect(summary.hasBase64LikeContent, true);
      expect(summary.topLevelKeys, isEmpty);
    });

    test('URI list content is not treated as Clash YAML', () {
      const content = '''
vless://redacted@example.invalid:443?security=tls#node
trojan://redacted@example.invalid:443#node
''';

      final normalized = normalizeSubscriptionConfig(content);
      final summary = SubscriptionContentSummary.from(content);

      expect(normalized.hasUsableNodeSource, false);
      expect(summary.protocolCounts['vless'], 1);
      expect(summary.protocolCounts['trojan'], 1);
    });

    test(
      'creates missing auto group with provider use when proxies are provider based',
      () {
        const content = '''
proxy-providers:
  airport-provider:
    type: http
    url: https://example.invalid/sub
    path: ./providers/airport.yaml
    interval: 3600
proxy-groups:
  - name: CloudGap
    type: select
    proxies:
      - 自动选择
      - DIRECT
    use:
      - airport-provider
rules:
  - MATCH,CloudGap
''';

        final normalized = normalizeSubscriptionConfig(content);

        expect(normalized.proxyCount, 0);
        expect(normalized.proxyProviderCount, 1);
        expect(normalized.proxyGroupCount, 2);
        expect(normalized.hasUseReferences, true);
        expect(normalized.hasUsableNodeSource, true);
        expect(normalized.repairedGroups, ['自动选择']);
        expect(normalized.content, contains('name: "自动选择"'));
        expect(normalized.content, contains('type: url-test'));
        expect(normalized.content, contains('use:'));
        expect(normalized.content, contains('airport-provider'));
        expect(normalized.content, isNot(contains('proxies: []')));
      },
    );

    test(
      'reports no usable node source only when proxies and providers empty',
      () {
        const content = '''
proxy-groups:
  - name: CloudGap
    type: select
    proxies:
      - DIRECT
rules:
  - MATCH,CloudGap
''';

        final normalized = normalizeSubscriptionConfig(content);

        expect(normalized.proxyCount, 0);
        expect(normalized.proxyProviderCount, 0);
        expect(normalized.proxyGroupCount, 1);
        expect(normalized.hasUsableNodeSource, false);
      },
    );

    test(
      'apply failure returns failure and keeps previous profile state',
      () async {
        const previous = Profile(
          id: 'old-profile',
          label: 'old profile',
          autoUpdateDuration: Duration(hours: 24),
        );
        const downloaded = Profile(
          id: 'new-wyx-profile',
          label: wyxV2BoardProfileLabel,
          url: '',
          autoUpdateDuration: Duration(hours: 24),
        );
        final env = _installProfileImportTestGlobalState(
          profiles: [previous],
          currentProfileId: previous.id,
          groups: [
            const Group(
              type: GroupType.Selector,
              name: 'Proxy',
              now: '旧节点',
              all: [Proxy(name: '旧节点', type: 'VLESS')],
            ),
          ],
        );
        addTearDown(env.restore);
        final cleaned = <String>[];
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final service = _profileImportServiceForTest(
          container,
          downloader:
              (
                String url, {
                required bool persistUrl,
                String? source,
                required bool allowEncryptedService,
              }) async {
                return downloaded;
              },
          applyRunner: () async {
            throw Exception(
              "proxy group[0]: CloudGap: '自动选择' not found; token=secret",
            );
          },
          cleaner: cleaned.add,
        );

        final result = await service.importSubscription(
          fixtureSubscribeUrl(),
          persistUrl: false,
          source: wyxV2BoardProfileSource,
          allowEncryptedService: false,
        );

        expect(result.isSuccess, false);
        expect(result.errorMessage, isNot(contains('fixture-subscribe-token')));
        expect(result.errorMessage, isNot(contains('token=secret')));
        expect(globalState.config.currentProfileId, previous.id);
        expect(globalState.config.profiles, [previous]);
        expect(globalState.appState.groups.single.now, '旧节点');
        expect(cleaned, [downloaded.id]);
      },
    );

    test(
      'apply success switches current profile before cleaning old wyx profile',
      () async {
        const oldWyx = Profile(
          id: 'old-wyx-profile',
          label: wyxV2BoardProfileLabel,
          url: '',
          autoUpdateDuration: Duration(hours: 24),
        );
        const downloaded = Profile(
          id: 'new-wyx-profile',
          label: wyxV2BoardProfileLabel,
          url: '',
          autoUpdateDuration: Duration(hours: 24),
        );
        final env = _installProfileImportTestGlobalState(
          profiles: [oldWyx],
          currentProfileId: oldWyx.id,
        );
        addTearDown(env.restore);
        final cleaned = <String>[];
        final applyCurrentIds = <String?>[];
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final service = _profileImportServiceForTest(
          container,
          downloader:
              (
                String url, {
                required bool persistUrl,
                String? source,
                required bool allowEncryptedService,
              }) async {
                return downloaded;
              },
          applyRunner: () async {
            applyCurrentIds.add(globalState.config.currentProfileId);
          },
          cleaner: cleaned.add,
        );

        final result = await service.importSubscription(
          fixtureSubscribeUrl(),
          persistUrl: false,
          source: wyxV2BoardProfileSource,
          allowEncryptedService: false,
        );

        expect(result.isSuccess, true);
        expect(applyCurrentIds, [downloaded.id]);
        expect(globalState.config.currentProfileId, downloaded.id);
        expect(globalState.config.profiles, [downloaded]);
        expect(cleaned, [oldWyx.id]);
        expect(result.profile?.url, isEmpty);
      },
    );
  });

  group('NodeSelectorBar wyx fallback priority', () {
    testWidgets(
      'shows real Clash proxy when groups are available instead of wyx summary',
      (tester) async {
        final wyxNodes = List.generate(
          27,
          (index) => _wyxNode(
            id: index + 1,
            name: index == 0 ? '日本｜隧道C' : '节点 ${index + 1}',
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              isWyxV2BoardBackendProvider.overrideWith((ref) async => true),
              patchClashConfigProvider.overrideWithValue(const ClashConfig()),
              selectedMapProvider.overrideWithValue(const {
                'Proxy': '真实 Clash 节点',
              }),
              appSettingProvider.overrideWithValue(const AppSettingProps()),
              runTimeProvider.overrideWithValue(null),
              delayDataSourceProvider.overrideWithValue(const {}),
              groupsProvider.overrideWithValue([
                const Group(
                  type: GroupType.Selector,
                  name: 'Proxy',
                  now: '真实 Clash 节点',
                  all: [Proxy(name: '真实 Clash 节点', type: 'VLESS')],
                ),
              ]),
              wyxV2BoardUiControllerProvider.overrideWith(
                (ref) => _StaticWyxUiController(
                  ref,
                  WyxV2BoardUiDataState(nodes: wyxNodes, nodesLoaded: true),
                ),
              ),
            ],
            child: _localizedApp(const Scaffold(body: NodeSelectorBar())),
          ),
        );
        await tester.pump();

        expect(find.text('真实 Clash 节点'), findsOneWidget);
        expect(find.text('日本｜隧道C'), findsNothing);
        expect(find.text('27 个'), findsNothing);
        autoLatencyService.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1600));
      },
    );

    testWidgets('shows wyx summary only when real Clash groups are empty', (
      tester,
    ) async {
      final wyxNodes = List.generate(
        27,
        (index) => _wyxNode(
          id: index + 1,
          name: index == 0 ? '日本｜隧道C' : '节点 ${index + 1}',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isWyxV2BoardBackendProvider.overrideWith((ref) async => true),
            patchClashConfigProvider.overrideWithValue(const ClashConfig()),
            selectedMapProvider.overrideWithValue(const {}),
            appSettingProvider.overrideWithValue(const AppSettingProps()),
            runTimeProvider.overrideWithValue(null),
            delayDataSourceProvider.overrideWithValue(const {}),
            groupsProvider.overrideWithValue(const []),
            wyxV2BoardUiControllerProvider.overrideWith(
              (ref) => _StaticWyxUiController(
                ref,
                WyxV2BoardUiDataState(nodes: wyxNodes, nodesLoaded: true),
              ),
            ),
          ],
          child: _localizedApp(const Scaffold(body: NodeSelectorBar())),
        ),
      );
      await tester.pump();

      expect(find.text('日本｜隧道C'), findsOneWidget);
      expect(find.text('27 个'), findsOneWidget);
      expect(find.text('真实 Clash 节点'), findsNothing);
      autoLatencyService.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1600));
    });
  });

  group('AppController traffic lifecycle', () {
    testWidgets(
      'updateTraffic skips writes when traffic providers are disposed',
      (tester) async {
        final env = _installProfileImportTestGlobalState(
          profiles: const [],
          currentProfileId: null,
        );
        addTearDown(env.restore);
        final trafficCompleter = Completer<Traffic>();
        final totalTrafficCompleter = Completer<Traffic>();
        AppController? controller;

        await tester.pumpWidget(
          ProviderScope(
            child: _AppControllerHarness(
              trafficFetcher: () => trafficCompleter.future,
              totalTrafficFetcher: () => totalTrafficCompleter.future,
              onReady: (value) => controller = value,
            ),
          ),
        );

        final updateFuture = controller!.updateTraffic();
        await tester.pumpWidget(const SizedBox.shrink());

        trafficCompleter.complete(Traffic(up: 1, down: 2));
        totalTrafficCompleter.complete(Traffic(up: 10, down: 20));

        await expectLater(updateFuture, completes);
      },
    );
  });
}

XBoardProfileImportService _profileImportServiceForTest(
  ProviderContainer container, {
  required ProfileDownloader downloader,
  required ProfileApplyRunner applyRunner,
  required ProfileEffectCleaner cleaner,
}) {
  final provider = Provider(
    (ref) => XBoardProfileImportService(
      ref,
      profileDownloader: downloader,
      profileApplyRunner: applyRunner,
      profileEffectCleaner: cleaner,
    ),
  );
  return container.read(provider);
}

ProviderContainer _container({
  _FakeWyxAdapter? adapter,
  _MemoryStorage? storage,
  _FakeProfileImportService? importService,
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
      if (importService != null)
        xboardProfileImportServiceProvider.overrideWithValue(importService),
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
  String subscribeUrl;
  int inviteCalls = 0;
  int nodeCalls = 0;
  String? lastPassword;

  _FakeWyxAdapter({this.loginError, this.nodes, this.subscribeUrl = ''});

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
    return WyxSubscribeInfo(
      planId: 3,
      token: 'subscribe-token',
      upload: 100,
      download: 200,
      transferEnable: 1000,
      deviceLimit: 3,
      email: 'user@example.com',
      uuid: 'uuid-1',
      aliveIp: 2,
      subscribeUrl: subscribeUrl,
      resetDay: 15,
      plan: const WyxPlanInfo(
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
    nodeCalls += 1;
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

class _FakeProfileImportService implements ProfileImportServiceApi {
  final bool shouldFail;
  final calls = <_ImportCall>[];
  bool applyProfileCalled = false;

  _FakeProfileImportService({this.shouldFail = false});

  @override
  bool get isImporting => false;

  @override
  Future<ImportResult> importSubscription(
    String url, {
    Function(ImportStatus, double, String?)? onProgress,
    bool persistUrl = true,
    String? source,
    bool allowEncryptedService = true,
  }) async {
    calls.add(
      _ImportCall(
        url: url,
        persistUrl: persistUrl,
        source: source,
        allowEncryptedService: allowEncryptedService,
      ),
    );
    if (shouldFail) {
      onProgress?.call(ImportStatus.failed, 0.0, '导入失败，请稍后重试');
      return ImportResult.failure(
        errorMessage: '导入失败，请稍后重试',
        errorType: ImportErrorType.downloadError,
      );
    }
    applyProfileCalled = true;
    final profile = Profile.normal(
      label: source == wyxV2BoardProfileSource
          ? wyxV2BoardProfileLabel
          : 'subscription',
      url: persistUrl ? url : '',
    );
    onProgress?.call(ImportStatus.success, 1.0, '导入成功');
    return ImportResult.success(profile: profile);
  }

  @override
  Future<ImportResult> importSubscriptionWithRetry(
    String url, {
    Function(ImportStatus, double, String?)? onProgress,
    int retries = XBoardProfileImportService.maxRetries,
    bool persistUrl = true,
    String? source,
    bool allowEncryptedService = true,
  }) {
    return importSubscription(
      url,
      onProgress: onProgress,
      persistUrl: persistUrl,
      source: source,
      allowEncryptedService: allowEncryptedService,
    );
  }
}

class _ImportCall {
  final String url;
  final bool persistUrl;
  final String? source;
  final bool allowEncryptedService;

  const _ImportCall({
    required this.url,
    required this.persistUrl,
    required this.source,
    required this.allowEncryptedService,
  });

  @override
  String toString() {
    return '_ImportCall(persistUrl: $persistUrl, source: $source, '
        'allowEncryptedService: $allowEncryptedService, url: [MASKED])';
  }
}

class _StaticWyxUiController extends WyxV2BoardUiController {
  _StaticWyxUiController(super.ref, WyxV2BoardUiDataState initialState) {
    state = initialState;
  }

  @override
  Future<List<WyxNodeInfo>> loadNodes() async {
    return state.nodes;
  }
}

class _AppControllerHarness extends ConsumerStatefulWidget {
  final TrafficFetcher trafficFetcher;
  final TrafficFetcher totalTrafficFetcher;
  final ValueChanged<AppController> onReady;

  const _AppControllerHarness({
    required this.trafficFetcher,
    required this.totalTrafficFetcher,
    required this.onReady,
  });

  @override
  ConsumerState<_AppControllerHarness> createState() =>
      _AppControllerHarnessState();
}

class _AppControllerHarnessState extends ConsumerState<_AppControllerHarness> {
  @override
  void initState() {
    super.initState();
    widget.onReady(
      AppController(
        context,
        ref,
        trafficFetcher: widget.trafficFetcher,
        totalTrafficFetcher: widget.totalTrafficFetcher,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Timed out waiting for condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
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

_ProfileImportGlobalStateSnapshot _installProfileImportTestGlobalState({
  required List<Profile> profiles,
  required String? currentProfileId,
  List<Group> groups = const [],
  List<ExternalProvider> providers = const [],
}) {
  final hadConfig = _isGlobalConfigReady();
  final hadAppState = _isGlobalAppStateReady();
  final oldConfig = hadConfig ? globalState.config : null;
  final oldAppState = hadAppState ? globalState.appState : null;

  globalState.config = Config(
    themeProps: defaultThemeProps,
    profiles: profiles,
    currentProfileId: currentProfileId,
  );
  globalState.appState = AppState(
    version: 1,
    viewSize: Size.zero,
    requests: FixedList(maxLength),
    logs: FixedList(maxLength),
    traffics: FixedList(30),
    totalTraffic: Traffic(),
    groups: groups,
    providers: providers,
  );

  return _ProfileImportGlobalStateSnapshot(
    hadConfig: hadConfig,
    oldConfig: oldConfig,
    hadAppState: hadAppState,
    oldAppState: oldAppState,
  );
}

bool _isGlobalConfigReady() {
  try {
    globalState.config;
    return true;
  } catch (_) {
    return false;
  }
}

bool _isGlobalAppStateReady() {
  try {
    globalState.appState;
    return true;
  } catch (_) {
    return false;
  }
}

class _ProfileImportGlobalStateSnapshot {
  final bool hadConfig;
  final Config? oldConfig;
  final bool hadAppState;
  final AppState? oldAppState;

  const _ProfileImportGlobalStateSnapshot({
    required this.hadConfig,
    required this.oldConfig,
    required this.hadAppState,
    required this.oldAppState,
  });

  void restore() {
    if (hadConfig && oldConfig != null) {
      globalState.config = oldConfig!;
    }
    if (hadAppState && oldAppState != null) {
      globalState.appState = oldAppState!;
    }
  }
}
