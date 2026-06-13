# WyxV2Board UI Integration

本阶段只做最小可用 UI 数据接入，不做品牌化、不打包、不改 Clash core、TUN、系统代理、托盘或支付流程。

## 接入范围

链路：

```text
RemoteConfig
-> SecureHttpClient
-> WyxV2BoardAdapter
-> Orange existing XBoard UI providers
```

已接入：

1. 登录页继续调用 `xboardUserProvider.login()`，内部按 `backend_type` 分支到 WyxV2BoardAdapter。
2. 登录成功后保存 `auth_data`、`token`、`is_admin` 和邮箱。
3. 首页继续读取现有 `DomainUser` / `DomainSubscription` 状态。
4. 套餐列表和公告摘要在 `wyx_v2board` 后端类型下走 WyxV2BoardAdapter。
5. 新增数据层 staging 脚本 `tool/wyx_v2board_ui_data_staging_check.dart`，用于验证 UI 所需数据摘要。

未接入：

1. 支付、购买、续费流程。
2. UI 品牌、图标、应用名称。
3. Clash core、TUN、系统代理、托盘、连接逻辑。
4. Wyx 节点到 Clash 出站配置的完整转换。

## backendType

在 `assets/config/xboard.config.yaml` 中配置：

```yaml
xboard:
  backend_type: wyx_v2board
```

默认示例仍为 `xboard`，避免影响旧 XBoard/V2Board/XV2B 流程。`wyx_v2board` 分支不会初始化旧 `flutter_xboard_sdk` 面板直连流程。

## 认证规则

wyx2685/v2board 登录返回 `data.token` 和 `data.auth_data`。

客户端后续用户接口必须使用：

```text
Authorization: <auth_data 原值>
```

不要使用 `token` 作为 Authorization，不要添加 `Bearer` 前缀。密码不保存；`auth_data`、`token`、`authorization`、`subscribe_url` 和完整邮箱不得写日志。

## RemoteConfig 初始化

`wyxV2BoardAdapterProvider` 会创建：

```text
RemoteConfigRepository.create()
-> loadInitialConfig()
-> refreshRemoteConfig()
-> createSecureHttpClient()
-> WyxV2BoardAdapter.withSecureHttpClient()
```

RemoteConfig 失败时沿用模块已有 last-known-good / bootstrap fallback。UI 层不处理 RSA/AES 细节，也不知道真实 V2Board 后端地址。

## 登录态存储

本阶段复用 Orange 现有 `XBoardStorageService` / SharedPreferences 存储方式：

1. `wyx_v2board_auth_data`
2. `wyx_v2board_token`
3. `wyx_v2board_is_admin`
4. `xboard_user_email`

风险：SharedPreferences 不是强安全存储。后续应单独迁移到 `flutter_secure_storage` 或平台 Keychain/Credential Locker。本阶段不保存用户密码；在 `wyx_v2board` 分支下，即使用户勾选记住密码，也只保存邮箱。

## 首页字段映射

`getUserInfo()` 和 `getSubscribeInfo()` 映射到：

1. 邮箱：`email`
2. 套餐名称：`subscribe.plan.name`
3. 总流量：`transfer_enable`
4. 已用流量：`u + d`
5. 剩余流量：`transfer_enable - u - d`
6. 到期时间：`expired_at`
7. 设备限制：`device_limit`
8. 在线设备：`alive_ip`，保存到 metadata
9. 封禁状态：`banned`

UI 继续使用现有格式化逻辑显示流量和时间。

## Staging 数据层验证

```bash
export SECURITY_BASE_URL="https://security.example.com"
export SECURE_V2_KEY_ID="staging-2026-01"
export SECURE_V2_PUBLIC_KEY="$(cat secure-v2-public.pem)"
export TEST_USER_EMAIL="user@example.com"
export TEST_USER_PASSWORD="replace-me"

dart run tool/wyx_v2board_ui_data_staging_check.dart
```

脚本验证 login、home data、subscribe 摘要、plan-list、notice-list、order-list、node-list 和 logout。输出只打印摘要，节点地址、密码、token、auth_data、authorization、subscribe_url 和完整邮箱会脱敏。

## 当前测试环境限制

Orange 当前源码声明了大量 Freezed `part 'generated/*.freezed.dart'`，但主项目没有可用的 `freezed` builder 依赖；`dart run build_runner build` 会提示 `unknown builder freezed:freezed` 并写入 0 个输出。因此完整 `flutter analyze` 会在既有 Domain/UI 模型上报缺失生成文件问题。

不建议在本阶段升级 Freezed 依赖：`freezed 2.x` 与当前 Flutter SDK/test 组合冲突，`freezed 3.x` 又要求升级 `freezed_annotation`，而内置 `flutter_xboard_sdk` 固定 `freezed_annotation ^2.4.1`。
