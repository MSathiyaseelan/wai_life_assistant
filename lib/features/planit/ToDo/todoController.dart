import 'package:flutter/foundation.dart';
import 'package:wai_life_assistant/data/models/planit/todoitem.dart';

class TodoController extends ChangeNotifier {
  final List<TodoItem> _todos = [];

  List<TodoItem> get all => _todos;
  List<TodoItem> get pending => _todos.where((e) => !e.isCompleted).toList();
  List<TodoItem> get completed => _todos.where((e) => e.isCompleted).toList();

  void addTodo(TodoItem todo) {
    _todos.add(todo);
    notifyListeners();
  }

  void toggleTodo(TodoItem todo) {
    final index = _todos.indexWhere((e) => e.id == todo.id);
    if (index != -1) {
      _todos[index] = todo.copyWith(isCompleted: !todo.isCompleted);
      notifyListeners();
    }
  }

  void deleteTodo(TodoItem todo) {
    _todos.removeWhere((e) => e.id == todo.id);
    notifyListeners();
  }
}
