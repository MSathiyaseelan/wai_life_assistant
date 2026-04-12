import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/features/wallet/widgets/tx_tile.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TX GROUP CARD
// Collapsible master card that shows all expenses in a named group.
// ─────────────────────────────────────────────────────────────────────────────

class TxGroupCard extends StatefulWidget {
  final TxGroup group;
  final bool isDark;

  /// Tap on a member tile → detail sheet
  final void Function(TxModel tx) onTxTap;

  /// Long press on a member tile → duplicate
  final void Function(TxModel tx) onTxLongPress;

  /// "Add Expense" button pressed
  final VoidCallback onAddExpense;

  /// Edit group name/emoji
  final void Function(String name, String emoji) onRename;

  /// Delete the whole group (txs become ungrouped)
  final VoidCallback onDeleteGroup;

  /// Called when a member tile drag starts (for parent to track _draggingTx)
  final void Function(TxModel tx)? onTxDragStarted;

  /// Called when a member tile drag ends
  final VoidCallback? onTxDragEnded;

  const TxGroupCard({
    super.key,
    required this.group,
    required this.isDark,
    required this.onTxTap,
    required this.onTxLongPress,
    required this.onAddExpense,
    required this.onRename,
    required this.onDeleteGroup,
    this.onTxDragStarted,
    this.onTxDragEnded,
  });

  @override
  State<TxGroupCard> createState() => _TxGroupCardState();
}

class _TxGroupCardState extends State<TxGroupCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _anim;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _expandAnim = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _anim.forward();
    } else {
      _anim.reverse();
    }
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) {
      final s = (v / 1000).toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
      return '${s}k';
    }
    return v.toStringAsFixed(0);
  }

  String _fmtDate(DateTime d) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month]}';
  }

  String get _dateRange {
    final g = widget.group;
    if (g.transactions.isEmpty) return '';
    if (g.transactions.length == 1) return _fmtDate(g.latestDate);
    final earliest = _fmtDate(g.earliestDate);
    final latest = _fmtDate(g.latestDate);
    return earliest == latest ? earliest : '$earliest – $latest';
  }

  void _showGroupMenu() {
    final isDark = widget.isDark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                Text(widget.group.emoji,
                    style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.group.name,
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Nunito',
                              color: tc)),
                      Text(
                        '${widget.group.transactions.length} expense${widget.group.transactions.length == 1 ? '' : 's'}  •  ₹${_fmt(widget.group.total)}',
                        style: TextStyle(
                            fontSize: 12, fontFamily: 'Nunito', color: sub),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _MenuTile(
              icon: Icons.edit_outlined,
              label: 'Rename group',
              color: AppColors.primary,
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog();
              },
            ),
            _MenuTile(
              icon: Icons.add_circle_outline_rounded,
              label: 'Add expense to group',
              color: AppColors.income,
              onTap: () {
                Navigator.pop(context);
                widget.onAddExpense();
              },
            ),
            _MenuTile(
              icon: Icons.delete_outline_rounded,
              label: 'Delete group',
              sublabel: 'Expenses remain, just ungrouped',
              color: AppColors.expense,
              onTap: () {
                Navigator.pop(context);
                widget.onDeleteGroup();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog() {
    final nameCtrl =
        TextEditingController(text: widget.group.name);
    final emojiCtrl =
        TextEditingController(text: widget.group.emoji);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Group',
            style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emojiCtrl,
              decoration: const InputDecoration(
                labelText: 'Emoji',
                hintText: '📦',
              ),
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Group name'),
              style: const TextStyle(fontFamily: 'Nunito'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final emoji = emojiCtrl.text.trim();
              if (name.isNotEmpty) {
                widget.onRename(name, emoji.isEmpty ? '📦' : emoji);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final g = widget.group;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.expense.withValues(alpha: 0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────────────
          GestureDetector(
            onTap: _toggle,
            onLongPress: _showGroupMenu,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  // Emoji badge
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.expense.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(g.emoji,
                        style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  // Name + meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: tc,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${g.transactions.length} expense${g.transactions.length == 1 ? '' : 's'}  •  $_dateRange',
                          style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Nunito',
                              color: sub),
                        ),
                      ],
                    ),
                  ),
                  // Total
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${_fmt(g.total)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito',
                          color: AppColors.expense,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 260),
                        child:
                            Icon(Icons.expand_more_rounded, size: 18, color: sub),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded body ────────────────────────────────────────────
          SizeTransition(
            sizeFactor: _expandAnim,
            axisAlignment: -1,
            child: Column(
              children: [
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.05),
                ),
                // Member tiles — each is draggable so user can remove from group
                ...g.transactions.map((tx) => LongPressDraggable<TxModel>(
                      data: tx,
                      delay: const Duration(milliseconds: 300),
                      onDragStarted: () => widget.onTxDragStarted?.call(tx),
                      onDragEnd: (_) => widget.onTxDragEnded?.call(),
                      feedback: _TxDragFeedback(tx: tx),
                      childWhenDragging: Opacity(
                        opacity: 0.35,
                        child: TxTile(tx: tx),
                      ),
                      child: TxTile(
                        tx: tx,
                        onTap: () => widget.onTxTap(tx),
                        onLongPress: () => widget.onTxLongPress(tx),
                      ),
                    )),
                // Add expense button
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onAddExpense();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 11, horizontal: 16),
                      decoration: BoxDecoration(
                        color: surfBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline_rounded,
                              size: 16,
                              color: AppColors.expense.withValues(alpha: 0.8)),
                          const SizedBox(width: 7),
                          Text(
                            'Add expense to group',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Nunito',
                              color: AppColors.expense.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Drag feedback card shown while dragging a transaction ────────────────────
class _TxDragFeedback extends StatelessWidget {
  final TxModel tx;
  const _TxDragFeedback({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tx.type.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              tx.title?.isNotEmpty == true ? tx.title! : tx.category,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontFamily: 'Nunito',
                color: isDark ? AppColors.textDark : AppColors.textLight,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '₹${tx.amount.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                fontFamily: 'DM Mono',
                color: AppColors.expense,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final Color color;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        label,
        style: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            fontSize: 14),
      ),
      subtitle: sublabel != null
          ? Text(sublabel!,
              style: const TextStyle(fontSize: 11, fontFamily: 'Nunito'))
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }
}
