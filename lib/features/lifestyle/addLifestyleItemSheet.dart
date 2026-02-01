import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyleItem.dart';
import 'package:wai_life_assistant/data/enum/lifestyleCategory.dart';
import 'package:provider/provider.dart';
import 'lifestyleController.dart';

class AddLifestyleItemSheet extends StatefulWidget {
  final LifestyleCategory category;

  const AddLifestyleItemSheet({super.key, required this.category});

  @override
  State<AddLifestyleItemSheet> createState() => _AddLifestyleItemSheetState();
}

class _AddLifestyleItemSheetState extends State<AddLifestyleItemSheet> {
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime? _purchaseDate;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<LifestyleController>();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🔝 Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Add ${_label(widget.category)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 🏷 Name
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Eg: Honda Activa / iPhone / Saree',
              ),
            ),

            const SizedBox(height: 12),

            // 🏭 Brand
            TextField(
              controller: _brandCtrl,
              decoration: const InputDecoration(labelText: 'Brand'),
            ),

            const SizedBox(height: 12),

            // 💰 Price
            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price (optional)'),
            ),

            const SizedBox(height: 12),

            // 📅 Purchase Date
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(
                _purchaseDate == null
                    ? 'Select purchase date'
                    : 'Purchased on ${_purchaseDate!.toLocal().toString().split(' ')[0]}',
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _purchaseDate = picked);
                }
              },
            ),

            const SizedBox(height: 12),

            // 📝 Notes
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),

            const SizedBox(height: 20),

            // ✅ Save
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                child: const Text('Save'),
                onPressed: () {
                  if (_nameCtrl.text.trim().isEmpty) return;

                  controller.addItem(
                    LifestyleItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: _nameCtrl.text.trim(),
                      brand: _brandCtrl.text.trim().isEmpty
                          ? null
                          : _brandCtrl.text.trim(),
                      category: widget.category,
                      price: _priceCtrl.text.isEmpty
                          ? null
                          : double.tryParse(_priceCtrl.text),
                      purchaseDate: _purchaseDate,
                      notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
                    ),
                  );

                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _label(LifestyleCategory category) {
  switch (category) {
    case LifestyleCategory.vehicle:
      return 'Vehicle';
    case LifestyleCategory.dresses:
      return 'Dress';
    case LifestyleCategory.gadgets:
      return 'Gadget';
    case LifestyleCategory.appliances:
      return 'Appliance';
    case LifestyleCategory.collections:
      return 'Collection';
  }
}
