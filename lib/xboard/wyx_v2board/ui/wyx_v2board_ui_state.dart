import '../../domain/domain.dart';
import '../wyx_v2board.dart';

class WyxV2BoardUiDataState {
  final bool isLoading;
  final String? errorMessage;
  final DomainUser? user;
  final DomainSubscription? subscription;
  final List<DomainPlan> plans;
  final List<DomainNotice> notices;
  final List<WyxOrderInfo> orders;
  final List<WyxNodeInfo> nodes;
  final DateTime? lastUpdated;

  const WyxV2BoardUiDataState({
    this.isLoading = false,
    this.errorMessage,
    this.user,
    this.subscription,
    this.plans = const [],
    this.notices = const [],
    this.orders = const [],
    this.nodes = const [],
    this.lastUpdated,
  });

  WyxV2BoardUiDataState copyWith({
    bool? isLoading,
    String? errorMessage,
    DomainUser? user,
    DomainSubscription? subscription,
    List<DomainPlan>? plans,
    List<DomainNotice>? notices,
    List<WyxOrderInfo>? orders,
    List<WyxNodeInfo>? nodes,
    DateTime? lastUpdated,
  }) {
    return WyxV2BoardUiDataState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      user: user ?? this.user,
      subscription: subscription ?? this.subscription,
      plans: plans ?? this.plans,
      notices: notices ?? this.notices,
      orders: orders ?? this.orders,
      nodes: nodes ?? this.nodes,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  WyxV2BoardUiDataState clear() {
    return const WyxV2BoardUiDataState();
  }
}
