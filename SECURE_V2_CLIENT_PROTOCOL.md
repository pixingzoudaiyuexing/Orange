# SECURE_V2_CLIENT_PROTOCOL.md

客户端 secure-v2 请求固定发送到：

```text
POST {securityBaseUrl}/secure-v2/proxy
```

Headers：

```text
Content-Type: application/json
X-Secure-Version: 2
X-Key-Id: <RemoteConfig security.keyId>
X-Request-Id: <uuid>
X-Timestamp: <milliseconds>
X-App-Version: <client version>
X-Platform: windows | macos | android | linux
```

Body：

```json
{
  "keyId": "main-2026-01",
  "encryptedKey": "base64",
  "iv": "base64",
  "ciphertext": "base64"
}
```

加密前 payload：

```json
{
  "method": "POST",
  "path": "/api/v1/passport/auth/login",
  "headers": {
    "authorization": "Bearer xxx"
  },
  "query": {},
  "body": {}
}
```

算法：

1. 每次请求生成 32 字节 AES key。
2. 每次请求生成 12 字节 AES-GCM IV。
3. payload 使用 AES-256-GCM 加密。
4. AES key 使用服务端 `publicKey` 做 RSA-OAEP-SHA256 加密。
5. 响应用同一个 AES key 解密。
6. 响应 `requestId` 必须匹配请求。

当前 Dart 端使用 `pointycastle` 的 `OAEPEncoding.withSHA256(RSAEngine())`。该实现需要和安全中间件 staging 做端到端验证，确认 Dart 端生成的 RSA-OAEP-SHA256 密文可被服务端解开。

客户端不能在 secure-v2 失败时自动降级到 secure-v1。
