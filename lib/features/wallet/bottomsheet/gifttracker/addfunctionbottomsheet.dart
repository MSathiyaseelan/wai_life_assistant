import 'package:flutter/material.dart';

class AddFunctionBottomSheet extends StatefulWidget {
  const AddFunctionBottomSheet({super.key});

  @override
  State<AddFunctionBottomSheet> createState() => _AddFunctionBottomSheetState();
}

class _AddFunctionBottomSheetState extends State<AddFunctionBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  final _functionNameCtrl = TextEditingController();
  final _personCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();

  DateTime? _selectedDate;
  String _functionType = "Marriage";

  final List<String> functionTypes = [
    "Marriage",
    "Birthday",
    "Religious",
    "House Warming",
    "Other",
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  "Add Function",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),

              const SizedBox(height: 16),

              /// Function Name
              TextFormField(
                controller: _functionNameCtrl,
                decoration: const InputDecoration(
                  labelText: "Function Name",
                  hintText: "My Marriage",
                ),
                validator: (v) => v == null || v.isEmpty ? "Required" : null,
              ),

              const SizedBox(height: 12),

              /// Function Type
              DropdownButtonFormField<String>(
                value: _functionType,
                items: functionTypes
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _functionType = value!;
                  });
                },
                decoration: const InputDecoration(labelText: "Function Type"),
              ),

              const SizedBox(height: 12),

              /// Person
              TextFormField(
                controller: _personCtrl,
                decoration: const InputDecoration(
                  labelText: "Person",
                  hintText: "Self / Son / Daughter",
                ),
              ),

              const SizedBox(height: 12),

              /// Date Picker
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    initialDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: "Function Date"),
                  child: Text(
                    _selectedDate == null
                        ? "Select date"
                        : "${_selectedDate!.day}-${_selectedDate!.month}-${_selectedDate!.year}",
                  ),
                ),
              ),

              const SizedBox(height: 12),

              /// Venue (Optional)
              TextFormField(
                controller: _venueCtrl,
                decoration: const InputDecoration(
                  labelText: "Venue (optional)",
                ),
              ),

              const SizedBox(height: 24),

              /// Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      // TODO: Save function to DB
                      Navigator.pop(context);
                    }
                  },
                  child: const Text("Save Function"),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
