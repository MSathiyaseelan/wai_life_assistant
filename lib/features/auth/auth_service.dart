import 'package:flutter/foundation.dart' show debugPrint;
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

  /// Dev bypass: sign in with a stable email+password derived from the phone number.
  /// This gives a consistent auth.uid() across cache clears for the same phone,
  /// so existing profile/wallet data is always found.
  /// Requires Email auth enabled in Supabase Dashboard → Auth → Email → enabled.
  /// Also disable "Confirm email" in Supabase Dashboard → Auth → Email settings.
  Future<void> signInWithPhoneBypass(String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final email = 'dev_$digits@wai.app';
    const password = 'wai_dev_bypass_2024';
    debugPrint('[Auth] bypass sign-in for $email');
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      debugPrint('[Auth] signed in uid=${res.user?.id}');
    } on AuthException catch (e) {
      debugPrint('[Auth] signIn failed (${e.statusCode}): ${e.message}');
      // User doesn't exist yet — sign up, then sign in explicitly
      // (signUp alone doesn't create a session when email confirmation is on)
      await _client.auth.signUp(email: email, password: password);
      debugPrint('[Auth] signed up, now signing in');
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      debugPrint('[Auth] post-signup sign-in uid=${res.user?.id}');
    }
  }

  /// Returns true if a valid session exists.
  bool get isLoggedIn => _client.auth.currentSession != null;

  /// The currently authenticated user, or null.
  User? get currentUser => _client.auth.currentUser;

  /// The current user's phone number, or null.
  String? get currentPhone => _client.auth.currentUser?.phone;
}
