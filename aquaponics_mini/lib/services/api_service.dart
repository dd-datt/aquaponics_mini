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

  Future<List<Map<String, dynamic>>> getImageHistory({int limit = 10}) async {
    try {
      final response = await dio.get('$baseUrl/image-history?limit=$limit');
      if (response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return [];
    } catch (e) {
      print('Error fetching image history: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPredictionHistory({int limit = 10}) async {
    try {
      final response = await dio.get('$baseUrl/prediction-history?limit=$limit');
      if (response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return [];
    } catch (e) {
      print('Error fetching prediction history: $e');
      return [];
    }
  }
}
