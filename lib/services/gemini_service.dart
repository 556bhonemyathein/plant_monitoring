import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  final String _apiKey;
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  GeminiService() : _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '' {
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env file');
    }
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
    try {
      // Read and encode image as base64
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final uri = Uri.parse('$_baseUrl?key=$_apiKey');

      // Build a rich context string from live sensor data
      final sensorContext = StringBuffer('Current sensor readings:\n');
      sensorContext.writeln('- Temperature: ${temperature.toStringAsFixed(1)}°C');
      sensorContext.writeln('- Humidity: ${humidity.toStringAsFixed(1)}%');
      sensorContext.writeln('- Soil: ${soilMoisture == 0 ? "Moist" : "Dry"}');
      sensorContext.writeln('- Nitrogen: $nitrogen mg/kg');
      sensorContext.writeln('- Phosphorus: $phosphorus mg/kg');
      sensorContext.writeln('- Potassium: $potassium mg/kg');
      sensorContext.writeln('- Light: ${light.toStringAsFixed(0)} lux');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text':
                      'Analyze this plant image in detail. Provide the following:\n'
                      '1. **Plant Species**: Identify the plant if possible.\n'
                      '2. **Health Condition**: Describe the overall health of the plant.\n'
                      '3. **Issues Detected**: Any diseases, pests, nutrient deficiencies, or abnormalities.\n'
                      '4. **Care Recommendations**: Watering, sunlight, soil, and other care tips.\n\n'
                      '$sensorContext\n'
                      'Consider the above sensor data in your analysis and recommendations.',
                },
                {
                  'inline_data': {'mime_type': 'image/jpeg', 'data': base64Image},
                },
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final parts = candidates[0]['content']['parts'] as List;
          if (parts.isNotEmpty) {
            return parts[0]['text'] ?? 'No text in response.';
          }
        }
        return 'Unexpected response format.';
      } else {
        return 'API Error (${response.statusCode}): ${response.body}';
      }
    } catch (e) {
      return 'Error analyzing plant: $e';
    }
  }
}
