import 'dart:io' show Platform;

import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// [BlynkService.openBlynkApp] ရဲ့ ရလဒ် — UI က ဘာပြရမလဲ ဆုံးဖြတ်ဖို့။
enum BlynkLaunchOutcome {
  /// Blynk app ကို ဖွင့်ပြီးပြီ။
  openedApp,

  /// App မရှိလို့ Play Store (ဒါမှမဟုတ် web console) ကို ဖွင့်ပေးလိုက်တယ်။
  openedStore,

  /// ဘာမှ ဖွင့်လို့ မရဘူး — user ကို အသိပေးရမယ်။
  failed,
}

/// Blynk Cloud နဲ့ ဆက်သွယ်တဲ့ service။
///
/// နှစ်မျိုး လုပ်ပေးတယ် —
/// 1. ဖုန်းထဲက Blynk app ကို လှမ်းဖွင့်ပေးတယ် ([openBlynkApp])။
/// 2. Blynk Cloud HTTP API ကနေ virtual pin ကို တိုက်ရိုက် ရေးပေးတယ် ([writePin])
///    — ရေစုပ်စက်/မီး စတဲ့ hardware ခလုတ်တွေကို app ထဲကနေ ဖွင့်/ပိတ်ဖို့။
class BlynkService {
  static final BlynkService instance = BlynkService._internal();

  BlynkService._internal();

  /// Blynk IoT (အသစ်) နဲ့ Blynk legacy (အဟောင်း) — နှစ်ခုလုံး စစ်ပေးတယ်။
  /// AndroidManifest ရဲ့ `<queries>` ထဲမှာလည်း ဒီနှစ်ခု ကြေညာထားရမယ်၊
  /// မဟုတ်ရင် Android 11+ မှာ တပ်ဆင်ထားရဲ့သားနဲ့ "မတွေ့ဘူး" ဖြစ်တယ်။
  static const List<String> _androidPackages = ['cloud.blynk', 'cc.blynk'];
  static final Uri _playStoreLink = Uri.parse('https://play.google.com/store/apps/details?id=cloud.blynk');

  /// Android မဟုတ်တဲ့ platform (iOS/desktop) မှာ app ကို package name နဲ့
  /// ဖွင့်လို့မရတာမို့ browser က Blynk console ကို ဖွင့်ပေးတယ်။
  static final Uri _webConsole = Uri.parse('https://blynk.cloud/dashboard');

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
  /// App မရှိရင် Play Store (Android မဟုတ်ရင် web console) ကို ဖွင့်ပေးတယ်။
  ///
  /// မှတ်ချက် — `LaunchApp.openApp` က မအောင်မြင်လည်း **exception မပစ်ဘူး**။
  /// Android ဘက်က အမှားကို စာသားအဖြစ် ပြန်ပေးပြီး Dart က `0` အဖြစ် ပြောင်းလိုက်တာမို့
  /// try/catch နဲ့ ဖမ်းလို့ မရဘူး — return code ကိုပဲ ကြည့်ရတယ်
  /// (`1` = app ပွင့်သွားပြီ)။ အရင်က catch နဲ့ ဖမ်းထားလို့ ခလုတ်နှိပ်လည်း
  /// ဘာမှ မဖြစ်တာ ဒါကြောင့်ပါ။
  static Future<BlynkLaunchOutcome> openBlynkApp() async {
    if (Platform.isAndroid) {
      for (final package in _androidPackages) {
        try {
          final installed = await LaunchApp.isAppInstalled(androidPackageName: package);
          if (installed != true) continue;
          final code = await LaunchApp.openApp(androidPackageName: package, openStore: false);
          if (code == 1) return BlynkLaunchOutcome.openedApp;
        } catch (_) {
          // package တစ်ခုမှာ ပြဿနာတက်ရင် နောက်တစ်ခု ဆက်စမ်း။
          continue;
        }
      }
    }

    // App မရှိဘူး — Store (ဒါမှမဟုတ် browser) နဲ့ ဆက်ကြည့်တယ်။
    // url_launcher က အောင်/မအောင် bool ပြန်ပေးတာမို့ ဒီနေရာမှာ သေချာ သိရတယ်။
    final fallback = Platform.isAndroid ? _playStoreLink : _webConsole;
    try {
      final opened = await launchUrl(fallback, mode: LaunchMode.externalApplication);
      return opened ? BlynkLaunchOutcome.openedStore : BlynkLaunchOutcome.failed;
    } catch (_) {
      return BlynkLaunchOutcome.failed;
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
