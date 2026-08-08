import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

import '../models/ai_care_advice.dart';
import '../theme/app_colors.dart';
import 'gemini_service.dart';

/// Plant အခြေအနေ အကြီးစား အမျိုးအစားများ။
enum PlantStatusLevel { unknown, good, warning, critical }

/// စာသားအစား verdict ကို enum အဖြစ်ထားတာမို့ UI ကပဲ ဘာသာစကားအလိုက်
/// [AppStrings.verdictHeadline] နဲ့ ဘာသာပြန်ပြနိုင်တယ်။
enum PlantVerdict { unknown, dry, pestRisk, tooHot, tooCold, good }

/// ချိတ်ဆက်မှု အမှား အမျိုးအစား (စာသားက UI ဘက်မှာ ဘာသာပြန်ထားတယ်)။
enum ConnectionError { unreachable, badStatus }

/// Sensor တစ်ခုချင်းစီရဲ့ အခြေအနေ အဆင့် — UI မှာ အရောင်/badge ရွေးဖို့။
enum ConditionLevel { good, warning, critical }

/// အပူချိန် အခြေအနေ (threshold တွေက [PlantService] ထဲမှာ)။
enum TempCondition {
  coldStress(ConditionLevel.critical),
  low(ConditionLevel.warning),
  optimal(ConditionLevel.good),
  warm(ConditionLevel.warning),
  heatStress(ConditionLevel.critical);

  const TempCondition(this.level);

  final ConditionLevel level;
}

/// လေထု စိုထိုင်းဆ အခြေအနေ။
enum HumidityCondition {
  dry(ConditionLevel.warning),
  normal(ConditionLevel.good),
  high(ConditionLevel.warning);

  const HumidityCondition(this.level);

  final ConditionLevel level;
}

/// မြေဆီ စိုထိုင်းဆ အခြေအနေ (sensor က 0/1 ပဲ ပေးတယ်)။
enum SoilCondition {
  dry(ConditionLevel.warning),
  wet(ConditionLevel.good);

  const SoilCondition(this.level);

  final ConditionLevel level;
}

/// ESP32-CAM ကနေ ဓာတ်ပုံ မဖမ်းနိုင်တဲ့အခါ ပစ်တဲ့ error။
class PlantCameraException implements Exception {
  const PlantCameraException(this.url, {this.statusCode});

  final String url;
  final int? statusCode;
}

/// ESP32 sensor data + verdict တွေကို တစ်နေရာတည်းမှာ စုထားပြီး
/// tab အားလုံး (Home / Camera / AI / Settings) မျှသုံးနိုင်တဲ့ store။
///
/// ChangeNotifier ဖြစ်တာမို့ screen တွေက ListenableBuilder နဲ့ နားစွင့်ရုံပါ။
class PlantService extends ChangeNotifier {
  PlantService._();

  static final PlantService instance = PlantService._();

  // ── Network ──
  // ESP32 ရဲ့ IP လိပ်စာ။ Settings tab ကနေ ပြောင်းနိုင်တယ်။
  String host = '172.24.78.154';
  int streamPort = 8080;

  String get dataUrl => 'http://$host/data';
  String get streamUrl => 'http://$host:$streamPort/stream';

  /// ESP32-CAM ရဲ့ still-image endpoint — AI ကို ပုံပို့တဲ့အခါ သုံးတယ်။
  String get captureUrl => 'http://$host:$streamPort/capture';

  // ── Care thresholds ──
  static const int nMin = 50;
  static const int pMin = 30;
  static const int kMin = 50;
  static const double lightMin = 5000;

  // ── Sensor data ──
  double temp = 0.0;
  double humid = 0.0;
  int soilMoisture = 0;
  int nitrogen = 0;
  int phosphorus = 0;
  int potassium = 0;
  double light = 0.0;

  // ── Meta ──
  /// ESP32-CAM က client တစ်ခုတည်းသာ လက်ခံတာမို့ ဓာတ်ပုံဖမ်းနေချိန်မှာ
  /// live preview တွေက ဒီ flag ကို ကြည့်ပြီး ခဏ ဖြုတ်ပေးရတယ်။
  bool streamPaused = false;

  bool isLoading = false;
  bool hasData = false;
  ConnectionError? lastError;
  int? lastErrorStatusCode;
  DateTime? lastUpdated;

  // ── Soil moisture as a percentage ──
  // Sensor က 0 / 1 ပဲ ပြန်ပေးတာမို့ UI မှာ percent အဖြစ် ပြနိုင်အောင် map လုပ်ထားတယ်။
  // Raw 0 = ခြောက်သွေ့ (dry)၊ Raw 1 = စိုစွတ် (moist)။
  // တန်ဖိုးတွေကို ဒီနှစ်ခုပဲ ပြင်ရုံနဲ့ ရတယ်။
  static const int soilPercentWhenDry = 0;
  static const int soilPercentWhenWet = 40;

  bool get isSoilDry => soilMoisture == 0;

  int get soilMoisturePercent => isSoilDry ? soilPercentWhenDry : soilPercentWhenWet;

  // ── Condition thresholds (AI မလိုဘဲ app ဘက်မှာတိုက်ရိုက် တွက်တဲ့ စည်းမျဉ်းများ) ──
  // အပူချိန်: <15 အအေးဒဏ် · 15–20 အအေး · 20–32 အကောင်းဆုံး · 32–35 ပူနွေး · >35 အပူဒဏ်
  static const double tempColdStressBelow = 15.0;
  static const double tempLowBelow = 20.0;
  static const double tempOptimalMax = 32.0;
  static const double tempWarmMax = 35.0;

  // စိုထိုင်းဆ: <50% ခြောက် · 50–80% ပုံမှန် · >80% စိုလွန်း
  static const double humidityDryBelow = 50.0;
  static const double humidityNormalMax = 80.0;

  TempCondition get tempCondition {
    if (temp < tempColdStressBelow) return TempCondition.coldStress;
    if (temp < tempLowBelow) return TempCondition.low;
    if (temp <= tempOptimalMax) return TempCondition.optimal;
    if (temp <= tempWarmMax) return TempCondition.warm;
    return TempCondition.heatStress;
  }

  HumidityCondition get humidityCondition {
    if (humid < humidityDryBelow) return HumidityCondition.dry;
    if (humid <= humidityNormalMax) return HumidityCondition.normal;
    return HumidityCondition.high;
  }

  SoilCondition get soilCondition => isSoilDry ? SoilCondition.dry : SoilCondition.wet;

  // ── Derived verdicts ──
  bool get needsWater => isSoilDry;
  bool get needsNitrogen => nitrogen < nMin;
  bool get needsPhosphorus => phosphorus < pMin;
  bool get needsPotassium => potassium < kMin;
  bool get needsNpk => needsNitrogen || needsPhosphorus || needsPotassium;
  bool get needsLight => light < lightMin;

  PlantStatusLevel level = PlantStatusLevel.unknown;
  PlantVerdict verdict = PlantVerdict.unknown;

  Color get statusColor => switch (level) {
    PlantStatusLevel.good => AppColors.green,
    PlantStatusLevel.warning => AppColors.orange,
    PlantStatusLevel.critical => AppColors.red,
    PlantStatusLevel.unknown => AppColors.secondaryLabel,
  };

  IconData get statusIcon => switch (level) {
    PlantStatusLevel.good => CupertinoIcons.check_mark_circled_solid,
    PlantStatusLevel.warning => CupertinoIcons.drop_fill,
    PlantStatusLevel.critical => CupertinoIcons.exclamationmark_triangle_fill,
    PlantStatusLevel.unknown => CupertinoIcons.leaf_arrow_circlepath,
  };

  // ── AI care guide ──
  AiCareAdvice? aiAdvice;
  bool aiLoading = false;
  String? aiError;

  /// Home screen က "AI ကို မေးမယ်" ခလုတ်တွေနဲ့ အစားထိုးလိုက်တာမို့ ယခု
  /// အလိုအလျောက် မခေါ်တော့ဘူး။ Care Guide ကို ပြန်ဖွင့်ချင်ရင် refresh() ထဲမှာ
  /// ဒီ method ကို ပြန်ခေါ်ရုံပါပဲ (quota သက်သာအောင် ခဏဖြုတ်ထားတာ)။
  /// Sensor data အသစ်ရပြီးတိုင်း Gemini ဆီပို့ပြီး care guide ပြန်ယူတယ်။
  /// API key မရှိရင် သို့မဟုတ် network ကျရင် [aiError] တင်ပြီး
  /// Home screen က threshold-based guide ကို fallback အဖြစ် ပြပါတယ်။
  Future<void> refreshAiAdvice() async {
    if (!hasData) return;
    aiLoading = true;
    aiError = null;
    notifyListeners();

    try {
      aiAdvice = await GeminiService().careGuideFromSensors(
        temperature: temp,
        humidity: humid,
        soilMoisture: soilMoisture,
        nitrogen: nitrogen,
        phosphorus: phosphorus,
        potassium: potassium,
        light: light,
      );
    } catch (e) {
      aiError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      aiLoading = false;
      notifyListeners();
    }
  }

  void updateHost(String newHost, {int? port}) {
    final trimmed = newHost.trim();
    if (trimmed.isEmpty) return;
    host = trimmed;
    if (port != null && port > 0) streamPort = port;
    notifyListeners();
  }

  /// ESP32 ဆီက data ဆွဲယူပြီး verdict တွေ ပြန်တွက်တယ်။
  /// Error တင်ရင် dialog မပြဘဲ [lastError] ထဲထည့်ပေးတာမို့ UI ကပဲ ဆုံးဖြတ်နိုင်တယ်။
  Future<void> refresh() async {
    isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse(dataUrl)).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        lastError = ConnectionError.badStatus;
        lastErrorStatusCode = response.statusCode;
      } else {
        // ESP32 က JSON သို့မဟုတ် HTML dashboard ပြန်ပေးနိုင်တာမို့ နှစ်မျိုးလုံး ဖတ်နိုင်အောင် လုပ်ထားတယ်။
        final data = _parseSensorData(response.body);
        temp = data['temperature'] ?? temp;
        humid = data['humidity'] ?? humid;
        soilMoisture = (data['soil_moisture'] ?? soilMoisture.toDouble()).toInt();
        _recomputeVerdict();
        hasData = true;
        lastError = null;
        lastErrorStatusCode = null;
        lastUpdated = DateTime.now();
      }
    } catch (_) {
      lastError = ConnectionError.unreachable;
      lastErrorStatusCode = null;
    } finally {
      isLoading = false;
      notifyListeners();
    }

  }

  /// ESP32-CAM ကနေ ဓာတ်ပုံတစ်ပုံ ဖမ်းယူတယ် (AI ကို ပို့ဖို့)။
  ///
  /// ESP32-CAM က client တစ်ခုတည်းသာ လက်ခံတာမို့ ဖမ်းနေချိန်မှာ live preview တွေကို
  /// [streamPaused] နဲ့ ဖြုတ်ထားရတယ် — မဟုတ်ရင် socket မလွတ်လို့ capture က အမြဲကျတယ်။
  /// /capture endpoint မရှိတဲ့ firmware ဆိုရင် MJPEG stream ထဲက frame တစ်ခုကို
  /// ဆွဲထုတ်ပြီး သုံးတယ်။
  Future<Uint8List> captureStill() async {
    streamPaused = true;
    notifyListeners();
    // preview socket အပြည့်အဝ ပိတ်သွားဖို့ ခဏစောင့်။
    await Future<void>.delayed(const Duration(milliseconds: 600));
    try {
      // firmware အလိုက် /capture က stream port မှာ ဒါမှမဟုတ် port 80 မှာ ရှိနိုင်တယ်။
      for (final url in {captureUrl, 'http://$host/capture'}) {
        final bytes = await _tryCapture(url);
        if (bytes != null) return bytes;
      }
      final frame = await _frameFromStream();
      if (frame != null) return frame;
      throw PlantCameraException(captureUrl);
    } finally {
      streamPaused = false;
      notifyListeners();
    }
  }

  /// /capture endpoint တစ်ခုကို စမ်းခေါ်တယ် — JPEG မဟုတ်ရင် (404 page စတာ) null ပြန်တယ်။
  Future<Uint8List?> _tryCapture(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final bytes = response.bodyBytes;
      return _isJpeg(bytes) ? bytes : null;
    } catch (_) {
      return null;
    }
  }

  /// MJPEG stream ကို ဖွင့်ပြီး ပထမဆုံး ပြည့်စုံတဲ့ JPEG frame တစ်ခုကို ဆွဲထုတ်တယ်။
  /// multipart boundary တွေကို ဖတ်စရာမလိုဘဲ SOI (FFD8) → EOI (FFD9) ကိုပဲ ရှာတယ်။
  Future<Uint8List?> _frameFromStream() async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(streamUrl));
      final response = await client.send(request).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final buffer = <int>[];
      await for (final chunk in response.stream.timeout(const Duration(seconds: 10))) {
        buffer.addAll(chunk);
        final frame = _extractJpeg(Uint8List.fromList(buffer));
        if (frame != null) return frame;
        // frame တစ်ခုစာထက် များစွာ ကြီးလာရင် ရပ် (ဖမ်းလို့မရတဲ့ stream ကနေ memory မကုန်အောင်)။
        if (buffer.length > 4 * 1024 * 1024) break;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  static bool _isJpeg(Uint8List bytes) => bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8;

  /// buffer ထဲမှာ SOI နဲ့ EOI နှစ်ခုလုံး ရှိပြီဆိုရင် ကြားထဲက JPEG ကို ပြန်ပေးတယ်။
  static Uint8List? _extractJpeg(Uint8List bytes) {
    var start = -1;
    for (var i = 0; i + 1 < bytes.length; i++) {
      if (bytes[i] != 0xFF) continue;
      if (start < 0) {
        if (bytes[i + 1] == 0xD8) start = i;
      } else if (bytes[i + 1] == 0xD9) {
        return Uint8List.sublistView(bytes, start, i + 2);
      }
    }
    return null;
  }

  void _recomputeVerdict() {
    if (isSoilDry) {
      level = PlantStatusLevel.warning;
      verdict = PlantVerdict.dry;
    } else if (humidityCondition == HumidityCondition.high && temp > 28.0) {
      level = PlantStatusLevel.critical;
      verdict = PlantVerdict.pestRisk;
    } else if (tempCondition == TempCondition.heatStress || tempCondition == TempCondition.warm) {
      level = tempCondition.level == ConditionLevel.critical ? PlantStatusLevel.critical : PlantStatusLevel.warning;
      verdict = PlantVerdict.tooHot;
    } else if (tempCondition == TempCondition.coldStress || tempCondition == TempCondition.low) {
      level = tempCondition.level == ConditionLevel.critical ? PlantStatusLevel.critical : PlantStatusLevel.warning;
      verdict = PlantVerdict.tooCold;
    } else {
      level = PlantStatusLevel.good;
      verdict = PlantVerdict.good;
    }
  }

  // ── Sensor data parser (JSON or HTML) ──
  // ESP32 က JSON ပြန်ရင် JSON အဖြစ် ဖတ်တယ်။ HTML dashboard ပြန်ရင်တော့
  // tag တွေ ဖယ်ပြီး "Temperature: 0.60 C" လိုစာသားထဲက ကိန်းဂဏန်းတွေ regex နဲ့ ဆွဲထုတ်တယ်။
  Map<String, double> _parseSensorData(String body) {
    final result = <String, double>{};

    // 1) JSON ဖြစ်ချင်ဖြစ်နိုင်တာမို့ အရင်စမ်းဖတ်
    final trimmed = body.trimLeft();
    if (trimmed.startsWith('{')) {
      try {
        final data = json.decode(body) as Map<String, dynamic>;
        void take(String key, String out) {
          final v = data[key];
          if (v is num) result[out] = v.toDouble();
        }

        take('temperature', 'temperature');
        take('humidity', 'humidity');
        take('soil_moisture', 'soil_moisture');
        take('soilMoisture', 'soil_moisture');
        if (result.isNotEmpty) return result;
      } catch (_) {
        // JSON မဟုတ်ရင် အောက်က HTML parsing ဆက်လုပ်
      }
    }

    // 2) HTML/text အဖြစ် ဖတ် — tag တွေ ဖယ်ပြီး label နောက်က နံပါတ်ကို ရှာ
    final text = body.replaceAll(RegExp(r'<[^>]*>'), ' ');
    double? grab(String label) {
      final m = RegExp(
        '$label'
        r'\s*:?\s*([-\d.]+)',
        caseSensitive: false,
      ).firstMatch(text);
      if (m == null) return null;
      return double.tryParse(m.group(1)!);
    }

    final t = grab('Temperature');
    final h = grab('Humidity');
    final s = grab(r'Soil\s*Moisture');
    if (t != null) result['temperature'] = t;
    if (h != null) result['humidity'] = h;
    if (s != null) result['soil_moisture'] = s;
    return result;
  }
}
