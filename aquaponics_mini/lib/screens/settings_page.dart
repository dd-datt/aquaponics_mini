import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController mqttController = TextEditingController(text: 'mqtt://broker.hivemq.com');
  final TextEditingController flaskController = TextEditingController(text: 'http://localhost:5000');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Cài đặt'), backgroundColor: Colors.green[700]),
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
                leading: Icon(Icons.cloud, color: Colors.green),
                title: Text('MQTT Server', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: TextField(
                  controller: mqttController,
                  decoration: InputDecoration(border: InputBorder.none),
                  style: TextStyle(color: Colors.green[800]),
                ),
              ),
            ),
            SizedBox(height: 12),
            Card(
              color: Colors.green[50],
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(Icons.api, color: Colors.green),
                title: Text('Flask Server', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: TextField(
                  controller: flaskController,
                  decoration: InputDecoration(border: InputBorder.none),
                  style: TextStyle(color: Colors.green[800]),
                ),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                // TODO: Lưu cấu hình
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã lưu cấu hình!')));
              },
              icon: Icon(Icons.save),
              label: Text('Lưu cấu hình', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
