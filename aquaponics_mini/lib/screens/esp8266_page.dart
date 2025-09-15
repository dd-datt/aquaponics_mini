import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mqtt_service.dart';
import 'dart:convert';

class Esp8266Page extends StatefulWidget {
  const Esp8266Page({super.key});

  @override
  State<Esp8266Page> createState() => _Esp8266PageState();
}

class _Esp8266PageState extends State<Esp8266Page> {
  String status8266 = 'Đang kết nối...';
  String temp = '--';
  String humidity = '--';
  String waterLevel = '--';
  bool pumpOn = false;
  bool lightOn = false;
  bool airOn = false;
  bool pumpRefillOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mqtt = Provider.of<MqttService>(context, listen: false);
      mqtt.connect().then((_) {
        mqtt.listenStatus((msg) {
          if (msg.startsWith('ESP32-CAM:')) return;
          try {
            final decoded = Map<String, dynamic>.from(_parseJson(msg));
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
            if (mounted) {
              setState(() => status8266 = 'Lỗi dữ liệu');
            }
          }
        });
      });
    });
  }

  void _publishSingleCommand(String deviceKey, bool value) {
    final mqtt = Provider.of<MqttService>(context, listen: false);
    final command = '{"$deviceKey":$value}';
    mqtt.publishCmd(command);
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP8266 - Cảm biến & Điều khiển'),
        backgroundColor: const Color.fromARGB(255, 117, 216, 122),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: status8266 == 'Hoạt động'
                  ? Colors.green
                  : status8266.contains('Lỗi')
                  ? Colors.red
                  : Colors.orange,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(
                  status8266 == 'Hoạt động'
                      ? Icons.check_circle
                      : status8266.contains('Lỗi')
                      ? Icons.error
                      : Icons.wifi,
                  color: Colors.white,
                ),
                title: const Text(
                  'ESP8266 (Cảm biến & Điều khiển)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                subtitle: Text('Trạng thái: $status8266', style: TextStyle(color: Colors.white.withOpacity(0.9))),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildInfoChip(Icons.thermostat, '$temp°C', Colors.orange),
                _buildInfoChip(Icons.water_drop, '$humidity%', Colors.blue),
                _buildWaterLevelChip(),
              ],
            ),
            const SizedBox(height: 16),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
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
    return Chip(
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
    );
  }
}
