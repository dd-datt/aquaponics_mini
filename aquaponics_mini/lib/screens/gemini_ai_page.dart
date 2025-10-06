import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiAIPage extends StatefulWidget {
  const GeminiAIPage({super.key});

  @override
  State<GeminiAIPage> createState() => _GeminiAIPageState();
}

class _GeminiAIPageState extends State<GeminiAIPage> {
  // Remove markdown formatting from Gemini output
  String _cleanMarkdown(String text) {
    // Remove common markdown characters and formatting
    final pattern = RegExp(r'(^[*>#\- ]+|[*_~`])', multiLine: true);
    return text.replaceAll(pattern, '');
  }

  final TextEditingController _controller = TextEditingController();
  String _response = '';
  bool _loading = false;

  Future<void> _askGemini(String prompt) async {
    setState(() {
      _loading = true;
      _response = '';
    });
    final apiKey = 'AIzaSyDBtBt-uxJcp9LqV0Em8JFgkfNqbc7MjZk';
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey',
    );
    final body = jsonEncode({
      "contents": [
        {
          "parts": [
            {"text": prompt},
          ],
        },
      ],
    });
    try {
      final res = await http.post(url, headers: {'Content-Type': 'application/json'}, body: body);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? 'No answer.';
        setState(() {
          _response = _cleanMarkdown(text);
        });
      } else {
        setState(() {
          _response = 'Error: ${res.statusCode}\n${res.body}';
        });
      }
    } catch (e) {
      setState(() {
        _response = 'Error: $e';
      });
    }
    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Tư Vấn Gemini'), backgroundColor: const Color.fromARGB(255, 117, 216, 122)),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green[50] ?? Colors.green.shade50, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header với icon và hướng dẫn
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.psychology, color: Colors.green[700], size: 32),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'AI Tư Vấn Thông Minh',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green[700]),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Nhập câu hỏi về cá cánh buồm, cây thủy canh kim ngân, sâu bệnh, tình trạng, giải pháp...'
                          '\nVí dụ: "Cây kim ngân bị vàng lá, phải làm sao?"',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Input field với styling đẹp hơn
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        labelText: 'Câu hỏi tư vấn',
                        hintText: 'Nhập câu hỏi của bạn...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300] ?? Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.green[700] ?? Colors.green.shade700, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300] ?? Colors.grey.shade300),
                        ),
                        labelStyle: TextStyle(color: Colors.green[700]),
                        prefixIcon: Icon(Icons.chat, color: Colors.green[600]),
                      ),
                      minLines: 2,
                      maxLines: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Button với shadow và animation
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: _loading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send, size: 20),
                    label: Text(
                      _loading ? 'Đang xử lý...' : 'Gửi cho AI Gemini',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    onPressed: _loading ? null : () => _askGemini(_controller.text.trim()),
                  ),
                ),
                const SizedBox(height: 24),
                // Loading state với animation đẹp hơn
                if (_loading) ...[
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.green[700] ?? Colors.green.shade700),
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'AI đang suy nghĩ và phân tích...',
                            style: TextStyle(fontSize: 16, color: Colors.green[700], fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (_response.isNotEmpty) ...[
                  // Response card với gradient và animation
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    child: Card(
                      elevation: 6,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.green[300] ?? Colors.green.shade300, width: 1.5),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.white, Colors.green[25] ?? Colors.green.shade50],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green[100],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.lightbulb, color: Colors.green[700], size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Kết quả tư vấn từ AI',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.verified, color: Colors.green[600], size: 20),
                                ],
                              ),
                              Divider(height: 24, thickness: 1.2, color: Colors.green[200] ?? Colors.green.shade200),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[200] ?? Colors.grey.shade200),
                                ),
                                child: Text(
                                  _response,
                                  style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
