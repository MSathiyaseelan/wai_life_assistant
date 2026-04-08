import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/core/services/app_prefs.dart';
import '_prefs_sheet_base.dart';

class DateTimePrefsSheet extends StatefulWidget {
  final bool isDark;
  const DateTimePrefsSheet({super.key, required this.isDark});
  @override
  State<DateTimePrefsSheet> createState() => _DateTimePrefsSheetState();
}

class _DateTimePrefsSheetState extends State<DateTimePrefsSheet> {
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
      title: '📅  Date & Time',
      loading: _loading,
      child: ListenableBuilder(
        listenable: _p,
        builder: (_, _) {
          final isDark = widget.isDark;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Date format ───────────────────────────────────────────
              PrefsSectionLabel('Date Format', isDark: isDark),
              PrefsCard(
                isDark: isDark,
                children: AppPrefs.dateFormats.map((f) => PrefsRadioTile(
                  isDark: isDark,
                  label: f.label,
                  sublabel: 'e.g. ${f.example}',
                  active: _p.dateFormat == f.key,
                  onTap: () => setState(() => _p.dateFormat = f.key),
                )).toList(),
              ),

              const SizedBox(height: 20),

              // ── Week starts on ────────────────────────────────────────
              PrefsSectionLabel('Week Starts On', isDark: isDark),
              _WeekStartPicker(isDark: isDark, prefs: _p,
                  onChanged: () => setState(() {})),
            ],
          );
        },
      ),
    );
  }
}

class _WeekStartPicker extends StatelessWidget {
  final bool isDark;
  final AppPrefs prefs;
  final VoidCallback onChanged;
  const _WeekStartPicker(
      {required this.isDark, required this.prefs, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final surf = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final tc   = isDark ? AppColors.textDark : AppColors.textLight;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: surf, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: Text('First day of week',
                style: TextStyle(
                    fontSize: 13, fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800, color: tc)),
          ),
          const SizedBox(width: 12),
          Row(
            children: ['sunday', 'monday'].map((day) {
              final active = prefs.weekStartsOn == day;
              final label = day == 'sunday' ? 'Sun' : 'Mon';
              return GestureDetector(
                onTap: () {
                  prefs.weekStartsOn = day;
                  onChanged();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary
                        : AppColors.primary.withAlpha(18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 13, fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          color: active ? Colors.white : AppColors.primary)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
