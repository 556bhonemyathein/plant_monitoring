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

  /// Analyzes a plant image and returns detailed information.
  Future<String> analyzePlantImage(File imageFile) async {
    try {
      // Read and encode image as base64
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final uri = Uri.parse('$_baseUrl?key=$_apiKey');

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
                      '4. **Care Recommendations**: Watering, sunlight, soil, and other care tips.\n'
                      'Please respond in a clear, structured format.',
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
