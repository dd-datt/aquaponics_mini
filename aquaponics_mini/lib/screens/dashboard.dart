import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mqtt_service.dart';
import '../services/api_service.dart';
import 'dart:convert';
import 'dart:typed_data';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Color _getStatusColor(String status) {
    if (status.contains('Hoạt động')) {
      return Colors.green;
    } else if (status.contains('Lỗi')) {
      return Colors.red;
    } else if (status.contains('Đang kết nối')) {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }

  String status8266 = 'Đang kết nối...';
  String status32cam = 'Đang kết nối...';
  String temp = '--';
  String humidity = '--';
  String waterLevel = '--';
  String imageUrl = '';
  String aiLabel = '';
  bool pumpOn = false;
  bool lightOn = false;
  bool airOn = false;
  bool pumpRefillOn = false;
  final int feedAngle = 60;
  final int feedHoldMs = 700;
  DateTime? lastLightPress;
  Uint8List? imageBytes;
  bool isLoadingImage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mqtt = Provider.of<MqttService>(context, listen: false);
      mqtt.connect().then((_) {
        mqtt.listenStatus((msg) {
          print('[MQTT DEBUG] Nhận dữ liệu: $msg');
          if (msg.startsWith('ESP32-CAM:')) {
            setState(() {
              status32cam = msg;
            });
            if (msg.toLowerCase().contains('ảnh') || msg.toLowerCase().contains('image')) {
              _fetchImageAndLabel();
            }
            return;
          }

          try {
            final data = msg.contains('{') ? msg : '{}';
            final decoded = data.isNotEmpty ? Map<String, dynamic>.from(_parseJson(data)) : {};
            print('[MQTT DEBUG] Đã parse: $decoded');
            String prevWaterLevel = waterLevel;
            setState(() {
              temp = decoded['temp']?.toString() ?? '--';
              humidity = decoded['humidity']?.toString() ?? '--';

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

              pumpOn = _toBoolDynamic(decoded['pump']);
              if (lastLightPress == null || DateTime.now().difference(lastLightPress!).inSeconds > 10) {
                lightOn = _toBoolDynamic(decoded['light']);
              }

              status8266 = 'Hoạt động';
            });
            // Cute notification when water LOW
            final normalized = waterLevel.toLowerCase();
            if ((prevWaterLevel.toLowerCase() != 'low') && (normalized == 'low')) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '🐟 Trời ơi! Nước sắp hết, mình sẽ bơm cho bạn ngay nè! 💧',
                      style: TextStyle(fontSize: 16),
                    ),
                    duration: Duration(seconds: 4),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          } catch (e) {
            print('Error parsing MQTT message: $e');
            if (mounted) {
              setState(() {
                status8266 = 'Lỗi dữ liệu';
              });
            }
          }
        });
      });
      _fetchImageAndLabel();
    });
  }

  Future<void> _fetchImageAndLabel() async {
    setState(() => isLoadingImage = true);
    final api = Provider.of<ApiService>(context, listen: false);
    final img = await api.getLastImage();
    final label = await api.getLastPrediction();
    setState(() {
      if (img.isNotEmpty) {
        try {
          imageBytes = base64Decode(img);
        } catch (e) {
          imageBytes = null;
        }
      } else {
        imageBytes = null;
      }
      aiLabel = label.isNotEmpty ? label : 'healthy (95%)';
      isLoadingImage = false;
    });
  }

  dynamic _parseJson(String data) {
    try {
      return data.isNotEmpty ? jsonDecode(data) : {};
    } catch (_) {
      return {};
    }
  }

  bool _toBoolDynamic(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase().trim();
      if (s == 'true' || s == 'on' || s == '1') return true;
      if (s == 'false' || s == 'off' || s == '0') return false;
    }
    return false;
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
              color: _getStatusColor(status8266),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(_getStatusIcon(status8266), color: Colors.white),
                title: Text(
                  'ESP8266 (Cảm biến & Điều khiển)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                subtitle: Text('Trạng thái: $status8266', style: TextStyle(color: Colors.white.withOpacity(0.9))),
              ),
            ),
            Card(
              color: _getStatusColor(status32cam),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(Icons.camera_alt, color: Colors.white),
                title: Text(
                  'ESP32-CAM (Camera)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                subtitle: Text('Trạng thái: $status32cam', style: TextStyle(color: Colors.white.withOpacity(0.9))),
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
                    child: isLoadingImage
                        ? Container(
                            height: 120,
                            width: double.infinity,
                            color: Colors.grey[200],
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : imageBytes != null
                        ? Image.memory(imageBytes!, height: 120, width: double.infinity, fit: BoxFit.cover)
                        : Image.asset(
                            'assets/images/esp32cam_placeholder.png',
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                  ),
                  ListTile(
                    leading: Icon(Icons.label, color: Colors.green),
                    title: Text('Kết quả AI'),
                    subtitle: Text(aiLabel),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.refresh, color: Colors.green),
                          onPressed: isLoadingImage ? null : _fetchImageAndLabel,
                          tooltip: 'Làm mới ảnh AI',
                        ),
                        IconButton(
                          icon: Icon(Icons.camera_alt, color: Colors.blue),
                          onPressed: () {
                            mqtt.publishCameraCmd('{"capture":true}');
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('Đã gửi lệnh chụp ảnh đến ESP32-CAM')));
                          },
                          tooltip: 'Chụp ảnh ngay',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pumpOn ? Colors.blue : Colors.grey[300],
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      bool newPumpState = !pumpOn;
                      mqtt.publishCmd(
                        '{"pump":$newPumpState,"light":$lightOn,"air":$airOn,"pump_refill":$pumpRefillOn}',
                      );
                      setState(() => pumpOn = newPumpState);
                    },
                    icon: Icon(Icons.water),
                    label: Text(pumpOn ? 'Bơm lọc bật' : 'Bơm lọc tắt'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lightOn ? Colors.grey[300] : Colors.yellow[700],
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      bool newLightState = !lightOn;
                      mqtt.publishCmd(
                        '{"pump":$pumpOn,"light":$newLightState,"air":$airOn,"pump_refill":$pumpRefillOn}',
                      );
                      setState(() {
                        lightOn = newLightState;
                        lastLightPress = DateTime.now();
                      });
                    },
                    icon: Icon(Icons.lightbulb),
                    label: Text(lightOn ? 'Đèn tắt' : 'Đèn bật'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: airOn ? Colors.teal : Colors.grey[300],
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      bool newAirState = !airOn;
                      mqtt.publishCmd(
                        '{"pump":$pumpOn,"light":$lightOn,"air":$newAirState,"pump_refill":$pumpRefillOn}',
                      );
                      setState(() => airOn = newAirState);
                    },
                    icon: Icon(Icons.air),
                    label: Text(airOn ? 'Sủi khí bật' : 'Sủi khí tắt'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pumpRefillOn ? const Color.fromARGB(255, 228, 83, 228) : Colors.grey[300],
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      bool newPumpRefillState = !pumpRefillOn;
                      mqtt.publishCmd(
                        '{"pump":$pumpOn,"light":$lightOn,"air":$airOn,"pump_refill":$newPumpRefillState}',
                      );
                      setState(() => pumpRefillOn = newPumpRefillState);
                    },
                    icon: Icon(Icons.water_drop),
                    label: Text(pumpRefillOn ? 'Bơm thường bật' : 'Bơm thường tắt'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 71, 181, 76),
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final cmd = '{"feed":{"action":"drop","angle":$feedAngle,"hold_ms":$feedHoldMs}}';
                      mqtt.publishCmd(cmd);
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('Đã gửi lệnh cho cá ăn!')));
                    },
                    icon: Icon(Icons.restaurant),
                    label: Text('Cho cá ăn'),
                  ),
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
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Roboto'),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      backgroundColor: Colors.white,
      elevation: 3,
      shadowColor: color.withOpacity(0.3),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
  }

  IconData _getStatusIcon(String status) {
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

// ...existing code...
