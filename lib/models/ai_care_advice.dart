import 'dart:convert';

/// Action တစ်ခုချင်းစီရဲ့ အရေးပေါ်အဆင့်။
enum CareUrgency { ok, soon, now }

CareUrgency _urgencyFrom(Object? raw) => switch (raw.toString().toLowerCase()) {
  'now' || 'urgent' || 'critical' => CareUrgency.now,
  'soon' || 'warning' => CareUrgency.soon,
  _ => CareUrgency.ok,
};

class CareAction {
  const CareAction({required this.title, required this.detail, required this.urgency});

  final String title;
  final String detail;
  final CareUrgency urgency;

  factory CareAction.fromJson(Map<String, dynamic> json) {
    return CareAction(
      title: (json['title'] ?? 'Care step').toString(),
      detail: (json['detail'] ?? '').toString(),
      urgency: _urgencyFrom(json['urgency']),
    );
  }
}

/// Gemini က sensor readings အပေါ်မူတည်ပြီး ပြန်ပေးတဲ့ care guide။
class AiCareAdvice {
  const AiCareAdvice({required this.headline, required this.summary, required this.actions, required this.generatedAt});

  final String headline;
  final String summary;
  final List<CareAction> actions;
  final DateTime generatedAt;

  /// Model က ```json fenced block နဲ့ ပြန်တတ်တာမို့ fence ကို အရင်ဖယ်ပြီး decode လုပ်တယ်။
  static AiCareAdvice parse(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '').replaceFirst(RegExp(r'```\s*$'), '').trim();
    }

    final decoded = json.decode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('AI response was not a JSON object.');
    }

    final actions = (decoded['actions'] as List?) ?? const [];
    return AiCareAdvice(
      headline: (decoded['headline'] ?? 'Care guide').toString(),
      summary: (decoded['summary'] ?? '').toString(),
      actions: [
        for (final a in actions)
          if (a is Map<String, dynamic>) CareAction.fromJson(a),
      ],
      generatedAt: DateTime.now(),
    );
  }
}
