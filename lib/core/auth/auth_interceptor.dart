import 'package:dio/dio.dart';
import '../logging/app_logger.dart';
import 'token_storage.dart';
import 'auth_service.dart';

class AuthInterceptor extends Interceptor {
  final Dio dio;
  final TokenStorage _storage = TokenStorage();
  final AuthService _authService = AuthService();

  AuthInterceptor(this.dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final accessToken = await _storage.getAccessToken();

    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }

    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (_isUnauthorized(err)) {
      AppLogger.w("🔒 Access token expired. Refreshing...");

      final newToken = await _authService.refreshAccessToken();

      if (newToken != null) {
        err.requestOptions.headers['Authorization'] = 'Bearer $newToken';

        final response = await dio.fetch(err.requestOptions);
        return handler.resolve(response);
      } else {
        await _storage.clear();
        AppLogger.e("🚪 Session expired. Logout user.");
      }
    }

    return handler.next(err);
  }

  bool _isUnauthorized(DioException err) {
    return err.response?.statusCode == 401;
  }
}
