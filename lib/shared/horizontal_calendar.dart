import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HorizontalCalendar extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onDateSelected;

  const HorizontalCalendar({
    super.key,
    required this.initialDate,
    required this.onDateSelected,
  });

  @override
  State<HorizontalCalendar> createState() => _HorizontalCalendarState();
}

class _HorizontalCalendarState extends State<HorizontalCalendar> {
  late DateTime _selectedDate;
  final ScrollController _scrollController = ScrollController();

  static const double _itemWidth = 72;
  static const int _totalDays = 120; // ±60 days

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;

    /// 🔥 Ensure today is visible on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToToday();
    });
  }

  void _jumpToToday() {
    final centerIndex = _totalDays ~/ 2;
    final index = centerIndex; // today index
    final offset =
        (index * _itemWidth) -
        (MediaQuery.of(context).size.width / 2) +
        (_itemWidth / 2);

    _scrollController.jumpTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
    );
  }

  void _scrollToDate(DateTime date) {
    final centerIndex = _totalDays ~/ 2;
    final difference = date.difference(DateTime.now()).inDays;
    final index = centerIndex + difference;

    final offset =
        (index * _itemWidth) -
        (MediaQuery.of(context).size.width / 2) +
        (_itemWidth / 2);

    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _moveWeek(int offset) {
    final newDate = _selectedDate.add(Duration(days: offset));
    setState(() => _selectedDate = newDate);
    widget.onDateSelected(newDate);
    _scrollToDate(newDate);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: Row(
        children: [
          /// ◀ Left Arrow
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _moveWeek(-7),
          ),

          /// Calendar strip
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: _totalDays,
              itemBuilder: (context, index) {
                final date = DateTime.now().add(
                  Duration(days: index - (_totalDays ~/ 2)),
                );

                final isSelected = _isSameDay(date, _selectedDate);
                final isToday = _isSameDay(date, DateTime.now());

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedDate = date);
                    widget.onDateSelected(date);
                    _scrollToDate(date);
                  },
                  child: Container(
                    width: _itemWidth,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.blue
                          : isToday
                          ? Colors.blue.withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEE').format(date),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : isToday
                                ? Colors.blue
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          date.day.toString(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : isToday
                                ? Colors.blue
                                : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          /// ▶ Right Arrow
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _moveWeek(7),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
