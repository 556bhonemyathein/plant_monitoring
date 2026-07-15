import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── iOS System Colors ──
  static const Color _systemGreen = Color(0xFF34C759);
  static const Color _systemBlue = Color(0xFF007AFF);
  static const Color _systemOrange = Color(0xFFFF9500);
  static const Color _systemRed = Color(0xFFFF3B30);
  static const Color _systemTeal = Color(0xFF5AC8FA);
  static const Color _label = Color(0xFF1C1C1E);
  static const Color _secondaryLabel = Color(0xFF8E8E93);

  // ── ESP32 network ──
  // ESP32 ရဲ့ IP လိပ်စာ ပြောင်းရင် ဒီတစ်နေရာပဲ ပြင်ရုံပါ။
  static const String _esp32Host = '10.250.118.154';

  // ── Care thresholds ──
  static const int _nMin = 50;
  static const int _pMin = 30;
  static const int _kMin = 50;
  static const double _lightMin = 5000;

  // ── Sensor data ──
  double temp = 0.0;
  double humid = 0.0;
  int soilMoisture = 0;
  int nitrogen = 0;
  int phosphorus = 0;
  int potassium = 0;
  double light = 0.0;

  // ── Derived verdicts ──
  bool get needsWater => soilMoisture == 1;
  bool get needsNitrogen => nitrogen < _nMin;
  bool get needsPhosphorus => phosphorus < _pMin;
  bool get needsPotassium => potassium < _kMin;
  bool get needsNpk => needsNitrogen || needsPhosphorus || needsPotassium;
  bool get needsLight => light < _lightMin;

  String healthStatus = 'Not checked yet';
  String advice = 'Press "Check for updates" below.';
  Color statusColor = _secondaryLabel;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // App ဖွင့်တာနဲ့ ESP32 က data ကို ချက်ချင်း စဆွဲယူပါ။
    WidgetsBinding.instance.addPostFrameCallback((_) => checkPlantHealth());
  }

  // ── Helpers ──
  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [CupertinoDialogAction(isDefaultAction: true, child: const Text('OK'), onPressed: () => Navigator.pop(ctx))],
      ),
    );
  }

  // ── ESP32 data fetch ──
  Future<void> checkPlantHealth() async {
    setState(() => isLoading = true);
    final url = Uri.parse('http://$_esp32Host/data');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        // ESP32 က JSON သို့မဟုတ် HTML dashboard ပြန်ပေးနိုင်တာမို့ နှစ်မျိုးလုံး ဖတ်နိုင်အောင် လုပ်ထားတယ်။
        final data = _parseSensorData(response.body);
        setState(() {
          temp = data['temperature'] ?? temp;
          humid = data['humidity'] ?? humid;
          soilMoisture = (data['soil_moisture'] ?? soilMoisture.toDouble()).toInt();
 
          if (soilMoisture == 1) {
            healthStatus = 'Soil is dry';
            advice = 'Action needed: Water the plant as soon as possible.';
            statusColor = _systemOrange;
          } else if (humid > 80.0 && temp > 28.0) {
            healthStatus = 'High risk of pests/fungus';
            advice = 'Action needed: Improve air circulation and apply pesticide preventively.';
            statusColor = _systemRed;
          } else if (temp > 35.0) {
            healthStatus = 'Temperature is too high';
            advice = 'Action needed: Move the plant to shade away from direct sunlight.';
            statusColor = _systemOrange;
          } else {
            healthStatus = 'Plant health is good';
            advice = 'Action needed: None. Keep maintaining it as usual.';
            statusColor = _systemGreen;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Could not connect to ESP32 at $_esp32Host. Please check the Wi-Fi/network.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ── Sensor data parser (JSON or HTML) ──
  // ESP32 က JSON ပြန်ရင် JSON အဖြစ် ဖတ်တယ်။ HTML dashboard ပြန်ရင်တော့
  // tag တွေ ဖယ်ပြီး "Temperature: 0.60 C" လိုစာသားထဲက ကိန်းဂဏန်းတွေ regex နဲ့ ဆွဲထုတ်တယ်။
  Map<String, double> _parseSensorData(String body) {
    final result = <String, double>{};

    // 1) JSON ဖြစ်ချင်ဖြစ်နိုင်တာမို့ အရင်စမ်းဖတ်
    final trimmed = body.trimLeft();
    if (trimmed.startsWith('{')) {
      try {
        final data = json.decode(body) as Map<String, dynamic>;
        void take(String key, String out) {
          final v = data[key];
          if (v is num) result[out] = v.toDouble();
        }
        take('temperature', 'temperature');
        take('humidity', 'humidity');
        take('soil_moisture', 'soil_moisture');
        take('soilMoisture', 'soil_moisture');
        if (result.isNotEmpty) return result;
      } catch (_) {
        // JSON မဟုတ်ရင် အောက်က HTML parsing ဆက်လုပ်
      }
    }

    // 2) HTML/text အဖြစ် ဖတ် — tag တွေ ဖယ်ပြီး label နောက်က နံပါတ်ကို ရှာ
    final text = body.replaceAll(RegExp(r'<[^>]*>'), ' ');
    double? grab(String label) {
      final m = RegExp('$label' r'\s*:?\s*([-\d.]+)', caseSensitive: false).firstMatch(text);
      if (m == null) return null;
      return double.tryParse(m.group(1)!);
    }

    final t = grab('Temperature');
    final h = grab('Humidity');
    final s = grab(r'Soil\s*Moisture');
    if (t != null) result['temperature'] = t;
    if (h != null) result['humidity'] = h;
    if (s != null) result['soil_moisture'] = s;
    return result;
  }

  // ── Status icon lookup ──
  IconData _statusIcon() {
    if (statusColor == _systemGreen) return CupertinoIcons.check_mark_circled_solid;
    if (statusColor == _systemOrange) return CupertinoIcons.drop_fill;
    if (statusColor == _systemRed) return CupertinoIcons.exclamationmark_triangle_fill;
    return CupertinoIcons.leaf_arrow_circlepath;
  }

  // ── BUILD ──
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoTheme.of(context).barBackgroundColor,
        middle: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.leaf_arrow_circlepath, size: 20, color: _systemGreen),
            SizedBox(width: 6),
            Text(
              'Smart Plant Monitor',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: _label),
            ),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _buildCameraSection(),
              const SizedBox(height: 16),
              _buildStatusCard(),
              const SizedBox(height: 24),
              _sectionTitle(CupertinoIcons.thermometer, 'Sensor Readings'),
              const SizedBox(height: 12),
              _buildSensorReadings(),
              const SizedBox(height: 24),
              _sectionTitle(CupertinoIcons.list_bullet, 'Care Guide'),
              const SizedBox(height: 12),
              _careCard(
                icon: CupertinoIcons.drop,
                title: 'Water',
                needs: needsWater,
                okText: 'Soil is moist — no watering needed',
                needText: 'Soil is dry — water the plant now',
                accent: _systemBlue,
              ),
              // NPK နဲ့ Sunlight fields တွေကို ESP32 က data မပို့သေးတာမို့ ခဏပိတ်ထားတယ်။
              // sensor တွေ ချိတ်ပြီးရင် အောက်ကကုဒ်ကို ပြန်ဖွင့်လိုက်ရုံပါ။
              // const SizedBox(height: 10),
              // _careCard(
              //   icon: CupertinoIcons.leaf_arrow_circlepath,
              //   title: 'Nutrients (NPK)',
              //   needs: needsNpk,
              //   okText: 'Nutrient levels are sufficient',
              //   needText: 'Low nutrients — apply fertilizer',
              //   accent: _systemGreen,
              //   extra: _npkBreakdown(),
              // ),
              // const SizedBox(height: 10),
              // _careCard(
              //   icon: CupertinoIcons.sun_max,
              //   title: 'Sunlight',
              //   needs: needsLight,
              //   okText: 'Light level is good (${light.toStringAsFixed(0)} lux)',
              //   needText: 'Too dark (${light.toStringAsFixed(0)} lux) — move to brighter spot',
              //   accent: _systemOrange,
              // ),
              const SizedBox(height: 24),
              _primaryButton(
                onPressed: isLoading ? null : checkPlantHealth,
                icon: CupertinoIcons.arrow_clockwise,
                label: 'Check for updates',
                loading: isLoading,
                color: _systemGreen,
              ),
              const SizedBox(height: 32),
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
                  isLive: true,
                  stream: 'http://$_esp32Host:8080/stream',
                  error: (context, error, stack) {
                    return Center(
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
                          decoration: const BoxDecoration(color: _systemRed, shape: BoxShape.circle),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CupertinoColors.systemGrey5),
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
                child: Center(child: Icon(_statusIcon(), color: statusColor, size: 22)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT STATUS',
                      style: TextStyle(fontSize: 11, letterSpacing: 0.5, fontWeight: FontWeight.w600, color: _secondaryLabel),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      healthStatus,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: statusColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: CupertinoColors.systemGrey6, borderRadius: BorderRadius.circular(10)),
            child: Text(advice, style: TextStyle(fontSize: 14, color: _label, height: 1.35)),
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
          value: temp.toStringAsFixed(2),
          unit: '°C',
          color: _systemOrange,
        ),
        const SizedBox(width: 10),
        _sensorTile(
          icon: CupertinoIcons.drop,
          label: 'Humidity',
          value: humid.toStringAsFixed(2),
          unit: '%',
          color: _systemBlue,
        ),
        const SizedBox(width: 10),
        _sensorTile(
          icon: CupertinoIcons.leaf_arrow_circlepath,
          label: 'Soil Moisture',
          value: '$soilMoisture',
          unit: '',
          color: _systemTeal,
        ),
      ],
    );
  }

  Widget _sensorTile({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CupertinoColors.systemGrey5),
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
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _label),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 2),
                  Text(unit, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _secondaryLabel)),
                ],
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: _secondaryLabel, height: 1.2),
            ),
          ],
        ),
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
    final Color color = needs ? accent : _systemGreen;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: needs ? accent.withValues(alpha: 0.3) : CupertinoColors.systemGrey5),
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
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _label),
                    ),
                    const SizedBox(height: 2),
                    Text(needs ? needText : okText, style: TextStyle(fontSize: 13, color: _secondaryLabel, height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: (needs ? accent : _systemGreen).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      needs ? CupertinoIcons.exclamationmark_triangle : CupertinoIcons.checkmark_alt,
                      size: 13,
                      color: needs ? accent : _systemGreen,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      needs ? 'Action' : 'OK',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: needs ? accent : _systemGreen),
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
        _npkStat('N', nitrogen, _nMin),
        const SizedBox(width: 8),
        _npkStat('P', phosphorus, _pMin),
        const SizedBox(width: 8),
        _npkStat('K', potassium, _kMin),
      ],
    );
  }

  Widget _npkStat(String label, int value, int min) {
    final bool low = value < min;
    final Color c = low ? _systemOrange : _systemGreen;
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _label),
            ),
            Text('mg/kg', style: TextStyle(fontSize: 10, color: _secondaryLabel)),
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
        Icon(icon, size: 18, color: _systemGreen),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _label),
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
