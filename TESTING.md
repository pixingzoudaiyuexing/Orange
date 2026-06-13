# TESTING.md

## 本地测试

```bash
flutter pub get
dart format --set-exit-if-changed lib/config lib/security lib/xboard/wyx_v2board test/config test/security test/xboard/wyx_v2board
flutter test test/config/remote_config_test.dart test/security/secure_http_client_test.dart test/xboard/wyx_v2board/wyx_v2board_adapter_test.dart
flutter analyze
```

如果 `flutter analyze` 因上游既有问题失败，需要区分：

1. `lib/security/` 和 `test/security/` 的新增问题
2. Orange 上游已有问题

## 当前依赖修复记录

使用 Flutter 3.44.x 时，SecureHttpClient 测试前置依赖解析需要先处理 Orange 既有依赖约束。当前修复为：

1. `re_editor` 从易漂移的 GitHub `main` 依赖切换到 pub.dev `^0.7.0`。
2. `material_color_utilities` 更新到 `^0.13.0`，匹配当前 Flutter SDK pin。
3. 移除本阶段测试不需要的 `custom_lint`、`riverpod_lint`、`riverpod_generator`、`freezed` dev dependencies，避免与 Flutter 3.44.x 自带 `flutter_test` 的 `matcher` / `test_api` pin 冲突。

这些依赖问题不属于 `lib/security/` 的 SecureHttpClient 实现，但会阻止 `flutter pub get`、`flutter test` 和 `flutter analyze` 启动。后续如需要代码生成或 custom lint，应单独恢复并匹配当前 Flutter/Dart 的兼容版本。

## secure-v2 staging 验证

本阶段未提交真实 staging 账号、密码或私钥。脚本必须从环境变量读取：

```bash
export SECURITY_BASE_URL="https://security.example.com"
export SECURE_V2_KEY_ID="staging-2026-01"
export SECURE_V2_PUBLIC_KEY="$(cat secure-v2-public.pem)"
export TEST_USER_EMAIL="user@example.com"
export TEST_USER_PASSWORD="replace-me"
```

运行：

```bash
dart run tool/secure_v2_staging_check.dart
```

该脚本会验证：

1. `/api/v1/passport/auth/login`
2. `/api/v1/user/info`
3. `/api/v1/user/getSubscribe`
4. 完整 URL、`..`、反斜杠、query 混入 path 会被本地拒绝
5. 响应 ciphertext 可以被 Dart 端解密

`requestId` 不匹配由单元测试 `secure_http_client_test.dart` 覆盖。staging 入口返回的 requestId 由中间件生成，正常流程不会主动篡改响应；如需实机负向验证，可在本地 mock transport 或中间件测试环境里临时返回错误 requestId。

测试脚本不得写死账号密码，不得打印 password、token、authorization 或 subscribe_url。输出必须经过 `SensitiveLogMasker`。

## 日志脱敏检查

`SensitiveLogMasker` 需要遮罩：

1. `password`
2. `passwd`
3. `token`
4. `authorization`
5. `subscribe_url`
6. `subscribeUrl`
7. `access_token`
8. `refresh_token`
9. `cookie`
10. `set-cookie`
11. `encryptedKey`
12. `ciphertext`
13. 完整邮箱

## WyxV2BoardAdapter 测试

本阶段只测试数据适配层，不需要真实账号：

```bash
dart format --set-exit-if-changed lib/xboard/wyx_v2board test/xboard/wyx_v2board
flutter test test/xboard/wyx_v2board/wyx_v2board_adapter_test.dart
dart analyze lib/xboard/wyx_v2board test/xboard/wyx_v2board
```

测试覆盖：

1. 登录解析 `data.token` 和 `data.auth_data`。
2. 登录后保存 `authData`。
3. 用户接口使用 `Authorization: <auth_data 原值>`。
4. 不给 `auth_data` 添加 `Bearer` 前缀。
5. 订阅信息解析 `subscribe_url` 和套餐信息。
6. `plan.content` 是 JSON 字符串时解析 feature。
7. `plan.content` 异常时不崩溃。
8. 节点、套餐、公告、订单列表解析。
9. 403 转换为未登录或登录过期错误。
10. `token`、`auth_data`、`authorization`、`subscribe_url`、`password` 脱敏。

真实 staging 互通先通过 `tool/secure_v2_staging_check.dart` 验证 secure-v2 链路。Adapter staging 脚本后续接入时也必须从环境变量读取账号、公钥和安全中间件地址，不允许写入代码。
