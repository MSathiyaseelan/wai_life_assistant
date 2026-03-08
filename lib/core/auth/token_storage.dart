import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _phoneKey = 'auth_phone';
  static const _isLoggedInKey = 'is_logged_in';

  final _storage = const FlutterSecureStorage();

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> savePhone(String phone) async {
    await _storage.write(key: _phoneKey, value: phone);
    await _storage.write(key: _isLoggedInKey, value: 'true');
  }

  Future<String?> getPhone() => _storage.read(key: _phoneKey);

  Future<bool> isLoggedIn() async {
    final val = await _storage.read(key: _isLoggedInKey);
    return val == 'true';
  }

  Future<void> clear() async {
    await _storage.deleteAll();
  }
}
