import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mqtt_service.dart';

class WifiSettingPage extends StatefulWidget {
  const WifiSettingPage({super.key});

  @override
  State<WifiSettingPage> createState() => _WifiSettingPageState();
}

class _WifiSettingPageState extends State<WifiSettingPage> {
  final _formKey32 = GlobalKey<FormState>();
  final _formKey8266 = GlobalKey<FormState>();
  final _ssid32Controller = TextEditingController();
  final _pass32Controller = TextEditingController();
  final _ssid8266Controller = TextEditingController();
  final _pass8266Controller = TextEditingController();
  bool _isSending32 = false;
  bool _isSending8266 = false;

  @override
  void dispose() {
    _ssid32Controller.dispose();
    _pass32Controller.dispose();
    _ssid8266Controller.dispose();
    _pass8266Controller.dispose();
    super.dispose();
  }

  void _sendWifiChange32() async {
    if (!_formKey32.currentState!.validate()) return;
    setState(() => _isSending32 = true);
    final mqtt = Provider.of<MqttService>(context, listen: false);
    final ssid = _ssid32Controller.text.trim();
    final pass = _pass32Controller.text.trim();
    final cmd = '{"wifi":{"ssid":"$ssid","pass":"$pass"}}';
    mqtt.publishCameraCmd(cmd);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _isSending32 = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi lệnh đổi WiFi đến ESP32-CAM!')));
  }

  void _sendWifiChange8266() async {
    if (!_formKey8266.currentState!.validate()) return;
    setState(() => _isSending8266 = true);
    final mqtt = Provider.of<MqttService>(context, listen: false);
    final ssid = _ssid8266Controller.text.trim();
    final pass = _pass8266Controller.text.trim();
    final cmd = '{"wifi":{"ssid":"$ssid","pass":"$pass"}}';
    mqtt.publishCmd(cmd);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _isSending8266 = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi lệnh đổi WiFi đến ESP8266!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt WiFi thiết bị'), backgroundColor: Color.fromARGB(255, 117, 216, 122)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Color.fromARGB(255, 142, 199, 154),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey32,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.camera_alt, color: Color.fromARGB(255, 0, 0, 0)),
                            const SizedBox(width: 8),
                            const Text(
                              'ESP32-CAM',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(255, 0, 0, 0),
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _ssid32Controller,
                          decoration: const InputDecoration(labelText: 'WiFi SSID', border: OutlineInputBorder()),
                          validator: (v) => v == null || v.isEmpty ? 'Nhập SSID' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _pass32Controller,
                          decoration: const InputDecoration(labelText: 'WiFi Password', border: OutlineInputBorder()),
                          obscureText: true,
                          validator: (v) => v == null || v.isEmpty ? 'Nhập mật khẩu' : null,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.send),
                          label: Text(_isSending32 ? 'Đang gửi...' : 'Đổi WiFi'),
                          onPressed: _isSending32 ? null : _sendWifiChange32,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                color: Color.fromARGB(255, 142, 199, 154),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey8266,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.memory, color: Color.fromARGB(255, 0, 0, 0)),
                            const SizedBox(width: 8),
                            const Text(
                              'ESP8266',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(255, 0, 0, 0),
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _ssid8266Controller,
                          decoration: const InputDecoration(labelText: 'WiFi SSID', border: OutlineInputBorder()),
                          validator: (v) => v == null || v.isEmpty ? 'Nhập SSID' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _pass8266Controller,
                          decoration: const InputDecoration(labelText: 'WiFi Password', border: OutlineInputBorder()),
                          obscureText: true,
                          validator: (v) => v == null || v.isEmpty ? 'Nhập mật khẩu' : null,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.send),
                          label: Text(_isSending8266 ? 'Đang gửi...' : 'Đổi WiFi'),
                          onPressed: _isSending8266 ? null : _sendWifiChange8266,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
