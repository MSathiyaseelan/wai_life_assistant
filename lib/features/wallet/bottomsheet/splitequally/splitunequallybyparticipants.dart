import 'package:flutter/material.dart';

class SplitUnequallybyParticipantsPage extends StatefulWidget {
  final double totalAmount;
  final List<String> participants;

  const SplitUnequallybyParticipantsPage({
    super.key,
    required this.totalAmount,
    required this.participants,
  });

  @override
  State<SplitUnequallybyParticipantsPage> createState() =>
      _SplitUnequallybyParticipantsPageState();
}

class _SplitUnequallybyParticipantsPageState
    extends State<SplitUnequallybyParticipantsPage> {
  late List<UnequalParticipant> _members;

  @override
  void initState() {
    super.initState();
    _members = widget.participants
        .map((e) => UnequalParticipant(name: e))
        .toList();
  }

  double get _totalEntered {
    return _members.fold(
      0,
      (sum, m) => sum + (double.tryParse(m.amountCtrl.text) ?? 0),
    );
  }

  double get _remaining => widget.totalAmount - _totalEntered;

  bool get _isValid => _remaining == 0;

  @override
  void dispose() {
    for (final m in _members) {
      m.amountCtrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Split Unequally')),
      body: Column(
        children: [
          /// Summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
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

                const SizedBox(height: 8),

                Text(
                  _remaining >= 0
                      ? 'Remaining: ₹ ${_remaining.toStringAsFixed(2)}'
                      : 'Exceeded by: ₹ ${(-_remaining).toStringAsFixed(2)}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: _remaining == 0
                        ? Colors.green
                        : (_remaining > 0 ? colors.error : colors.error),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          /// Editable list
          Expanded(
            child: ListView.separated(
              itemCount: _members.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final member = _members[index];

                return ListTile(
                  title: Text(member.name),
                  trailing: SizedBox(
                    width: 110,
                    child: TextField(
                      controller: member.amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        prefixText: '₹ ',
                        hintText: '0',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
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
                  onPressed: _isValid
                      ? () {
                          Navigator.pop(context, _members);
                        }
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

class UnequalParticipant {
  final String name;
  final TextEditingController amountCtrl;

  UnequalParticipant({required this.name, String initialAmount = ''})
    : amountCtrl = TextEditingController(text: initialAmount);
}
