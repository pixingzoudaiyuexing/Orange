import 'package:fl_clash/xboard/wyx_v2board/ui/wyx_v2board_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('XBoardBackendType', () {
    test('recognizes wyx_v2board aliases', () {
      expect(XBoardBackendType.isWyxV2Board('wyx_v2board'), true);
      expect(XBoardBackendType.isWyxV2Board('wyx-v2board'), true);
      expect(XBoardBackendType.isWyxV2Board('wyxv2board'), true);
      expect(XBoardBackendType.isWyxV2Board('WYX_V2BOARD'), true);
    });

    test('does not treat legacy backends as wyx', () {
      expect(XBoardBackendType.isWyxV2Board('xboard'), false);
      expect(XBoardBackendType.isWyxV2Board('v2board'), false);
      expect(XBoardBackendType.isWyxV2Board('xv2b'), false);
      expect(XBoardBackendType.isWyxV2Board(''), false);
      expect(XBoardBackendType.isWyxV2Board(null), false);
    });
  });
}
