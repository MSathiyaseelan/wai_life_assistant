import 'package:flutter/material.dart';

// ── Shared enums ──────────────────────────────────────────────────────────────

enum Priority { low, medium, high, urgent }

extension PriorityExt on Priority {
  String get label {
    switch (this) {
      case Priority.low:
        return 'Low';
      case Priority.medium:
        return 'Medium';
      case Priority.high:
        return 'High';
      case Priority.urgent:
        return 'Urgent';
    }
  }

  Color get color {
    switch (this) {
      case Priority.low:
        return const Color(0xFF00C897);
      case Priority.medium:
        return const Color(0xFF4A9EFF);
      case Priority.high:
        return const Color(0xFFFFAA2C);
      case Priority.urgent:
        return const Color(0xFFFF5C7A);
    }
  }
}

enum RepeatMode { none, daily, weekly, monthly, yearly }

extension RepeatModeExt on RepeatMode {
  String get label {
    switch (this) {
      case RepeatMode.none:
        return 'No repeat';
      case RepeatMode.daily:
        return 'Daily';
      case RepeatMode.weekly:
        return 'Weekly';
      case RepeatMode.monthly:
        return 'Monthly';
      case RepeatMode.yearly:
        return 'Yearly';
    }
  }

  String get badge {
    switch (this) {
      case RepeatMode.none:
        return '';
      case RepeatMode.daily:
        return '🔁 Daily';
      case RepeatMode.weekly:
        return '🔁 Weekly';
      case RepeatMode.monthly:
        return '🔁 Monthly';
      case RepeatMode.yearly:
        return '🔁 Yearly';
    }
  }
}

enum TaskStatus { todo, inProgress, done }

extension TaskStatusExt on TaskStatus {
  String get label {
    switch (this) {
      case TaskStatus.todo:
        return 'To Do';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.done:
        return 'Done';
    }
  }

  Color get color {
    switch (this) {
      case TaskStatus.todo:
        return const Color(0xFF6C63FF);
      case TaskStatus.inProgress:
        return const Color(0xFFFFAA2C);
      case TaskStatus.done:
        return const Color(0xFF00C897);
    }
  }

  IconData get icon {
    switch (this) {
      case TaskStatus.todo:
        return Icons.radio_button_unchecked_rounded;
      case TaskStatus.inProgress:
        return Icons.timelapse_rounded;
      case TaskStatus.done:
        return Icons.check_circle_rounded;
    }
  }
}

enum SpecialDayType {
  birthday,
  anniversary,
  festival,
  govtHoliday,
  holiday,
  custom,
}

extension SpecialDayTypeExt on SpecialDayType {
  String get label {
    switch (this) {
      case SpecialDayType.birthday:
        return 'Birthday';
      case SpecialDayType.anniversary:
        return 'Anniversary';
      case SpecialDayType.festival:
        return 'Festival';
      case SpecialDayType.govtHoliday:
        return 'Govt Holiday';
      case SpecialDayType.holiday:
        return 'Holiday';
      case SpecialDayType.custom:
        return 'Custom';
    }
  }

  String get emoji {
    switch (this) {
      case SpecialDayType.birthday:
        return '🎂';
      case SpecialDayType.anniversary:
        return '💍';
      case SpecialDayType.festival:
        return '🎉';
      case SpecialDayType.govtHoliday:
        return '🏛️';
      case SpecialDayType.holiday:
        return '🌟';
      case SpecialDayType.custom:
        return '📅';
    }
  }

  Color get color {
    switch (this) {
      case SpecialDayType.birthday:
        return const Color(0xFFFF5C7A);
      case SpecialDayType.anniversary:
        return const Color(0xFFFFAA2C);
      case SpecialDayType.festival:
        return const Color(0xFF6C63FF);
      case SpecialDayType.govtHoliday:
        return const Color(0xFF1A8FE3);
      case SpecialDayType.holiday:
        return const Color(0xFF00C897);
      case SpecialDayType.custom:
        return const Color(0xFF4A9EFF);
    }
  }
}

enum WishCategory {
  electronics,
  fashion,
  home,
  travel,
  food,
  experience,
  other,
}

extension WishCategoryExt on WishCategory {
  String get label {
    switch (this) {
      case WishCategory.electronics:
        return 'Electronics';
      case WishCategory.fashion:
        return 'Fashion';
      case WishCategory.home:
        return 'Home';
      case WishCategory.travel:
        return 'Travel';
      case WishCategory.food:
        return 'Food';
      case WishCategory.experience:
        return 'Experience';
      case WishCategory.other:
        return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case WishCategory.electronics:
        return '💻';
      case WishCategory.fashion:
        return '👗';
      case WishCategory.home:
        return '🏠';
      case WishCategory.travel:
        return '✈️';
      case WishCategory.food:
        return '🍽️';
      case WishCategory.experience:
        return '🎭';
      case WishCategory.other:
        return '🎁';
    }
  }
}

enum BillCategory {
  electricity,
  water,
  gas,
  internet,
  phone,
  insurance,
  school,
  rent,
  subscription,
  medical,
  emi,
  other,
}

extension BillCategoryExt on BillCategory {
  String get label {
    switch (this) {
      case BillCategory.electricity:
        return 'Electricity';
      case BillCategory.water:
        return 'Water';
      case BillCategory.gas:
        return 'Gas';
      case BillCategory.internet:
        return 'Internet';
      case BillCategory.phone:
        return 'Phone';
      case BillCategory.insurance:
        return 'Insurance';
      case BillCategory.school:
        return 'School Fees';
      case BillCategory.rent:
        return 'Rent';
      case BillCategory.subscription:
        return 'Subscription';
      case BillCategory.medical:
        return 'Medical';
      case BillCategory.emi:
        return 'EMI';
      case BillCategory.other:
        return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case BillCategory.electricity:
        return '💡';
      case BillCategory.water:
        return '💧';
      case BillCategory.gas:
        return '🔥';
      case BillCategory.internet:
        return '📡';
      case BillCategory.phone:
        return '📱';
      case BillCategory.insurance:
        return '🛡️';
      case BillCategory.school:
        return '🎒';
      case BillCategory.rent:
        return '🏠';
      case BillCategory.subscription:
        return '📺';
      case BillCategory.medical:
        return '🏥';
      case BillCategory.emi:
        return '🏦';
      case BillCategory.other:
        return '📋';
    }
  }
}

enum TravelMode { flight, train, car, bus, bike, ship, mixed }

extension TravelModeExt on TravelMode {
  String get label {
    switch (this) {
      case TravelMode.flight:
        return 'Flight';
      case TravelMode.train:
        return 'Train';
      case TravelMode.car:
        return 'Car';
      case TravelMode.bus:
        return 'Bus';
      case TravelMode.bike:
        return 'Bike';
      case TravelMode.ship:
        return 'Ship';
      case TravelMode.mixed:
        return 'Mixed';
    }
  }

  String get emoji {
    switch (this) {
      case TravelMode.flight:
        return '✈️';
      case TravelMode.train:
        return '🚆';
      case TravelMode.car:
        return '🚗';
      case TravelMode.bus:
        return '🚌';
      case TravelMode.bike:
        return '🏍️';
      case TravelMode.ship:
        return '🚢';
      case TravelMode.mixed:
        return '🗺️';
    }
  }
}

enum HealthRecordType {
  prescription,
  report,
  vaccination,
  vitals,
  allergy,
  surgery,
  other,
}

extension HealthRecordTypeExt on HealthRecordType {
  String get label {
    switch (this) {
      case HealthRecordType.prescription:
        return 'Prescription';
      case HealthRecordType.report:
        return 'Lab Report';
      case HealthRecordType.vaccination:
        return 'Vaccination';
      case HealthRecordType.vitals:
        return 'Vitals';
      case HealthRecordType.allergy:
        return 'Allergy';
      case HealthRecordType.surgery:
        return 'Surgery';
      case HealthRecordType.other:
        return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case HealthRecordType.prescription:
        return '💊';
      case HealthRecordType.report:
        return '🔬';
      case HealthRecordType.vaccination:
        return '💉';
      case HealthRecordType.vitals:
        return '❤️';
      case HealthRecordType.allergy:
        return '⚠️';
      case HealthRecordType.surgery:
        return '🏥';
      case HealthRecordType.other:
        return '📋';
    }
  }

  Color get color {
    switch (this) {
      case HealthRecordType.prescription:
        return const Color(0xFF6C63FF);
      case HealthRecordType.report:
        return const Color(0xFF4A9EFF);
      case HealthRecordType.vaccination:
        return const Color(0xFF00C897);
      case HealthRecordType.vitals:
        return const Color(0xFFFF5C7A);
      case HealthRecordType.allergy:
        return const Color(0xFFFFAA2C);
      case HealthRecordType.surgery:
        return const Color(0xFFFF7043);
      case HealthRecordType.other:
        return const Color(0xFF8E8EA0);
    }
  }
}

// ── Shared member model ───────────────────────────────────────────────────────

class PlanMember {
  final String id;
  final String name;
  final String emoji;
  final String? phone;

  const PlanMember({
    required this.id,
    required this.name,
    required this.emoji,
    this.phone,
  });
}

final mockMembers = [
  const PlanMember(id: 'me', name: 'Me', emoji: '👤'),
  const PlanMember(
    id: 'arjun',
    name: 'Arjun',
    emoji: '👨',
    phone: '9876543210',
  ),
  const PlanMember(
    id: 'priya',
    name: 'Priya',
    emoji: '👩',
    phone: '9876543211',
  ),
  const PlanMember(
    id: 'rahul',
    name: 'Rahul',
    emoji: '🧑',
    phone: '9876543212',
  ),
  const PlanMember(
    id: 'sneha',
    name: 'Sneha',
    emoji: '👧',
    phone: '9876543213',
  ),
  const PlanMember(id: 'dad', name: 'Dad', emoji: '👴'),
  const PlanMember(id: 'mom', name: 'Mom', emoji: '👵'),
];

// ─────────────────────────────────────────────────────────────────────────────
// a. ALERT ME
// ─────────────────────────────────────────────────────────────────────────────

class ReminderModel {
  final String id;
  String title;
  String emoji;
  DateTime dueDate;
  TimeOfDay dueTime;
  RepeatMode repeat;
  Priority priority;
  String assignedTo; // member id
  bool snoozed;
  bool done;
  String? note;
  String walletId;

  ReminderModel({
    required this.id,
    required this.title,
    required this.emoji,
    required this.dueDate,
    required this.dueTime,
    required this.repeat,
    required this.priority,
    required this.assignedTo,
    required this.walletId,
    this.snoozed = false,
    this.done = false,
    this.note,
  });

  factory ReminderModel.fromRow(Map<String, dynamic> row) {
    final timeParts = (row['due_time'] as String? ?? '09:00').split(':');
    return ReminderModel(
      id: row['id'] as String,
      walletId: row['wallet_id'] as String,
      title: row['title'] as String,
      emoji: row['emoji'] as String? ?? '🔔',
      dueDate: DateTime.parse(row['due_date'] as String),
      dueTime: TimeOfDay(
        hour: int.tryParse(timeParts[0]) ?? 9,
        minute: int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0,
      ),
      repeat: RepeatMode.values.firstWhere(
        (r) => r.name == (row['repeat'] as String? ?? 'none'),
        orElse: () => RepeatMode.none,
      ),
      priority: Priority.values.firstWhere(
        (p) => p.name == (row['priority'] as String? ?? 'medium'),
        orElse: () => Priority.medium,
      ),
      assignedTo: row['assigned_to'] as String? ?? 'me',
      snoozed: row['snoozed'] as bool? ?? false,
      done: row['done'] as bool? ?? false,
      note: row['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'title':       title,
    'emoji':       emoji,
    'due_date':    dueDate.toIso8601String().split('T').first,
    'due_time':    '${dueTime.hour.toString().padLeft(2, '0')}:${dueTime.minute.toString().padLeft(2, '0')}',
    'repeat':      repeat.name,
    'priority':    priority.name,
    'assigned_to': assignedTo,
    'snoozed':     snoozed,
    'done':        done,
    if (note != null) 'note': note,
  };
}

final DateTime _t = DateTime.now();

List<ReminderModel> mockReminders = [
  ReminderModel(
    id: 'r1',
    title: 'Pay electricity bill',
    emoji: '💡',
    dueDate: _t.add(const Duration(days: 2)),
    dueTime: const TimeOfDay(hour: 10, minute: 0),
    repeat: RepeatMode.monthly,
    priority: Priority.high,
    assignedTo: 'me',
    walletId: 'personal',
  ),
  ReminderModel(
    id: 'r2',
    title: 'Arjun\'s dental check-up',
    emoji: '🦷',
    dueDate: _t.add(const Duration(days: 5)),
    dueTime: const TimeOfDay(hour: 11, minute: 30),
    repeat: RepeatMode.none,
    priority: Priority.medium,
    assignedTo: 'arjun',
    walletId: 'f1',
    note: 'Dr. Sharma clinic, Connaught Place',
  ),
  ReminderModel(
    id: 'r3',
    title: 'Car insurance renewal',
    emoji: '🚗',
    dueDate: _t.add(const Duration(days: 12)),
    dueTime: const TimeOfDay(hour: 9, minute: 0),
    repeat: RepeatMode.yearly,
    priority: Priority.urgent,
    assignedTo: 'me',
    walletId: 'personal',
  ),
  ReminderModel(
    id: 'r4',
    title: 'Mom\'s medicine refill',
    emoji: '💊',
    dueDate: _t.add(const Duration(days: 3)),
    dueTime: const TimeOfDay(hour: 18, minute: 0),
    repeat: RepeatMode.weekly,
    priority: Priority.high,
    assignedTo: 'mom',
    walletId: 'f1',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// b. MY TASKS
// ─────────────────────────────────────────────────────────────────────────────

class TaskModel {
  final String id;
  String title;
  String? description;
  String emoji;
  TaskStatus status;
  Priority priority;
  DateTime? dueDate;
  String? project;
  List<String> tags;
  String assignedTo;
  String walletId;
  List<SubTask> subtasks;
  DateTime createdAt;

  TaskModel({
    required this.id,
    required this.title,
    required this.emoji,
    required this.status,
    required this.priority,
    required this.assignedTo,
    required this.walletId,
    this.description,
    this.dueDate,
    this.project,
    this.tags = const [],
    this.subtasks = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory TaskModel.fromRow(Map<String, dynamic> row) {
    const sm = {
      'todo': TaskStatus.todo,
      'inProgress': TaskStatus.inProgress,
      'done': TaskStatus.done,
    };
    const pm = {
      'low': Priority.low,
      'medium': Priority.medium,
      'high': Priority.high,
      'urgent': Priority.urgent,
    };
    final rawSubs = (row['subtasks'] as List? ?? []);
    return TaskModel(
      id: row['id'] as String,
      walletId: row['wallet_id'] as String,
      title: row['title'] as String,
      emoji: row['emoji'] as String? ?? '✅',
      description: row['description'] as String?,
      status: sm[row['status']] ?? TaskStatus.todo,
      priority: pm[row['priority']] ?? Priority.medium,
      dueDate: row['due_date'] != null
          ? DateTime.tryParse(row['due_date'] as String)
          : null,
      project: row['project'] as String?,
      tags: List<String>.from(row['tags'] as List? ?? []),
      assignedTo: row['assigned_to'] as String? ?? 'me',
      subtasks: rawSubs.map((s) {
        final m = Map<String, dynamic>.from(s as Map);
        return SubTask(
          id: m['id'] as String,
          title: m['title'] as String,
          done: m['done'] as bool? ?? false,
        );
      }).toList(),
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toRow() => {
    'wallet_id': walletId,
    'title': title,
    'emoji': emoji,
    if (description != null) 'description': description,
    'status': status.name,
    'priority': priority.name,
    if (dueDate != null) 'due_date': dueDate!.toIso8601String().split('T').first,
    if (project != null) 'project': project,
    'tags': tags,
    'assigned_to': assignedTo,
    'subtasks': subtasks.map((s) => s.toMap()).toList(),
  };
}

class SubTask {
  final String id;
  String title;
  bool done;
  SubTask({required this.id, required this.title, this.done = false});

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'done': done};
}

List<TaskModel> mockTasks = [
  TaskModel(
    id: 't1',
    title: 'Book school bus for next term',
    emoji: '🎒',
    status: TaskStatus.todo,
    priority: Priority.high,
    assignedTo: 'me',
    walletId: 'f1',
    dueDate: _t.add(const Duration(days: 7)),
    project: 'School',
    subtasks: [
      SubTask(id: 'st1', title: 'Check routes'),
      SubTask(id: 'st2', title: 'Compare fees', done: true),
      SubTask(id: 'st3', title: 'Confirm registration'),
    ],
  ),
  TaskModel(
    id: 't2',
    title: 'Plan anniversary dinner',
    emoji: '🍽️',
    status: TaskStatus.inProgress,
    priority: Priority.medium,
    assignedTo: 'priya',
    walletId: 'personal',
    dueDate: _t.add(const Duration(days: 14)),
    project: 'Family',
    tags: ['romantic', 'dinner'],
  ),
  TaskModel(
    id: 't3',
    title: 'Submit quarterly report',
    emoji: '📊',
    status: TaskStatus.done,
    priority: Priority.urgent,
    assignedTo: 'me',
    walletId: 'personal',
    project: 'Work',
  ),
  TaskModel(
    id: 't4',
    title: 'Fix leaking tap in kitchen',
    emoji: '🔧',
    status: TaskStatus.todo,
    priority: Priority.medium,
    assignedTo: 'arjun',
    walletId: 'f1',
    dueDate: _t.add(const Duration(days: 2)),
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// c. SPECIAL DAYS
// ─────────────────────────────────────────────────────────────────────────────

class SpecialDayModel {
  final String id;
  String title;
  String emoji;
  SpecialDayType type;
  DateTime date;
  bool yearlyRecur;
  List<String> members; // member ids
  String? note;
  int alertDaysBefore;
  String walletId;

  SpecialDayModel({
    required this.id,
    required this.title,
    required this.emoji,
    required this.type,
    required this.date,
    required this.walletId,
    this.yearlyRecur = true,
    this.members = const [],
    this.note,
    this.alertDaysBefore = 1,
  });

  factory SpecialDayModel.fromRow(Map<String, dynamic> row) {
    const tm = {
      'birthday': SpecialDayType.birthday,
      'anniversary': SpecialDayType.anniversary,
      'festival': SpecialDayType.festival,
      'govtHoliday': SpecialDayType.govtHoliday,
      'holiday': SpecialDayType.holiday,
      'custom': SpecialDayType.custom,
    };
    return SpecialDayModel(
      id: row['id'] as String,
      walletId: row['wallet_id'] as String,
      title: row['title'] as String,
      emoji: row['emoji'] as String? ?? '📅',
      type: tm[row['type']] ?? SpecialDayType.custom,
      date: DateTime.parse(row['date'] as String),
      yearlyRecur: row['yearly_recur'] as bool? ?? true,
      members: List<String>.from(row['members'] as List? ?? []),
      note: row['note'] as String?,
      alertDaysBefore: row['alert_days_before'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toRow() => {
    'wallet_id': walletId,
    'title': title,
    'emoji': emoji,
    'type': type.name,
    'date': '${date.year.toString().padLeft(4,'0')}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}',
    'yearly_recur': yearlyRecur,
    'members': members,
    if (note != null) 'note': note,
    'alert_days_before': alertDaysBefore,
  };
}

List<SpecialDayModel> mockSpecialDays = [
  // ── Upcoming ──
  SpecialDayModel(
    id: 'sd1',
    title: "Priya's Birthday",
    emoji: '🎂',
    type: SpecialDayType.birthday,
    date: DateTime(DateTime.now().year, 3, 15),
    members: ['priya'],
    walletId: 'personal',
    alertDaysBefore: 3,
    note: 'Plan surprise party!',
  ),
  SpecialDayModel(
    id: 'sd2',
    title: 'Wedding Anniversary',
    emoji: '💍',
    type: SpecialDayType.anniversary,
    date: DateTime(DateTime.now().year, 5, 20),
    members: ['me', 'priya'],
    walletId: 'personal',
    alertDaysBefore: 7,
  ),
  SpecialDayModel(
    id: 'sd3',
    title: 'Diwali',
    emoji: '🪔',
    type: SpecialDayType.festival,
    date: DateTime(DateTime.now().year, 11, 1),
    members: ['me', 'arjun', 'priya', 'mom', 'dad'],
    walletId: 'f1',
    alertDaysBefore: 7,
  ),
  SpecialDayModel(
    id: 'sd4',
    title: "Dad's Birthday",
    emoji: '🎂',
    type: SpecialDayType.birthday,
    date: DateTime(DateTime.now().year, 8, 10),
    members: ['dad'],
    walletId: 'f1',
    alertDaysBefore: 5,
  ),
  // ── Past (before March 3) ──
  SpecialDayModel(
    id: 'sd5',
    title: "Republic Day",
    emoji: '🇮🇳',
    type: SpecialDayType.govtHoliday,
    date: DateTime(DateTime.now().year, 1, 26),
    walletId: 'personal',
    alertDaysBefore: 1,
  ),
  SpecialDayModel(
    id: 'sd6',
    title: "Mum's Birthday",
    emoji: '🎂',
    type: SpecialDayType.birthday,
    date: DateTime(DateTime.now().year, 2, 14),
    members: ['mom'],
    walletId: 'personal',
    alertDaysBefore: 7,
    note: 'Get flowers!',
  ),
  SpecialDayModel(
    id: 'sd7',
    title: "Holi",
    emoji: '🎨',
    type: SpecialDayType.festival,
    date: DateTime(DateTime.now().year, 2, 26),
    members: ['me', 'arjun', 'priya'],
    walletId: 'f1',
    alertDaysBefore: 3,
  ),
  SpecialDayModel(
    id: 'sd8',
    title: "Work Anniversary",
    emoji: '💼',
    type: SpecialDayType.anniversary,
    date: DateTime(DateTime.now().year, 1, 10),
    walletId: 'personal',
    alertDaysBefore: 1,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// d. WISH LIST
// ─────────────────────────────────────────────────────────────────────────────

class SavingsEntry {
  final double amount;
  final DateTime date;
  final String? note;
  SavingsEntry({required this.amount, required this.date, this.note});
}

class WishModel {
  final String id;
  String title;
  String emoji;
  WishCategory category;
  double? targetPrice;
  double savedAmount;
  String? link;
  String? note;
  Priority priority;
  bool purchased;
  DateTime? targetDate;
  String walletId;
  List<SavingsEntry> savingsHistory;

  WishModel({
    required this.id,
    required this.title,
    required this.emoji,
    required this.category,
    required this.priority,
    required this.walletId,
    this.targetPrice,
    this.savedAmount = 0,
    this.link,
    this.note,
    this.purchased = false,
    this.targetDate,
    List<SavingsEntry>? savingsHistory,
  }) : savingsHistory = savingsHistory ?? [];

  double get progress => (targetPrice != null && targetPrice! > 0)
      ? (savedAmount / targetPrice!).clamp(0, 1)
      : 0;
}

List<WishModel> mockWishes = [
  WishModel(
    id: 'w1',
    title: 'MacBook Pro M3',
    emoji: '💻',
    category: WishCategory.electronics,
    priority: Priority.high,
    walletId: 'personal',
    targetPrice: 180000,
    savedAmount: 45000,
    targetDate: _t.add(const Duration(days: 120)),
  ),
  WishModel(
    id: 'w2',
    title: 'Family trip to Goa',
    emoji: '🏖️',
    category: WishCategory.travel,
    priority: Priority.medium,
    walletId: 'f1',
    targetPrice: 50000,
    savedAmount: 15000,
    targetDate: _t.add(const Duration(days: 90)),
  ),
  WishModel(
    id: 'w3',
    title: 'Sony WH-1000XM5 Headphones',
    emoji: '🎧',
    category: WishCategory.electronics,
    priority: Priority.low,
    walletId: 'personal',
    targetPrice: 28000,
    savedAmount: 28000,
    note: 'Available on Amazon',
  ),
  WishModel(
    id: 'w4',
    title: 'New sofa set',
    emoji: '🛋️',
    category: WishCategory.home,
    priority: Priority.medium,
    walletId: 'f1',
    targetPrice: 35000,
    savedAmount: 8000,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// e. BILL WATCH
// ─────────────────────────────────────────────────────────────────────────────

class BillModel {
  final String id;
  String name;
  BillCategory category;
  double amount;
  DateTime dueDate;
  RepeatMode repeat;
  bool paid;
  String? provider;
  String? accountNumber;
  String? note;
  String walletId;
  List<BillPayment> history;

  BillModel({
    required this.id,
    required this.name,
    required this.category,
    required this.amount,
    required this.dueDate,
    required this.repeat,
    required this.walletId,
    this.paid = false,
    this.provider,
    this.accountNumber,
    this.note,
    this.history = const [],
  });

  bool get isOverdue => !paid && dueDate.isBefore(DateTime.now());
  bool get isDueSoon =>
      !paid && !isOverdue && dueDate.difference(DateTime.now()).inDays <= 5;

  BillModel copyWith({
    String? name,
    BillCategory? category,
    double? amount,
    DateTime? dueDate,
    RepeatMode? repeat,
    bool? paid,
    String? provider,
    String? accountNumber,
    String? note,
    String? walletId,
    List<BillPayment>? history,
  }) => BillModel(
    id: id,
    name: name ?? this.name,
    category: category ?? this.category,
    amount: amount ?? this.amount,
    dueDate: dueDate ?? this.dueDate,
    repeat: repeat ?? this.repeat,
    paid: paid ?? this.paid,
    provider: provider ?? this.provider,
    accountNumber: accountNumber ?? this.accountNumber,
    note: note ?? this.note,
    walletId: walletId ?? this.walletId,
    history: history ?? List.from(this.history),
  );
}

class BillPayment {
  final String id;
  final DateTime paidOn;
  final double amount;
  BillPayment({required this.id, required this.paidOn, required this.amount});
}

List<BillModel> mockBills = [
  BillModel(
    id: 'b1',
    name: 'BESCOM Electricity',
    category: BillCategory.electricity,
    amount: 1850,
    dueDate: _t.add(const Duration(days: 3)),
    repeat: RepeatMode.monthly,
    walletId: 'personal',
    provider: 'BESCOM',
    accountNumber: 'BLR-4521-990',
    history: [
      BillPayment(
        id: 'bp1',
        paidOn: _t.subtract(const Duration(days: 28)),
        amount: 1620,
      ),
      BillPayment(
        id: 'bp2',
        paidOn: _t.subtract(const Duration(days: 58)),
        amount: 1900,
      ),
    ],
  ),
  BillModel(
    id: 'b2',
    name: 'LIC Premium',
    category: BillCategory.insurance,
    amount: 12500,
    dueDate: _t.add(const Duration(days: 18)),
    repeat: RepeatMode.monthly,
    walletId: 'personal',
    provider: 'LIC of India',
    accountNumber: 'LIC-7823651',
  ),
  BillModel(
    id: 'b3',
    name: 'Arjun School Fees',
    category: BillCategory.school,
    amount: 8500,
    dueDate: _t.subtract(const Duration(days: 1)),
    repeat: RepeatMode.monthly,
    walletId: 'f1',
    provider: 'Delhi Public School',
  ),
  BillModel(
    id: 'b4',
    name: 'Airtel Broadband',
    category: BillCategory.internet,
    amount: 999,
    dueDate: _t.add(const Duration(days: 8)),
    repeat: RepeatMode.monthly,
    walletId: 'personal',
    provider: 'Airtel',
    accountNumber: 'AIR-DEL-992',
  ),
  BillModel(
    id: 'b5',
    name: 'Home Loan EMI',
    category: BillCategory.emi,
    amount: 35000,
    dueDate: _t.add(const Duration(days: 5)),
    repeat: RepeatMode.monthly,
    walletId: 'personal',
    provider: 'SBI Home Loans',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// f. TRAVEL BOARD
// ─────────────────────────────────────────────────────────────────────────────
// f. TRAVEL BOARD
// ─────────────────────────────────────────────────────────────────────────────

enum TripStatus { planning, confirmed, ongoing, completed, cancelled }

extension TripStatusExt on TripStatus {
  String get label {
    switch (this) {
      case TripStatus.planning:
        return 'Planning';
      case TripStatus.confirmed:
        return 'Confirmed';
      case TripStatus.ongoing:
        return 'Ongoing';
      case TripStatus.completed:
        return 'Completed';
      case TripStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get emoji {
    switch (this) {
      case TripStatus.planning:
        return '📝';
      case TripStatus.confirmed:
        return '✅';
      case TripStatus.ongoing:
        return '🚀';
      case TripStatus.completed:
        return '🏁';
      case TripStatus.cancelled:
        return '❌';
    }
  }
}

enum TaskCategory {
  booking,
  packing,
  document,
  activity,
  food,
  transport,
  accommodation,
  other,
}

extension TaskCategoryExt on TaskCategory {
  String get label {
    switch (this) {
      case TaskCategory.booking:
        return 'Booking';
      case TaskCategory.packing:
        return 'Packing';
      case TaskCategory.document:
        return 'Documents';
      case TaskCategory.activity:
        return 'Activity';
      case TaskCategory.food:
        return 'Food';
      case TaskCategory.transport:
        return 'Transport';
      case TaskCategory.accommodation:
        return 'Stay';
      case TaskCategory.other:
        return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case TaskCategory.booking:
        return '🎫';
      case TaskCategory.packing:
        return '🧳';
      case TaskCategory.document:
        return '📄';
      case TaskCategory.activity:
        return '🎯';
      case TaskCategory.food:
        return '🍽️';
      case TaskCategory.transport:
        return '🚌';
      case TaskCategory.accommodation:
        return '🏨';
      case TaskCategory.other:
        return '📌';
    }
  }
}

class TripDestination {
  String name;
  String? notes;
  int orderIndex;
  TripDestination({required this.name, this.notes, required this.orderIndex});
}

class TripTask {
  final String id;
  String title;
  String assignedTo; // member id
  String addedBy; // member id
  TaskCategory category;
  double? cost;
  String? notes;
  bool done;
  DateTime? dueDate;
  TripTask({
    required this.id,
    required this.title,
    required this.assignedTo,
    required this.addedBy,
    this.category = TaskCategory.other,
    this.cost,
    this.notes,
    this.done = false,
    this.dueDate,
  });
}

class TripExpense {
  final String id;
  final String paidBy; // member id
  final String description;
  final double amount;
  final DateTime at;
  TripExpense({
    required this.id,
    required this.paidBy,
    required this.description,
    required this.amount,
    required this.at,
  });
}

class TripMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime at;
  TripMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.at,
  });
}

class TripVote {
  final String id;
  final String question;
  final List<String> options;
  Map<String, int> tally; // optionIndex → count (mutable for voting)
  TripVote({
    required this.id,
    required this.question,
    required this.options,
    Map<String, int>? tally,
  }) : tally = tally ?? {};
}

class TripModel {
  final String id;
  String title;
  String emoji;
  List<TripDestination> destinations; // multi-destination support
  DateTime? startDate;
  DateTime? endDate;
  TravelMode travelMode;
  double? budget;
  List<String> memberIds;
  List<TripTask> tasks;
  List<TripExpense> expenses;
  List<TripMessage> messages;
  List<TripVote> votes;
  String? notes;
  String walletId;
  TripStatus status;
  String createdBy;

  TripModel({
    required this.id,
    required this.title,
    required this.emoji,
    required this.destinations,
    required this.travelMode,
    required this.walletId,
    required this.createdBy,
    this.startDate,
    this.endDate,
    this.budget,
    this.memberIds = const [],
    this.tasks = const [],
    this.expenses = const [],
    this.messages = const [],
    this.votes = const [],
    this.notes,
    this.status = TripStatus.planning,
  });

  double get totalSpent => expenses.fold(0, (s, e) => s + e.amount);

  // Primary destination label (first one or comma-joined)
  String get destinationLabel => destinations.isEmpty
      ? '—'
      : destinations.length == 1
      ? destinations.first.name
      : destinations.map((d) => d.name).join(' → ');

  int get tasksDone => tasks.where((t) => t.done).length;
  int get tasksTotal => tasks.length;
}

List<TripModel> mockTrips = [
  TripModel(
    id: 'tr1',
    title: 'Goa Beach Holiday',
    emoji: '🏖️',
    destinations: [
      TripDestination(
        name: 'Goa, India',
        orderIndex: 0,
        notes: 'North Goa beaches, Baga & Calangute',
      ),
      TripDestination(
        name: 'Mumbai, India',
        orderIndex: 1,
        notes: 'Stopover — visit Marine Drive',
      ),
    ],
    startDate: _t.add(const Duration(days: 45)),
    endDate: _t.add(const Duration(days: 51)),
    travelMode: TravelMode.flight,
    budget: 80000,
    memberIds: ['me', 'priya', 'arjun'],
    walletId: 'f1',
    createdBy: 'me',
    status: TripStatus.confirmed,
    tasks: [
      TripTask(
        id: 'tt1',
        title: 'Book flights',
        assignedTo: 'me',
        addedBy: 'me',
        category: TaskCategory.booking,
      ),
      TripTask(
        id: 'tt2',
        title: 'Hotel booking at North Goa',
        assignedTo: 'priya',
        addedBy: 'priya',
        category: TaskCategory.accommodation,
        cost: 12000,
      ),
      TripTask(
        id: 'tt3',
        title: 'Pack beach gear & sunscreen',
        assignedTo: 'arjun',
        addedBy: 'me',
        category: TaskCategory.packing,
        done: true,
      ),
      TripTask(
        id: 'tt4',
        title: 'Apply travel insurance',
        assignedTo: 'me',
        addedBy: 'me',
        category: TaskCategory.document,
      ),
      TripTask(
        id: 'tt5',
        title: 'Book water sports activity',
        assignedTo: 'priya',
        addedBy: 'priya',
        category: TaskCategory.activity,
        cost: 3000,
      ),
    ],
    expenses: [
      TripExpense(
        id: 'te1',
        paidBy: 'me',
        description: 'Flight tickets × 3',
        amount: 22000,
        at: _t.subtract(const Duration(days: 5)),
      ),
      TripExpense(
        id: 'te2',
        paidBy: 'priya',
        description: 'Hotel advance',
        amount: 8000,
        at: _t.subtract(const Duration(days: 3)),
      ),
    ],
    messages: [
      TripMessage(
        id: 'tm1',
        senderId: 'priya',
        text: 'I found a great resort deal! Rs. 4000/night for ocean view 🌊',
        at: _t.subtract(const Duration(hours: 2)),
      ),
      TripMessage(
        id: 'tm2',
        senderId: 'me',
        text: 'Looks amazing! Let\'s book it',
        at: _t.subtract(const Duration(hours: 1)),
      ),
      TripMessage(
        id: 'tm3',
        senderId: 'arjun',
        text: 'Count me in! Already packed my bags 😂',
        at: _t.subtract(const Duration(minutes: 30)),
      ),
    ],
    votes: [
      TripVote(
        id: 'tv1',
        question: 'Which hotel?',
        options: ['Ocean View Resort', 'Budget Hostel', 'Airbnb Villa'],
        tally: {'0': 2, '1': 0, '2': 1},
      ),
    ],
  ),
  TripModel(
    id: 'tr2',
    title: 'Ooty Weekend Getaway',
    emoji: '🌿',
    destinations: [TripDestination(name: 'Ooty, Tamil Nadu', orderIndex: 0)],
    startDate: _t.add(const Duration(days: 12)),
    endDate: _t.add(const Duration(days: 14)),
    travelMode: TravelMode.car,
    budget: 15000,
    memberIds: ['me', 'priya'],
    walletId: 'personal',
    createdBy: 'me',
    status: TripStatus.planning,
    expenses: [
      TripExpense(
        id: 'te3',
        paidBy: 'me',
        description: 'Fuel fill-up',
        amount: 3500,
        at: _t.subtract(const Duration(days: 1)),
      ),
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// g. PLAN THE PARTY
// ─────────────────────────────────────────────────────────────────────────────

class PartyModel {
  final String id;
  String title;
  String emoji;
  DateTime? eventDate;
  TimeOfDay? eventTime;
  String? venue;
  String? address;
  double? budget;
  double spent;
  List<String> guestIds;
  List<ContractorModel> contractors;
  List<PartyTask> tasks;
  List<PartyMessage> messages;
  String? notes;
  String walletId;

  PartyModel({
    required this.id,
    required this.title,
    required this.emoji,
    required this.walletId,
    this.eventDate,
    this.eventTime,
    this.venue,
    this.address,
    this.budget,
    this.spent = 0,
    this.guestIds = const [],
    this.contractors = const [],
    this.tasks = const [],
    this.messages = const [],
    this.notes,
  });
}

class ContractorModel {
  final String id;
  String name;
  String role;
  String? phone;
  String? address;
  double? quotedAmount;
  bool confirmed;
  ContractorModel({
    required this.id,
    required this.name,
    required this.role,
    this.phone,
    this.address,
    this.quotedAmount,
    this.confirmed = false,
  });
}

class PartyTask {
  final String id;
  String title;
  String assignedTo;
  bool done;
  String? update;
  PartyTask({
    required this.id,
    required this.title,
    required this.assignedTo,
    this.done = false,
    this.update,
  });
}

class PartyMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime at;
  PartyMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.at,
  });
}

List<PartyModel> mockParties = [
  PartyModel(
    id: 'p1',
    title: "Arjun's Birthday Party",
    emoji: '🎂',
    eventDate: _t.add(const Duration(days: 20)),
    eventTime: const TimeOfDay(hour: 18, minute: 0),
    venue: 'Community Hall, Sector 5',
    address: 'Block A, Sector 5, Noida',
    budget: 25000,
    spent: 8000,
    guestIds: ['priya', 'rahul', 'sneha', 'mom', 'dad'],
    walletId: 'f1',
    contractors: [
      ContractorModel(
        id: 'c1',
        name: 'Happy Cakes',
        role: 'Cake',
        phone: '9988776655',
        quotedAmount: 3500,
        confirmed: true,
      ),
      ContractorModel(
        id: 'c2',
        name: 'Party Deco Co.',
        role: 'Decoration',
        phone: '9977665544',
        quotedAmount: 6000,
      ),
    ],
    tasks: [
      PartyTask(
        id: 'pt1',
        title: 'Send invites',
        assignedTo: 'priya',
        done: true,
      ),
      PartyTask(id: 'pt2', title: 'Order birthday cake', assignedTo: 'me'),
      PartyTask(
        id: 'pt3',
        title: 'Arrange music playlist',
        assignedTo: 'arjun',
        update: 'Working on it!',
      ),
    ],
    messages: [
      PartyMessage(
        id: 'pm1',
        senderId: 'priya',
        text: 'Invites sent to everyone!',
        at: _t.subtract(const Duration(hours: 3)),
      ),
      PartyMessage(
        id: 'pm2',
        senderId: 'arjun',
        text: 'Can we have a photo booth?',
        at: _t.subtract(const Duration(hours: 1)),
      ),
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// h. MY SCHEDULE
// ─────────────────────────────────────────────────────────────────────────────

class AppointmentModel {
  final String id;
  String title;
  String emoji;
  String withWhom;
  String? phone;
  String? address;
  DateTime date;
  TimeOfDay time;
  int durationMin;
  String? notes;
  bool confirmed;
  bool done;
  String walletId;

  AppointmentModel({
    required this.id,
    required this.title,
    required this.emoji,
    required this.withWhom,
    required this.date,
    required this.time,
    required this.walletId,
    this.phone,
    this.address,
    this.durationMin = 60,
    this.notes,
    this.confirmed = true,
    this.done = false,
  });
}

List<AppointmentModel> mockAppointments = [
  AppointmentModel(
    id: 'ap1',
    title: 'Doctor – Annual Check-up',
    emoji: '👨‍⚕️',
    withWhom: 'Dr. Mehta',
    phone: '9812345678',
    address: 'Apollo Clinic, MG Road, Bangalore',
    date: _t.add(const Duration(days: 3)),
    time: const TimeOfDay(hour: 10, minute: 30),
    durationMin: 45,
    walletId: 'personal',
    notes: 'Carry previous reports',
  ),
  AppointmentModel(
    id: 'ap2',
    title: 'Bank – Home Loan Review',
    emoji: '🏦',
    withWhom: 'SBI Branch Manager',
    phone: '1800112211',
    address: 'SBI, Koramangala Branch',
    date: _t.add(const Duration(days: 6)),
    time: const TimeOfDay(hour: 11, minute: 0),
    durationMin: 30,
    walletId: 'personal',
  ),
  AppointmentModel(
    id: 'ap3',
    title: "Priya's Parent-Teacher Meet",
    emoji: '🎒',
    withWhom: "Class Teacher - Mrs. Sharma",
    address: 'DPS, Sector 45',
    date: _t.add(const Duration(days: 1)),
    time: const TimeOfDay(hour: 9, minute: 0),
    durationMin: 30,
    walletId: 'f1',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// i. HEALTH VAULT
// ─────────────────────────────────────────────────────────────────────────────

class HealthMemberProfile {
  final String id;
  final String memberId; // links to PlanMember
  String bloodGroup;
  String? allergies;
  String? chronicConditions;
  List<HealthRecord> records;

  HealthMemberProfile({
    required this.id,
    required this.memberId,
    this.bloodGroup = 'Unknown',
    this.allergies,
    this.chronicConditions,
    this.records = const [],
  });
}

class HealthRecord {
  final String id;
  String title;
  HealthRecordType type;
  DateTime date;
  String? doctor;
  String? hospital;
  String? notes;
  List<String> tags;

  HealthRecord({
    required this.id,
    required this.title,
    required this.type,
    required this.date,
    this.doctor,
    this.hospital,
    this.notes,
    this.tags = const [],
  });
}

List<HealthMemberProfile> mockHealthProfiles = [
  HealthMemberProfile(
    id: 'hp1',
    memberId: 'me',
    bloodGroup: 'B+',
    allergies: 'Penicillin',
    chronicConditions: 'Mild hypertension',
    records: [
      HealthRecord(
        id: 'hr1',
        title: 'Annual Blood Work',
        type: HealthRecordType.report,
        date: _t.subtract(const Duration(days: 30)),
        doctor: 'Dr. Mehta',
        hospital: 'Apollo Clinic',
        tags: ['CBC', 'Thyroid'],
      ),
      HealthRecord(
        id: 'hr2',
        title: 'BP Medication',
        type: HealthRecordType.prescription,
        date: _t.subtract(const Duration(days: 30)),
        doctor: 'Dr. Mehta',
        notes: 'Telma 40mg – once daily',
      ),
    ],
  ),
  HealthMemberProfile(
    id: 'hp2',
    memberId: 'arjun',
    bloodGroup: 'O+',
    records: [
      HealthRecord(
        id: 'hr3',
        title: 'COVID Vaccination',
        type: HealthRecordType.vaccination,
        date: _t.subtract(const Duration(days: 400)),
        hospital: 'Government Clinic',
        tags: ['Covishield', 'Dose 2'],
      ),
    ],
  ),
  HealthMemberProfile(
    id: 'hp3',
    memberId: 'mom',
    bloodGroup: 'A+',
    allergies: 'Dust allergy',
    chronicConditions: 'Diabetes Type 2',
    records: [
      HealthRecord(
        id: 'hr4',
        title: 'HbA1c Report',
        type: HealthRecordType.report,
        date: _t.subtract(const Duration(days: 15)),
        doctor: 'Dr. Gupta',
        hospital: 'City Hospital',
        notes: 'HbA1c: 7.2% – Controlled',
      ),
    ],
  ),
];
