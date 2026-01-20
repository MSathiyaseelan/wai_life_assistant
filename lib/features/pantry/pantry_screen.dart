import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'weeklymealplanner.dart';
import 'package:wai_life_assistant/core/theme/app_text.dart';
import 'bottomsheet/showpantrybottomsheet.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppText.pantryTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              showPantryBottomSheet(context);
            },
          ),
        ],
      ),

      //resizeToAvoidBottomInset: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 1️⃣ Calendar
          _WeeklyCalendar(
            selectedDate: _selectedDate,
            onDateSelected: (d) {
              setState(() => _selectedDate = d);
            },
          ),

          const SizedBox(height: 8),

          Text(
            'Upcoming Food Planner',
            style: textTheme.titleMedium,
            textAlign: TextAlign.left,
          ),

          /// 2️⃣ Weekly planner (compact)
          //Expanded(child: WeeklyMealPlanner(selectedDate: _selectedDate)),
          SizedBox(
            height: 160,
            child: WeeklyMealPlanner(selectedDate: _selectedDate),
          ),

          //const Divider(),

          /// 3️⃣ Today's detail
          //Expanded(child: _TodayMealDetail(date: _selectedDate)),
          Expanded(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom:
                    MediaQuery.of(context).viewInsets.bottom +
                    MediaQuery.of(context).padding.bottom,
              ),
              child: _TodayMealDetail(date: _selectedDate),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyCalendar extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _WeeklyCalendar({
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final weekStart = _startOfWeek(selectedDate);
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    return Row(
      children: [
        /// ⬅ Previous week
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            onDateSelected(selectedDate.subtract(const Duration(days: 7)));
          },
        ),

        /// Days (FIXED)
        Expanded(
          child: Row(
            children: days.map((day) {
              final isSelected = _isSameDay(day, selectedDate);

              return Expanded(
                child: GestureDetector(
                  onTap: () => onDateSelected(day),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        /// Day name
                        Text(
                          DateFormat('EEE').format(day),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? Colors.white
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                        ),

                        const SizedBox(height: 4),

                        /// Date
                        Text(
                          day.day.toString(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        /// ➡ Next week
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            onDateSelected(selectedDate.add(const Duration(days: 7)));
          },
        ),
      ],
    );
  }

  DateTime _startOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _WeeklyMealPlanner extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDayTap;

  const _WeeklyMealPlanner({
    required this.selectedDate,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      scrollDirection: Axis.horizontal,
      itemCount: 7,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final day = DateTime.now().add(Duration(days: index));

        return GestureDetector(
          onTap: () => onDayTap(day),
          child: Container(
            width: 130,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: day.day == selectedDate.day
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surface,
              boxShadow: const [
                BoxShadow(blurRadius: 4, color: Colors.black12),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Mon', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text('B: Idli'),
                Text('L: Rice'),
                Text('D: Chapati'),
                Text('S: Fruits'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TodayMealDetail extends StatelessWidget {
  final DateTime date;

  const _TodayMealDetail({required this.date});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔒 Sticky header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Today\'s Meals', style: textTheme.titleMedium),
        ),

        // 📜 Scrollable content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              _MealSection(title: 'Breakfast', value: 'Idli & Chutney'),
              _MealSection(title: 'Lunch', value: 'Sambar Rice'),
              _MealSection(title: 'Snacks', value: 'Tea & Fruits'),
              _MealSection(title: 'Dinner', value: 'Chapati & Kurma'),
            ],
          ),
        ),
      ],
    );
  }
}

class _MealSection extends StatelessWidget {
  final String title;
  final String value;

  const _MealSection({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(title),
        subtitle: Text(value),
        trailing: const Icon(Icons.edit),
      ),
    );
  }
}

// class PantryScreen extends StatelessWidget {
//   const PantryScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text(AppText.pantryTitle)),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
//             const SizedBox(height: 12),
//             const Text(
//               "Sathiya",
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 24),
//             _profileItem(Icons.settings, "Settings"),
//             _profileItem(Icons.lock, "Privacy"),
//             _profileItem(Icons.help, "Help & Support"),
//             _profileItem(Icons.logout, "Logout"),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _profileItem(IconData icon, String title) {
//     return ListTile(
//       leading: Icon(icon),
//       title: Text(title),
//       trailing: const Icon(Icons.arrow_forward_ios, size: 16),
//     );
//   }
// }
