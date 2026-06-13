# CONFIG_FAILOVER.md

RemoteConfig failover 策略：

1. 启动先使用 last-known-good 或 bootstrap 默认配置。
2. 刷新时优先尝试 preferred URL。
3. preferred URL 连续失败达到阈值后清除，回到默认 URL 顺序。
4. 当前 URL 失败后尝试下一个 URL。
5. 所有 URL 失败时读取 last-known-good。
6. 缓存不存在或损坏时使用 bootstrap 默认配置。

HTTP 请求支持 `ETag` / `If-None-Match`。即使托管平台返回缓存内容，客户端仍然要求签名校验通过后才会保存新配置。`304 Not Modified` 时仅复用已验证的缓存或当前配置。

任何网络错误、解析错误、签名错误、过期配置、危险字段都会被隔离，不能覆盖 last-known-good。
