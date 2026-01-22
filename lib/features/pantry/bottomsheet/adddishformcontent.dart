import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/models/pandry/mealdish.dart';

class AddDishFormContent extends StatefulWidget {
  const AddDishFormContent({super.key});

  @override
  State<AddDishFormContent> createState() => _AddDishFormContentState();
}

class _AddDishFormContentState extends State<AddDishFormContent> {
  final _nameCtrl = TextEditingController();
  final _ingredientsCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();

  String _cuisine = 'Indian';
  final Set<MealType> _mealTypes = {};

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add Dish', style: textTheme.titleMedium),

        const SizedBox(height: 12),

        TextFormField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Dish name'),
        ),

        const SizedBox(height: 8),

        DropdownMenu<String>(
          label: const Text('Cuisine'),
          initialSelection: _cuisine,
          dropdownMenuEntries: const [
            DropdownMenuEntry(value: 'Indian', label: 'Indian'),
            DropdownMenuEntry(value: 'Chettinad', label: 'Chettinad'),
            DropdownMenuEntry(value: 'Kerala', label: 'Kerala'),
            DropdownMenuEntry(value: 'Chinese', label: 'Chinese'),
          ],
          onSelected: (v) => setState(() => _cuisine = v!),
        ),

        const SizedBox(height: 8),

        Text('Suitable for', style: textTheme.bodyMedium),
        Wrap(
          spacing: 8,
          children: MealType.values.map((t) {
            final selected = _mealTypes.contains(t);
            return FilterChip(
              label: Text(t.name),
              selected: selected,
              onSelected: (v) {
                setState(() {
                  v ? _mealTypes.add(t) : _mealTypes.remove(t);
                });
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 8),

        TextFormField(
          controller: _ingredientsCtrl,
          decoration: const InputDecoration(
            labelText: 'Ingredients (comma separated)',
          ),
        ),

        const SizedBox(height: 8),

        TextFormField(
          controller: _linkCtrl,
          decoration: const InputDecoration(labelText: 'Reference link'),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _submit,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _submit() {
    Navigator.pop(context);
  }
}
