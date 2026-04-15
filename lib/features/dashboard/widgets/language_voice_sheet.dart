import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/core/services/app_prefs.dart';
import '_prefs_sheet_base.dart';

class LanguageVoiceSheet extends StatefulWidget {
  final bool isDark;
  const LanguageVoiceSheet({super.key, required this.isDark});
  @override
  State<LanguageVoiceSheet> createState() => _LanguageVoiceSheetState();
}

class _LanguageVoiceSheetState extends State<LanguageVoiceSheet> {
  final _p = AppPrefs.instance;
  bool _loading = true;

  // Both collapsed by default
  bool _appLangExpanded   = false;
  bool _voiceLangExpanded = false;

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
      title: '🌐  Language & Voice',
      loading: _loading,
      child: ListenableBuilder(
        listenable: _p,
        builder: (_, _) {
          final isDark = widget.isDark;
          final surf   = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
          final tc     = isDark ? AppColors.textDark : AppColors.textLight;
          final sub    = isDark ? AppColors.subDark  : AppColors.subLight;
          final div    = isDark
              ? Colors.white.withAlpha(18)
              : Colors.black.withAlpha(18);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── App Language ───────────────────────────────────────────
              _SectionHeader(
                label: 'App Language',
                subtitle: 'Changes UI text across the app',
                selectedLabel: _labelFor(_p.appLanguage),
                expanded: _appLangExpanded,
                isDark: isDark,
                onTap: () =>
                    setState(() => _appLangExpanded = !_appLangExpanded),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: _appLangExpanded
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: _LangList(
                  surf: surf, tc: tc, sub: sub, div: div,
                  selected: _p.appLanguage,
                  onSelect: (v) => setState(() => _p.appLanguage = v),
                ),
                secondChild: const SizedBox.shrink(),
              ),

              const SizedBox(height: 20),

              // ── Voice Input Language ───────────────────────────────────
              _SectionHeader(
                label: 'Voice Input Language',
                subtitle: 'Language used for speech-to-text',
                selectedLabel: _labelFor(_p.voiceLanguage),
                expanded: _voiceLangExpanded,
                isDark: isDark,
                onTap: () =>
                    setState(() => _voiceLangExpanded = !_voiceLangExpanded),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: _voiceLangExpanded
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: _LangList(
                  surf: surf, tc: tc, sub: sub, div: div,
                  selected: _p.voiceLanguage,
                  onSelect: (v) => setState(() => _p.voiceLanguage = v),
                ),
                secondChild: const SizedBox.shrink(),
              ),
            ],
          );
        },
      ),
    );
  }

  String _labelFor(String code) =>
      AppPrefs.languages
          .firstWhere((l) => l.code == code,
              orElse: () => AppPrefs.languages.first)
          .label;
}

// ── Collapsible section header ────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final String subtitle;
  final String selectedLabel;
  final bool expanded;
  final bool isDark;
  final VoidCallback onTap;

  const _SectionHeader({
    required this.label,
    required this.subtitle,
    required this.selectedLabel,
    required this.expanded,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc  = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark  : AppColors.subLight;

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
                  if (!expanded) ...[
                    const SizedBox(height: 2),
                    Text(
                      selectedLabel,
                      style: TextStyle(
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

// ── Language list ─────────────────────────────────────────────────────────────

class _LangList extends StatelessWidget {
  final Color surf, tc, sub, div;
  final String selected;
  final ValueChanged<String> onSelect;

  const _LangList({
    required this.surf,
    required this.tc,
    required this.sub,
    required this.div,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration:
          BoxDecoration(color: surf, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: AppPrefs.languages.asMap().entries.map((e) {
          final lang    = e.value;
          final active  = lang.code == selected;
          final enabled = lang.code == 'en';

          return Column(
            children: [
              if (e.key > 0) Divider(height: 1, color: div, indent: 16),
              Opacity(
                opacity: enabled ? 1.0 : 0.38,
                child: InkWell(
                  onTap: enabled ? () => onSelect(lang.code) : null,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    lang.label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontFamily: 'Nunito',
                                      fontWeight: FontWeight.w800,
                                      color: active ? AppColors.primary : tc,
                                    ),
                                  ),
                                  if (!enabled) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: sub.withAlpha(30),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Coming soon',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontFamily: 'Nunito',
                                          fontWeight: FontWeight.w700,
                                          color: sub,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                lang.native,
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
                              size: 20, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
