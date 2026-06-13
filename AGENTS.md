# AGENTS.md

你是本项目的严谨工程代理，负责协助开发、测试、重构和文档维护。

## 工作原则

1. 先分析，再修改。
2. 先小步改动，再逐步扩展。
3. 不要一次性重构整个项目。
4. 修改前说明计划。
5. 修改后说明改了哪些文件。
6. 能运行测试就必须运行测试。
7. 没有运行测试就不要声称测试通过。
8. 如果无法测试，说明原因和缺少的环境。
9. 不要硬编码密钥、token、账号、密码、真实后端地址。
10. 不要关闭 TLS 证书验证。
11. 不要在日志输出密码、token、订阅链接、真实后端域名。
12. 不要删除上游功能，除非明确说明原因。
13. 保留开源协议声明和第三方依赖 license。
14. 保持代码可维护、模块化、可配置。

## 法律和版权边界

1. 不允许反编译、复制、还原闭源软件源码。
2. 不允许复制闭源软件的 logo、图片、图标、文案、证书、密钥、接口地址。
3. 安装包只能作为黑盒功能参考。
4. UI 和代码必须原创或来自允许使用的开源协议。
5. 最终项目必须是合法的开源项目二次开发和原创改造。

## 客户端项目要求

客户端基于 Orange 二次开发。

目标平台：

1. Windows
2. macOS
3. Android
4. Linux

客户端必须通过安全中间件访问业务接口。  
客户端禁止直连真实 V2Board 后端。  
客户端禁止出现 BACKEND_DOMAIN、SEC_PASSWORD、私钥、管理员账号密码。

客户端只允许配置：

1. securityBaseUrl
2. backupSecurityBaseUrls
3. publicKey
4. keyId
5. brandName
6. websiteUrl
7. supportUrl
8. updateUrl
9. configUrls
10. configVerifyPublicKey

业务适配必须通过：

1. SecureHttpClient
2. WyxV2BoardAdapter

不要让 WyxV2BoardAdapter 直接使用普通 HTTP Client。

## 远程配置要求

客户端需要支持远程配置托管。

要求：

1. 支持多个 configUrls。
2. 支持 OSS / COS / GitHub Raw / CDN。
3. 远程配置必须签名。
4. 签名不通过不得生效。
5. 支持 last-known-good 缓存。
6. 支持配置失败切换。
7. 远程配置不能包含真实后端地址、SEC_PASSWORD、私钥、管理员账号密码。
8. 远程配置不能下发任意代码或脚本。
9. 远程配置不能关闭 TLS 验证。

## 测试要求

客户端修改后优先运行：

1. flutter analyze
2. flutter test
3. dart format 检查
4. 对应平台 build 命令

如果命令不存在，说明缺少的环境。
