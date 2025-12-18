import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

class AuthRepository {
  final ApiClient _apiClient = ApiClient();

  Future<void> login(String email, String password) async {
    await _apiClient.post(
      ApiEndpoints.login,
      data: {"email": email, "password": password},
    );
  }
}
