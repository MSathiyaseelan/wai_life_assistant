import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared scaffold for all Preferences sub-sheets
// ─────────────────────────────────────────────────────────────────────────────

class PrefsSheetBase extends StatelessWidget {
  final bool isDark;
  final String title;
  final bool loading;
  final Widget child;

  const PrefsSheetBase({
    super.key,
    required this.isDark,
    required this.title,
    required this.loading,
    required this.child,
  });

  Color get _bg   => isDark ? AppColors.cardDark : AppColors.cardLight;
  Color get _tc   => isDark ? AppColors.textDark : AppColors.textLight;
  Color get _sub  => isDark ? AppColors.subDark  : AppColors.subLight;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: _sub.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 10),
            child: Row(
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 17,
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w900,
                        color: _tc)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: _sub, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Body
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                    children: [child],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable section label
// ─────────────────────────────────────────────────────────────────────────────

class PrefsSectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  const PrefsSectionLabel(this.text, {super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11, fontFamily: 'Nunito',
          fontWeight: FontWeight.w800, letterSpacing: 0.8, color: sub,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable card container
// ─────────────────────────────────────────────────────────────────────────────

class PrefsCard extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;
  const PrefsCard({super.key, required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    final surf = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final div  = isDark
        ? Colors.white.withAlpha(18)
        : Colors.black.withAlpha(18);
    return Container(
      decoration: BoxDecoration(
          color: surf, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: children.asMap().entries.map((e) => Column(
          children: [
            if (e.key > 0) Divider(height: 1, color: div, indent: 56),
            e.value,
          ],
        )).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable radio-style list tile
// ─────────────────────────────────────────────────────────────────────────────

class PrefsRadioTile extends StatelessWidget {
  final bool isDark;
  final String label;
  final String? sublabel;
  final bool active;
  final VoidCallback onTap;

  const PrefsRadioTile({
    super.key,
    required this.isDark,
    required this.label,
    this.sublabel,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc  = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark  : AppColors.subLight;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 13, fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          color: active ? AppColors.primary : tc)),
                  if (sublabel != null)
                    Text(sublabel!,
                        style: TextStyle(
                            fontSize: 11, fontFamily: 'Nunito', color: sub)),
                ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Reusable switch tile
// ─────────────────────────────────────────────────────────────────────────────

class PrefsSwitchTile extends StatelessWidget {
  final bool isDark;
  final String emoji;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const PrefsSwitchTile({
    super.key,
    required this.isDark,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tc  = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark  : AppColors.subLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13, fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800, color: tc)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11, fontFamily: 'Nunito', color: sub)),
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
  }
}
