import '../../enum/todoPriority.dart';

class TodoItem {
  final String id;
  final String title;
  final bool isCompleted;
  final DateTime? dueDate;
  final TodoPriority priority;
  final String? note;

  TodoItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.dueDate,
    this.priority = TodoPriority.medium,
    this.note,
  });

  TodoItem copyWith({bool? isCompleted}) {
    return TodoItem(
      id: id,
      title: title,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: dueDate,
      priority: priority,
      note: note,
    );
  }
}
