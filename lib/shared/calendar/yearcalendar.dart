import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class YearCalendar extends StatefulWidget {
  final DateTime selectedDate;

  const YearCalendar({super.key, required this.selectedDate});

  @override
  State<YearCalendar> createState() => _YearCalendarState();
}

class _YearCalendarState extends State<YearCalendar> {
  late int focusedYear;
  final DateTime today = DateTime.now();

  @override
  void initState() {
    super.initState();
    focusedYear = widget.selectedDate.year;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          /// Year Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => focusedYear--),
              ),
              Text(
                focusedYear.toString(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => focusedYear++),
              ),
            ],
          ),

          const SizedBox(height: 16),

          /// Months Grid
          GridView.builder(
            shrinkWrap: true,
            itemCount: 12,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final monthDate = DateTime(focusedYear, index + 1);

              final isCurrentMonth =
                  today.year == focusedYear && today.month == index + 1;

              final isSelected =
                  widget.selectedDate.year == focusedYear &&
                  widget.selectedDate.month == index + 1;

              return InkWell(
                onTap: () => Navigator.pop(context, monthDate),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? Theme.of(context).primaryColor : null,
                    border: isCurrentMonth
                        ? Border.all(
                            color: Theme.of(context).primaryColor,
                            width: 2,
                          )
                        : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      DateFormat.MMM().format(monthDate),
                      style: TextStyle(
                        color: isSelected ? Colors.white : null,
                        fontWeight: isCurrentMonth || isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
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
