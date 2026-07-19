import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wai_life_assistant/data/services/subscription_service.dart';

class AuthCoordinator {
  AuthCoordinator._();
  static final AuthCoordinator instance = AuthCoordinator._();

  final _firebaseAuth = fb.FirebaseAuth.instance;
  SupabaseClient get _client => Supabase.instance.client;

  String _verificationId = '';
  int? _forceResendingToken;
  fb.PhoneAuthCredential? _autoCredential;

  /// True when Firebase auto-verified the phone on Android (no OTP entry needed).
  bool get isAutoVerified => _autoCredential != null;

  /// Sends OTP to [phone] via Firebase Phone Auth.
  /// [phone] must include country code, e.g. "+919876543210".
  Future<void> sendOtp(String phone) async {
    _autoCredential = null;
    final completer = Completer<void>();

    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: _forceResendingToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (fb.PhoneAuthCredential credential) {
        // Android only: SMS auto-read succeeded — store credential for instant sign-in.
        _autoCredential = credential;
        if (!completer.isCompleted) completer.complete();
      },
      verificationFailed: (fb.FirebaseAuthException e) {
        if (!completer.isCompleted) {
          completer.completeError(
            AuthException(e.message ?? 'Phone verification failed'),
          );
        }
      },
      codeSent: (String verificationId, int? forceResendingToken) {
        _verificationId = verificationId;
        _forceResendingToken = forceResendingToken;
        if (!completer.isCompleted) completer.complete();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );

    return completer.future;
  }

  /// Verifies [otp] entered by the user (or auto-credential on Android).
  /// On success, exchanges the Firebase ID token for a Supabase session.
  Future<void> verifyOtp(String phone, String otp) async {
    try {
      final credential = _autoCredential ??
          fb.PhoneAuthProvider.credential(
            verificationId: _verificationId,
            smsCode: otp,
          );
      _autoCredential = null;

      final userCred = await _firebaseAuth.signInWithCredential(credential);
      final idToken  = await userCred.user!.getIdToken();

      // Exchange Firebase ID token for a Supabase session via edge function.
      final res = await _client.functions.invoke(
        'firebase-verify',
        body: {'id_token': idToken},
      );

      final data = res.data as Map<String, dynamic>?;
      if (res.status != 200 || data == null) {
        throw AuthException(
          data?['error'] as String? ?? 'Authentication failed',
        );
      }

      final accessToken  = data['access_token']  as String?;
      final refreshToken = data['refresh_token'] as String?;
      if (accessToken == null || refreshToken == null) {
        throw AuthException('Missing session tokens');
      }

      await _client.auth.setSession(refreshToken);
      if (kDebugMode) debugPrint('[Auth] Firebase OTP verified');
      final uid = _client.auth.currentUser?.id;
      if (uid != null) await SubscriptionService.instance.login(uid);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e.code));
    }
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'invalid-verification-code':
        return 'Invalid OTP. Please check and try again.';
      case 'session-expired':
        return 'OTP expired. Please request a new one.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-phone-number':
        return 'Invalid phone number.';
      default:
        return 'Verification failed. Please try again.';
    }
  }

  /// Resend OTP to [phone] — reuses the resend token for faster delivery.
  Future<void> resendOtp(String phone) => sendOtp(phone);

  /// Dev-only bypass: signs in anonymously without OTP.
  Future<void> bypassVerify() async {
    final res = await _client.auth.signInAnonymously();
    if (res.session == null) {
      throw AuthException('Anonymous sign-in failed — enable it in Supabase dashboard.');
    }
    if (kDebugMode) debugPrint('[Auth] Bypass login');
    final uid = res.session!.user.id;
    await SubscriptionService.instance.login(uid);
  }

  /// Signs the user out of Firebase and Supabase.
  /// Pass [allDevices: true] to revoke all refresh tokens (logout everywhere).
  Future<void> signOut({bool allDevices = true}) async {
    // Run both sign-outs independently — Firebase may have no active user
    // (anonymous / bypass sessions never sign into Firebase).
    await _client.auth.signOut(
      scope: allDevices ? SignOutScope.global : SignOutScope.local,
    );
    try {
      await _firebaseAuth.signOut();
    } catch (_) {}
    await SubscriptionService.instance.logout();
  }

  bool get isLoggedIn  => _client.auth.currentSession != null;
  User? get currentUser => _client.auth.currentUser;
  String? get currentPhone => _client.auth.currentUser?.phone;
}
