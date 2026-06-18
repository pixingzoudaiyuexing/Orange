import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const onlineSupportUnavailableMessage = '在线客服暂未开放，请通过官网或工单联系客服';

final crispSupportConfigProvider = Provider<CrispSupportConfig>((ref) {
  return CrispSupportConfig.fromRemoteConfig();
});

class CrispSupportConfig {
  final bool enabled;
  final String? websiteId;
  final String? fallbackUrl;

  const CrispSupportConfig({
    required this.enabled,
    this.websiteId,
    this.fallbackUrl,
  });

  factory CrispSupportConfig.fromRemoteConfig() {
    return CrispSupportConfig(
      enabled: true,
      websiteId: _readConfigValue(() => XBoardConfig.crispWebsiteId),
      fallbackUrl: _readConfigValue(() => XBoardConfig.crispFallbackUrl),
    );
  }

  bool get isAvailable =>
      enabled && websiteId != null && websiteId!.trim().isNotEmpty;

  Uri? get crispUri {
    final id = websiteId?.trim();
    if (id == null || id.isEmpty) return null;
    return buildCrispEmbedUri(id);
  }

  Uri? get fallbackUri {
    final url = fallbackUrl?.trim();
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri;
  }

  static Uri buildCrispEmbedUri(String websiteId) {
    return Uri.https('go.crisp.chat', '/chat/embed/', {
      'website_id': websiteId,
    });
  }

  static String? _readConfigValue(String? Function() read) {
    try {
      final value = read()?.trim();
      return value == null || value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }
}
