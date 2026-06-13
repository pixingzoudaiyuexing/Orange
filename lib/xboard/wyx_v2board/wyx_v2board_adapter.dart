import 'package:fl_clash/security/security.dart';

import 'wyx_v2board_api.dart';
import 'wyx_v2board_errors.dart';
import 'wyx_v2board_mapper.dart';
import 'wyx_v2board_models.dart';

abstract interface class WyxV2BoardSecureClient {
  Future<SecureResponse> get(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
  });

  Future<SecureResponse> post(
    String path, {
    Object? body,
    Map<String, String>? query,
    Map<String, String>? headers,
  });
}

class SecureHttpWyxV2BoardClient implements WyxV2BoardSecureClient {
  final SecureHttpClient _client;

  const SecureHttpWyxV2BoardClient(this._client);

  @override
  Future<SecureResponse> get(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
  }) {
    return _client.get(path, query: query, headers: headers);
  }

  @override
  Future<SecureResponse> post(
    String path, {
    Object? body,
    Map<String, String>? query,
    Map<String, String>? headers,
  }) {
    return _client.post(path, body: body, query: query, headers: headers);
  }
}

class WyxV2BoardAdapter {
  final WyxV2BoardSecureClient _client;
  final SensitiveLogMasker _masker;

  WyxAuthSession? _session;

  WyxV2BoardAdapter({
    required WyxV2BoardSecureClient client,
    SensitiveLogMasker masker = const SensitiveLogMasker(),
  })  : _client = client,
        _masker = masker;

  WyxV2BoardAdapter.withSecureHttpClient(
    SecureHttpClient client, {
    SensitiveLogMasker masker = const SensitiveLogMasker(),
  }) : this(
          client: SecureHttpWyxV2BoardClient(client),
          masker: masker,
        );

  WyxAuthSession? get currentSession => _session;
  bool get isLoggedIn => _session?.authData.isNotEmpty == true;

  Future<WyxLoginResult> login(String email, String password) async {
    final response = await _post(
      WyxV2BoardApi.login,
      body: {
        'email': email,
        'password': password,
      },
      requiresAuth: false,
      operation: 'login',
    );
    final data = _dataMap(response, operation: 'login');
    final token = WyxV2BoardMapper.string(data['token']) ?? '';
    final authData = WyxV2BoardMapper.string(data['auth_data']) ?? '';
    if (authData.isEmpty) {
      throw const WyxV2BoardException(
        code: WyxV2BoardErrorCode.loginFailed,
        message: 'Login response missing auth_data',
        safeDebugMessage: 'auth_data is empty',
      );
    }
    final session = WyxAuthSession(
      token: token,
      authData: authData,
      isAdmin: WyxV2BoardMapper.boolean(data['is_admin']),
    );
    _session = session;
    return WyxLoginResult(session: session);
  }

  void logout() {
    _session = null;
  }

  Future<WyxUserInfo> getUserInfo() async {
    final response = await _get(WyxV2BoardApi.userInfo, operation: 'userInfo');
    return WyxV2BoardMapper.userInfo(_dataMap(response, operation: 'userInfo'));
  }

  Future<WyxSubscribeInfo> getSubscribeInfo() async {
    final response = await _get(
      WyxV2BoardApi.subscribeInfo,
      operation: 'subscribeInfo',
    );
    return WyxV2BoardMapper.subscribeInfo(
      _dataMap(response, operation: 'subscribeInfo'),
    );
  }

  Future<String?> getSubscribeUrl() async {
    final subscribeInfo = await getSubscribeInfo();
    return subscribeInfo.subscribeUrl;
  }

  Future<List<WyxNodeInfo>> getNodeList() async {
    final response = await _get(WyxV2BoardApi.nodeList, operation: 'nodeList');
    return WyxV2BoardMapper.listMaps(_data(response))
        .map(WyxV2BoardMapper.nodeInfo)
        .toList(growable: false);
  }

  Future<List<WyxPlanInfo>> getPlanList() async {
    final response = await _get(WyxV2BoardApi.planList, operation: 'planList');
    return WyxV2BoardMapper.listMaps(_data(response))
        .map(WyxV2BoardMapper.planInfo)
        .toList(growable: false);
  }

  Future<List<WyxNotice>> getNoticeList() async {
    final response = await _get(
      WyxV2BoardApi.noticeList,
      operation: 'noticeList',
    );
    return WyxV2BoardMapper.listMaps(_data(response))
        .map(WyxV2BoardMapper.notice)
        .toList(growable: false);
  }

  Future<WyxInviteInfo> getInviteInfo() async {
    final response = await _get(
      WyxV2BoardApi.inviteInfo,
      operation: 'inviteInfo',
    );
    return WyxV2BoardMapper.inviteInfo(
      _dataMap(response, operation: 'inviteInfo'),
    );
  }

  Future<List<WyxOrderInfo>> getOrderList() async {
    final response = await _get(
      WyxV2BoardApi.orderList,
      operation: 'orderList',
    );
    return WyxV2BoardMapper.listMaps(_data(response))
        .map(WyxV2BoardMapper.orderInfo)
        .toList(growable: false);
  }

  Future<WyxOrderInfo> getOrderDetail(String orderId) async {
    final response = await _get(
      WyxV2BoardApi.orderDetail,
      query: {'trade_no': orderId},
      operation: 'orderDetail',
    );
    return WyxV2BoardMapper.orderInfo(
      _dataMap(response, operation: 'orderDetail'),
    );
  }

  Future<String> getPaymentRedirectUrl(String orderId) {
    throw const WyxV2BoardException(
      code: WyxV2BoardErrorCode.notImplemented,
      message: 'Payment redirect is not implemented in the data adapter stage',
      safeDebugMessage: 'requires payment method selection',
    );
  }

  Future<Object?> checkCoupon(String code) {
    throw const WyxV2BoardException(
      code: WyxV2BoardErrorCode.notImplemented,
      message: 'Coupon check is not implemented in the data adapter stage',
      safeDebugMessage: 'requires plan_id and period mapping',
    );
  }

  Future<Object?> getClientAppConfig() {
    throw const WyxV2BoardException(
      code: WyxV2BoardErrorCode.notImplemented,
      message: 'Client app config is not implemented in the data adapter stage',
    );
  }

  Future<Object?> getClientAppVersion() {
    throw const WyxV2BoardException(
      code: WyxV2BoardErrorCode.notImplemented,
      message:
          'Client app version is not implemented in the data adapter stage',
    );
  }

  Future<SecureResponse> _get(
    String path, {
    Map<String, String>? query,
    required String operation,
  }) async {
    return _send(
      () => _client.get(path, query: query, headers: _authHeaders()),
      operation: operation,
    );
  }

  Future<SecureResponse> _post(
    String path, {
    Object? body,
    bool requiresAuth = true,
    required String operation,
  }) async {
    return _send(
      () => _client.post(
        path,
        body: body,
        headers: requiresAuth ? _authHeaders() : null,
      ),
      operation: operation,
    );
  }

  Future<SecureResponse> _send(
    Future<SecureResponse> Function() action, {
    required String operation,
  }) async {
    try {
      final response = await action();
      _ensureSuccess(response, operation: operation);
      return response;
    } on SecureHttpException catch (error) {
      throw WyxV2BoardException.fromSecureHttp(error);
    }
  }

  Map<String, String> _authHeaders() {
    final authData = _session?.authData;
    if (authData == null || authData.isEmpty) {
      throw const WyxV2BoardException(
        code: WyxV2BoardErrorCode.unauthenticated,
        message: 'User is not logged in',
        safeDebugMessage: 'missing auth_data',
      );
    }
    return {'authorization': authData};
  }

  void _ensureSuccess(SecureResponse response, {required String operation}) {
    if (response.isSuccess) {
      return;
    }
    final message = _safeMessage(response.body);
    if (response.status == 403) {
      throw WyxV2BoardException(
        code: WyxV2BoardErrorCode.unauthenticated,
        message: message ?? 'User is not logged in or session expired',
        statusCode: response.status,
        requestId: response.requestId,
        safeDebugMessage: operation,
      );
    }
    throw WyxV2BoardException(
      code: WyxV2BoardErrorCode.backendError,
      message: message ?? 'WyxV2Board backend request failed',
      statusCode: response.status,
      requestId: response.requestId,
      safeDebugMessage: operation,
    );
  }

  Object? _data(SecureResponse response) {
    final body = WyxV2BoardMapper.mapOrNull(response.body);
    if (body == null) {
      return null;
    }
    return body['data'];
  }

  Map<String, dynamic> _dataMap(
    SecureResponse response, {
    required String operation,
  }) {
    final data = _data(response);
    final map = WyxV2BoardMapper.mapOrNull(data);
    if (map != null) {
      return map;
    }
    throw WyxV2BoardException(
      code: WyxV2BoardErrorCode.invalidResponse,
      message: 'WyxV2Board response data is invalid',
      statusCode: response.status,
      requestId: response.requestId,
      safeDebugMessage: operation,
    );
  }

  String? _safeMessage(Object? body) {
    final bodyMap = WyxV2BoardMapper.mapOrNull(body);
    final message = WyxV2BoardMapper.string(bodyMap?['message']);
    if (message == null || message.isEmpty) {
      return null;
    }
    return _masker.maskText(message);
  }
}
