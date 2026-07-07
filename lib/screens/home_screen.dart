import 'dart:io';
import 'package:flutter/material.dart';
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
  // Palette
  static const Color _bg = Color(0xFFF3F6F3);
  static const Color _primary = Color(0xFF2E7D32);
  static const Color _primaryDark = Color(0xFF1B5E20);
  static const Color _ink = Color(0xFF1B2B1B);
  static const Color _accent = Color(0xFF6A3DE8);

  // Care thresholds — tune these per crop.
  static const int _nMin = 50; // Nitrogen mg/kg
  static const int _pMin = 30; // Phosphorus mg/kg
  static const int _kMin = 50; // Potassium mg/kg
  static const double _lightMin = 5000; // lux (below = too dark)

  // Sensor data
  double temp = 0.0;
  double humid = 0.0;
  int soilMoisture = 0; // 0 = moist, 1 = dry
  int nitrogen = 0; // mg/kg
  int phosphorus = 0; // mg/kg
  int potassium = 0; // mg/kg
  double light = 0.0; // lux

  // Grower action verdicts (derived from the readings above).
  bool get needsWater => soilMoisture == 1;
  bool get needsNitrogen => nitrogen < _nMin;
  bool get needsPhosphorus => phosphorus < _pMin;
  bool get needsPotassium => potassium < _kMin;
  bool get needsNpk => needsNitrogen || needsPhosphorus || needsPotassium;
  bool get needsLight => light < _lightMin;

  String healthStatus = "Not checked yet";
  String advice = "Press the 'Check for updates' button below.";
  Color statusColor = Colors.grey;
  bool isLoading = false;

  // Gemini & Photo state
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gemini API key not configured. Check .env file.')));
      });
    }
  }

  // ESP32 data fetch
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
            healthStatus = "Soil is dry";
            advice = "Action needed: Water the plant as soon as possible.";
            statusColor = Colors.orange;
          } else if (humid > 80.0 && temp > 28.0) {
            healthStatus = "High risk of pests/fungus";
            advice = "Action needed: Improve air circulation and apply pesticide preventively.";
            statusColor = Colors.red;
          } else if (temp > 35.0) {
            healthStatus = "Temperature is too high";
            advice = "Action needed: Move the plant to shade away from direct sunlight.";
            statusColor = Colors.amber;
          } else {
            healthStatus = "Plant health is good";
            advice = "Action needed: None. Keep maintaining it as usual.";
            statusColor = Colors.green;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not connect to ESP32. Please check the Wi-Fi.")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Pick image from camera or gallery
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to pick image: $e")));
    }
  }

  // Analyze plant using Gemini
  Future<void> _analyzePlant() async {
    if (_plantImage == null) return;

    final gemini = _geminiService;
    if (gemini == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gemini API key not configured. Check .env file.')));
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      // Analyze with Gemini, passing live sensor readings for better advice
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

  // Show bottom sheet for image source selection
  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),
              const Text("Add a photo", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              _sourceOption(ctx, Icons.camera_alt_rounded, "Take a photo with camera", ImageSource.camera),
              const SizedBox(height: 8),
              _sourceOption(ctx, Icons.photo_library_rounded, "Choose from gallery", ImageSource.gallery),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceOption(BuildContext ctx, IconData icon, String label, ImageSource source) {
    return Material(
      color: _bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.pop(ctx);
          _pickImage(source);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: _primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: _primary, size: 22),
              ),
              const SizedBox(width: 14),
              Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            Transform.translate(
              offset: const Offset(0, -28),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Floating status card overlapping the header
                    _buildStatusCard(),
                    const SizedBox(height: 26),

                    // === CARE GUIDE — what the grower should do ===
                    _sectionTitle("Care Guide", Icons.task_alt_rounded),
                    const SizedBox(height: 14),
                    _careCard(
                      icon: Icons.water_drop_rounded,
                      title: "Water",
                      needs: needsWater,
                      okText: "Soil is moist — no watering needed",
                      needText: "Soil is dry — water the plant now",
                      accent: const Color(0xFF1E88E5),
                    ),
                    const SizedBox(height: 12),
                    _careCard(
                      icon: Icons.eco_rounded,
                      title: "Nutrients (NPK)",
                      needs: needsNpk,
                      okText: "Nutrient levels are sufficient",
                      needText: "Low nutrients — apply fertilizer",
                      accent: const Color(0xFF2E7D32),
                      extra: _npkBreakdown(),
                    ),
                    const SizedBox(height: 12),
                    _careCard(
                      icon: Icons.wb_sunny_rounded,
                      title: "Sunlight",
                      needs: needsLight,
                      okText: "Light level is good (${light.toStringAsFixed(0)} lux)",
                      needText: "Too dark (${light.toStringAsFixed(0)} lux) — move to brighter spot",
                      accent: const Color(0xFFFB8C00),
                    ),
                    const SizedBox(height: 26),

                    // // Sensor readings (raw reference values)
                    // _sectionTitle("Sensor Readings", Icons.sensors_rounded),
                    // const SizedBox(height: 14),
                    // Row(
                    //   children: [
                    //     Expanded(
                    //       child: _sensorTile(Icons.thermostat_rounded, "Temperature",
                    //           "${temp.toStringAsFixed(1)}°C", const Color(0xFFE53935)),
                    //     ),
                    //     const SizedBox(width: 14),
                    //     Expanded(
                    //       child: _sensorTile(Icons.water_drop_rounded, "Humidity",
                    //           "${humid.toStringAsFixed(1)}%", const Color(0xFF1E88E5)),
                    //     ),
                    //   ],
                    // ),
                    // const SizedBox(height: 14),
                    // Row(
                    //   children: [
                    //     Expanded(child: _sensorTile(Icons.grass_rounded, "Soil", soilMoisture == 0 ? "Moist" : "Dry", const Color(0xFF8D6E63))),
                    //     const SizedBox(width: 14),
                    //     Expanded(child: _sensorTile(Icons.wb_sunny_rounded, "Light", "${light.toStringAsFixed(0)} lux", const Color(0xFFFB8C00))),
                    //   ],
                    // ),
                    const SizedBox(height: 26),

                    // AI analysis
                    _sectionTitle("AI Plant Analysis", Icons.auto_awesome_rounded),
                    const SizedBox(height: 14),
                    _buildPhotoCard(),
                    const SizedBox(height: 16),
                    _primaryButton(
                      onPressed: _isAnalyzing ? null : _showImageSourceOptions,
                      icon: Icons.camera_alt_rounded,
                      label: _isAnalyzing ? "Analyzing photo..." : "Take a photo of the plant",
                      loading: _isAnalyzing,
                      color: _accent,
                    ),
                    if (_geminiResult.isNotEmpty) ...[const SizedBox(height: 16), _buildResultCard()],
                    const SizedBox(height: 26),

                    _primaryButton(
                      onPressed: isLoading ? null : checkPlantHealth,
                      icon: Icons.refresh_rounded,
                      label: "Check for updates",
                      loading: isLoading,
                      color: _primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Gradient header with title and live camera feed.
  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 18, 20, 46),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_primary, _primaryDark]),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.eco_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Smart Plant Monitor",
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 2),
                  Text("Live monitoring & AI care", style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      color: Colors.black,
                      child: Mjpeg(
                        isLive: true,
                        stream: 'http://192.168.1.50:81/stream',
                        error: (context, error, stack) {
                          return const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 40),
                                SizedBox(height: 8),
                                Text("Camera Stream Disconnected", style: TextStyle(color: Colors.white70)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // LIVE badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          _Dot(color: Color(0xFFFF5252)),
                          SizedBox(width: 6),
                          Text(
                            "LIVE",
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                child: Icon(_statusIcon(), color: statusColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "CURRENT STATUS",
                      style: TextStyle(fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w600, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      healthStatus,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(14)),
            child: Text(advice, style: TextStyle(fontSize: 13.5, color: Colors.grey[800], height: 1.4)),
          ),
        ],
      ),
    );
  }

  IconData _statusIcon() {
    if (statusColor == Colors.green) return Icons.check_circle_rounded;
    if (statusColor == Colors.orange) return Icons.water_drop_rounded;
    if (statusColor == Colors.red) return Icons.coronavirus_rounded;
    if (statusColor == Colors.amber) return Icons.wb_sunny_rounded;
    return Icons.eco_rounded;
  }

  // A single "what to do" indicator card. Shows a green OK state or an
  // action-needed state highlighted in [accent].
  Widget _careCard({
    required IconData icon,
    required String title,
    required bool needs,
    required String okText,
    required String needText,
    required Color accent,
    Widget? extra,
  }) {
    final Color color = needs ? accent : _primary;
    final Color okGreen = _primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: needs ? accent.withValues(alpha: 0.35) : Colors.grey.withValues(alpha: 0.12), width: needs ? 1.4 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _ink),
                    ),
                    const SizedBox(height: 3),
                    Text(needs ? needText : okText, style: TextStyle(fontSize: 12.5, color: Colors.grey[600], height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Verdict pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(color: (needs ? accent : okGreen).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(needs ? Icons.priority_high_rounded : Icons.check_rounded, size: 14, color: needs ? accent : okGreen),
                    const SizedBox(width: 3),
                    Text(
                      needs ? "Action" : "OK",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: needs ? accent : okGreen),
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

  // N / P / K mini-breakdown shown inside the Nutrients care card.
  Widget _npkBreakdown() {
    return Row(
      children: [
        _npkStat("N", nitrogen, _nMin),
        const SizedBox(width: 10),
        _npkStat("P", phosphorus, _pMin),
        const SizedBox(width: 10),
        _npkStat("K", potassium, _kMin),
      ],
    );
  }

  Widget _npkStat(String label, int value, int min) {
    final bool low = value < min;
    final Color c = low ? const Color(0xFFEF6C00) : _primary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c),
            ),
            const SizedBox(height: 2),
            Text(
              "$value",
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _ink),
            ),
            Text("mg/kg", style: TextStyle(fontSize: 9, color: Colors.grey[500])),
            const SizedBox(height: 2),
            Text(
              low ? "Low" : "OK",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _primaryDark),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _ink),
        ),
      ],
    );
  }

  // Widget _sensorTile(IconData icon, String label, String value, Color color) {
  //   return Container(
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(18),
  //       boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
  //     ),
  //     child: Row(
  //       children: [
  //         Container(
  //           padding: const EdgeInsets.all(10),
  //           decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
  //           child: Icon(icon, color: color, size: 24),
  //         ),
  //         const SizedBox(width: 12),
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
  //               const SizedBox(height: 3),
  //               Text(
  //                 value,
  //                 style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _ink),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildPhotoCard() {
    return Container(
      width: double.infinity,
      height: 200,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        image: _plantImage != null ? DecorationImage(image: FileImage(_plantImage!), fit: BoxFit.cover) : null,
      ),
      child: _plantImage == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_rounded, size: 44, color: Colors.grey[400]),
                const SizedBox(height: 10),
                Text("No photo yet", style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                const SizedBox(height: 4),
                Text("Take a photo to get AI care advice", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              ],
            )
          : null,
    );
  }

  Widget _buildResultCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.auto_awesome, color: _accent, size: 20),
              ),
              const SizedBox(width: 12),
              const Text("AI Analysis", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: Colors.grey[200], height: 1),
          ),
          _buildAiSections(),
        ],
      ),
    );
  }

  // Renders the Gemini response as titled subject sections. Falls back to
  // plain text when the response isn't in the expected numbered format
  // (e.g. an error message).
  Widget _buildAiSections() {
    final sections = _parseAiSections(_geminiResult);
    if (sections.isEmpty) {
      return Text(_geminiResult, style: TextStyle(fontSize: 14, height: 1.5, color: Colors.grey[800]));
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
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(_aiSectionIcon(title), color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _ink),
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(body, style: TextStyle(fontSize: 13.5, height: 1.45, color: Colors.grey[800])),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Parses lines like "1. Water: needs watering" into (title, body) pairs.
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
      // Strip markdown bold/bullet artifacts.
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
    if (t.contains('water')) return const Color(0xFF1E88E5);
    if (t.contains('nutrient') || t.contains('npk')) return const Color(0xFF2E7D32);
    if (t.contains('sun') || t.contains('light')) return const Color(0xFFFB8C00);
    if (t.contains('temp') || t.contains('humid')) return const Color(0xFF00897B);
    if (t.contains('urgent') || t.contains('action') || t.contains('next')) {
      return const Color(0xFFE53935);
    }
    if (t.contains('problem') || t.contains('pest') || t.contains('disease')) {
      return const Color(0xFFEF6C00);
    }
    if (t.contains('health')) return const Color(0xFF43A047);
    return _accent;
  }

  IconData _aiSectionIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('water')) return Icons.water_drop_rounded;
    if (t.contains('nutrient') || t.contains('npk')) return Icons.eco_rounded;
    if (t.contains('sun') || t.contains('light')) return Icons.wb_sunny_rounded;
    if (t.contains('temp') || t.contains('humid')) return Icons.device_thermostat_rounded;
    if (t.contains('urgent') || t.contains('action') || t.contains('next')) {
      return Icons.priority_high_rounded;
    }
    if (t.contains('problem') || t.contains('pest') || t.contains('disease')) {
      return Icons.bug_report_rounded;
    }
    if (t.contains('health')) return Icons.favorite_rounded;
    if (t.contains('type') || t.contains('plant')) return Icons.local_florist_rounded;
    return Icons.chevron_right_rounded;
  }

  Widget _primaryButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required bool loading,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.6),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            else
              Icon(icon, size: 20),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// Small solid dot used in the LIVE badge.
class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
