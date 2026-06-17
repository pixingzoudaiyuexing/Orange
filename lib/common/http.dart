import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/security/security.dart';
import 'package:fl_clash/state.dart';

const _masker = SensitiveLogMasker();

class FlClashHttpOverrides extends HttpOverrides {
  static String handleFindProxy(Uri url) {
    if ([localhost].contains(url.host)) {
      return "DIRECT";
    }
    final port = globalState.config.patchClashConfig.mixedPort;
    final isStart = globalState.appState.runTime != null;
    commonPrint.log("find ${_maskUrl(url)} proxy:$isStart");
    if (!isStart) return "DIRECT";
    return "PROXY localhost:$port";
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (_, __, ___) => true;
    client.findProxy = handleFindProxy;
    return client;
  }
}

String _maskUrl(Uri url) {
  final text = _masker.maskText(url.toString());
  return text.replaceAllMapped(
    RegExp(r'https?:\/\/[^\s",)]+', caseSensitive: false),
    (match) {
      final value = match.group(0)!;
      return value.startsWith('https://') ? 'https********' : 'http********';
    },
  );
}
