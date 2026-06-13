# WYXV2BOARD_ADAPTER.md

## 目标

`WyxV2BoardAdapter` 是 wyx2685/v2board 的数据适配层。它只负责通过 `SecureHttpClient` 调用安全中间件，并把响应转换成客户端可用的 Dart 模型。

本阶段不接入 UI，不替换现有 XBoard / V2Board / XV2B 逻辑。

## 放置位置

代码位于：

```text
lib/xboard/wyx_v2board/
```

选择该位置的原因：

1. 它属于 Orange 现有 `xboard` 业务域。
2. 现有 `flutter_xboard_sdk` 使用普通 HTTP/Dio，不适合本阶段的 secure-v2 强制链路。
3. 独立目录可以避免影响现有 XBoard SDK、页面、provider 和路由。

## 认证差异

wyx2685/v2board 登录接口返回：

```json
{
  "data": {
    "token": "...",
    "auth_data": "..."
  }
}
```

用户 API 必须使用：

```text
Authorization: <auth_data 原值>
```

不要使用 `data.token` 作为 Authorization。不要自动添加 `Bearer` 前缀。wyx2685/v2board 的用户中间件会直接把 `authorization` 交给 `AuthService::decryptAuthData()`，添加 `Bearer` 会导致解密失败并返回 403。

`token` 主要用于订阅相关信息，不等同于用户 API 登录态。

## 已实现接口

1. `login(email, password)`
2. `logout()`
3. `getUserInfo()`
4. `getSubscribeInfo()`
5. `getSubscribeUrl()`
6. `getNodeList()`
7. `getPlanList()`
8. `getNoticeList()`
9. `getInviteInfo()`
10. `getOrderList()`
11. `getOrderDetail(orderId)`

## 暂未实现接口

以下接口保留在 adapter API 中，但本阶段不会执行业务逻辑：

1. `getPaymentRedirectUrl(orderId)`
2. `checkCoupon(code)`
3. `getClientAppConfig()`
4. `getClientAppVersion()`

原因：支付跳转和优惠券通常需要更多 UI/业务上下文，例如支付方式、套餐周期、订单状态处理。客户端版本接口后续应和 RemoteConfig / 更新模块一起设计。

## 安全要求

Adapter 必须：

1. 只通过 `SecureHttpClient` 或 `WyxV2BoardSecureClient` 抽象发起请求。
2. 不出现真实 V2Board 后端地址。
3. 不出现 `BACKEND_DOMAIN`。
4. 不出现 `SEC_PASSWORD`。
5. 不保存用户密码。
6. 不把 `token`、`auth_data`、`authorization`、`subscribe_url`、`password` 原样写入日志。
7. 不降级到 secure-v1。

## 模型

当前定义的模型：

1. `WyxLoginResult`
2. `WyxAuthSession`
3. `WyxUserInfo`
4. `WyxSubscribeInfo`
5. `WyxPlanInfo`
6. `WyxPlanFeature`
7. `WyxNotice`
8. `WyxNodeInfo`
9. `WyxOrderInfo`
10. `WyxInviteInfo`

模型保留原始字节流量值。UI 后续负责格式化。

## plan.content

`plan.content` 在 wyx2685/v2board 中可能是 JSON 字符串。Adapter 会尝试解析成 `List<WyxPlanFeature>`。解析失败时返回空列表，不抛出异常。

## 测试

本阶段使用 mock `WyxV2BoardSecureClient`，不需要真实账号：

```bash
flutter test test/xboard/wyx_v2board/wyx_v2board_adapter_test.dart
dart analyze lib/xboard/wyx_v2board test/xboard/wyx_v2board
```

staging 互通仍使用 SecureHttpClient 阶段的：

```bash
dart run tool/secure_v2_staging_check.dart
```

不要把 staging 账号、密码、公钥写入代码。
