import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/core/constants/api_endpoints.dart';
import 'package:wai_life_assistant/core/services/app_prefs.dart';
import 'package:wai_life_assistant/core/services/ai_parser.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';
import 'package:wai_life_assistant/data/services/wallet_service.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/shared/utils/ai_limit_snackbar.dart';

// ── Wallet "Scan Bill" sheet ───────────────────────────────────────────────────
// Mirrors the Pantry ScanBillSheet (shopping_basket_section.dart) — pick a
// photo of any spending/earning bill, parse it with Gemini, let the user
// review/edit line items, then insert them as Wallet transactions. Multiple
// confirmed items are grouped together automatically (via tx_groups), same
// as manually using "Add to group" on a set of related transactions.

class WalletBillScanSheet extends StatefulWidget {
  final bool isDark;
  final String walletId;
  final void Function(List<TxModel>) onSaved;

  const WalletBillScanSheet({
    super.key,
    required this.isDark,
    required this.walletId,
    required this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required String walletId,
    required void Function(List<TxModel>) onSaved,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WalletBillScanSheet(
        isDark: isDark,
        walletId: walletId,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<WalletBillScanSheet> createState() => _WalletBillScanSheetState();
}

class _WalletBillScanSheetState extends State<WalletBillScanSheet> {
  // 'pick' → 'loading' → 'confirm' → (done)
  String _phase = 'pick';
  File? _image;
  List<_ScannedBillItem> _scannedItems = [];
  String? _merchant;
  String? _error;
  bool _saving = false;
  bool _limitChecking = true;
  bool _limitReached = false;
  int _monthlyLimit = 30;

  @override
  void initState() {
    super.initState();
    _checkLimitOnOpen();
  }

  @override
  void dispose() {
    for (final i in _scannedItems) {
      i.titleCtrl.dispose();
      i.amountCtrl.dispose();
    }
    super.dispose();
  }

  // ── Scan limit check ────────────────────────────────────────────────────────

  Future<void> _checkLimitOnOpen() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _limitChecking = false);
        return;
      }
      final month =
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
      final results = await Future.wait<dynamic>([
        client
            .from('feature_usage')
            .select('count')
            .eq('user_id', userId)
            .eq('feature', 'ai_parser')
            .eq('month', month)
            .maybeSingle(),
        client.rpc(
          AppRpc.getEffectiveFeatureLimit,
          params: {'p_user_id': userId, 'p_feature': 'ai_parser'},
        ),
      ]);
      final usageRow = results[0] as Map<String, dynamic>?;
      final limit = results[1] as int? ?? 30;
      if (!mounted) return;
      final count = (usageRow?['count'] as int?) ?? 0;
      setState(() {
        _monthlyLimit = limit;
        _limitReached = limit != -1 && count >= limit;
        _limitChecking = false;
      });
    } catch (e) {
      ErrorLogger.warning(e, action: 'wallet_bill_scan_check_limit');
      if (!mounted) return;
      setState(() => _limitChecking = false);
    }
  }

  // ── Pick image ──────────────────────────────────────────────────────────────

  Future<void> _pick(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (!mounted || picked == null) return;
    final file = File(picked.path);
    setState(() {
      _image = file;
      _phase = 'loading';
      _error = null;
    });
    await _analyze(file);
  }

  // ── Call Edge Function via AIParser ─────────────────────────────────────────

  Future<void> _analyze(File imageFile) async {
    try {
      if (_limitReached) {
        setState(() => _phase = 'pick');
        return;
      }

      final bytes = await imageFile.readAsBytes();
      final ext = imageFile.path.toLowerCase();
      final mimeType = ext.endsWith('.png') ? 'image/png' : 'image/jpeg';

      final result = await AIParser.parseImage(
        feature: 'wallet',
        subFeature: 'bill_scan',
        imageBytes: bytes,
        mimeType: mimeType,
      );

      if (!mounted) return;

      if (!result.success) {
        maybeShowAiLimitSnackbar(context, result.error);
        setState(() {
          _error = result.error ?? 'Could not read bill. Please try again.';
          _phase = 'pick';
        });
        return;
      }
      await _checkLimitOnOpen();
      if (!mounted) return;

      if (result.data?['is_financial_bill'] == false) {
        final guess = result.data?['bill_type_guess'] as String?;
        setState(() {
          _error = guess != null && guess != 'unknown'
              ? "This doesn't look like a bill or receipt (looks like a $guess) — nothing was added."
              : "This doesn't look like a bill or receipt — nothing was added.";
          _phase = 'pick';
        });
        return;
      }

      final rawItems =
          (result.data?['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      final items = rawItems.map((m) {
        return _ScannedBillItem(
          title: m['title'] as String? ?? 'Item',
          amount: (m['amount'] as num?)?.toDouble() ?? 0,
          category: m['category'] as String? ?? 'Other',
          isIncome: (m['type'] as String? ?? 'expense') == 'income',
          confidence: (m['confidence'] as num?)?.toDouble(),
        );
      }).where((i) => i.amount > 0).toList();

      if (items.isEmpty) {
        setState(() {
          _error = 'No items found in the bill. Try a clearer photo.';
          _phase = 'pick';
        });
        return;
      }
      setState(() {
        _scannedItems = items;
        _merchant = result.data?['merchant'] as String?;
        _phase = 'confirm';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not read bill: ${e.toString().split('\n').first}';
        _phase = 'pick';
      });
    }
  }

  // ── Save confirmed items ────────────────────────────────────────────────────

  Future<void> _saveSelected() async {
    final selected = _scannedItems.where((i) => i.selected).toList();
    if (selected.isEmpty || _saving) return;

    setState(() => _saving = true);
    try {
      final saved = <TxModel>[];
      for (final item in selected) {
        final amount = double.tryParse(item.amountCtrl.text) ?? item.amount;
        final title = item.titleCtrl.text.trim().isEmpty
            ? item.title
            : item.titleCtrl.text.trim();
        final row = await WalletService.instance.addTransaction(
          walletId: widget.walletId,
          type: item.isIncome ? 'income' : 'expense',
          amount: amount,
          category: item.category,
          title: title,
          note: 'Scanned from bill',
          date: DateTime.now(),
        );
        saved.add(TxModel.fromRow(row));
      }

      // Multiple line items from one bill → group them together, same as
      // manually using "Add to group" across several transactions.
      var finalTxs = saved;
      if (saved.length > 1) {
        final groupRow = await WalletService.instance.createTxGroup(
          walletId: widget.walletId,
          name: (_merchant != null && _merchant!.trim().isNotEmpty)
              ? _merchant!.trim()
              : 'Scanned Bill',
          emoji: '🧾',
        );
        final groupId = groupRow['id'] as String;
        for (final tx in saved) {
          await WalletService.instance.setTxGroup(tx.id, groupId);
        }
        finalTxs = saved
            .map((tx) => TxModel(
                  id: tx.id,
                  type: tx.type,
                  amount: tx.amount,
                  category: tx.category,
                  date: tx.date,
                  walletId: tx.walletId,
                  payMode: tx.payMode,
                  title: tx.title,
                  note: tx.note,
                  person: tx.person,
                  persons: tx.persons,
                  status: tx.status,
                  dueDate: tx.dueDate,
                  userId: tx.userId,
                  groupId: groupId,
                ))
            .toList();
      }

      if (!mounted) return;
      widget.onSaved(finalTxs);
      final messenger = ScaffoldMessenger.of(context);
      final count = finalTxs.length;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            count > 1
                ? '$count transactions added and grouped ✓'
                : '1 transaction added ✓',
            style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800),
          ),
          backgroundColor: AppColors.income,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'wallet_bill_scan_save');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save transactions. Please try again.')),
      );
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? AppColors.cardDark : AppColors.cardLight;
    final surf = widget.isDark ? AppColors.surfDark : AppColors.bgLight;
    final tc = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final sub = widget.isDark ? AppColors.subDark : AppColors.subLight;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: switch (_phase) {
          'loading' => _buildLoading(sub),
          'confirm' => _buildConfirm(bg, surf, tc, sub),
          _ => _buildPick(bg, surf, tc, sub),
        },
      ),
    );
  }

  Widget _handle() => Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      );

  // ── Phase: pick ─────────────────────────────────────────────────────────────

  Widget _buildPick(Color bg, Color surf, Color tc, Color sub) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          const SizedBox(height: 16),
          const Text('🧾', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            'Scan Bill',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              fontFamily: 'Nunito',
              color: tc,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pick a photo of any bill or receipt.\nAI will extract the spending/earning items for you.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: sub),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.expense.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.expense,
                  fontSize: 12,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (_limitChecking)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: AppColors.income, strokeWidth: 2),
                  ),
                  const SizedBox(height: 10),
                  Text('Just a moment…', style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub)),
                ],
              ),
            )
          else if (_limitReached)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.expense.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.expense.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Text('🚫', style: TextStyle(fontSize: 32)),
                  const SizedBox(height: 8),
                  Text(
                    'Free scan limit reached',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: tc),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_monthlyLimit scans/month on free plan.\nUpgrade to scan more.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: sub),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _PickButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    isDark: widget.isDark,
                    onTap: () => _pick(ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    isDark: widget.isDark,
                    onTap: () => _pick(ImageSource.camera),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── Phase: loading ──────────────────────────────────────────────────────────

  Widget _buildLoading(Color sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          const SizedBox(height: 24),
          if (_image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(_image!, height: 160, width: double.infinity, fit: BoxFit.cover),
            ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: AppColors.income),
          const SizedBox(height: 16),
          Text(
            'Reading bill with AI…',
            style: TextStyle(fontSize: 14, fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: sub),
          ),
        ],
      ),
    );
  }

  // ── Phase: confirm ──────────────────────────────────────────────────────────

  Widget _buildConfirm(Color bg, Color surf, Color tc, Color sub) {
    final selectedCount = _scannedItems.where((i) => i.selected).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            children: [
              _handle(),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (_image != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(_image!, width: 48, height: 48, fit: BoxFit.cover),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Items Found',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: tc),
                        ),
                        Text(
                          selectedCount > 1
                              ? '${_scannedItems.length} items — will be grouped together'
                              : '${_scannedItems.length} item${_scannedItems.length == 1 ? '' : 's'} — select to add',
                          style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      final allSelected = _scannedItems.every((i) => i.selected);
                      for (final i in _scannedItems) {
                        i.selected = !allSelected;
                      }
                    }),
                    child: Text(
                      _scannedItems.every((i) => i.selected) ? 'Deselect all' : 'Select all',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'Nunito',
                        color: AppColors.income,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shrinkWrap: true,
            itemCount: _scannedItems.length,
            itemBuilder: (_, i) => _ScannedBillItemTile(
              item: _scannedItems[i],
              isDark: widget.isDark,
              onToggle: () => setState(() {
                _scannedItems[i].selected = !_scannedItems[i].selected;
              }),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => setState(() => _phase = 'pick'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(color: sub.withValues(alpha: 0.4)),
                  ),
                  child: Text('Rescan', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: sub)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: selectedCount == 0 || _saving ? null : _saveSelected,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.income,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.income.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          selectedCount == 0
                              ? 'Select items'
                              : selectedCount > 1
                                  ? 'Add $selectedCount as group'
                                  : 'Add $selectedCount item',
                          style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Scanned item data model ───────────────────────────────────────────────────

class _ScannedBillItem {
  bool selected = true;
  final String title;
  final double amount;
  final String category;
  final bool isIncome;
  final double? confidence;
  late final TextEditingController titleCtrl;
  late final TextEditingController amountCtrl;

  _ScannedBillItem({
    required this.title,
    required this.amount,
    required this.category,
    required this.isIncome,
    this.confidence,
  }) {
    titleCtrl = TextEditingController(text: title);
    amountCtrl = TextEditingController(text: amount.toStringAsFixed(2));
  }
}

// ── Scanned item tile (in confirm list) ──────────────────────────────────────

class _ScannedBillItemTile extends StatelessWidget {
  final _ScannedBillItem item;
  final bool isDark;
  final VoidCallback onToggle;

  const _ScannedBillItemTile({
    required this.item,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final surf = isDark ? AppColors.surfDark : AppColors.bgLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final amountColor = item.isIncome ? AppColors.income : AppColors.expense;

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedOpacity(
        opacity: item.selected ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 180),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: surf,
            borderRadius: BorderRadius.circular(14),
            border: item.selected
                ? Border.all(color: AppColors.income.withValues(alpha: 0.5), width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              Icon(
                item.selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: item.selected ? AppColors.income : sub.withValues(alpha: 0.5),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: item.titleCtrl,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: tc),
                      decoration: const InputDecoration.collapsed(hintText: 'Title'),
                      onTap: () {},
                    ),
                    Text(
                      item.category,
                      style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: TextField(
                  controller: item.amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: amountColor),
                  decoration: InputDecoration.collapsed(hintText: '${AppPrefs.cs}0'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pick source button ────────────────────────────────────────────────────────

class _PickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _PickButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surf = isDark ? AppColors.surfDark : AppColors.bgLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.income.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.income, size: 26),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: tc)),
          ],
        ),
      ),
    );
  }
}
