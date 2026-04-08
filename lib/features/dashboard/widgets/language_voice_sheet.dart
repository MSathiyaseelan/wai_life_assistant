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

  @override
  void initState() {
    super.initState();
    _p.init().then((_) { if (mounted) setState(() => _loading = false); });
  }

  @override
  Widget build(BuildContext context) {
    return PrefsSheetBase(
      isDark: widget.isDark,
      title: '🌐  Language & Voice',
      loading: _loading,
      child: ListenableBuilder(
        listenable: _p,
        builder: (_, _) => Column(
          children: [
            _LangSection(
              isDark: widget.isDark,
              heading: 'App Language',
              subtitle: 'Changes UI text across the app (restart may be needed)',
              selected: _p.appLanguage,
              onSelect: (v) => setState(() => _p.appLanguage = v),
            ),
            const SizedBox(height: 16),
            _LangSection(
              isDark: widget.isDark,
              heading: 'Voice Input Language',
              subtitle: 'Language used for speech-to-text recognition',
              selected: _p.voiceLanguage,
              onSelect: (v) => setState(() => _p.voiceLanguage = v),
            ),
          ],
        ),
      ),
    );
  }
}

class _LangSection extends StatelessWidget {
  final bool isDark;
  final String heading;
  final String subtitle;
  final String selected;
  final ValueChanged<String> onSelect;

  const _LangSection({
    required this.isDark,
    required this.heading,
    required this.subtitle,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final surf = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final tc   = isDark ? AppColors.textDark : AppColors.textLight;
    final sub  = isDark ? AppColors.subDark  : AppColors.subLight;
    final div  = isDark
        ? Colors.white.withAlpha(18)
        : Colors.black.withAlpha(18);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(heading,
                  style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w900,
                      color: tc)),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 11, fontFamily: 'Nunito', color: sub)),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: surf, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: AppPrefs.languages.asMap().entries.map((e) {
              final lang = e.value;
              final active = lang.code == selected;
              return Column(
                children: [
                  if (e.key > 0) Divider(height: 1, color: div, indent: 16),
                  InkWell(
                    onTap: () => onSelect(lang.code),
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
                                Text(lang.label,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontFamily: 'Nunito',
                                        fontWeight: FontWeight.w800,
                                        color: active
                                            ? AppColors.primary
                                            : tc)),
                                Text(lang.native,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'Nunito',
                                        color: sub)),
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
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
