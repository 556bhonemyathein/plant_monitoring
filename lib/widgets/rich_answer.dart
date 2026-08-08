import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';

/// Gemini က markdown လေးလေး ပြန်ပေးတာမို့ **bold** နဲ့ bullet လောက်ကို
/// package မထည့်ဘဲ ကိုယ်တိုင် render လုပ်ပေးတယ်။
/// (AI Scan tab နဲ့ Home ရဲ့ "AI ကို မေးမယ်" အဖြေ နှစ်ခုလုံးက ဒါကို သုံးတယ်။)
class RichAnswer extends StatelessWidget {
  const RichAnswer({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final raw in lines)
          if (raw.trim().isEmpty)
            const SizedBox(height: 8)
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _line(raw.trimRight()),
            ),
      ],
    );
  }

  Widget _line(String line) {
    // `### ခေါင်းစဉ်` လို markdown heading တွေကို `#` အတိုင်း မပြဘဲ စာလုံးထူအဖြစ်ပဲ ပြတယ်။
    final heading = RegExp(r'^\s*#{1,6}\s+').hasMatch(line);
    if (heading) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.w700, color: AppColors.label),
            children: _spans(line.replaceFirst(RegExp(r'^\s*#{1,6}\s+'), '')),
          ),
        ),
      );
    }

    final bullet = RegExp(r'^\s*[*-]\s+').hasMatch(line);
    final content = bullet ? line.replaceFirst(RegExp(r'^\s*[*-]\s+'), '') : line;

    final body = RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.label),
        children: _spans(content),
      ),
    );

    if (!bullet) return body;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 8),
            child: SizedBox(
              width: 5,
              height: 5,
              child: DecoratedBox(decoration: BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  List<TextSpan> _spans(String content) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    var index = 0;
    for (final m in pattern.allMatches(content)) {
      if (m.start > index) spans.add(TextSpan(text: content.substring(index, m.start)));
      spans.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w700)));
      index = m.end;
    }
    if (index < content.length) spans.add(TextSpan(text: content.substring(index)));
    return spans;
  }
}
