import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/models/lifestyle/vehicle/VehiclePolicy.dart';

class AddPolicyBottomSheet extends StatefulWidget {
  const AddPolicyBottomSheet({super.key});

  @override
  State<AddPolicyBottomSheet> createState() => _AddPolicyBottomSheetState();
}

class _AddPolicyBottomSheetState extends State<AddPolicyBottomSheet> {
  final providerCtrl = TextEditingController();
  final policyNoCtrl = TextEditingController();
  final idvCtrl = TextEditingController();

  InsuranceType type = InsuranceType.comprehensive;
  DateTime? startDate;
  DateTime? expiryDate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: providerCtrl,
            decoration: const InputDecoration(labelText: 'Insurance Provider'),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: policyNoCtrl,
            decoration: const InputDecoration(labelText: 'Policy Number'),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<InsuranceType>(
            value: type,
            items: InsuranceType.values
                .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                .toList(),
            onChanged: (v) => setState(() => type = v!),
            decoration: const InputDecoration(labelText: 'Insurance Type'),
          ),
          const SizedBox(height: 12),

          _DatePickerField(
            label: 'Insurance Start Date',
            value: startDate,
            onChanged: (d) => setState(() => startDate = d),
          ),
          const SizedBox(height: 12),

          _DatePickerField(
            label: 'Insurance Expiry Date',
            value: expiryDate,
            onChanged: (d) => setState(() => expiryDate = d),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              child: const Text('Save Policy'),
              onPressed: () {
                // save policy to vehicle/controller
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(1990),
          lastDate: DateTime(2100),
        );

        if (picked != null) {
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(
          value == null
              ? 'Select date'
              : value!.toLocal().toString().split(' ')[0],
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
