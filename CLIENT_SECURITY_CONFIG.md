# CLIENT_SECURITY_CONFIG.md

客户端安全配置来自 RemoteConfig 的 `config.security` 字段。

允许客户端保存：

1. `securityBaseUrl`
2. `backupSecurityBaseUrls`
3. `secureProtocol`
4. `keyId`
5. `publicKey`

禁止客户端保存：

1. 真实 V2Board 后端地址
2. `BACKEND_DOMAIN`
3. `SEC_PASSWORD`
4. secure-v2 私钥
5. 管理员账号密码
6. 用户密码
7. 用户 token 的日志副本
8. 真实订阅链接的日志副本

`SEC_PASSWORD` 只服务 Web 前端 secure-v1，不允许进入客户端。客户端生产环境只使用 secure-v2，不做 secure-v1 自动降级。

`securityBaseUrl` 是安全中间件业务请求入口。`configUrls` 是 RemoteConfig 配置托管地址。两者是两套独立 failover，不要混用。
