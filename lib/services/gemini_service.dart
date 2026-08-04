import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../l10n/app_strings.dart';
import '../models/ai_care_advice.dart';

/// Gemini call တစ်ခု မအောင်မြင်တဲ့အခါ ပစ်တဲ့ error။
/// [message] က user ကို တိုက်ရိုက်ပြလို့ရအောင် ရေးထားတယ် — raw JSON မဟုတ်ပါ။
class GeminiException implements Exception {
  const GeminiException(this.message, {this.retryAfter, this.isQuota = false});

  final String message;
  final Duration? retryAfter;
  final bool isQuota;

  @override
  String toString() => message;
}

class GeminiService {
  final String _apiKey;
  final String _model;

  /// Free tier မှာ model တစ်ခုချင်း quota မတူတာမို့ .env က `GEMINI_MODEL` နဲ့
  /// ပြောင်းလို့ရအောင် ထားတယ် (ဥပမာ gemini-2.5-flash-lite)။
  static const String _defaultModel = 'gemini-2.5-flash';

  GeminiService() : _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '', _model = dotenv.env['GEMINI_MODEL']?.trim().isNotEmpty == true ? dotenv.env['GEMINI_MODEL']!.trim() : _defaultModel {
    if (_apiKey.isEmpty) {
      throw const GeminiException('GEMINI_API_KEY is missing. Add it to the .env file and restart the app.');
    }
  }

  String get _endpoint => 'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  /// Settings မှာ ရွေးထားတဲ့ ဘာသာစကားနဲ့ပဲ AI က ပြန်ဖြေအောင် prompt ထဲ ထည့်ပေးတယ်။
  String get _languageInstruction => 'Write every piece of text you return in ${LocaleController.instance.language.promptName}. ';

  /// Sensor readings သီးသန့် (ဓာတ်ပုံမပါဘဲ) ကို Gemini ဆီပို့ပြီး
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

  /// Gemini generateContent ကို ခေါ်ပြီး ပထမ text part ကို ပြန်ပေးတယ်။
  Future<String> _generate(List<Map<String, dynamic>> parts, {bool jsonOutput = false}) async {
    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_endpoint?key=$_apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {'parts': parts},
              ],
              if (jsonOutput) 'generationConfig': {'response_mime_type': 'application/json'},
            }),
          )
          .timeout(const Duration(seconds: 45));
    } catch (e) {
      throw GeminiException('Could not reach Gemini. Check your internet connection.\n($e)');
    }

    if (response.statusCode != 200) throw _errorFor(response);

    final data = jsonDecode(response.body);
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      // safety filter နဲ့ ပိတ်ခံရရင် candidates မပါဘဲ promptFeedback ပဲ ပါလာတယ်။
      final blocked = data['promptFeedback']?['blockReason'];
      throw GeminiException(blocked != null ? 'Gemini blocked this request ($blocked).' : 'Gemini returned an empty response. Try again.');
    }
    final responseParts = (candidates[0]['content']?['parts'] as List?) ?? const [];
    if (responseParts.isEmpty) {
      throw const GeminiException('Gemini returned an empty response. Try again.');
    }
    return (responseParts[0]['text'] ?? '').toString();
  }

  /// 400/403 က API key ကြောင့်လား၊ တခြားအကြောင်းကြောင့်လား ခွဲခြားတယ်။
  bool _looksLikeKeyProblem(String? message) {
    if (message == null) return true; // message မပါရင် key ကို အရင်သံသယရှိမယ်
    final m = message.toLowerCase();
    return m.contains('api key') || m.contains('api_key') || m.contains('permission') || m.contains('unauthenticated');
  }

  /// HTTP error body ထဲက အဓိကအချက်ကို ဆွဲထုတ်ပြီး ဖတ်လို့ရတဲ့ message အဖြစ် ပြောင်းတယ်။
  /// (အရင်က raw JSON တစ်ခုလုံး screen ပေါ်တင်နေလို့ ဒီနေရာမှာ စစ်ထားတာပါ။)
  GeminiException _errorFor(http.Response response) {
    String? apiMessage;
    Duration? retryAfter;
    try {
      final error = jsonDecode(response.body)['error'];
      apiMessage = error?['message']?.toString();
      for (final d in (error?['details'] as List? ?? const [])) {
        final delay = d is Map ? d['retryDelay']?.toString() : null;
        final seconds = delay == null ? null : double.tryParse(delay.replaceAll('s', ''));
        if (seconds != null) retryAfter = Duration(seconds: seconds.ceil());
      }
    } catch (_) {
      // JSON မဟုတ်ရင် status code သက်သက်နဲ့ပဲ ဆက်သွားမယ်။
    }

    return switch (response.statusCode) {
      429 => GeminiException(
        retryAfter != null
            ? 'Gemini quota reached for "$_model". Try again in ${retryAfter.inSeconds}s, or set GEMINI_MODEL in .env to a model your key has free-tier quota for.'
            : 'Gemini quota reached for "$_model". Wait a moment, or set GEMINI_MODEL in .env to a model your key has free-tier quota for.',
        retryAfter: retryAfter,
        isQuota: true,
      ),
      // 400 က key ပြဿနာချည်း မဟုတ်ဘူး — ပုံ ဖတ်မရတာ၊ request ကြီးလွန်းတာလည်း ဖြစ်နိုင်တာမို့
      // API ရဲ့ message ကိုယ်တိုင်ကို ပြပေးတယ်။
      400 || 403 when _looksLikeKeyProblem(apiMessage) => GeminiException(
        'Gemini rejected the API key (HTTP ${response.statusCode}). Check GEMINI_API_KEY in .env.\n\n$apiMessage',
      ),
      404 => GeminiException('Model "$_model" is not available for this API key. Set GEMINI_MODEL in .env to a supported model.'),
      >= 500 => const GeminiException('Gemini is temporarily unavailable. Please try again shortly.'),
      _ => GeminiException(apiMessage != null ? '$apiMessage\n\n(HTTP ${response.statusCode})' : 'Gemini error (HTTP ${response.statusCode}).'),
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
