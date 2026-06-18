/// 配置条目基础类
///
/// 表示配置中的一个条目，包含URL和描述信息
class ConfigEntry {
  final String url;
  final String description;
  final Map<String, dynamic>? metadata;

  const ConfigEntry({
    required this.url,
    required this.description,
    this.metadata,
  });

  factory ConfigEntry.fromJson(Map<String, dynamic> json) {
    final metadata = <String, dynamic>{
      if (json['metadata'] is Map<String, dynamic>)
        ...(json['metadata'] as Map<String, dynamic>),
    };

    for (final key in [
      'secure_v2',
      'online_support',
      'links',
      'backend_type',
      'panelType',
      'panel_type',
    ]) {
      if (json.containsKey(key) && !metadata.containsKey(key)) {
        metadata[key] = json[key];
      }
    }

    return ConfigEntry(
      url: json['url'] as String? ?? '',
      description: json['description'] as String? ?? '',
      metadata: metadata.isEmpty ? null : metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'description': description,
      if (metadata != null) 'metadata': metadata,
    };
  }

  @override
  String toString() {
    return 'ConfigEntry(url: $url, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConfigEntry &&
        other.url == url &&
        other.description == description;
  }

  @override
  int get hashCode => url.hashCode ^ description.hashCode;
}
