import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryService {
  static const String _predictionHistoryKey = 'prediction_history';
  static const int _maxHistoryItems = 50; // Giữ tối đa 50 items

  // Lấy lịch sử từ SharedPreferences
  Future<List<Map<String, dynamic>>> getPredictionHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_predictionHistoryKey);

      if (historyJson != null) {
        final List<dynamic> historyList = jsonDecode(historyJson);
        return historyList.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      print('Error getting prediction history: $e');
    }
    return [];
  }

  // Thêm kết quả AI mới vào lịch sử
  Future<void> addPredictionResult({required String result, String? confidence, String? imageBase64}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentHistory = await getPredictionHistory();

      // Tạo item mới
      final newItem = {
        'result': result,
        'confidence': confidence,
        'timestamp': DateTime.now().toIso8601String(),
        'imageBase64': imageBase64, // Lưu ảnh nếu có
      };

      // Thêm vào đầu danh sách (mới nhất trước)
      currentHistory.insert(0, newItem);

      // Giữ tối đa _maxHistoryItems items
      if (currentHistory.length > _maxHistoryItems) {
        currentHistory.removeRange(_maxHistoryItems, currentHistory.length);
      }

      // Lưu lại
      final historyJson = jsonEncode(currentHistory);
      await prefs.setString(_predictionHistoryKey, historyJson);

      print('✅ Đã lưu kết quả AI vào lịch sử: $result');
    } catch (e) {
      print('Error adding prediction result: $e');
    }
  }

  // Xóa toàn bộ lịch sử
  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_predictionHistoryKey);
      print('✅ Đã xóa toàn bộ lịch sử');
    } catch (e) {
      print('Error clearing history: $e');
    }
  }

  // Xóa 1 item theo index
  Future<void> removeHistoryItem(int index) async {
    try {
      final currentHistory = await getPredictionHistory();
      if (index >= 0 && index < currentHistory.length) {
        currentHistory.removeAt(index);

        final prefs = await SharedPreferences.getInstance();
        final historyJson = jsonEncode(currentHistory);
        await prefs.setString(_predictionHistoryKey, historyJson);

        print('✅ Đã xóa item tại index $index');
      }
    } catch (e) {
      print('Error removing history item: $e');
    }
  }

  // Lấy thống kê lịch sử
  Future<Map<String, dynamic>> getHistoryStats() async {
    final history = await getPredictionHistory();

    int healthyCount = 0;
    int diseaseCount = 0;
    int warningCount = 0;

    for (final item in history) {
      final result = item['result']?.toString().toLowerCase() ?? '';
      if (result.contains('healthy') || result.contains('tốt')) {
        healthyCount++;
      } else if (result.contains('disease') || result.contains('bệnh')) {
        diseaseCount++;
      } else if (result.contains('warning') || result.contains('cảnh báo')) {
        warningCount++;
      }
    }

    return {
      'total': history.length,
      'healthy': healthyCount,
      'disease': diseaseCount,
      'warning': warningCount,
      'healthyPercent': history.isNotEmpty ? (healthyCount * 100 / history.length).round() : 0,
    };
  }
}
