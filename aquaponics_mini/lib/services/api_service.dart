import 'package:dio/dio.dart';

class ApiService {
  final Dio dio;
  final String baseUrl;

  ApiService({required this.baseUrl}) : dio = Dio();

  Future<Map<String, dynamic>> getLastImage() async {
    final response = await dio.get('$baseUrl/last-image');
    return {'image': response.data['image'] ?? '', 'timestamp': response.data['timestamp']};
  }

  Future<Map<String, dynamic>> getLastPrediction() async {
    final response = await dio.get('$baseUrl/last-prediction');
    return {'result': response.data['result'] ?? '', 'timestamp': response.data['timestamp']};
  }
}
