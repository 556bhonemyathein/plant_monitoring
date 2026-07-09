import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../services/gemini_service.dart';

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

  // ── Gemini & Photo state ──
  File? _plantImage;
  String _geminiResult = '';
  bool _isAnalyzing = false;

  final ImagePicker _picker = ImagePicker();
  GeminiService? _geminiService;

  @override
  void initState() {
    super.initState();
    try {
      _geminiService = GeminiService();
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showError('Gemini API key not configured. Check .env file.'));
    }
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
    final url = Uri.parse('http://192.168.1.50/data');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          temp = (data['temperature'] as num?)?.toDouble() ?? 0.0;
          humid = (data['humidity'] as num?)?.toDouble() ?? 0.0;
          soilMoisture = (data['soil_moisture'] as num?)?.toInt() ?? 0;
          nitrogen = (data['nitrogen'] as num?)?.toInt() ?? 0;
          phosphorus = (data['phosphorus'] as num?)?.toInt() ?? 0;
          potassium = (data['potassium'] as num?)?.toInt() ?? 0;
          light = (data['light'] as num?)?.toDouble() ?? 0.0;

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
      _showError('Could not connect to ESP32. Please check the Wi-Fi.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ── Image picking ──
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
      if (pickedFile != null) {
        setState(() {
          _plantImage = File(pickedFile.path);
          _geminiResult = '';
        });
        _analyzePlant();
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _analyzePlant() async {
    if (_plantImage == null) return;
    final gemini = _geminiService;
    if (gemini == null) {
      _showError('Gemini API key not configured. Check .env file.');
      return;
    }

    setState(() => _isAnalyzing = true);
    try {
      final result = await gemini.analyzePlantImage(
        _plantImage!,
        temperature: temp,
        humidity: humid,
        soilMoisture: soilMoisture,
        nitrogen: nitrogen,
        phosphorus: phosphorus,
        potassium: potassium,
        light: light,
      );
      setState(() => _geminiResult = result);
    } catch (e) {
      setState(() => _geminiResult = 'Analysis failed: $e');
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  void _showImageSourceOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Add a photo'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.camera);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Icon(CupertinoIcons.camera, size: 20), SizedBox(width: 8), Text('Take a photo with camera')],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.gallery);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Icon(CupertinoIcons.photo, size: 20), SizedBox(width: 8), Text('Choose from gallery')],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(isDefaultAction: true, onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      ),
    );
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
              const SizedBox(height: 10),
              _careCard(
                icon: CupertinoIcons.leaf_arrow_circlepath,
                title: 'Nutrients (NPK)',
                needs: needsNpk,
                okText: 'Nutrient levels are sufficient',
                needText: 'Low nutrients — apply fertilizer',
                accent: _systemGreen,
                extra: _npkBreakdown(),
              ),
              const SizedBox(height: 10),
              _careCard(
                icon: CupertinoIcons.sun_max,
                title: 'Sunlight',
                needs: needsLight,
                okText: 'Light level is good (${light.toStringAsFixed(0)} lux)',
                needText: 'Too dark (${light.toStringAsFixed(0)} lux) — move to brighter spot',
                accent: _systemOrange,
              ),
              const SizedBox(height: 24),
              _sectionTitle(CupertinoIcons.sparkles, 'AI Plant Analysis'),
              const SizedBox(height: 12),
              _buildPhotoCard(),
              const SizedBox(height: 14),
              _primaryButton(
                onPressed: _isAnalyzing ? null : _showImageSourceOptions,
                icon: CupertinoIcons.camera,
                label: _isAnalyzing ? 'Analyzing photo...' : 'Take a photo of the plant',
                loading: _isAnalyzing,
                color: _systemBlue,
              ),
              if (_geminiResult.isNotEmpty) ...[const SizedBox(height: 16), _buildResultCard()],
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
                  stream: 'http://192.168.1.50:81/stream',
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

  // ── Photo Card ──
  Widget _buildPhotoCard() {
    return Container(
      width: double.infinity,
      height: 200,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CupertinoColors.systemGrey5),
        image: _plantImage != null ? DecorationImage(image: FileImage(_plantImage!), fit: BoxFit.cover) : null,
      ),
      child: _plantImage == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo_on_rectangle, size: 40, color: CupertinoColors.systemGrey3),
                const SizedBox(height: 10),
                Text('No photo yet', style: TextStyle(color: _secondaryLabel, fontSize: 15)),
                const SizedBox(height: 4),
                Text('Take a photo to get AI care advice', style: TextStyle(color: CupertinoColors.systemGrey3, fontSize: 13)),
              ],
            )
          : null,
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

  // ── AI Result Card ──
  Widget _buildResultCard() {
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
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: _systemBlue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: const Center(child: Icon(CupertinoIcons.sparkles, color: _systemBlue, size: 18)),
              ),
              const SizedBox(width: 12),
              const Text(
                'AI Analysis',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _label),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Container(height: 1, color: CupertinoColors.systemGrey5),
          ),
          _buildAiSections(),
        ],
      ),
    );
  }

  // ── AI Sections Parser ──
  Widget _buildAiSections() {
    final sections = _parseAiSections(_geminiResult);
    if (sections.isEmpty) {
      return Text(_geminiResult, style: TextStyle(fontSize: 14, height: 1.5, color: _label));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < sections.length; i++) ...[if (i > 0) const SizedBox(height: 14), _aiSection(sections[i].$1, sections[i].$2)],
      ],
    );
  }

  Widget _aiSection(String title, String body) {
    final color = _aiSectionColor(title);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
          child: Center(child: Icon(_aiSectionIcon(title), color: color, size: 17)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _label),
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(body, style: TextStyle(fontSize: 14, height: 1.45, color: _label.withValues(alpha: 0.8))),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<(String, String)> _parseAiSections(String text) {
    final sections = <(String, String)>[];
    final headerRe = RegExp(r'^\s*\d+[\.\)]\s*([^:]+):\s*(.*)$');
    String? title;
    final body = StringBuffer();

    void flush() {
      final t = title;
      if (t != null) {
        sections.add((t, body.toString().trim()));
      }
      body.clear();
    }

    for (final raw in text.split('\n')) {
      final line = raw.replaceAll('**', '').replaceAll(RegExp(r'^\s*[\*\-]\s*'), '').trim();
      if (line.isEmpty) continue;
      final m = headerRe.firstMatch(line);
      if (m != null) {
        flush();
        title = m.group(1)!.trim();
        final rest = m.group(2)!.trim();
        if (rest.isNotEmpty) body.writeln(rest);
      } else if (title != null) {
        body.writeln(line);
      }
    }
    flush();
    return sections;
  }

  Color _aiSectionColor(String title) {
    final t = title.toLowerCase();
    if (t.contains('water')) return _systemBlue;
    if (t.contains('nutrient') || t.contains('npk')) return _systemGreen;
    if (t.contains('sun') || t.contains('light')) return _systemOrange;
    if (t.contains('temp') || t.contains('humid')) return _systemTeal;
    if (t.contains('urgent') || t.contains('action') || t.contains('next')) return _systemRed;
    if (t.contains('problem') || t.contains('pest') || t.contains('disease')) return _systemOrange;
    if (t.contains('health')) return _systemGreen;
    return _systemBlue;
  }

  IconData _aiSectionIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('water')) return CupertinoIcons.drop;
    if (t.contains('nutrient') || t.contains('npk')) return CupertinoIcons.leaf_arrow_circlepath;
    if (t.contains('sun') || t.contains('light')) return CupertinoIcons.sun_max;
    if (t.contains('temp') || t.contains('humid')) return CupertinoIcons.thermometer;
    if (t.contains('urgent') || t.contains('action') || t.contains('next')) return CupertinoIcons.exclamationmark_triangle;
    if (t.contains('problem') || t.contains('pest') || t.contains('disease')) return CupertinoIcons.ant;
    if (t.contains('health')) return CupertinoIcons.heart;
    if (t.contains('type') || t.contains('plant')) return CupertinoIcons.sparkles;
    return CupertinoIcons.chevron_right;
  }
}
