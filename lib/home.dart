import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart'; // ကင်မရာ stream အတွက်
import 'package:http/http.dart' as http;
import 'dart:convert';

class PlantDashboard extends StatefulWidget {
  const PlantDashboard({super.key});

  @override
  State<PlantDashboard> createState() => _PlantDashboardState();
}

class _PlantDashboardState extends State<PlantDashboard> {
  // ကိန်းဂဏန်းများ သိမ်းဆည်းရန် Variable များ
  double temp = 0.0;
  double humid = 0.0;
  int soilMoisture = 0; // 0 = စိုစွတ်, 1 = ခြောက်သွေ့

  String healthStatus = "စစ်ဆေးခြင်းမရှိသေးပါ";
  String advice = "အောက်က 'အခြေအနေစစ်ဆေးမည်' ခလုတ်ကို နှိပ်ပါ။";
  Color statusColor = Colors.grey;
  bool isLoading = false;

  // ESP32 ထံမှ Data ဖတ်ယူပြီး Logic တွက်ချက်မည့် Function
  Future<void> checkPlantHealth() async {
    setState(() => isLoading = true);

    // မိမိ ESP32 ရဲ့ IP Address ဖြင့် အစားထိုးပါ
    final url = Uri.parse('http://192.168.1.50/data');

    try {
      final response = await http.get(url).timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          temp = data['temperature'].toDouble();
          humid = data['humidity'].toDouble();
          soilMoisture = data['soil_moisture'];

          // --- ဉာဏ်စမ်း Logic များ (၁ လအတွင်း ပြီးမည့်ဗားရှင်း) ---
          if (soilMoisture == 1) {
            healthStatus = "မြေဆီလွှာ ခြောက်သွေ့နေသည်";
            advice =
                "လိုအပ်ချက်: အပင်ကို အမြန်ဆုံး ရေလောင်းပေးရန် လိုအပ်ပါသည်။";
            statusColor = Colors.orange;
          } else if (humid > 80.0 && temp > 28.0) {
            healthStatus = "ပိုးမွှား/မှိုကျရောက်နိုင်ခြေ မြင့်မားနေသည်";
            advice =
                "လိုအပ်ချက်: လေဝင်လေထွက်ကောင်းအောင်လုပ်ပြီး ပိုးသတ်ဆေး ကြိုတင်ဖျန်းပါ။";
            statusColor = Colors.red;
          } else if (temp > 35.0) {
            healthStatus = "အပူချိန် အရမ်းပြင်းထန်နေသည်";
            advice =
                "လိုအပ်ချက်: အပင်ကို နေရောင်တိုက်ရိုက်မကျသော အရိပ်အောက် ရွှေ့ပေးပါ။";
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
        SnackBar(
          content: Text("ESP32 နဲ့ ချိတ်ဆက်၍မရပါ။ Wi-Fi ကို ပြန်စစ်ပါတ။"),
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("Smart Plant Monitor"),
        backgroundColor: Colors.green[700],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ၁။ ကင်မရာ Live Stream ပြသရမည့် နေရာ
            Container(
              height: 250,
              width: double.infinity,
              color: Colors.black,
              child: Mjpeg(
                isLive: true,
                // မိမိ ESP32-CAM ရဲ့ Stream IP Address ဖြင့် အစားထိုးရန်
                stream: 'http://192.168.1.50:81/stream',
                error: (context, error, stack) {
                  return Center(
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
                  // ၂။ အဓိက ကျန်းမာရေး အခြေအနေ ကတ်ပြား
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      padding: EdgeInsets.all(16),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: statusColor, width: 8),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "လက်ရှိအခြေအနေ",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            healthStatus,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                          Divider(),
                          Text(
                            advice,
                            style: TextStyle(fontSize: 14, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  Text(
                    "ဆင်ဆာများ၏ အချက်အလက်",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),

                  // ၃။ ဆင်ဆာအလိုက် အချက်အလက်ပြ ကတ်ပြားများ
                  Row(
                    children: [
                      Expanded(
                        child: sensorCard(
                          Icons.thermostat,
                          "အပူချိန်",
                          "$temp °C",
                          Colors.red,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: sensorCard(
                          Icons.water_drop,
                          "လေထုစိုထိုင်းဆ",
                          "$humid %",
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  sensorCard(
                    Icons.grass,
                    "မြေဆီလွှာအခြေအနေ",
                    soilMoisture == 0
                        ? "စိုစွတ် (ကျန်းမာ)"
                        : "ခြောက်သွေ့ (ရေလိုသည်)",
                    Colors.brown,
                  ),

                  SizedBox(height: 30),

                  // ၄။ အခြေအနေသစ် လှမ်းဖတ်မည့် ခလုတ်
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : checkPlantHealth,
                      icon: isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Icon(Icons.refresh),
                      label: Text(
                        "အခြေအနေသစ် စစ်ဆေးမည်",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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

  // ဆင်ဆာကတ်ပြားများအတွက် အထဲက Component ပုံစံငယ်
  Widget sensorCard(
    IconData icon,
    String title,
    String value,
    Color iconColor,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 30),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
