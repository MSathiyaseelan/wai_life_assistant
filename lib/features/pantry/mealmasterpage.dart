import 'package:flutter/material.dart';
import 'package:wai_life_assistant/features/pantry/mealdishcard.dart';
import 'package:wai_life_assistant/data/models/pandry/mealdish.dart';
import 'package:wai_life_assistant/features/pantry/bottomsheet/showadddishbottomsheet.dart';

class MealMasterPage extends StatefulWidget {
  const MealMasterPage({super.key});

  @override
  State<MealMasterPage> createState() => _MealMasterPageState();
}

class _MealMasterPageState extends State<MealMasterPage> {
  String _selectedCuisine = 'All';

  final List<String> cuisines = [
    'All',
    'Indian',
    'Chettinad',
    'Kerala',
    'Chinese',
  ];

  final List<MealDish> _dishes = [
    MealDish(
      id: '1',
      name: 'Idli',
      ingredients: ['Rice', 'Urad Dal', 'Salt'],
      suitableFor: {MealType.breakfast},
      cuisine: 'South Indian',
      referenceLink: 'https://youtu.be/idli_recipe',
    ),
    MealDish(
      id: '2',
      name: 'Chicken Chettinad',
      ingredients: ['Chicken', 'Pepper', 'Garlic', 'Spices'],
      suitableFor: {MealType.lunch, MealType.dinner},
      cuisine: 'Chettinad',
      referenceLink: 'https://youtu.be/chettinad_chicken',
    ),
    MealDish(
      id: '3',
      name: 'Puttu & Kadala Curry',
      ingredients: ['Rice flour', 'Coconut', 'Black chickpeas'],
      suitableFor: {MealType.breakfast, MealType.dinner},
      cuisine: 'Kerala',
    ),
  ]; // later from DB

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final filteredDishes = _selectedCuisine == 'All'
        ? _dishes
        : _dishes.where((d) => d.cuisine == _selectedCuisine).toList();

    const String addCuisineKey = '__add_new__';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Master'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              showAddDishBottomSheet(context: context);
            },
          ),
        ],
      ),

      body: Column(
        children: [
          /// Cuisine filter
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                DropdownMenu<String>(
                  initialSelection: _selectedCuisine,
                  dropdownMenuEntries: [
                    ...cuisines.map(
                      (c) => DropdownMenuEntry(value: c, label: c),
                    ),

                    const DropdownMenuEntry(
                      value: addCuisineKey,
                      label: '➕ Add new cuisine',
                    ),
                  ],
                  onSelected: (value) async {
                    if (value == addCuisineKey) {
                      final newCuisine = await _showAddCuisineDialog(context);

                      if (newCuisine != null && newCuisine.isNotEmpty) {
                        setState(() {
                          cuisines.add(newCuisine);
                          _selectedCuisine = newCuisine;
                        });
                      }
                    } else if (value != null) {
                      setState(() => _selectedCuisine = value);
                    }
                  },
                ),
              ],
            ),
          ),

          /// Dish list
          Expanded(
            child: filteredDishes.isEmpty
                ? const _EmptyMealMaster()
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredDishes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return MealDishCard(dish: filteredDishes[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMealMaster extends StatelessWidget {
  const _EmptyMealMaster();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.restaurant_menu, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text('No dishes added yet'),
        ],
      ),
    );
  }
}

Future<String?> _showAddCuisineDialog(BuildContext context) async {
  final controller = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Add new cuisine'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Andhra, Punjabi'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Add'),
          ),
        ],
      );
    },
  );
}
