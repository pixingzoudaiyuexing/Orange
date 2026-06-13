import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'config_errors.dart';
import 'config_models.dart';

abstract interface class RemoteConfigCache {
  Future<RemoteConfigDocument?> readLastKnownGood();
  Future<void> saveLastKnownGood(RemoteConfigDocument config);
  Future<String?> readPreferredConfigUrl();
  Future<int> readPreferredConfigUrlFailures();
  Future<void> savePreferredConfigUrl(String url);
  Future<void> incrementPreferredConfigUrlFailures();
  Future<void> clearPreferredConfigUrl();
  Future<String?> readEtag(String url);
  Future<void> saveEtag(String url, String etag);
  Future<void> clear();
}

class SharedPreferencesRemoteConfigCache implements RemoteConfigCache {
  static const _lastKnownGoodKey = 'remote_config.last_known_good';
  static const _preferredUrlKey = 'remote_config.preferred_url';
  static const _preferredUrlFailuresKey = 'remote_config.preferred_url_failures';
  static const _etagPrefix = 'remote_config.etag.';

  final SharedPreferences _preferences;

  SharedPreferencesRemoteConfigCache(this._preferences);

  static Future<SharedPreferencesRemoteConfigCache> create() async {
    return SharedPreferencesRemoteConfigCache(
      await SharedPreferences.getInstance(),
    );
  }

  @override
  Future<RemoteConfigDocument?> readLastKnownGood() async {
    try {
      final raw = _preferences.getString(_lastKnownGoodKey);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return RemoteConfigDocument.fromJson(json);
    } catch (_) {
      await _preferences.remove(_lastKnownGoodKey);
      return null;
    }
  }

  @override
  Future<void> saveLastKnownGood(RemoteConfigDocument config) async {
    try {
      await _preferences.setString(
        _lastKnownGoodKey,
        jsonEncode(config.toJson()),
      );
    } catch (_) {
      throw const RemoteConfigException(
        RemoteConfigErrorCode.cacheWrite,
        'Failed to write remote config cache',
      );
    }
  }

  @override
  Future<String?> readPreferredConfigUrl() async {
    return _preferences.getString(_preferredUrlKey);
  }

  @override
  Future<int> readPreferredConfigUrlFailures() async {
    return _preferences.getInt(_preferredUrlFailuresKey) ?? 0;
  }

  @override
  Future<void> savePreferredConfigUrl(String url) async {
    await _preferences.setString(_preferredUrlKey, url);
    await _preferences.setInt(_preferredUrlFailuresKey, 0);
  }

  @override
  Future<void> incrementPreferredConfigUrlFailures() async {
    final current = await readPreferredConfigUrlFailures();
    await _preferences.setInt(_preferredUrlFailuresKey, current + 1);
  }

  @override
  Future<void> clearPreferredConfigUrl() async {
    await _preferences.remove(_preferredUrlKey);
    await _preferences.remove(_preferredUrlFailuresKey);
  }

  @override
  Future<String?> readEtag(String url) async {
    return _preferences.getString('$_etagPrefix$url');
  }

  @override
  Future<void> saveEtag(String url, String etag) async {
    await _preferences.setString('$_etagPrefix$url', etag);
  }

  @override
  Future<void> clear() async {
    await _preferences.remove(_lastKnownGoodKey);
    await clearPreferredConfigUrl();
  }
}

class MemoryRemoteConfigCache implements RemoteConfigCache {
  RemoteConfigDocument? lastKnownGood;
  String? preferredConfigUrl;
  int preferredConfigUrlFailures = 0;
  final Map<String, String> etags = {};

  @override
  Future<RemoteConfigDocument?> readLastKnownGood() async => lastKnownGood;

  @override
  Future<void> saveLastKnownGood(RemoteConfigDocument config) async {
    lastKnownGood = config;
  }

  @override
  Future<String?> readPreferredConfigUrl() async => preferredConfigUrl;

  @override
  Future<int> readPreferredConfigUrlFailures() async {
    return preferredConfigUrlFailures;
  }

  @override
  Future<void> savePreferredConfigUrl(String url) async {
    preferredConfigUrl = url;
    preferredConfigUrlFailures = 0;
  }

  @override
  Future<void> incrementPreferredConfigUrlFailures() async {
    preferredConfigUrlFailures += 1;
  }

  @override
  Future<void> clearPreferredConfigUrl() async {
    preferredConfigUrl = null;
    preferredConfigUrlFailures = 0;
  }

  @override
  Future<String?> readEtag(String url) async => etags[url];

  @override
  Future<void> saveEtag(String url, String etag) async {
    etags[url] = etag;
  }

  @override
  Future<void> clear() async {
    lastKnownGood = null;
    etags.clear();
    await clearPreferredConfigUrl();
  }
}
