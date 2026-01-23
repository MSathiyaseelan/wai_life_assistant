import 'package:flutter/material.dart';
import 'todoController.dart';
import 'package:intl/intl.dart';
import 'addTodoSheet.dart';
import 'package:wai_life_assistant/data/models/planit/todoitem.dart';
import 'package:provider/provider.dart';

class TodoPage extends StatelessWidget {
  const TodoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TodoController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('To-Do'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openAddTodoSheet(context),
          ),
        ],
      ),
      body: controller.pending.isEmpty
          ? const _EmptyTodo()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: controller.pending.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final todo = controller.pending[index];
                return _TodoTile(todo: todo);
              },
            ),
    );
  }
}

class _TodoTile extends StatelessWidget {
  final TodoItem todo;

  const _TodoTile({required this.todo});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<TodoController>();

    return Card(
      child: CheckboxListTile(
        value: todo.isCompleted,
        title: Text(todo.title),
        subtitle: todo.dueDate != null
            ? Text(DateFormat('dd MMM').format(todo.dueDate!))
            : null,
        onChanged: (_) => controller.toggleTodo(todo),
      ),
    );
  }
}

void _openAddTodoSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const AddTodoSheet(),
  );
}

class _EmptyTodo extends StatelessWidget {
  const _EmptyTodo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.checklist, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text('No tasks yet'),
        ],
      ),
    );
  }
}
