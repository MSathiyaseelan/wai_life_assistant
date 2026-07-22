import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/wallet/flow_models.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/features/wallet/widgets/wallet_bill_scan_sheet.dart';

class FlowSelectorSheet extends StatelessWidget {
  final void Function(FlowType) onSelect;
  final String walletId;
  final void Function(List<TxModel>) onScanBillSaved;

  const FlowSelectorSheet({
    super.key,
    required this.onSelect,
    required this.walletId,
    required this.onScanBillSaved,
  });

  /// Opens as a bottom sheet
  static Future<void> show(
    BuildContext context, {
    required void Function(FlowType) onSelect,
    required String walletId,
    required void Function(List<TxModel>) onScanBillSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => FlowSelectorSheet(
        onSelect: onSelect,
        walletId: walletId,
        onScanBillSaved: onScanBillSaved,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              child: Column(
                children: [
                  const Text('💬', style: TextStyle(fontSize: 36)),
                  const SizedBox(height: 10),
                  Text(
                    'What would you like to do?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                      color: isDark ? AppColors.textDark : AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to start a conversation',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Nunito',
                      color: isDark ? AppColors.subDark : AppColors.subLight,
                    ),
                  ),
                ],
              ),
            ),

            // Flow grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.9,
                children: [
                  ...FlowType.values
                      .where((f) => f != FlowType.split) // Split Bill hidden — use Splits tab instead
                      .map(
                        (f) => _FlowCard(
                          flow: f,
                          onTap: () {
                            Navigator.pop(context);
                            onSelect(f);
                          },
                        ),
                      ),
                  // Scan Bill isn't a conversational flow (no FlowType of its
                  // own) — it opens the AI bill-scan sheet directly instead.
                  _ScanBillCard(
                    onTap: () {
                      Navigator.pop(context);
                      WalletBillScanSheet.show(
                        context,
                        walletId: walletId,
                        onSaved: onScanBillSaved,
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _ScanBillCard extends StatefulWidget {
  final VoidCallback onTap;

  const _ScanBillCard({required this.onTap});

  @override
  State<_ScanBillCard> createState() => _ScanBillCardState();
}

class _ScanBillCardState extends State<_ScanBillCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const c = AppColors.income;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_pressed ? 0.93 : 1.0),
        transformAlignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: _pressed ? c.withOpacity(0.2) : c.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: c.withOpacity(_pressed ? 0.18 : 0.06),
              blurRadius: _pressed ? 12 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🧾', style: TextStyle(fontSize: 28)),
            SizedBox(height: 8),
            Text(
              'Scan Bill',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                fontFamily: 'Nunito',
                color: c,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowCard extends StatefulWidget {
  final FlowType flow;
  final VoidCallback onTap;

  const _FlowCard({required this.flow, required this.onTap});

  @override
  State<_FlowCard> createState() => _FlowCardState();
}

class _FlowCardState extends State<_FlowCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.flow.color;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_pressed ? 0.93 : 1.0),
        transformAlignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: _pressed ? c.withOpacity(0.2) : c.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: c.withOpacity(_pressed ? 0.18 : 0.06),
              blurRadius: _pressed ? 12 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.flow.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(
              widget.flow.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                fontFamily: 'Nunito',
                color: c,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
