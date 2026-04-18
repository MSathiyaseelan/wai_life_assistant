import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/supabase/wallet_service.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/wallet/flow_models.dart';
import 'package:wai_life_assistant/features/wallet/services/sms_parser_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SmsHistoryImportScreen
//
// Scans the SMS inbox for a user-chosen date range and shows a checklist
// of parsed bank transactions.  User reviews, unchecks any unwanted rows,
// then taps "Import" to bulk-insert them into the active wallet.
// ─────────────────────────────────────────────────────────────────────────────

class SmsHistoryImportScreen extends StatefulWidget {
  final String walletId;
  final VoidCallback? onImported;

  const SmsHistoryImportScreen({
    super.key,
    required this.walletId,
    this.onImported,
  });

  static Future<void> show(
    BuildContext context, {
    required String walletId,
    VoidCallback? onImported,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SmsHistoryImportScreen(
        walletId: walletId,
        onImported: onImported,
      ),
    );
  }

  @override
  State<SmsHistoryImportScreen> createState() => _SmsHistoryImportScreenState();
}

// ── Range options ─────────────────────────────────────────────────────────────

enum _Range { last30, last60, last90, last180 }

extension _RangeExt on _Range {
  String get label => switch (this) {
        _Range.last30  => 'Last 30 days',
        _Range.last60  => 'Last 60 days',
        _Range.last90  => 'Last 90 days',
        _Range.last180 => 'Last 6 months',
      };

  int get days => switch (this) {
        _Range.last30  => 30,
        _Range.last60  => 60,
        _Range.last90  => 90,
        _Range.last180 => 180,
      };
}

// ── State ─────────────────────────────────────────────────────────────────────

class _SmsHistoryImportScreenState extends State<SmsHistoryImportScreen> {
  _Range _range   = _Range.last90;
  bool   _loading = false;
  bool   _saving  = false;
  String? _error;

  List<SmsHistoryItem> _items   = [];
  Set<int>             _checked = {};

  // ── Scan ──────────────────────────────────────────────────────────────────

  Future<void> _scan() async {
    setState(() { _loading = true; _error = null; _items = []; _checked = {}; });

    final now  = DateTime.now();
    final from = now.subtract(Duration(days: _range.days));

    final results = await SMSParserService.scanHistory(from: from, to: now);

    if (!mounted) return;
    setState(() {
      _loading = false;
      _items   = results;
      _checked = Set.from(List.generate(results.length, (i) => i));
      if (results.isEmpty) _error = 'No bank transactions found in this period.';
    });
  }

  // ── Bulk import ───────────────────────────────────────────────────────────

  Future<void> _import() async {
    if (_checked.isEmpty) return;
    setState(() => _saving = true);

    final service = WalletService.instance;
    int saved = 0;

    for (final i in _checked) {
      final item = _items[i];
      final tx   = item.tx;
      try {
        final intent = tx.toParsedIntent();
        await service.addTransaction(
          walletId: widget.walletId,
          type:     intent.flowType == FlowType.expense ? 'expense' : 'income',
          amount:   tx.amount,
          category: tx.category,
          payMode:  tx.paymentMode != null
              ? (tx.paymentMode!.toLowerCase().contains('cash') ||
                      tx.paymentMode!.toLowerCase().contains('atm')
                  ? 'cash'
                  : 'online')
              : null,
          title:    tx.merchant,
          date:     DateTime.tryParse(tx.transactionDate),
        );
        saved++;
      } catch (e) {
        debugPrint('[SmsImport] failed to save item $i: $e');
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$saved transaction${saved == 1 ? '' : 's'} imported')),
    );
    widget.onImported?.call();
    Navigator.pop(context);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg  = isDark ? AppColors.cardDark : Colors.white;
    final tc  = isDark ? AppColors.textDark  : AppColors.textLight;
    final sub = isDark ? AppColors.subDark   : AppColors.subLight;

    final maxH = MediaQuery.of(context).size.height * 0.9;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Handle + header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: sub.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.history, color: Color(0xFF6366F1), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import past transactions',
                          style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w900,
                            fontFamily: 'Nunito', color: tc,
                          ),
                        ),
                        Text(
                          'Scan your SMS inbox history',
                          style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Range selector + scan button ───────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<_Range>(
                            value: _range,
                            style: TextStyle(
                              fontFamily: 'Nunito', fontSize: 13,
                              fontWeight: FontWeight.w700, color: tc,
                            ),
                            dropdownColor: bg,
                            items: _Range.values.map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.label),
                            )).toList(),
                            onChanged: (r) {
                              if (r != null) setState(() => _range = r);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _loading ? null : _scan,
                      icon: _loading
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.search, size: 18),
                      label: Text(
                        _loading ? 'Scanning…' : 'Scan',
                        style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Select all / count row ─────────────────────────────────
                if (_items.isNotEmpty) ...[
                  Row(
                    children: [
                      Text(
                        '${_items.length} transaction${_items.length == 1 ? '' : 's'} found',
                        style: TextStyle(
                          fontSize: 12, fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700, color: sub,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() =>
                            _checked = _checked.length == _items.length
                                ? {}
                                : Set.from(List.generate(_items.length, (i) => i))),
                        child: Text(
                          _checked.length == _items.length ? 'Deselect all' : 'Select all',
                          style: const TextStyle(
                            fontSize: 12, fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700, color: Color(0xFF6366F1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 1),

          // ── List / empty state ─────────────────────────────────────────────
          Expanded(
            child: _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          fontSize: 14, fontFamily: 'Nunito', color: sub,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : _items.isEmpty && !_loading
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Choose a period above and tap Scan\nto find past transactions.',
                            style: TextStyle(
                              fontSize: 14, fontFamily: 'Nunito', color: sub,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, indent: 72, color: sub.withValues(alpha: 0.12)),
                        itemBuilder: (context, i) => _ItemTile(
                          item:      _items[i],
                          checked:   _checked.contains(i),
                          isDark:    isDark,
                          tc:        tc,
                          sub:       sub,
                          onToggle:  () => setState(() {
                            _checked.contains(i) ? _checked.remove(i) : _checked.add(i);
                          }),
                        ),
                      ),
          ),

          // ── Import button ──────────────────────────────────────────────────
          if (_items.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving || _checked.isEmpty ? null : _import,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1e1b4b),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _checked.isEmpty
                                ? 'Select transactions to import'
                                : 'Import ${_checked.length} transaction${_checked.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontFamily: 'Nunito', fontWeight: FontWeight.w800,
                              fontSize: 15, color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Single transaction row ────────────────────────────────────────────────────

class _ItemTile extends StatelessWidget {
  final SmsHistoryItem item;
  final bool           checked;
  final bool           isDark;
  final Color          tc;
  final Color          sub;
  final VoidCallback   onToggle;

  const _ItemTile({
    required this.item,
    required this.checked,
    required this.isDark,
    required this.tc,
    required this.sub,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final tx        = item.tx;
    final isExpense = tx.isExpense;
    final amtColor  = isExpense ? const Color(0xFFEF4444) : const Color(0xFF22C55E);
    final amtSign   = isExpense ? '−' : '+';

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Checkbox
            Checkbox(
              value: checked,
              onChanged: (_) => onToggle(),
              activeColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 4),

            // Category icon bubble
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: (isExpense
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF22C55E))
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isExpense ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 18,
                color: amtColor,
              ),
            ),
            const SizedBox(width: 12),

            // Merchant + date + category
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.merchant ?? tx.category,
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito', color: tc,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        tx.transactionDate,
                        style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: sub.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tx.category,
                          style: TextStyle(
                            fontSize: 10, fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700, color: sub,
                          ),
                        ),
                      ),
                      if (tx.bankName != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          tx.bankName!,
                          style: TextStyle(fontSize: 10, fontFamily: 'Nunito', color: sub),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Amount
            Text(
              '$amtSign₹${tx.amount.toStringAsFixed(tx.amount.truncateToDouble() == tx.amount ? 0 : 2)}',
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w900,
                fontFamily: 'Nunito', color: amtColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
