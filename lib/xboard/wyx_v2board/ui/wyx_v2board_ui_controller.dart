import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/core.dart';
import '../../domain/domain.dart';
import '../../features/profile/providers/profile_import_provider.dart';
import '../../services/services.dart';
import '../wyx_v2board.dart';
import 'wyx_v2board_domain_mapper.dart';
import 'wyx_v2board_providers.dart';
import 'wyx_v2board_ui_helpers.dart';
import 'wyx_v2board_ui_state.dart';

final _logger = FileLogger('wyx_v2board_ui_controller.dart');

final wyxV2BoardUiControllerProvider =
    StateNotifierProvider<WyxV2BoardUiController, WyxV2BoardUiDataState>((ref) {
      return WyxV2BoardUiController(ref);
    });

class WyxV2BoardUiController extends StateNotifier<WyxV2BoardUiDataState> {
  final Ref _ref;

  WyxV2BoardUiController(this._ref) : super(const WyxV2BoardUiDataState());

  XBoardStorageService get _storage => _ref.read(storageServiceProvider);

  Future<WyxV2BoardAdapterApi> _adapter() {
    return _ref.read(wyxV2BoardAdapterProvider.future);
  }

  Future<bool> restoreSession() async {
    try {
      final sessionResult = await _storage.getWyxAuthSession();
      final sessionData = sessionResult.dataOrNull;
      if (sessionData == null) {
        return false;
      }

      final authData = sessionData['authData'] as String? ?? '';
      if (authData.isEmpty) {
        return false;
      }

      final adapter = await _adapter();
      adapter.restoreSession(
        WyxAuthSession(
          token: sessionData['token'] as String? ?? '',
          authData: authData,
          isAdmin: sessionData['isAdmin'] as bool? ?? false,
        ),
      );

      final email = (await _storage.getUserEmail()).dataOrNull;
      final user = (await _storage.getDomainUser()).dataOrNull;
      final subscription = (await _storage.getDomainSubscription()).dataOrNull;
      _publishHomeData(user: user, subscription: subscription);
      _logger.info('wyx_v2board session restored for ${_maskEmail(email)}');
      return true;
    } catch (error) {
      _logger.warning('wyx_v2board session restore failed', error);
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final adapter = await _adapter();
      final login = await adapter.login(email, password);
      await _storage.saveUserEmail(email);
      await _storage.saveWyxAuthSession(
        authData: login.session.authData,
        token: login.session.token,
        isAdmin: login.session.isAdmin,
      );

      await loadHomeData(importSubscription: true);
      state = state.copyWith(isLoading: false, lastUpdated: DateTime.now());
      _logger.info('wyx_v2board login succeeded for ${_maskEmail(email)}');
      return true;
    } on WyxV2BoardException catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: WyxV2BoardUiErrorMapper.message(error),
      );
      return false;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: WyxV2BoardUiErrorMapper.message(error),
      );
      return false;
    }
  }

  Future<void> loadHomeData({bool importSubscription = false}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final adapter = await _adapter();
      final userFuture = adapter.getUserInfo();
      final subscriptionFuture = adapter.getSubscribeInfo();
      final results = await Future.wait([userFuture, subscriptionFuture]);
      final userInfo = results[0] as WyxUserInfo;
      final subscribeInfo = results[1] as WyxSubscribeInfo;

      final subscription = WyxV2BoardDomainMapper.subscription(subscribeInfo);
      final user = WyxV2BoardDomainMapper.user(
        userInfo,
        subscribe: subscribeInfo,
      );
      await _storage.saveDomainUser(user);
      await _storage.saveDomainSubscription(subscription);
      _publishHomeData(user: user, subscription: subscription);
      state = state.copyWith(isLoading: false, errorMessage: null);

      if (importSubscription && subscription.subscribeUrl.isNotEmpty) {
        _logger.info('wyx_v2board importing subscription URL: [MASKED]');
        _ref
            .read(profileImportProvider.notifier)
            .importSubscription(subscription.subscribeUrl);
      }
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: WyxV2BoardUiErrorMapper.message(error),
      );
      rethrow;
    }
  }

  Future<List<DomainPlan>> loadPlans() async {
    final adapter = await _adapter();
    final plans = (await adapter.getPlanList())
        .map(WyxV2BoardDomainMapper.plan)
        .where((plan) => plan.isVisible)
        .toList(growable: false);
    state = state.copyWith(plans: plans, lastUpdated: DateTime.now());
    return plans;
  }

  Future<List<DomainNotice>> loadNotices() async {
    try {
      final adapter = await _adapter();
      final notices = (await adapter.getNoticeList())
          .map(WyxV2BoardDomainMapper.notice)
          .where((notice) => notice.isVisible)
          .toList(growable: false);
      state = state.copyWith(
        notices: notices,
        errorMessage: null,
        lastUpdated: DateTime.now(),
      );
      return notices;
    } catch (error) {
      state = state.copyWith(
        errorMessage: WyxV2BoardUiErrorMapper.message(error),
      );
      rethrow;
    }
  }

  Future<List<WyxOrderInfo>> loadOrders() async {
    final adapter = await _adapter();
    final orders = await adapter.getOrderList();
    state = state.copyWith(orders: orders, lastUpdated: DateTime.now());
    return orders;
  }

  Future<List<WyxNodeInfo>> loadNodes() async {
    state = state.copyWith(isLoading: state.nodes.isEmpty, errorMessage: null);
    try {
      final adapter = await _adapter();
      final nodes = await adapter.getNodeList();
      state = state.copyWith(
        isLoading: false,
        nodes: nodes,
        nodesLoaded: true,
        lastUpdated: DateTime.now(),
      );
      return nodes;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        nodesLoaded: true,
        nodes: state.nodes,
        errorMessage: WyxV2BoardUiErrorMapper.message(error),
      );
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      final adapter = await _adapter();
      adapter.logout();
    } catch (_) {
      // Adapter creation may fail while logging out; storage cleanup is enough.
    }
    await _storage.clearWyxAuthSession();
    await _storage.clearAuthData();
    _publishHomeData(user: null, subscription: null);
    state = state.clear();
  }

  void _publishHomeData({
    required DomainUser? user,
    required DomainSubscription? subscription,
  }) {
    state = state.copyWith(
      user: user,
      subscription: subscription,
      lastUpdated: DateTime.now(),
    );
  }

  String _maskEmail(String? email) {
    if (email == null || email.isEmpty) {
      return '[EMPTY]';
    }
    final at = email.indexOf('@');
    if (at <= 1) {
      return '***${at >= 0 ? email.substring(at) : ''}';
    }
    return '${email[0]}***${email.substring(at)}';
  }
}
