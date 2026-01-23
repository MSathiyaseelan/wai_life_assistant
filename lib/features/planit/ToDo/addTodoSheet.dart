import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/models/planit/todoitem.dart';
import 'todoController.dart';
import 'package:provider/provider.dart';

class AddTodoSheet extends StatefulWidget {
  const AddTodoSheet({super.key});

  @override
  State<AddTodoSheet> createState() => _AddTodoSheetState();
}

class _AddTodoSheetState extends State<AddTodoSheet> {
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final todoController = context.read<TodoController>();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Task'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                todoController.addTodo(
                  TodoItem(
                    id: DateTime.now().toString(),
                    title: controller.text,
                  ),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
