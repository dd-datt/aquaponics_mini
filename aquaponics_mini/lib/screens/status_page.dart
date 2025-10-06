import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mqtt_service.dart';

class StatusPage extends StatelessWidget {
  const StatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mqtt = Provider.of<MqttService>(context);
    // Lấy dữ liệu từ mqtt.lastData nếu có, fallback nếu không có
    String temp = '--';
    String humidity = '--';
    String waterLevel = '--';
    if (mqtt.lastData != null) {
      final data = mqtt.lastData;
      if (data is Map<String, dynamic>) {
        temp = data['temp']?.toString() ?? '--';
        humidity = data['humidity']?.toString() ?? '--';
        if (data.containsKey('water')) {
          final waterData = data['water'];
          if (waterData != null) {
            if (waterData is bool) {
              waterLevel = waterData ? 'FULL' : 'LOW';
            } else if (waterData is String) {
              final s = waterData.toLowerCase();
              if (s == 'true')
                waterLevel = 'FULL';
              else if (s == 'false')
                waterLevel = 'LOW';
              else
                waterLevel = waterData;
            } else {
              waterLevel = waterData.toString();
            }
          }
        }
      }
    }
    return Scaffold(
      appBar: AppBar(title: Text('Trạng thái hệ thống'), backgroundColor: Colors.green[700]),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSensorCard(
              icon: Icons.thermostat,
              title: 'Nhiệt độ',
              value: temp != '--' ? '$temp°C' : '--',
              color: Colors.orange,
              description: 'Nhiệt độ nước hiện tại',
            ),
            _buildSensorCard(
              icon: Icons.water_drop,
              title: 'Độ ẩm',
              value: humidity != '--' ? '$humidity%' : '--',
              color: Colors.blue,
              description: 'Độ ẩm không khí',
            ),
            _buildSensorCard(
              icon: Icons.waves,
              title: 'Mức nước',
              value: waterLevel,
              color: Colors.teal,
              description: 'Mức nước bể',
            ),
            Card(
              color: Colors.green[50],
              child: ListTile(
                leading: Icon(Icons.camera_alt, color: Colors.green),
                title: Text('ESP32-CAM'),
                subtitle: Text(mqtt.status.isNotEmpty ? mqtt.status : 'Chưa có trạng thái'),
              ),
            ),
            Card(
              color: Colors.red[50],
              child: ListTile(
                leading: Icon(Icons.warning, color: Colors.red),
                title: Text('Cảnh báo'),
                subtitle: Text('Không có cảnh báo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required String description,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: Text(
          value,
          style: TextStyle(fontSize: 18, color: color, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
