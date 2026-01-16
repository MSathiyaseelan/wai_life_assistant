import 'package:flutter/material.dart';

class SplitByPercentagePage extends StatefulWidget {
  final double totalAmount;
  final List<String> participants;

  const SplitByPercentagePage({
    super.key,
    required this.totalAmount,
    required this.participants,
  });

  @override
  State<SplitByPercentagePage> createState() => _SplitByPercentagePageState();
}

class _SplitByPercentagePageState extends State<SplitByPercentagePage> {
  late List<PercentageParticipant> _members;

  @override
  void initState() {
    super.initState();
    _members = widget.participants
        .map((e) => PercentageParticipant(name: e))
        .toList();
  }

  double get _totalPercentage {
    return _members.fold(
      0,
      (sum, m) => sum + (double.tryParse(m.percentCtrl.text) ?? 0),
    );
  }

  double _amountFor(double percent) => (widget.totalAmount * percent) / 100;

  double get _remainingPercentage => 100 - _totalPercentage;

  bool get _isValid => _remainingPercentage == 0;

  @override
  void dispose() {
    for (final m in _members) {
      m.percentCtrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Split by Percentage')),
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
                  _remainingPercentage == 0
                      ? 'Total: 100%'
                      : _remainingPercentage > 0
                      ? 'Remaining: ${_remainingPercentage.toStringAsFixed(1)}%'
                      : 'Exceeded by: ${(-_remainingPercentage).toStringAsFixed(1)}%',
                  style: textTheme.bodyMedium?.copyWith(
                    color: _remainingPercentage == 0
                        ? Colors.green
                        : colors.error,
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
                final percent = double.tryParse(member.percentCtrl.text) ?? 0;
                final amount = _amountFor(percent);

                return ListTile(
                  title: Text(member.name),
                  subtitle: Text(
                    '₹ ${amount.toStringAsFixed(2)}',
                    style: textTheme.bodySmall,
                  ),
                  trailing: SizedBox(
                    width: 110,
                    child: TextField(
                      controller: member.percentCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        suffixText: '%',
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

class PercentageParticipant {
  final String name;
  final TextEditingController percentCtrl;

  PercentageParticipant({required this.name, String initialPercent = ''})
    : percentCtrl = TextEditingController(text: initialPercent);
}
