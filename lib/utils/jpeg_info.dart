import 'dart:typed_data';

/// JPEG တစ်ပုံရဲ့ အရွယ်အစား (pixel)။
class ImageSize {
  const ImageSize(this.width, this.height);

  final int width;
  final int height;

  /// ဘေးတိုဘက်ရဲ့ pixel အရေအတွက် — "ဘယ်လောက် သေးလဲ" ဆိုတာ တိုင်းဖို့။
  int get shortSide => width < height ? width : height;

  /// ESP32-CAM ရဲ့ သေးငယ်တဲ့ framesize (QQVGA 160×120၊ QCIF 176×144 စသဖြင့်)
  /// ဆိုရင် အသေးစိတ် အကွက်အကွင်းတွေ ပျောက်နေပြီ။
  bool get isLowResolution => shortSide <= 240;

  @override
  String toString() => '$width×$height';
}

/// JPEG bytes ထဲက width/height ကို package မထည့်ဘဲ ဖတ်တယ်။
///
/// SOI (FFD8) ပြီးရင် marker segment တွေကို ခုန်ကျော်ရင်း SOF marker
/// (FFC0–FFCF — DHT/JPG/DAC တွေ မပါ) ကို ရှာတယ်။ SOF payload ရဲ့
/// byte 1 က precision၊ 2–3 က height၊ 4–5 က width ဖြစ်တယ်။
/// JPEG မဟုတ်ရင် ဒါမှမဟုတ် ဖတ်လို့မရရင် null ပြန်တယ် — ဖတ်လို့မရတာက
/// အမှားမဟုတ်ဘဲ "မသိဘူး" ပဲ ဖြစ်သင့်တယ်။
ImageSize? jpegSize(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;

  var i = 2;
  while (i + 3 < bytes.length) {
    // Marker တစ်ခုက FF နဲ့ စရမယ် — padding FF တွေ ခုန်ကျော်။
    if (bytes[i] != 0xFF) {
      i++;
      continue;
    }
    var marker = bytes[i + 1];
    while (marker == 0xFF && i + 2 < bytes.length) {
      i++;
      marker = bytes[i + 1];
    }
    i += 2;

    // Standalone marker တွေမှာ length မပါဘူး။
    if (marker == 0xD8 || marker == 0xD9 || (marker >= 0xD0 && marker <= 0xD7)) continue;
    if (i + 1 >= bytes.length) return null;

    final length = (bytes[i] << 8) | bytes[i + 1];
    if (length < 2) return null;

    final isSof = marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC;
    if (isSof) {
      if (i + 7 >= bytes.length) return null;
      final height = (bytes[i + 3] << 8) | bytes[i + 4];
      final width = (bytes[i + 5] << 8) | bytes[i + 6];
      if (width <= 0 || height <= 0) return null;
      return ImageSize(width, height);
    }

    // SOS ရောက်ရင် နောက်က entropy data ချည်းမို့ ဆက်ရှာစရာ မလိုတော့ဘူး။
    if (marker == 0xDA) return null;
    i += length;
  }
  return null;
}
