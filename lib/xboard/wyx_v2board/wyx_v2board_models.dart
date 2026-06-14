class WyxAuthSession {
  final String token;
  final String authData;
  final bool isAdmin;

  const WyxAuthSession({
    required this.token,
    required this.authData,
    required this.isAdmin,
  });

  @override
  String toString() {
    return 'WyxAuthSession(token: [MASKED], authData: [MASKED], '
        'isAdmin: $isAdmin)';
  }
}

class WyxLoginResult {
  final WyxAuthSession session;

  const WyxLoginResult({required this.session});
}

class WyxUserInfo {
  final String? email;
  final int transferEnable;
  final int? deviceLimit;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;
  final bool banned;
  final DateTime? expiredAt;
  final int balance;
  final int commissionBalance;
  final int? planId;
  final num? discount;
  final String? uuid;
  final String? avatarUrl;

  const WyxUserInfo({
    this.email,
    required this.transferEnable,
    this.deviceLimit,
    this.lastLoginAt,
    this.createdAt,
    required this.banned,
    this.expiredAt,
    required this.balance,
    required this.commissionBalance,
    this.planId,
    this.discount,
    this.uuid,
    this.avatarUrl,
  });
}

class WyxSubscribeInfo {
  final int? planId;
  final String? token;
  final DateTime? expiredAt;
  final int upload;
  final int download;
  final int transferEnable;
  final int? deviceLimit;
  final String? email;
  final String? uuid;
  final String? planName;
  final WyxPlanInfo? plan;
  final int aliveIp;
  final String? subscribeUrl;
  final int? resetDay;
  final String? allowNewPeriod;

  const WyxSubscribeInfo({
    this.planId,
    this.token,
    this.expiredAt,
    required this.upload,
    required this.download,
    required this.transferEnable,
    this.deviceLimit,
    this.email,
    this.uuid,
    this.planName,
    this.plan,
    required this.aliveIp,
    this.subscribeUrl,
    this.resetDay,
    this.allowNewPeriod,
  });

  int get usedTraffic => upload + download;
  int get remainingTraffic => transferEnable - usedTraffic;

  @override
  String toString() {
    return 'WyxSubscribeInfo(planId: $planId, token: [MASKED], '
        'subscribeUrl: [MASKED], transferEnable: $transferEnable)';
  }
}

class WyxPlanInfo {
  final int? id;
  final int? groupId;
  final int transferEnable;
  final String name;
  final int? deviceLimit;
  final int? speedLimit;
  final bool show;
  final int? sort;
  final bool renew;
  final String? content;
  final List<WyxPlanFeature> features;
  final int? monthPrice;
  final int? quarterPrice;
  final int? halfYearPrice;
  final int? yearPrice;
  final int? twoYearPrice;
  final int? threeYearPrice;
  final int? onetimePrice;
  final int? resetPrice;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WyxPlanInfo({
    this.id,
    this.groupId,
    required this.transferEnable,
    required this.name,
    this.deviceLimit,
    this.speedLimit,
    required this.show,
    this.sort,
    required this.renew,
    this.content,
    required this.features,
    this.monthPrice,
    this.quarterPrice,
    this.halfYearPrice,
    this.yearPrice,
    this.twoYearPrice,
    this.threeYearPrice,
    this.onetimePrice,
    this.resetPrice,
    this.createdAt,
    this.updatedAt,
  });
}

class WyxPlanFeature {
  final String feature;
  final bool support;

  const WyxPlanFeature({required this.feature, required this.support});
}

class WyxNotice {
  final int? id;
  final String title;
  final String content;
  final bool show;
  final String? imageUrl;
  final List<String> tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WyxNotice({
    this.id,
    required this.title,
    required this.content,
    required this.show,
    this.imageUrl,
    required this.tags,
    this.createdAt,
    this.updatedAt,
  });
}

class WyxNodeInfo {
  final int? id;
  final String name;
  final String? type;
  final num? rate;
  final String? country;
  final List<String> tags;
  final Map<String, dynamic> raw;

  const WyxNodeInfo({
    this.id,
    required this.name,
    this.type,
    this.rate,
    this.country,
    required this.tags,
    required this.raw,
  });

  @override
  String toString() {
    return 'WyxNodeInfo(id: $id, name: $name, type: $type, rate: $rate, '
        'raw: [OMITTED])';
  }
}

class WyxOrderInfo {
  final String? tradeNo;
  final int? planId;
  final String? planName;
  final String? period;
  final int? status;
  final int? totalAmount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WyxOrderInfo({
    this.tradeNo,
    this.planId,
    this.planName,
    this.period,
    this.status,
    this.totalAmount,
    this.createdAt,
    this.updatedAt,
  });
}

class WyxInviteInfo {
  final String? code;
  final int? invitedCount;
  final int? commissionBalance;
  final Map<String, dynamic> safeData;

  const WyxInviteInfo({
    this.code,
    this.invitedCount,
    this.commissionBalance,
    required this.safeData,
  });
}
