import '../../domain/domain.dart';
import '../wyx_v2board.dart';

class WyxV2BoardDomainMapper {
  const WyxV2BoardDomainMapper._();

  static DomainUser user(WyxUserInfo user, {WyxSubscribeInfo? subscribe}) {
    return DomainUser(
      email: user.email ?? subscribe?.email ?? '',
      uuid: user.uuid ?? subscribe?.uuid ?? '',
      avatarUrl: user.avatarUrl ?? '',
      planId: user.planId ?? subscribe?.planId,
      transferLimit: subscribe?.transferEnable ?? user.transferEnable,
      uploadedBytes: subscribe?.upload ?? 0,
      downloadedBytes: subscribe?.download ?? 0,
      balanceInCents: user.balance,
      commissionBalanceInCents: user.commissionBalance,
      expiredAt: subscribe?.expiredAt ?? user.expiredAt,
      lastLoginAt: user.lastLoginAt,
      createdAt: user.createdAt,
      banned: user.banned,
      discount: user.discount?.toDouble(),
      metadata: {
        'source': 'wyx_v2board',
        if (user.deviceLimit != null) 'device_limit': user.deviceLimit,
        if (subscribe?.aliveIp != null) 'alive_ip': subscribe!.aliveIp,
      },
    );
  }

  static DomainSubscription subscription(WyxSubscribeInfo subscribe) {
    return DomainSubscription(
      subscribeUrl: subscribe.subscribeUrl ?? '',
      email: subscribe.email ?? '',
      uuid: subscribe.uuid ?? '',
      planId: subscribe.planId ?? 0,
      planName: subscribe.plan?.name ?? subscribe.planName,
      token: subscribe.token,
      transferLimit: subscribe.transferEnable,
      uploadedBytes: subscribe.upload,
      downloadedBytes: subscribe.download,
      speedLimit: subscribe.plan?.speedLimit,
      deviceLimit: subscribe.deviceLimit ?? subscribe.plan?.deviceLimit,
      expiredAt: subscribe.expiredAt,
      metadata: {
        'source': 'wyx_v2board',
        'alive_ip': subscribe.aliveIp,
        if (subscribe.resetDay != null) 'reset_day': subscribe.resetDay,
        if (subscribe.allowNewPeriod != null)
          'allow_new_period': subscribe.allowNewPeriod,
      },
    );
  }

  static DomainPlan plan(WyxPlanInfo plan) {
    return DomainPlan(
      id: plan.id ?? 0,
      name: plan.name,
      groupId: plan.groupId ?? 0,
      transferQuota: plan.transferEnable,
      description: plan.content,
      tags: plan.features.map((item) => item.feature).toList(growable: false),
      speedLimit: plan.speedLimit,
      deviceLimit: plan.deviceLimit,
      isVisible: plan.show,
      renewable: plan.renew,
      sort: plan.sort,
      onetimePrice: _price(plan.onetimePrice),
      monthlyPrice: _price(plan.monthPrice),
      quarterlyPrice: _price(plan.quarterPrice),
      halfYearlyPrice: _price(plan.halfYearPrice),
      yearlyPrice: _price(plan.yearPrice),
      twoYearPrice: _price(plan.twoYearPrice),
      threeYearPrice: _price(plan.threeYearPrice),
      resetPrice: _price(plan.resetPrice),
      createdAt: plan.createdAt,
      updatedAt: plan.updatedAt,
      metadata: {
        'source': 'wyx_v2board',
        'features': plan.features
            .map((item) => {'feature': item.feature, 'support': item.support})
            .toList(growable: false),
      },
    );
  }

  static DomainNotice notice(WyxNotice notice) {
    return DomainNotice(
      id: notice.id ?? 0,
      title: notice.title,
      content: notice.content,
      imageUrls: notice.imageUrl == null || notice.imageUrl!.isEmpty
          ? const []
          : [notice.imageUrl!],
      tags: notice.tags,
      isVisible: notice.show,
      createdAt: notice.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: notice.updatedAt,
      metadata: const {'source': 'wyx_v2board'},
    );
  }

  static double? _price(int? cents) {
    if (cents == null) {
      return null;
    }
    return cents / 100;
  }
}
