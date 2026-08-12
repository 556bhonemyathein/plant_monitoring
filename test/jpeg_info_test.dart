import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plant_monitoring/utils/jpeg_info.dart';

/// APP0 segment တစ်ခု ကျော်ပြီးမှ SOF ပါတဲ့ JPEG header အတု တစ်ခု ဆောက်တယ်။
Uint8List fakeJpeg({required int width, required int height, int sofMarker = 0xC0}) {
  return Uint8List.fromList([
    0xFF, 0xD8, // SOI
    0xFF, 0xE0, 0x00, 0x04, 0x00, 0x00, // APP0, length 4 (payload 2 bytes)
    0xFF, sofMarker, 0x00, 0x11, 0x08, // SOF, length 17, precision 8
    (height >> 8) & 0xFF, height & 0xFF,
    (width >> 8) & 0xFF, width & 0xFF,
    0x03, // component count (နောက်က byte တွေ မလိုတော့ဘူး)
  ]);
}

void main() {
  test('reads dimensions from a baseline JPEG', () {
    expect(jpegSize(fakeJpeg(width: 640, height: 480))?.toString(), '640×480');
  });

  test('reads dimensions from a progressive JPEG (SOF2)', () {
    final size = jpegSize(fakeJpeg(width: 800, height: 600, sofMarker: 0xC2));
    expect(size?.width, 800);
    expect(size?.height, 600);
  });

  test('flags small ESP32-CAM frame sizes as low resolution', () {
    expect(jpegSize(fakeJpeg(width: 160, height: 120))!.isLowResolution, isTrue); // QQVGA
    expect(jpegSize(fakeJpeg(width: 176, height: 144))!.isLowResolution, isTrue); // QCIF
    expect(jpegSize(fakeJpeg(width: 640, height: 480))!.isLowResolution, isFalse); // VGA
  });

  test('does not treat DHT (FFC4) as a start-of-frame marker', () {
    // FFC4 က SOF အပိုင်းအခြားထဲ ရောက်နေပေမယ့် Huffman table ဖြစ်တယ်။
    final bytes = Uint8List.fromList([
      0xFF, 0xD8,
      0xFF, 0xC4, 0x00, 0x04, 0x00, 0x00, // DHT — ကျော်ရမယ်
      0xFF, 0xC0, 0x00, 0x11, 0x08, 0x00, 0x64, 0x00, 0xC8, 0x03,
    ]);
    expect(jpegSize(bytes)?.toString(), '200×100');
  });

  test('returns null for data that is not a JPEG', () {
    expect(jpegSize(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47])), isNull); // PNG
    expect(jpegSize(Uint8List(0)), isNull);
  });
}
