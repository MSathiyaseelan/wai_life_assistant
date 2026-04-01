import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/core/supabase/wallet_service.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/features/wallet/widgets/tx_tile.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TX DETAIL SHEET
// ─────────────────────────────────────────────────────────────────────────────

class TxDetailSheet extends StatelessWidget {
  final TxModel tx;
  final bool isDark;
  final List<WalletModel> otherWallets;
  final void Function(TxModel) onEdit;
  final VoidCallback onDelete;
  final void Function(WalletModel) onMove;

  /// Existing groups for this wallet — used to show Group picker.
  final List<TxGroup> groups;

  /// Called when user picks a group or creates a new one.
  /// Passes the chosen/created [TxGroup].
  final void Function(TxGroup group)? onAddToGroup;

  /// Called when user removes this tx from its current group.
  final VoidCallback? onRemoveFromGroup;

  const TxDetailSheet({
    super.key,
    required this.tx,
    required this.isDark,
    required this.otherWallets,
    required this.onEdit,
    required this.onDelete,
    required this.onMove,
    this.groups = const [],
    this.onAddToGroup,
    this.onRemoveFromGroup,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
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
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          TxTile(tx: tx),
          const SizedBox(height: 20),

          // ── Move to wallet ──────────────────────────────────────────────
          if (otherWallets.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'MOVE TO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Nunito',
                  color: sub,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: otherWallets.map((w) {
                  final color = w.isPersonal ? AppColors.primary : AppColors.income;
                  final emoji = w.emoji.startsWith('http') || w.emoji.isEmpty
                      ? (w.isPersonal ? '👤' : '👨‍👩‍👧')
                      : w.emoji;
                  return GestureDetector(
                    onTap: () => onMove(w),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: color.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            w.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Nunito',
                              color: tc,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded,
                              size: 12, color: color),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Edit / Delete ───────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) =>
                          TxEditSheet(tx: tx, isDark: isDark, onSave: onEdit),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text(
                    'Edit',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    onDelete();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text(
                    'Delete',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.expense,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Group action ────────────────────────────────────────────────
          if (onAddToGroup != null || onRemoveFromGroup != null) ...[
            const SizedBox(height: 10),
            if (tx.groupId != null && onRemoveFromGroup != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onRemoveFromGroup!();
                  },
                  icon: const Icon(Icons.folder_off_outlined, size: 18),
                  label: const Text(
                    'Remove from Group',
                    style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              )
            else if (tx.groupId == null && onAddToGroup != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showGroupPicker(context, sub, tc);
                  },
                  icon: const Icon(Icons.folder_special_outlined, size: 18),
                  label: const Text(
                    'Add to Group',
                    style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _showGroupPicker(BuildContext context, Color sub, Color tc) {
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _GroupPickerSheet(
        isDark: isDark,
        bg: bg,
        sub: sub,
        tc: tc,
        groups: groups,
        onPick: (g) => onAddToGroup!(g),
      ),
    );
  }
}

class _GroupPickerSheet extends StatefulWidget {
  final bool isDark;
  final Color bg, sub, tc;
  final List<TxGroup> groups;
  final void Function(TxGroup) onPick;

  const _GroupPickerSheet({
    required this.isDark,
    required this.bg,
    required this.sub,
    required this.tc,
    required this.groups,
    required this.onPick,
  });

  @override
  State<_GroupPickerSheet> createState() => _GroupPickerSheetState();
}

class _GroupPickerSheetState extends State<_GroupPickerSheet> {
  final _nameCtrl = TextEditingController();
  final _emojiCtrl = TextEditingController(text: '📦');
  bool _creating = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emojiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        decoration: BoxDecoration(
          color: widget.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Add to Group',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
                color: widget.tc,
              ),
            ),
            const SizedBox(height: 14),
            // Existing groups
            if (widget.groups.isNotEmpty) ...[
              ...widget.groups.map((g) => ListTile(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onPick(g);
                    },
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.expense.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(g.emoji,
                          style: const TextStyle(fontSize: 20)),
                    ),
                    title: Text(g.name,
                        style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                            color: widget.tc)),
                    subtitle: Text(
                      '${g.transactions.length} expense${g.transactions.length == 1 ? '' : 's'}',
                      style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Nunito',
                          color: widget.sub),
                    ),
                    trailing: Icon(Icons.chevron_right_rounded,
                        color: widget.sub),
                  )),
              const Divider(height: 20),
            ],
            // Create new group
            if (!_creating)
              GestureDetector(
                onTap: () => setState(() => _creating = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.create_new_folder_outlined,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        'Create new group',
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
              )
            else ...[
              Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: TextField(
                      controller: _emojiCtrl,
                      style: const TextStyle(fontSize: 22),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        hintText: '📦',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _nameCtrl,
                      autofocus: true,
                      style: TextStyle(
                          fontFamily: 'Nunito', color: widget.tc),
                      decoration: const InputDecoration(
                        hintText: 'Group name…',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final name = _nameCtrl.text.trim();
                    final emoji = _emojiCtrl.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(context);
                    widget.onPick(TxGroup(
                      id: '', // will be assigned after DB insert
                      walletId: '',
                      name: name,
                      emoji: emoji.isEmpty ? '📦' : emoji,
                      transactions: const [],
                    ));
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Create & Add',
                    style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
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

// ─────────────────────────────────────────────────────────────────────────────
// TX EDIT SHEET
// ─────────────────────────────────────────────────────────────────────────────

class TxEditSheet extends StatefulWidget {
  final TxModel tx;
  final bool isDark;
  final void Function(TxModel) onSave;

  const TxEditSheet({
    super.key,
    required this.tx,
    required this.isDark,
    required this.onSave,
  });

  @override
  State<TxEditSheet> createState() => _TxEditSheetState();
}

class _TxEditSheetState extends State<TxEditSheet> {
  late TextEditingController _amtCtrl;
  late TextEditingController _catCtrl;
  late TextEditingController _titleCtrl;
  late TextEditingController _noteCtrl;
  late TextEditingController _personCtrl;
  late TxType _type;
  late PayMode? _payMode;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final tx = widget.tx;
    _amtCtrl = TextEditingController(text: tx.amount.toStringAsFixed(0));
    _catCtrl = TextEditingController(text: tx.category);
    _titleCtrl = TextEditingController(text: tx.title ?? '');
    _noteCtrl = TextEditingController(text: tx.note ?? '');
    _personCtrl = TextEditingController(text: tx.person ?? '');
    _type = tx.type;
    _payMode = tx.payMode;
    _date = tx.date;
    _catCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    _catCtrl.dispose();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _personCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final amount = double.tryParse(_amtCtrl.text.replaceAll(',', ''));
    final cat = _catCtrl.text.trim();
    if (amount == null || amount <= 0 || cat.isEmpty) return;
    HapticFeedback.mediumImpact();

    widget.onSave(
      TxModel(
        id: widget.tx.id,
        type: _type,
        amount: amount,
        category: cat,
        date: _date,
        walletId: widget.tx.walletId,
        payMode: _payMode,
        title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        person: _personCtrl.text.trim().isEmpty
            ? null
            : _personCtrl.text.trim(),
        persons: widget.tx.persons,
        status: widget.tx.status,
        dueDate: widget.tx.dueDate,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    final showPerson =
        _type == TxType.lend ||
        _type == TxType.borrow ||
        _type == TxType.request;
    final showPayMode =
        _type == TxType.income ||
        _type == TxType.expense ||
        _type == TxType.lend ||
        _type == TxType.borrow;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle + header
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(_type.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Text(
                    'Edit Transaction',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                      color: tc,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Type chips
              _ELbl('TYPE', sub),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: TxType.values.map((t) {
                    final sel = t == _type;
                    return GestureDetector(
                      onTap: () => setState(() => _type = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: sel ? t.color.withValues(alpha: 0.12) : surfBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel ? t.color : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(t.emoji, style: const TextStyle(fontSize: 15)),
                            const SizedBox(width: 5),
                            Text(
                              t.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                                color: sel ? t.color : sub,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // Amount
              _ELbl('AMOUNT', sub),
              TextField(
                controller: _amtCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'DM Mono',
                  color: _type.color,
                ),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(
                    fontSize: 18,
                    color: _type.color.withValues(alpha: 0.6),
                    fontFamily: 'DM Mono',
                  ),
                  filled: true,
                  fillColor: surfBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Category
              _ELbl('CATEGORY', sub),
              _EField(_catCtrl, 'e.g. Food, Travel…', surfBg, tc),
              const SizedBox(height: 8),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: WalletService.instance
                      .categoriesFor(WalletService.txCategoryType(_type.name))
                      .map((c) => GestureDetector(
                            onTap: () => setState(() => _catCtrl.text = c),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 100),
                              margin: const EdgeInsets.only(right: 7),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 11, vertical: 6),
                              decoration: BoxDecoration(
                                color: _catCtrl.text == c
                                    ? _type.color.withValues(alpha: 0.12)
                                    : surfBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _catCtrl.text == c
                                      ? _type.color
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                c,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Nunito',
                                  color: _catCtrl.text == c ? _type.color : sub,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 14),

              // Person (lend/borrow/request)
              if (showPerson) ...[
                _ELbl('PERSON', sub),
                _EField(_personCtrl, 'Name of person', surfBg, tc),
                const SizedBox(height: 14),
              ],

              // Pay mode chips
              if (showPayMode) ...[
                _ELbl('PAY MODE', sub),
                Row(
                  children: PayMode.values.map((m) {
                    final sel = _payMode == m;
                    final lbl = m == PayMode.cash ? '💵 Cash' : '📱 Online';
                    final col = m == PayMode.cash
                        ? const Color(0xFF43A047)
                        : const Color(0xFF1E88E5);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _payMode = m),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: sel ? col.withValues(alpha: 0.1) : surfBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: sel ? col : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            lbl,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Nunito',
                              color: sel ? col : sub,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
              ],

              // Date
              _ELbl('DATE', sub),
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) setState(() => _date = d);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: surfBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 16, color: sub),
                      const SizedBox(width: 10),
                      Text(
                        '${_date.day} ${['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][_date.month]} ${_date.year}',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          color: tc,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title
              _ELbl('TITLE (OPTIONAL)', sub),
              _EField(_titleCtrl, 'e.g. Monthly groceries, Dinner with team…', surfBg, tc),
              const SizedBox(height: 14),

              // Note
              _ELbl('NOTE (OPTIONAL)', sub),
              _EField(_noteCtrl, 'Add a note…', surfBg, tc, maxLines: 2),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: _type.color,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ELbl(String t, Color c) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        fontFamily: 'Nunito',
        color: c,
      ),
    ),
  );

  Widget _EField(
    TextEditingController c,
    String hint,
    Color s,
    Color tc, {
    int maxLines = 1,
  }) => TextField(
    controller: c,
    maxLines: maxLines,
    style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: tc),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: 12,
        color: AppColors.subLight,
      ),
      filled: true,
      fillColor: s,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}
