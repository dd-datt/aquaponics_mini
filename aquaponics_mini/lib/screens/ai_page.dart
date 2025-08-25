import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

class AIPage extends StatefulWidget {
  const AIPage({super.key});

  @override
  State<AIPage> createState() => _AIPageState();
}

class _AIPageState extends State<AIPage> {
  String imageUrl = 'https://via.placeholder.com/400x250?text=ESP32-CAM';
  String aiLabel = '';
  bool loading = false;

  Future<void> sendImageToServer() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) return;
    setState(() => loading = true);
    final formData = FormData.fromMap({'image': await MultipartFile.fromFile(pickedFile.path, filename: 'image.jpg')});
    try {
      final response = await Dio().post(
        'https://your-ngrok-url.ngrok.io/predict', // Thay bằng URL ngrok của bạn
        data: formData,
      );
      setState(() {
        aiLabel = response.data['result'] ?? '';
        imageUrl = pickedFile.path;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi gửi ảnh: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AI & Ảnh'), backgroundColor: Colors.green[700]),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Stack(
                alignment: Alignment.bottomLeft,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: imageUrl.startsWith('http')
                        ? Image.network(imageUrl, height: 220, width: double.infinity, fit: BoxFit.cover)
                        : Image.asset(imageUrl, height: 220, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.7),
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), topRight: Radius.circular(16)),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kết quả AI:',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          aiLabel.isNotEmpty ? aiLabel : 'Chưa có kết quả',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  if (loading)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black26,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: loading ? null : sendImageToServer,
              icon: Icon(Icons.camera_alt),
              label: Text('Chụp ảnh & gửi lên AI', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
