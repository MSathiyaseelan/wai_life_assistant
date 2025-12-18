import 'package:dio/dio.dart';
import '../env/env.dart';
import 'dio_interceptors.dart';
import '../auth/auth_interceptor.dart';
import '../error/api_error_mapper.dart';
import '../error/api_exception.dart';

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

    dio.interceptors.add(AuthInterceptor(dio));
    dio.interceptors.add(DioInterceptors(dio)); // Logging + Retry
  }

  // Generic GET
  Future<Response> get(String path, {Map<String, dynamic>? query}) async {
    try {
      return await dio.get(path, queryParameters: query);
    } on DioException catch (e) {
      throw ApiErrorMapper.map(e);
    }
  }

  // Generic POST
  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await dio.post(path, data: data);
    } on DioException catch (e) {
      throw ApiErrorMapper.map(e);
    }
  }

  // PUT
  Future<Response> put(String path, {dynamic data}) async {
    try {
      return await dio.put(path, data: data);
    } on DioException catch (e) {
      throw ApiErrorMapper.map(e);
    }
  }

  // DELETE
  Future<Response> delete(String path) async {
    try {
      return await dio.delete(path);
    } on DioException catch (e) {
      throw ApiErrorMapper.map(e);
    }
  }
}
