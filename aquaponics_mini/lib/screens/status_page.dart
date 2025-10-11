import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mqtt_service.dart';
import '../services/history_service.dart';

class StatusPage extends StatefulWidget {
  const StatusPage({super.key});

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  List<Map<String, dynamic>> predictionHistory = [];
  bool isLoadingHistory = false;
  Map<String, dynamic> historyStats = {};

  @override
  void initState() {
    super.initState();
    _loadPredictionHistory();
    _loadHistoryStats();
  }

  Future<void> _loadHistoryStats() async {
    final historyService = HistoryService();
    final stats = await historyService.getHistoryStats();
    setState(() {
      historyStats = stats;
    });
  }

  Future<void> _loadPredictionHistory() async {
    setState(() => isLoadingHistory = true);

    // 🔄 SỬ DỤNG HISTORY SERVICE THAY VÌ API
    final historyService = HistoryService();
    try {
      final history = await historyService.getPredictionHistory();
      print('📊 [DEBUG] Loaded ${history.length} history items from local storage');
      setState(() {
        predictionHistory = history.take(10).toList(); // Lấy 10 items mới nhất
        isLoadingHistory = false;
      });
      // Cập nhật stats sau khi load history
      await _loadHistoryStats();
    } catch (e) {
      setState(() => isLoadingHistory = false);
      print('❌ [ERROR] Error loading prediction history: $e');
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa lịch sử'),
        content: const Text('Bạn có chắc muốn xóa toàn bộ lịch sử phân tích AI?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final historyService = HistoryService();
      await historyService.clearHistory();
      await _loadPredictionHistory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Đã xóa toàn bộ lịch sử')));
      }
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return 'N/A';
    try {
      final dateTime = DateTime.parse(timestamp);
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }

  Color _getResultColor(String result) {
    final lower = result.toLowerCase();
    if (lower.contains('healthy') || lower.contains('tốt')) {
      return Colors.green;
    } else if (lower.contains('disease') || lower.contains('bệnh')) {
      return Colors.red;
    } else if (lower.contains('warning') || lower.contains('cảnh báo')) {
      return Colors.orange;
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final mqtt = Provider.of<MqttService>(context);

    String temp = '--';
    String humidity = '--';
    String waterLevel = '--';
    if (mqtt.lastData != null) {
      final data = mqtt.lastData;
      if (data is Map<String, dynamic>) {
        temp = data['temp']?.toString() ?? '--';
        humidity = data['humidity']?.toString() ?? '--';
        if (data.containsKey('water')) {
          final waterData = data['water'];
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
          }
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Trạng thái hệ thống'), backgroundColor: Colors.green[700]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSensorCard(
              icon: Icons.thermostat,
              title: 'Nhiệt độ',
              value: temp != '--' ? '$temp°C' : '--',
              color: Colors.orange,
              description: 'Nhiệt độ nước hiện tại',
            ),
            _buildSensorCard(
              icon: Icons.water_drop,
              title: 'Độ ẩm',
              value: humidity != '--' ? '$humidity%' : '--',
              color: Colors.blue,
              description: 'Độ ẩm không khí',
            ),
            _buildSensorCard(
              icon: Icons.waves,
              title: 'Mức nước',
              value: waterLevel,
              color: Colors.teal,
              description: 'Mức nước bể',
            ),
            Card(
              color: Colors.green[50],
              child: ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.green),
                title: const Text('ESP32-CAM'),
                subtitle: Text(mqtt.status.isNotEmpty ? mqtt.status : 'Chưa có trạng thái'),
              ),
            ),

            // Card lịch sử phân tích AI
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                leading: const Icon(Icons.history, color: Colors.purple),
                title: const Text('Lịch sử phân tích AI', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${predictionHistory.length} kết quả gần đây'),
                    if (historyStats.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.check_circle, size: 12, color: Colors.green),
                          Text(' ${historyStats['healthy'] ?? 0}', style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 8),
                          Icon(Icons.warning, size: 12, color: Colors.red),
                          Text(' ${historyStats['disease'] ?? 0}', style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 8),
                          Text(
                            '(${historyStats['healthyPercent'] ?? 0}% khỏe mạnh)',
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                trailing: isLoadingHistory
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: predictionHistory.isNotEmpty ? _clearHistory : null,
                            tooltip: 'Xóa toàn bộ lịch sử',
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _loadPredictionHistory,
                            tooltip: 'Làm mới lịch sử',
                          ),
                        ],
                      ),
                children: [
                  if (isLoadingHistory)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (predictionHistory.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'Chưa có dữ liệu lịch sử phân tích',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'DEBUG: Hãy vào Dashboard và bấm "TEST: Lưu lịch sử"',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  else
                    ...predictionHistory.map((prediction) {
                      final result = prediction['result']?.toString() ?? 'N/A';
                      final timestamp = prediction['timestamp']?.toString();
                      final confidence = prediction['confidence']?.toString();

                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 12,
                          backgroundColor: _getResultColor(result).withOpacity(0.2),
                          child: Icon(
                            result.toLowerCase().contains('healthy')
                                ? Icons.check_circle_outline
                                : result.toLowerCase().contains('disease')
                                ? Icons.warning_outlined
                                : Icons.help_outline,
                            size: 16,
                            color: _getResultColor(result),
                          ),
                        ),
                        title: Text(
                          result,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _getResultColor(result)),
                        ),
                        subtitle: Row(
                          children: [
                            Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(_formatTimestamp(timestamp), style: const TextStyle(fontSize: 12)),
                            if (confidence != null) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.percent, size: 12, color: Colors.grey[600]),
                              const SizedBox(width: 2),
                              Text(confidence, style: const TextStyle(fontSize: 12)),
                            ],
                          ],
                        ),
                        trailing: Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
                      );
                    }),
                ],
              ),
            ),

            Card(
              color: Colors.red[50],
              child: ListTile(
                leading: const Icon(Icons.warning, color: Colors.red),
                title: const Text('Cảnh báo'),
                subtitle: const Text('Không có cảnh báo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required String description,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: Text(
          value,
          style: TextStyle(fontSize: 18, color: color, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
