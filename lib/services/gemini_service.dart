import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  final String _apiKey;

  // Tried in order. If the first is overloaded, we fall back to the next.
  static const List<String> _models = ['gemini-2.5-flash', 'gemini-2.0-flash'];

  // How many times to retry a single model when it returns an overloaded /
  // rate-limited status before giving up on it.
  static const int _maxRetriesPerModel = 3;

  GeminiService() : _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '' {
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env file');
    }
  }

  /// Analyzes a plant image and returns detailed care information.
  ///
  /// Optionally accepts live sensor readings so the AI can tailor its
  /// recommendations to the plant's current environment.
  ///
  /// Transient overload (503) / rate-limit (429) responses are retried with
  /// exponential backoff, then fall back to the next model in [_models].
  Future<String> analyzePlantImage(
    File imageFile, {
    double? temperature,
    double? humidity,
    int? soilMoisture,
    int? nitrogen,
    int? phosphorus,
    int? potassium,
    double? light,
  }) async {
    try {
      // Read and encode image as base64
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': _buildPrompt(temperature, humidity, soilMoisture, nitrogen, phosphorus, potassium, light)},
              {
                'inline_data': {'mime_type': 'image/jpeg', 'data': base64Image},
              },
            ],
          },
        ],
        // Lower temperature -> more consistent, factual analysis.
        'generationConfig': {'temperature': 0.4, 'maxOutputTokens': 2048},
      });

      String? lastError;

      for (final model in _models) {
        final uri = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_apiKey');

        for (int attempt = 0; attempt < _maxRetriesPerModel; attempt++) {
          http.Response response;
          try {
            response = await http
                .post(uri,
                    headers: {'Content-Type': 'application/json'}, body: body)
                .timeout(const Duration(seconds: 30));
          } catch (e) {
            // Network hiccup / timeout — treat as retryable.
            lastError = 'Network error: $e';
            await _backoff(attempt);
            continue;
          }

          if (response.statusCode == 200) {
            return _extractText(response.body);
          }

          // 503 = overloaded, 429 = rate limited: retry / fall back.
          if (response.statusCode == 503 || response.statusCode == 429) {
            lastError =
                'The AI model is busy (${response.statusCode}). Retrying...';
            await _backoff(attempt);
            continue;
          }

          // Any other status is a real error — don't waste retries on it.
          return 'API Error (${response.statusCode}): ${response.body}';
        }
        // This model stayed overloaded; loop tries the next model.
      }

      return 'The AI service is currently overloaded. Please tap "Take a photo" '
          'to try again in a moment.\n\n(${lastError ?? 'unknown error'})';
    } catch (e) {
      return 'An error occurred while analyzing the plant: $e';
    }
  }

  /// Waits with exponential backoff (~1s, 2s, 4s) plus a little headroom.
  Future<void> _backoff(int attempt) async {
    final seconds = 1 << attempt; // 1, 2, 4, ...
    await Future.delayed(Duration(milliseconds: seconds * 1000 + 300));
  }

  /// Pulls the generated text out of a successful Gemini response body.
  String _extractText(String responseBody) {
    final data = jsonDecode(responseBody);
    final candidates = data['candidates'] as List?;
    if (candidates != null && candidates.isNotEmpty) {
      final parts = candidates[0]['content']?['parts'] as List?;
      if (parts != null && parts.isNotEmpty) {
        return parts[0]['text'] ?? 'No response text was returned.';
      }
    }
    return 'The response format from the AI was invalid.';
  }

  /// Builds a structured, English-language prompt. Injects live sensor
  /// readings when they are available for more accurate advice.
  String _buildPrompt(double? temperature, double? humidity, int? soilMoisture,
      int? nitrogen, int? phosphorus, int? potassium, double? light) {
    final buffer = StringBuffer();

    buffer.writeln(
      'You are an experienced agriculture/horticulture expert. '
      'Carefully analyze the provided plant photo.',
    );

    // Inject live sensor context when available.
    final hasSensorData = temperature != null ||
        humidity != null ||
        soilMoisture != null ||
        nitrogen != null ||
        phosphorus != null ||
        potassium != null ||
        light != null;
    if (hasSensorData) {
      buffer.writeln('\nCurrent sensor readings:');
      if (temperature != null) {
        buffer.writeln('- Temperature: ${temperature.toStringAsFixed(1)} °C');
      }
      if (humidity != null) {
        buffer.writeln('- Humidity: ${humidity.toStringAsFixed(1)} %');
      }
      if (soilMoisture != null) {
        final soilDesc = soilMoisture == 1 ? 'dry' : 'moist';
        buffer.writeln('- Soil moisture: $soilDesc');
      }
      if (nitrogen != null) {
        buffer.writeln('- Nitrogen (N): $nitrogen mg/kg');
      }
      if (phosphorus != null) {
        buffer.writeln('- Phosphorus (P): $phosphorus mg/kg');
      }
      if (potassium != null) {
        buffer.writeln('- Potassium (K): $potassium mg/kg');
      }
      if (light != null) {
        buffer.writeln('- Light: ${light.toStringAsFixed(0)} lux');
      }
      buffer.writeln('Take these sensor readings into account when giving advice.');
    }

    buffer.writeln('''

Answer as a practical care report for a grower, using EXACTLY these 7 numbered
sections and no others. For each section start with a clear verdict word
(GOOD / OK / NEEDED / WARNING) then 1-2 short, practical sentences of advice.

1. Overall Health: (a quick summary of the plant's current condition)
2. Water: (Is the soil moisture fine, or does it need watering now? How often?)
3. Nutrients (NPK): (Are N, P, K sufficient, or is fertilizer needed? Say which nutrient is low and what to add.)
4. Sunlight: (Is the light level enough, too low, or too high? Where to place it?)
5. Temperature & Humidity: (Are the current temperature and humidity suitable for this plant?)
6. Pests & Disease: (Any signs of pests, fungus, or disease in the photo? What to do?)
7. Next Action: (The single most important thing the grower should do right now.)

Reply in English, in exactly these 7 numbered sections in this order. Keep it
simple and practical. Do not add any extra sections or commentary.''');

    return buffer.toString();
  }
}
