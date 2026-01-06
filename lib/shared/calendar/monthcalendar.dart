import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wai_life_assistant/shared/calendar/yearcalendar.dart';

class MonthCalendar extends StatefulWidget {
  final DateTime selectedDate;

  const MonthCalendar({super.key, required this.selectedDate});

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  late DateTime focusedMonth;
  final DateTime today = DateTime.now();

  @override
  void initState() {
    super.initState();
    focusedMonth = widget.selectedDate;
  }

  void _openYearView() async {
    final pickedMonth = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      builder: (_) => YearCalendar(selectedDate: focusedMonth),
    );

    if (pickedMonth != null) {
      setState(() => focusedMonth = pickedMonth);
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(
      focusedMonth.year,
      focusedMonth.month,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          /// Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    focusedMonth = DateTime(
                      focusedMonth.year,
                      focusedMonth.month - 1,
                    );
                  });
                },
              ),

              InkWell(
                onTap: _openYearView,
                child: Text(
                  DateFormat('MMMM yyyy').format(focusedMonth),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    focusedMonth = DateTime(
                      focusedMonth.year,
                      focusedMonth.month + 1,
                    );
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 12),

          /// Days Grid
          GridView.builder(
            shrinkWrap: true,
            itemCount: daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final day = DateTime(
                focusedMonth.year,
                focusedMonth.month,
                index + 1,
              );

              final isSelected = DateUtils.isSameDay(day, widget.selectedDate);

              final isToday = DateUtils.isSameDay(day, today);

              return InkWell(
                onTap: () => Navigator.pop(context, day),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? Theme.of(context).primaryColor : null,
                    border: isToday
                        ? Border.all(
                            color: Theme.of(context).primaryColor,
                            width: 2,
                          )
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight: isToday || isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
