import 'package:flutter/material.dart';

// ── Overlay-based toast ──────────────────────────────────────────────────────
// Shows a floating, auto-dismissing message via the root Overlay instead of
// ScaffoldMessenger/SnackBar. A SnackBar needs a Scaffold ancestor to host it,
// and — critically — if that Scaffold belongs to the page *underneath* an
// open modal bottom sheet, the SnackBar renders stacked below the sheet's
// route and stays invisible until the sheet closes. An Overlay entry has no
// such requirement: it floats above every route, sheet included, so it's the
// right choice for any error/status message that might fire while a sheet is
// still on screen (e.g. a save failing while its bottom sheet hasn't closed).

void showOverlayToast(
  BuildContext context,
  String message, {
  Color backgroundColor = Colors.black87,
  Duration duration = const Duration(seconds: 4),
}) {
  final overlay = Overlay.of(context, rootOverlay: true);

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _OverlayToast(message: message, backgroundColor: backgroundColor),
  );
  overlay.insert(entry);

  Future.delayed(duration, () {
    if (entry.mounted) entry.remove();
  });
}

class _OverlayToast extends StatelessWidget {
  final String message;
  final Color backgroundColor;
  const _OverlayToast({required this.message, required this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 32,
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontFamily: 'Nunito',
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
