import 'package:dio/dio.dart';
import '../logging/app_logger.dart';

class DioInterceptors extends Interceptor {
  final Dio dio;

  DioInterceptors(this.dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    AppLogger.d('➡️ ${options.method} ${options.baseUrl}${options.path}');
    AppLogger.d('Payload: ${options.data}');
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    AppLogger.i('✅ ${response.statusCode} ${response.requestOptions.path}');
    super.onResponse(response, handler);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    AppLogger.e(
      '❌ API ERROR ${err.requestOptions.path}',
      error: err,
      stackTrace: err.stackTrace,
    );

    // 🔁 Retry logic (network errors only)
    if (_shouldRetry(err)) {
      try {
        final response = await _retry(err.requestOptions);
        return handler.resolve(response);
      } catch (_) {
        return handler.next(err);
      }
    }

    return handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.unknown;
  }

  Future<Response> _retry(RequestOptions requestOptions) async {
    AppLogger.w('🔁 Retrying request...');
    return dio.fetch(requestOptions);
  }
}
