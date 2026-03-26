import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/pantry/pantry_models.dart';
import '../sheets/add_meal_sheet.dart';

class MealMapSection extends StatefulWidget {
  final List<MealEntry> meals;
  final List<RecipeModel> recipes;
  final DateTime selectedDate;
  final String walletId;
  final void Function(MealEntry meal) onMealAdded;
  final void Function(MealEntry meal)? onMealUpdated;
  final void Function(MealEntry meal) onMealTapped;

  // Copy / paste
  final List<MealEntry>? clipboardMeals;
  final String clipboardLabel;
  final bool clipboardIsWeek;
  final void Function(MealEntry meal)? onCopyMeal;
  final void Function(DateTime day)? onCopyDay;
  final void Function(DateTime day)? onPasteToDay;
  final void Function(DateTime weekStart)? onCopyWeek;
  final void Function(DateTime weekStart)? onPasteToWeek;
  final VoidCallback? onClearClipboard;

  const MealMapSection({
    super.key,
    required this.meals,
    required this.recipes,
    required this.selectedDate,
    required this.walletId,
    required this.onMealAdded,
    required this.onMealTapped,
    this.onMealUpdated,
    this.clipboardMeals,
    this.clipboardLabel = '',
    this.clipboardIsWeek = false,
    this.onCopyMeal,
    this.onCopyDay,
    this.onPasteToDay,
    this.onCopyWeek,
    this.onPasteToWeek,
    this.onClearClipboard,
  });

  @override
  State<MealMapSection> createState() => _MealMapSectionState();
}

class _MealMapSectionState extends State<MealMapSection> {
  final _scrollCtrl = ScrollController();
  static const _columnWidth = 140.0; // 130 card + 10 margin

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToToday());
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToToday() {
    if (!_scrollCtrl.hasClients) return;
    // weekday: Mon=1 … Sun=7 → index 0…6
    final todayIndex = widget.selectedDate.weekday - 1;
    final offset = (todayIndex * _columnWidth).clamp(
      0.0,
      _scrollCtrl.position.maxScrollExtent,
    );
    _scrollCtrl.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // Get 7-day window starting from Monday of selectedDate's week
  List<DateTime> get _weekDays {
    final start = widget.selectedDate.subtract(
      Duration(days: widget.selectedDate.weekday - 1),
    ); // Monday
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  List<MealEntry> _mealsForDay(DateTime day) =>
      widget.meals
          .where(
            (m) =>
                m.walletId == widget.walletId &&
                m.date.year == day.year &&
                m.date.month == day.month &&
                m.date.day == day.day,
          )
          .toList()
        ..sort((a, b) => a.mealTime.index.compareTo(b.mealTime.index));

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  bool get _hasClipboard =>
      widget.clipboardMeals != null && widget.clipboardMeals!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final days = _weekDays;
    final weekStart = days.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header — actions only (title shown in tab bar)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: [
              const Spacer(),
              // Copy week
              _IconAction(
                icon: Icons.copy_rounded,
                tooltip: 'Copy week',
                onTap: () => widget.onCopyWeek?.call(weekStart),
              ),
              // Paste week (only when clipboard has week data)
              if (_hasClipboard && widget.clipboardIsWeek) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => widget.onPasteToWeek?.call(weekStart),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.content_paste_rounded,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Paste Week',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Clipboard banner
        if (_hasClipboard)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.copy_rounded,
                    size: 13,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Copied: ${widget.clipboardLabel}  •  Long-press a day to paste',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onClearClipboard,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          const SizedBox(height: 8),

        // Horizontal scroll of day columns — starts at today's column
        SizedBox(
          height: 260,
          child: ListView.builder(
            controller: _scrollCtrl,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16, right: 8),
            itemCount: days.length,
            itemBuilder: (_, i) {
              final day = days[i];
              final dayMeals = _mealsForDay(day);
              final isToday = _isToday(day);
              final isSel =
                  day.day == widget.selectedDate.day &&
                  day.month == widget.selectedDate.month &&
                  day.year == widget.selectedDate.year;

              return _DayColumn(
                day: day,
                dayName: _dayNames[i],
                meals: dayMeals,
                isToday: isToday,
                isSelected: isSel,
                walletId: widget.walletId,
                isDark: isDark,
                hasClipboard: _hasClipboard,
                clipboardLabel: widget.clipboardLabel,
                onAddMeal: (dt) async {
                  await AddMealSheet.show(
                    context,
                    date: dt,
                    walletId: widget.walletId,
                    recipes: widget.recipes,
                    onSave: widget.onMealAdded,
                    onUpdate: widget.onMealUpdated,
                    dayMeals: dayMeals,
                  );
                },
                onMealTapped: widget.onMealTapped,
                onCopyDay: widget.onCopyDay,
                onPasteToDay: widget.onPasteToDay,
                onCopyMeal: widget.onCopyMeal,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Day column card ────────────────────────────────────────────────────────────

class _DayColumn extends StatelessWidget {
  final DateTime day;
  final String dayName;
  final List<MealEntry> meals;
  final bool isToday, isSelected, isDark;
  final String walletId;
  final bool hasClipboard;
  final String clipboardLabel;
  final void Function(DateTime) onAddMeal;
  final void Function(MealEntry) onMealTapped;
  final void Function(DateTime)? onCopyDay;
  final void Function(DateTime)? onPasteToDay;
  final void Function(MealEntry)? onCopyMeal;

  const _DayColumn({
    required this.day,
    required this.dayName,
    required this.meals,
    required this.isToday,
    required this.isSelected,
    required this.isDark,
    required this.walletId,
    required this.onAddMeal,
    required this.onMealTapped,
    this.hasClipboard = false,
    this.clipboardLabel = '',
    this.onCopyDay,
    this.onPasteToDay,
    this.onCopyMeal,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final border = isSelected
        ? AppColors.primary
        : isToday
        ? AppColors.income.withOpacity(0.5)
        : Colors.transparent;

    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: isSelected ? 2 : 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Day header — long-press to copy/paste
          GestureDetector(
            onLongPress: () {
              HapticFeedback.mediumImpact();
              _showDayCopyMenu(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : isToday
                    ? AppColors.income.withOpacity(0.12)
                    : (isDark ? AppColors.surfDark : AppColors.bgLight),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    dayName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Nunito',
                      color: isSelected
                          ? Colors.white70
                          : (isDark ? AppColors.subDark : AppColors.subLight),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                      color: isSelected
                          ? Colors.white
                          : isToday
                          ? AppColors.income
                          : (isDark ? AppColors.textDark : AppColors.textLight),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Meal slots
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  ...meals.map(
                    (m) => _MealChip(
                      meal: m,
                      isDark: isDark,
                      onTap: () => onMealTapped(m),
                      onLongPress: onCopyMeal != null
                          ? () => onCopyMeal!(m)
                          : null,
                    ),
                  ),

                  // Add button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onAddMeal(day);
                    },
                    child: Container(
                      margin: EdgeInsets.only(top: meals.isNotEmpty ? 4 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.25),
                          width: 1,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              fontFamily: 'Nunito',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDayCopyMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final label = '$dayName ${day.day}';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w900,
                fontFamily: 'Nunito', color: tc,
              ),
            ),
            const SizedBox(height: 14),
            _SheetOption(
              icon: Icons.copy_rounded,
              color: AppColors.primary,
              title: 'Copy "$label" meals',
              subtitle: meals.isEmpty ? 'No meals to copy' : '${meals.length} meal${meals.length == 1 ? '' : 's'}',
              enabled: meals.isNotEmpty,
              onTap: () {
                Navigator.pop(context);
                onCopyDay?.call(day);
              },
            ),
            if (hasClipboard) ...[
              const SizedBox(height: 10),
              _SheetOption(
                icon: Icons.content_paste_rounded,
                color: AppColors.income,
                title: 'Paste here',
                subtitle: clipboardLabel,
                onTap: () {
                  Navigator.pop(context);
                  onPasteToDay?.call(day);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Meal chip inside day column ────────────────────────────────────────────────

class _MealChip extends StatelessWidget {
  final MealEntry meal;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _MealChip({
    required this.meal,
    required this.isDark,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = meal.mealTime.color;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: c.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.withOpacity(0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(meal.mealTime.emoji, style: const TextStyle(fontSize: 9)),
                const SizedBox(width: 3),
                Text(
                  meal.mealTime.label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: c,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${meal.emoji} ${meal.name}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'Nunito',
                color: isDark ? AppColors.textDark : AppColors.textLight,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (meal.reactions.isNotEmpty) ...[
              const SizedBox(height: 4),
              _ReactionBadgeRow(reactions: meal.reactions),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReactionBadgeRow extends StatelessWidget {
  final List<MealReaction> reactions;
  const _ReactionBadgeRow({required this.reactions});

  @override
  Widget build(BuildContext context) {
    // Count each emoji
    final counts = <String, int>{};
    for (final r in reactions) {
      counts[r.reactionEmoji] = (counts[r.reactionEmoji] ?? 0) + 1;
    }
    return Row(
      children: [
        const Icon(Icons.chat_bubble_outline_rounded, size: 9, color: AppColors.primary),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            counts.entries.map((e) => '${e.key}${e.value > 1 ? e.value : ''}').join(' '),
            style: const TextStyle(fontSize: 9, color: AppColors.primary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Today's Plate section ──────────────────────────────────────────────────────

class TodaysPlateSection extends StatelessWidget {
  final List<MealEntry> todayMeals;
  final String walletId;
  final bool isDark;
  final void Function(MealEntry) onMealTapped;
  final VoidCallback onAddMeal;

  const TodaysPlateSection({
    super.key,
    required this.todayMeals,
    required this.walletId,
    required this.isDark,
    required this.onMealTapped,
    required this.onAddMeal,
  });

  @override
  Widget build(BuildContext context) {
    final mealsByTime = <MealTime, List<MealEntry>>{};
    for (final m in todayMeals) {
      mealsByTime.putIfAbsent(m.mealTime, () => []).add(m);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            children: [
              const Text('🍽️', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text(
                "Today's Plate",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onAddMeal,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Add Meal',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        if (todayMeals.isEmpty)
          _EmptyMealState(isDark: isDark, onAdd: onAddMeal)
        else
          ...MealTime.values.map((mt) {
            final meals = mealsByTime[mt] ?? [];
            return _MealTimeRow(
              mealTime: mt,
              meals: meals,
              isDark: isDark,
              onMealTapped: onMealTapped,
            );
          }),
      ],
    );
  }
}

class _MealTimeRow extends StatelessWidget {
  final MealTime mealTime;
  final List<MealEntry> meals;
  final bool isDark;
  final void Function(MealEntry) onMealTapped;

  const _MealTimeRow({
    required this.mealTime,
    required this.meals,
    required this.isDark,
    required this.onMealTapped,
  });

  @override
  Widget build(BuildContext context) {
    final c = mealTime.color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time label column
          SizedBox(
            width: 78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${mealTime.emoji}  ${mealTime.label}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    color: c,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Meals
          Expanded(
            child: meals.isEmpty
                ? Text(
                    'Nothing planned',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Nunito',
                      color: isDark ? AppColors.subDark : AppColors.subLight,
                    ),
                  )
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: meals
                        .map(
                          (m) => GestureDetector(
                            onTap: () => onMealTapped(m),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.cardDark
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: c.withOpacity(0.3)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                '${m.emoji} ${m.name}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Nunito',
                                  color: isDark
                                      ? AppColors.textDark
                                      : AppColors.textLight,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMealState extends StatelessWidget {
  final bool isDark;
  final VoidCallback onAdd;
  const _EmptyMealState({required this.isDark, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: onAdd,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: const Column(
            children: [
              Text('🍽️', style: TextStyle(fontSize: 32)),
              SizedBox(height: 8),
              Text(
                "Nothing on the table yet!",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Nunito',
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Tap to plan today's meals",
                style: TextStyle(fontSize: 12, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small icon action button ───────────────────────────────────────────────────

class _IconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _IconAction({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfDark
                : AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 15, color: AppColors.primary),
        ),
      ),
    );
  }
}

// ── Sheet option row ───────────────────────────────────────────────────────────

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito', color: tc,
                    )),
                    if (subtitle.isNotEmpty)
                      Text(subtitle, style: TextStyle(
                        fontSize: 11, fontFamily: 'Nunito', color: sub,
                      )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
