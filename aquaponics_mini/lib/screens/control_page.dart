import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mqtt_service.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  bool pumpOn = false;
  bool lightOn = false;
  bool airOn = false;
  bool pumpRefillOn = false;
  double feedAngle = 60;
  int feedHoldMs = 700;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Điều khiển'), backgroundColor: Colors.green[700]),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildControlCard(
                      icon: Icons.water,
                      title: 'Bơm lọc',
                      value: pumpOn,
                      color: Colors.blue,
                      onChanged: (v) => setState(() => pumpOn = v),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildControlCard(
                      icon: Icons.lightbulb,
                      title: 'Đèn chiếu sáng',
                      value: lightOn,
                      color: Colors.yellow[700]!,
                      onChanged: (v) => setState(() => lightOn = v),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildControlCard(
                      icon: Icons.air,
                      title: 'Sủi khí',
                      value: airOn,
                      color: Colors.teal,
                      onChanged: (v) => setState(() => airOn = v),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildControlCard(
                      icon: Icons.water_drop,
                      title: 'Bơm thường',
                      value: pumpRefillOn,
                      color: Colors.indigo,
                      onChanged: (v) => setState(() => pumpRefillOn = v),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cho cá ăn (Servo)', style: TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text('Góc quay'),
                                Slider(
                                  value: feedAngle,
                                  min: 0,
                                  max: 180,
                                  divisions: 18,
                                  label: feedAngle.round().toString(),
                                  onChanged: (v) => setState(() => feedAngle = v),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              children: [
                                Text('Giữ (ms)'),
                                Slider(
                                  value: feedHoldMs.toDouble(),
                                  min: 200,
                                  max: 2000,
                                  divisions: 18,
                                  label: feedHoldMs.toString(),
                                  onChanged: (v) => setState(() => feedHoldMs = v.round()),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          final mqtt = Provider.of<MqttService>(context, listen: false);
                          final cmd = '{"feed":{"action":"drop","angle":${feedAngle.round()},"hold_ms":$feedHoldMs}}';
                          mqtt.publishCmd(cmd);
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Đã gửi lệnh cho cá ăn: $cmd')));
                        },
                        icon: Icon(Icons.restaurant),
                        label: Text('Cho cá ăn'),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final mqtt = Provider.of<MqttService>(context, listen: false);
                  String command = '{"pump":$pumpOn,"light":$lightOn,"air":$airOn,"pump_refill":$pumpRefillOn}';
                  mqtt.publishCmd(command);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã gửi lệnh: $command')));
                },
                icon: Icon(Icons.send),
                label: Text('Gửi trạng thái điều khiển', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlCard({
    required IconData icon,
    required String title,
    required bool value,
    required Color color,
    required ValueChanged<bool> onChanged,
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
        trailing: Switch(value: value, activeColor: color, onChanged: onChanged),
      ),
    );
  }
}
