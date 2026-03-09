import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Sends an OTP to [phone] (must include country code, e.g. "+919876543210").
  Future<void> sendOtp(String phone) async {
    await _client.auth.signInWithOtp(phone: phone);
  }

  /// Verifies the OTP. Throws [AuthException] on failure.
  Future<AuthResponse> verifyOtp(String phone, String token) async {
    return await _client.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );
  }

  /// Signs the user out and clears the session.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Returns true if a valid session exists.
  bool get isLoggedIn => _client.auth.currentSession != null;

  /// The currently authenticated user, or null.
  User? get currentUser => _client.auth.currentUser;

  /// The current user's phone number, or null.
  String? get currentPhone => _client.auth.currentUser?.phone;
}
