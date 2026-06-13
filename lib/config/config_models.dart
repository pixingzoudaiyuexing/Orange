import 'dart:convert';

import 'config_errors.dart';

class BootstrapConfig {
  final List<String> configUrls;
  final String configVerifyPublicKey;
  final int configVersion;
  final RemoteConfigDocument defaultConfig;

  const BootstrapConfig({
    required this.configUrls,
    required this.configVerifyPublicKey,
    required this.configVersion,
    required this.defaultConfig,
  });
}

class RemoteConfigDocument {
  final int version;
  final String minClientVersion;
  final String latestClientVersion;
  final bool forceUpdate;
  final bool maintenance;
  final String maintenanceMessage;
  final DateTime generatedAt;
  final DateTime expiresAt;
  final ClientConfig config;
  final String signature;
  final bool allowRollback;

  const RemoteConfigDocument({
    required this.version,
    required this.minClientVersion,
    required this.latestClientVersion,
    required this.forceUpdate,
    required this.maintenance,
    required this.maintenanceMessage,
    required this.generatedAt,
    required this.expiresAt,
    required this.config,
    required this.signature,
    this.allowRollback = false,
  });

  factory RemoteConfigDocument.fromJson(Map<String, dynamic> json) {
    validateNoDangerousFields(json);
    return RemoteConfigDocument(
      version: _readInt(json, 'version'),
      minClientVersion: _readString(json, 'minClientVersion'),
      latestClientVersion: _readString(json, 'latestClientVersion'),
      forceUpdate: _readBool(json, 'forceUpdate'),
      maintenance: _readBool(json, 'maintenance'),
      maintenanceMessage: _readOptionalString(json, 'maintenanceMessage'),
      generatedAt: _readDateTime(json, 'generatedAt'),
      expiresAt: _readDateTime(json, 'expiresAt'),
      config: ClientConfig.fromJson(_readMap(json, 'config')),
      signature: _readString(json, 'signature'),
      allowRollback: _readOptionalBool(json, 'allowRollback'),
    );
  }

  Map<String, dynamic> toJson({bool includeSignature = true}) {
    final json = <String, dynamic>{
      'version': version,
      'minClientVersion': minClientVersion,
      'latestClientVersion': latestClientVersion,
      'forceUpdate': forceUpdate,
      'maintenance': maintenance,
      'maintenanceMessage': maintenanceMessage,
      'generatedAt': generatedAt.toUtc().toIso8601String(),
      'expiresAt': expiresAt.toUtc().toIso8601String(),
      'config': config.toJson(),
    };
    if (allowRollback) {
      json['allowRollback'] = true;
    }
    if (includeSignature) {
      json['signature'] = signature;
    }
    return json;
  }

  String canonicalPayload() {
    return canonicalJson(toJson(includeSignature: false));
  }

  RemoteConfigDocument copyWith({
    int? version,
    String? signature,
    DateTime? expiresAt,
    bool? forceUpdate,
    bool? maintenance,
    String? maintenanceMessage,
  }) {
    return RemoteConfigDocument(
      version: version ?? this.version,
      minClientVersion: minClientVersion,
      latestClientVersion: latestClientVersion,
      forceUpdate: forceUpdate ?? this.forceUpdate,
      maintenance: maintenance ?? this.maintenance,
      maintenanceMessage: maintenanceMessage ?? this.maintenanceMessage,
      generatedAt: generatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      config: config,
      signature: signature ?? this.signature,
      allowRollback: allowRollback,
    );
  }

  void validateSafeFields() {
    validateNoDangerousFields(toJson());
    final urls = [
      config.security.securityBaseUrl,
      ...config.security.backupSecurityBaseUrls,
      config.urls.websiteUrl,
      config.urls.supportUrl,
      config.urls.privacyUrl,
      config.urls.termsUrl,
      config.urls.updateUrl,
      ...config.platforms.values.map((platform) => platform.downloadUrl),
    ];
    for (final url in urls.where((url) => url.isNotEmpty)) {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme || uri.scheme != 'https') {
        throw const RemoteConfigException(
          RemoteConfigErrorCode.invalidUrl,
          'Remote config URLs must use HTTPS',
        );
      }
    }

    if (config.security.secureProtocol != 'secure-v2') {
      throw const RemoteConfigException(
        RemoteConfigErrorCode.dangerousField,
        'Remote config may only enable secure-v2',
      );
    }
  }
}

void validateNoDangerousFields(Object? value) {
  const forbiddenKeys = [
    'backend_domain',
    'backenddomain',
    'sec_password',
    'secpassword',
    'privatekey',
    'private_key',
    'adminpassword',
    'admin_password',
    'adminemail',
    'admin_email',
    'subscribe_url',
    'subscribeurl',
    'token',
    'authorization',
    'cookie',
    'access_token',
    'accesstoken',
    'refresh_token',
    'refreshtoken',
    'database',
    'db_password',
    'script',
    'scripts',
    'code',
  ];

  void visit(Object? node, [String? key]) {
    final normalizedKey = key?.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (normalizedKey != null && forbiddenKeys.contains(normalizedKey)) {
      throw const RemoteConfigException(
        RemoteConfigErrorCode.dangerousField,
        'Remote config contains a forbidden field',
      );
    }

    if (node is Map) {
      for (final entry in node.entries) {
        visit(entry.value, entry.key.toString());
      }
      return;
    }
    if (node is List) {
      for (final item in node) {
        visit(item);
      }
    }
  }

  visit(value);
}

class ClientConfig {
  final String brandName;
  final RemoteSecurityConfig security;
  final RemoteUrlsConfig urls;
  final RemoteFeatureFlags features;
  final Map<String, RemotePlatformConfig> platforms;
  final RemoteNoticeConfig notice;

  const ClientConfig({
    required this.brandName,
    required this.security,
    required this.urls,
    required this.features,
    required this.platforms,
    required this.notice,
  });

  factory ClientConfig.fromJson(Map<String, dynamic> json) {
    return ClientConfig(
      brandName: _readString(json, 'brandName'),
      security: RemoteSecurityConfig.fromJson(_readMap(json, 'security')),
      urls: RemoteUrlsConfig.fromJson(_readMap(json, 'urls')),
      features: RemoteFeatureFlags.fromJson(_readMap(json, 'features')),
      platforms: _readMap(json, 'platforms').map(
        (key, value) => MapEntry(
          key,
          RemotePlatformConfig.fromJson(_asMap(value, key)),
        ),
      ),
      notice: RemoteNoticeConfig.fromJson(_readMap(json, 'notice')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'brandName': brandName,
      'security': security.toJson(),
      'urls': urls.toJson(),
      'features': features.toJson(),
      'platforms': platforms.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'notice': notice.toJson(),
    };
  }
}

class RemoteSecurityConfig {
  final String securityBaseUrl;
  final List<String> backupSecurityBaseUrls;
  final String secureProtocol;
  final String keyId;
  final String publicKey;

  const RemoteSecurityConfig({
    required this.securityBaseUrl,
    required this.backupSecurityBaseUrls,
    required this.secureProtocol,
    required this.keyId,
    required this.publicKey,
  });

  factory RemoteSecurityConfig.fromJson(Map<String, dynamic> json) {
    return RemoteSecurityConfig(
      securityBaseUrl: _readString(json, 'securityBaseUrl'),
      backupSecurityBaseUrls: _readStringList(json, 'backupSecurityBaseUrls'),
      secureProtocol: _readString(json, 'secureProtocol'),
      keyId: _readString(json, 'keyId'),
      publicKey: _readString(json, 'publicKey'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'securityBaseUrl': securityBaseUrl,
      'backupSecurityBaseUrls': backupSecurityBaseUrls,
      'secureProtocol': secureProtocol,
      'keyId': keyId,
      'publicKey': publicKey,
    };
  }
}

class RemoteUrlsConfig {
  final String websiteUrl;
  final String supportUrl;
  final String privacyUrl;
  final String termsUrl;
  final String updateUrl;

  const RemoteUrlsConfig({
    required this.websiteUrl,
    required this.supportUrl,
    required this.privacyUrl,
    required this.termsUrl,
    required this.updateUrl,
  });

  factory RemoteUrlsConfig.fromJson(Map<String, dynamic> json) {
    return RemoteUrlsConfig(
      websiteUrl: _readString(json, 'websiteUrl'),
      supportUrl: _readString(json, 'supportUrl'),
      privacyUrl: _readString(json, 'privacyUrl'),
      termsUrl: _readString(json, 'termsUrl'),
      updateUrl: _readString(json, 'updateUrl'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'websiteUrl': websiteUrl,
      'supportUrl': supportUrl,
      'privacyUrl': privacyUrl,
      'termsUrl': termsUrl,
      'updateUrl': updateUrl,
    };
  }
}

class RemoteFeatureFlags {
  final bool enableRegister;
  final bool enableInvite;
  final bool enablePlanPurchase;
  final bool enableNotice;
  final bool enableAutoUpdate;
  final bool enableTunMode;
  final bool enableSystemProxy;

  const RemoteFeatureFlags({
    required this.enableRegister,
    required this.enableInvite,
    required this.enablePlanPurchase,
    required this.enableNotice,
    required this.enableAutoUpdate,
    required this.enableTunMode,
    required this.enableSystemProxy,
  });

  factory RemoteFeatureFlags.fromJson(Map<String, dynamic> json) {
    return RemoteFeatureFlags(
      enableRegister: _readBool(json, 'enableRegister'),
      enableInvite: _readBool(json, 'enableInvite'),
      enablePlanPurchase: _readBool(json, 'enablePlanPurchase'),
      enableNotice: _readBool(json, 'enableNotice'),
      enableAutoUpdate: _readBool(json, 'enableAutoUpdate'),
      enableTunMode: _readBool(json, 'enableTunMode'),
      enableSystemProxy: _readBool(json, 'enableSystemProxy'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enableRegister': enableRegister,
      'enableInvite': enableInvite,
      'enablePlanPurchase': enablePlanPurchase,
      'enableNotice': enableNotice,
      'enableAutoUpdate': enableAutoUpdate,
      'enableTunMode': enableTunMode,
      'enableSystemProxy': enableSystemProxy,
    };
  }
}

class RemotePlatformConfig {
  final String downloadUrl;

  const RemotePlatformConfig({required this.downloadUrl});

  factory RemotePlatformConfig.fromJson(Map<String, dynamic> json) {
    return RemotePlatformConfig(
      downloadUrl: _readString(json, 'downloadUrl'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'downloadUrl': downloadUrl,
    };
  }
}

class RemoteNoticeConfig {
  final String title;
  final String content;
  final String level;

  const RemoteNoticeConfig({
    required this.title,
    required this.content,
    required this.level,
  });

  factory RemoteNoticeConfig.fromJson(Map<String, dynamic> json) {
    return RemoteNoticeConfig(
      title: _readOptionalString(json, 'title'),
      content: _readOptionalString(json, 'content'),
      level: _readOptionalString(json, 'level', fallback: 'info'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'level': level,
    };
  }
}

class UpdateInfo {
  final String minClientVersion;
  final String latestClientVersion;
  final bool forceUpdate;
  final String updateUrl;

  const UpdateInfo({
    required this.minClientVersion,
    required this.latestClientVersion,
    required this.forceUpdate,
    required this.updateUrl,
  });
}

class MaintenanceInfo {
  final bool maintenance;
  final String message;

  const MaintenanceInfo({
    required this.maintenance,
    required this.message,
  });
}

String canonicalJson(Object? value) {
  return jsonEncode(_canonicalize(value));
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final sortedKeys = value.keys.map((key) => key.toString()).toList()..sort();
    return {
      for (final key in sortedKeys) key: _canonicalize(value[key]),
    };
  }
  if (value is List) {
    return value.map(_canonicalize).toList();
  }
  return value;
}

Map<String, dynamic> _readMap(Map<String, dynamic> json, String key) {
  return _asMap(json[key], key);
}

Map<String, dynamic> _asMap(Object? value, String key) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  throw RemoteConfigException(
    RemoteConfigErrorCode.invalidJson,
    'Missing or invalid map field: $key',
  );
}

String _readString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw RemoteConfigException(
    RemoteConfigErrorCode.invalidJson,
    'Missing or invalid string field: $key',
  );
}

String _readOptionalString(
  Map<String, dynamic> json,
  String key, {
  String fallback = '',
}) {
  final value = json[key];
  if (value == null) {
    return fallback;
  }
  if (value is String) {
    return value;
  }
  throw RemoteConfigException(
    RemoteConfigErrorCode.invalidJson,
    'Invalid string field: $key',
  );
}

int _readInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  throw RemoteConfigException(
    RemoteConfigErrorCode.invalidJson,
    'Missing or invalid int field: $key',
  );
}

bool _readBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  throw RemoteConfigException(
    RemoteConfigErrorCode.invalidJson,
    'Missing or invalid bool field: $key',
  );
}

bool _readOptionalBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return false;
  }
  if (value is bool) {
    return value;
  }
  throw RemoteConfigException(
    RemoteConfigErrorCode.invalidJson,
    'Invalid bool field: $key',
  );
}

DateTime _readDateTime(Map<String, dynamic> json, String key) {
  final value = _readString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw RemoteConfigException(
      RemoteConfigErrorCode.invalidJson,
      'Invalid datetime field: $key',
    );
  }
  return parsed.toUtc();
}

List<String> _readStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List && value.every((item) => item is String)) {
    return value.cast<String>();
  }
  throw RemoteConfigException(
    RemoteConfigErrorCode.invalidJson,
    'Missing or invalid string list field: $key',
  );
}
