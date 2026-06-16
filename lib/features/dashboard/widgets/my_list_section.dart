import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/pantry/pantry_models.dart';
import 'package:wai_life_assistant/data/services/pantry_service.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';
import 'package:wai_life_assistant/features/pantry/widgets/create_list_sheet.dart';

class MyListSection extends StatelessWidget {
  final List<GroceryItem> items;
  final String walletId;
  final bool isDark;
  final Color cardBg;
  final Color sub;
  final VoidCallback onItemsChanged;
  final VoidCallback onGoToPantry;

  const MyListSection({
    super.key,
    required this.items,
    required this.walletId,
    required this.isDark,
    required this.cardBg,
    required this.sub,
    required this.onItemsChanged,
    required this.onGoToPantry,
  });

  List<GroceryItem> get _groceryItems  => items.where((i) => i.isGrocery).toList();
  List<GroceryItem> get _quickItems    => items.where((i) => !i.isGrocery).toList();

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final grocery = _groceryItems;
    final quick   = _quickItems;
    final hasAny  = grocery.isNotEmpty || quick.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ────────────────────────────────────────────────────
        Row(
          children: [
            const Text('🛍️', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 7),
            Text(
              'My List',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
                color: tc,
              ),
            ),
            const Spacer(),
            if (items.isNotEmpty)
              GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => CreateListSheet(items: items),
                ),
                child: Text(
                  '📋 List',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Nunito',
                    color: AppColors.lend,
                  ),
                ),
              ),
            if (items.isNotEmpty) const SizedBox(width: 12),
            GestureDetector(
              onTap: onGoToPantry,
              child: Text(
                'Pantry →',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Nunito',
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ── Card ──────────────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.15),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: isDark ? 0.06 : 0.07),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              if (hasAny) ...[
                // ── Grocery sub-section ───────────────────────────────────────
                if (grocery.isNotEmpty) ...[
                  _SubHeader(
                    label: '🛒 Grocery',
                    count: grocery.length,
                    color: AppColors.primary,
                    isDark: isDark,
                  ),
                  ...grocery.take(3).map(
                    (item) => _GroceryRow(
                      item: item,
                      isDark: isDark,
                      sub: sub,
                      onDone: () => _markGroceryDone(item),
                      onGoToPantry: onGoToPantry,
                    ),
                  ),
                  if (grocery.length > 3)
                    _MoreRow(
                      label: '+${grocery.length - 3} more in Pantry Basket',
                      color: AppColors.primary,
                      isDark: isDark,
                      onTap: onGoToPantry,
                    ),
                ],

                // ── Divider between sub-sections ──────────────────────────────
                if (grocery.isNotEmpty && quick.isNotEmpty)
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.06),
                  ),

                // ── Quick list sub-section ────────────────────────────────────
                if (quick.isNotEmpty) ...[
                  _SubHeader(
                    label: '📋 Quick List',
                    count: quick.length,
                    color: AppColors.lend,
                    isDark: isDark,
                  ),
                  ...quick.map(
                    (item) => _QuickRow(
                      item: item,
                      isDark: isDark,
                      sub: sub,
                      onDone: () => _deleteItem(item),
                      onMoveToGrocery: () => _moveToGrocery(item),
                    ),
                  ),
                ],
              ] else ...[
                // ── Empty state ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        'Nothing on your list yet',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Nunito',
                          color: sub,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Add button ────────────────────────────────────────────────
              Divider(
                height: 1,
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.06),
              ),
              GestureDetector(
                onTap: () => _showAddSheet(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Add to list',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _markGroceryDone(GroceryItem item) async {
    try {
      await PantryService.instance.updateGroceryItem(item.id, {
        'to_buy':       false,
        'in_stock':     true,
        'last_updated': DateTime.now().toIso8601String(),
      });
      PantryService.listChangeSignal.value++;
      onItemsChanged();
    } catch (_) {}
  }

  Future<void> _deleteItem(GroceryItem item) async {
    try {
      await PantryService.instance.deleteGroceryItem(item.id);
      PantryService.listChangeSignal.value++;
      onItemsChanged();
    } catch (_) {}
  }

  Future<void> _moveToGrocery(GroceryItem item) async {
    try {
      await PantryService.instance.updateGroceryItem(item.id, {
        'is_grocery': true,
        'in_stock': false,
      });
      PantryService.listChangeSignal.value++;
      onItemsChanged();
    } catch (_) {}
  }

  void _showAddSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddListItemSheet(
        walletId: walletId,
        isDark: isDark,
        onAdded: () {
          PantryService.listChangeSignal.value++;
          onItemsChanged();
        },
      ),
    );
  }
}

// ── Sub-header row inside card ────────────────────────────────────────────────

class _SubHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isDark;
  const _SubHeader({
    required this.label,
    required this.count,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              fontFamily: 'Nunito',
              color: color,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                fontFamily: 'Nunito',
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Grocery item row ──────────────────────────────────────────────────────────

class _GroceryRow extends StatelessWidget {
  final GroceryItem item;
  final bool isDark;
  final Color sub;
  final VoidCallback onDone;
  final VoidCallback onGoToPantry;
  const _GroceryRow({
    required this.item,
    required this.isDark,
    required this.sub,
    required this.onDone,
    required this.onGoToPantry,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final qtyLabel = item.quantity == item.quantity.truncateToDouble()
        ? '${item.quantity.toInt()} ${item.unit}'
        : '${item.quantity} ${item.unit}';

    return GestureDetector(
      onTap: onGoToPantry,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(right: 9, top: 1),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Text(
                item.name,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                  color: tc,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              qtyLabel,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'Nunito',
                color: sub,
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onDone,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick list item row ───────────────────────────────────────────────────────

class _QuickRow extends StatelessWidget {
  final GroceryItem item;
  final bool isDark;
  final Color sub;
  final VoidCallback onDone;
  final VoidCallback onMoveToGrocery;
  const _QuickRow({
    required this.item,
    required this.isDark,
    required this.sub,
    required this.onDone,
    required this.onMoveToGrocery,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final qtyLabel = item.quantity == item.quantity.truncateToDouble()
        ? '${item.quantity.toInt()} ${item.unit}'
        : '${item.quantity} ${item.unit}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(right: 9, top: 1),
            decoration: BoxDecoration(
              color: AppColors.lend.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              item.name,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w600,
                color: tc,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            qtyLabel,
            style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub),
          ),
          const SizedBox(width: 8),
          // Move to grocery button
          GestureDetector(
            onTap: onMoveToGrocery,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                '🛒',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Done/delete button
          GestureDetector(
            onTap: onDone,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.expense.withValues(alpha: isDark ? 0.15 : 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.check_rounded,
                size: 15,
                color: AppColors.expense,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── "N more" row ──────────────────────────────────────────────────────────────

class _MoreRow extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  const _MoreRow({
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 2, 14, 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            color: color.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

// ── Add item bottom sheet ─────────────────────────────────────────────────────

class _AddListItemSheet extends StatefulWidget {
  final String walletId;
  final bool isDark;
  final VoidCallback onAdded;
  const _AddListItemSheet({
    required this.walletId,
    required this.isDark,
    required this.onAdded,
  });

  @override
  State<_AddListItemSheet> createState() => _AddListItemSheetState();
}

class _AddListItemSheetState extends State<_AddListItemSheet> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl  = TextEditingController(text: '1');
  String _unit    = 'pcs';
  bool _isGrocery = false;
  bool _saving    = false;

  static const _units = ['pcs', 'kg', 'g', 'L', 'ml', 'pack', 'box', 'bottle'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await PantryService.instance.addGroceryItem(
        walletId: widget.walletId,
        name: name,
        category: GroceryCategory.other.name,
        quantity: double.tryParse(_qtyCtrl.text.trim()) ?? 1,
        unit: _unit,
        inStock: false,
        toBuy: true,
        isGrocery: _isGrocery,
      );
      if (mounted) {
        widget.onAdded();
        Navigator.pop(context);
      }
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'my_list_add_item');
      debugPrint('[MyList] save error: $e');
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = widget.isDark;
    final bg      = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc      = isDark ? AppColors.textDark : AppColors.textLight;
    final sub     = isDark ? AppColors.subDark : AppColors.subLight;
    final inset   = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + inset),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: sub.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            'Add to My List',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              fontFamily: 'Nunito',
              color: tc,
            ),
          ),
          const SizedBox(height: 16),

          // Name field
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Nunito',
              color: tc,
            ),
            decoration: InputDecoration(
              hintText: 'Item name',
              hintStyle: TextStyle(color: sub, fontFamily: 'Nunito'),
              filled: true,
              fillColor: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),

          // Qty + unit row
          Row(
            children: [
              SizedBox(
                width: 70,
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Nunito',
                    color: tc,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Qty',
                    hintStyle: TextStyle(color: sub, fontFamily: 'Nunito'),
                    filled: true,
                    fillColor: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _unit,
                  dropdownColor: bg,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Nunito',
                    color: tc,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  items: _units
                      .map(
                        (u) => DropdownMenuItem(
                          value: u,
                          child: Text(u),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _unit = v ?? _unit),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Type toggle
          Row(
            children: [
              Text(
                'Add to:',
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Nunito',
                  color: sub,
                ),
              ),
              const SizedBox(width: 10),
              _TypeChip(
                label: '📋 Quick List',
                selected: !_isGrocery,
                color: AppColors.lend,
                isDark: isDark,
                onTap: () => setState(() => _isGrocery = false),
              ),
              const SizedBox(width: 8),
              _TypeChip(
                label: '🛒 Grocery',
                selected: _isGrocery,
                color: AppColors.primary,
                isDark: isDark,
                onTap: () => setState(() => _isGrocery = true),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Nunito',
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: isDark ? 0.22 : 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.55)
                : color.withValues(alpha: 0.20),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            fontFamily: 'Nunito',
            color: selected
                ? (isDark ? color.withValues(alpha: 0.9) : color)
                : (isDark ? AppColors.subDark : AppColors.subLight),
          ),
        ),
      ),
    );
  }
}
