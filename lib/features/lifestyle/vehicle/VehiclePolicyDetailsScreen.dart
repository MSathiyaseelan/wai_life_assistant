import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/models/lifestyle/vehicle/VehiclePolicy.dart';
import 'AddPolicyBottomSheet.dart';
import 'package:wai_life_assistant/data/models/lifestyle/vehicle/Vehicle.dart';

class VehiclePolicyDetailsScreen extends StatefulWidget {
  final Vehicle vehicle;

  const VehiclePolicyDetailsScreen({super.key, required this.vehicle});

  @override
  State<VehiclePolicyDetailsScreen> createState() =>
      _VehiclePolicyDetailsScreenState();
}

class _VehiclePolicyDetailsScreenState
    extends State<VehiclePolicyDetailsScreen> {
  bool isEditing = false;

  @override
  Widget build(BuildContext context) {
    final policy = widget.vehicle.policy;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Policy Details'),
        actions: [
          if (policy == null)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _openAddPolicySheet(context),
            )
          else
            IconButton(
              icon: Icon(isEditing ? Icons.check : Icons.edit),
              onPressed: () {
                setState(() => isEditing = !isEditing);
              },
            ),
        ],
      ),
      body: policy == null
          ? const _EmptyPolicyState()
          : _PolicyDetailsView(policy: policy, editable: isEditing),
    );
  }

  void _openAddPolicySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AddPolicyBottomSheet(),
    );
  }
}

class _EmptyPolicyState extends StatelessWidget {
  const _EmptyPolicyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No policy added yet',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _PolicyDetailsView extends StatelessWidget {
  final VehiclePolicy policy;
  final bool editable;

  const _PolicyDetailsView({required this.policy, required this.editable});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PolicyField(
          label: 'Insurance Provider',
          value: policy.provider,
          editable: editable,
        ),
        _PolicyField(
          label: 'Policy Number',
          value: policy.policyNumber,
          editable: editable,
        ),
        _PolicyField(
          label: 'Insurance Type',
          value: policy.type.name,
          editable: editable,
        ),
        _PolicyField(
          label: 'Insurance Start Date',
          value: _formatDate(policy.startDate),
          editable: editable,
        ),
        _PolicyField(
          label: 'Insurance Expiry Date',
          value: _formatDate(policy.expiryDate),
          editable: editable,
        ),
        if (policy.idvValue != null)
          _PolicyField(
            label: 'IDV Value',
            value: '₹${policy.idvValue}',
            editable: editable,
          ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return date.toLocal().toString().split(' ')[0];
  }
}

class _PolicyField extends StatelessWidget {
  final String label;
  final String value;
  final bool editable;

  const _PolicyField({
    required this.label,
    required this.value,
    required this.editable,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: editable
            ? TextFormField(
                initialValue: value,
                decoration: InputDecoration(labelText: label),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
      ),
    );
  }
}
