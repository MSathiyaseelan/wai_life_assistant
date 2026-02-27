import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/pantry/pantry_models.dart';
import '../sheets/add_meal_sheet.dart';

class MealMapSection extends StatelessWidget {
  final List<MealEntry> meals;
  final DateTime selectedDate;
  final String walletId;
  final void Function(MealEntry meal) onMealAdded;
  final void Function(MealEntry meal) onMealTapped;

  const MealMapSection({
    super.key,
    required this.meals,
    required this.selectedDate,
    required this.walletId,
    required this.onMealAdded,
    required this.onMealTapped,
  });

  // Get 7-day window starting from Monday of selectedDate's week
  List<DateTime> get _weekDays {
    final start = selectedDate.subtract(
      Duration(days: selectedDate.weekday - 1),
    ); // Monday
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  List<MealEntry> _mealsForDay(DateTime day) =>
      meals
          .where(
            (m) =>
                m.walletId == walletId &&
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final days = _weekDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            children: [
              const Text('🗺️', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text(
                'Meal Map',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const Spacer(),
              _SectionBadge(label: 'This Week', color: const Color(0xFF6C63FF)),
            ],
          ),
        ),

        // Horizontal scroll of day columns
        SizedBox(
          height: 260,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16, right: 8),
            itemCount: days.length,
            itemBuilder: (_, i) {
              final day = days[i];
              final dayMeals = _mealsForDay(day);
              final isToday = _isToday(day);
              final isSel =
                  day.day == selectedDate.day &&
                  day.month == selectedDate.month &&
                  day.year == selectedDate.year;

              return _DayColumn(
                day: day,
                dayName: _dayNames[i],
                meals: dayMeals,
                isToday: isToday,
                isSelected: isSel,
                walletId: walletId,
                isDark: isDark,
                onAddMeal: (dt) async {
                  await AddMealSheet.show(
                    context,
                    date: dt,
                    walletId: walletId,
                    onSave: onMealAdded,
                  );
                },
                onMealTapped: onMealTapped,
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
  final void Function(DateTime) onAddMeal;
  final void Function(MealEntry) onMealTapped;

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
          // Day header
          Container(
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
}

// ── Meal chip inside day column ────────────────────────────────────────────────

class _MealChip extends StatelessWidget {
  final MealEntry meal;
  final bool isDark;
  final VoidCallback onTap;

  const _MealChip({
    required this.meal,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = meal.mealTime.color;
    return GestureDetector(
      onTap: onTap,
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
              meal.emoji + ' ' + meal.name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'Nunito',
                color: isDark ? AppColors.textDark : AppColors.textLight,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
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
                  mealTime.emoji + '  ' + mealTime.label,
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

class _SectionBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: color,
        fontFamily: 'Nunito',
      ),
    ),
  );
}
