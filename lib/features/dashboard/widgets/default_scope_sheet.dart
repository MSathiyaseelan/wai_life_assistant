import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/core/services/app_prefs.dart';
import 'package:wai_life_assistant/core/supabase/profile_service.dart';
import '_prefs_sheet_base.dart';

class DefaultScopeSheet extends StatefulWidget {
  final bool isDark;
  const DefaultScopeSheet({super.key, required this.isDark});
  @override
  State<DefaultScopeSheet> createState() => _DefaultScopeSheetState();
}

class _DefaultScopeSheetState extends State<DefaultScopeSheet> {
  final _p = AppPrefs.instance;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _p.init().then((_) { if (mounted) setState(() => _loading = false); });
  }

  void _persist() {
    ProfileService.instance.updateDefaultScopes(
      walletScope: _p.walletScope,
      pantryScope: _p.pantryScope,
      planItScope: _p.planItScope,
    ).catchError((e) => debugPrint('[DefaultScope] persist error: $e'));
  }

  @override
  Widget build(BuildContext context) {
    return PrefsSheetBase(
      isDark: widget.isDark,
      title: '🏠  Default Scope',
      loading: _loading,
      child: ListenableBuilder(
        listenable: _p,
        builder: (_, _) {
          final isDark = widget.isDark;
          final surf = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
          final tc   = isDark ? AppColors.textDark : AppColors.textLight;
          final sub  = isDark ? AppColors.subDark  : AppColors.subLight;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withAlpha(40)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'When opening each tab, which wallet context should load first?',
                        style: TextStyle(
                            fontSize: 12, fontFamily: 'Nunito', color: sub),
                      ),
                    ),
                  ],
                ),
              ),

              // Wallet
              PrefsSectionLabel('Wallet', isDark: isDark),
              _ScopePicker(
                isDark: isDark, surf: surf, tc: tc,
                value: _p.walletScope,
                onChanged: (v) { setState(() => _p.walletScope = v); _persist(); },
              ),
              const SizedBox(height: 16),

              // Pantry
              PrefsSectionLabel('Pantry', isDark: isDark),
              _ScopePicker(
                isDark: isDark, surf: surf, tc: tc,
                value: _p.pantryScope,
                onChanged: (v) { setState(() => _p.pantryScope = v); _persist(); },
              ),
              const SizedBox(height: 16),

              // PlanIt
              PrefsSectionLabel('PlanIt', isDark: isDark),
              _ScopePicker(
                isDark: isDark, surf: surf, tc: tc,
                value: _p.planItScope,
                onChanged: (v) { setState(() => _p.planItScope = v); _persist(); },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ScopePicker extends StatelessWidget {
  final bool isDark;
  final Color surf;
  final Color tc;
  final String value;
  final ValueChanged<String> onChanged;

  const _ScopePicker({
    required this.isDark,
    required this.surf,
    required this.tc,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
          color: surf, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: ['personal', 'family'].map((scope) {
          final active = value == scope;
          final label  = scope == 'personal' ? '👤  Personal' : '👨‍👩‍👧  Family';
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(scope),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13, fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        color: active ? Colors.white : tc)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
