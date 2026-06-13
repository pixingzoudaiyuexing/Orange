class WyxV2BoardApi {
  static const login = '/api/v1/passport/auth/login';
  static const userInfo = '/api/v1/user/info';
  static const subscribeInfo = '/api/v1/user/getSubscribe';
  static const nodeList = '/api/v1/user/server/fetch';
  static const planList = '/api/v1/user/plan/fetch';
  static const noticeList = '/api/v1/user/notice/fetch';
  static const inviteInfo = '/api/v1/user/invite/fetch';
  static const orderList = '/api/v1/user/order/fetch';
  static const orderDetail = '/api/v1/user/order/detail';
  static const orderSave = '/api/v1/user/order/save';
  static const orderCheckout = '/api/v1/user/order/checkout';
  static const couponCheck = '/api/v1/user/coupon/check';
  static const clientAppConfig = '/api/v1/client/app/getConfig';
  static const clientAppVersion = '/api/v1/client/app/getVersion';

  const WyxV2BoardApi._();
}
