import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import '../l10n/app_strings.dart';
import '../services/blynk_service.dart';
import '../services/gemini_service.dart';
import '../services/plant_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
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
  ({String title, String question})? _lastAsk; // "ထပ်စမ်းရန်" အတွက် နောက်ဆုံးမေးခွန်း
  Uint8List? _photo; // AI ကို ပို့လိုက်တဲ့ ESP32-CAM ဓာတ်ပုံ (အဖြေနဲ့အတူ ပြဖို့)
  String? _answer;
  String? _askError;
  bool _asking = false;
  bool _capturing = false;
  bool _openingBlynk = false;

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

  /// ESP32-CAM ကနေ ဓာတ်ပုံတစ်ပုံ ဖမ်းပြီး အဲဒီပုံအပေါ် AI ကို မေးတယ်။
  /// အပူချိန်/စိုထိုင်းဆ/မြေဆီ အခြေအနေတွေကတော့ AI မလိုဘဲ threshold နဲ့ တွက်တာမို့
  /// AI ကို ဓာတ်ပုံအခြေခံ မေးခွန်း (ရောဂါ/ဆေးဖျန်း) အတွက်ပဲ သုံးတယ်။
  Future<void> _askAboutPhoto({required String title, required String question}) async {
    setState(() {
      _askTitle = title;
      _lastAsk = (title: title, question: question);
      _photo = null;
      _answer = null;
      _askError = null;
      _asking = true;
      _capturing = true;
    });
    try {
      final photo = await _service.captureStill();
      if (mounted) {
        setState(() {
          _capturing = false;
          _photo = photo;
        });
      }
      final answer = await GeminiService().analyzeImageBytes(
        photo,
        question: question,
        temperature: _service.temp,
        humidity: _service.humid,
        soilMoisture: _service.soilMoisture,
      );
      if (mounted) setState(() => _answer = answer);
    } catch (e) {
      if (mounted) {
        setState(() {
          _askError = _messageFor(e);
          // card ရဲ့ ခေါင်းစဉ်ကိုပါ သတိပေးချက်အဖြစ် ပြောင်းပေးတယ်။
          _askTitle = _errorTitleFor(e) ?? _askTitle;
        });
      }
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
    // ဘာသာစကား မှားပြီး ဖတ်လို့မရတဲ့ အဖြေ၊ အပင်မဟုတ်တဲ့ ဓာတ်ပုံ နှစ်မျိုးလုံးမှာ
    // AI ရဲ့ စာသားကို လုံးဝ မပြဘဲ သတိပေးချက်ပဲ ပြတယ်။
    AiUnreadableException() => _s.unreadableAnswerMessage,
    NotAPlantException() => _s.notAPlantMessage,
    GeminiException() => e.message,
    PlantCameraException() => _s.captureFailed(e.url),
    _ => _s.aiAnalysisFailed(e),
  };

  /// သတိပေးချက် အမျိုးအစားအလိုက် answer card ရဲ့ ခေါင်းစဉ် (မရှိရင် ခလုတ်နာမည် အတိုင်း)။
  String? _errorTitleFor(Object e) => switch (e) {
    AiUnreadableException() => _s.unreadableAnswerTitle,
    NotAPlantException() => _s.notAPlantTitle,
    _ => null,
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
                    const SizedBox(height: AppSpacing.lg),
                    _buildSensorReadings(),
                    const SizedBox(height: AppSpacing.xl),
                    _sectionTitle(CupertinoIcons.checkmark_seal, _s.conditionSection, AppColors.green),
                    _conditionCard(),
                    const SizedBox(height: AppSpacing.xl),
                    _sectionTitle(CupertinoIcons.camera_viewfinder, _s.askAiCameraSection, AppColors.blue),
                    _photoQuestionButtons(),
                    if (_asking || _answer != null || _askError != null) ...[const SizedBox(height: AppSpacing.lg), _answerCard()],
                    const SizedBox(height: AppSpacing.xl),
                    _primaryButton(
                      onPressed: _service.isLoading ? null : _refresh,
                      icon: CupertinoIcons.arrow_clockwise,
                      label: _s.checkForUpdates,
                      loading: _service.isLoading,
                      color: AppColors.green,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _sectionTitle(CupertinoIcons.gear_alt, _s.blynkSection, AppColors.green),
                    _careSystemCard(),
                    const SizedBox(height: AppSpacing.lg),
                    _primaryButton(
                      onPressed: _openingBlynk ? null : _openBlynk,
                      icon: CupertinoIcons.arrow_up_right_square,
                      label: _s.systemUse,
                      loading: _openingBlynk,
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
    // ဓာတ်ပုံဖမ်းနေချိန်မှာလည်း ဖြုတ်ထားရမယ် — camera က connection တစ်ခုပဲ ပေးလို့။
    final streaming = ActiveTab.isActive(context, ActiveTab.home) && !_service.streamPaused;

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
        const SizedBox(width: AppSpacing.md),
        _sensorTile(icon: CupertinoIcons.drop, label: _s.humidity, value: _service.humid.toStringAsFixed(0), unit: '%', color: AppColors.blue),
        const SizedBox(width: AppSpacing.md),
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
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.sm),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: AppRadius.card, boxShadow: AppShadow.card),
        child: Column(
          children: [
            IconChip(icon: icon, color: color, size: 40),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: AppText.metric),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 2),
                  Text(
                    unit,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.secondaryLabel),
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
              style: AppText.caption,
            ),
          ],
        ),
      ),
    );
  }

  // ── Sensor အခြေအနေ (AI မလို — threshold တွေနဲ့ app ကိုယ်တိုင် တွက်တာ) ──
  Widget _conditionCard() {
    if (!_service.hasData) {
      return _card(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _s.waitingForSensorTitle,
                  style: AppText.rowTitle,
                ),
                const SizedBox(height: 4),
                Text(_s.waitingForSensorMessage, style: const TextStyle(fontSize: 12.5, color: AppColors.secondaryLabel, height: 1.35)),
              ],
            ),
          ),
        ],
      );
    }

    final temp = _service.tempCondition;
    final humidity = _service.humidityCondition;
    final soil = _service.soilCondition;

    return _card(
      children: [
        _conditionRow(
          icon: CupertinoIcons.thermometer,
          title: _s.temperature,
          reading: '${_service.temp.toStringAsFixed(1)}°C',
          label: _s.tempConditionLabel(temp),
          advice: _s.tempConditionAdvice(temp),
          level: temp.level,
        ),
        const AppSeparator(),
        _conditionRow(
          icon: CupertinoIcons.drop,
          title: _s.humidity,
          reading: '${_service.humid.toStringAsFixed(0)}%',
          label: _s.humidityConditionLabel(humidity),
          advice: _s.humidityConditionAdvice(humidity),
          level: humidity.level,
        ),
        const AppSeparator(),
        _conditionRow(
          icon: CupertinoIcons.leaf_arrow_circlepath,
          title: _s.soilMoisture,
          reading: '${_service.soilMoisturePercent}%',
          label: _s.soilConditionLabel(soil),
          advice: _s.soilConditionAdvice(soil),
          level: soil.level,
        ),
      ],
    );
  }

  Widget _conditionRow({
    required IconData icon,
    required String title,
    required String reading,
    required String label,
    required String advice,
    required ConditionLevel level,
  }) {
    final color = _levelColor(level);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconChip(icon: icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppText.rowTitle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      reading,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color, height: 1.3),
                ),
                const SizedBox(height: 2),
                Text(advice, style: const TextStyle(fontSize: 12.5, color: AppColors.secondaryLabel, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _levelColor(ConditionLevel level) => switch (level) {
    ConditionLevel.good => AppColors.green,
    ConditionLevel.warning => AppColors.orange,
    ConditionLevel.critical => AppColors.red,
  };

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
            question:
                'What rice disease, pest or nutrient deficiency does this crop have? '
                'Name the most likely one (use the common rice name, e.g. blast, bacterial leaf blight, brown planthopper) '
                'and the signs you can see in the photo.',
          ),
        ),
        const AppSeparator(),
        _askRow(
          icon: CupertinoIcons.drop_triangle,
          color: AppColors.green,
          title: _s.askSprayTitle,
          subtitle: _s.askSpraySubtitle,
          onPressed: () => _askAboutPhoto(
            title: _s.askSprayTitle,
            question:
                'Based on this photo, what should I spray or apply to this paddy field? '
                'Give the treatment or fertiliser, how to mix it, the rate per acre, how often to apply it, '
                'and say whether the field water level should be changed.',
          ),
        ),
      ],
    );
  }

  Widget _card({required List<Widget> children}) => AppCard.rows(children: children);

  Widget _askRow({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onPressed}) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: BorderRadius.zero,
      minimumSize: Size.zero,
      onPressed: _asking ? null : onPressed,
      child: Row(
        children: [
          IconChip(icon: icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.rowTitle,
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.rowSubtitle),
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
          // AI ကို တကယ် ပို့လိုက်တဲ့ frame — ဘာကို ကြည့်ပြီး ဖြေထားလဲ မြင်ရအောင်။
          if (_photo != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.memory(_photo!, fit: BoxFit.cover, gaplessPlayback: true),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (busy)
            Text(_capturing ? _s.capturingPhoto : _s.aiThinking, style: const TextStyle(fontSize: 13.5, color: AppColors.secondaryLabel, height: 1.4))
          else if (error != null) ...[
            Text(error, style: const TextStyle(fontSize: 13.5, color: AppColors.secondaryLabel, height: 1.4)),
            if (_lastAsk != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: 42,
                width: double.infinity,
                child: CupertinoButton(
                  color: AppColors.fill,
                  borderRadius: BorderRadius.circular(12),
                  padding: EdgeInsets.zero,
                  onPressed: () => _askAboutPhoto(title: _lastAsk!.title, question: _lastAsk!.question),
                  child: Text(
                    _s.tryAgain,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.label),
                  ),
                ),
              ),
            ],
          ] else if (_answer != null)
            RichAnswer(text: _answer!),
        ],
      ),
    );
  }

  // ── Section Title ──
  Widget _sectionTitle(IconData icon, String title, Color color) => SectionHeader(icon: icon, title: title, color: color);

  // ── အလိုအလျောက် ပြုစုစောင့်ရှောက်ရေး စနစ် ──
  // ဒီ row တွေက ဖော်ပြချက်သက်သက် (နှိပ်လို့မရဘူး) — အောက်က "System Use" ခလုတ်ကနေ
  // Blynk app ကို ဖွင့်ပြီး တကယ့် ခလုတ်တွေကို ထိန်းချုပ်ရတယ်။
  Widget _careSystemCard() {
    return _card(
      children: [
        _infoRow(icon: CupertinoIcons.drop_fill, color: AppColors.blue, title: _s.autoWateringTitle, subtitle: _s.autoWateringSubtitle),
        const AppSeparator(),
        _infoRow(icon: CupertinoIcons.wind, color: AppColors.orange, title: _s.autoSprayingTitle, subtitle: _s.autoSprayingSubtitle),
        const AppSeparator(),
        _infoRow(
          icon: CupertinoIcons.tray_arrow_down_fill,
          color: AppColors.purple,
          title: _s.autoFeedingTitle,
          subtitle: _s.autoFeedingSubtitle,
        ),
        const AppSeparator(),
        _infoRow(icon: CupertinoIcons.waveform_path, color: AppColors.red, title: _s.birdDeterrentTitle, subtitle: _s.birdDeterrentSubtitle),
      ],
    );
  }

  /// [_askRow] နဲ့ ပုံစံတူပေမယ့် နှိပ်လို့မရတဲ့ (chevron မပါတဲ့) အတန်း။
  Widget _infoRow({required IconData icon, required Color color, required String title, required String subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          IconChip(icon: icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.rowTitle,
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.rowSubtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openBlynk() async {
    setState(() => _openingBlynk = true);
    try {
      // Store ကို ပို့လိုက်တာလည်း အောင်မြင်တာပဲ — failed ဆိုမှ သတိပေးချက် ပြတယ်။
      final outcome = await BlynkService.openBlynkApp();
      if (outcome == BlynkLaunchOutcome.failed && mounted) _showError(_s.blynkOpenFailed);
    } catch (e) {
      if (mounted) _showError(_s.blynkOpenFailed);
    } finally {
      if (mounted) setState(() => _openingBlynk = false);
    }
  }

  Widget _primaryButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required bool loading,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: AppRadius.tile,
        // ခလုတ် အသက်ဝင်နေချိန်မှာပဲ အလင်းရိပ် ပြတယ် — disabled မှာ ပြရင် လှည့်စားသလို ဖြစ်တယ်။
        boxShadow: onPressed == null ? null : AppShadow.glow(color),
      ),
      child: CupertinoButton(
        onPressed: onPressed,
        disabledColor: color.withValues(alpha: 0.45),
        borderRadius: AppRadius.tile,
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CupertinoColors.white, letterSpacing: -0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
