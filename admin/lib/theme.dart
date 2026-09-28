import 'package:flutter/material.dart';

/// Colours used by the dashboard. Chart series colour follows the dataviz
/// reference palette (slot 1), stepped separately for light and dark.
class AdminTheme {
  static const _seed = Color(0xFF5B5BD6);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: b);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: b == Brightness.light ? const Color(0xFFF6F6F4) : const Color(0xFF121212),
      cardTheme: CardThemeData(
        elevation: 0,
        color: b == Brightness.light ? const Color(0xFFFCFCFB) : const Color(0xFF1A1A19),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        margin: EdgeInsets.zero,
      ),
      dataTableTheme: const DataTableThemeData(headingRowHeight: 40, dataRowMinHeight: 44),
    );
  }

  static Color series(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFF3987E5) : const Color(0xFF2A78D6);

  static Color chartSurface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1A19) : const Color(0xFFFCFCFB);
}

/// Reserved status colours — always shown with a label, never alone.
enum StatusTone { good, warning, serious, critical, neutral }

extension StatusToneColor on StatusTone {
  Color color(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch (this) {
      StatusTone.good => dark ? const Color(0xFF3FB950) : const Color(0xFF1A7F37),
      StatusTone.warning => dark ? const Color(0xFFD29922) : const Color(0xFF9A6700),
      StatusTone.serious => dark ? const Color(0xFFF0883E) : const Color(0xFFBC4C00),
      StatusTone.critical => dark ? const Color(0xFFF85149) : const Color(0xFFCF222E),
      StatusTone.neutral => Theme.of(context).colorScheme.onSurfaceVariant,
    };
  }
}
