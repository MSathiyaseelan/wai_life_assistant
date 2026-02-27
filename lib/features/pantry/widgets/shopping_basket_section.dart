import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/pantry/pantry_models.dart';

class ShoppingBasketSection extends StatefulWidget {
  final List<GroceryItem> items;
  final String walletId;
  final void Function(GroceryItem) onItemToggleBuy;
  final void Function(GroceryItem) onItemToggleStock;
  final void Function(GroceryItem) onItemAdded;
  final void Function(GroceryItem) onItemDeleted;

  const ShoppingBasketSection({
    super.key,
    required this.items,
    required this.walletId,
    required this.onItemToggleBuy,
    required this.onItemToggleStock,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            children: [
              const Text('🧺', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text(
                'Shopping Basket',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const Spacer(),
              // Scan bill button
              GestureDetector(
                onTap: () => _showScanSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.income.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
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

        // Tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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

        // Category filter row
        const SizedBox(height: 10),
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _CatChip(
                label: 'All',
                selected: _filterCat == null,
                onTap: () => setState(() => _filterCat = null),
              ),
              const SizedBox(width: 6),
              ...GroceryCategory.values.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _CatChip(
                    label: '${c.emoji} ${c.label}',
                    selected: _filterCat == c,
                    onTap: () =>
                        setState(() => _filterCat = _filterCat == c ? null : c),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Tab content
        SizedBox(
          height: 280,
          child: TabBarView(
            controller: _tabCtrl,
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
                  onMarkBought: () {
                    widget.onItemToggleStock(item);
                    widget.onItemToggleBuy(item);
                  },
                ),
              ),
            ],
          ),
        ),

        // Chat-style add bar
        _GroceryChatBar(
          isDark: isDark,
          walletId: widget.walletId,
          onAdded: widget.onItemAdded,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  void _showScanSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScanBillSheet(isDark: isDark),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emptyEmoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 8),
            Text(
              emptyMsg,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'Nunito',
                color: isDark ? AppColors.subDark : AppColors.subLight,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        final c = item.category.emoji;
        final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;

        // Check expiry warning
        final isExpiringSoon =
            item.expiryDate != null &&
            item.expiryDate!.difference(DateTime.now()).inDays <= 2;

        return Dismissible(
          key: ValueKey(item.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.expense.withOpacity(0.15),
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
                      color: AppColors.lend.withOpacity(0.6),
                      width: 1.5,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.15 : 0.05),
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
                                color: AppColors.lend.withOpacity(0.15),
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
            ? AppColors.lend.withOpacity(0.12)
            : AppColors.primary.withOpacity(0.08),
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
        color: AppColors.income.withOpacity(0.12),
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

// ── Chat-style grocery add bar ────────────────────────────────────────────────

class _GroceryChatBar extends StatefulWidget {
  final bool isDark;
  final String walletId;
  final void Function(GroceryItem) onAdded;
  const _GroceryChatBar({
    required this.isDark,
    required this.walletId,
    required this.onAdded,
  });
  @override
  State<_GroceryChatBar> createState() => _GroceryChatBarState();
}

class _GroceryChatBarState extends State<_GroceryChatBar> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() => _hasText = _ctrl.text.isNotEmpty));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    // Simple parse: "2 kg rice" → qty=2, unit=kg, name=rice
    final parts = text.split(' ');
    double qty = 1;
    String unit = 'pcs';
    String name = text;

    if (parts.length >= 3) {
      qty = double.tryParse(parts[0]) ?? 1;
      unit = parts[1];
      name = parts.sublist(2).join(' ');
    } else if (parts.length == 2) {
      final maybeQty = double.tryParse(parts[0]);
      if (maybeQty != null) {
        qty = maybeQty;
        name = parts[1];
      }
    }

    widget.onAdded(
      GroceryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _capitalize(name),
        category: GroceryCategory.other,
        quantity: qty,
        unit: unit,
        walletId: widget.walletId,
        inStock: false,
        toBuy: true,
      ),
    );
    _ctrl.clear();
    _focus.unfocus();
    HapticFeedback.lightImpact();
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? AppColors.cardDark : AppColors.cardLight;
    final inputBg = widget.isDark ? AppColors.surfDark : AppColors.bgLight;
    final hint = widget.isDark ? AppColors.subDark : AppColors.subLight;
    final text = widget.isDark ? AppColors.textDark : AppColors.textLight;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _hasText
                      ? AppColors.income.withOpacity(0.4)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                maxLines: null,
                minLines: 1,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(
                  fontSize: 13,
                  color: text,
                  fontFamily: 'Nunito',
                ),
                decoration: InputDecoration.collapsed(
                  hintText: 'Add item... e.g. "2 kg tomatoes"',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: hint,
                    fontFamily: 'Nunito',
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          GestureDetector(
            onTap: _hasText ? _submit : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _hasText ? AppColors.income : inputBg,
                shape: BoxShape.circle,
                boxShadow: _hasText
                    ? [
                        BoxShadow(
                          color: AppColors.income.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Icon(
                _hasText ? Icons.add_rounded : Icons.add_rounded,
                color: _hasText
                    ? Colors.white
                    : (widget.isDark ? AppColors.subDark : AppColors.subLight),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.income.withOpacity(0.18)
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

// ── Scan Bill sheet placeholder ───────────────────────────────────────────────

class _ScanBillSheet extends StatelessWidget {
  final bool isDark;
  const _ScanBillSheet({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text('📸', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 14),
          const Text(
            'Scan Bill',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Camera scanner coming soon',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Nunito',
              color: isDark ? AppColors.subDark : AppColors.subLight,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.income.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Coming Soon',
              style: TextStyle(
                color: AppColors.income,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                fontFamily: 'Nunito',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
