# CONFIG_SIGNATURE.md

RemoteConfig 使用 RSA-PSS-SHA256 签名。

选择原因：

1. Dart 端可用项目现有 `pointycastle` 实现，不新增依赖。
2. Node.js、OpenSSL 和多数 CI 环境都能生成和校验。
3. 比固定对称密钥更适合客户端只内置公钥的场景。

## 生成测试 key

```bash
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out config-signing-private.pem
openssl rsa -pubout -in config-signing-private.pem -out config-signing-public.pem
```

生产私钥只能放在离线签名环境或安全 CI Secret 中，不能提交到 GitHub。

## 签名流程

1. 准备配置 JSON。
2. 移除 `signature` 字段。
3. 对剩余 JSON 做 canonical JSON：对象 key 排序，列表保持顺序。
4. 用 RSA-PSS-SHA256 签名 canonical JSON 字节。
5. 将签名 base64 后写入 `signature`。

OpenSSL 示例：

```bash
openssl dgst -sha256 \
  -sign config-signing-private.pem \
  -sigopt rsa_padding_mode:pss \
  -sigopt rsa_pss_saltlen:32 \
  -sigopt rsa_mgf1_md:sha256 \
  -out config.sig canonical-config.json

base64 < config.sig
```

客户端永远只内置公钥。普通远程配置不能替换配置签名公钥；后续轮换公钥需要单独 key rotation 机制。

## 生产轮换建议

1. 在新版本客户端中内置旧公钥和新公钥的 key set。
2. 远程配置增加 `configKeyId`，但该字段本身也必须被旧 key 签名覆盖。
3. 灰度期内同时发布旧 key 和新 key 签名的配置，或发布双签名结构。
4. 等旧客户端自然淘汰后，再移除旧公钥。

不要通过普通远程配置下发新的配置签名公钥，否则攻击者一旦控制配置托管源，就可以替换公钥并接管配置。
