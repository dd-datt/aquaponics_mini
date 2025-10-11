import 'dart:io';
import '../aquaponics_mini/lib/services/history_service.dart';

// Test HistoryService
void main() async {
  final historyService = HistoryService();

  print('🧪 Testing HistoryService...\n');

  // 1. Thêm một số dữ liệu test
  print('1. Thêm dữ liệu test...');
  await historyService.addPredictionResult(result: 'healthy (95%)', confidence: '95');

  await historyService.addPredictionResult(result: 'disease detected (78%)', confidence: '78');

  await historyService.addPredictionResult(result: 'healthy (92%)', confidence: '92');

  // 2. Lấy lịch sử
  print('\n2. Lấy lịch sử...');
  final history = await historyService.getPredictionHistory();
  print('Số lượng items: ${history.length}');

  for (int i = 0; i < history.length; i++) {
    final item = history[i];
    print('  ${i + 1}. ${item['result']} - ${item['timestamp']}');
  }

  // 3. Lấy thống kê
  print('\n3. Thống kê...');
  final stats = await historyService.getHistoryStats();
  print('Tổng: ${stats['total']}');
  print('Healthy: ${stats['healthy']}');
  print('Disease: ${stats['disease']}');
  print('Warning: ${stats['warning']}');
  print('Healthy %: ${stats['healthyPercent']}%');

  print('\n✅ Test completed!');
}
