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
          : 'wyx-adapter-staging-check',
      platform: env['APP_PLATFORM']?.trim().isNotEmpty == true
          ? env['APP_PLATFORM']!.trim()
          : 'macos',
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
        'isAdmin': login.session.isAdmin,
        'authHeaderMode': 'auth_data_raw',
        'bearerPrefix': login.session.authData.startsWith('Bearer '),
      },
      masker,
    );

    final userInfo = await adapter.getUserInfo();
    _printStep(
      'user-info',
      {
        'success': true,
        'email': userInfo.email,
        'planId': userInfo.planId,
        'banned': userInfo.banned,
        'transferEnable': userInfo.transferEnable,
        'expiredAt': userInfo.expiredAt?.toIso8601String(),
      },
      masker,
    );

    final subscribe = await adapter.getSubscribeInfo();
    _printStep(
      'subscribe',
      {
        'success': true,
        'planId': subscribe.planId,
        'planName': subscribe.plan?.name,
        'email': subscribe.email,
        'upload': subscribe.upload,
        'download': subscribe.download,
        'usedTraffic': subscribe.usedTraffic,
        'transferEnable': subscribe.transferEnable,
        'expiredAt': subscribe.expiredAt?.toIso8601String(),
        'aliveIp': subscribe.aliveIp,
        'hasToken': subscribe.token?.isNotEmpty == true,
        'subscribe_url': subscribe.subscribeUrl,
      },
      masker,
    );

    await _runAdapterStep(
      'plan-list',
      () async {
        final plans = await adapter.getPlanList();
        return {
          'success': true,
          'count': plans.length,
          'items': plans.take(5).map(_planSummary).toList(growable: false),
        };
      },
      masker,
    );

    await _runAdapterStep(
      'notice-list',
      () async {
        final notices = await adapter.getNoticeList();
        return {
          'success': true,
          'count': notices.length,
          'items': notices.take(5).map(_noticeSummary).toList(growable: false),
        };
      },
      masker,
    );

    await _runAdapterStep(
      'order-list',
      () async {
        final orders = await adapter.getOrderList();
        return {
          'success': true,
          'count': orders.length,
          'items': orders.take(5).map(_orderSummary).toList(growable: false),
        };
      },
      masker,
    );

    await _runAdapterStep(
      'node-list',
      () async {
        final nodes = await adapter.getNodeList();
        return {
          'success': true,
          'count': nodes.length,
          'items': nodes.take(8).map(_nodeSummary).toList(growable: false),
        };
      },
      masker,
    );

    stdout.writeln('wyx-v2board adapter staging check completed');
  } on Object catch (error) {
    stderr.writeln(
      'wyx-v2board adapter staging check failed: '
      '${masker.maskText('$error')}',
    );
    exitCode = 1;
  }
}

Future<void> _runAdapterStep(
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

Map<String, Object?> _planSummary(WyxPlanInfo plan) {
  return {
    'id': plan.id,
    'name': plan.name,
    'transferEnable': plan.transferEnable,
    'deviceLimit': plan.deviceLimit,
    'monthPrice': plan.monthPrice,
    'yearPrice': plan.yearPrice,
    'features': plan.features
        .take(3)
        .map((feature) => {
              'feature': feature.feature,
              'support': feature.support,
            })
        .toList(growable: false),
  };
}

Map<String, Object?> _noticeSummary(WyxNotice notice) {
  return {
    'id': notice.id,
    'title': notice.title,
    'show': notice.show,
    'createdAt': notice.createdAt?.toIso8601String(),
  };
}

Map<String, Object?> _orderSummary(WyxOrderInfo order) {
  return {
    'tradeNo': order.tradeNo,
    'planId': order.planId,
    'planName': order.planName,
    'period': order.period,
    'status': order.status,
    'totalAmount': order.totalAmount,
    'createdAt': order.createdAt?.toIso8601String(),
  };
}

Map<String, Object?> _nodeSummary(WyxNodeInfo node) {
  return {
    'id': node.id,
    'name': node.name,
    'type': node.type,
    'rate': node.rate,
    'country': node.country,
    'tags': node.tags.take(5).toList(growable: false),
  };
}
