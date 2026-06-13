class SensitiveLogMasker {
  static const _sensitiveKeys = {
    'password',
    'passwd',
    'token',
    'auth_data',
    'authdata',
    'authorization',
    'subscribe_url',
    'subscribeurl',
    'access_token',
    'accesstoken',
    'refresh_token',
    'refreshtoken',
    'cookie',
    'set-cookie',
    'encryptedkey',
    'ciphertext',
  };

  const SensitiveLogMasker();

  Object? mask(Object? value) {
    if (value is Map) {
      return value.map((key, dynamic item) {
        final normalizedKey = _normalizeKey('$key');
        if (_sensitiveKeys.contains(normalizedKey)) {
          return MapEntry(key, _maskValue(item));
        }
        return MapEntry(key, mask(item));
      });
    }
    if (value is List) {
      return value.map(mask).toList();
    }
    if (value is String && _looksLikeEmail(value)) {
      return _maskEmail(value);
    }
    return value;
  }

  Map<String, String> maskHeaders(Map<String, String> headers) {
    return headers.map((key, value) {
      final normalizedKey = _normalizeKey(key);
      if (_sensitiveKeys.contains(normalizedKey)) {
        return MapEntry(key, _maskValue(value));
      }
      return MapEntry(key, value);
    });
  }

  String maskText(String value) {
    var masked = value;
    final patterns = [
      RegExp(r'Bearer\s+([A-Za-z0-9._~+/=-]{6,})'),
      RegExp(
        r'(password|passwd|token|auth_data|authData|subscribe_url|subscribeUrl)'
        r'["\s:=]+([^\s",}]+)',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      masked = masked.replaceAllMapped(pattern, (match) {
        final prefix = match.group(0)!.contains('Bearer')
            ? 'Bearer '
            : '${match.group(1)}=';
        final secret = match.group(match.groupCount) ?? '';
        return '$prefix${_maskString(secret)}';
      });
    }
    return masked.replaceAllMapped(
      RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false),
      (match) => _maskEmail(match.group(0)!),
    );
  }

  static String _normalizeKey(String key) {
    return key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '');
  }

  static String _maskValue(Object? value) {
    if (value == null) {
      return '[MASKED]';
    }
    return _maskString('$value');
  }

  static String _maskString(String value) {
    if (value.length <= 8) {
      return '********';
    }
    return '${value.substring(0, 4)}********';
  }

  static bool _looksLikeEmail(String value) {
    return RegExp(
      r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$',
      caseSensitive: false,
    ).hasMatch(value);
  }

  static String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) {
      return _maskString(email);
    }
    final name = parts[0];
    final visible = name.isEmpty ? '*' : name.substring(0, 1);
    return '$visible***@${parts[1]}';
  }
}
