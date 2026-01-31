import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wai_life_assistant/data/models/planit/reminder.dart';

class ReminderListPage extends StatefulWidget {
  const ReminderListPage({super.key});

  @override
  State<ReminderListPage> createState() => _ReminderListPageState();
}

class _ReminderListPageState extends State<ReminderListPage> {
  @override
  Widget build(BuildContext context) {
    // 🔹 Simple grouping (can be improved later)
    final today = reminders.take(1).toList();
    final tomorrow = reminders.length > 1 ? [reminders[1]] : <Reminder>[];
    final upcoming = reminders.skip(2).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              HapticFeedback.selectionClick();

              // 🔥 IMPORTANT: wait for sheet to close
              await showAddReminderSheet(context);

              // 🔥 Refresh UI
              setState(() {});
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (today.isNotEmpty)
            _ReminderSection(title: 'Today', reminders: today),

          if (tomorrow.isNotEmpty)
            _ReminderSection(title: 'Tomorrow', reminders: tomorrow),

          if (upcoming.isNotEmpty)
            _ReminderSection(title: 'Upcoming', reminders: upcoming),
        ],
      ),
    );
  }
}

final List<Reminder> reminders = [
  Reminder(
    id: '1',
    title: 'Take medicine',
    dateTime: DateTime.now().add(const Duration(hours: 1)),
    repeat: 'Daily',
  ),
  Reminder(
    id: '2',
    title: 'Call school',
    dateTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
    repeat: 'Does not repeat',
  ),
];

class _ReminderSection extends StatelessWidget {
  final String title;
  final List<Reminder> reminders;

  const _ReminderSection({required this.title, required this.reminders});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...reminders.map((r) => _ReminderTile(reminder: r)),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final Reminder reminder;

  const _ReminderTile({required this.reminder});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.alarm),
        title: Text(reminder.title),
        subtitle: Text(reminder.timeLabel(context)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          HapticFeedback.selectionClick();
          showEditReminderSheet(context, reminder);
        },
      ),
    );
  }
}

Future<void> showAddReminderSheet(BuildContext context) async {
  DateTime selectedDateTime = DateTime.now();
  final titleController = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New Reminder',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            TextField(
              decoration: const InputDecoration(
                labelText: 'What do you want to remember?',
                prefixIcon: Icon(Icons.edit),
              ),
            ),

            const SizedBox(height: 16),

            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date'),
              subtitle: Text(
                MaterialLocalizations.of(
                  context,
                ).formatMediumDate(selectedDateTime),
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: selectedDateTime,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );

                if (date != null) {
                  selectedDateTime = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    selectedDateTime.hour,
                    selectedDateTime.minute,
                  );
                }
              },
            ),

            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Time'),
              subtitle: Text(
                TimeOfDay.fromDateTime(selectedDateTime).format(context),
              ),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                );

                if (time != null) {
                  selectedDateTime = DateTime(
                    selectedDateTime.year,
                    selectedDateTime.month,
                    selectedDateTime.day,
                    time.hour,
                    time.minute,
                  );
                }
              },
            ),

            ListTile(
              leading: const Icon(Icons.repeat),
              title: const Text('Repeat'),
              subtitle: const Text('Does not repeat'),
              onTap: () {
                // TODO: repeat picker
              },
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  reminders.add(
                    Reminder(
                      id: DateTime.now().toIso8601String(),
                      title: titleController.text,
                      dateTime: selectedDateTime,
                      repeat: 'Does not repeat',
                    ),
                  );

                  Navigator.pop(context);
                },

                child: const Text('Save Reminder'),
              ),
            ),
          ],
        ),
      );
    },
  );
}

void showEditReminderSheet(BuildContext context, Reminder reminder) {
  final titleController = TextEditingController(text: reminder.title);
  DateTime selectedDateTime = reminder.dateTime;
  String repeat = reminder.repeat;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Reminder',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Reminder',
                    prefixIcon: Icon(Icons.edit),
                  ),
                ),

                const SizedBox(height: 16),

                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Date'),
                  subtitle: Text(
                    MaterialLocalizations.of(
                      context,
                    ).formatMediumDate(selectedDateTime),
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDateTime,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );

                    if (date != null) {
                      setState(() {
                        selectedDateTime = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          selectedDateTime.hour,
                          selectedDateTime.minute,
                        );
                      });
                    }
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text('Time'),
                  subtitle: Text(
                    TimeOfDay.fromDateTime(selectedDateTime).format(context),
                  ),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                    );

                    if (time != null) {
                      setState(() {
                        selectedDateTime = DateTime(
                          selectedDateTime.year,
                          selectedDateTime.month,
                          selectedDateTime.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.repeat),
                  title: const Text('Repeat'),
                  subtitle: Text(repeat),
                  onTap: () async {
                    final value = await _showRepeatPicker(ctx);
                    if (value != null) {
                      setState(() => repeat = value);
                    }
                  },
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      reminder.title = titleController.text;
                      reminder.dateTime = selectedDateTime;
                      reminder.repeat = repeat;
                      Navigator.pop(ctx);
                    },
                    child: const Text('Update Reminder'),
                  ),
                ),

                const SizedBox(height: 8),

                Center(
                  child: TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmDelete(context, reminder);
                    },
                    child: const Text('Delete Reminder'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<String?> _showRepeatPicker(BuildContext context) {
  const options = ['Does not repeat', 'Daily', 'Weekly', 'Monthly'];

  return showModalBottomSheet<String>(
    context: context,
    builder: (_) {
      return ListView(
        children: options.map((e) {
          return ListTile(
            title: Text(e),
            onTap: () => Navigator.pop(context, e),
          );
        }).toList(),
      );
    },
  );
}

void _confirmDelete(BuildContext context, Reminder reminder) {
  showDialog(
    context: context,
    builder: (_) {
      return AlertDialog(
        title: const Text('Delete reminder?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: remove reminder from list / DB
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      );
    },
  );
}
