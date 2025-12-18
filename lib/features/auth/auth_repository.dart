import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/token_storage.dart';

class AuthRepository {
  final ApiClient _apiClient = ApiClient();
  final TokenStorage _storage = TokenStorage();

  Future<void> login(String email, String password) async {
    final response = await _apiClient.post(
      ApiEndpoints.login,
      data: {"email": email, "password": password},
    );

    await _storage.saveTokens(
      accessToken: response.data['accessToken'],
      refreshToken: response.data['refreshToken'],
    );
  }
}
