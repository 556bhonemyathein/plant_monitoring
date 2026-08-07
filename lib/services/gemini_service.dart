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
  static const String _defaultVisionModel = 'google/gemma-4-31b-it:free';

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

  /// Settings မှာ ရွေးထားတဲ့ ဘာသာစကားနဲ့ပဲ AI က ပြန်ဖြေအောင် prompt ထဲ ထည့်ပေးတယ်။
  String get _languageInstruction => 'Write every piece of text you return in ${LocaleController.instance.language.promptName}. ';

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
        'You are an agronomist assistant inside a plant monitoring app. '
        'These are the current live readings from an ESP32 sensor node:\n\n'
        '$context\n'
        'Give practical care guidance for the plant based ONLY on these readings. '
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

    // Build a rich context string from live sensor data
    final sensorContext = StringBuffer('Current sensor readings:\n');
    sensorContext.writeln('- Temperature: ${temperature.toStringAsFixed(1)}°C');
    sensorContext.writeln('- Humidity: ${humidity.toStringAsFixed(1)}%');
    sensorContext.writeln('- Soil: ${soilMoisture == 0 ? "Dry" : "Moist"}');
    sensorContext.writeln('- Nitrogen: $nitrogen mg/kg');
    sensorContext.writeln('- Phosphorus: $phosphorus mg/kg');
    sensorContext.writeln('- Potassium: $potassium mg/kg');
    sensorContext.writeln('- Light: ${light.toStringAsFixed(0)} lux');

    // Error တွေကို string အဖြစ် return မလုပ်တော့ဘဲ GeminiException ပစ်တယ် —
    // ဒါမှ UI က အဖြေနဲ့ error ကို ခွဲပြနိုင်မယ်။
    final task = question == null
        ? 'Analyze this plant image in detail. Provide the following:\n'
              '1. **Plant Species**: Identify the plant if possible.\n'
              '2. **Health Condition**: Describe the overall health of the plant.\n'
              '3. **Issues Detected**: Any diseases, pests, nutrient deficiencies, or abnormalities.\n'
              '4. **Care Recommendations**: Watering, sunlight, soil, and other care tips.\n\n'
        : 'Look at this photo of the plant and answer the question below.\n'
              'Question: "$question"\n'
              'Keep the answer under 120 words, concrete and practical. '
              'If the photo is too unclear to judge, say so plainly.\n\n';

    return _generate([
      {
        'text':
            '$task'
            '$sensorContext\n'
            'Consider the above sensor data in your analysis and recommendations. '
            '$_languageInstruction',
      },
      {
        // အရင်က image/jpeg လို့ အမြဲ ပို့နေတာမို့ PNG/WebP/HEIC ဖိုင်ဆိုရင် API က 400 ပြန်တယ်။
        'inline_data': {'mime_type': mimeType, 'data': base64Image},
      },
    ]);
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
