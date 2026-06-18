import 'config_entry.dart';

/// 在线客服信息
///
/// 扩展ConfigEntry，添加在线客服特有的属性
class OnlineSupportInfo extends ConfigEntry {
  final bool enabled;
  final String provider;
  final String crispWebsiteId;
  final String fallbackUrl;
  final String apiBaseUrl;
  final String wsBaseUrl;

  const OnlineSupportInfo({
    required super.url,
    required super.description,
    this.enabled = true,
    this.provider = '',
    this.crispWebsiteId = '',
    this.fallbackUrl = '',
    required this.apiBaseUrl,
    required this.wsBaseUrl,
    super.metadata,
  });

  /// 从JSON创建在线客服信息
  factory OnlineSupportInfo.fromJson(Map<String, dynamic> json) {
    final crisp = json['crisp'] is Map<String, dynamic>
        ? json['crisp'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final provider = json['provider'] as String? ?? '';
    final websiteId = crisp['website_id'] as String? ?? '';
    final fallbackUrl = json['fallback_url'] as String? ?? '';
    final metadata = <String, dynamic>{
      if (json['metadata'] is Map<String, dynamic>)
        ...(json['metadata'] as Map<String, dynamic>),
      if (provider.isNotEmpty) 'provider': provider,
      if (websiteId.isNotEmpty) 'crisp': {'website_id': websiteId},
      if (fallbackUrl.isNotEmpty) 'fallback_url': fallbackUrl,
    };

    return OnlineSupportInfo(
      url: fallbackUrl,
      description: json['description'] as String? ?? 'Online support',
      enabled: json['enabled'] as bool? ?? true,
      provider: provider,
      crispWebsiteId: websiteId,
      fallbackUrl: fallbackUrl,
      apiBaseUrl: '',
      wsBaseUrl: '',
      metadata: metadata.isEmpty ? null : metadata,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'enabled': enabled,
      if (provider.isNotEmpty) 'provider': provider,
      if (crispWebsiteId.isNotEmpty) 'crisp': {'website_id': crispWebsiteId},
      if (fallbackUrl.isNotEmpty) 'fallback_url': fallbackUrl,
    });
    return json;
  }

  bool get isCrisp => provider.toLowerCase() == 'crisp';

  bool get hasCrispWebsiteId => crispWebsiteId.trim().isNotEmpty;

  bool get hasValidCrispConfig => enabled && isCrisp && hasCrispWebsiteId;

  /// 验证URL格式
  bool validate() {
    if (!enabled) return true;
    if (isCrisp) {
      return hasCrispWebsiteId &&
          (fallbackUrl.isEmpty || _isValidHttpUrl(fallbackUrl));
    }
    return false;
  }

  /// 获取验证错误信息
  List<String> getValidationErrors() {
    final errors = <String>[];

    if (!enabled) return errors;

    if (isCrisp) {
      if (!hasCrispWebsiteId) {
        errors.add('Crisp website_id is required');
      }
      if (fallbackUrl.isNotEmpty && !_isValidHttpUrl(fallbackUrl)) {
        errors.add('Crisp fallback_url must be a valid HTTP/HTTPS URL');
      }
      return errors;
    }

    errors.add('Online support only supports provider=crisp');

    return errors;
  }

  /// 检查是否为有效的HTTP URL
  bool _isValidHttpUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.scheme == 'http' || uri.scheme == 'https';
    } catch (e) {
      return false;
    }
  }

  @override
  String toString() {
    return 'OnlineSupportInfo(enabled: $enabled, provider: $provider, '
        'hasCrispWebsiteId: $hasCrispWebsiteId, '
        'hasFallbackUrl: ${fallbackUrl.isNotEmpty})';
  }
}
