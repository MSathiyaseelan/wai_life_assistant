import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/core/services/privacy_prefs.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PRIVACY & SECURITY SHEET
// ─────────────────────────────────────────────────────────────────────────────

class PrivacySecuritySheet extends StatefulWidget {
  final bool isDark;
  const PrivacySecuritySheet({super.key, required this.isDark});

  @override
  State<PrivacySecuritySheet> createState() => _PrivacySecuritySheetState();
}

class _PrivacySecuritySheetState extends State<PrivacySecuritySheet> {
  final _prefs = PrivacyPrefs.instance;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _prefs.init().then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  // ── colours ────────────────────────────────────────────────────────────────
  Color get _bg   => widget.isDark ? AppColors.cardDark  : AppColors.cardLight;
  Color get _surf => widget.isDark ? AppColors.surfDark  : const Color(0xFFEDEEF5);
  Color get _tc   => widget.isDark ? AppColors.textDark  : AppColors.textLight;
  Color get _sub  => widget.isDark ? AppColors.subDark   : AppColors.subLight;
  Color get _div  => widget.isDark
      ? Colors.white.withAlpha(18)
      : Colors.black.withAlpha(18);

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _prefs,
      builder: (_, _) => Container(
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            _handle(),
            _header(context),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      children: [
                        const SizedBox(height: 4),
                        _sectionLabel('App Lock'),
                        _card([
                          _switchTile(
                            icon: Icons.lock_rounded,
                            iconColor: AppColors.primary,
                            iconBg: AppColors.primary.withAlpha(20),
                            title: 'Enable App Lock',
                            subtitle: 'Require authentication to open the app',
                            value: _prefs.appLockEnabled,
                            onChanged: (v) => setState(() => _prefs.appLockEnabled = v),
                          ),
                          if (_prefs.appLockEnabled) ...[
                            _divider(),
                            _lockMethodTile(),
                            _divider(),
                            _lockAfterTile(),
                          ],
                        ]),

                        const SizedBox(height: 16),
                        _sectionLabel('Locked Notes'),
                        _card([
                          _switchTile(
                            icon: Icons.fingerprint_rounded,
                            iconColor: const Color(0xFF00C897),
                            iconBg: const Color(0xFF00C897).withAlpha(20),
                            title: 'Require Biometric',
                            subtitle: 'Use Face ID / Fingerprint to open locked notes',
                            value: _prefs.lockedNotesBiometric,
                            onChanged: (v) => setState(() => _prefs.lockedNotesBiometric = v),
                          ),
                          _divider(),
                          _arrowTile(
                            icon: Icons.pin_rounded,
                            iconColor: const Color(0xFFFFAA2C),
                            iconBg: const Color(0xFFFFAA2C).withAlpha(20),
                            title: 'Change PIN',
                            subtitle: 'Update your notes unlock PIN',
                            onTap: () => _showPinSetup(context, changeMode: true),
                          ),
                        ]),

                        const SizedBox(height: 16),
                        _sectionLabel('Data Privacy'),
                        _card([
                          _switchTile(
                            icon: Icons.auto_awesome_rounded,
                            iconColor: const Color(0xFF7C4DFF),
                            iconBg: const Color(0xFF7C4DFF).withAlpha(20),
                            title: 'Personalisation',
                            subtitle:
                                'Allow the app to use your data to improve AI suggestions',
                            value: _prefs.allowPersonalisation,
                            onChanged: (v) => setState(() => _prefs.allowPersonalisation = v),
                          ),
                        ]),

                        const SizedBox(height: 16),
                        _sectionLabel('Export My Data'),
                        _card([
                          _arrowTile(
                            icon: Icons.picture_as_pdf_rounded,
                            iconColor: const Color(0xFFFF5C7A),
                            iconBg: const Color(0xFFFF5C7A).withAlpha(20),
                            title: 'Export as PDF',
                            subtitle: 'Download a PDF copy of your data',
                            onTap: () => _showComingSoon(context, 'Export as PDF'),
                          ),
                          _divider(),
                          _arrowTile(
                            icon: Icons.table_chart_rounded,
                            iconColor: const Color(0xFF00C897),
                            iconBg: const Color(0xFF00C897).withAlpha(20),
                            title: 'Export as Excel',
                            subtitle: 'Download an Excel spreadsheet of your data',
                            onTap: () => _showComingSoon(context, 'Export as Excel'),
                          ),
                          _divider(),
                          _arrowTile(
                            icon: Icons.email_rounded,
                            iconColor: const Color(0xFF4A9EFF),
                            iconBg: const Color(0xFF4A9EFF).withAlpha(20),
                            title: 'Send to Email',
                            subtitle: 'Receive your exported data via email',
                            onTap: () => _showComingSoon(context, 'Send to Email'),
                          ),
                        ]),

                        const SizedBox(height: 16),
                        _sectionLabel('Legal'),
                        _card([
                          _arrowTile(
                            icon: Icons.shield_rounded,
                            iconColor: _sub,
                            iconBg: _sub.withAlpha(20),
                            title: 'Privacy Policy',
                            subtitle: 'View how we handle your data',
                            onTap: () => _showPrivacyPolicy(context),
                          ),
                        ]),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── components ─────────────────────────────────────────────────────────────

  Widget _handle() => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _sub.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );

  Widget _header(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 8, 10),
        child: Row(
          children: [
            Text(
              '🔒  Privacy & Security',
              style: TextStyle(
                fontSize: 17,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w900,
                color: _tc,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.close_rounded, color: _sub, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: _sub,
          ),
        ),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: _surf,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: children),
      );

  Widget _divider() => Divider(height: 1, color: _div, indent: 56);

  Widget _iconBox(IconData icon, Color iconColor, Color bg) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: iconColor),
      );

  Widget _switchTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            _iconBox(icon, iconColor, iconBg),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          color: _tc)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Nunito',
                          color: _sub)),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppColors.primary,
            ),
          ],
        ),
      );

  Widget _arrowTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              _iconBox(icon, iconColor, iconBg),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w800,
                            color: _tc)),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Nunito',
                            color: _sub)),
                  ],
                ),
              ),
              trailing ??
                  Icon(Icons.chevron_right_rounded, size: 20, color: _sub),
            ],
          ),
        ),
      );

  // ── Lock Method tile (inline radio) ───────────────────────────────────────

  Widget _lockMethodTile() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _iconBox(Icons.security_rounded, const Color(0xFF4A9EFF),
                const Color(0xFF4A9EFF).withAlpha(20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lock Method',
                      style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          color: _tc)),
                  const SizedBox(height: 8),
                  _methodOption(
                    LockMethod.biometric,
                    Icons.fingerprint_rounded,
                    'Biometric',
                    'Face ID / Fingerprint',
                  ),
                  const SizedBox(height: 6),
                  _methodOption(
                    LockMethod.pin,
                    Icons.pin_rounded,
                    'PIN',
                    '4 or 6 digit code',
                    onSelected: () => _showPinSetup(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _methodOption(
    LockMethod method,
    IconData icon,
    String label,
    String sub, {
    VoidCallback? onSelected,
  }) {
    final active = _prefs.lockMethod == method;
    return GestureDetector(
      onTap: () {
        setState(() => _prefs.lockMethod = method);
        onSelected?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withAlpha(18) : _div.withAlpha(30),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppColors.primary.withAlpha(80) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: active ? AppColors.primary : _sub),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          color: active ? AppColors.primary : _tc)),
                  Text(sub,
                      style: TextStyle(
                          fontSize: 10, fontFamily: 'Nunito', color: _sub)),
                ],
              ),
            ),
            if (active)
              const Icon(Icons.check_circle_rounded,
                  size: 16, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  // ── Lock After tile (segmented chips) ─────────────────────────────────────

  Widget _lockAfterTile() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _iconBox(Icons.timer_rounded, const Color(0xFFFFAA2C),
                const Color(0xFFFFAA2C).withAlpha(20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lock After',
                      style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          color: _tc)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: LockAfter.values.map((opt) {
                      final active = _prefs.lockAfter == opt;
                      return GestureDetector(
                        onTap: () => setState(() => _prefs.lockAfter = opt),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.primary
                                : AppColors.primary.withAlpha(18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            opt.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w800,
                              color: active ? Colors.white : AppColors.primary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  // ── PIN Setup / Change dialog ──────────────────────────────────────────────

  void _showPinSetup(BuildContext context, {bool changeMode = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PinSetupSheet(
        isDark: widget.isDark,
        changeMode: changeMode,
        onSaved: () {
          if (mounted) setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(changeMode ? 'PIN updated' : 'PIN set successfully'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  // ── Coming Soon snackbar ───────────────────────────────────────────────────

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Privacy Policy dialog ─────────────────────────────────────────────────

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Privacy Policy',
            style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w900,
                color: _tc)),
        content: Text(
          'WAI Life Assistant collects only the data you enter. '
          'Your data is stored securely in Supabase and is never sold '
          'to third parties. AI parsing uses anonymised prompts only.\n\n'
          'For the full policy, visit our website.',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: _sub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close',
                style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PIN SETUP SHEET — set or change a 4 / 6 digit PIN
// ─────────────────────────────────────────────────────────────────────────────

class _PinSetupSheet extends StatefulWidget {
  final bool isDark;
  final bool changeMode;
  final VoidCallback onSaved;
  const _PinSetupSheet({
    required this.isDark,
    required this.changeMode,
    required this.onSaved,
  });

  @override
  State<_PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends State<_PinSetupSheet> {
  int _digits = 4;
  String _pin = '';
  String _confirm = '';
  bool _confirming = false;
  String? _error;

  Color get _bg  => widget.isDark ? AppColors.cardDark  : AppColors.cardLight;
  Color get _tc  => widget.isDark ? AppColors.textDark  : AppColors.textLight;
  Color get _sub => widget.isDark ? AppColors.subDark   : AppColors.subLight;

  void _onKey(String digit) {
    setState(() {
      _error = null;
      if (!_confirming) {
        if (_pin.length < _digits) _pin += digit;
        if (_pin.length == _digits) {
          Future.delayed(const Duration(milliseconds: 120),
              () => setState(() => _confirming = true));
        }
      } else {
        if (_confirm.length < _digits) _confirm += digit;
        if (_confirm.length == _digits) _submit();
      }
    });
  }

  void _onDelete() {
    setState(() {
      _error = null;
      if (_confirming) {
        if (_confirm.isNotEmpty) _confirm = _confirm.substring(0, _confirm.length - 1);
      } else {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  Future<void> _submit() async {
    if (_pin != _confirm) {
      setState(() {
        _error = 'PINs do not match. Try again.';
        _pin = '';
        _confirm = '';
        _confirming = false;
      });
      return;
    }
    await PrivacyPrefs.instance.savePin(_pin);
    if (mounted) {
      Navigator.pop(context);
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _confirming ? _confirm : _pin;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: _sub.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              widget.changeMode ? 'Change PIN' : 'Set PIN',
              style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w900,
                  color: _tc),
            ),
            const SizedBox(height: 6),
            Text(
              _confirming ? 'Confirm your PIN' : 'Enter a new PIN',
              style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: _sub),
            ),
            const SizedBox(height: 20),

            // Digit length toggle
            if (!_confirming)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [4, 6].map((d) {
                  final active = _digits == d;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _digits = d;
                      _pin = '';
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primary
                            : AppColors.primary.withAlpha(18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$d digit',
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w800,
                            color: active ? Colors.white : AppColors.primary,
                          )),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 20),

            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_digits, (i) {
                final filled = i < current.length;
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
                          : _sub.withAlpha(120),
                      width: 2,
                    ),
                  ),
                );
              }),
            ),

            // Error
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Nunito',
                      color: AppColors.expense)),
            ],

            const SizedBox(height: 24),

            // Numpad
            _Numpad(onDigit: _onKey, onDelete: _onDelete, sub: _sub, tc: _tc),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NUMPAD
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
            if (k.isEmpty) return const SizedBox(width: 72, height: 56);
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
                width: 72,
                height: 56,
                alignment: Alignment.center,
                child: Text(
                  k,
                  style: TextStyle(
                    fontSize: k == '⌫' ? 20 : 22,
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
