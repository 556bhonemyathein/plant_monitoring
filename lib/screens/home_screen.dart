import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import '../l10n/app_strings.dart';
import '../services/gemini_service.dart';
import '../services/plant_service.dart';
import '../theme/app_colors.dart';
import '../widgets/rich_answer.dart';
import 'root_shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PlantService _service = PlantService.instance;

  /// build() တိုင်းမှာ အသစ်ယူတယ် — helper method တွေက context မကိုင်ဘဲ သုံးနိုင်အောင်။
  late AppStrings _s = AppLocale.of(context);

  // ── "AI ကို မေးမယ်" ခလုတ်တွေရဲ့ အခြေအနေ ──
  String? _askTitle; // ဘယ်ခလုတ်ကို နှိပ်ထားလဲ (အဖြေ card ရဲ့ ခေါင်းစဉ်)
  String? _answer;
  String? _askError;
  bool _asking = false;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    // App ဖွင့်တာနဲ့ ESP32 က data ကို ချက်ချင်း စဆွဲယူပါ။
    WidgetsBinding.instance.addPostFrameCallback((_) => _service.refresh());
  }

  Future<void> _refresh() async {
    await _service.refresh();
    final error = _service.lastError;
    if (error != null && mounted) {
      _showError(_s.connectionError(error, host: _service.host, statusCode: _service.lastErrorStatusCode));
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

  /// Sensor တန်ဖိုးတွေအပေါ် အခြေခံပြီး AI ကို မေးခွန်းတစ်ခု မေးတယ်။
  Future<void> _ask({required String title, required String question}) async {
    setState(() {
      _askTitle = title;
      _answer = null;
      _askError = null;
      _asking = true;
      _capturing = false;
    });
    try {
      // API key မရှိရင် GeminiService constructor ကတည်းက exception ပစ်တယ်။
      final answer = await GeminiService().askAboutSensors(
        question: question,
        temperature: _service.temp,
        humidity: _service.humid,
        soilMoisture: _service.soilMoisture,
        soilMoisturePercent: _service.soilMoisturePercent,
      );
      if (mounted) setState(() => _answer = answer);
    } catch (e) {
      if (mounted) setState(() => _askError = _messageFor(e));
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  /// ESP32-CAM ကနေ ဓာတ်ပုံတစ်ပုံ ဖမ်းပြီး အဲဒီပုံအပေါ် AI ကို မေးတယ်။
  Future<void> _askAboutPhoto({required String title, required String question}) async {
    setState(() {
      _askTitle = title;
      _answer = null;
      _askError = null;
      _asking = true;
      _capturing = true;
    });
    try {
      final photo = await _service.captureStill();
      if (mounted) setState(() => _capturing = false);
      final answer = await GeminiService().analyzeImageBytes(
        photo,
        question: question,
        temperature: _service.temp,
        humidity: _service.humid,
        soilMoisture: _service.soilMoisture,
      );
      if (mounted) setState(() => _answer = answer);
    } catch (e) {
      if (mounted) setState(() => _askError = _messageFor(e));
    } finally {
      if (mounted) {
        setState(() {
          _asking = false;
          _capturing = false;
        });
      }
    }
  }

  /// Exception တွေကို user ကို ပြလို့ရတဲ့ စာသားအဖြစ် ပြောင်းတယ်။
  String _messageFor(Object e) => switch (e) {
    GeminiException() => e.message,
    PlantCameraException() => _s.captureFailed(e.url),
    _ => _s.aiAnalysisFailed(e),
  };

  @override
  Widget build(BuildContext context) {
    _s = AppLocale.of(context);
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoTheme.of(context).barBackgroundColor,
        middle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.leaf_arrow_circlepath, size: 20, color: AppColors.green),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _s.appTitle,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: AppColors.label),
              ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _service,
          builder: (context, _) => CustomScrollView(
            slivers: [
              // ဖုန်းကို အောက်ဆွဲချရုံနဲ့ data refresh လုပ်နိုင်တဲ့ iOS ပုံစံ pull-to-refresh။
              CupertinoSliverRefreshControl(onRefresh: _refresh),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, kNavBarClearance),
                sliver: SliverList.list(
                  children: [
                    _buildCameraSection(),
                    const SizedBox(height: 16),
                    _buildSensorReadings(),
                    const SizedBox(height: 24),
                    _sectionTitle(CupertinoIcons.sparkles, _s.askAiSection, AppColors.purple),
                    const SizedBox(height: 12),
                    _sensorQuestionButtons(),
                    const SizedBox(height: 20),
                    _sectionTitle(CupertinoIcons.camera_viewfinder, _s.askAiCameraSection, AppColors.blue),
                    const SizedBox(height: 12),
                    _photoQuestionButtons(),
                    if (_asking || _answer != null || _askError != null) ...[const SizedBox(height: 16), _answerCard()],
                    const SizedBox(height: 24),
                    _primaryButton(
                      onPressed: _service.isLoading ? null : _refresh,
                      icon: CupertinoIcons.arrow_clockwise,
                      label: _s.checkForUpdates,
                      loading: _service.isLoading,
                      color: AppColors.green,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Camera Section ──
  Widget _buildCameraSection() {
    // ESP32-CAM က stream client တစ်ခုတည်းသာ လက်ခံတယ်။ IndexedStack ကြောင့်
    // Live tab ကလည်း အသက်ရှင်နေတာမို့ ဒီ preview က Home ကို ဖွင့်ထားချိန်မှသာ
    // ချိတ်ရမယ် — မဟုတ်ရင် နှစ်ခုလုံး လုနေပြီး တစ်ခုက ပုံမရဘူး။
    final streaming = ActiveTab.isActive(context, ActiveTab.home);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 220,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: CupertinoColors.black,
                child: streaming
                    ? Mjpeg(
                        key: ValueKey(_service.streamUrl),
                        isLive: true,
                        stream: _service.streamUrl,
                        error: (context, error, stack) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: CupertinoColors.white, size: 36),
                                const SizedBox(height: 8),
                                Text(
                                  _s.cameraStreamDisconnected,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: CupertinoColors.white, fontSize: 14),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.pause_circle, color: CupertinoColors.white, size: 36),
                            const SizedBox(height: 8),
                            Text(
                              _s.previewPaused,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: CupertinoColors.white, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            // Frosted glass LIVE badge
            Positioned(
              top: 12,
              left: 12,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: CupertinoColors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _s.live,
                          style: const TextStyle(color: CupertinoColors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sensor Readings (Temperature / Humidity / Soil Moisture) ──
  Widget _buildSensorReadings() {
    return Row(
      children: [
        _sensorTile(
          icon: CupertinoIcons.thermometer,
          label: _s.temperature,
          value: _service.temp.toStringAsFixed(0),
          unit: '°C',
          color: AppColors.orange,
        ),
        const SizedBox(width: 10),
        _sensorTile(icon: CupertinoIcons.drop, label: _s.humidity, value: _service.humid.toStringAsFixed(0), unit: '%', color: AppColors.blue),
        const SizedBox(width: 10),
        // Sensor က 0/1 ပဲပေးတာမို့ PlantService မှာ percent အဖြစ် map လုပ်ထားတယ်။
        _sensorTile(
          icon: CupertinoIcons.leaf_arrow_circlepath,
          label: _s.soilMoisture,
          value: '${_service.soilMoisturePercent}',
          unit: '%',
          color: AppColors.teal,
        ),
      ],
    );
  }

  Widget _sensorTile({required IconData icon, required String label, required String value, required String unit, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.separator),
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
              child: Center(child: Icon(icon, color: color, size: 20)),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.label),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 2),
                  Text(
                    unit,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondaryLabel),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.secondaryLabel, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }

  // ── AI ကို မေးမယ် (sensor အခြေခံ) ──
  Widget _sensorQuestionButtons() {
    return _card(
      children: [
        _askRow(
          icon: CupertinoIcons.leaf_arrow_circlepath,
          color: AppColors.teal,
          title: _s.askSoilTitle,
          subtitle: _s.askSoilSubtitle,
          onPressed: () => _ask(
            title: _s.askSoilTitle,
            question: 'How is the soil moisture right now, and does the plant need watering?',
          ),
        ),
        const _Separator(),
        _askRow(
          icon: CupertinoIcons.thermometer,
          color: AppColors.orange,
          title: _s.askTempTitle,
          subtitle: _s.askTempSubtitle,
          onPressed: () => _ask(
            title: _s.askTempTitle,
            question: 'What is the temperature right now, and is it good for the plant?',
          ),
        ),
        const _Separator(),
        _askRow(
          icon: CupertinoIcons.drop,
          color: AppColors.blue,
          title: _s.askHumidityTitle,
          subtitle: _s.askHumiditySubtitle,
          onPressed: () => _ask(
            title: _s.askHumidityTitle,
            question: 'What is the air humidity right now, and is it good for the plant?',
          ),
        ),
      ],
    );
  }

  // ── AI ကို မေးမယ် (ကင်မရာ ဓာတ်ပုံ အခြေခံ) ──
  Widget _photoQuestionButtons() {
    return _card(
      children: [
        _askRow(
          icon: CupertinoIcons.sparkles,
          color: AppColors.purple,
          title: _s.askDiseaseTitle,
          subtitle: _s.askDiseaseSubtitle,
          onPressed: () => _askAboutPhoto(
            title: _s.askDiseaseTitle,
            question: 'What disease, pest or deficiency does this plant have? Name the most likely one and the signs you can see.',
          ),
        ),
        const _Separator(),
        _askRow(
          icon: CupertinoIcons.drop_triangle,
          color: AppColors.green,
          title: _s.askSprayTitle,
          subtitle: _s.askSpraySubtitle,
          onPressed: () => _askAboutPhoto(
            title: _s.askSprayTitle,
            question: 'Based on this photo, what should I spray or apply to treat the plant? Give the treatment type, how to mix it and how often.',
          ),
        ),
      ],
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.separator),
      ),
      child: Column(children: children),
    );
  }

  Widget _askRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
  }) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: BorderRadius.zero,
      minimumSize: Size.zero,
      onPressed: _asking ? null : onPressed,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.label),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.secondaryLabel, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(CupertinoIcons.chevron_right, size: 15, color: AppColors.secondaryLabel),
        ],
      ),
    );
  }

  // ── AI ရဲ့ အဖြေ ──
  Widget _answerCard() {
    final busy = _asking;
    final error = _askError;
    final accent = error != null ? AppColors.orange : AppColors.purple;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(error != null ? CupertinoIcons.exclamationmark_circle : CupertinoIcons.sparkles, size: 17, color: accent),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _askTitle ?? _s.aiAnswerTitle,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.label),
                ),
              ),
              if (busy) const CupertinoActivityIndicator(radius: 9),
            ],
          ),
          const SizedBox(height: 12),
          if (busy)
            Text(
              _capturing ? _s.capturingPhoto : _s.aiThinking,
              style: const TextStyle(fontSize: 13.5, color: AppColors.secondaryLabel, height: 1.4),
            )
          else if (error != null)
            Text(error, style: const TextStyle(fontSize: 13.5, color: AppColors.secondaryLabel, height: 1.4))
          else if (_answer != null)
            RichAnswer(text: _answer!),
        ],
      ),
    );
  }

  // ── Section Title ──
  Widget _sectionTitle(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.label),
          ),
        ),
      ],
    );
  }

  // ── Primary Button (Cupertino style) ──
  Widget _primaryButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required bool loading,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: CupertinoButton(
        onPressed: onPressed,
        disabledColor: color.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        color: color,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading) const CupertinoActivityIndicator(color: CupertinoColors.white) else Icon(icon, size: 18, color: CupertinoColors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: CupertinoColors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cupertino မှာ Divider မရှိတာမို့ hairline separator ကို ကိုယ်တိုင်လုပ်ထားတယ်။
class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, margin: const EdgeInsets.only(left: 64), color: AppColors.separator);
  }
}
