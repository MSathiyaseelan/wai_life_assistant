part of 'my_functions_screen.dart';

// ── Gift entry editor — shared by the Edit/Convert-to-Attended sheets ────────
// Lets the user list what was given at a function (category + amount + notes)
// so the total is available later for repay-tracking (see AttendedFunction.giftsTotal).

class _GiftEntryEditor extends StatefulWidget {
  final List<PlannedGiftItem> gifts;
  final Color funcColor;
  final VoidCallback onChanged;

  const _GiftEntryEditor({
    required this.gifts,
    required this.funcColor,
    required this.onChanged,
  });

  @override
  State<_GiftEntryEditor> createState() => _GiftEntryEditorState();
}

class _GiftEntryEditorState extends State<_GiftEntryEditor> {
  String? _newCategory;
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.gifts.isNotEmpty) ...[
          Text(
            'Given',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              fontFamily: 'Nunito',
              color: sub,
            ),
          ),
          const SizedBox(height: 8),
          ...widget.gifts.asMap().entries.map((e) {
            final cat = _upcomingGiftCategories.firstWhere(
              (c) => c.$2 == e.value.category,
              orElse: () => ('🎁', e.value.category),
            );
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(cat.$1, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              e.value.category,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                                color: tc,
                              ),
                            ),
                            if (e.value.amount != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                '· ₹${e.value.amount!.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Nunito',
                                  color: widget.funcColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (e.value.notes != null)
                          Text(
                            e.value.notes!,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Nunito',
                              color: sub,
                            ),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() => widget.gifts.removeAt(e.key));
                      widget.onChanged();
                    },
                    child: Icon(Icons.close_rounded, size: 16, color: sub),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
        Text(
          'Add Gift Given',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            fontFamily: 'Nunito',
            color: sub,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _upcomingGiftCategories.map((c) {
            final sel = _newCategory == c.$2;
            return GestureDetector(
              onTap: () => setState(() => _newCategory = sel ? null : c.$2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? widget.funcColor.withValues(alpha: 0.12) : surfBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel ? widget.funcColor : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.$1, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      c.$2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Nunito',
                        color: sel ? widget.funcColor : sub,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        PlanInputField(
          controller: _amountCtrl,
          hint: 'Amount given (₹) — optional',
          inputType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 8),
        PlanInputField(controller: _notesCtrl, hint: 'Notes (optional)'),
        GestureDetector(
          onTap: () {
            if (_newCategory == null) return;
            setState(() {
              widget.gifts.add(
                PlannedGiftItem(
                  category: _newCategory!,
                  notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
                  amount: double.tryParse(_amountCtrl.text.trim()),
                ),
              );
              _newCategory = null;
              _amountCtrl.clear();
              _notesCtrl.clear();
            });
            widget.onChanged();
          },
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _newCategory != null ? widget.funcColor.withValues(alpha: 0.1) : surfBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _newCategory != null ? widget.funcColor : Colors.transparent,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '+ Add',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontFamily: 'Nunito',
                color: _newCategory != null ? widget.funcColor : sub,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Attended function group picker — same pattern as Wallet's "Add to Group" ─
class _AttendedGroupPickerSheet extends StatefulWidget {
  final bool isDark;
  final Color bg, sub, tc;
  final List<AttendedFunctionGroup> groups;
  final void Function(AttendedFunctionGroup) onPick;

  const _AttendedGroupPickerSheet({
    required this.isDark,
    required this.bg,
    required this.sub,
    required this.tc,
    required this.groups,
    required this.onPick,
  });

  @override
  State<_AttendedGroupPickerSheet> createState() => _AttendedGroupPickerSheetState();
}

class _AttendedGroupPickerSheetState extends State<_AttendedGroupPickerSheet> {
  final _nameCtrl = TextEditingController();
  final _emojiCtrl = TextEditingController(text: '👨‍👩‍👧');
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
                        color: _funcColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(g.emoji, style: const TextStyle(fontSize: 20)),
                    ),
                    title: Text(
                      g.name,
                      style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: widget.tc),
                    ),
                    trailing: Icon(Icons.chevron_right_rounded, color: widget.sub),
                  )),
              const Divider(height: 20),
            ],
            if (!_creating)
              GestureDetector(
                onTap: () => setState(() => _creating = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: _funcColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _funcColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.create_new_folder_outlined, size: 18, color: _funcColor),
                      const SizedBox(width: 10),
                      Text(
                        'Create new group',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: _funcColor,
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
                        hintText: '👨‍👩‍👧',
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
                      style: TextStyle(fontFamily: 'Nunito', color: widget.tc),
                      decoration: const InputDecoration(
                        hintText: 'e.g. Sharma Family',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    widget.onPick(AttendedFunctionGroup(
                      id: '', // assigned after DB insert
                      walletId: '',
                      name: name,
                      emoji: emoji.isEmpty ? '👨‍👩‍👧' : emoji,
                    ));
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _funcColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Create & Add',
                    style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: Colors.white),
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

// ── Attended function group card — collapsible master card, mirrors TxGroupCard ─
class _AttendedGroupCard extends StatefulWidget {
  final AttendedFunctionGroup group;
  final bool isDark;
  final void Function(AttendedFunction) onFunctionTap;
  final void Function(String name, String emoji) onRename;
  final VoidCallback onDeleteGroup;

  const _AttendedGroupCard({
    required this.group,
    required this.isDark,
    required this.onFunctionTap,
    required this.onRename,
    required this.onDeleteGroup,
  });

  @override
  State<_AttendedGroupCard> createState() => _AttendedGroupCardState();
}

class _AttendedGroupCardState extends State<_AttendedGroupCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _anim;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
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
                Text(widget.group.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.group.name,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito',
                          color: tc,
                        ),
                      ),
                      Text(
                        '${widget.group.functions.length} function${widget.group.functions.length == 1 ? '' : 's'}  •  ₹${widget.group.total.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListTile(
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog();
              },
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _funcColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_outlined, color: _funcColor, size: 18),
              ),
              title: const Text(
                'Rename group',
                style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 14),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            ),
            ListTile(
              onTap: () {
                Navigator.pop(context);
                widget.onDeleteGroup();
              },
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.expense.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: AppColors.expense, size: 18),
              ),
              title: const Text(
                'Delete group',
                style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 14),
              ),
              subtitle: const Text(
                'Functions remain, just ungrouped',
                style: TextStyle(fontSize: 11, fontFamily: 'Nunito'),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog() {
    final nameCtrl = TextEditingController(text: widget.group.name);
    final emojiCtrl = TextEditingController(text: widget.group.emoji);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Group', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emojiCtrl,
              decoration: const InputDecoration(labelText: 'Emoji', hintText: '👨‍👩‍👧'),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final emoji = emojiCtrl.text.trim();
              if (name.isNotEmpty) widget.onRename(name, emoji.isEmpty ? '👨‍👩‍👧' : emoji);
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
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final g = widget.group;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _funcColor.withValues(alpha: 0.15), width: 1.2),
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
          GestureDetector(
            onTap: _toggle,
            onLongPress: _showGroupMenu,
            child: Container(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _funcColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(g.emoji, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
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
                          '${g.functions.length} function${g.functions.length == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${g.total.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito',
                          color: _funcColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 260),
                        child: Icon(Icons.expand_more_rounded, size: 18, color: sub),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _expandAnim,
            axisAlignment: -1,
            child: Column(
              children: [
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    children: g.functions
                        .map((fn) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _AttendedCard(
                                item: fn,
                                isDark: isDark,
                                onTap: () => widget.onFunctionTap(fn),
                              ),
                            ))
                        .toList(),
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

