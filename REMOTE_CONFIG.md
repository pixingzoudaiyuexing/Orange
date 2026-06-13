# REMOTE_CONFIG.md

RemoteConfig 模块位于 `lib/config/`，用于启动后从多个静态托管地址拉取客户端公开配置。

支持托管位置：

1. 阿里云 OSS
2. 腾讯云 COS
3. GitHub Raw
4. Cloudflare R2
5. 自建 CDN

客户端内置 bootstrap 配置，只包含公开字段：`configUrls`、配置签名公钥、默认公开配置。真实 V2Board 后端、`BACKEND_DOMAIN`、`SEC_PASSWORD`、私钥、管理员账号密码、用户 token 和真实订阅链接都禁止进入客户端和远程配置。

## 启动策略

1. 读取 last-known-good 缓存。
2. 没有缓存时使用内置默认配置。
3. 后台按 URL 顺序刷新远程配置。
4. preferred URL 会优先尝试，连续失败后回退默认顺序。
5. 下载成功后先验签，再检查版本、过期时间和危险字段。
6. 通过后保存为 last-known-good。
7. 远程失败时继续使用缓存或默认配置，不让客户端崩溃。
8. `304 Not Modified` 只会复用已经验签过的当前配置或 last-known-good。

## 模块

- `bootstrap_config.dart`：内置示例 config URLs、测试签名公钥、默认配置。
- `config_models.dart`：配置模型和 canonical JSON。
- `config_signature_verifier.dart`：RSA-PSS-SHA256 签名校验。
- `config_cache.dart`：last-known-good、preferred URL、ETag 缓存。
- `remote_config_service.dart`：多 URL 拉取、签名校验、版本和安全校验。
- `remote_config_repository.dart`：面向上层的读取接口。

本阶段不接入 UI、SecureHttpClient 或 WyxV2BoardAdapter。
