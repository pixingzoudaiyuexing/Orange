# REMOTE_CONFIG_SCHEMA.md

远程配置文件结构：

```json
{
  "version": 12,
  "minClientVersion": "1.0.0",
  "latestClientVersion": "1.0.5",
  "forceUpdate": false,
  "maintenance": false,
  "maintenanceMessage": "",
  "generatedAt": "2026-06-13T00:00:00.000Z",
  "expiresAt": "2026-07-13T00:00:00.000Z",
  "config": {
    "brandName": "BrandName",
    "security": {
      "securityBaseUrl": "https://security.example.com",
      "backupSecurityBaseUrls": [
        "https://security-backup1.example.com"
      ],
      "secureProtocol": "secure-v2",
      "keyId": "main-2026-01",
      "publicKey": "-----BEGIN PUBLIC KEY-----..."
    },
    "urls": {
      "websiteUrl": "https://www.example.com",
      "supportUrl": "https://support.example.com",
      "privacyUrl": "https://www.example.com/privacy",
      "termsUrl": "https://www.example.com/terms",
      "updateUrl": "https://www.example.com/download"
    },
    "features": {
      "enableRegister": true,
      "enableInvite": true,
      "enablePlanPurchase": true,
      "enableNotice": true,
      "enableAutoUpdate": true,
      "enableTunMode": true,
      "enableSystemProxy": true
    },
    "platforms": {
      "windows": { "downloadUrl": "https://download.example.com/windows/latest.exe" },
      "macos": { "downloadUrl": "https://download.example.com/macos/latest.dmg" },
      "android": { "downloadUrl": "https://download.example.com/android/latest.apk" },
      "linux": { "downloadUrl": "https://download.example.com/linux/latest.AppImage" }
    },
    "notice": {
      "title": "",
      "content": "",
      "level": "info"
    }
  },
  "signature": "base64-signature"
}
```

`signature` 不参与签名。签名内容是去掉 `signature` 后的 canonical JSON，map key 按字典序排序。

默认拒绝 `version` 小于缓存版本的配置。确需回滚时，必须增加签名有效的 `allowRollback: true`。

`expiresAt` 过期的远程配置不得作为新配置生效。`generatedAt` 明显来自未来或过旧时，Repository 上层可以根据 fetch result 的 warning 做提示或上报，但本阶段不接 UI。
