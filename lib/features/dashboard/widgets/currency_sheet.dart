import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/core/services/app_prefs.dart';
import '_prefs_sheet_base.dart';

class CurrencySheet extends StatefulWidget {
  final bool isDark;
  const CurrencySheet({super.key, required this.isDark});
  @override
  State<CurrencySheet> createState() => _CurrencySheetState();
}

class _CurrencySheetState extends State<CurrencySheet> {
  final _p = AppPrefs.instance;
  bool _loading = true;
  bool _currencyExpanded = false;
  bool _symbolExpanded = false;

  @override
  void initState() {
    super.initState();
    _p.init().then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PrefsSheetBase(
      isDark: widget.isDark,
      title: '₹  Currency',
      loading: _loading,
      child: ListenableBuilder(
        listenable: _p,
        builder: (_, _) {
          final isDark = widget.isDark;
          final surf = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
          final tc   = isDark ? AppColors.textDark : AppColors.textLight;
          final sub  = isDark ? AppColors.subDark  : AppColors.subLight;
          final div  = isDark
              ? Colors.white.withAlpha(18)
              : Colors.black.withAlpha(18);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Primary Currency (collapsible) ────────────────────────
              _SectionHeader(
                label: 'Primary Currency',
                selectedLabel: '${_p.currentCurrency.symbol}  ${_p.currentCurrency.code}',
                expanded: _currencyExpanded,
                isDark: isDark,
                onTap: () =>
                    setState(() => _currencyExpanded = !_currencyExpanded),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: _currencyExpanded
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Container(
                  decoration: BoxDecoration(
                      color: surf, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: AppPrefs.currencies.asMap().entries.map((e) {
                      final c      = e.value;
                      final active = _p.primaryCurrency == c.code;
                      final enabled = c.code == 'INR';

                      return Column(
                        children: [
                          if (e.key > 0)
                            Divider(height: 1, color: div, indent: 16),
                          Opacity(
                            opacity: enabled ? 1.0 : 0.38,
                            child: InkWell(
                              onTap: enabled
                                  ? () => setState(
                                      () => _p.primaryCurrency = c.code)
                                  : null,
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    // Symbol chip
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: active
                                            ? AppColors.primary.withAlpha(20)
                                            : sub.withAlpha(20),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        c.symbol,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontFamily: 'Nunito',
                                          fontWeight: FontWeight.w900,
                                          color: active
                                              ? AppColors.primary
                                              : sub,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                c.code,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontFamily: 'Nunito',
                                                  fontWeight: FontWeight.w800,
                                                  color: active
                                                      ? AppColors.primary
                                                      : tc,
                                                ),
                                              ),
                                              if (!enabled) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        sub.withAlpha(30),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: Text(
                                                    'Coming soon',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontFamily: 'Nunito',
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: sub,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          Text(
                                            c.name,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontFamily: 'Nunito',
                                              color: sub,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (active)
                                      const Icon(Icons.check_circle_rounded,
                                          size: 20,
                                          color: AppColors.primary),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                secondChild: const SizedBox.shrink(),
              ),

              const SizedBox(height: 20),

              // ── Symbol Display (collapsible) ──────────────────────────
              _SectionHeader(
                label: 'Symbol Display',
                selectedLabel: _p.currencySymbol,
                expanded: _symbolExpanded,
                isDark: isDark,
                onTap: () =>
                    setState(() => _symbolExpanded = !_symbolExpanded),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: _symbolExpanded
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Container(
                  decoration: BoxDecoration(
                      color: surf, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      _displayOption('symbol', _p.currentCurrency.symbol,
                          'Symbol (e.g. ${_p.currentCurrency.symbol})',
                          div, tc, sub),
                      Divider(height: 1, color: div, indent: 16),
                      _displayOption('code', _p.currentCurrency.code,
                          'Code (e.g. ${_p.currentCurrency.code})',
                          div, tc, sub),
                      Divider(height: 1, color: div, indent: 16),
                      _displayOption(
                          'short', 'Rs', 'Short (e.g. Rs)', div, tc, sub),
                    ],
                  ),
                ),
                secondChild: const SizedBox.shrink(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _displayOption(
    String key,
    String preview,
    String description,
    Color div,
    Color tc,
    Color sub,
  ) {
    final active = _p.currencyDisplay == key;
    return InkWell(
      onTap: () => setState(() => _p.currencyDisplay = key),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 32,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primary.withAlpha(20)
                    : sub.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                preview,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w900,
                  color: active ? AppColors.primary : sub,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  color: active ? AppColors.primary : tc,
                ),
              ),
            ),
            if (active)
              const Icon(Icons.check_circle_rounded,
                  size: 20, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

// ── Section header with expand/collapse chevron ──────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final String? selectedLabel;
  final bool expanded;
  final bool isDark;
  final VoidCallback onTap;

  const _SectionHeader({
    required this.label,
    this.selectedLabel,
    required this.expanded,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final tc  = isDark ? AppColors.textDark : AppColors.textLight;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      color: sub,
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (!expanded && selectedLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      selectedLabel!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            AnimatedRotation(
              turns: expanded ? 0 : -0.25,
              duration: const Duration(milliseconds: 220),
              child: Icon(Icons.expand_more_rounded, size: 18, color: tc),
            ),
          ],
        ),
      ),
    );
  }
}
