import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

import '../models/ai_care_advice.dart';
import '../theme/app_colors.dart';
import 'gemini_service.dart';

/// Plant အခြေအနေ အကြီးစား အမျိုးအစားများ။
enum PlantStatusLevel { unknown, good, warning, critical }

/// စာသားအစား verdict ကို enum အဖြစ်ထားတာမို့ UI ကပဲ ဘာသာစကားအလိုက်
/// [AppStrings.verdictHeadline] နဲ့ ဘာသာပြန်ပြနိုင်တယ်။
enum PlantVerdict { unknown, dry, pestRisk, tooHot, good }

/// ချိတ်ဆက်မှု အမှား အမျိုးအစား (စာသားက UI ဘက်မှာ ဘာသာပြန်ထားတယ်)။
enum ConnectionError { unreachable, badStatus }

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
  bool isLoading = false;
  bool hasData = false;
  ConnectionError? lastError;
  int? lastErrorStatusCode;
  DateTime? lastUpdated;

  // ── Derived verdicts ──
  bool get needsWater => soilMoisture == 1;
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

    // AI ကို await မလုပ်ဘဲ နောက်ကွယ်မှာ ဆက်ခေါ်တယ် — sensor UI က မစောင့်ရအောင်။
    if (hasData) unawaited(refreshAiAdvice());
  }

  void _recomputeVerdict() {
    if (soilMoisture == 1) {
      level = PlantStatusLevel.warning;
      verdict = PlantVerdict.dry;
    } else if (humid > 80.0 && temp > 28.0) {
      level = PlantStatusLevel.critical;
      verdict = PlantVerdict.pestRisk;
    } else if (temp > 35.0) {
      level = PlantStatusLevel.warning;
      verdict = PlantVerdict.tooHot;
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
