import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:http/http.dart' as http;

class VideoAIPage extends StatefulWidget {
  final String mjpegUrl;
  final String aiApiUrl;
  const VideoAIPage({required this.mjpegUrl, required this.aiApiUrl, super.key});

  @override
  State<VideoAIPage> createState() => _VideoAIPageState();
}

class _VideoAIPageState extends State<VideoAIPage> {
  String aiResult = '';
  Timer? _aiTimer;

  @override
  void initState() {
    super.initState();
    // Định kỳ lấy kết quả AI từ Flask server mỗi 3 giây
    _aiTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchAIResult();
    });
  }

  @override
  void dispose() {
    _aiTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAIResult() async {
    try {
      final response = await http.get(Uri.parse('${widget.aiApiUrl}/last-prediction'));
      if (response.statusCode == 200) {
        setState(() {
          aiResult = response.body;
        });
      } else {
        setState(() {
          aiResult = 'AI error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        aiResult = 'AI error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video + AI Real-time')),
      body: Column(
        children: [
          Expanded(
            child: Mjpeg(
              stream: widget.mjpegUrl,
              isLive: true,
              error: (context, error, stack) => Center(child: Text('Stream error: $error')),
            ),
          ),
          Container(
            color: Colors.black87,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            child: Text('AI result: $aiResult', style: const TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
