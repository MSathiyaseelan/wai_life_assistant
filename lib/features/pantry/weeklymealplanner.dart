import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'mealplannerdetailpage.dart';
import 'package:wai_life_assistant/data/models/pandry/daymealplan.dart';

class WeeklyMealPlanner extends StatefulWidget {
  final DateTime selectedDate;

  const WeeklyMealPlanner({super.key, required this.selectedDate});

  @override
  State<WeeklyMealPlanner> createState() => _WeeklyMealPlannerState();
}

class _WeeklyMealPlannerState extends State<WeeklyMealPlanner> {
  final ScrollController _scrollController = ScrollController();

  //late final Map<DateTime, GlobalKey> _dayKeys;
  late Map<DateTime, GlobalKey> _dayKeys;

  final Map<DateTime, DayMealPlan> _mealPlans = {
    DateTime(2026, 1, 20): DayMealPlan(
      breakfast: 'Idli',
      lunch: 'Rice & Curry',
    ),
    DateTime(2026, 1, 22): DayMealPlan(dinner: 'Chapati'),
  };

  @override
  void initState() {
    super.initState();
    _buildKeys();
  }

  @override
  void didUpdateWidget(covariant WeeklyMealPlanner oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldWeek = _weekStart(oldWidget.selectedDate);
    final newWeek = _weekStart(widget.selectedDate);

    if (!_isSameDay(oldWeek, newWeek)) {
      _buildKeys();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDay();
    });
  }

  void _buildKeys() {
    final start = _normalize(DateTime.now().add(const Duration(days: 1)));

    _dayKeys = {
      for (int i = 0; i < 7; i++)
        _normalize(start.add(Duration(days: i))): GlobalKey(),
    };
  }

  void _scrollToSelectedDay() {
    final key = _dayKeys[_normalize(widget.selectedDate)];

    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.15,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = _weekStart(widget.selectedDate);
    final days = List.generate(7, (i) => start.add(Duration(days: i)));

    return SizedBox(
      height: 60, // 🔑 required for horizontal ListView
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = _isSameDay(day, widget.selectedDate);
          final normalizedDay = _normalize(day);
          final mealPlan = _mealPlans[normalizedDay];

          final mealCard = Container(
            key: _dayKeys[_normalize(day)],
            width: 200,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 6,
                  color: Colors.black12,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: GestureDetector(
              onTap: () {
                // later you will open edit/details page here
              },
              child: _MealDayCard(
                day: day,
                isSelected: isSelected,
                mealPlan: mealPlan,
              ),
            ),
          );

          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MealPlannerDetailPage(date: day),
                ),
              );
            },
            child: mealCard,
          );
        },
      ),
    );
  }

  // ---------------- Helpers ----------------

  DateTime _weekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _MealDayCard extends StatelessWidget {
  final DateTime day;
  final bool isSelected;
  final DayMealPlan? mealPlan;

  const _MealDayCard({
    required this.day,
    required this.isSelected,
    this.mealPlan,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    final isEmpty = mealPlan == null || mealPlan!.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// Date
        Text(
          DateFormat('EEEE, dd MMM').format(day),
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        /// Empty state
        if (isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No meals planned yet',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap to add meals',
                  style: textTheme.bodySmall?.copyWith(color: colors.primary),
                ),
              ],
            ),
          )
        else ...[
          if (mealPlan!.breakfast != null)
            _MealRow('Breakfast', mealPlan!.breakfast!),
          if (mealPlan!.lunch != null) _MealRow('Lunch', mealPlan!.lunch!),
          if (mealPlan!.dinner != null) _MealRow('Dinner', mealPlan!.dinner!),
          if (mealPlan!.snacks != null) _MealRow('Snacks', mealPlan!.snacks!),
        ],
      ],
    );
  }
}

class _MealRow extends StatelessWidget {
  final String label;
  final String value;

  const _MealRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
