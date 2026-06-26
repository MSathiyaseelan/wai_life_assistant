import 'package:dio/dio.dart';
import '../logging/app_logger.dart';

const _kMaxRetries = 3;

class DioInterceptors extends Interceptor {
  final Dio dio;

  DioInterceptors(this.dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    AppLogger.d('➡️ ${options.method} ${options.baseUrl}${options.path}');
    AppLogger.d('Payload: ${options.data}');
    options.extra['retryCount'] ??= 0;
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

    final attempt = (err.requestOptions.extra['retryCount'] as int? ?? 0);
    if (_shouldRetry(err) && attempt < _kMaxRetries) {
      err.requestOptions.extra['retryCount'] = attempt + 1;
      final delay = Duration(milliseconds: 500 * (1 << attempt)); // 500ms, 1s, 2s
      AppLogger.w('🔁 Retry ${attempt + 1}/$_kMaxRetries in ${delay.inMilliseconds}ms…');
      await Future.delayed(delay);
      try {
        final response = await dio.fetch(err.requestOptions);
        return handler.resolve(response);
      } catch (_) {
        return handler.next(err);
      }
    }

    return handler.next(err);
  }

  bool _shouldRetry(DioException err) =>
      err.type == DioExceptionType.connectionTimeout ||
      err.type == DioExceptionType.receiveTimeout ||
      err.type == DioExceptionType.unknown;
}
