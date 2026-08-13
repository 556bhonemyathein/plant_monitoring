import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_strings.dart';
import '../services/gemini_service.dart';
import '../services/plant_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/rich_answer.dart';
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

  /// build() တိုင်းမှာ အသစ်ယူတယ် — helper တွေက context မကိုင်ဘဲ သုံးနိုင်အောင်။
  late AppStrings _s = AppLocale.of(context);

  File? _image;
  String? _result;
  String? _error;
  String? _errorTitle; // သတိပေးချက် ခေါင်းစဉ် (မထည့်ရင် "စစ်ဆေး၍ မရပါ" ကို သုံးတယ်)
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
      if (mounted) _showError(_s.couldNotOpenImage(e));
    }
  }

  Future<void> _analyze() async {
    final image = _image;
    if (image == null) return;

    setState(() {
      _analyzing = true;
      _error = null;
      _errorTitle = null;
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
      // ဖတ်လို့မရတဲ့ အဖြေဆိုရင်တော့ အဖြေအစား ဘာသာစကားအလိုက် သတိပေးချက်ကို ပြတယ်။
      if (mounted) {
        setState(() {
          _errorTitle = switch (e) {
            AiUnreadableException() => _s.unreadableAnswerTitle,
            NotAPlantException() => _s.notAPlantTitle,
            _ => null,
          };
          _error = switch (e) {
            AiUnreadableException() => _s.unreadableAnswerMessage,
            NotAPlantException() => _s.notAPlantMessage,
            GeminiException() => e.message,
            _ => _s.aiAnalysisFailed(e),
          };
        });
      }
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(_s.error),
        content: Text(message),
        actions: [CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(ctx), child: Text(_s.ok))],
      ),
    );
  }

  void _showSourceSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(_s.addPlantPhoto),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _pick(ImageSource.camera);
            },
            child: Text(_s.takePhoto),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _pick(ImageSource.gallery);
            },
            child: Text(_s.chooseFromGallery),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(isDestructiveAction: true, onPressed: () => Navigator.pop(ctx), child: Text(_s.cancel)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _s = AppLocale.of(context);
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        middle: Text(_s.aiScanTitle, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.label)),
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
                    label: _image == null ? _s.addPhoto : _s.changePhoto,
                    icon: CupertinoIcons.camera,
                    color: AppColors.purple,
                    onPressed: _analyzing ? null : _showSourceSheet,
                  ),
                ),
                if (_image != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: _button(
                      label: _s.reanalyze,
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
              _AnalyzingCard(strings: _s)
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
                    borderRadius: AppRadius.card,
                    boxShadow: AppShadow.card,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.sparkles, size: 40, color: AppColors.purple),
                      const SizedBox(height: 10),
                      Text(
                        _s.scanLeafTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.label),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _s.scanLeafSubtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: AppColors.secondaryLabel),
                        ),
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
          borderRadius: AppRadius.card,
          boxShadow: AppShadow.card,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: const Icon(CupertinoIcons.antenna_radiowaves_left_right, size: 19, color: AppColors.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _s.sensorContextTitle,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.label),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _s.sensorContextValue(temp: _service.temp, humidity: _service.humid, dry: _service.needsWater),
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
        borderRadius: AppRadius.card,
        boxShadow: AppShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.sparkles, size: 17, color: AppColors.purple),
              const SizedBox(width: 7),
              Text(
                _s.aiDiagnosis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.label),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RichAnswer(text: text),
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
                decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 19, color: AppColors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _errorTitle ?? _s.couldNotAnalyze,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.label),
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
              child: Text(
                _s.tryAgain,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.label),
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
  const _AnalyzingCard({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.card,
        boxShadow: AppShadow.card,
      ),
      child: Column(
        children: [
          const CupertinoActivityIndicator(radius: 14),
          const SizedBox(height: 12),
          Text(
            strings.analyzingTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.label),
          ),
          const SizedBox(height: 3),
          Text(
            strings.analyzingSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AppColors.secondaryLabel),
          ),
        ],
      ),
    );
  }
}
