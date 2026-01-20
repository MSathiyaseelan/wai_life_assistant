import 'dart:io';
import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import 'package:image_picker/image_picker.dart';

class SplitEquallyFormContent extends StatefulWidget {
  const SplitEquallyFormContent({super.key});

  @override
  State<SplitEquallyFormContent> createState() =>
      _SplitEquallyFormContentState();
}

class _SplitEquallyFormContentState extends State<SplitEquallyFormContent> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _groupNameController = TextEditingController();

  File? groupImage;
  String? selectedGroupType;

  final List<String> groupTypes = [
    'Friends',
    'Family',
    'Trip',
    'Office',
    'Custom',
  ];

  final List<MemberModel> selectedMembers = [];

  bool get isFormValid =>
      _groupNameController.text.trim().isNotEmpty &&
      selectedGroupType != null &&
      selectedMembers.length >= 2;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Title
          Text('Create Group', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.gapSM),

          /// Group Image
          Center(child: _buildGroupImage()),
          const SizedBox(height: AppSpacing.gapMM),

          /// Group Name
          TextFormField(
            controller: _groupNameController,
            decoration: const InputDecoration(
              labelText: 'Group Name',
              hintText: 'Trip to Goa',
            ),
            validator: (v) =>
                v == null || v.isEmpty ? 'Enter group name' : null,
          ),

          const SizedBox(height: AppSpacing.gapMM),

          /// Group Type
          Text('Group Type', style: textTheme.labelLarge),
          const SizedBox(height: AppSpacing.gapSM),
          Wrap(
            spacing: 8,
            children: groupTypes.map((type) {
              return ChoiceChip(
                label: Text(type),
                selected: selectedGroupType == type,
                onSelected: (_) {
                  setState(() => selectedGroupType = type);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: AppSpacing.gapMM),

          /// Members Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Members (${selectedMembers.length})',
                style: textTheme.labelLarge,
              ),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: _openContactPicker,
              ),
            ],
          ),

          /// Selected Members
          if (selectedMembers.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.gapSM),
            _buildSelectedMembers(),
          ],

          const SizedBox(height: AppSpacing.gapL),

          /// Buttons
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
                  onPressed: isFormValid ? _submit : null,
                  child: const Text('Create'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- UI HELPERS ----------------

  Widget _buildGroupImage() {
    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: CircleAvatar(
            radius: 44,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            backgroundImage: groupImage != null ? FileImage(groupImage!) : null,
            child: groupImage == null
                ? Icon(
                    Icons.group,
                    size: 40,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )
                : null,
          ),
        ),

        Positioned(
          bottom: 0,
          right: 0,
          child: InkWell(
            onTap: _pickGroupImage,
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(
                Icons.camera_alt,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedMembers() {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: selectedMembers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, index) {
          final member = selectedMembers[index];
          return Stack(
            children: [
              CircleAvatar(radius: 28, child: Text(member.initials)),
              Positioned(
                top: -2,
                right: -2,
                child: GestureDetector(
                  onTap: () {
                    setState(() => selectedMembers.removeAt(index));
                  },
                  child: const CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close, size: 12, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------- ACTIONS ----------------

  final ImagePicker _picker = ImagePicker();

  void _pickGroupImage() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80, // compress
        maxWidth: 1024,
      );

      if (pickedFile != null) {
        setState(() {
          groupImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
    }
  }

  void _openContactPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return ContactPickerSheet(
          alreadySelected: selectedMembers,
          onDone: (members) {
            setState(() {
              selectedMembers
                ..clear()
                ..addAll(members);
            });
          },
        );
      },
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final groupData = {
      'groupName': _groupNameController.text,
      'groupType': selectedGroupType,
      'members': selectedMembers.map((e) => e.name).toList(),
    };

    debugPrint('Group Created: $groupData');
    Navigator.pop(context);
  }
}

// ---------------- MODELS ----------------

class MemberModel {
  final String id;
  final String name;

  MemberModel({required this.id, required this.name});

  String get initials =>
      name.isNotEmpty ? name.trim().substring(0, 1).toUpperCase() : '?';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MemberModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ---------------- CONTACT PICKER (SAME STYLE) ----------------

class ContactPickerSheet extends StatefulWidget {
  final List<MemberModel> alreadySelected;
  final Function(List<MemberModel>) onDone;

  const ContactPickerSheet({
    super.key,
    required this.alreadySelected,
    required this.onDone,
  });

  @override
  State<ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<ContactPickerSheet> {
  final TextEditingController searchController = TextEditingController();
  final List<MemberModel> allContacts = mockContacts;
  late List<MemberModel> selected;

  @override
  void initState() {
    selected = [...widget.alreadySelected];
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = allContacts
        .where(
          (e) => e.name.toLowerCase().contains(
            searchController.text.toLowerCase(),
          ),
        )
        .toList();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search contacts',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, index) {
                final contact = filtered[index];
                final isSelected = selected.contains(contact);

                return ListTile(
                  leading: CircleAvatar(child: Text(contact.initials)),
                  title: Text(contact.name),
                  trailing: Checkbox(
                    value: isSelected,
                    onChanged: (_) {
                      setState(() {
                        isSelected
                            ? selected.remove(contact)
                            : selected.add(contact);
                      });
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton(
              onPressed: () {
                widget.onDone(selected);
                Navigator.pop(context);
              },
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- MOCK DATA ----------------

final List<MemberModel> mockContacts = [
  MemberModel(id: '1', name: 'Arun'),
  MemberModel(id: '2', name: 'Bala'),
  MemberModel(id: '3', name: 'Charan'),
  MemberModel(id: '4', name: 'Divya'),
  MemberModel(id: '5', name: 'Elan'),
];
