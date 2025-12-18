import 'package:dio/dio.dart';
import '../env/env.dart';
import 'dio_interceptors.dart';

class ApiClient {
  late final Dio dio;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: envConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(DioInterceptors(dio));
  }

  // Generic GET
  Future<Response> get(String path, {Map<String, dynamic>? query}) {
    return dio.get(path, queryParameters: query);
  }

  // Generic POST
  Future<Response> post(String path, {dynamic data}) {
    return dio.post(path, data: data);
  }

  // PUT
  Future<Response> put(String path, {dynamic data}) {
    return dio.put(path, data: data);
  }

  // DELETE
  Future<Response> delete(String path) {
    return dio.delete(path);
  }
}
