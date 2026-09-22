import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';
import 'package:wai_life_assistant/data/models/wallet/split_group_models.dart';

/// Exports a split group's expenses (one row per participant share) as a
/// CSV and hands it to the native share sheet. Single-tap, no range picker —
/// a split group's data is naturally bounded (unlike the full wallet ledger).
class SplitExportService {
  SplitExportService._();

  static String _csvField(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static String _buildCsv(SplitGroup group) {
    final buf = StringBuffer(
      'Date,Expense,Paid By,Total Amount,Split Type,Participant,Share Amount,Status\n',
    );
    for (final tx in group.transactions) {
      final payer = group.participantById(tx.addedById)?.name ?? 'Unknown';
      final dateStr =
          '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}-${tx.date.day.toString().padLeft(2, '0')}';
      for (final share in tx.shares) {
        final participant = group.participantById(share.participantId)?.name ?? 'Unknown';
        final row = [
          dateStr,
          tx.title,
          payer,
          tx.totalAmount.toStringAsFixed(2),
          tx.splitType.label,
          participant,
          share.amount.toStringAsFixed(2),
          share.status.label,
        ].map(_csvField).join(',');
        buf.writeln(row);
      }
    }
    return buf.toString();
  }

  static Future<void> export(BuildContext context, SplitGroup group) async {
    if (group.transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No expenses to export yet.')),
      );
      return;
    }
    try {
      final csv = _buildCsv(group);
      final dir = await getTemporaryDirectory();
      final fileName = '${group.name}_split_expenses'
          .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
      final file = File('${dir.path}/$fileName.csv');
      await file.writeAsString(csv);
      if (!context.mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: '${group.name} — split expenses',
          text: 'Split expense report for ${group.name}.',
        ),
      );
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'split_group_export');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed. Please try again.')),
        );
      }
    }
  }
}
