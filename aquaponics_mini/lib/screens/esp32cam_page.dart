import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/mqtt_service.dart';
import 'dart:convert';
import 'dart:typed_data';

class Esp32CamPage extends StatefulWidget {
  const Esp32CamPage({super.key});

  @override
  State<Esp32CamPage> createState() => _Esp32CamPageState();
}

class _Esp32CamPageState extends State<Esp32CamPage> {
  String status32cam = 'Đang kết nối...';
  Uint8List? imageBytes;
  bool isLoadingImage = false;
  String aiLabel = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mqtt = Provider.of<MqttService>(context, listen: false);
      mqtt.connect().then((_) {
        mqtt.listenStatus((msg) {
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

  @override
  Widget build(BuildContext context) {
    final mqtt = Provider.of<MqttService>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('ESP32-CAM - Camera'), backgroundColor: Colors.blue),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: status32cam.contains('Hoạt động')
                  ? Colors.green
                  : status32cam.contains('Lỗi')
                  ? Colors.red
                  : Colors.orange,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white),
                title: const Text(
                  'ESP32-CAM (Camera)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                subtitle: Text('Trạng thái: $status32cam', style: TextStyle(color: Colors.white.withOpacity(0.9))),
              ),
            ),
            const SizedBox(height: 16),
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
          ],
        ),
      ),
    );
  }
}
