import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import 'package:wai_life_assistant/features/wallet/features/splitequally.dart';

class SettleUpPage extends StatefulWidget {
  final SplitGroup group;

  const SettleUpPage({super.key, required this.group});

  @override
  State<SettleUpPage> createState() => _SettleUpPageState();
}

class _SettleUpPageState extends State<SettleUpPage> {
  String? _from;
  String? _to;
  String _paymentMode = 'Cash';
  final _noteCtrl = TextEditingController();

  double get settleAmount =>
      widget.group.youOwe > 0 ? widget.group.youOwe : widget.group.youGet;

  @override
  void initState() {
    super.initState();

    /// Default logic
    if (widget.group.youOwe > 0) {
      _from = 'You';
      _to = widget.group.members.first;
    } else {
      _from = widget.group.members.first;
      _to = 'You';
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settle up')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.dblscreenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Amount
            Center(
              child: Text(
                '₹ ${settleAmount.toStringAsFixed(0)}',
                style: textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.gapL),

            /// From
            DropdownMenu<String>(
              width: double.infinity,
              label: const Text('From'),
              initialSelection: _from,
              dropdownMenuEntries: [
                const DropdownMenuEntry(value: 'You', label: 'You'),
                ...widget.group.members.map(
                  (m) => DropdownMenuEntry(value: m, label: m),
                ),
              ],
              onSelected: (v) => setState(() => _from = v),
            ),

            const SizedBox(height: AppSpacing.gapSM),

            /// To
            DropdownMenu<String>(
              width: double.infinity,
              label: const Text('To'),
              initialSelection: _to,
              dropdownMenuEntries: [
                const DropdownMenuEntry(value: 'You', label: 'You'),
                ...widget.group.members.map(
                  (m) => DropdownMenuEntry(value: m, label: m),
                ),
              ],
              onSelected: (v) => setState(() => _to = v),
            ),

            const SizedBox(height: AppSpacing.gapSM),

            /// Payment Mode
            DropdownMenu<String>(
              width: double.infinity,
              initialSelection: _paymentMode,
              label: const Text('Payment mode'),
              dropdownMenuEntries: const [
                DropdownMenuEntry(value: 'Cash', label: 'Cash'),
                DropdownMenuEntry(value: 'UPI', label: 'UPI'),
                DropdownMenuEntry(
                  value: 'Bank Transfer',
                  label: 'Bank Transfer',
                ),
              ],
              onSelected: (v) {
                if (v != null) setState(() => _paymentMode = v);
              },
            ),

            const SizedBox(height: AppSpacing.gapSM),

            /// Note
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Add a note (optional)',
              ),
              maxLines: 2,
            ),

            const Spacer(),

            /// Confirm
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirmSettle,
                child: const Text('Confirm settle'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSettle() {
    if (_from == _to) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('From and To cannot be same')),
      );
      return;
    }

    final result = {
      'from': _from,
      'to': _to,
      'amount': settleAmount,
      'mode': _paymentMode,
      'note': _noteCtrl.text,
    };

    Navigator.pop(context, result);
  }
}
