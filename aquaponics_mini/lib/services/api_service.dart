import 'package:dio/dio.dart';

class ApiService {
  final Dio dio;
  final String baseUrl;

  ApiService({required this.baseUrl}) : dio = Dio();

  Future<String> getLastImage() async {
    final response = await dio.get('$baseUrl/last-image');
    return response.data['image_path'] ?? '';
  }

  Future<String> getLastPrediction() async {
    final response = await dio.get('$baseUrl/last-prediction');
    return response.data['result'] ?? '';
  }
}
