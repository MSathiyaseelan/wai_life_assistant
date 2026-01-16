import 'package:flutter/material.dart';

class SplitEquallybyParticipantsPage extends StatefulWidget {
  final double totalAmount;
  final List<String> participants;

  const SplitEquallybyParticipantsPage({
    super.key,
    required this.totalAmount,
    required this.participants,
  });

  @override
  State<SplitEquallybyParticipantsPage> createState() =>
      _SplitEquallybyParticipantsPageState();
}

class _SplitEquallybyParticipantsPageState
    extends State<SplitEquallybyParticipantsPage> {
  late List<SplitParticipant> _members;

  @override
  void initState() {
    super.initState();
    _members = widget.participants
        .map((e) => SplitParticipant(name: e))
        .toList();
  }

  double get _perHeadAmount {
    final activeCount = _members.where((m) => m.included).length;

    if (activeCount == 0) return 0;
    return widget.totalAmount / activeCount;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Split Equally')),
      body: Column(
        children: [
          /// Total summary
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            color: colors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Amount', style: textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  '₹ ${widget.totalAmount.toStringAsFixed(2)}',
                  style: textTheme.titleLarge,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          /// Participants list
          Expanded(
            child: ListView.separated(
              itemCount: _members.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final member = _members[index];

                return CheckboxListTile(
                  value: member.included,
                  onChanged: (v) {
                    setState(() => member.included = v ?? true);
                  },
                  title: Text(member.name, style: textTheme.bodyLarge),
                  secondary: Text(
                    member.included
                        ? '₹ ${_perHeadAmount.toStringAsFixed(2)}'
                        : '₹ 0',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                );
              },
            ),
          ),

          /// Footer
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _members.any((m) => m.included)
                      ? () => Navigator.pop(context)
                      : null,
                  child: const Text('Done'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SplitParticipant {
  final String name;
  bool included;

  SplitParticipant({required this.name, this.included = true});
}
