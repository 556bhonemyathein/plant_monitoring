import 'package:flutter/cupertino.dart';

import '../services/plant_service.dart';

/// App က ထောက်ပံ့တဲ့ ဘာသာစကားများ။
enum AppLanguage {
  english('English', 'EN'),
  myanmar('မြန်မာ', 'MM');

  const AppLanguage(this.label, this.shortLabel);

  /// Settings က segmented control ပေါ်မှာ ပြမယ့် နာမည် (ကိုယ့်ဘာသာစကားနဲ့ကိုယ်)။
  final String label;
  final String shortLabel;

  /// Gemini prompt ထဲ ထည့်ပေးမယ့် ဘာသာစကား အမည်။
  String get promptName => switch (this) {
    AppLanguage.english => 'English',
    AppLanguage.myanmar => 'Burmese (Myanmar language)',
  };
}

/// ရွေးထားတဲ့ ဘာသာစကားကို သိမ်းထားပြီး ပြောင်းတိုင်း listener တွေကို အသိပေးတယ်။
///
/// မှတ်ချက်: host/port setting တွေလိုပဲ memory ထဲမှာသာ ရှိတာမို့
/// app ပိတ်ပြန်ဖွင့်ရင် English ကို ပြန်ရောက်တယ်။
class LocaleController extends ChangeNotifier {
  LocaleController._();

  static final LocaleController instance = LocaleController._();

  AppLanguage _language = AppLanguage.english;
  AppLanguage get language => _language;

  AppStrings get strings => switch (_language) {
    AppLanguage.english => const _EnStrings(),
    AppLanguage.myanmar => const _MyStrings(),
  };

  void setLanguage(AppLanguage value) {
    if (value == _language) return;
    _language = value;
    notifyListeners();
  }
}

/// Widget tree ထဲ ဘယ်နေရာကမဆို `AppLocale.of(context)` နဲ့ စာသားတွေ ယူနိုင်တယ်။
/// InheritedNotifier ဖြစ်တာမို့ ဘာသာစကား ပြောင်းတာနဲ့ သုံးထားတဲ့ widget တွေ
/// အလိုအလျောက် rebuild ဖြစ်သွားတယ်။
class AppLocale extends InheritedNotifier<LocaleController> {
  const AppLocale({super.key, required LocaleController controller, required super.child}) : super(notifier: controller);

  static AppStrings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppLocale>();
    return (scope?.notifier ?? LocaleController.instance).strings;
  }

  static AppLanguage languageOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppLocale>();
    return (scope?.notifier ?? LocaleController.instance).language;
  }
}

/// UI စာသားအားလုံးရဲ့ စာရင်း။ ဘာသာစကားတစ်ခုစီအတွက် အောက်မှာ implement လုပ်ထားတယ်။
abstract class AppStrings {
  const AppStrings();

  // ── Common ──
  String get appTitle;
  String get ok;
  String get cancel;
  String get error;
  String get tryAgain;
  String get live;

  // ── Navigation ──
  String get navHome;
  String get navLive;
  String get navAiScan;
  String get navSettings;

  // ── Home ──
  String get currentStatus;
  String get sensorReadings;
  String get temperature;
  String get humidity;
  String get soilMoisture;
  String get careGuide;
  String get aiBadge;

  // ── Home ရဲ့ sensor အခြေအနေ (AI မလို — app ကိုယ်တိုင် တွက်တာ) ──
  String get conditionSection;
  String tempConditionLabel(TempCondition condition);
  String tempConditionAdvice(TempCondition condition);
  String humidityConditionLabel(HumidityCondition condition);
  String humidityConditionAdvice(HumidityCondition condition);
  String soilConditionLabel(SoilCondition condition);
  String soilConditionAdvice(SoilCondition condition);

  // ── Home ရဲ့ "AI ကို မေးမယ်" ခလုတ်များ ──
  String get askAiCameraSection;
  String get askDiseaseTitle;
  String get askDiseaseSubtitle;
  String get askSprayTitle;
  String get askSpraySubtitle;
  String get aiThinking;
  String get capturingPhoto;
  String captureFailed(String url);
  String get aiAnswerTitle;

  String get checkForUpdates;
  String get cameraStreamDisconnected;
  String get previewPaused;
  String get waitingForSensorTitle;
  String get waitingForSensorMessage;
  String get askingAiTitle;
  String get askingAiMessage;
  String get aiUnavailableTitle;
  String get aiUnavailableMessage;
  String get water;
  String get soilMoistOk;
  String get soilDryAction;
  String get actionBadge;
  String get okBadge;
  String get lowBadge;
  String get urgencyNow;
  String get urgencySoon;
  String get urgencyOk;

  // ── Camera ──
  String get reload;
  String get streamDisconnectedTitle;
  String streamDisconnectedMessage(String host);
  String get soilDryShort;
  String get soilMoistShort;

  // ── AI Scan ──
  String get aiScanTitle;
  String get addPhoto;
  String get changePhoto;
  String get reanalyze;
  String get scanLeafTitle;
  String get scanLeafSubtitle;
  String get sensorContextTitle;
  String sensorContextValue({required double temp, required double humidity, required bool dry});
  String get aiDiagnosis;
  String get analyzingTitle;
  String get analyzingSubtitle;
  String get couldNotAnalyze;
  String get addPlantPhoto;
  String get takePhoto;
  String get chooseFromGallery;
  String couldNotOpenImage(Object error);
  String aiAnalysisFailed(Object error);

  // ── Settings ──
  String get settingsTitle;
  String get languageSection;
  String get languageFooter;
  String get deviceSection;
  String get hostField;
  String get portField;
  String get saveDeviceSettings;
  String get connectionSection;
  String get dataEndpoint;
  String get streamEndpoint;
  String get lastSync;
  String get testConnection;
  String get thresholdsSection;
  String get nitrogenMin;
  String get phosphorusMin;
  String get potassiumMin;
  String get lightMin;
  String get savedTitle;
  String savedMessage(String host, int port);
  String get connectedTitle;
  String connectedMessage(String url);
  String get connectionFailedTitle;
  String get appVersion;

  // ── PlantService ကနေလာတဲ့ dynamic စာသားများ ──
  String verdictHeadline(PlantVerdict verdict);
  String verdictAdvice(PlantVerdict verdict);
  String lastUpdatedLabel(DateTime? at);
  String connectionError(ConnectionError error, {required String host, int? statusCode});
}

class _EnStrings extends AppStrings {
  const _EnStrings();

  @override
  String get appTitle => 'Plant Monitoring';
  @override
  String get ok => 'OK';
  @override
  String get cancel => 'Cancel';
  @override
  String get error => 'Error';
  @override
  String get tryAgain => 'Try again';
  @override
  String get live => 'LIVE';

  @override
  String get navHome => 'Home';
  @override
  String get navLive => 'Live';
  @override
  String get navAiScan => 'AI Scan';
  @override
  String get navSettings => 'Settings';

  @override
  String get currentStatus => 'CURRENT STATUS';
  @override
  String get sensorReadings => 'Sensor Readings';
  @override
  String get temperature => 'Temperature';
  @override
  String get humidity => 'Humidity';
  @override
  String get soilMoisture => 'Soil Moisture';
  @override
  String get careGuide => 'Care Guide';
  @override
  String get aiBadge => 'AI';

  @override
  String get conditionSection => 'Sensor condition';

  @override
  String tempConditionLabel(TempCondition condition) => switch (condition) {
    TempCondition.coldStress => 'Cold stress (below 15°C)',
    TempCondition.low => 'Low temperature (15–20°C)',
    TempCondition.optimal => 'Optimal (20–32°C)',
    TempCondition.warm => 'Warm (32–35°C)',
    TempCondition.heatStress => 'Heat stress (above 35°C)',
  };

  @override
  String tempConditionAdvice(TempCondition condition) => switch (condition) {
    TempCondition.coldStress => 'Growth stops and flowers may not set fruit. Raise the water level to keep the roots warm.',
    TempCondition.low => 'Growth slows down and the roots take up fewer nutrients. Keep watching it.',
    TempCondition.optimal => 'Best range for growth, strength and fruit set. Keep things as they are.',
    TempCondition.warm => 'The plant drinks more water and loses it faster through the leaves. Water more often.',
    TempCondition.heatStress => 'Heat can make the flowers sterile and dry the plant out. Move it to shade and water it now.',
  };

  @override
  String humidityConditionLabel(HumidityCondition condition) => switch (condition) {
    HumidityCondition.dry => 'Dry air (below 50%)',
    HumidityCondition.normal => 'Normal (50–80%)',
    HumidityCondition.high => 'Too humid (above 80%)',
  };

  @override
  String humidityConditionAdvice(HumidityCondition condition) => switch (condition) {
    HumidityCondition.dry => 'The air is dry, so the plant may need water.',
    HumidityCondition.normal => 'Comfortable air humidity for the plant.',
    HumidityCondition.high => 'Watch out for fungal disease — improve the air flow around the plant.',
  };

  @override
  String soilConditionLabel(SoilCondition condition) => switch (condition) {
    SoilCondition.dry => 'Dry (below 50%)',
    SoilCondition.wet => 'Wet (above 60%)',
  };

  @override
  String soilConditionAdvice(SoilCondition condition) => switch (condition) {
    SoilCondition.dry => 'The plant is thirsty — water it now.',
    SoilCondition.wet => 'The plant has enough water.',
  };

  @override
  String get askAiCameraSection => 'Ask about the camera photo';
  @override
  String get askDiseaseTitle => 'Diagnose the plant';
  @override
  String get askDiseaseSubtitle => 'What disease does this plant have?';
  @override
  String get askSprayTitle => 'What should I spray?';
  @override
  String get askSpraySubtitle => 'Which treatment should I use?';
  @override
  String get aiThinking => 'The AI is thinking…';
  @override
  String get capturingPhoto => 'Taking a photo from the camera…';
  @override
  String captureFailed(String url) => 'Could not take a photo from the camera ($url). Check that the ESP32-CAM is on and reachable.';
  @override
  String get aiAnswerTitle => 'AI answer';
  @override
  String get checkForUpdates => 'Check for updates';
  @override
  String get cameraStreamDisconnected => 'Camera Stream Disconnected';
  @override
  String get previewPaused => 'Preview paused — open the Live tab to watch';
  @override
  String get waitingForSensorTitle => 'Waiting for sensor data';
  @override
  String get waitingForSensorMessage => 'Once the ESP32 reports its readings, the AI will suggest what your plant needs.';
  @override
  String get askingAiTitle => 'Asking the AI…';
  @override
  String get askingAiMessage => 'Reading your latest sensor values and writing a care plan.';
  @override
  String get aiUnavailableTitle => 'AI guide unavailable';
  @override
  String get aiUnavailableMessage => 'Could not reach Gemini. Showing the built-in threshold guide instead.';
  @override
  String get water => 'Water';
  @override
  String get soilMoistOk => 'Soil is moist — no watering needed';
  @override
  String get soilDryAction => 'Soil is dry — water the plant now';
  @override
  String get actionBadge => 'Action';
  @override
  String get okBadge => 'OK';
  @override
  String get lowBadge => 'Low';
  @override
  String get urgencyNow => 'Now';
  @override
  String get urgencySoon => 'Soon';
  @override
  String get urgencyOk => 'OK';

  @override
  String get reload => 'Reload';
  @override
  String get streamDisconnectedTitle => 'Camera stream disconnected';
  @override
  String streamDisconnectedMessage(String host) => 'No video from $host. Check that the ESP32-CAM is powered on and on the same network.';
  @override
  String get soilDryShort => 'Dry';
  @override
  String get soilMoistShort => 'Moist';

  @override
  String get aiScanTitle => 'AI Scan';
  @override
  String get addPhoto => 'Add photo';
  @override
  String get changePhoto => 'Change photo';
  @override
  String get reanalyze => 'Re-analyze';
  @override
  String get scanLeafTitle => 'Scan a leaf with AI';
  @override
  String get scanLeafSubtitle => 'Photo + live sensor data → diagnosis';
  @override
  String get sensorContextTitle => 'Sensor context sent with the photo';
  @override
  String sensorContextValue({required double temp, required double humidity, required bool dry}) =>
      '${temp.toStringAsFixed(1)}°C · ${humidity.toStringAsFixed(0)}% humidity · soil ${dry ? 'dry' : 'moist'}';
  @override
  String get aiDiagnosis => 'AI Diagnosis';
  @override
  String get analyzingTitle => 'Analyzing your plant…';
  @override
  String get analyzingSubtitle => 'This usually takes a few seconds';
  @override
  String get couldNotAnalyze => "Couldn't analyze this photo";
  @override
  String get addPlantPhoto => 'Add a plant photo';
  @override
  String get takePhoto => 'Take a photo';
  @override
  String get chooseFromGallery => 'Choose from gallery';
  @override
  String couldNotOpenImage(Object error) => 'Could not open the image: $error';
  @override
  String aiAnalysisFailed(Object error) => 'AI analysis failed: $error';

  @override
  String get settingsTitle => 'Settings';
  @override
  String get languageSection => 'LANGUAGE';
  @override
  String get languageFooter => 'Changes the app text and the language the AI answers in.';
  @override
  String get deviceSection => 'DEVICE';
  @override
  String get hostField => 'ESP32 host / IP';
  @override
  String get portField => 'Camera stream port';
  @override
  String get saveDeviceSettings => 'Save device settings';
  @override
  String get connectionSection => 'CONNECTION';
  @override
  String get dataEndpoint => 'Data endpoint';
  @override
  String get streamEndpoint => 'Stream endpoint';
  @override
  String get lastSync => 'Last sync';
  @override
  String get testConnection => 'Test connection';
  @override
  String get thresholdsSection => 'CARE THRESHOLDS';
  @override
  String get nitrogenMin => 'Nitrogen minimum';
  @override
  String get phosphorusMin => 'Phosphorus minimum';
  @override
  String get potassiumMin => 'Potassium minimum';
  @override
  String get lightMin => 'Light minimum';
  @override
  String get savedTitle => 'Saved';
  @override
  String savedMessage(String host, int port) => 'Now using $host for sensor data and port $port for the camera stream.';
  @override
  String get connectedTitle => 'Connected';
  @override
  String connectedMessage(String url) => 'Got sensor data from $url.';
  @override
  String get connectionFailedTitle => 'Connection failed';
  @override
  String get appVersion => 'Plant Monitoring · v1.0.0';

  @override
  String verdictHeadline(PlantVerdict verdict) => switch (verdict) {
    PlantVerdict.unknown => 'Not checked yet',
    PlantVerdict.dry => 'Soil is dry',
    PlantVerdict.pestRisk => 'High risk of pests/fungus',
    PlantVerdict.tooHot => 'Temperature is too high',
    PlantVerdict.tooCold => 'Temperature is too low',
    PlantVerdict.good => 'Plant health is good',
  };

  @override
  String verdictAdvice(PlantVerdict verdict) => switch (verdict) {
    PlantVerdict.unknown => 'Tap refresh to read the latest sensor values.',
    PlantVerdict.dry => 'Action needed: Water the plant as soon as possible.',
    PlantVerdict.pestRisk => 'Action needed: Improve air circulation and apply pesticide preventively.',
    PlantVerdict.tooHot => 'Action needed: Move the plant to shade away from direct sunlight.',
    PlantVerdict.tooCold => 'Action needed: Keep the plant warm and raise the water level to protect the roots.',
    PlantVerdict.good => 'Action needed: None. Keep maintaining it as usual.',
  };

  @override
  String lastUpdatedLabel(DateTime? at) {
    if (at == null) return 'Never updated';
    final diff = DateTime.now().difference(at);
    if (diff.inSeconds < 60) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes} min ago';
    return 'Updated ${diff.inHours} hr ago';
  }

  @override
  String connectionError(ConnectionError error, {required String host, int? statusCode}) => switch (error) {
    ConnectionError.unreachable => 'Could not connect to ESP32 at $host. Please check the Wi-Fi/network.',
    ConnectionError.badStatus => 'ESP32 responded with HTTP $statusCode.',
  };
}

class _MyStrings extends AppStrings {
  const _MyStrings();

  @override
  String get appTitle => 'အပင် စောင့်ကြည့်စနစ်';
  @override
  String get ok => 'ရပြီ';
  @override
  String get cancel => 'မလုပ်တော့ပါ';
  @override
  String get error => 'အမှား';
  @override
  String get tryAgain => 'ထပ်စမ်းကြည့်ပါ';
  @override
  String get live => 'တိုက်ရိုက်';

  @override
  String get navHome => 'ပင်မ';
  @override
  String get navLive => 'တိုက်ရိုက်';
  @override
  String get navAiScan => 'AI စစ်ဆေး';
  @override
  String get navSettings => 'ဆက်တင်';

  @override
  String get currentStatus => 'လက်ရှိအခြေအနေ';
  @override
  String get sensorReadings => 'Sensor တိုင်းတာချက်များ';
  @override
  String get temperature => 'အပူချိန်';
  @override
  String get humidity => 'စိုထိုင်းဆ';
  @override
  String get soilMoisture => 'မြေဆီစိုထိုင်းဆ';
  @override
  String get careGuide => 'ပြုစုနည်း လမ်းညွှန်';
  @override
  String get aiBadge => 'AI';

  @override
  String get conditionSection => 'Sensor အခြေအနေ';

  @override
  String tempConditionLabel(TempCondition condition) => switch (condition) {
    TempCondition.coldStress => 'အလွန်အေးလွန်း (15°C အောက်)',
    TempCondition.low => 'အေးလွန်း (15–20°C)',
    TempCondition.optimal => 'အကောင်းဆုံး (20–32°C)',
    TempCondition.warm => 'ပူနွေးလွန်း (32–35°C)',
    TempCondition.heatStress => 'အလွန်ပူလွန်း (35°C အထက်)',
  };

  @override
  String tempConditionAdvice(TempCondition condition) => switch (condition) {
    TempCondition.coldStress => 'ကြီးထွားမှု ရပ်တန့်ပြီး ပန်းပွင့်ချိန်တွင် အသီးမအောင်နိုင်ပါ။ အနွေးဓာတ် ထိန်းရန် ရေအဆင့် မြှင့်ပေးပါ။',
    TempCondition.low => 'အပင်ကြီးထွားမှု နှေးကွေးပြီး အမြစ်မှ အာဟာရ စုပ်ယူမှု လျော့နည်းသည်။ ဆက်လက် စောင့်ကြည့်ပါ။',
    TempCondition.optimal => 'ကြီးထွားမှု၊ သန်မာမှုနှင့် အသီးအောင်မှု အကောင်းဆုံးဖြစ်သည့် အနေအထား။ ပုံမှန်အတိုင်း ထားပါ။',
    TempCondition.warm => 'အပင် ရေသောက်သုံးမှု များပြားလာပြီး ရေငွေ့ပြန်နှုန်း မြင့်တက်လာသည်။ ရေ ပိုမိုလောင်းပါ။',
    TempCondition.heatStress => 'အပူဒဏ်ကြောင့် ပန်းပွင့်ချိန်တွင် အသီးမအောင်ဘဲ မြုံနိုင်ပြီး ရေဓာတ် ခမ်းခြောက်နိုင်သည်။ အရိပ်ထဲ ရွှေ့ပြီး ရေလောင်းပါ။',
  };

  @override
  String humidityConditionLabel(HumidityCondition condition) => switch (condition) {
    HumidityCondition.dry => 'ခြောက်သွေ့ (50% အောက်)',
    HumidityCondition.normal => 'ပုံမှန် (50–80%)',
    HumidityCondition.high => 'စိုထိုင်းလွန်း (80% အထက်)',
  };

  @override
  String humidityConditionAdvice(HumidityCondition condition) => switch (condition) {
    HumidityCondition.dry => 'စိုထိုင်းဆ နည်းနေသဖြင့် ရေဓာတ် လိုအပ်နိုင်သည်။',
    HumidityCondition.normal => 'အပင်အတွက် သင့်တော်သော လေထု စိုထိုင်းဆ။',
    HumidityCondition.high => 'မှိုရောဂါ များနိုင်သဖြင့် သတိထားပါ။ လေဝင်လေထွက် ကောင်းအောင် လုပ်ပါ။',
  };

  @override
  String soilConditionLabel(SoilCondition condition) => switch (condition) {
    SoilCondition.dry => 'ခြောက်သွေ့ (မြေစိုဓာတ် 50% အောက်)',
    SoilCondition.wet => 'စိုစွတ် (မြေစိုဓာတ် 60% အထက်)',
  };

  @override
  String soilConditionAdvice(SoilCondition condition) => switch (condition) {
    SoilCondition.dry => 'အပင် ရေငတ်နေသည် — ရေလောင်းပေးပါ။',
    SoilCondition.wet => 'အပင်အတွက် ရေလုံလောက်နေသည်။',
  };

  @override
  String get askAiCameraSection => 'ကင်မရာ ဓာတ်ပုံအတွက် AI ကို မေးမယ်';
  @override
  String get askDiseaseTitle => 'အပင်ကို စစ်ဆေးမယ်';
  @override
  String get askDiseaseSubtitle => 'ဒီအပင် ဘာရောဂါ ဖြစ်နေလဲ?';
  @override
  String get askSprayTitle => 'ဘာဆေး ဖျန်းရမလဲ?';
  @override
  String get askSpraySubtitle => 'ဘယ်လို ကုသမှု လုပ်သင့်လဲ?';
  @override
  String get aiThinking => 'AI က စဉ်းစားနေသည်…';
  @override
  String get capturingPhoto => 'ကင်မရာကနေ ဓာတ်ပုံ ရိုက်နေသည်…';
  @override
  String captureFailed(String url) => 'ကင်မရာကနေ ဓာတ်ပုံ မရိုက်နိုင်ပါ ($url)။ ESP32-CAM ဖွင့်ထားခြင်း ရှိမရှိ စစ်ဆေးပါ။';
  @override
  String get aiAnswerTitle => 'AI ရဲ့ အဖြေ';
  @override
  String get checkForUpdates => 'အချက်အလက် အသစ်ရယူရန်';
  @override
  String get cameraStreamDisconnected => 'ကင်မရာ ချိတ်ဆက်မှု ပြတ်တောက်နေသည်';
  @override
  String get previewPaused => 'ရပ်ထားသည် — ကြည့်ရန် တိုက်ရိုက် tab ကို ဖွင့်ပါ';
  @override
  String get waitingForSensorTitle => 'Sensor data ကို စောင့်နေသည်';
  @override
  String get waitingForSensorMessage => 'ESP32 က တိုင်းတာချက်များ ပို့ပြီးသည်နှင့် AI က အပင်အတွက် လိုအပ်ချက်ကို အကြံပြုပါမည်။';
  @override
  String get askingAiTitle => 'AI ကို မေးနေသည်…';
  @override
  String get askingAiMessage => 'နောက်ဆုံး sensor တန်ဖိုးများကို ဖတ်ပြီး ပြုစုနည်း အစီအစဉ် ရေးနေသည်။';
  @override
  String get aiUnavailableTitle => 'AI လမ်းညွှန် မရနိုင်ပါ';
  @override
  String get aiUnavailableMessage => 'Gemini ကို မဆက်သွယ်နိုင်ပါ။ built-in threshold လမ်းညွှန်ကို အစားထိုးပြသထားသည်။';
  @override
  String get water => 'ရေ';
  @override
  String get soilMoistOk => 'မြေဆီ စိုနေသည် — ရေမလောင်းရသေးပါ';
  @override
  String get soilDryAction => 'မြေဆီ ခြောက်နေသည် — ရေချက်ချင်း လောင်းပါ';
  @override
  String get actionBadge => 'လုပ်ဆောင်ရန်';
  @override
  String get okBadge => 'ကောင်း';
  @override
  String get lowBadge => 'နည်း';
  @override
  String get urgencyNow => 'ချက်ချင်း';
  @override
  String get urgencySoon => 'မကြာမီ';
  @override
  String get urgencyOk => 'ကောင်း';

  @override
  String get reload => 'ပြန်ဖွင့်ရန်';
  @override
  String get streamDisconnectedTitle => 'ကင်မရာ ချိတ်ဆက်မှု ပြတ်တောက်နေသည်';
  @override
  String streamDisconnectedMessage(String host) => '$host မှ ဗီဒီယို မရရှိပါ။ ESP32-CAM ဖွင့်ထားခြင်း ရှိမရှိနှင့် network တူမတူ စစ်ဆေးပါ။';
  @override
  String get soilDryShort => 'ခြောက်';
  @override
  String get soilMoistShort => 'စို';

  @override
  String get aiScanTitle => 'AI စစ်ဆေးခြင်း';
  @override
  String get addPhoto => 'ဓာတ်ပုံ ထည့်ရန်';
  @override
  String get changePhoto => 'ဓာတ်ပုံ ပြောင်းရန်';
  @override
  String get reanalyze => 'ပြန်စစ်ရန်';
  @override
  String get scanLeafTitle => 'အရွက်ကို AI နဲ့ စစ်ဆေးပါ';
  @override
  String get scanLeafSubtitle => 'ဓာတ်ပုံ + sensor data → ရောဂါရှာဖွေချက်';
  @override
  String get sensorContextTitle => 'ဓာတ်ပုံနှင့်အတူ ပို့လိုက်သော sensor အချက်အလက်';
  @override
  String sensorContextValue({required double temp, required double humidity, required bool dry}) =>
      '${temp.toStringAsFixed(1)}°C · စိုထိုင်းဆ ${humidity.toStringAsFixed(0)}% · မြေဆီ ${dry ? 'ခြောက်' : 'စို'}';
  @override
  String get aiDiagnosis => 'AI ရောဂါရှာဖွေချက်';
  @override
  String get analyzingTitle => 'အပင်ကို စစ်ဆေးနေသည်…';
  @override
  String get analyzingSubtitle => 'ပုံမှန်အားဖြင့် စက္ကန့်အနည်းငယ် ကြာပါသည်';
  @override
  String get couldNotAnalyze => 'ဤဓာတ်ပုံကို စစ်ဆေး၍ မရပါ';
  @override
  String get addPlantPhoto => 'အပင် ဓာတ်ပုံ ထည့်ရန်';
  @override
  String get takePhoto => 'ဓာတ်ပုံ ရိုက်ရန်';
  @override
  String get chooseFromGallery => 'ဓာတ်ပုံအိမ်မှ ရွေးရန်';
  @override
  String couldNotOpenImage(Object error) => 'ဓာတ်ပုံကို ဖွင့်၍ မရပါ — $error';
  @override
  String aiAnalysisFailed(Object error) => 'AI စစ်ဆေးမှု မအောင်မြင်ပါ — $error';

  @override
  String get settingsTitle => 'ဆက်တင်';
  @override
  String get languageSection => 'ဘာသာစကား';
  @override
  String get languageFooter => 'App စာသားနှင့် AI ဖြေကြားမည့် ဘာသာစကားကို ပြောင်းပေးသည်။';
  @override
  String get deviceSection => 'စက်ပစ္စည်း';
  @override
  String get hostField => 'ESP32 host / IP';
  @override
  String get portField => 'ကင်မရာ stream port';
  @override
  String get saveDeviceSettings => 'စက်ဆက်တင် သိမ်းရန်';
  @override
  String get connectionSection => 'ချိတ်ဆက်မှု';
  @override
  String get dataEndpoint => 'Data လိပ်စာ';
  @override
  String get streamEndpoint => 'Stream လိပ်စာ';
  @override
  String get lastSync => 'နောက်ဆုံး ချိတ်ဆက်မှု';
  @override
  String get testConnection => 'ချိတ်ဆက်မှု စမ်းသပ်ရန်';
  @override
  String get thresholdsSection => 'ပြုစုရေး သတ်မှတ်ချက်များ';
  @override
  String get nitrogenMin => 'နိုက်ထရိုဂျင် အနည်းဆုံး';
  @override
  String get phosphorusMin => 'ဖော့စဖရပ် အနည်းဆုံး';
  @override
  String get potassiumMin => 'ပိုတက်စီယမ် အနည်းဆုံး';
  @override
  String get lightMin => 'အလင်းရောင် အနည်းဆုံး';
  @override
  String get savedTitle => 'သိမ်းပြီးပါပြီ';
  @override
  String savedMessage(String host, int port) => 'Sensor data အတွက် $host ကို၊ ကင်မရာ stream အတွက် port $port ကို သုံးပါမည်။';
  @override
  String get connectedTitle => 'ချိတ်ဆက်မှု အောင်မြင်သည်';
  @override
  String connectedMessage(String url) => '$url မှ sensor data ရရှိပါသည်။';
  @override
  String get connectionFailedTitle => 'ချိတ်ဆက်၍ မရပါ';
  @override
  String get appVersion => 'အပင် စောင့်ကြည့်စနစ် · v1.0.0';

  @override
  String verdictHeadline(PlantVerdict verdict) => switch (verdict) {
    PlantVerdict.unknown => 'မစစ်ဆေးရသေးပါ',
    PlantVerdict.dry => 'မြေဆီ ခြောက်နေသည်',
    PlantVerdict.pestRisk => 'ပိုးမွှား/မှိုတက် အန္တရာယ် များနေသည်',
    PlantVerdict.tooHot => 'အပူချိန် မြင့်လွန်းနေသည်',
    PlantVerdict.tooCold => 'အပူချိန် နိမ့်လွန်းနေသည်',
    PlantVerdict.good => 'အပင် ကျန်းမာရေး ကောင်းသည်',
  };

  @override
  String verdictAdvice(PlantVerdict verdict) => switch (verdict) {
    PlantVerdict.unknown => 'နောက်ဆုံး sensor တန်ဖိုးများ ဖတ်ရန် refresh ကို နှိပ်ပါ။',
    PlantVerdict.dry => 'လုပ်ဆောင်ရန်: အပင်ကို အမြန်ဆုံး ရေလောင်းပါ။',
    PlantVerdict.pestRisk => 'လုပ်ဆောင်ရန်: လေဝင်လေထွက် ကောင်းအောင်လုပ်ပြီး ပိုးသတ်ဆေး ကြိုတင်ဖျန်းပါ။',
    PlantVerdict.tooHot => 'လုပ်ဆောင်ရန်: နေရောင်တိုက်ရိုက်မကျအောင် အရိပ်ထဲ ရွှေ့ပါ။',
    PlantVerdict.tooCold => 'လုပ်ဆောင်ရန်: အနွေးဓာတ် ရအောင်ထားပြီး အမြစ်ကို ကာကွယ်ရန် ရေအဆင့် မြှင့်ပေးပါ။',
    PlantVerdict.good => 'လုပ်ဆောင်ရန်: မလိုပါ။ ပုံမှန်အတိုင်း ဆက်ပြုစုပါ။',
  };

  @override
  String lastUpdatedLabel(DateTime? at) {
    if (at == null) return 'တစ်ခါမှ မဖတ်ရသေးပါ';
    final diff = DateTime.now().difference(at);
    if (diff.inSeconds < 60) return 'ယခုပင် ဖတ်ပြီး';
    if (diff.inMinutes < 60) return 'လွန်ခဲ့သော ${diff.inMinutes} မိနစ်က';
    return 'လွန်ခဲ့သော ${diff.inHours} နာရီက';
  }

  @override
  String connectionError(ConnectionError error, {required String host, int? statusCode}) => switch (error) {
    ConnectionError.unreachable => '$host ရှိ ESP32 ကို မချိတ်ဆက်နိုင်ပါ။ Wi-Fi/network ကို စစ်ဆေးပါ။',
    ConnectionError.badStatus => 'ESP32 က HTTP $statusCode ပြန်ပေးသည်။',
  };
}
