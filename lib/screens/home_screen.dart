import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';
import '../services/gemini_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Sensor data
  double temp = 0.0;
  double humid = 0.0;
  int soilMoisture = 0;

  String healthStatus = "စစ်ဆေးခြင်းမရှိသေးပါ";
  String advice = "အောက်က 'အခြေအနေစစ်ဆေးမည်' ခလုတ်ကို နှိပ်ပါ။";
  Color statusColor = Colors.grey;
  bool isLoading = false;

  // Gemini & Photo state
  File? _plantImage;
  String _geminiResult = '';
  bool _isAnalyzing = false;

  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();
  late final GeminiService _geminiService;

  @override
  void initState() {
    super.initState();
    try {
      _geminiService = GeminiService();
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gemini API key not configured. Check .env file.')),
        );
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
          temp = data['temperature'].toDouble();
          humid = data['humidity'].toDouble();
          soilMoisture = data['soil_moisture'];

          if (soilMoisture == 1) {
            healthStatus = "မြေဆီလွှာ ခြောက်သွေ့နေသည်";
            advice = "လိုအပ်ချက်: အပင်ကို အမြန်ဆုံး ရေလောင်းပေးရန် လိုအပ်ပါသည်။";
            statusColor = Colors.orange;
          } else if (humid > 80.0 && temp > 28.0) {
            healthStatus = "ပိုးမွှား/မှိုကျရောက်နိုင်ခြေ မြင့်မားနေသည်";
            advice = "လိုအပ်ချက်: လေဝင်လေထွက်ကောင်းအောင်လုပ်ပြီး ပိုးသတ်ဆေး ကြိုတင်ဖျန်းပါ။";
            statusColor = Colors.red;
          } else if (temp > 35.0) {
            healthStatus = "အပူချိန် အရမ်းပြင်းထန်နေသည်";
            advice = "လိုအပ်ချက်: အပင်ကို နေရောင်တိုက်ရိုက်မကျသော အရိပ်အောက် ရွှေ့ပေးပါ။";
            statusColor = Colors.amber;
          } else {
            healthStatus = "အပင်ကျန်းမာရေး ကောင်းမွန်ပါသည်";
            advice = "လိုအပ်ချက်: မရှိပါ။ ပုံမှန်အတိုင်း ဆက်လက်ထိန်းသိမ်းပါ။";
            statusColor = Colors.green;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ESP32 နဲ့ ချိတ်ဆက်၍မရပါ။ Wi-Fi ကို ပြန်စစ်ပါ။")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Pick image from camera or gallery
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _plantImage = File(pickedFile.path);
          _geminiResult = '';
        });
        _analyzePlant();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to pick image: $e")),
      );
    }
  }

  // Analyze plant using Gemini
  Future<void> _analyzePlant() async {
    if (_plantImage == null) return;

    setState(() => _isAnalyzing = true);

    try {
      // Upload to Firebase Storage (optional, for record keeping)
      try {
        await _storageService.uploadImage('user_001', _plantImage!);
      } catch (e) {
        // Storage upload failed but we can still analyze
        debugPrint('Storage upload failed: $e');
      }

      // Analyze with Gemini
      final result = await _geminiService.analyzePlantImage(_plantImage!);
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
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("ကင်မရာဖြင့် ရိုက်မည်"),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("ပြခန်းမှ ရွေးမည်"),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Smart Plant Monitor"),
        backgroundColor: Colors.green[700],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Camera Live Stream
            Container(
              height: 200,
              width: double.infinity,
              color: Colors.black,
              child: Mjpeg(
                isLive: true,
                stream: 'http://192.168.1.50:81/stream',
                error: (context, error, stack) {
                  return const Center(
                    child: Text(
                      "Camera Stream Disconnected",
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. Health Status Card
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: statusColor, width: 8)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("လက်ရှိအခြေအနေ",
                              style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                          const SizedBox(height: 5),
                          Text(
                            healthStatus,
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: statusColor),
                          ),
                          const Divider(),
                          Text(advice,
                              style: const TextStyle(fontSize: 14, color: Colors.black)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. Sensor Data
                  Text("ဆင်ဆာများ၏ အချက်အလက်",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: sensorCard(
                              Icons.thermostat, "အပူချိန်", "$temp °C", Colors.red)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: sensorCard(
                              Icons.water_drop, "လေထုစိုထိုင်းဆ", "$humid %", Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  sensorCard(
                    Icons.grass,
                    "မြေဆီလွှာအခြေအနေ",
                    soilMoisture == 0 ? "စိုစွတ် (ကျန်းမာ)" : "ခြောက်သွေ့ (ရေလိုသည်)",
                    Colors.brown,
                  ),

                  const SizedBox(height: 20),

                  // 4. Gemini AI Plant Analysis Section
                  Text("AI အပင်စစ်ဆေးခြင်း",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  // Photo preview
                  if (_plantImage != null)
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: FileImage(_plantImage!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),

                  // Take photo button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isAnalyzing ? null : _showImageSourceOptions,
                      icon: _isAnalyzing
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Icon(Icons.camera_alt),
                      label: Text(
                        _isAnalyzing ? "ဓာတ်ပုံအား စစ်ဆေးနေသည်..." : "အပင်၏ဓာတ်ပုံရိုက်မည်",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),

                  // Gemini result
                  if (_geminiResult.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border(
                            left: const BorderSide(color: Colors.deepPurple, width: 8),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.auto_awesome,
                                    color: Colors.deepPurple[400], size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  "AI ခွဲခြမ်းစိတ်ဖြာချက်",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            Text(
                              _geminiResult,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // 5. Manual refresh button (existing)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : checkPlantHealth,
                      icon: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Icon(Icons.refresh),
                      label: const Text("အခြေအနေသစ် စစ်ဆေးမည်",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget sensorCard(IconData icon, String title, String value, Color iconColor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 30),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
