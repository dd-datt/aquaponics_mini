import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../services/mqtt_service.dart';
import '../services/api_service.dart';
import 'dart:convert';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String status = 'Đang kết nối...';
  String temp = '--';
  String humidity = '--';
  String waterLevel = '--';
  String imageUrl = '';
  String aiLabel = '';
  bool pumpOn = false;
  bool lightOn = false;

  @override
  void initState() {
    super.initState();
    final mqtt = Provider.of<MqttService>(context, listen: false);
    mqtt.connect().then((_) {
      mqtt.listenStatus((msg) {
        // Giả sử msg là JSON: {"temp":28,"humidity":65,"water":"Đầy","pump":true,"light":false}
        try {
          final data = msg.contains('{') ? msg : '{}';
          final decoded = data.isNotEmpty ? Map<String, dynamic>.from(_parseJson(data)) : {};
          setState(() {
            temp = decoded['temp']?.toString() ?? '--';
            humidity = decoded['humidity']?.toString() ?? '--';
            waterLevel = decoded['water']?.toString() ?? '--';
            pumpOn = decoded['pump'] ?? false;
            lightOn = decoded['light'] ?? false;
            status = 'Hoạt động';
          });
        } catch (_) {}
      });
    });
    _fetchImageAndLabel();
  }

  Future<void> _fetchImageAndLabel() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final img = await api.getLastImage();
    final label = await api.getLastPrediction();
    setState(() {
      imageUrl = img.isNotEmpty ? img : 'https://via.placeholder.com/400x200?text=Ảnh+ESP32-CAM';
      aiLabel = label.isNotEmpty ? label : 'healthy (95%)';
    });
  }

  dynamic _parseJson(String data) {
    try {
      return data.isNotEmpty ? jsonDecode(data) : {};
    } catch (_) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final mqtt = Provider.of<MqttService>(context);
    return Scaffold(
      appBar: AppBar(title: Text('Aquaponics Mini'), backgroundColor: const Color.fromARGB(255, 117, 216, 122)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.green[50],
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(Icons.eco, color: Colors.green),
                title: Text('Aquaponics Mini', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Trạng thái: $status', style: TextStyle(color: Colors.green[800])),
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildInfoChip(Icons.thermostat, '$temp°C', Colors.orange),
                _buildInfoChip(Icons.water_drop, '$humidity%', Colors.blue),
                _buildInfoChip(Icons.waves, waterLevel, Colors.teal),
              ],
            ),
            SizedBox(height: 16),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.network(imageUrl, height: 120, width: double.infinity, fit: BoxFit.cover),
                  ),
                  ListTile(
                    leading: Icon(Icons.label, color: Colors.green),
                    title: Text('Kết quả AI'),
                    subtitle: Text(aiLabel),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pumpOn ? Colors.blue : Colors.grey[300],
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    bool newPumpState = !pumpOn;
                    mqtt.publishCmd('{"pump":$newPumpState,"light":$lightOn}');
                    setState(() => pumpOn = newPumpState);
                  },
                  icon: Icon(Icons.water),
                  label: Text(pumpOn ? 'Tắt Bơm' : 'Bật Bơm'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: lightOn ? Colors.yellow[700] : Colors.grey[300],
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    bool newLightState = !lightOn;
                    mqtt.publishCmd('{"pump":$pumpOn,"light":$newLightState}');
                    setState(() => lightOn = newLightState);
                  },
                  icon: Icon(Icons.lightbulb),
                  label: Text(lightOn ? 'Tắt Đèn' : 'Bật Đèn'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color.withOpacity(0.2),
        child: Icon(icon, color: color, size: 20),
      ),
      label: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
      backgroundColor: Colors.white,
      elevation: 2,
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}
