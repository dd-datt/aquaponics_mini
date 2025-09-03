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
        print('[MQTT DEBUG] Nhận dữ liệu: $msg');
        try {
          final data = msg.contains('{') ? msg : '{}';
          final decoded = data.isNotEmpty ? Map<String, dynamic>.from(_parseJson(data)) : {};
          print('[MQTT DEBUG] Đã parse: $decoded');
          setState(() {
            temp = decoded['temp']?.toString() ?? '--';
            humidity = decoded['humidity']?.toString() ?? '--';

            // Xử lý water level một cách an toàn
            var waterData = decoded['water'];
            if (waterData != null) {
              if (waterData is String) {
                waterLevel = waterData;
              } else if (waterData is bool) {
                waterLevel = waterData ? 'FULL' : 'LOW';
              } else {
                waterLevel = waterData.toString();
              }
            } else {
              waterLevel = '--';
            }

            pumpOn = decoded['pump'] ?? false;
            lightOn = decoded['light'] ?? false;
            status = 'Hoạt động';
          });
        } catch (e) {
          print('Error parsing MQTT message: $e');
          if (mounted) {
            setState(() {
              status = 'Lỗi dữ liệu';
            });
          }
        }
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
              color: _getStatusColor(),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(_getStatusIcon(), color: Colors.white),
                title: Text(
                  'Aquaponics Mini',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                subtitle: Text('Trạng thái: $status', style: TextStyle(color: Colors.white.withOpacity(0.9))),
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildInfoChip(Icons.thermostat, '$temp°C', Colors.orange),
                _buildInfoChip(Icons.water_drop, '$humidity%', Colors.blue),
                _buildWaterLevelChip(),
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
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 14, // Tăng từ mặc định lên 14
          fontFamily: 'Roboto',
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 2,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
  }

  Color _getStatusColor() {
    if (status.contains('Hoạt động')) {
      return Colors.green[600]!;
    } else if (status.contains('Lỗi')) {
      return Colors.red[600]!;
    } else if (status.contains('Đang kết nối')) {
      return Colors.orange[600]!;
    } else {
      return Colors.grey[600]!;
    }
  }

  IconData _getStatusIcon() {
    if (status.contains('Hoạt động')) {
      return Icons.check_circle;
    } else if (status.contains('Lỗi')) {
      return Icons.error;
    } else if (status.contains('Đang kết nối')) {
      return Icons.wifi;
    } else {
      return Icons.help;
    }
  }

  String _getWaterLevelTooltip(String displayText) {
    if (displayText.contains('Chưa có dữ liệu')) {
      return 'Đang chờ dữ liệu từ cảm biến mực nước';
    } else if (displayText.contains('Nước đầy')) {
      return 'Mức nước an toàn - hệ thống hoạt động bình thường';
    } else if (displayText.contains('Nước thấp')) {
      return 'Cần thêm nước để tránh hỏng bơm và đảm bảo tưới tiêu';
    } else {
      return 'Trạng thái mực nước: $displayText';
    }
  }

  Widget _buildWaterLevelChip() {
    // Xác định màu sắc và icon dựa trên trạng thái nước
    Color chipColor;
    IconData waterIcon;
    String displayText;

    String normalized = waterLevel.toString().toLowerCase().trim();

    if (normalized == '--' || normalized.isEmpty) {
      chipColor = Colors.grey;
      waterIcon = Icons.help_outline;
      displayText = 'NO DATA';
    } else if (normalized.contains('full') ||
        normalized.contains('đầy') ||
        normalized.contains('high') ||
        normalized == 'true' ||
        normalized == '1') {
      chipColor = Colors.blue[600]!;
      waterIcon = Icons.water;
      displayText = 'FULL';
    } else if (normalized.contains('low') ||
        normalized.contains('thấp') ||
        normalized.contains('empty') ||
        normalized == 'false' ||
        normalized == '0') {
      chipColor = Colors.orange[600]!;
      waterIcon = Icons.water_drop_outlined;
      displayText = 'LOW';
    } else {
      // Tất cả trường hợp không xác định được => hiển thị NO DATA
      chipColor = Colors.grey;
      waterIcon = Icons.help_outline;
      displayText = 'NO DATA';
    }

    return Tooltip(
      message: _getWaterLevelTooltip(displayText),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        child: Chip(
          avatar: CircleAvatar(
            backgroundColor: chipColor.withOpacity(0.2),
            child: Icon(waterIcon, color: chipColor, size: 20),
          ),
          label: Text(
            displayText,
            style: TextStyle(color: chipColor, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Roboto'),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          backgroundColor: Colors.white,
          elevation: 3,
          shadowColor: chipColor.withOpacity(0.3),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
      ),
    );
  }
}
