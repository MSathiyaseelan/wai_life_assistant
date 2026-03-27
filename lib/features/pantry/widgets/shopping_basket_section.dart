import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/core/supabase/wallet_service.dart';
import 'package:wai_life_assistant/data/models/pantry/pantry_models.dart';
import 'package:wai_life_assistant/services/ai_parser.dart';

class ShoppingBasketSection extends StatefulWidget {
  final List<GroceryItem> items;
  final String walletId;
  final void Function(GroceryItem) onItemToggleBuy;
  final void Function(GroceryItem) onItemToggleStock;
  final void Function(GroceryItem) onItemMarkBought;
  final void Function(GroceryItem) onItemAdded;
  final void Function(GroceryItem) onItemDeleted;

  const ShoppingBasketSection({
    super.key,
    required this.items,
    required this.walletId,
    required this.onItemToggleBuy,
    required this.onItemToggleStock,
    required this.onItemMarkBought,
    required this.onItemAdded,
    required this.onItemDeleted,
  });

  @override
  State<ShoppingBasketSection> createState() => _ShoppingBasketSectionState();
}

class _ShoppingBasketSectionState extends State<ShoppingBasketSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  GroceryCategory? _filterCat;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) setState(() => _filterCat = null);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  List<GroceryItem> get _walletItems =>
      widget.items.where((i) => i.walletId == widget.walletId).toList();

  List<GroceryItem> get _inStock => _walletItems
      .where((i) => i.inStock)
      .where((i) => _filterCat == null || i.category == _filterCat)
      .toList();

  List<GroceryItem> get _toBuy => _walletItems
      .where((i) => i.toBuy)
      .where((i) => _filterCat == null || i.category == _filterCat)
      .toList();

  /// Distinct categories present in the ACTIVE tab's items, in GroceryCategory.values order.
  List<GroceryCategory> get _availableCategories {
    final base = _tabCtrl.index == 0
        ? _walletItems.where((i) => i.inStock)
        : _walletItems.where((i) => i.toBuy);
    final present = base.map((i) => i.category).toSet();
    return GroceryCategory.values.where(present.contains).toList();
  }

  @override
  void didUpdateWidget(ShoppingBasketSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_filterCat != null && !_availableCategories.contains(_filterCat)) {
      _filterCat = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tabs + Scan Bill on same row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
          child: Row(
            children: [
              // In Stock / To Buy tabs
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: tabBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: TabBar(
                    controller: _tabCtrl,
                    indicator: BoxDecoration(
                      color: AppColors.income,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: isDark
                        ? AppColors.subDark
                        : AppColors.subLight,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      fontFamily: 'Nunito',
                    ),
                    padding: EdgeInsets.zero,
                    tabs: [
                      Tab(text: '🏠 In Stock (${_inStock.length})', height: 34),
                      Tab(text: '🛒 To Buy (${_toBuy.length})', height: 34),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Scan Bill button
              GestureDetector(
                onTap: () => _showScanSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.income.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.document_scanner_outlined,
                        size: 14,
                        color: AppColors.income,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Scan Bill',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.income,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Category filter chips — only categories present in items
        if (_availableCategories.isNotEmpty) ...[
          const SizedBox(height: 4),
          SizedBox(
            height: 32,
            child: ListView(
              primary: false,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _CatChip(
                  label: 'All',
                  selected: _filterCat == null,
                  onTap: () => setState(() => _filterCat = null),
                ),
                ..._availableCategories.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: _CatChip(
                      label: '${c.emoji} ${c.label}',
                      selected: _filterCat == c,
                      onTap: () => setState(
                        () => _filterCat = _filterCat == c ? null : c,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),

        // Tab content — Expanded fills all remaining space so inner ListView scrolls freely
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // In-stock list
              _GroceryList(
                items: _inStock,
                isDark: isDark,
                emptyMsg: 'No items in stock',
                emptyEmoji: '📦',
                onToggleBuy: widget.onItemToggleBuy,
                onToggleStock: widget.onItemToggleStock,
                onDelete: widget.onItemDeleted,
                trailing: (item) => _StockTrail(
                  item: item,
                  isDark: isDark,
                  onToggleBuy: () => widget.onItemToggleBuy(item),
                ),
              ),
              // To-buy list
              _GroceryList(
                items: _toBuy,
                isDark: isDark,
                emptyMsg: 'Nothing on the list!',
                emptyEmoji: '🎉',
                onToggleBuy: widget.onItemToggleBuy,
                onToggleStock: widget.onItemToggleStock,
                onDelete: widget.onItemDeleted,
                trailing: (item) => _BuyTrail(
                  item: item,
                  isDark: isDark,
                  onMarkBought: () => widget.onItemMarkBought(item),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  void _showScanSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScanBillSheet(
        isDark: isDark,
        walletId: widget.walletId,
        onItemAdded: widget.onItemAdded,
      ),
    );
  }
}

// ── Grocery list ─────────────────────────────────────────────────────────────

class _GroceryList extends StatelessWidget {
  final List<GroceryItem> items;
  final bool isDark;
  final String emptyMsg, emptyEmoji;
  final void Function(GroceryItem) onToggleBuy, onToggleStock, onDelete;
  final Widget Function(GroceryItem) trailing;

  const _GroceryList({
    required this.items,
    required this.isDark,
    required this.emptyMsg,
    required this.emptyEmoji,
    required this.onToggleBuy,
    required this.onToggleStock,
    required this.onDelete,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emptyEmoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 6),
              Text(
                emptyMsg,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Nunito',
                  color: isDark ? AppColors.subDark : AppColors.subLight,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      primary: false,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        final c = item.category.emoji;
        final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;

        // Check expiry warning
        final now = DateTime.now();
        final isExpiringSoon = item.expiryDate != null &&
            DateTime(item.expiryDate!.year, item.expiryDate!.month, item.expiryDate!.day)
                .isBefore(DateTime(now.year, now.month, now.day));

        return Dismissible(
          key: ValueKey(item.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.expense.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.delete_outline, color: AppColors.expense),
          ),
          onDismissed: (_) => onDelete(item),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: isExpiringSoon
                  ? Border.all(
                      color: AppColors.lend.withValues(alpha: 0.6),
                      width: 1.5,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(c, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                          color: isDark
                              ? AppColors.textDark
                              : AppColors.textLight,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${item.quantity} ${item.unit}',
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Nunito',
                              color: isDark
                                  ? AppColors.subDark
                                  : AppColors.subLight,
                            ),
                          ),
                          if (isExpiringSoon) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.lend.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '⚠️ Expiring soon',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.lend,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                trailing(item),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StockTrail extends StatelessWidget {
  final GroceryItem item;
  final bool isDark;
  final VoidCallback onToggleBuy;
  const _StockTrail({
    required this.item,
    required this.isDark,
    required this.onToggleBuy,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onToggleBuy,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: item.toBuy
            ? AppColors.lend.withValues(alpha: 0.12)
            : AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        item.toBuy ? '📋 Listed' : '+ List',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          fontFamily: 'Nunito',
          color: item.toBuy ? AppColors.lend : AppColors.primary,
        ),
      ),
    ),
  );
}

class _BuyTrail extends StatelessWidget {
  final GroceryItem item;
  final bool isDark;
  final VoidCallback onMarkBought;
  const _BuyTrail({
    required this.item,
    required this.isDark,
    required this.onMarkBought,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onMarkBought,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.income.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        '✓ Bought',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          fontFamily: 'Nunito',
          color: AppColors.income,
        ),
      ),
    ),
  );
}

// ── Category filter chip ──────────────────────────────────────────────────────

class _CatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CatChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.income.withValues(alpha: 0.18)
              : (isDark ? AppColors.surfDark : AppColors.bgLight),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.income : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
            color: selected
                ? AppColors.income
                : (isDark ? AppColors.subDark : AppColors.subLight),
          ),
        ),
      ),
    );
  }
}

// ── Scan Bill sheet ───────────────────────────────────────────────────────────

class _ScanBillSheet extends StatefulWidget {
  final bool isDark;
  final String walletId;
  final void Function(GroceryItem) onItemAdded;

  const _ScanBillSheet({
    required this.isDark,
    required this.walletId,
    required this.onItemAdded,
  });

  @override
  State<_ScanBillSheet> createState() => _ScanBillSheetState();
}

class _ScanBillSheetState extends State<_ScanBillSheet> {
  // 'pick' → 'loading' → 'confirm' → (done)
  String _phase = 'pick';
  File? _image;
  List<_ScannedItem> _scannedItems = [];
  String? _error;
  bool _pushToWallet = false;
  bool _limitChecking = false;

  // ── Scan limit check ────────────────────────────────────────────────────────

  static const _freeScansPerMonth = 3;

  Future<bool> _checkScanLimit() async {
    try {
      final result = await Supabase.instance.client.rpc(
        'check_feature_limit',
        params: {
          'p_user_id': Supabase.instance.client.auth.currentUser!.id,
          'p_feature': 'bill_scan',
          'p_limit': _freeScansPerMonth,
        },
      );
      return result as bool? ?? true;
    } catch (_) {
      return true; // fail open on DB error
    }
  }

  // ── Pick image ──────────────────────────────────────────────────────────────

  Future<void> _pick(ImageSource source) async {
    setState(() { _limitChecking = true; _error = null; });
    final allowed = await _checkScanLimit();
    if (!mounted) return;
    if (!allowed) {
      setState(() {
        _limitChecking = false;
        _error = 'Free scan limit reached ($_freeScansPerMonth/month). Upgrade to scan more.';
      });
      return;
    }
    setState(() => _limitChecking = false);

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
      final bytes = await imageFile.readAsBytes();
      final ext = imageFile.path.toLowerCase();
      final mimeType = ext.endsWith('.png') ? 'image/png' : 'image/jpeg';

      final result = await AIParser.parseImage(
        feature: 'pantry',
        subFeature: 'bill_scan',
        imageBytes: bytes,
        mimeType: mimeType,
      );

      if (!mounted) return;

      if (!result.success) {
        setState(() {
          _error = result.error ?? 'Could not read bill. Please try again.';
          _phase = 'pick';
        });
        return;
      }

      final rawItems =
          (result.data?['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      final items = rawItems.map((m) {
        final catStr = (m['category'] as String?)?.toLowerCase() ?? 'other';
        final cat = GroceryCategory.values.firstWhere(
          (c) => c.name == catStr,
          orElse: () => GroceryCategory.other,
        );
        return _ScannedItem(
          name: m['name'] as String? ?? 'Item',
          quantity: (m['quantity'] as num?)?.toDouble() ?? 1,
          unit: m['unit'] as String? ?? 'pcs',
          category: cat,
          price: (m['price'] as num?)?.toDouble(),
          confidence: (m['confidence'] as num?)?.toDouble(),
        );
      }).toList();

      setState(() {
        _scannedItems = items;
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
    if (selected.isEmpty) return;

    // Add items to In Stock
    for (final item in selected) {
      final qty = double.tryParse(item.qtyCtrl.text) ?? item.quantity;
      widget.onItemAdded(
        GroceryItem(
          id: '${DateTime.now().microsecondsSinceEpoch}_${item.name}',
          name: item.nameCtrl.text.trim().isEmpty
              ? item.name
              : item.nameCtrl.text.trim(),
          category: item.category,
          quantity: qty,
          unit: item.unitCtrl.text.trim().isEmpty
              ? item.unit
              : item.unitCtrl.text.trim(),
          walletId: widget.walletId,
          inStock: true,
          toBuy: false,
        ),
      );
    }

    // Optionally push total to Wallet as an expense
    if (_pushToWallet) {
      final total = selected.fold<double>(0.0, (sum, i) {
        final p = double.tryParse(i.priceCtrl.text) ?? i.price ?? 0.0;
        return sum + p;
      });
      if (total > 0) {
        try {
          await WalletService.instance.addTransaction(
            walletId: widget.walletId,
            type: 'expense',
            amount: total,
            category: 'groceries',
            note: 'Bill scan — ${selected.length} item${selected.length == 1 ? '' : 's'}',
          );
        } catch (_) {
          // Non-critical — basket save already succeeded
        }
      }
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final count = selected.length;
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: Text(
        '$count item${count == 1 ? '' : 's'} added to stock ✓',
        style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800),
      ),
      backgroundColor: AppColors.income,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    for (final i in _scannedItems) {
      i.nameCtrl.dispose();
      i.qtyCtrl.dispose();
      i.unitCtrl.dispose();
      i.priceCtrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? AppColors.cardDark : AppColors.cardLight;
    final surf = widget.isDark ? AppColors.surfDark : AppColors.bgLight;
    final tc = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final sub = widget.isDark ? AppColors.subDark : AppColors.subLight;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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

  // ── Phase: pick ─────────────────────────────────────────────────────────────

  Widget _buildPick(Color bg, Color surf, Color tc, Color sub) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          const SizedBox(height: 16),
          const Text('📸', style: TextStyle(fontSize: 48)),
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
            'Pick a screenshot or photo of a bill/receipt.\nClaude AI will extract the items for you.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Nunito',
              color: sub,
            ),
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: CircularProgressIndicator(
                color: AppColors.income, strokeWidth: 2,
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
              child: Image.file(
                _image!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: AppColors.income),
          const SizedBox(height: 16),
          Text(
            'Reading bill with Claude AI…',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              color: sub,
            ),
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
                      child: Image.file(
                        _image!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Items Found',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Nunito',
                            color: tc,
                          ),
                        ),
                        Text(
                          '${_scannedItems.length} items — select to add to basket',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Nunito',
                            color: sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      final allSelected =
                          _scannedItems.every((i) => i.selected);
                      for (final i in _scannedItems) {
                        i.selected = !allSelected;
                      }
                    }),
                    child: Text(
                      _scannedItems.every((i) => i.selected)
                          ? 'Deselect all'
                          : 'Select all',
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
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.45,
          ),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shrinkWrap: true,
            itemCount: _scannedItems.length,
            itemBuilder: (_, i) => _ScannedItemTile(
              item: _scannedItems[i],
              isDark: widget.isDark,
              onToggle: () => setState(() {
                _scannedItems[i].selected = !_scannedItems[i].selected;
              }),
            ),
          ),
        ),
        // ── Also push to Wallet? toggle ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: GestureDetector(
            onTap: () => setState(() => _pushToWallet = !_pushToWallet),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: surf,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _pushToWallet
                      ? AppColors.lend.withValues(alpha: 0.4)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded,
                      size: 18,
                      color: _pushToWallet ? AppColors.lend : sub),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Also push to Wallet?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: _pushToWallet ? AppColors.lend : tc,
                          ),
                        ),
                        if (_pushToWallet) Builder(builder: (_) {
                          final total = _scannedItems
                              .where((i) => i.selected)
                              .fold<double>(0.0, (s, i) =>
                                  s + (double.tryParse(i.priceCtrl.text) ??
                                      i.price ?? 0.0));
                          return Text(
                            total > 0
                                ? '₹${total.toStringAsFixed(2)} logged as grocery expense'
                                : 'Enter prices above to track amount',
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Nunito',
                              color: sub,
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  Switch(
                    value: _pushToWallet,
                    onChanged: (v) => setState(() => _pushToWallet = v),
                    activeThumbColor: AppColors.lend,
                    activeTrackColor: AppColors.lend.withValues(alpha: 0.4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _phase = 'pick'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(color: sub.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'Rescan',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      color: sub,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: selectedCount == 0 ? null : _saveSelected,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.income,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.income.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    selectedCount == 0
                        ? 'Select items'
                        : 'Add $selectedCount item${selectedCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
}

// ── Scanned item data model ───────────────────────────────────────────────────

class _ScannedItem {
  bool selected = true;
  final String name;
  final double quantity;
  final String unit;
  final GroceryCategory category;
  final double? price;
  final double? confidence;
  late final TextEditingController nameCtrl;
  late final TextEditingController qtyCtrl;
  late final TextEditingController unitCtrl;
  late final TextEditingController priceCtrl;

  _ScannedItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    this.price,
    this.confidence,
  }) {
    nameCtrl = TextEditingController(text: name);
    qtyCtrl = TextEditingController(text: _fmtQty(quantity));
    unitCtrl = TextEditingController(text: unit);
    priceCtrl = TextEditingController(
        text: price != null ? price!.toStringAsFixed(2) : '');
  }

  static String _fmtQty(double q) =>
      q == q.truncateToDouble() ? q.toInt().toString() : q.toString();
}

// ── Scanned item tile (in confirm list) ──────────────────────────────────────

class _ScannedItemTile extends StatelessWidget {
  final _ScannedItem item;
  final bool isDark;
  final VoidCallback onToggle;

  const _ScannedItemTile({
    required this.item,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final surf = isDark ? AppColors.surfDark : AppColors.bgLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

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
                ? Border.all(
                    color: AppColors.income.withValues(alpha: 0.5),
                    width: 1.5,
                  )
                : null,
          ),
          child: Row(
            children: [
              // Checkbox
              Icon(
                item.selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color:
                    item.selected ? AppColors.income : sub.withValues(alpha: 0.5),
                size: 22,
              ),
              const SizedBox(width: 10),
              // Category emoji
              Text(
                item.category.emoji,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 8),
              // Editable name
              Expanded(
                child: TextField(
                  controller: item.nameCtrl,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    color: tc,
                  ),
                  decoration: const InputDecoration.collapsed(hintText: 'Name'),
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 8),
              // Quantity
              SizedBox(
                width: 36,
                child: TextField(
                  controller: item.qtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Nunito',
                    color: tc,
                  ),
                  decoration: const InputDecoration.collapsed(hintText: '1'),
                ),
              ),
              // Unit
              SizedBox(
                width: 38,
                child: TextField(
                  controller: item.unitCtrl,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Nunito',
                    color: sub,
                  ),
                  decoration: const InputDecoration.collapsed(hintText: 'pcs'),
                ),
              ),
              const SizedBox(width: 6),
              // Price (₹)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('₹', style: TextStyle(fontSize: 11, color: sub, fontFamily: 'Nunito')),
                  SizedBox(
                    width: 46,
                    child: TextField(
                      controller: item.priceCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                      decoration: const InputDecoration.collapsed(hintText: '0'),
                    ),
                  ),
                ],
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
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.income.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppColors.income),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                fontFamily: 'Nunito',
                color: tc,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
