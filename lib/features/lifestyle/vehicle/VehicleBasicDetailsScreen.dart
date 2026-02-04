import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyleItem.dart';

class VehicleBasicDetailsScreen extends StatefulWidget {
  final LifestyleItem vehicle;

  const VehicleBasicDetailsScreen({super.key, required this.vehicle});

  @override
  State<VehicleBasicDetailsScreen> createState() =>
      _VehicleBasicDetailsScreenState();
}

class _VehicleBasicDetailsScreenState extends State<VehicleBasicDetailsScreen> {
  bool _isEditing = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _numberCtrl;
  late TextEditingController _brandCtrl;
  late TextEditingController _modelCtrl;

  String _vehicleType = 'Car';
  String _owner = 'Self';
  DateTime? _purchaseDate;

  @override
  void initState() {
    super.initState();

    _nameCtrl = TextEditingController(text: widget.vehicle.name);
    _numberCtrl = TextEditingController(text: widget.vehicle.brand);
    _brandCtrl = TextEditingController(text: widget.vehicle.brand);
    _modelCtrl = TextEditingController();
    _purchaseDate = widget.vehicle.purchaseDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _numberCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Basic Details'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: () {
              setState(() => _isEditing = !_isEditing);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _field(
              label: 'Vehicle Name',
              child: TextField(
                controller: _nameCtrl,
                enabled: _isEditing,
                decoration: const InputDecoration(
                  hintText: 'Honda City / Activa 6G',
                ),
              ),
            ),

            _dropdown(
              label: 'Vehicle Type',
              value: _vehicleType,
              items: const ['Car', 'Bike', 'Scooter', 'EV'],
              enabled: _isEditing,
              onChanged: (v) => _vehicleType = v!,
            ),

            _field(
              label: 'Vehicle Number',
              child: TextField(
                controller: _numberCtrl,
                enabled: _isEditing,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'TN 01 AB 1234'),
              ),
            ),

            _dropdown(
              label: 'Owner',
              value: _owner,
              items: const ['Self', 'Family Member'],
              enabled: _isEditing,
              onChanged: (v) => _owner = v!,
            ),

            _field(
              label: 'Brand',
              child: TextField(
                controller: _brandCtrl,
                enabled: _isEditing,
                decoration: const InputDecoration(
                  hintText: 'Honda / Tata / TVS',
                ),
              ),
            ),

            _field(
              label: 'Model',
              child: TextField(
                controller: _modelCtrl,
                enabled: _isEditing,
                decoration: const InputDecoration(
                  hintText: 'City ZX / Nexon EV',
                ),
              ),
            ),

            _field(
              label: 'Purchase Date',
              child: InkWell(
                onTap: !_isEditing
                    ? null
                    : () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _purchaseDate ?? DateTime.now(),
                          firstDate: DateTime(1990),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _purchaseDate = date);
                        }
                      },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _purchaseDate == null
                        ? 'Select date'
                        : DateFormat('dd MMM yyyy').format(_purchaseDate!),
                  ),
                ),
              ),
            ),

            if (_isEditing) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _isEditing = false);
                      },
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _save() {
    // TODO: update Vehicle / LifestyleController here
    setState(() => _isEditing = false);
  }

  Widget _field({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required bool enabled,
    required ValueChanged<String?> onChanged,
  }) {
    return _field(
      label: label,
      child: DropdownButtonFormField<String>(
        value: value,
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: enabled ? onChanged : null,
        decoration: const InputDecoration(),
      ),
    );
  }
}
