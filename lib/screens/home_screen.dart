import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

import '../models/ai_care_advice.dart';
import '../services/plant_service.dart';
import '../theme/app_colors.dart';
import 'root_shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PlantService _service = PlantService.instance;

  @override
  void initState() {
    super.initState();
    // App ဖွင့်တာနဲ့ ESP32 က data ကို ချက်ချင်း စဆွဲယူပါ။
    WidgetsBinding.instance.addPostFrameCallback((_) => _service.refresh());
  }

  Future<void> _refresh() async {
    await _service.refresh();
    final error = _service.lastError;
    if (error != null && mounted) _showError(error);
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoTheme.of(context).barBackgroundColor,
        middle: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.leaf_arrow_circlepath, size: 20, color: AppColors.green),
            SizedBox(width: 6),
            Text(
              'Plant Monitoring',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: AppColors.label),
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
                    _buildStatusCard(),
                    const SizedBox(height: 24),
                    _sectionTitle(CupertinoIcons.thermometer, 'Sensor Readings'),
                    const SizedBox(height: 12),
                    _buildSensorReadings(),
                    const SizedBox(height: 24),
                    _careGuideHeader(),
                    const SizedBox(height: 12),
                    _buildCareGuide(),
                    const SizedBox(height: 24),
                    _primaryButton(
                      onPressed: _service.isLoading ? null : _refresh,
                      icon: CupertinoIcons.arrow_clockwise,
                      label: 'Check for updates',
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
                child: Mjpeg(
                  key: ValueKey(_service.streamUrl),
                  isLive: true,
                  stream: _service.streamUrl,
                  error: (context, error, stack) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.exclamationmark_triangle_fill, color: CupertinoColors.white, size: 36),
                          SizedBox(height: 8),
                          Text('Camera Stream Disconnected', style: TextStyle(color: CupertinoColors.white, fontSize: 14)),
                        ],
                      ),
                    );
                  },
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
                        const Text(
                          'LIVE',
                          style: TextStyle(color: CupertinoColors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
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

  // ── Status Card ──
  Widget _buildStatusCard() {
    final statusColor = _service.statusColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(22)),
                child: Center(child: Icon(_service.statusIcon, color: statusColor, size: 22)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CURRENT STATUS',
                      style: TextStyle(fontSize: 11, letterSpacing: 0.5, fontWeight: FontWeight.w600, color: AppColors.secondaryLabel),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _service.headline,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: statusColor),
                    ),
                  ],
                ),
              ),
              Text(_service.lastUpdatedLabel, style: const TextStyle(fontSize: 11, color: AppColors.secondaryLabel)),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.fill, borderRadius: BorderRadius.circular(10)),
            child: Text(_service.advice, style: const TextStyle(fontSize: 14, color: AppColors.label, height: 1.35)),
          ),
        ],
      ),
    );
  }

  // ── Sensor Readings (Temperature / Humidity / Soil Moisture) ──
  Widget _buildSensorReadings() {
    return Row(
      children: [
        _sensorTile(
          icon: CupertinoIcons.thermometer,
          label: 'Temperature',
          value: _service.temp.toStringAsFixed(2),
          unit: '°C',
          color: AppColors.orange,
        ),
        const SizedBox(width: 10),
        _sensorTile(icon: CupertinoIcons.drop, label: 'Humidity', value: _service.humid.toStringAsFixed(2), unit: '%', color: AppColors.blue),
        const SizedBox(width: 10),
        _sensorTile(
          icon: CupertinoIcons.leaf_arrow_circlepath,
          label: 'Soil Moisture',
          value: '${_service.soilMoisture}',
          unit: '',
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
              style: const TextStyle(fontSize: 11, color: AppColors.secondaryLabel, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }

  // ── AI Care Guide ──
  // Threshold တွေနဲ့ ကိုယ်တိုင်တွက်တဲ့အစား sensor readings ကို Gemini ဆီပို့ပြီး
  // အကြံပြုချက် ပြန်ယူတယ်။ AI မရလို့ရှိရင် အောက်က threshold guide ကို fallback ပြတယ်။
  Widget _careGuideHeader() {
    return Row(
      children: [
        const Icon(CupertinoIcons.sparkles, size: 18, color: AppColors.purple),
        const SizedBox(width: 8),
        const Text(
          'Care Guide',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.label),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: AppColors.purple.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
          child: const Text(
            'AI',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: AppColors.purple),
          ),
        ),
        const Spacer(),
        if (_service.hasData && !_service.aiLoading)
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: _service.refreshAiAdvice,
            child: const Icon(CupertinoIcons.arrow_2_circlepath, size: 19, color: AppColors.purple),
          ),
      ],
    );
  }

  Widget _buildCareGuide() {
    final advice = _service.aiAdvice;

    if (!_service.hasData) {
      return _noticeCard(
        icon: CupertinoIcons.antenna_radiowaves_left_right,
        color: AppColors.secondaryLabel,
        title: 'Waiting for sensor data',
        message: 'Once the ESP32 reports its readings, the AI will suggest what your plant needs.',
      );
    }

    if (advice == null && _service.aiLoading) {
      return _noticeCard(
        icon: CupertinoIcons.sparkles,
        color: AppColors.purple,
        title: 'Asking the AI…',
        message: 'Reading your latest sensor values and writing a care plan.',
        busy: true,
      );
    }

    if (advice == null) {
      // AI မရရင် အရင်က threshold-based cards တွေနဲ့ ဆက်အလုပ်လုပ်နိုင်တယ်။
      return Column(
        children: [
          _noticeCard(
            icon: CupertinoIcons.exclamationmark_circle,
            color: AppColors.orange,
            title: 'AI guide unavailable',
            message: _service.aiError ?? 'Could not reach Gemini. Showing the built-in threshold guide instead.',
          ),
          const SizedBox(height: 10),
          _thresholdGuide(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.purple.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      advice.headline,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.label),
                    ),
                  ),
                  if (_service.aiLoading) const CupertinoActivityIndicator(radius: 8),
                ],
              ),
              if (advice.summary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(advice.summary, style: const TextStyle(fontSize: 13.5, color: AppColors.secondaryLabel, height: 1.4)),
              ],
            ],
          ),
        ),
        for (final action in advice.actions) ...[const SizedBox(height: 10), _aiActionCard(action)],
      ],
    );
  }

  Widget _aiActionCard(CareAction action) {
    final (Color color, IconData icon, String badge) = switch (action.urgency) {
      CareUrgency.now => (AppColors.red, CupertinoIcons.exclamationmark_triangle_fill, 'Now'),
      CareUrgency.soon => (AppColors.orange, CupertinoIcons.clock_fill, 'Soon'),
      CareUrgency.ok => (AppColors.green, CupertinoIcons.checkmark_alt, 'OK'),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: action.urgency == CareUrgency.ok ? AppColors.separator : color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.label),
                ),
                if (action.detail.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(action.detail, style: const TextStyle(fontSize: 13, color: AppColors.secondaryLabel, height: 1.35)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Text(
              badge,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }

  /// AI မရတဲ့အခါ သုံးမယ့် threshold-based guide။
  Widget _thresholdGuide() {
    return _careCard(
      icon: CupertinoIcons.drop,
      title: 'Water',
      needs: _service.needsWater,
      okText: 'Soil is moist — no watering needed',
      needText: 'Soil is dry — water the plant now',
      accent: AppColors.blue,
    );
    // NPK နဲ့ Sunlight fields တွေကို ESP32 က data မပို့သေးတာမို့ ခဏပိတ်ထားတယ်။
    // sensor တွေ ချိတ်ပြီးရင် _careCard တွေ ထပ်ထည့်လိုက်ရုံပါ (_npkBreakdown ကို extra အဖြစ်သုံး)။
  }

  Widget _noticeCard({required IconData icon, required Color color, required String title, required String message, bool busy = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.separator),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: busy ? const Center(child: CupertinoActivityIndicator(radius: 9)) : Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.label),
                ),
                const SizedBox(height: 3),
                Text(message, style: const TextStyle(fontSize: 13, color: AppColors.secondaryLabel, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Care Card ──
  Widget _careCard({
    required IconData icon,
    required String title,
    required bool needs,
    required String okText,
    required String needText,
    required Color accent,
    Widget? extra,
  }) {
    final Color color = needs ? accent : AppColors.green;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: needs ? accent.withValues(alpha: 0.3) : AppColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Center(child: Icon(icon, color: color, size: 22)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.label),
                    ),
                    const SizedBox(height: 2),
                    Text(needs ? needText : okText, style: const TextStyle(fontSize: 13, color: AppColors.secondaryLabel, height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(needs ? CupertinoIcons.exclamationmark_triangle : CupertinoIcons.checkmark_alt, size: 13, color: color),
                    const SizedBox(width: 3),
                    Text(
                      needs ? 'Action' : 'OK',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (extra != null) ...[const SizedBox(height: 14), extra],
        ],
      ),
    );
  }

  // ── NPK Breakdown ──
  // ignore: unused_element  (NPK card ပြန်ဖွင့်ရင် ပြန်သုံးမယ့်ကုဒ်)
  Widget _npkBreakdown() {
    return Row(
      children: [
        _npkStat('N', _service.nitrogen, PlantService.nMin),
        const SizedBox(width: 8),
        _npkStat('P', _service.phosphorus, PlantService.pMin),
        const SizedBox(width: 8),
        _npkStat('K', _service.potassium, PlantService.kMin),
      ],
    );
  }

  Widget _npkStat(String label, int value, int min) {
    final bool low = value < min;
    final Color c = low ? AppColors.orange : AppColors.green;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c),
            ),
            const SizedBox(height: 2),
            Text(
              '$value',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.label),
            ),
            const Text('mg/kg', style: TextStyle(fontSize: 10, color: AppColors.secondaryLabel)),
            const SizedBox(height: 2),
            Text(
              low ? 'Low' : 'OK',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section Title ──
  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.green),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.label),
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
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: CupertinoColors.white),
            ),
          ],
        ),
      ),
    );
  }
}
