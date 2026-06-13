# CONFIG_SECURITY.md

RemoteConfig 是高风险入口，必须保持最小权限。

允许远程更新：

1. `securityBaseUrl`
2. `backupSecurityBaseUrls`
3. secure-v2 `keyId`
4. secure-v2 `publicKey`
5. 官网、客服、隐私政策、用户协议、更新地址
6. 平台下载地址
7. 公告内容
8. 维护模式
9. 强制更新和最低版本
10. 功能开关

禁止字段：

1. 真实 V2Board 后端地址
2. `BACKEND_DOMAIN`
3. `SEC_PASSWORD`
4. secure-v2 私钥
5. 管理员账号密码
6. 用户 token
7. 真实订阅链接
8. 数据库信息
9. 任意脚本、代码或可执行片段

代码会对明显危险字段做基础拦截，并要求远程 URL 使用 HTTPS。RemoteConfig 使用独立 `SafeRemoteConfigHttpClient`，基于 `package:http` 默认客户端，不使用项目中已有的 `badCertificateCallback => true` HTTP 逻辑。

当前拦截是保守策略：字段名中出现 `BACKEND_DOMAIN`、`SEC_PASSWORD`、`privateKey`、`authorization`、`token`、`subscribe_url`、`cookie`、数据库、脚本或代码执行相关字段时，配置会被拒绝。后续如果业务确实需要某个同名公开字段，必须先做安全评审并改成更窄的 schema 字段。

不要关闭 TLS 证书验证。签名校验用于防止托管配置被篡改，TLS 用于保护传输，两者不能互相替代。
