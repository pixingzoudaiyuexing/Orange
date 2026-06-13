import 'config_models.dart';

const _testConfigVerifyPublicKey = '''
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4SkHjGBhBCbKK+5Gtw+l
LBlWKaqwRebFAwhoUOEPJ/Oa1xO+35XyZvG+oIMD1balIyB/WfTiAROmwERrHxK/
+O1AJt42kaZZeffCq0Bs1QJgw5Kg0OLmK3Cy2/kmGHE1DDwXRztzE1vYhADE6uqy
lZ726HfTSBUInp2qUawoGTiLw6RT3kklaS7aRZCIzw66ru2Fip5xQUyIy9k3YE7k
adW++OBZHC76adppAYnXvq8yaODwQyYfTlb2FrlqgZ6JB3Vq13rokLQ//CVY+uc3
PsRSJci1YzUUdrH/7Ef8ZPIBFAFyVw64NBrx8OiwAHc2SMm+WkxVcGfHmoyAr3sh
EQIDAQAB
-----END PUBLIC KEY-----
''';

final bootstrapConfig = BootstrapConfig(
  configUrls: const [
    'https://example-oss.oss-cn-hangzhou.aliyuncs.com/client/config.json',
    'https://example-cos.cos.ap-guangzhou.myqcloud.com/client/config.json',
    'https://raw.githubusercontent.com/owner/repo/main/config/client-config.json',
    'https://cdn.example.com/client/config.json',
  ],
  configVerifyPublicKey: _testConfigVerifyPublicKey,
  configVersion: 1,
  defaultConfig: RemoteConfigDocument(
    version: 1,
    minClientVersion: '1.0.0',
    latestClientVersion: '1.0.0',
    forceUpdate: false,
    maintenance: false,
    maintenanceMessage: '',
    generatedAt: DateTime.utc(2026, 6, 13),
    expiresAt: DateTime.utc(2099, 1, 1),
    config: const ClientConfig(
      brandName: 'BrandName',
      security: RemoteSecurityConfig(
        securityBaseUrl: 'https://security.example.com',
        backupSecurityBaseUrls: [
          'https://security-backup1.example.com',
          'https://security-backup2.example.com',
        ],
        secureProtocol: 'secure-v2',
        keyId: 'main-2026-01',
        publicKey: '''
-----BEGIN PUBLIC KEY-----
TEST_SECURE_V2_PUBLIC_KEY_ONLY
-----END PUBLIC KEY-----
''',
      ),
      urls: RemoteUrlsConfig(
        websiteUrl: 'https://www.example.com',
        supportUrl: 'https://support.example.com',
        privacyUrl: 'https://www.example.com/privacy',
        termsUrl: 'https://www.example.com/terms',
        updateUrl: 'https://www.example.com/download',
      ),
      features: RemoteFeatureFlags(
        enableRegister: true,
        enableInvite: true,
        enablePlanPurchase: true,
        enableNotice: true,
        enableAutoUpdate: true,
        enableTunMode: true,
        enableSystemProxy: true,
      ),
      platforms: {
        'windows': RemotePlatformConfig(
          downloadUrl: 'https://download.example.com/windows/latest.exe',
        ),
        'macos': RemotePlatformConfig(
          downloadUrl: 'https://download.example.com/macos/latest.dmg',
        ),
        'android': RemotePlatformConfig(
          downloadUrl: 'https://download.example.com/android/latest.apk',
        ),
        'linux': RemotePlatformConfig(
          downloadUrl: 'https://download.example.com/linux/latest.AppImage',
        ),
      },
      notice: RemoteNoticeConfig(
        title: '',
        content: '',
        level: 'info',
      ),
    ),
    signature: 'bootstrap-default-config',
  ),
);
