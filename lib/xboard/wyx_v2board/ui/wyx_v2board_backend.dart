import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/xboard_config.dart';

class XBoardBackendType {
  static const wyxV2Board = 'wyx_v2board';

  const XBoardBackendType._();

  static bool isWyxV2Board(String? value) {
    final normalized = value?.trim().toLowerCase();
    return normalized == wyxV2Board ||
        normalized == 'wyx-v2board' ||
        normalized == 'wyxv2board';
  }
}

final xboardBackendTypeProvider = FutureProvider<String>((ref) async {
  final localType = await ConfigFileLoaderHelper.getBackendType();
  if (localType.isNotEmpty) {
    return localType;
  }

  if (XBoardConfig.isInitialized) {
    try {
      return XBoardConfig.provider.getPanelType();
    } catch (_) {
      return '';
    }
  }

  return '';
});

final isWyxV2BoardBackendProvider = FutureProvider<bool>((ref) async {
  final backendType = await ref.watch(xboardBackendTypeProvider.future);
  return XBoardBackendType.isWyxV2Board(backendType);
});
