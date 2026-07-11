import 'package:wai_life_assistant/core/services/app_prefs.dart';

/// Compact abbreviation for amounts >= 1,00,000 (1 lakh), used across the
/// Wallet feature's compact amount displays (wallet cards, tx tiles,
/// budgets, reports). Indian Lakh notation ("1.5L") only makes sense for
/// INR — for any other currency this falls back to a locale-neutral
/// M (million) suffix instead. Returns null below the threshold so callers
/// can fall through to their own smaller-amount formatting (e.g. "k").
String? formatLargeAmount(double v, {int decimals = 1}) {
  if (v < 100000) return null;
  if (AppPrefs.instance.primaryCurrency == 'INR') {
    return '${(v / 100000).toStringAsFixed(decimals)}L';
  }
  return '${(v / 1000000).toStringAsFixed(decimals)}M';
}
