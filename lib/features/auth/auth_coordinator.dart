import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthCoordinator {
  AuthCoordinator._();
  static final AuthCoordinator instance = AuthCoordinator._();

  SupabaseClient get _client => Supabase.instance.client;
  String requestId = '';

  /// Sends an OTP to [phone] via the MSG91-backed edge function.
  /// [phone] must include the country code, e.g. "+919876543210".
  Future<void> sendOtp(String phone) async {
    final res = await _client.functions.invoke(
      'send-otp',
      body: {'phone': phone},
    );
    if (res.status != 200) {
      final msg =
          (res.data as Map<String, dynamic>?)?['error'] as String? ??
          'Failed to send OTP';
      throw AuthException(msg);
    }
    requestId = res.data['request_id'];
  }

  /// Verifies [otp] for [phone] via the edge function.
  /// On success the returned session is activated so [isLoggedIn] becomes true.
  Future<void> verifyOtp(String phone, String otp) async {
    final res = await _client.functions.invoke(
      'verify-otp',
      body: {'phone': phone, 'otp': otp, 'request_id': requestId},
    );

    final data = res.data as Map<String, dynamic>?;

    if (res.status != 200 || data == null) {
      final msg = data?['error'] as String? ?? 'Invalid OTP. Please try again.';
      throw AuthException(msg);
    }

    final accessToken = data['access_token'] as String?;
    final refreshToken = data['refresh_token'] as String?;

    if (accessToken == null || refreshToken == null) {
      throw AuthException('Authentication failed — missing session tokens.');
    }

    // Activate the session in the Supabase Flutter client.
    await _client.auth.setSession(accessToken);
    debugPrint('[Auth] OTP verified, uid=${_client.auth.currentUser?.id}');
  }

  /// Dev-only bypass: signs in anonymously to get a real session without OTP.
  /// Remove or gate this behind a compile flag before going to production.
  Future<void> bypassVerify() async {
    final res = await _client.auth.signInAnonymously();
    if (res.session == null) {
      throw AuthException('Anonymous sign-in failed — enable it in Supabase dashboard.');
    }
    debugPrint('[Auth] Bypass login, uid=${_client.auth.currentUser?.id}');
  }

  /// Resend OTP — same as sendOtp, exposed separately for the resend button.
  Future<void> resendOtp(String phone) => sendOtp(phone);

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
