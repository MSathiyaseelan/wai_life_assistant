import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/core/services/app_prefs.dart';
import '_prefs_sheet_base.dart';

class AiParserSheet extends StatefulWidget {
  final bool isDark;
  const AiParserSheet({super.key, required this.isDark});
  @override
  State<AiParserSheet> createState() => _AiParserSheetState();
}

class _AiParserSheetState extends State<AiParserSheet> {
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
      title: '✦  AI Parser',
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
              // ── Confirm sheet toggle ──────────────────────────────────
              PrefsSectionLabel('Behaviour', isDark: isDark),
              PrefsCard(
                isDark: isDark,
                children: [
                  PrefsSwitchTile(
                    isDark: isDark,
                    emoji: '🔍',
                    title: 'Always show confirm sheet',
                    subtitle: _p.aiAlwaysConfirm
                        ? 'Review every parsed result before saving'
                        : 'Auto-save when confidence > 90%',
                    value: _p.aiAlwaysConfirm,
                    onChanged: (v) => setState(() => _p.aiAlwaysConfirm = v),
                  ),
                ],
              ),

              // Info note
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 20),
                child: Text(
                  _p.aiAlwaysConfirm
                      ? 'The confirm sheet will always appear after parsing.'
                      : 'When the AI is confident (≥90%), the transaction is saved automatically. A confirm sheet still appears for low-confidence results.',
                  style: TextStyle(
                      fontSize: 11, fontFamily: 'Nunito', color: sub),
                ),
              ),

              // ── Voice input language ──────────────────────────────────
              PrefsSectionLabel('Voice Input Language', isDark: isDark),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  'Primary language the microphone listens for',
                  style: TextStyle(
                      fontSize: 11, fontFamily: 'Nunito', color: sub),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                    color: surf, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: AppPrefs.languages.asMap().entries.map((e) {
                    final lang   = e.value;
                    final active = _p.aiVoiceLanguage == lang.code;
                    return Column(
                      children: [
                        if (e.key > 0) Divider(height: 1, color: div, indent: 16),
                        InkWell(
                          onTap: () => setState(() => _p.aiVoiceLanguage = lang.code),
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
        },
      ),
    );
  }
}
