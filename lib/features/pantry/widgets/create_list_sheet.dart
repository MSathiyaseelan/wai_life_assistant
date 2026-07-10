import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';
import 'package:wai_life_assistant/data/models/pantry/pantry_models.dart';
import 'package:wai_life_assistant/data/services/pantry_service.dart';
import 'package:wai_life_assistant/core/utils/ingredient_normalizer.dart';

class CreateListSheet extends StatefulWidget {
  final List<GroceryItem> items;
  final String walletId;
  final VoidCallback? onSaved;
  const CreateListSheet({
    super.key,
    required this.items,
    required this.walletId,
    this.onSaved,
  });

  @override
  State<CreateListSheet> createState() => _CreateListSheetState();
}

class _CreateListSheetState extends State<CreateListSheet> {
  late final List<bool> _checked;

  @override
  void initState() {
    super.initState();
    _checked = List.filled(widget.items.length, true);
  }

  int get _selectedCount => _checked.where((v) => v).length;

  List<GroceryItem> get _selectedItems => [
    for (var i = 0; i < widget.items.length; i++)
      if (_checked[i]) widget.items[i],
  ];

  String _fmtQty(GroceryItem g) {
    final q = g.quantity == g.quantity.truncateToDouble()
        ? g.quantity.toInt().toString()
        : g.quantity.toString();
    return '$q ${g.unit}';
  }

  String _dateStr() {
    final now = DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  String _buildListText() {
    final selected = _selectedItems;
    if (selected.isEmpty) return '';
    final buf = StringBuffer();
    buf.writeln('🛒 Shopping List  ·  ${_dateStr()}');
    buf.writeln('─' * 30);
    for (var i = 0; i < selected.length; i++) {
      final g = selected[i];
      buf.writeln('${i + 1}. ${g.category.emoji} ${displayCase(g.name)} — ${_fmtQty(g)}');
    }
    buf.writeln('─' * 30);
    buf.write('📦 ${selected.length} item${selected.length == 1 ? '' : 's'}');
    return buf.toString();
  }

  // Auto-saved to list history the first time the user actually does
  // something with the list (Share/Excel/PDF) — no separate "Save" step.
  // Idempotent per sheet session: repeated exports reuse the same list
  // instead of creating a new history entry each time.
  bool _saving = false;
  String? _savedListId;

  Future<void> _ensureSaved() async {
    if (_savedListId != null || _saving) return;
    final selected = _selectedItems;
    if (selected.isEmpty) return;
    _saving = true;
    try {
      final list = await PantryService.instance.createGroceryList(
        walletId: widget.walletId,
        name: '🛒 Shopping List – ${_dateStr()}',
        itemIds: selected.map((i) => i.id).toList(),
      );
      _savedListId = list['id'] as String;
      widget.onSaved?.call();
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'create_grocery_list');
      // Silent: saving to history is a side effect, not the user's primary
      // intent — the export/share itself should still succeed regardless.
    } finally {
      _saving = false;
    }
  }

  Future<void> _exportCsv() async {
    final selected = _selectedItems;
    if (selected.isEmpty) return;
    unawaited(_ensureSaved());
    final buf = StringBuffer();
    buf.writeln('#,Item,Category,Quantity,Unit');
    for (var i = 0; i < selected.length; i++) {
      final g = selected[i];
      final q = g.quantity == g.quantity.truncateToDouble()
          ? g.quantity.toInt().toString()
          : g.quantity.toString();
      buf.writeln('${i + 1},"${displayCase(g.name)}","${g.category.label}","$q","${g.unit}"');
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/shopping_list.csv');
    await file.writeAsString(buf.toString());
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv', name: 'shopping_list.csv')],
      subject: 'Shopping List',
    );
  }

  Future<void> _exportPdf() async {
    final selected = _selectedItems;
    if (selected.isEmpty) return;
    unawaited(_ensureSaved());

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Shopping List',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              _dateStr(),
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 18),
            pw.TableHelper.fromTextArray(
              headers: ['#', 'Item', 'Category', 'Qty'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo100),
              cellHeight: 28,
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerRight,
              },
              data: [
                for (var i = 0; i < selected.length; i++)
                  [
                    '${i + 1}',
                    displayCase(selected[i].name),
                    selected[i].category.label,
                    _fmtQty(selected[i]),
                  ],
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              '${selected.length} item${selected.length == 1 ? '' : 's'} total',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/shopping_list.pdf');
    await file.writeAsBytes(await doc.save());
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf', name: 'shopping_list.pdf')],
      subject: 'Shopping List',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark  : AppColors.bgLight;
    final tc     = isDark ? AppColors.textDark  : AppColors.textLight;
    final sub    = isDark ? AppColors.subDark   : AppColors.subLight;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Row(
            children: [
              const Text('📋', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Create Shopping List',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Nunito',
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  final allOn = _selectedCount == widget.items.length;
                  setState(() {
                    for (var i = 0; i < _checked.length; i++) {
                      _checked[i] = !allOn;
                    }
                  });
                },
                child: Text(
                  _selectedCount == widget.items.length
                      ? 'Deselect all'
                      : 'Select all',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Nunito',
                    color: AppColors.lend,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.items.length,
              itemBuilder: (_, i) {
                final item = widget.items[i];
                final sel  = _checked[i];
                final qty  = item.quantity == item.quantity.truncateToDouble()
                    ? item.quantity.toInt().toString()
                    : item.quantity.toString();
                return GestureDetector(
                  onTap: () => setState(() => _checked[i] = !_checked[i]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.lend.withValues(alpha: 0.08)
                          : surfBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: sel
                            ? AppColors.lend.withValues(alpha: 0.4)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(item.category.emoji,
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayCase(item.name),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Nunito',
                                  color: sel ? tc : sub,
                                ),
                              ),
                              Text(
                                '$qty ${item.unit}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'Nunito',
                                  color: sub,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: sel ? AppColors.lend : Colors.transparent,
                            border: Border.all(
                              color: sel ? AppColors.lend : sub,
                              width: 2,
                            ),
                          ),
                          child: sel
                              ? const Icon(Icons.check_rounded,
                                  size: 14, color: Colors.white)
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectedCount == 0 ? null : _exportCsv,
                  icon: const Icon(Icons.table_chart_rounded, size: 16),
                  label: const Text(
                    'Excel',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      fontFamily: 'Nunito',
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1D6F42),
                    side: BorderSide(
                      color: _selectedCount == 0
                          ? Colors.grey.withValues(alpha: 0.3)
                          : const Color(0xFF1D6F42),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectedCount == 0 ? null : _exportPdf,
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                  label: const Text(
                    'PDF',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      fontFamily: 'Nunito',
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFCC2222),
                    side: BorderSide(
                      color: _selectedCount == 0
                          ? Colors.grey.withValues(alpha: 0.3)
                          : const Color(0xFFCC2222),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedCount == 0
                  ? null
                  : () {
                      unawaited(_ensureSaved());
                      Share.share(_buildListText(), subject: 'Shopping List');
                    },
              icon: const Icon(Icons.share_rounded, size: 18),
              label: Text(
                _selectedCount == 0
                    ? 'Select items to share'
                    : 'Share $_selectedCount item${_selectedCount == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  fontFamily: 'Nunito',
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lend,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.lend.withValues(alpha: 0.3),
                elevation: 3,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
