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

  // 🔹 Vehicle controllers
  final _vehicleNameCtrl = TextEditingController();
  final _vehicleNumberCtrl = TextEditingController();
  final _vehicleBrandCtrl = TextEditingController();
  final _vehicleModelCtrl = TextEditingController();

  // 🔹 Dropdown values
  String? _vehicleType;
  String _vehicleOwner = 'Self';

  // 🔹 Vehicle purchase date
  DateTime? _vehiclePurchaseDate;

  DateTime? _purchaseDate;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    _vehicleNameCtrl.dispose();
    _vehicleNumberCtrl.dispose();
    _vehicleBrandCtrl.dispose();
    _vehicleModelCtrl.dispose();
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

            // const SizedBox(height: 12),

            // _CommonFields(
            //   nameCtrl: _nameCtrl,
            //   brandCtrl: _brandCtrl,
            //   priceCtrl: _priceCtrl,
            //   notesCtrl: _notesCtrl,
            //   purchaseDate: _purchaseDate,
            //   onPickDate: (date) => setState(() => _purchaseDate = date),
            // ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                child: const Text('Save'),
                onPressed: () {
                  final controller = context.read<LifestyleController>();

                  if (_vehicleNameCtrl.text.trim().isEmpty ||
                      _vehicleType == null ||
                      _vehicleNumberCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill required vehicle details'),
                      ),
                    );
                    return;
                  }

                  controller.addItem(
                    LifestyleItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      category: LifestyleCategory.vehicle,
                      name: _vehicleNameCtrl.text.trim(),
                      vehicleType: _vehicleType,
                      vehicleNumber: _vehicleNumberCtrl.text.trim(),
                      owner: _vehicleOwner,
                      brand: _vehicleBrandCtrl.text.trim().isEmpty
                          ? null
                          : _vehicleBrandCtrl.text.trim(),
                      model: _vehicleModelCtrl.text.trim().isEmpty
                          ? null
                          : _vehicleModelCtrl.text.trim(),
                      purchaseDate: _vehiclePurchaseDate,
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
        //return const _VehicleExtraFields();
        return _VehicleExtraFields(
          vehicleNameCtrl: _vehicleNameCtrl,
          vehicleNumberCtrl: _vehicleNumberCtrl,
          brandCtrl: _vehicleBrandCtrl,
          modelCtrl: _vehicleModelCtrl,
          vehicleType: _vehicleType,
          owner: _vehicleOwner,
          purchaseDate: _vehiclePurchaseDate,
          onVehicleTypeChanged: (v) => setState(() => _vehicleType = v),
          onOwnerChanged: (v) => setState(() => _vehicleOwner = v),
          onPickDate: (date) => setState(() => _vehiclePurchaseDate = date),
        );

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
  final TextEditingController vehicleNameCtrl;
  final TextEditingController vehicleNumberCtrl;
  final TextEditingController brandCtrl;
  final TextEditingController modelCtrl;

  final String? vehicleType;
  final String owner;
  final DateTime? purchaseDate;

  final ValueChanged<String?> onVehicleTypeChanged;
  final ValueChanged<String> onOwnerChanged;
  final ValueChanged<DateTime> onPickDate;

  const _VehicleExtraFields({
    required this.vehicleNameCtrl,
    required this.vehicleNumberCtrl,
    required this.brandCtrl,
    required this.modelCtrl,
    required this.vehicleType,
    required this.owner,
    required this.purchaseDate,
    required this.onVehicleTypeChanged,
    required this.onOwnerChanged,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        /// 🚗 Vehicle Name
        TextField(
          controller: vehicleNameCtrl,
          decoration: const InputDecoration(
            labelText: 'Vehicle Name',
            hintText: 'My Car / Dad Bike',
          ),
        ),
        const SizedBox(height: 12),

        /// 🚘 Vehicle Type
        DropdownButtonFormField<String>(
          value: vehicleType,
          decoration: const InputDecoration(labelText: 'Vehicle Type'),
          items: const [
            DropdownMenuItem(value: 'Car', child: Text('Car')),
            DropdownMenuItem(value: 'Bike', child: Text('Bike')),
            DropdownMenuItem(value: 'Scooter', child: Text('Scooter')),
            DropdownMenuItem(value: 'Truck', child: Text('Truck')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
          onChanged: onVehicleTypeChanged,
        ),
        const SizedBox(height: 12),

        /// 🔢 Vehicle Number
        TextField(
          controller: vehicleNumberCtrl,
          decoration: const InputDecoration(
            labelText: 'Vehicle Number',
            hintText: 'TN 01 AB 1234',
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 12),

        /// 👤 Owner
        DropdownButtonFormField<String>(
          value: owner,
          decoration: const InputDecoration(labelText: 'Owner'),
          items: const [
            DropdownMenuItem(value: 'Self', child: Text('Self')),
            DropdownMenuItem(value: 'Family', child: Text('Family Member')),
          ],
          onChanged: (v) {
            if (v != null) onOwnerChanged(v);
          },
        ),
        const SizedBox(height: 12),

        /// 🏷 Brand
        TextField(
          controller: brandCtrl,
          decoration: const InputDecoration(
            labelText: 'Brand',
            hintText: 'Honda / Hyundai / Tata',
          ),
        ),
        const SizedBox(height: 12),

        /// 📘 Model
        TextField(
          controller: modelCtrl,
          decoration: const InputDecoration(
            labelText: 'Model',
            hintText: 'City / i20 / Activa',
          ),
        ),
        const SizedBox(height: 12),

        /// 📅 Purchase Date
        TextField(
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'Purchase Date',
            hintText: purchaseDate == null
                ? 'Select date'
                : '${purchaseDate!.day}/${purchaseDate!.month}/${purchaseDate!.year}',
            suffixIcon: const Icon(Icons.calendar_today),
          ),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: purchaseDate ?? DateTime.now(),
              firstDate: DateTime(1990),
              lastDate: DateTime.now(),
            );

            if (date != null) onPickDate(date);
          },
        ),
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
