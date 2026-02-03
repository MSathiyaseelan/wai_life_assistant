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
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(title: 'Add ${_label(widget.category)}'),

            const SizedBox(height: 16),

            // 🧠 Category-specific fields
            _buildCategoryFields(),

            const SizedBox(height: 12),

            _CommonFields(
              nameCtrl: _nameCtrl,
              brandCtrl: _brandCtrl,
              priceCtrl: _priceCtrl,
              notesCtrl: _notesCtrl,
              purchaseDate: _purchaseDate,
              onPickDate: (date) => setState(() => _purchaseDate = date),
            ),

            const SizedBox(height: 20),

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

  /// 🔁 Switch UI by category
  Widget _buildCategoryFields() {
    switch (widget.category) {
      case LifestyleCategory.vehicle:
        return const _VehicleExtraFields();

      case LifestyleCategory.dresses:
        return const _DressExtraFields();

      case LifestyleCategory.gadgets:
        return const _GadgetExtraFields();

      case LifestyleCategory.appliances:
        return const _ApplianceExtraFields();

      case LifestyleCategory.collections:
        return const SizedBox.shrink();
    }
  }
}

class _Header extends StatelessWidget {
  final String title;

  const _Header({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

class _VehicleExtraFields extends StatelessWidget {
  const _VehicleExtraFields();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        TextField(
          decoration: InputDecoration(
            labelText: 'Vehicle Number',
            hintText: 'TN 01 AB 1234',
          ),
        ),
        SizedBox(height: 12),
        TextField(
          decoration: InputDecoration(
            labelText: 'Fuel Type',
            hintText: 'Petrol / Diesel / EV',
          ),
        ),
        SizedBox(height: 12),
      ],
    );
  }
}

class _DressExtraFields extends StatelessWidget {
  const _DressExtraFields();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        TextField(
          decoration: InputDecoration(
            labelText: 'Size',
            hintText: 'S / M / L / XL',
          ),
        ),
        SizedBox(height: 12),
        TextField(
          decoration: InputDecoration(
            labelText: 'Occasion',
            hintText: 'Wedding / Casual',
          ),
        ),
        SizedBox(height: 12),
      ],
    );
  }
}

class _GadgetExtraFields extends StatelessWidget {
  const _GadgetExtraFields();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        TextField(
          decoration: InputDecoration(
            labelText: 'Model',
            hintText: 'iPhone 14 / Galaxy S23',
          ),
        ),
        SizedBox(height: 12),
        TextField(
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Warranty (years)'),
        ),

        SizedBox(height: 12),
      ],
    );
  }
}

class _ApplianceExtraFields extends StatelessWidget {
  const _ApplianceExtraFields();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        TextField(
          decoration: InputDecoration(
            labelText: 'Room',
            hintText: 'Kitchen / Bedroom',
          ),
        ),
        SizedBox(height: 12),
      ],
    );
  }
}

class _CommonFields extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController brandCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController notesCtrl;
  final DateTime? purchaseDate;
  final ValueChanged<DateTime> onPickDate;

  const _CommonFields({
    required this.nameCtrl,
    required this.brandCtrl,
    required this.priceCtrl,
    required this.notesCtrl,
    required this.purchaseDate,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: brandCtrl,
          decoration: const InputDecoration(labelText: 'Brand'),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: priceCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Price (optional)'),
        ),
        const SizedBox(height: 12),

        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today),
          title: Text(
            purchaseDate == null
                ? 'Select purchase date'
                : 'Purchased on ${purchaseDate!.toLocal().toString().split(' ')[0]}',
          ),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (picked != null) onPickDate(picked);
          },
        ),

        TextField(
          controller: notesCtrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Notes'),
        ),
      ],
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
