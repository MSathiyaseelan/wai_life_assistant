import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:wai_life_assistant/core/services/privacy_prefs.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppLockGuard — wraps the main app content and enforces the app lock
// ─────────────────────────────────────────────────────────────────────────────

class AppLockGuard extends StatefulWidget {
  final Widget child;
  const AppLockGuard({super.key, required this.child});

  @override
  State<AppLockGuard> createState() => _AppLockGuardState();
}

class _AppLockGuardState extends State<AppLockGuard>
    with WidgetsBindingObserver {
  final _prefs = PrivacyPrefs.instance;
  final _auth = LocalAuthentication();

  bool _locked = false;
  bool _biometricFailed = false; // show PIN fallback when biometric fails
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prefs.init().then((_) {
      if (!mounted) return;
      if (_prefs.appLockEnabled) {
        setState(() => _locked = true);
        // Defer until after the first frame so the activity is fully in the
        // foreground — calling authenticate() too early throws PlatformException.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 300), _attemptUnlock);
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_prefs.appLockEnabled) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final elapsed =
          DateTime.now().difference(_pausedAt ?? DateTime.now()).inSeconds;
      final threshold = _prefs.lockAfter.seconds;
      if (threshold == 0 || elapsed >= threshold) {
        if (!_locked) {
          setState(() {
            _locked = true;
            _biometricFailed = false;
          });
          Future.delayed(const Duration(milliseconds: 300), _attemptUnlock);
        }
      }
      _pausedAt = null;
    }
  }

  Future<void> _attemptUnlock() async {
    if (_prefs.lockMethod == LockMethod.biometric) {
      await _tryBiometric();
    }
    // PIN method → overlay shows PIN entry; biometric failure → overlay shows fallback
  }

  Future<void> _tryBiometric() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      if (!isSupported) {
        // Device has no secure lock screen at all — fall back to PIN.
        if (mounted) setState(() => _biometricFailed = true);
        return;
      }
      final success = await _auth.authenticate(
        localizedReason: 'Authenticate to open WAI',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (!mounted) return;
      if (success) {
        setState(() => _locked = false);
      }
      // success == false means user dismissed — keep biometric UI so they
      // can tap retry. Do NOT flip to PIN automatically.
    } catch (_) {
      // On any platform error leave the biometric retry screen visible;
      // the user can still tap the fingerprint icon to try again, or
      // choose "Use PIN instead" manually.
    }
  }

  void _onUnlocked() => setState(() => _locked = false);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_locked)
          _AppLockOverlay(
            isDark: Theme.of(context).brightness == Brightness.dark,
            lockMethod: _prefs.lockMethod,
            biometricFailed: _biometricFailed,
            pinLength: _prefs.pinLength,
            onUnlocked: _onUnlocked,
            onRetryBiometric: () {
              setState(() => _biometricFailed = false);
              _tryBiometric();
            },
            onSwitchToPin: () => setState(() => _biometricFailed = true),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AppLockOverlay — the full-screen lock UI
// ─────────────────────────────────────────────────────────────────────────────

class _AppLockOverlay extends StatefulWidget {
  final bool isDark;
  final LockMethod lockMethod;
  final bool biometricFailed;
  final int pinLength;
  final VoidCallback onUnlocked;
  final VoidCallback onRetryBiometric;
  final VoidCallback onSwitchToPin;

  const _AppLockOverlay({
    required this.isDark,
    required this.lockMethod,
    required this.biometricFailed,
    required this.pinLength,
    required this.onUnlocked,
    required this.onRetryBiometric,
    required this.onSwitchToPin,
  });

  @override
  State<_AppLockOverlay> createState() => _AppLockOverlayState();
}

class _AppLockOverlayState extends State<_AppLockOverlay> {
  String _pin = '';
  String? _error;
  bool _checking = false;

  bool get _showPin =>
      widget.lockMethod == LockMethod.pin || widget.biometricFailed;

  Color get _bg =>
      widget.isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF4F5FF);
  Color get _tc => widget.isDark ? Colors.white : const Color(0xFF0F172A);
  Color get _sub =>
      widget.isDark ? Colors.white54 : const Color(0xFF64748B);

  void _onDigit(String d) {
    if (_checking || _pin.length >= widget.pinLength) return;
    setState(() {
      _error = null;
      _pin += d;
    });
    if (_pin.length == widget.pinLength) {
      _checkPin();
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() {
      _error = null;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _checkPin() async {
    setState(() => _checking = true);
    final ok = await PrivacyPrefs.instance.checkPin(_pin);
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() {
        _checking = false;
        _error = 'Incorrect PIN. Try again.';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _bg,
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // Lock icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text('🔐', style: TextStyle(fontSize: 36)),
            ),
            const SizedBox(height: 20),

            Text(
              'WAI is Locked',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
                color: _tc,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _showPin
                  ? 'Enter your PIN to continue'
                  : 'Use biometric to unlock',
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'Nunito',
                color: _sub,
              ),
            ),

            const Spacer(),

            if (!_showPin) ...[
              // ── Biometric UI ──────────────────────────────────────────────
              GestureDetector(
                onTap: widget.onRetryBiometric,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    size: 44,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Tap to authenticate',
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Nunito',
                  color: _sub,
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: widget.onSwitchToPin,
                child: Text(
                  'Use PIN instead',
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ] else ...[
              // ── PIN UI ────────────────────────────────────────────────────
              // PIN dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.pinLength, (i) {
                  final filled = i < _pin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? AppColors.primary : Colors.transparent,
                      border: Border.all(
                        color: filled
                            ? AppColors.primary
                            : _sub.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),

              // Error
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: _error != null
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'Nunito',
                            color: AppColors.expense,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 28),

              // Numpad
              _Numpad(onDigit: _onDigit, onDelete: _onDelete, sub: _sub, tc: _tc),

              // Switch to biometric (if method was biometric and fallback was triggered)
              if (widget.lockMethod == LockMethod.biometric) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: widget.onRetryBiometric,
                  icon: const Icon(Icons.fingerprint_rounded,
                      size: 16, color: AppColors.primary),
                  label: const Text(
                    'Use Biometric',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Numpad
// ─────────────────────────────────────────────────────────────────────────────

class _Numpad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final Color sub;
  final Color tc;

  const _Numpad({
    required this.onDigit,
    required this.onDelete,
    required this.sub,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Column(
      children: keys.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((k) {
            if (k.isEmpty) return const SizedBox(width: 80, height: 60);
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                if (k == '⌫') {
                  onDelete();
                } else {
                  onDigit(k);
                }
              },
              child: Container(
                width: 80,
                height: 60,
                alignment: Alignment.center,
                child: Text(
                  k,
                  style: TextStyle(
                    fontSize: k == '⌫' ? 22 : 24,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    color: k == '⌫' ? sub : tc,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
