import 'dart:async';

import 'package:fl_clash/enum/enum.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/security/security.dart';
import 'package:fl_clash/state.dart';

import '../../core/core.dart';
import '../../domain/domain.dart';
import '../../features/profile/providers/profile_import_provider.dart';
import '../../features/profile/services/profile_import_service.dart';
import '../../services/services.dart';
import '../wyx_v2board.dart';
import 'wyx_v2board_domain_mapper.dart';
import 'wyx_v2board_providers.dart';
import 'wyx_v2board_ui_helpers.dart';
import 'wyx_v2board_ui_state.dart';

final _logger = FileLogger('wyx_v2board_ui_controller.dart');
const _masker = SensitiveLogMasker();
const _profileImportCooldown = Duration(seconds: 30);

final wyxV2BoardUiControllerProvider =
    StateNotifierProvider<WyxV2BoardUiController, WyxV2BoardUiDataState>((ref) {
      return WyxV2BoardUiController(ref);
    });

class WyxV2BoardUiController extends StateNotifier<WyxV2BoardUiDataState> {
  final Ref _ref;
  DateTime? _lastRestoreImportAttemptAt;

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
      unawaited(_importSubscriptionProfileIfNeededOnRestore());
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

      final rawSubscribeUrl = subscribeInfo.subscribeUrl ?? '';
      final subscription = WyxV2BoardDomainMapper.subscription(subscribeInfo);
      final safeSubscription = subscription.copyWith(
        subscribeUrl: '',
        token: null,
      );
      final user = WyxV2BoardDomainMapper.user(
        userInfo,
        subscribe: subscribeInfo,
      );
      await _storage.saveDomainUser(user);
      await _storage.saveDomainSubscription(safeSubscription);
      _publishHomeData(user: user, subscription: safeSubscription);
      state = state.copyWith(isLoading: false, errorMessage: null);

      if (importSubscription && rawSubscribeUrl.isNotEmpty) {
        _logger.info(
          'wyx_v2board importing subscription URL: '
          '${_maskSensitiveText(rawSubscribeUrl)}',
        );
        unawaited(_importSubscriptionProfile(rawSubscribeUrl));
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
      if (!adapter.isLoggedIn) {
        state = state.copyWith(isLoading: false, nodesLoaded: true);
        return state.nodes;
      }
      final nodes = await adapter.getNodeList();
      state = state.copyWith(
        isLoading: false,
        nodes: nodes,
        nodesLoaded: true,
        lastUpdated: DateTime.now(),
      );
      return nodes;
    } on WyxV2BoardException catch (error) {
      if (error.code == WyxV2BoardErrorCode.unauthenticated) {
        state = state.copyWith(isLoading: false, nodesLoaded: true);
        return state.nodes;
      }
      state = state.copyWith(
        isLoading: false,
        nodesLoaded: true,
        nodes: state.nodes,
        errorMessage: WyxV2BoardUiErrorMapper.message(error),
      );
      rethrow;
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
    await _cleanupWyxGeneratedProfile();
    _publishHomeData(user: null, subscription: null);
    state = state.clear();
  }

  Future<void> _importSubscriptionProfile(String subscribeUrl) async {
    try {
      final imported = await _ref
          .read(profileImportProvider.notifier)
          .importSubscription(
            subscribeUrl,
            persistUrl: false,
            source: wyxV2BoardProfileSource,
            allowEncryptedService: false,
          );
      if (!imported) {
        _logger.warning('wyx_v2board subscription profile import failed');
      }
    } catch (error) {
      _logger.warning(
        'wyx_v2board subscription profile import failed: '
        '${_maskSensitiveText(error)}',
      );
    }
  }

  Future<void> _importSubscriptionProfileIfNeededOnRestore() async {
    if (!_shouldImportProfileOnRestore()) {
      return;
    }
    _lastRestoreImportAttemptAt = DateTime.now();
    try {
      final adapter = await _adapter();
      if (!adapter.isLoggedIn) {
        return;
      }
      final subscribe = await adapter.getSubscribeInfo();
      final subscribeUrl = subscribe.subscribeUrl ?? '';
      if (subscribeUrl.isEmpty) {
        return;
      }
      _logger.info('wyx_v2board restored session requires profile import');
      await _importSubscriptionProfile(subscribeUrl);
    } catch (error) {
      _logger.warning(
        'wyx_v2board restored session profile import skipped: '
        '${_maskSensitiveText(error)}',
      );
    }
  }

  bool _shouldImportProfileOnRestore() {
    final now = DateTime.now();
    final lastAttempt = _lastRestoreImportAttemptAt;
    if (lastAttempt != null &&
        now.difference(lastAttempt) < _profileImportCooldown) {
      return false;
    }

    final profiles = globalState.config.profiles;
    final currentProfile = profiles.getProfile(
      globalState.config.currentProfileId,
    );
    final groups = globalState.appState.groups;
    final importState = _ref.read(profileImportProvider);
    if (importState.isImporting) {
      return false;
    }
    if (importState.lastResult?.isSuccess == false) {
      return true;
    }
    if (currentProfile == null) {
      return true;
    }
    if (currentProfile.label != wyxV2BoardProfileLabel) {
      return true;
    }
    return groups.isEmpty;
  }

  Future<void> _cleanupWyxGeneratedProfile() async {
    try {
      final profiles = globalState.config.profiles;
      final currentProfileId = globalState.config.currentProfileId;
      final wyxProfiles = profiles
          .where(
            (profile) =>
                profile.label == wyxV2BoardProfileLabel &&
                profile.type == ProfileType.file,
          )
          .toList(growable: false);

      if (wyxProfiles.isEmpty) {
        return;
      }

      for (final profile in wyxProfiles) {
        _ref.read(profilesProvider.notifier).deleteProfileById(profile.id);
        await globalState.appController.clearEffect(profile.id);
      }

      if (wyxProfiles.any((profile) => profile.id == currentProfileId)) {
        final remainingProfiles = globalState.config.profiles;
        _ref.read(currentProfileIdProvider.notifier).value =
            remainingProfiles.isEmpty ? null : remainingProfiles.first.id;
      }

      _logger.info(
        'wyx_v2board cleaned ${wyxProfiles.length} generated profile(s)',
      );
    } catch (error) {
      _logger.warning('wyx_v2board generated profile cleanup skipped');
    }
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

String _maskSensitiveText(Object? value) {
  final masked = _masker.maskText('$value');
  return masked.replaceAllMapped(
    RegExp(r'https?:\/\/[^\s",)]+', caseSensitive: false),
    (match) {
      final text = match.group(0)!;
      return text.startsWith('https://') ? 'https********' : 'http********';
    },
  );
}
