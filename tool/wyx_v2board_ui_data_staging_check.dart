import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/security/security.dart';
import 'package:fl_clash/xboard/wyx_v2board/wyx_v2board.dart';

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
  final secureClient = SecureHttpClient(
    config: SecureConfig(
      securityBaseUrl: env['SECURITY_BASE_URL']!.trim(),
      backupSecurityBaseUrls: _splitUrls(env['BACKUP_SECURITY_BASE_URLS']),
      keyId: env['SECURE_V2_KEY_ID']!.trim(),
      publicKey: env['SECURE_V2_PUBLIC_KEY']!.trim(),
      appVersion: env['APP_VERSION']?.trim().isNotEmpty == true
          ? env['APP_VERSION']!.trim()
          : 'wyx-ui-data-staging-check',
      platform: env['APP_PLATFORM']?.trim().isNotEmpty == true
          ? env['APP_PLATFORM']!.trim()
          : Platform.operatingSystem,
    ),
  );
  final adapter = WyxV2BoardAdapter.withSecureHttpClient(
    secureClient,
    masker: masker,
  );

  try {
    final login = await adapter.login(
      env['TEST_USER_EMAIL']!.trim(),
      env['TEST_USER_PASSWORD']!,
    );
    _printStep(
      'login',
      {
        'success': true,
        'hasToken': login.session.token.isNotEmpty,
        'hasAuthData': login.session.authData.isNotEmpty,
        'authHeaderMode': 'auth_data_raw',
        'bearerPrefix': login.session.authData.startsWith('Bearer '),
      },
      masker,
    );

    final userInfo = await adapter.getUserInfo();
    final subscribeInfo = await adapter.getSubscribeInfo();
    _printStep(
      'home-data',
      {
        'success': true,
        'email': userInfo.email ?? subscribeInfo.email,
        'planName': subscribeInfo.plan?.name ?? '暂无套餐',
        'transferLimit': subscribeInfo.transferEnable,
        'usedBytes': subscribeInfo.usedTraffic,
        'remainingBytes': subscribeInfo.remainingTraffic,
        'expiredAt': subscribeInfo.expiredAt?.toIso8601String(),
        'deviceLimit': subscribeInfo.deviceLimit ?? userInfo.deviceLimit,
        'aliveIp': subscribeInfo.aliveIp,
        'banned': userInfo.banned,
        'subscribe_url': subscribeInfo.subscribeUrl,
      },
      masker,
    );

    await _runStep(
      'plan-list',
      () async {
        final plans = await adapter.getPlanList();
        return {
          'success': true,
          'count': plans.length,
          'items': plans
              .take(5)
              .map((plan) => {
                    'id': plan.id,
                    'name': plan.name,
                    'traffic': plan.transferEnable,
                    'visible': plan.show,
                    'renew': plan.renew,
                    'features': plan.features.length,
                  })
              .toList(growable: false),
        };
      },
      masker,
    );

    await _runStep(
      'notice-list',
      () async {
        final notices = await adapter.getNoticeList();
        return {
          'success': true,
          'count': notices.length,
          'items': notices
              .take(5)
              .map((notice) => {
                    'id': notice.id,
                    'title': notice.title,
                    'show': notice.show,
                  })
              .toList(growable: false),
        };
      },
      masker,
    );

    await _runStep(
      'order-list',
      () async {
        final orders = await adapter.getOrderList();
        return {
          'success': true,
          'count': orders.length,
          'items': orders
              .take(5)
              .map((order) => {
                    'tradeNo': order.tradeNo,
                    'planId': order.planId,
                    'planName': order.planName,
                    'status': order.status,
                    'totalAmount': order.totalAmount,
                  })
              .toList(growable: false),
        };
      },
      masker,
    );

    await _runStep(
      'node-list',
      () async {
        final nodes = await adapter.getNodeList();
        return {
          'success': true,
          'count': nodes.length,
          'items': nodes
              .take(8)
              .map((node) => {
                    'id': node.id,
                    'name': node.name,
                    'type': node.type,
                    'rate': node.rate,
                    'country': node.country,
                  })
              .toList(growable: false),
        };
      },
      masker,
    );

    adapter.logout();
    _printStep('logout', {'success': !adapter.isLoggedIn}, masker);
    stdout.writeln('wyx-v2board UI data staging check completed');
  } on Object catch (error) {
    stderr.writeln(
      'wyx-v2board UI data staging check failed: '
      '${masker.maskText('$error')}',
    );
    exitCode = 1;
  }
}

Future<void> _runStep(
  String step,
  Future<Map<String, Object?>> Function() action,
  SensitiveLogMasker masker,
) async {
  try {
    _printStep(step, await action(), masker);
  } on WyxV2BoardException catch (error) {
    _printStep(
      step,
      {
        'success': false,
        'code': error.code.name,
        'statusCode': error.statusCode,
        'requestId': error.requestId,
        'message': error.message,
        'safeDebugMessage': error.safeDebugMessage,
      },
      masker,
    );
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

void _printStep(
  String step,
  Map<String, Object?> payload,
  SensitiveLogMasker masker,
) {
  stdout.writeln(
    jsonEncode({
      'step': step,
      ...masker.mask(payload) as Map,
    }),
  );
}
