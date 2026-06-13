# SECURE_HTTP_CLIENT.md

`SecureHttpClient` 位于 `lib/security/`，是 Orange 客户端后续访问业务 API 的安全入口。

链路：

```text
Orange Client -> SecureHttpClient -> securityBaseUrl/secure-v2/proxy -> Security Middleware -> V2Board Backend
```

客户端只知道安全中间件地址，不知道真实 V2Board 后端地址。

## 模块

- `secure_config.dart`：安全中间件地址、keyId、公钥、平台和版本。
- `secure_request.dart`：业务请求 payload，校验 method/path/header。
- `secure_response.dart`：解密后的响应模型。
- `secure_crypto_service.dart`：AES-256-GCM 和 RSA-OAEP-SHA256。
- `secure_http_client.dart`：请求封装、secure-v2 wire format、base URL failover。
- `sensitive_log_masker.dart`：敏感字段脱敏。
- `secure_http_errors.dart`：统一错误对象。

## Base URL Failover

请求优先使用 `securityBaseUrl`。网络错误或 5xx 时尝试 `backupSecurityBaseUrls`。4xx secure-v2 拒绝不会切换地址，因为这通常是 keyId、timestamp、白名单或密文问题。

成功地址会作为本次运行的 preferred base URL。不会修改 RemoteConfig 缓存。

## Path 规则

`path` 必须：

1. 以 `/api/v1/` 开头
2. 是相对路径
3. 不包含完整 URL
4. 不包含 `..`
5. 不包含反斜杠
6. 不把 query 混入 path

query 必须单独通过 `query` 参数传入。

## TLS

SecureHttpClient 使用 `package:http` 默认客户端，不使用 `badCertificateCallback => true`，不关闭 TLS 证书验证。
