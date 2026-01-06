import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wai_life_assistant/shared/calendar/monthcalendar.dart';

class DayNavigator extends StatefulWidget {
  const DayNavigator({super.key});

  @override
  State<DayNavigator> createState() => _DayNavigatorState();
}

class _DayNavigatorState extends State<DayNavigator> {
  DateTime selectedDate = DateTime.now();

  void _changeDay(int days) {
    setState(() {
      selectedDate = selectedDate.add(Duration(days: days));
    });
  }

  void _openMonthView() async {
    final pickedDate = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => MonthCalendar(selectedDate: selectedDate),
    );

    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => _changeDay(-1),
        ),

        Expanded(
          // 🔑 THIS IS THE KEY FIX
          child: InkWell(
            onTap: _openMonthView,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('EEEE').format(selectedDate),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(selectedDate),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),

        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => _changeDay(1),
        ),
      ],
    );
  }
}
