# Production RemoteConfig

This document describes the production RemoteConfig setup for the
`wyx_v2board` backend. The production app should load a small local
`assets/config/xboard.config.yaml` bootstrap file, then fetch the real runtime
configuration from a COS-hosted HTTPS JSON document.

Do not commit local private configuration, generated files, keys, account
credentials, tokens, `auth_data`, or subscription URLs.

## Production `assets/config/xboard.config.yaml`

The production bootstrap file should only contain the remote configuration
source. It must not contain secure-v2 keys, account data, tokens, or backend
secrets.

```yaml
xboard:
  backend_type: wyx_v2board
  provider: mihomo

  remote_config:
    sources:
      - name: cos
        url: https://your-cos-bucket.example.com/config/remote_config.json?v=202606180001
        priority: 100

  subscription:
    prefer_encrypt: false
```

Notes:

- Replace the URL with the production COS HTTPS URL.
- Keep the `?v=YYYYMMDDHHMM` parameter when you need deterministic cache
  refreshes.
- Do not use `http://127.0.0.1:18080/remote_config.json` in production.
- Do not point this URL to `security_base_url`.
- Do not keep `gitee`, `example`, or local debug sources in production.
- The app treats `cos` as a plain HTTPS JSON source.

## Production COS RemoteConfig JSON

Upload a JSON document like this to COS. The panel URL and secure-v2 base URL
may both point at the security gateway if that is the intended entry point, but
the local YAML source URL must point only to this COS JSON document.

```json
{
  "version": 1,
  "updated_at": "2026-06-18T00:00:00.000Z",
  "panelType": "v2board",
  "panel_type": "v2board",
  "backend_type": "wyx_v2board",
  "app": {
    "title": "YourAppName",
    "website": "https://www.example.com"
  },
  "panels": {
    "mihomo": [
      {
        "name": "production-wyx-v2board",
        "description": "Production wyx_v2board via secure-v2",
        "url": "https://security.example.com",
        "panelType": "v2board",
        "panel_type": "v2board",
        "backend_type": "wyx_v2board",
        "secure_v2": {
          "enabled": true,
          "security_base_url": "https://security.example.com",
          "key_id": "production-key-id",
          "public_key": "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A...\n-----END PUBLIC KEY-----"
        },
        "online_support": {
          "enabled": true,
          "provider": "crisp",
          "crisp": {
            "website_id": "YOUR_CRISP_WEBSITE_ID"
          },
          "fallback_url": "https://www.example.com/support"
        },
        "links": {
          "website": "https://www.example.com",
          "forgot_password": "https://www.example.com/#/forgot-password",
          "support": "https://www.example.com/support"
        }
      }
    ]
  },
  "subscription": {
    "prefer_encrypt": false
  },
  "metadata": {
    "sources": ["cos"],
    "lastUpdated": "2026-06-18T00:00:00.000Z",
    "version": "production-202606180001",
    "statistics": {
      "panels": 1
    }
  }
}
```

The current parser reads CloudGap online support from the current panel item
only. Do not add top-level `online_support` or legacy `onlineSupport` blocks.

## Crisp Online Support

The only supported COS RemoteConfig shape for CloudGap online support is:

```json
{
  "online_support": {
    "enabled": true,
    "provider": "crisp",
    "crisp": {
      "website_id": "YOUR_CRISP_WEBSITE_ID"
    },
    "fallback_url": "https://www.example.com/support"
  }
}
```

`website_id` is the public Crisp Website ID. Do not put Crisp API tokens,
Crisp secrets, WebSocket support fields, user credentials, app tokens,
`auth_data`, or subscription URLs in RemoteConfig. If Crisp is not ready, set
`online_support.enabled=false` and keep a safe `links.support` or
`fallback_url` for operators.

## Public Key Format

`secure_v2.public_key` must be a public PEM only:

```text
-----BEGIN PUBLIC KEY-----
BASE64_PUBLIC_KEY_BODY
-----END PUBLIC KEY-----
```

When embedded in JSON, line breaks must be escaped as `\n`. Do not paste a
private key. Reject the file if it contains any of these markers:

- `PRIVATE KEY`
- `BEGIN RSA PRIVATE KEY`
- `BEGIN OPENSSH PRIVATE KEY`

## Forbidden Fields

Do not put any of these fields or values in COS JSON, local YAML, documentation
examples with real data, logs, commits, or build artifacts:

- `SEC_PASSWORD`
- `BACKEND_DOMAIN`
- private keys
- account emails or passwords
- `token`
- `auth_data`
- `authorization`
- full `subscribe_url`
- cookies
- database credentials
- Crisp API Token
- Crisp Secret

## Preflight Checks

Run these checks before packaging:

```bash
rg -n "127\\.0\\.0\\.1|18080|local_config" assets/config/xboard.config.yaml docs assets/config
rg -n "SEC_PASSWORD|BACKEND_DOMAIN|PRIVATE KEY|BEGIN OPENSSH|BEGIN RSA|BEGIN PRIVATE|auth_data|subscribe_url|token=|password" \
  assets/config docs lib tool test \
  --glob '!assets/config/xboard.config.yaml' \
  --glob '!local_config/**' \
  --glob '!secure-v2-public.pem' \
  --glob '!**/*.pem'
curl -fsSL "https://your-cos-bucket.example.com/config/remote_config.json?v=202606180001" \
  | jq '.panels.mihomo[0] | {panelType, panel_type, backend_type, url, description, has_secure_v2: (.secure_v2 != null)}'
```

For app validation, temporarily put the production COS URL into the ignored
`assets/config/xboard.config.yaml`, then run:

```bash
flutter run -d macos
```

Expected runtime checks:

- Logs show the COS HTTPS source, not `127.0.0.1`.
- `panelType`, `panel_type`, and `backend_type` are present.
- secure-v2 initializes from the current panel item's `secure_v2`.
- Login succeeds.
- wyx subscription import succeeds.
- Real Clash/Mihomo groups appear.
- Node switching and latency testing work.
- Starting and stopping the proxy does not produce provider-disposed errors.
- Logs mask URLs, tokens, `auth_data`, passwords, and subscription URLs.
