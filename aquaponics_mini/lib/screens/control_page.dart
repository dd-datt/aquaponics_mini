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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Điều khiển'), backgroundColor: Colors.green[700]),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildControlCard(
              icon: Icons.water,
              title: 'Bơm nước',
              value: pumpOn,
              color: Colors.blue,
              onChanged: (v) => setState(() => pumpOn = v),
            ),
            SizedBox(height: 16),
            _buildControlCard(
              icon: Icons.lightbulb,
              title: 'Đèn chiếu sáng',
              value: lightOn,
              color: Colors.yellow[700]!,
              onChanged: (v) => setState(() => lightOn = v),
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final mqtt = Provider.of<MqttService>(context, listen: false);
                String command = '{"pump":$pumpOn,"light":$lightOn}';
                mqtt.publishCmd(command);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã gửi lệnh: $command')));
              },
              icon: Icon(Icons.send),
              label: Text('Gửi trạng thái điều khiển', style: TextStyle(fontSize: 16)),
            ),
          ],
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
