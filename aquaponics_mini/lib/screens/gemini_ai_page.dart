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
      appBar: AppBar(title: const Text('AI Tư Vấn Gemini')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nhập câu hỏi về cá cánh buồm, cây thủy canh kim ngân, sâu bệnh, tình trạng, giải pháp...'
                '\nVí dụ: "Cây kim ngân bị vàng lá, phải làm sao?"',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(labelText: 'Câu hỏi tư vấn', border: OutlineInputBorder()),
                minLines: 1,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: const Text('Gửi cho AI Gemini'),
                onPressed: _loading ? null : () => _askGemini(_controller.text.trim()),
              ),
              const SizedBox(height: 24),
              if (_loading) ...[
                const Center(child: CircularProgressIndicator()),
              ] else if (_response.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Card(
                    elevation: 3,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.green.shade200, width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lightbulb, color: Colors.green[700], size: 28),
                              const SizedBox(width: 10),
                              Text(
                                'Kết quả tư vấn',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green[700]),
                              ),
                            ],
                          ),
                          const Divider(height: 24, thickness: 1.2),
                          Text(_response, style: const TextStyle(fontSize: 16, height: 1.5)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
