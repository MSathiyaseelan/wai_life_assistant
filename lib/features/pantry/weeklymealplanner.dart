import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

          final mealCard = Container(
            key: _dayKeys[_normalize(day)],
            width: 200, // 🔑 card width
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
            child: _MealDayCard(day: day, isSelected: isSelected),
          );
          // if (index == 0) {
          //       return Column(
          //         crossAxisAlignment: CrossAxisAlignment.start,
          //         children: [
          //           Padding(
          //             padding: const EdgeInsets.symmetric(
          //               horizontal: 16,
          //               vertical: 4,
          //             ),
          //             child: Text(
          //               'Upcoming Meals',
          //               style: Theme.of(context).textTheme.titleSmall,
          //             ),
          //           ),
          //           mealCard,
          //         ],
          //       );
          //     }

          return mealCard;
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

  const _MealDayCard({required this.day, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('EEEE, dd MMM').format(day),
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        _MealRow('Breakfast', 'Idli'),
        _MealRow('Lunch', 'Rice & Curry'),
        _MealRow('Dinner', 'Chapati'),
        _MealRow('Snacks', 'Fruits'),
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
