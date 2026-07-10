import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';
import 'package:wai_life_assistant/data/models/pantry/pantry_models.dart';
import 'package:wai_life_assistant/data/services/pantry_service.dart';
import 'package:wai_life_assistant/core/utils/ingredient_normalizer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GROCERY LIST HISTORY — past "Create List" snapshots, with the ability to
// bulk mark items bought (moves them to In Stock / off To Buy, same as the
// single-item mark-bought action used elsewhere in Pantry).
// ─────────────────────────────────────────────────────────────────────────────

class GroceryListHistorySheet extends StatefulWidget {
  final String walletId;
  final bool isDark;
  final VoidCallback? onItemsChanged;

  const GroceryListHistorySheet({
    super.key,
    required this.walletId,
    required this.isDark,
    this.onItemsChanged,
  });

  @override
  State<GroceryListHistorySheet> createState() => _GroceryListHistorySheetState();
}

class _GroceryListHistorySheetState extends State<GroceryListHistorySheet> {
  bool _loading = true;
  List<GroceryListModel> _lists = [];
  Map<String, List<GroceryItem>> _itemsByList = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final lists = await PantryService.instance.fetchGroceryLists(widget.walletId);
      final items = await PantryService.instance
          .fetchItemsForLists(lists.map((l) => l['id'] as String).toList());
      final grouped = <String, List<GroceryItem>>{};
      for (final row in items) {
        final item = GroceryItem.fromMap(row);
        final listId = row['list_id'] as String?;
        if (listId == null) continue;
        (grouped[listId] ??= []).add(item);
      }
      if (!mounted) return;
      setState(() {
        _lists = lists.map(GroceryListModel.fromMap).toList();
        _itemsByList = grouped;
        _loading = false;
      });
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'grocery_list_history_load');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteList(GroceryListModel list) async {
    final removed = _lists;
    setState(() => _lists = _lists.where((l) => l.id != list.id).toList());
    try {
      await PantryService.instance.deleteGroceryList(list.id);
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'grocery_list_delete');
      if (!mounted) return;
      setState(() => _lists = removed);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete list.')),
      );
    }
  }

  void _openList(GroceryListModel list) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ListDetailSheet(
        list: list,
        items: _itemsByList[list.id] ?? [],
        isDark: widget.isDark,
        onChanged: () {
          widget.onItemsChanged?.call();
          _load();
        },
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = widget.isDark ? AppColors.surfDark : AppColors.bgLight;
    final tc = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final sub = widget.isDark ? AppColors.subDark : AppColors.subLight;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  const Text('📜', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'List History',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _lists.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('📋', style: TextStyle(fontSize: 40)),
                              const SizedBox(height: 8),
                              Text(
                                'No saved lists yet',
                                style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: sub),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: ctrl,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: _lists.length,
                          itemBuilder: (_, i) {
                            final list = _lists[i];
                            final items = _itemsByList[list.id] ?? [];
                            final bought = items.where((it) => it.inStock).length;
                            return Dismissible(
                              key: ValueKey(list.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.expense.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
                              ),
                              onDismissed: (_) => _deleteList(list),
                              child: GestureDetector(
                                onTap: () => _openList(list),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: surfBg,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              list.name,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                fontFamily: 'Nunito',
                                                color: tc,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '${_fmtDate(list.createdAt)}  ·  $bought of ${items.length} bought',
                                              style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.chevron_right_rounded, size: 18, color: sub),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIST DETAIL — select some/all pending items and mark them bought in bulk.
// ─────────────────────────────────────────────────────────────────────────────

class _ListDetailSheet extends StatefulWidget {
  final GroceryListModel list;
  final List<GroceryItem> items;
  final bool isDark;
  final VoidCallback onChanged;

  const _ListDetailSheet({
    required this.list,
    required this.items,
    required this.isDark,
    required this.onChanged,
  });

  @override
  State<_ListDetailSheet> createState() => _ListDetailSheetState();
}

class _ListDetailSheetState extends State<_ListDetailSheet> {
  late Set<String> _selected;
  bool _saving = false;

  List<GroceryItem> get _pending => widget.items.where((i) => !i.inStock).toList();
  List<GroceryItem> get _bought => widget.items.where((i) => i.inStock).toList();

  @override
  void initState() {
    super.initState();
    _selected = {};
  }

  Future<void> _markSelectedBought() async {
    final toMark = widget.items.where((i) => _selected.contains(i.id)).toList();
    if (toMark.isEmpty) return;
    setState(() => _saving = true);
    try {
      await PantryService.instance.markItemsBought(toMark);
      PantryService.listChangeSignal.value++;
      widget.onChanged();
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'grocery_list_mark_bought');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update items. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = widget.isDark ? AppColors.surfDark : AppColors.bgLight;
    final tc = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final sub = widget.isDark ? AppColors.subDark : AppColors.subLight;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.list.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                      color: tc,
                    ),
                  ),
                ),
                if (_pending.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() {
                      final allOn = _selected.length == _pending.length;
                      _selected = allOn ? {} : _pending.map((i) => i.id).toSet();
                    }),
                    child: Text(
                      _selected.length == _pending.length ? 'Deselect all' : 'Select all',
                      style: const TextStyle(
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
            Expanded(
              child: ListView(
                controller: ctrl,
                children: [
                  if (_pending.isNotEmpty) ...[
                    Text('TO BUY', style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8,
                      fontFamily: 'Nunito', color: sub,
                    )),
                    const SizedBox(height: 6),
                    ..._pending.map((item) => _ItemRow(
                          item: item,
                          selected: _selected.contains(item.id),
                          surfBg: surfBg,
                          tc: tc,
                          sub: sub,
                          onTap: () => setState(() {
                            if (!_selected.remove(item.id)) _selected.add(item.id);
                          }),
                        )),
                  ],
                  if (_bought.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('ALREADY BOUGHT', style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8,
                      fontFamily: 'Nunito', color: sub,
                    )),
                    const SizedBox(height: 6),
                    ..._bought.map((item) => _ItemRow(
                          item: item,
                          selected: true,
                          done: true,
                          surfBg: surfBg,
                          tc: tc,
                          sub: sub,
                          onTap: null,
                        )),
                  ],
                ],
              ),
            ),
            if (_pending.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selected.isEmpty || _saving ? null : _markSelectedBought,
                  icon: _saving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(
                    _selected.isEmpty
                        ? 'Select items to mark bought'
                        : 'Mark ${_selected.length} as Bought',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, fontFamily: 'Nunito'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.income,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.income.withValues(alpha: 0.3),
                    elevation: 3,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final GroceryItem item;
  final bool selected;
  final bool done;
  final Color surfBg, tc, sub;
  final VoidCallback? onTap;

  const _ItemRow({
    required this.item,
    required this.selected,
    this.done = false,
    required this.surfBg,
    required this.tc,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final qty = item.quantity == item.quantity.truncateToDouble()
        ? item.quantity.toInt().toString()
        : item.quantity.toString();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected && !done ? AppColors.lend.withValues(alpha: 0.08) : surfBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected && !done ? AppColors.lend.withValues(alpha: 0.4) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Text(item.category.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                displayCase(item.name),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Nunito',
                  color: done ? sub : tc,
                  decoration: done ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            Text('$qty ${item.unit}', style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub)),
            const SizedBox(width: 10),
            if (done)
              const Icon(Icons.check_circle_rounded, size: 20, color: AppColors.income)
            else
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.lend : Colors.transparent,
                  border: Border.all(color: selected ? AppColors.lend : sub, width: 2),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
