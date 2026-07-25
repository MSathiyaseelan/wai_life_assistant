import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wai_life_assistant/data/services/subscription_service.dart';
import 'package:wai_life_assistant/core/services/fcm_service.dart';

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

  /// Optional hook OtpScreen can set to react if SMS auto-read succeeds
  /// *after* sendOtp() has already returned — the common case, since
  /// codeSent normally fires (and completes sendOtp) before Android
  /// finishes auto-reading the SMS, right up until the 60s timeout. Without
  /// this, an OtpScreen that only checked isAutoVerified once in initState
  /// would miss a late auto-verify and leave the user typing a code that's
  /// already been handled.
  void Function()? onAutoVerified;

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
        onAutoVerified?.call();
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
    final fb.UserCredential userCred;
    try {
      final credential = _autoCredential ??
          fb.PhoneAuthProvider.credential(
            verificationId: _verificationId,
            smsCode: otp,
          );
      _autoCredential = null;
      userCred = await _firebaseAuth.signInWithCredential(credential);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e.code));
    }

    // Firebase has now confirmed the OTP is correct and consumed it — a
    // Firebase phone credential can't be reused. So any failure past this
    // point means retyping the *same* code will never work; the user needs
    // a fresh OTP. Wrap failures here with a message steering them to
    // Resend instead of the generic "verification failed" (which reads as
    // "the code was wrong" and invites a pointless retry).
    try {
      final idToken = await userCred.user!.getIdToken();

      // Exchange Firebase ID token for a Supabase session via edge function.
      final res = await _client.functions.invoke(
        'firebase-verify',
        body: {'id_token': idToken},
      );

      final data = res.data as Map<String, dynamic>?;
      if (res.status != 200 || data == null) {
        throw AuthException(
          data?['error'] as String? ?? 'Sign-in failed after verification.',
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
    } catch (_) {
      throw AuthException(
        "Your code was verified, but sign-in couldn't finish. "
        'Please tap Resend to get a new code and try again.',
      );
    }
  }

  /// Verifies [otp] for a NEW phone number and renames the *currently
  /// logged-in* account to it, via the change-phone edge function.
  ///
  /// Deliberately does NOT reuse [verifyOtp] — that flow exchanges the
  /// Firebase credential for a Supabase session via firebase-verify, which
  /// signs into (or creates) whichever account owns that phone number. For
  /// changing your own number that's wrong: it would switch you to a
  /// different account instead of renaming this one. Call [sendOtp] first
  /// to trigger the SMS to the new number, same as login.
  Future<void> verifyAndChangePhone(String otp) async {
    try {
      final credential = _autoCredential ??
          fb.PhoneAuthProvider.credential(
            verificationId: _verificationId,
            smsCode: otp,
          );
      _autoCredential = null;

      final userCred = await _firebaseAuth.signInWithCredential(credential);
      final idToken = await userCred.user!.getIdToken();

      final res = await _client.functions.invoke(
        'change-phone',
        body: {'id_token': idToken},
      );

      final data = res.data as Map<String, dynamic>?;
      if (res.status != 200 || data?['success'] != true) {
        throw AuthException(
          data?['error'] as String? ?? 'Failed to change phone number',
        );
      }
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

  /// Dev-only bypass: signs in anonymously without OTP. Not currently wired
  /// to any UI. Hard-gated on kDebugMode (not just "nothing calls it today")
  /// so it can never activate in a release build even if someone wires it
  /// into a debug menu later without noticing the build mode.
  Future<void> bypassVerify() async {
    if (!kDebugMode) {
      throw AuthException('Bypass sign-in is only available in debug builds.');
    }
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
    // Must happen BEFORE auth.signOut() — user_fcm_tokens RLS scopes rows to
    // auth.uid(), so this device's token can only be removed while still
    // authenticated. Otherwise a different account logging in on this same
    // device later would leave this account's token behind and keep
    // receiving its notifications.
    try {
      await FcmService.deleteFcmToken();
    } catch (_) {}

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
