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
  // ---------------- UI helpers ----------------
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

  // ---------------- States ----------------
  String status8266 = 'Đang kết nối...';
  String status32cam = 'Đang kết nối...';
  String temp = '--';
  String humidity = '--';
  String waterLevel = '--';
  String aiLabel = '';
  bool pumpOn = false;
  bool lightOn = false;
  bool airOn = false;
  bool pumpRefillOn = false; // hiển thị trạng thái, không điều khiển
  final int feedAngle = 60;
  final int feedHoldMs = 700;

  // 🔥 KHÔNG CẦN lastPress - mỗi nút hoạt động hoàn toàn độc lập

  Uint8List? imageBytes;
  bool isLoadingImage = false;

  // ---------------- Lifecycle ----------------
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mqtt = Provider.of<MqttService>(context, listen: false);
      mqtt.connect().then((_) {
        mqtt.listenStatus((msg) {
          // ignore: avoid_print
          print('[MQTT DEBUG] Nhận dữ liệu: $msg');

          // ESP32-CAM message
          if (msg.startsWith('ESP32-CAM:')) {
            final content = msg.substring('ESP32-CAM:'.length).trim();
            if (mounted) {
              setState(() {
                status32cam = content;
              });
            }
            final lower = msg.toLowerCase();
            if (lower.contains('ảnh') || lower.contains('image')) {
              _fetchImageAndLabel();
            }
            return;
          }

          // Parse JSON trong chuỗi
          try {
            final decoded = Map<String, dynamic>.from(_parseJson(msg));
            // ignore: avoid_print
            print('[MQTT DEBUG] Đã parse: $decoded');

            final prevWaterLevel = waterLevel;

            if (mounted) {
              setState(() {
                temp = decoded['temp']?.toString() ?? '--';
                humidity = decoded['humidity']?.toString() ?? '--';

                final waterData = decoded['water'];
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
                } else {
                  waterLevel = '--';
                }

                // 🔥 CÁC NÚT HOÀN TOÀN ĐỘC LẬP - CHỈ THAY ĐỔI KHI USER BẤM
                // KHÔNG tự động cập nhật từ MQTT status để tránh xung đột
                // Mỗi nút chỉ on/off theo lệnh trực tiếp từ user

                // Chỉ hiển thị pump_refill (tự động) từ ESP8266
                pumpRefillOn = _toBoolDynamic(decoded['pump_refill']);
                status8266 = 'Hoạt động';
              });
            }

            if (prevWaterLevel.toLowerCase() != 'low' && waterLevel.toLowerCase() == 'low') {
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
            // ignore: avoid_print
            print('Error parsing MQTT message: $e');
            if (mounted) {
              setState(() => status8266 = 'Lỗi dữ liệu');
            }
          }
        });
      });

      _fetchImageAndLabel();
    });
  }

  // ---------------- Networking helpers ----------------
  Future<void> _fetchImageAndLabel() async {
    setState(() => isLoadingImage = true);
    final api = Provider.of<ApiService>(context, listen: false);
    final img = await api.getLastImage();
    final label = await api.getLastPrediction();

    setState(() {
      if (img.isNotEmpty) {
        try {
          imageBytes = base64Decode(img);
        } catch (_) {
          imageBytes = null;
        }
      } else {
        imageBytes = null;
      }
      aiLabel = label.isNotEmpty ? label : 'healthy (95%)';
      isLoadingImage = false;
    });
  }

  /// Gửi lệnh đơn giản cho RIÊNG TỪNG thiết bị - KHÔNG ảnh hưởng thiết bị khác
  void _publishSingleCommand(String deviceKey, bool value) {
    final mqtt = Provider.of<MqttService>(context, listen: false);
    final command = '{"$deviceKey":$value}';
    print('🚀 [INDEPENDENT] Sending: $command (Only affects $deviceKey)');
    mqtt.publishCmd(command);
  }

  // ---------------- Utils ----------------
  dynamic _parseJson(String data) {
    try {
      final start = data.indexOf('{');
      final end = data.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        final jsonStr = data.substring(start, end + 1);
        return jsonDecode(jsonStr);
      }
    } catch (_) {}
    return {};
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

  // ---------------- Build ----------------
  @override
  Widget build(BuildContext context) {
    final mqtt = Provider.of<MqttService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Aquaponics Mini'), backgroundColor: const Color.fromARGB(255, 117, 216, 122)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ESP8266 status
            Card(
              color: _getStatusColor(status8266),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(_getStatusIcon(status8266), color: Colors.white),
                title: const Text(
                  'ESP8266 (Cảm biến & Điều khiển)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                subtitle: Text('Trạng thái: $status8266', style: TextStyle(color: Colors.white.withOpacity(0.9))),
              ),
            ),

            // ESP32-CAM status
            Card(
              color: _getStatusColor(status32cam),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: const ListTile(
                leading: Icon(Icons.camera_alt, color: Colors.white),
                title: Text(
                  'ESP32-CAM (Camera)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Text('Trạng thái: $status32cam', style: TextStyle(color: Colors.black.withOpacity(0.6))),
            ),

            const SizedBox(height: 8),

            // Chips info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildInfoChip(Icons.thermostat, '$temp°C', Colors.orange),
                _buildInfoChip(Icons.water_drop, '$humidity%', Colors.blue),
                _buildWaterLevelChip(),
              ],
            ),

            const SizedBox(height: 16),

            // Card AI image + actions
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: isLoadingImage
                        ? Container(
                            height: 120,
                            width: double.infinity,
                            color: Colors.grey[200],
                            child: const Center(child: CircularProgressIndicator()),
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
                    leading: const Icon(Icons.label, color: Colors.green),
                    title: const Text('Kết quả AI'),
                    subtitle: Text(aiLabel),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.green),
                          onPressed: isLoadingImage ? null : _fetchImageAndLabel,
                          tooltip: 'Làm mới ảnh AI',
                        ),
                        IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.blue),
                          onPressed: () {
                            mqtt.publishCameraCmd('{"capture":true}');
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(const SnackBar(content: Text('Đã gửi lệnh chụp ảnh đến ESP32-CAM')));
                          },
                          tooltip: 'Chụp ảnh ngay',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Row: Pump + Light
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pumpOn ? Colors.blue : Colors.grey[300],
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      // 🔥 HOÀN TOÀN ĐỘC LẬP - chỉ toggle trạng thái local + gửi lệnh
                      final newPump = !pumpOn;
                      _publishSingleCommand('pump', newPump);
                      setState(() {
                        pumpOn = newPump;
                      });
                    },
                    icon: const Icon(Icons.water),
                    label: Text(pumpOn ? 'Bơm lọc BẬT' : 'Bơm lọc TẮT'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lightOn ? Colors.yellow[700] : Colors.grey[300],
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      // 🔥 HOÀN TOÀN ĐỘC LẬP - chỉ toggle trạng thái local + gửi lệnh
                      final newLight = !lightOn;
                      _publishSingleCommand('light', newLight);
                      setState(() {
                        lightOn = newLight;
                      });
                    },
                    icon: const Icon(Icons.lightbulb),
                    label: Text(lightOn ? 'Đèn LED BẬT' : 'Đèn LED TẮT'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Row: Air + Pump refill (display only)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: airOn ? Colors.teal : Colors.grey[300],
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      // 🔥 HOÀN TOÀN ĐỘC LẬP - chỉ toggle trạng thái local + gửi lệnh
                      final newAir = !airOn;
                      _publishSingleCommand('air', newAir);
                      setState(() {
                        airOn = newAir;
                      });
                    },
                    icon: const Icon(Icons.air),
                    label: Text(airOn ? 'Sủi khí BẬT' : 'Sủi khí TẮT'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: pumpRefillOn ? const Color.fromARGB(255, 228, 83, 228) : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.water_drop, color: pumpRefillOn ? Colors.white : Colors.black),
                        const SizedBox(width: 8),
                        Text(
                          pumpRefillOn ? 'Bơm thường BẬT' : 'Bơm thường TẮT',
                          style: TextStyle(
                            color: pumpRefillOn ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Feed button
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 71, 181, 76),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final cmd = '{"feed":{"action":"drop","angle":$feedAngle,"hold_ms":$feedHoldMs}}';
                      mqtt.publishCmd(cmd);
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('Đã gửi lệnh cho cá ăn!')));
                    },
                    icon: const Icon(Icons.restaurant),
                    label: const Text('Cho cá ăn'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Small UI components ----------------
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
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
    Color chipColor;
    IconData waterIcon;
    String displayText;

    final normalized = waterLevel.toString().toLowerCase().trim();

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
      chipColor = Colors.grey;
      waterIcon = Icons.help_outline;
      displayText = 'NO DATA';
    }

    return Tooltip(
      message: _getWaterLevelTooltip(displayText),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
      ),
    );
  }
}
