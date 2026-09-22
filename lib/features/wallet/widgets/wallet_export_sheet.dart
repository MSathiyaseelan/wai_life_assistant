import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wai_life_assistant/core/services/app_prefs.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/features/wallet/widgets/month_year_picker.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WALLET EXPORT SHEET
// Export the current (or a selected range of) month's transactions as a CSV
// report, shared via the native share sheet.
// ─────────────────────────────────────────────────────────────────────────────

class WalletExportSheet extends StatefulWidget {
  final String walletId;
  final String walletName;
  final List<TxModel> transactions;

  const WalletExportSheet({
    super.key,
    required this.walletId,
    required this.walletName,
    required this.transactions,
  });

  static Future<void> show(
    BuildContext context, {
    required String walletId,
    required String walletName,
    required List<TxModel> transactions,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WalletExportSheet(
        walletId: walletId,
        walletName: walletName,
        transactions: transactions,
      ),
    );
  }

  @override
  State<WalletExportSheet> createState() => _WalletExportSheetState();
}

class _WalletExportSheetState extends State<WalletExportSheet> {
  MonthRange _range = MonthRange.thisMonth();
  bool _exporting = false;

  List<TxModel> get _matching => widget.transactions
      .where((t) => t.walletId == widget.walletId && _range.contains(t.date))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  Future<void> _pickRange() async {
    final picked = await MonthYearPicker.showPicker(context, _range);
    if (picked != null) setState(() => _range = picked);
  }

  String _csvField(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  String _buildCsv(List<TxModel> txs) {
    final buf = StringBuffer('Date,Type,Category,Title,Amount,Pay Mode,Person,Note\n');
    for (final t in txs) {
      final row = [
        '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}',
        t.type.label,
        t.category,
        t.title ?? '',
        t.amount.toStringAsFixed(2),
        t.payMode?.name ?? '',
        t.person ?? '',
        t.note ?? '',
      ].map(_csvField).join(',');
      buf.writeln(row);
    }
    return buf.toString();
  }

  Future<void> _export() async {
    if (_exporting) return;
    final txs = _matching;
    if (txs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions in this range.')),
      );
      return;
    }
    setState(() => _exporting = true);
    try {
      final csv = _buildCsv(txs);
      final dir = await getTemporaryDirectory();
      final stamp = _range.label.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      final fileName = '${widget.walletName}_transactions_$stamp.csv'
          .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(csv);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: '${widget.walletName} transactions — ${_range.label}',
          text: 'Transaction report for ${_range.label}.',
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'wallet_export_transactions');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    final txs = _matching;
    final income = txs.where((t) => t.type == TxType.income).fold(0.0, (s, t) => s + t.amount);
    final expense = txs.where((t) => t.type == TxType.expense).fold(0.0, (s, t) => s + t.amount);

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Text('📤', style: TextStyle(fontSize: 26)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Export Transactions',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: tc)),
                          Text('Download a CSV report for a month or a range',
                              style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub)),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  MonthYearPicker(selected: _range, onTap: _pickRange),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: surfBg, borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${txs.length}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'DM Mono', color: tc)),
                            Text('transactions', style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${AppPrefs.cs}${income.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, fontFamily: 'DM Mono', color: AppColors.income)),
                            Text('income', style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${AppPrefs.cs}${expense.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, fontFamily: 'DM Mono', color: AppColors.expense)),
                            Text('expense', style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _exporting ? null : _export,
                      icon: _exporting
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.ios_share_rounded, size: 18, color: Colors.white),
                      label: Text(
                        _exporting ? 'Preparing…' : 'Export CSV',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, fontFamily: 'Nunito', color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
