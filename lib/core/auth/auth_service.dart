import 'package:dio/dio.dart';
import '../api/api_endpoints.dart';
import '../env/env.dart';
import '../logging/app_logger.dart';
import 'token_storage.dart';

class AuthService {
  final Dio _dio = Dio();
  final TokenStorage _storage = TokenStorage();

  Future<String?> refreshAccessToken() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) return null;

    try {
      final response = await _dio.post(
        '${envConfig.baseUrl}${ApiEndpoints.refreshToken}',
        data: {"refreshToken": refreshToken},
      );

      final newAccessToken = response.data['accessToken'];
      final newRefreshToken = response.data['refreshToken'];

      await _storage.saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );

      AppLogger.i("🔑 Token refreshed successfully");
      return newAccessToken;
    } catch (e, s) {
      AppLogger.e("❌ Token refresh failed", error: e, stackTrace: s);
      return null;
    }
  }
}
