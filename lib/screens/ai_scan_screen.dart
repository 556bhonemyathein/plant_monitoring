import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';

import '../services/gemini_service.dart';
import '../services/plant_service.dart';
import '../theme/app_colors.dart';
import 'root_shell.dart';

/// AI Scan tab — ဓာတ်ပုံ တစ်ပုံရိုက်/ရွေးပြီး live sensor data နဲ့အတူ
/// Gemini ကို ပို့ကာ အပင်ရဲ့ ရောဂါ/ကျန်းမာရေး အကြံပြုချက် ပြန်ယူတယ်။
class AiScanScreen extends StatefulWidget {
  const AiScanScreen({super.key});

  @override
  State<AiScanScreen> createState() => _AiScanScreenState();
}

class _AiScanScreenState extends State<AiScanScreen> {
  final PlantService _service = PlantService.instance;
  final ImagePicker _picker = ImagePicker();

  File? _image;
  String? _result;
  String? _error;
  bool _analyzing = false;

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1600);
      if (picked == null || !mounted) return;
      setState(() {
        _image = File(picked.path);
        _result = null;
        _error = null;
      });
      await _analyze();
    } catch (e) {
      if (mounted) _showError('Could not open the image: $e');
    }
  }

  Future<void> _analyze() async {
    final image = _image;
    if (image == null) return;

    setState(() {
      _analyzing = true;
      _error = null;
    });
    try {
      // API key မရှိရင် GeminiService constructor က exception ပစ်တာမို့ ဒီထဲမှာပဲ ဖမ်းထားတယ်။
      final answer = await GeminiService().analyzePlantImage(
        image,
        temperature: _service.temp,
        humidity: _service.humid,
        soilMoisture: _service.soilMoisture,
        nitrogen: _service.nitrogen,
        phosphorus: _service.phosphorus,
        potassium: _service.potassium,
        light: _service.light,
      );
      if (mounted) setState(() => _result = answer);
    } catch (e) {
      // GeminiException က user ကို ပြလို့ရတဲ့ စာသား ဖြစ်ပြီးသားမို့ တိုက်ရိုက်ပြတယ်။
      if (mounted) setState(() => _error = e is GeminiException ? e.message : 'AI analysis failed: $e');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  void _showSourceSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Add a plant photo'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _pick(ImageSource.camera);
            },
            child: const Text('Take a photo'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _pick(ImageSource.gallery);
            },
            child: const Text('Choose from gallery'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(isDestructiveAction: true, onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('AI Scan', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.label)),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, kNavBarClearance),
          children: [
            _preview(),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _button(
                    label: _image == null ? 'Add photo' : 'Change photo',
                    icon: CupertinoIcons.camera,
                    color: AppColors.purple,
                    onPressed: _analyzing ? null : _showSourceSheet,
                  ),
                ),
                if (_image != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: _button(
                      label: 'Re-analyze',
                      icon: CupertinoIcons.arrow_clockwise,
                      color: AppColors.blue,
                      onPressed: _analyzing ? null : _analyze,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            _sensorContextCard(),
            const SizedBox(height: 20),
            if (_analyzing)
              const _AnalyzingCard()
            else if (_error != null)
              _errorCard(_error!)
            else if (_result != null)
              _resultCard(_result!),
          ],
        ),
      ),
    );
  }

  Widget _preview() {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: _image == null
            ? GestureDetector(
                onTap: _showSourceSheet,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border.all(color: AppColors.separator),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.sparkles, size: 40, color: AppColors.purple),
                      SizedBox(height: 10),
                      Text(
                        'Scan a leaf with AI',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.label),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Photo + live sensor data → diagnosis',
                        style: TextStyle(fontSize: 13, color: AppColors.secondaryLabel),
                      ),
                    ],
                  ),
                ),
              )
            : Image.file(_image!, fit: BoxFit.cover),
      ),
    );
  }

  Widget _sensorContextCard() {
    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.separator),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
              child: const Icon(CupertinoIcons.antenna_radiowaves_left_right, size: 19, color: AppColors.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sensor context sent with the photo',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.label),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_service.temp.toStringAsFixed(1)}°C · ${_service.humid.toStringAsFixed(0)}% humidity · soil ${_service.needsWater ? "dry" : "moist"}',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.secondaryLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.sparkles, size: 17, color: AppColors.purple),
              const SizedBox(width: 7),
              const Text(
                'AI Diagnosis',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.label),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _RichAnswer(text: text),
        ],
      ),
    );
  }

  Widget _errorCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
                child: const Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 19, color: AppColors.orange),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Couldn't analyze this photo",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.label),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(fontSize: 13.5, color: AppColors.secondaryLabel, height: 1.4)),
          const SizedBox(height: 14),
          SizedBox(
            height: 42,
            width: double.infinity,
            child: CupertinoButton(
              color: AppColors.fill,
              borderRadius: BorderRadius.circular(12),
              padding: EdgeInsets.zero,
              onPressed: _analyze,
              child: const Text(
                'Try again',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.label),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _button({required String label, required IconData icon, required Color color, required VoidCallback? onPressed}) {
    return SizedBox(
      height: 48,
      child: CupertinoButton(
        onPressed: onPressed,
        color: color,
        disabledColor: color.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: CupertinoColors.white),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: CupertinoColors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyzingCard extends StatelessWidget {
  const _AnalyzingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.separator),
      ),
      child: const Column(
        children: [
          CupertinoActivityIndicator(radius: 14),
          SizedBox(height: 12),
          Text(
            'Analyzing your plant…',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.label),
          ),
          SizedBox(height: 3),
          Text('This usually takes a few seconds', style: TextStyle(fontSize: 12.5, color: AppColors.secondaryLabel)),
        ],
      ),
    );
  }
}

/// Gemini က markdown လေးလေး ပြန်ပေးတာမို့ **bold** နဲ့ bullet လောက်ကို
/// package မထည့်ဘဲ ကိုယ်တိုင် render လုပ်ပေးတယ်။
class _RichAnswer extends StatelessWidget {
  const _RichAnswer({required this.text});

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
