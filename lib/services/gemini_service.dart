import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../l10n/app_strings.dart';
import '../models/ai_care_advice.dart';

/// AI call တစ်ခု မအောင်မြင်တဲ့အခါ ပစ်တဲ့ error။
/// [message] က user ကို တိုက်ရိုက်ပြလို့ရအောင် ရေးထားတယ် — raw JSON မဟုတ်ပါ။
class GeminiException implements Exception {
  const GeminiException(this.message, {this.retryAfter, this.isQuota = false});

  final String message;
  final Duration? retryAfter;
  final bool isQuota;

  @override
  String toString() => message;
}

/// AI က ရွေးထားတဲ့ ဘာသာစကားနဲ့ မဟုတ်ဘဲ (ဒါမှမဟုတ် စာလုံးပျက်နဲ့) ပြန်ဖြေတဲ့အခါ
/// ပစ်တဲ့ error။ ဖတ်လို့မရတဲ့ စာသားကို screen ပေါ်တင်မပြဘဲ သတိပေးချက်ပဲ ပြဖို့ပါ။
class AiUnreadableException implements Exception {
  const AiUnreadableException();

  @override
  String toString() => 'AiUnreadableException';
}

/// ဓာတ်ပုံထဲမှာ အပင် မပါလို့ (ဒါမှမဟုတ် အပင်နဲ့ မဆိုင်တဲ့ အကြောင်းအရာ ဖြစ်လို့)
/// AI ကို ဖြေခိုင်းလို့ မရတဲ့အခါ ပစ်တဲ့ error။
class NotAPlantException implements Exception {
  const NotAPlantException();

  @override
  String toString() => 'NotAPlantException';
}

/// အပင်နဲ့ မဆိုင်တဲ့ ဓာတ်ပုံဆိုရင် AI က ဒီ token ကိုပဲ ပြန်ပေးရမယ်။
/// (ဘာသာစကား ညွှန်ကြားချက်ထဲက ချွင်းချက် — မြန်မာလို ဘာသာမပြန်ဘဲ အတိအကျ ပြန်ရမယ်။)
const String _notAPlantToken = 'NOT_A_PLANT';

/// AI ရဲ့ အဖြေက ရွေးထားတဲ့ ဘာသာစကားနဲ့ ဖတ်လို့ရရဲ့လား စစ်တယ်။
///
/// မြန်မာလို ရွေးထားရင် အဖြေထဲမှာ မြန်မာစာလုံး (U+1000–U+109F) အများစု ပါရမယ် —
/// အင်္ဂလိပ်လို ဒါမှမဟုတ် တခြားဘာသာစကားနဲ့ ပြန်လာရင် user က ဖတ်လို့မရလို့။
/// ("mg/kg" လို နည်းပညာစကားလုံး အနည်းငယ် ရောပါတာကိုတော့ လက်ခံတယ်။)
bool isReadableAnswer(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;
  // U+FFFD က encoding ပျက်နေတဲ့ လက္ခဏာ — ဖတ်လို့ မရတော့ဘူး။
  if (trimmed.contains('�')) return false;

  var burmese = 0;
  var latin = 0;
  var other = 0;
  for (final rune in trimmed.runes) {
    if (rune >= 0x1000 && rune <= 0x109F) {
      burmese++;
    } else if ((rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A)) {
      latin++;
    } else if (rune > 0x02FF) {
      // ဂဏန်း/သဒ္ဒါအမှတ်အသားတွေကို မရေတွက်ဘဲ တခြားဘာသာစကား စာလုံးတွေပဲ ရေတွက်တယ်။
      other++;
    }
  }

  final total = burmese + latin + other;
  if (total == 0) return false;
  final expected = LocaleController.instance.language == AppLanguage.myanmar ? burmese : latin;
  return expected / total >= 0.4;
}

/// OpenRouter (OpenAI-compatible chat completions) ကို သုံးတယ်။
/// အရင်က Gemini native API နဲ့ ခေါ်ထားတာကို ဒီမှာ ပြောင်းလိုက်တာ —
/// class/exception နာမည်တွေကတော့ call site တွေ မထိရအောင် အတူတူပဲ ထားထားတယ်။
class GeminiService {
  final String _apiKey;
  final String _baseUrl;
  final String _model;
  final String _visionModel;

  static const String _defaultBaseUrl = 'https://openrouter.ai/api/v1';
  static const String _defaultModel = 'openai/gpt-oss-120b';

  /// gpt-oss-120b က text-only မို့ ဓာတ်ပုံပါလာရင် ဒီ model ကို သုံးတယ်။
  /// (`openrouter/free` လို auto-routing မသုံးရ — free pool ထဲမှာ chat model မဟုတ်တဲ့
  /// content-safety classifier တွေရော မြန်မာစာ ပျက်တဲ့ model တွေရော ပါနေလို့။)
  static const String _defaultVisionModel = 'google/gemma-4-26b-a4b-it:free';

  GeminiService()
    : _apiKey = _env('OPENROUTER_API_KEY') ?? '',
      _baseUrl = (_env('OPENROUTER_BASE_URL') ?? _defaultBaseUrl).replaceAll(RegExp(r'/+$'), ''),
      _model = _env('OPENROUTER_MODEL') ?? _defaultModel,
      _visionModel = _env('OPENROUTER_VISION_MODEL') ?? _defaultVisionModel {
    if (_apiKey.isEmpty) {
      throw const GeminiException('OPENROUTER_API_KEY is missing. Add it to the .env file and restart the app.');
    }
  }

  /// .env value ကို trim လုပ်ပြီး ဗလာဆိုရင် null ပြန်ပေးတယ်။
  static String? _env(String key) {
    final value = dotenv.env[key]?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  String get _endpoint => '$_baseUrl/chat/completions';

  /// App ရဲ့ အဓိက ရည်ရွယ်ချက်က စပါးပင်/စပါးခင်း ဖြစ်တာမို့ AI ကို ယေဘုယျ ဥယျာဉ်ပညာရှင်
  /// မဟုတ်ဘဲ စပါးစိုက်ပျိုးရေး ကျွမ်းကျင်သူအဖြစ် သတ်မှတ်ပေးတယ် — ဒါမှ ရောဂါနာမည်၊
  /// ပိုးမွှားနာမည်၊ ဆေးအညွှန်း၊ ရေသွင်း/ရေထုတ် အကြံပြုချက်တွေက စပါးခင်းနဲ့ ကိုက်မယ်။
  static const String _riceRole =
      'You are an agronomy assistant for RICE (paddy) farming. '
      'The user grows rice, so treat every photo and every sensor reading as coming from a rice plant '
      'or a paddy field unless the photo clearly shows something else. '
      'Use rice-specific knowledge:\n'
      '- Growth stages: seedling, tillering, panicle initiation, booting, heading, flowering, ripening.\n'
      '- Common rice diseases: blast, bacterial leaf blight, sheath blight, brown spot, tungro, false smut.\n'
      '- Common rice pests: brown planthopper, stem borer, leaf folder, rice bug, golden apple snail.\n'
      '- Common rice nutrient problems: nitrogen deficiency, zinc deficiency, potassium deficiency, iron toxicity.\n'
      'Recommend treatments, doses and timing that suit a smallholder paddy field, and include water '
      'management (flooding depth, draining, alternate wetting and drying) whenever it is relevant. '
      'If the photo shows a plant that is clearly NOT rice, say that in your first sentence, then answer briefly. '
      'Do not discuss anything outside rice growing and the plant in the photo.\n\n';

  /// Settings မှာ ရွေးထားတဲ့ ဘာသာစကားနဲ့ပဲ AI က ပြန်ဖြေအောင် prompt ထဲ ထည့်ပေးတယ်။
  String get _languageInstruction => 'Write every piece of text you return in ${LocaleController.instance.language.promptName}. ';

  /// ပထမအကြိမ်မှာ မှားတဲ့ ဘာသာစကားနဲ့ ပြန်လာရင် ဒီညွှန်ကြားချက်နဲ့ ထပ်မေးတယ်။
  String get _strictLanguageInstruction {
    final language = LocaleController.instance.language;
    final base =
        'CRITICAL: Write your ENTIRE reply in ${language.promptName}. '
        'Do not reply in any other language and do not transliterate. ';
    return language == AppLanguage.myanmar
        ? '${base}Use Burmese (Myanmar) script only — not romanized Burmese. '
              'Technical units such as mg/kg or °C may stay as they are. '
        : base;
  }

  /// Sensor readings သီးသန့် (ဓာတ်ပုံမပါဘဲ) ကို AI ဆီပို့ပြီး
  /// Home screen ရဲ့ Care Guide အတွက် structured JSON အကြံပြုချက် ပြန်ယူတယ်။
  Future<AiCareAdvice> careGuideFromSensors({
    required double temperature,
    required double humidity,
    required int soilMoisture,
    int nitrogen = 0,
    int phosphorus = 0,
    int potassium = 0,
    double light = 0,
    bool hasNpk = false,
    bool hasLight = false,
  }) async {
    final context = StringBuffer()
      ..writeln('- Air temperature: ${temperature.toStringAsFixed(1)} °C')
      ..writeln('- Air humidity: ${humidity.toStringAsFixed(1)} %')
      ..writeln('- Soil moisture sensor: ${soilMoisture == 0 ? "DRY" : "MOIST"}');
    if (hasNpk) {
      context
        ..writeln('- Nitrogen: $nitrogen mg/kg')
        ..writeln('- Phosphorus: $phosphorus mg/kg')
        ..writeln('- Potassium: $potassium mg/kg');
    }
    if (hasLight) context.writeln('- Light: ${light.toStringAsFixed(0)} lux');

    final prompt =
        '$_riceRole'
        'These are the current live readings from an ESP32 sensor node in the paddy field:\n\n'
        '$context\n'
        'Give practical care guidance for the rice crop based ONLY on these readings. '
        'Do not invent readings that are not listed. '
        'Return 2 to 4 actions, ordered with the most urgent first. '
        '$_languageInstruction\n\n'
        'Respond with JSON only, in exactly this shape:\n'
        '{"headline": "short status, max 6 words", '
        '"summary": "1-2 sentence plain-language explanation", '
        '"actions": [{"title": "short action name, max 4 words", '
        '"detail": "one sentence of concrete instruction", '
        '"urgency": "now|soon|ok"}]}';

    final text = await _generate([
      {'text': prompt},
    ], jsonOutput: true);
    return AiCareAdvice.parse(text);
  }

  /// chat/completions ကို ခေါ်ပြီး ပထမ choice ရဲ့ content ကို ပြန်ပေးတယ်။
  /// [parts] က `{'text': ...}` ဒါမှမဟုတ် `{'inline_data': {'mime_type':..., 'data': base64}}`
  /// အဖြစ် လက်ခံပြီး OpenAI content-part အဖြစ် ဒီထဲမှာပဲ ပြောင်းပေးတယ်။
  Future<String> _generate(List<Map<String, dynamic>> parts, {bool jsonOutput = false}) async {
    final hasImage = parts.any((p) => p.containsKey('inline_data'));
    final model = hasImage ? _visionModel : _model;

    final content = parts.map((part) {
      final inline = part['inline_data'] as Map<String, dynamic>?;
      if (inline != null) {
        return {
          'type': 'image_url',
          'image_url': {'url': 'data:${inline['mime_type']};base64,${inline['data']}'},
        };
      }
      return {'type': 'text', 'text': (part['text'] ?? '').toString()};
    }).toList();

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
              // OpenRouter က ဒီ header နှစ်ခုကို leaderboard/attribution အတွက် သုံးတယ် (optional)။
              'HTTP-Referer': 'https://github.com/plant-monitoring',
              'X-Title': 'Plant Monitoring',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {'role': 'user', 'content': content},
              ],
              if (jsonOutput) 'response_format': {'type': 'json_object'},
            }),
          )
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      throw GeminiException('Could not reach the AI service. Check your internet connection.\n($e)');
    }

    if (response.statusCode != 200) throw _errorFor(response, model);

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    // OpenRouter က HTTP 200 နဲ့တောင် body ထဲမှာ error ထည့်ပြန်နိုင်တယ်။
    final inlineError = data['error'];
    if (inlineError != null) {
      throw GeminiException(inlineError['message']?.toString() ?? 'The AI service returned an error.');
    }

    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw const GeminiException('The AI returned an empty response. Try again.');
    }
    final text = (choices[0]['message']?['content'] ?? '').toString();
    // Model ရွေးမှားပြီး chat model မဟုတ်ဘဲ content-safety classifier ဆီ ရောက်သွားရင်
    // "User Safety: safe" လိုမျိုးပဲ ပြန်တယ် — အဲဒါကို အဖြေအဖြစ် ဘယ်တော့မှ မပြရဘူး။
    if (RegExp(r'^\s*(User Safety|Safety Categories)\s*:', caseSensitive: false).hasMatch(text)) {
      throw GeminiException('The model "$model" is not usable for this app. Set OPENROUTER_VISION_MODEL in .env to a vision chat model.');
    }
    if (text.trim().isEmpty) {
      final reason = choices[0]['finish_reason']?.toString();
      throw GeminiException(
        reason == 'content_filter' ? 'The AI blocked this request (content filter).' : 'The AI returned an empty response. Try again.',
      );
    }
    return text;
  }

  /// HTTP error body ထဲက အဓိကအချက်ကို ဆွဲထုတ်ပြီး ဖတ်လို့ရတဲ့ message အဖြစ် ပြောင်းတယ်။
  /// (အရင်က raw JSON တစ်ခုလုံး screen ပေါ်တင်နေလို့ ဒီနေရာမှာ စစ်ထားတာပါ။)
  GeminiException _errorFor(http.Response response, String model) {
    String? apiMessage;
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final error = body['error'];
      apiMessage = (error is Map ? error['message'] : error)?.toString() ?? body['message']?.toString();
    } catch (_) {
      // JSON မဟုတ်ရင် status code သက်သက်နဲ့ပဲ ဆက်သွားမယ်။
    }

    // Rate limit ဆိုရင် OpenRouter က Retry-After header ပြန်ပေးတယ်။
    final retrySeconds = int.tryParse(response.headers['retry-after'] ?? '');
    final retryAfter = retrySeconds == null ? null : Duration(seconds: retrySeconds);

    return switch (response.statusCode) {
      401 => GeminiException('OpenRouter rejected the API key (HTTP 401). Check OPENROUTER_API_KEY in .env.\n\n$apiMessage'),
      402 => const GeminiException('This OpenRouter account is out of credits for that model. Add credits, or set OPENROUTER_MODEL in .env to a free model.'),
      403 => GeminiException('OpenRouter refused this request (HTTP 403).\n\n$apiMessage'),
      404 => GeminiException('Model "$model" is not available on OpenRouter for this key. Set OPENROUTER_MODEL in .env to a supported model.'),
      429 => GeminiException(
        retryAfter != null
            ? 'Rate limit reached for "$model". Try again in ${retryAfter.inSeconds}s, or set OPENROUTER_MODEL in .env to another model.'
            : 'Rate limit reached for "$model". Wait a moment, or set OPENROUTER_MODEL in .env to another model.',
        retryAfter: retryAfter,
        isQuota: true,
      ),
      >= 500 => const GeminiException('The AI service is temporarily unavailable. Please try again shortly.'),
      _ => GeminiException(apiMessage != null ? '$apiMessage\n\n(HTTP ${response.statusCode})' : 'AI service error (HTTP ${response.statusCode}).'),
    };
  }

  /// Analyzes a plant image with live sensor context and returns detailed information.
  Future<String> analyzePlantImage(
    File imageFile, {
    double temperature = 0,
    double humidity = 0,
    int soilMoisture = 0,
    int nitrogen = 0,
    int phosphorus = 0,
    int potassium = 0,
    double light = 0,
  }) async {
    // Read and encode image as base64
    final imageBytes = await imageFile.readAsBytes();
    if (imageBytes.isEmpty) {
      throw const GeminiException('That photo is empty or could not be read. Try taking or picking it again.');
    }
    if (imageBytes.length > 18 * 1024 * 1024) {
      throw const GeminiException('That photo is too large to send. Try a smaller image.');
    }
    return analyzeImageBytes(
      imageBytes,
      mimeType: _mimeFor(imageFile.path),
      temperature: temperature,
      humidity: humidity,
      soilMoisture: soilMoisture,
      nitrogen: nitrogen,
      phosphorus: phosphorus,
      potassium: potassium,
      light: light,
    );
  }

  /// ဓာတ်ပုံ bytes (ESP32-CAM ကနေ ဖမ်းလာတာ ဖြစ်နိုင်တယ်) ကို sensor context နဲ့အတူ ပို့တယ်။
  /// [question] ပေးရင် အဲဒီမေးခွန်းကိုပဲ ဖြေခိုင်းတယ် — မပေးရင် အပြည့်အစုံ ခွဲခြမ်းစိတ်ဖြာချက် ရတယ်။
  Future<String> analyzeImageBytes(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
    String? question,
    double temperature = 0,
    double humidity = 0,
    int soilMoisture = 0,
    int nitrogen = 0,
    int phosphorus = 0,
    int potassium = 0,
    double light = 0,
  }) async {
    if (imageBytes.isEmpty) {
      throw const GeminiException('That photo is empty or could not be read. Try taking or picking it again.');
    }
    if (imageBytes.length > 18 * 1024 * 1024) {
      throw const GeminiException('That photo is too large to send. Try a smaller image.');
    }
    final base64Image = base64Encode(imageBytes);

    // Build a rich context string from live sensor data.
    // NPK/light sensor မတပ်ထားရင် 0 လို့ ပို့မိတာမို့ AI က "nitrogen လုံးဝမရှိ" လို့
    // မှားကောက်တတ်တယ် — တန်ဖိုးရှိတဲ့ sensor တွေကိုပဲ ထည့်ပေးတယ်။
    final sensorContext = StringBuffer('Current sensor readings from the paddy field:\n');
    sensorContext.writeln('- Temperature: ${temperature.toStringAsFixed(1)}°C');
    sensorContext.writeln('- Humidity: ${humidity.toStringAsFixed(1)}%');
    sensorContext.writeln('- Soil: ${soilMoisture == 0 ? "Dry" : "Moist"}');
    if (nitrogen > 0) sensorContext.writeln('- Nitrogen: $nitrogen mg/kg');
    if (phosphorus > 0) sensorContext.writeln('- Phosphorus: $phosphorus mg/kg');
    if (potassium > 0) sensorContext.writeln('- Potassium: $potassium mg/kg');
    if (light > 0) sensorContext.writeln('- Light: ${light.toStringAsFixed(0)} lux');
    sensorContext.writeln('Readings that are not listed are simply not measured — do not assume they are zero.');

    // Error တွေကို string အဖြစ် return မလုပ်တော့ဘဲ GeminiException ပစ်တယ် —
    // ဒါမှ UI က အဖြေနဲ့ error ကို ခွဲပြနိုင်မယ်။
    final task = question == null
        ? 'Analyze this rice (paddy) photo in detail. Provide the following:\n'
              '1. **Crop & Stage**: Confirm whether it is rice and estimate the growth stage.\n'
              '2. **Health Condition**: Describe the overall health of the crop.\n'
              '3. **Issues Detected**: Rice diseases, pests, nutrient deficiencies, or other abnormalities.\n'
              '4. **Field Actions**: Treatment, fertiliser and water management for this paddy field.\n\n'
        : 'Look at this photo from the paddy field and answer the question below.\n'
              'Question: "$question"\n'
              'Keep the answer under 120 words, concrete and practical for a rice farmer. '
              'If the photo is too unclear to judge, say so plainly.\n\n';

    // App က အပင်အတွက်သာ ဖြစ်တာမို့ အပင်မပါတဲ့ ဓာတ်ပုံ (လူ/အခန်း/စာရွက် စသဖြင့်) ဆိုရင်
    // မှန်းဆပြီး မဖြေဘဲ token ပဲ ပြန်ခိုင်းတယ် — UI ကပဲ သတိပေးချက် ပြလိမ့်မယ်။
    const scopeGuard =
        'SCOPE: You may only discuss rice and other crops, the soil and water they grow in, and their care. '
        'First decide whether the photo actually shows a plant or part of a plant '
        '(leaf, stem, tiller, panicle, grain, root, seedling) or a field, paddy soil or paddy water. '
        'If it does not — for example a person, an animal, a room, a document, a screen, or an empty view — '
        'reply with exactly $_notAPlantToken and nothing else. '
        'That token must stay in English even when you are asked to answer in another language. '
        'Never answer questions that are unrelated to the crop.\n\n';

    List<Map<String, dynamic>> parts({required bool strict}) => [
      {
        'text':
            '$_riceRole'
            '$scopeGuard'
            '$task'
            '$sensorContext\n'
            'Consider the above sensor data in your analysis and recommendations. '
            '${strict ? _strictLanguageInstruction : _languageInstruction}',
      },
      {
        // အရင်က image/jpeg လို့ အမြဲ ပို့နေတာမို့ PNG/WebP/HEIC ဖိုင်ဆိုရင် API က 400 ပြန်တယ်။
        'inline_data': {'mime_type': mimeType, 'data': base64Image},
      },
    ];

    // မှားတဲ့ ဘာသာစကားနဲ့ ပြန်လာရင် ပိုတင်းကျပ်တဲ့ ညွှန်ကြားချက်နဲ့ တစ်ခါ ပြန်စမ်းတယ်။
    // နှစ်ခါလုံး မရရင်တော့ ဖတ်လို့မရတဲ့ စာသားကို မပြဘဲ သတိပေးချက်ပဲ ပြဖို့ error ပစ်တယ်။
    final answer = await _generate(parts(strict: false));
    _rejectIfNotAPlant(answer);
    if (isReadableAnswer(answer)) return answer;

    final retry = await _generate(parts(strict: true));
    _rejectIfNotAPlant(retry);
    if (isReadableAnswer(retry)) return retry;
    throw const AiUnreadableException();
  }

  /// အပင်မဟုတ်ကြောင်း token ပါလာရင် အဖြေအဖြစ် မယူဘဲ [NotAPlantException] ပစ်တယ်။
  /// Model က တစ်ခါတလေ `**NOT_A_PLANT**` လို format ချည်တတ်လို့ ရှေ့ပိုင်းလေးကိုပဲ ကြည့်တယ်။
  void _rejectIfNotAPlant(String answer) {
    final head = answer.trim();
    final probe = head.length > 120 ? head.substring(0, 120) : head;
    if (probe.toUpperCase().replaceAll(RegExp(r'[^A-Z_]'), '').contains(_notAPlantToken)) {
      throw const NotAPlantException();
    }
  }

  String _mimeFor(String path) {
    final ext = path.toLowerCase().split('.').last;
    return switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
  }
}
