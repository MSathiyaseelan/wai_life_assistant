import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyleItem.dart';

class VehicleIdentityDetailsScreen extends StatefulWidget {
  final LifestyleItem vehicle;

  const VehicleIdentityDetailsScreen({super.key, required this.vehicle});

  @override
  State<VehicleIdentityDetailsScreen> createState() =>
      _VehicleIdentityDetailsScreenState();
}

class _VehicleIdentityDetailsScreenState
    extends State<VehicleIdentityDetailsScreen> {
  bool _isEditing = false;

  late TextEditingController _rcCtrl;
  late TextEditingController _engineCtrl;
  late TextEditingController _chassisCtrl;

  String? _fuelType;
  DateTime? _registrationDate;
  DateTime? _pucExpiryDate;

  @override
  void initState() {
    super.initState();

    _rcCtrl = TextEditingController();
    _engineCtrl = TextEditingController();
    _chassisCtrl = TextEditingController();

    /// Auto-fill registration date from purchase date
    _registrationDate = widget.vehicle.purchaseDate;
  }

  @override
  void dispose() {
    _rcCtrl.dispose();
    _engineCtrl.dispose();
    _chassisCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Identity Details'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            onPressed: () {
              setState(() => _isEditing = !_isEditing);

              if (!_isEditing) {
                // TODO: Save identity details to DB / controller
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DateField(
            label: 'Registration Date',
            value: _registrationDate,
            enabled: _isEditing,
            onPick: (d) => setState(() => _registrationDate = d),
          ),

          _ReadOnlyHint(
            label: 'Registration Validity',
            value: _registrationDate == null
                ? '-'
                : '${_registrationDate!.year + 15}',
          ),

          _TextField(
            controller: _rcCtrl,
            label: 'RC Number',
            enabled: _isEditing,
          ),

          _DropdownField(
            label: 'Fuel Type',
            value: _fuelType,
            enabled: _isEditing,
            items: const ['Petrol', 'Diesel', 'CNG', 'Electric'],
            onChanged: (v) => setState(() => _fuelType = v),
          ),

          _TextField(
            controller: _engineCtrl,
            label: 'Engine Number',
            enabled: _isEditing,
          ),

          _TextField(
            controller: _chassisCtrl,
            label: 'Chassis Number',
            enabled: _isEditing,
          ),

          _DateField(
            label: 'PUC Expiry Date',
            value: _pucExpiryDate,
            enabled: _isEditing,
            onPick: (d) => setState(() => _pucExpiryDate = d),
          ),
        ],
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool enabled;

  const _TextField({
    required this.controller,
    required this.label,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final bool enabled;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(labelText: label),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final bool enabled;
  final ValueChanged<DateTime> onPick;

  const _DateField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: !enabled
            ? null
            : () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: value ?? DateTime.now(),
                  firstDate: DateTime(1990),
                  lastDate: DateTime(2100),
                );
                if (date != null) onPick(date);
              },
        child: InputDecorator(
          decoration: InputDecoration(labelText: label),
          child: Text(
            value == null
                ? 'Select date'
                : value!.toLocal().toString().split(' ')[0],
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyHint extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyHint({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value),
      ),
    );
  }
}
