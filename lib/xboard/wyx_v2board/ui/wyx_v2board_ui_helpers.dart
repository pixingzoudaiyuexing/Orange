import 'package:fl_clash/security/security.dart';

import '../../domain/domain.dart';
import '../wyx_v2board.dart';

class WyxV2BoardUiErrorMapper {
  static const _masker = SensitiveLogMasker();

  const WyxV2BoardUiErrorMapper._();

  static String message(Object error) {
    if (error is WyxV2BoardException) {
      return _fromWyx(error);
    }
    if (error is SecureHttpException) {
      return _fromSecure(error);
    }
    return '请求失败，请稍后重试';
  }

  static String _fromWyx(WyxV2BoardException error) {
    switch (error.code) {
      case WyxV2BoardErrorCode.unauthenticated:
        return '登录状态已过期，请重新登录';
      case WyxV2BoardErrorCode.loginFailed:
        return '邮箱或密码错误';
      case WyxV2BoardErrorCode.secureTransport:
        return _secureMessage(error.safeDebugMessage);
      case WyxV2BoardErrorCode.backendError:
        return _backendMessage(error.message);
      case WyxV2BoardErrorCode.invalidResponse:
        return '服务器响应异常，请稍后重试';
      case WyxV2BoardErrorCode.notImplemented:
        return '当前功能暂未开放';
    }
  }

  static String _fromSecure(SecureHttpException error) {
    switch (error.code) {
      case SecureHttpErrorCode.network:
        return '网络连接失败，请稍后重试';
      case SecureHttpErrorCode.invalidConfig:
        return _configMessage(error.safeDebugMessage);
      case SecureHttpErrorCode.invalidPath:
      case SecureHttpErrorCode.invalidMethod:
      case SecureHttpErrorCode.invalidHeader:
      case SecureHttpErrorCode.secureV2Error:
        return _secureMessage(error.safeDebugMessage);
      case SecureHttpErrorCode.encryptionFailed:
      case SecureHttpErrorCode.decryptionFailed:
        return '安全连接失败，请检查网络';
      case SecureHttpErrorCode.invalidResponse:
      case SecureHttpErrorCode.requestIdMismatch:
        return '安全网关响应异常，请稍后重试';
      case SecureHttpErrorCode.httpStatus:
        if (error.statusCode == 401 || error.statusCode == 403) {
          return '登录状态已过期，请重新登录';
        }
        return '服务器维护中，请稍后再试';
    }
  }

  static String _secureMessage(String safeDebugMessage) {
    final normalized = safeDebugMessage.toLowerCase();
    if (normalized.contains('path_not_allowed') ||
        normalized.contains('not_allowed') ||
        normalized.contains('whitelist')) {
      return '请求被安全网关拦截，请联系客服';
    }
    if (normalized.contains('keyid') || normalized.contains('key_id')) {
      return '安全配置缺少 keyId，请联系客服';
    }
    if (normalized.contains('publickey') || normalized.contains('public_key')) {
      return '安全配置缺少公钥，请联系客服';
    }
    if (normalized.contains('securitybaseurl') ||
        normalized.contains('base_url')) {
      return '安全网关地址缺失，请联系客服';
    }
    return '安全连接失败，请检查网络';
  }

  static String _configMessage(String safeDebugMessage) {
    final normalized = safeDebugMessage.toLowerCase();
    if (normalized.contains('keyid') || normalized.contains('key_id')) {
      return '安全配置缺少 keyId，请联系客服';
    }
    if (normalized.contains('publickey') || normalized.contains('public_key')) {
      return '安全配置缺少公钥，请联系客服';
    }
    if (normalized.contains('securitybaseurl') ||
        normalized.contains('baseurl') ||
        normalized.contains('base_url')) {
      return '安全网关地址缺失，请联系客服';
    }
    return '安全配置缺失，请联系客服';
  }

  static String _backendMessage(String message) {
    final masked = _masker.maskText(message).trim();
    if (masked.isEmpty) {
      return '服务器维护中，请稍后再试';
    }
    if (masked.contains('未登录') || masked.contains('登陆已过期')) {
      return '登录状态已过期，请重新登录';
    }
    if (masked.length > 80) {
      return '服务器返回业务错误，请稍后重试';
    }
    return masked;
  }
}

class WyxHomeDisplayData {
  final String email;
  final String planName;
  final int totalBytes;
  final int usedBytes;
  final int remainingBytes;
  final DateTime? expiredAt;
  final int? deviceLimit;
  final int? aliveIp;
  final bool banned;
  final int? resetDay;
  final String? allowNewPeriod;

  const WyxHomeDisplayData({
    required this.email,
    required this.planName,
    required this.totalBytes,
    required this.usedBytes,
    required this.remainingBytes,
    required this.expiredAt,
    required this.deviceLimit,
    required this.aliveIp,
    required this.banned,
    required this.resetDay,
    required this.allowNewPeriod,
  });

  factory WyxHomeDisplayData.from({
    required DomainUser? user,
    required DomainSubscription? subscription,
  }) {
    final total = subscription?.transferLimit ?? user?.transferLimit ?? 0;
    final used = subscription?.totalUsedBytes ?? user?.totalUsedBytes ?? 0;
    final remaining = total - used;
    return WyxHomeDisplayData(
      email: subscription?.email.isNotEmpty == true
          ? subscription!.email
          : user?.email ?? '',
      planName: subscription?.planName?.isNotEmpty == true
          ? subscription!.planName!
          : '暂无套餐',
      totalBytes: total,
      usedBytes: used,
      remainingBytes: remaining > 0 ? remaining : 0,
      expiredAt: subscription?.expiredAt ?? user?.expiredAt,
      deviceLimit:
          subscription?.deviceLimit ??
          _intMetadata(subscription?.metadata, 'device_limit') ??
          _intMetadata(user?.metadata, 'device_limit'),
      aliveIp:
          _intMetadata(subscription?.metadata, 'alive_ip') ??
          _intMetadata(user?.metadata, 'alive_ip'),
      banned: user?.banned ?? false,
      resetDay: _intMetadata(subscription?.metadata, 'reset_day'),
      allowNewPeriod: subscription?.metadata['allow_new_period']?.toString(),
    );
  }

  String get displayEmail => email.isEmpty ? '未设置邮箱' : email;
  String get statusText => banned ? '账号异常' : '账号正常';
  String get deviceLimitText =>
      deviceLimit == null || deviceLimit == 0 ? '不限设备' : '$deviceLimit 台设备';
  String get aliveIpText => aliveIp == null ? '未上报' : '$aliveIp 台在线';
  String get resetDayText => resetDay == null ? '未设置' : '每月 $resetDay 日';
  String get expiredText {
    if (expiredAt == null || expiredAt!.millisecondsSinceEpoch == 0) {
      return '长期有效';
    }
    return _formatDate(expiredAt!.toLocal());
  }

  String get totalText => formatBytes(totalBytes);
  String get usedText => formatBytes(usedBytes);
  String get remainingText => formatBytes(remainingBytes);
  double get progress =>
      totalBytes <= 0 ? 0 : (usedBytes / totalBytes).clamp(0.0, 1.0).toDouble();

  Map<String, Object?> toSafeMap() {
    return {
      'email': displayEmail,
      'planName': planName,
      'totalBytes': totalBytes,
      'usedBytes': usedBytes,
      'remainingBytes': remainingBytes,
      'expiredText': expiredText,
      'deviceLimitText': deviceLimitText,
      'aliveIpText': aliveIpText,
      'statusText': statusText,
      'resetDayText': resetDayText,
    };
  }

  static int? _intMetadata(Map<String, dynamic>? metadata, String key) {
    final value = metadata?[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}

class WyxNodeDisplayData {
  final String name;
  final String type;
  final String rate;
  final String region;
  final String tags;

  const WyxNodeDisplayData({
    required this.name,
    required this.type,
    required this.rate,
    required this.region,
    required this.tags,
  });

  factory WyxNodeDisplayData.from(WyxNodeInfo node) {
    return WyxNodeDisplayData(
      name: node.name.isEmpty ? '未命名节点' : node.name,
      type: node.type?.isNotEmpty == true ? node.type! : '未知类型',
      rate: node.rate == null ? '倍率未设置' : '${node.rate}x',
      region: node.country?.isNotEmpty == true ? node.country! : '地区未设置',
      tags: node.tags.isEmpty ? '' : node.tags.take(3).join(' / '),
    );
  }
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }
  if (size >= 100) {
    return '${size.toStringAsFixed(0)} ${units[unitIndex]}';
  }
  if (size >= 10) {
    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }
  return '${size.toStringAsFixed(2)} ${units[unitIndex]}';
}

String _formatDate(DateTime value) {
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
