import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:http/http.dart' as http;

/// Blynk Cloud နဲ့ ဆက်သွယ်တဲ့ service။
///
/// နှစ်မျိုး လုပ်ပေးတယ် —
/// 1. ဖုန်းထဲက Blynk app ကို လှမ်းဖွင့်ပေးတယ် ([openBlynkApp])။
/// 2. Blynk Cloud HTTP API ကနေ virtual pin ကို တိုက်ရိုက် ရေးပေးတယ် ([writePin])
///    — ရေစုပ်စက်/မီး စတဲ့ hardware ခလုတ်တွေကို app ထဲကနေ ဖွင့်/ပိတ်ဖို့။
class BlynkService {
  static final BlynkService instance = BlynkService._internal();

  BlynkService._internal();

  static const String _androidPackage = 'cloud.blynk';
  static const String _playStoreLink = 'https://play.google.com/store/apps/details?id=$_androidPackage';

  final String _authToken = 'AchCAUSnNG6wdAqI6hPmxG1QLmcExHNE';
  final String _baseUrl = 'https://sgp1.blynk.cloud/external/api';

  /// Blynk API ကို browser နဲ့ ဖွင့်ကြည့်ဖို့ လင့်ခ်။
  ///
  /// မှတ်ချက် — base URL သီးသန့် (`/external/api`) ဖွင့်ရင် Blynk က
  /// "No token provided" ဆိုပြီး ပြန်တယ်။ token ပါတဲ့ endpoint အပြည့်အစုံကိုမှ
  /// ဖွင့်ရမယ် — ဒီမှာ hardware ချိတ်ဆက်မှု စစ်တဲ့ endpoint ကို သုံးထားတယ်
  /// (`true` / `false` ပဲ ပြန်တယ်)။
  Uri get statusUrl => Uri.parse('$_baseUrl/isHardwareConnected?token=$_authToken');

  /// ESP32 က Blynk Cloud နဲ့ ချိတ်ဆက်ထားသေးလား စစ်တယ်။
  Future<bool> isHardwareConnected() async {
    final response = await http.get(statusUrl).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('Blynk returned status code ${response.statusCode}');
    }
    return response.body.trim().toLowerCase() == 'true';
  }

  /// ဖုန်းထဲမှာ တပ်ဆင်ထားတဲ့ Blynk app ကို ဖွင့်တယ်။
  /// App မရှိရင် (ဒါမှမဟုတ် ဖွင့်လို့ မရရင်) Play Store ဆီ ပို့ပေးတယ်။
  static Future<void> openBlynkApp() async {
    try {
      await LaunchApp.openApp(
        androidPackageName: _androidPackage,
        appStoreLink: _playStoreLink,
        // App ရှိရင် တန်းဖွင့် — Store ဆီ အတင်း မပို့ဘူး။
        openStore: false,
      );
    } catch (_) {
      // App လုံးဝ မရှိရင် Play Store ဆီ ပို့ပေးတယ်။
      await LaunchApp.openApp(
        androidPackageName: _androidPackage,
        appStoreLink: _playStoreLink,
        openStore: true,
      );
    }
  }

  /// Virtual pin တစ်ခုကို တန်ဖိုးရေးပြီး hardware ကို control လုပ်တယ်။
  /// ဥပမာ `writePin(1, 1)` က V1 ကို ON လုပ်တာ။
  Future<void> writePin(int pinNumber, int value) async {
    final url = Uri.parse('$_baseUrl/update?token=$_authToken&v$pinNumber=$value');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw Exception('Failed to update Blynk status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Blynk Network Error: $e');
    }
  }
}
