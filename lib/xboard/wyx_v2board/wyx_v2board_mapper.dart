import 'dart:convert';

import 'wyx_v2board_models.dart';

class WyxV2BoardMapper {
  const WyxV2BoardMapper._();

  static WyxUserInfo userInfo(Object? value) {
    final json = map(value);
    return WyxUserInfo(
      email: string(json['email']),
      transferEnable: integer(json['transfer_enable']) ?? 0,
      deviceLimit: integer(json['device_limit']),
      lastLoginAt: unixTime(json['last_login_at']),
      createdAt: unixTime(json['created_at']),
      banned: boolean(json['banned']),
      expiredAt: unixTime(json['expired_at']),
      balance: integer(json['balance']) ?? 0,
      commissionBalance: integer(json['commission_balance']) ?? 0,
      planId: integer(json['plan_id']),
      discount: number(json['discount']),
      uuid: string(json['uuid']),
      avatarUrl: string(json['avatar_url']),
    );
  }

  static WyxSubscribeInfo subscribeInfo(Object? value) {
    final json = map(value);
    final planJson = json['plan'];
    return WyxSubscribeInfo(
      planId: integer(json['plan_id']),
      token: string(json['token']),
      expiredAt: unixTime(json['expired_at']),
      upload: integer(json['u']) ?? 0,
      download: integer(json['d']) ?? 0,
      transferEnable: integer(json['transfer_enable']) ?? 0,
      deviceLimit: integer(json['device_limit']),
      email: string(json['email']),
      uuid: string(json['uuid']),
      planName: string(json['plan_name']) ?? string(json['planName']),
      plan: planJson is Map ? planInfo(planJson) : null,
      aliveIp: integer(json['alive_ip']) ?? 0,
      subscribeUrl: string(json['subscribe_url']),
      resetDay: integer(json['reset_day']),
      allowNewPeriod: string(json['allow_new_period']),
    );
  }

  static WyxPlanInfo planInfo(Object? value) {
    final json = map(value);
    final content = string(json['content']);
    return WyxPlanInfo(
      id: integer(json['id']),
      groupId: integer(json['group_id']),
      transferEnable: integer(json['transfer_enable']) ?? 0,
      name: string(json['name']) ?? '',
      deviceLimit: integer(json['device_limit']),
      speedLimit: integer(json['speed_limit']),
      show: boolean(json['show'], defaultValue: true),
      sort: integer(json['sort']),
      renew: boolean(json['renew'], defaultValue: true),
      content: content,
      features: planFeatures(content),
      monthPrice: integer(json['month_price']),
      quarterPrice: integer(json['quarter_price']),
      halfYearPrice: integer(json['half_year_price']),
      yearPrice: integer(json['year_price']),
      twoYearPrice: integer(json['two_year_price']),
      threeYearPrice: integer(json['three_year_price']),
      onetimePrice: integer(json['onetime_price']),
      resetPrice: integer(json['reset_price']),
      createdAt: unixTime(json['created_at']),
      updatedAt: unixTime(json['updated_at']),
    );
  }

  static WyxNotice notice(Object? value) {
    final json = map(value);
    return WyxNotice(
      id: integer(json['id']),
      title: string(json['title']) ?? '',
      content: string(json['content']) ?? '',
      show: boolean(json['show'], defaultValue: true),
      imageUrl: string(json['img_url']),
      tags: stringList(json['tags']),
      createdAt: unixTime(json['created_at']),
      updatedAt: unixTime(json['updated_at']),
    );
  }

  static WyxNodeInfo nodeInfo(Object? value) {
    final json = map(value);
    return WyxNodeInfo(
      id: integer(json['id']),
      name: string(json['name']) ?? string(json['remarks']) ?? '',
      type: string(json['type']),
      rate: number(json['rate']),
      country: string(json['country']) ?? string(json['region']),
      tags: stringList(json['tags']),
      raw: Map.unmodifiable(json),
    );
  }

  static WyxOrderInfo orderInfo(Object? value) {
    final json = map(value);
    final plan = mapOrNull(json['plan']);
    return WyxOrderInfo(
      tradeNo: string(json['trade_no']),
      planId: integer(json['plan_id']),
      planName: plan == null ? null : string(plan['name']),
      period: string(json['period']),
      status: integer(json['status']),
      totalAmount: integer(json['total_amount']),
      createdAt: unixTime(json['created_at']),
      updatedAt: unixTime(json['updated_at']),
    );
  }

  static WyxInviteInfo inviteInfo(Object? value) {
    final json = map(value);
    return WyxInviteInfo(
      code: string(json['code']) ?? string(json['invite_code']),
      invitedCount: integer(json['invited_count']) ?? integer(json['stat']),
      commissionBalance: integer(json['commission_balance']),
      safeData: Map.unmodifiable(json),
    );
  }

  static List<WyxPlanFeature> planFeatures(Object? content) {
    Object? decoded = content;
    if (content is String && content.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(content);
      } on FormatException {
        return const [];
      }
    }
    if (decoded is! List) {
      return const [];
    }
    return decoded
        .whereType<Map>()
        .map((item) {
          final feature = string(item['feature']) ?? string(item['name']);
          if (feature == null || feature.isEmpty) {
            return null;
          }
          return WyxPlanFeature(
            feature: feature,
            support: boolean(item['support'], defaultValue: true),
          );
        })
        .whereType<WyxPlanFeature>()
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> listMaps(Object? value) {
    Object? listValue = value;
    if (listValue is Map) {
      listValue = listValue['data'] ?? listValue['items'] ?? listValue['list'];
    }
    if (listValue is! List) {
      return const [];
    }
    return listValue
        .whereType<Map>()
        .map((item) => map(item))
        .toList(growable: false);
  }

  static Map<String, dynamic> map(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, dynamic item) => MapEntry('$key', item));
    }
    return const {};
  }

  static Map<String, dynamic>? mapOrNull(Object? value) {
    if (value is Map) {
      return map(value);
    }
    return null;
  }

  static String? string(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }
    return '$value';
  }

  static int? integer(Object? value) {
    if (value == null) {
      return null;
    }
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

  static num? number(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value;
    }
    if (value is String) {
      return num.tryParse(value);
    }
    return null;
  }

  static bool boolean(Object? value, {bool defaultValue = false}) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return defaultValue;
  }

  static DateTime? unixTime(Object? value) {
    final seconds = integer(value);
    if (seconds == null || seconds <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  static List<String> stringList(Object? value) {
    if (value is List) {
      return value.map((item) => '$item').toList(growable: false);
    }
    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }
}
