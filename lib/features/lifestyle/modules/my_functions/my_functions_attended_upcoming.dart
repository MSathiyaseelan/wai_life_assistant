part of 'my_functions_screen.dart';

// ── Attended card ─────────────────────────────────────────────────────────────

class _AttendedCard extends StatelessWidget {
  final AttendedFunction item;
  final bool isDark;
  final VoidCallback onTap;
  const _AttendedCard({
    required this.item,
    required this.isDark,
    required this.onTap,
  });

  String _countdown() {
    if (item.date == null) return '';
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final d = DateTime(item.date!.year, item.date!.month, item.date!.day);
    final diff = d.difference(today).inDays;
    if (diff == 0) return '🎉 Today!';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff > 1) {
      if (diff >= 365) {
        final y = (diff / 365).floor();
        return 'In $y yr${y > 1 ? 's' : ''}';
      }
      return 'In $diff days';
    }
    final abs = diff.abs();
    if (abs >= 365) {
      final y = (abs / 365).floor();
      return '$y yr${y > 1 ? 's' : ''} ago';
    }
    return '$abs days ago';
  }

  Color _countdownColor(bool isDark) {
    if (item.date == null) return Colors.transparent;
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final d = DateTime(item.date!.year, item.date!.month, item.date!.day);
    final diff = d.difference(today).inDays;
    if (diff == 0) return AppColors.income;
    if (diff == 1 || (diff < 0 && diff >= -1)) return AppColors.expense;
    if (diff > 0 && diff <= 7) return AppColors.expense;
    if (diff > 7 && diff <= 30) return AppColors.lend;
    if (diff < 0) return isDark ? AppColors.subDark : AppColors.subLight;
    return isDark ? AppColors.subDark : AppColors.subLight;
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return GestureDetector(
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left color strip
            Container(
              width: 5,
              decoration: const BoxDecoration(
                color: _funcColor,
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(20),
                ),
              ),
            ),
            // Card body
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.18 : 0.05,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Emoji badge
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _funcColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        item.type.emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Middle info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.functionName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: tc,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 3,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _funcColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.type.label,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                    color: _funcColor,
                                  ),
                                ),
                              ),
                              if (item.date != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 11,
                                      color: sub,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${item.date!.day}/${item.date!.month}/${item.date!.year}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'Nunito',
                                        color: sub,
                                      ),
                                    ),
                                  ],
                                ),
                              if (item.venue != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.location_on_rounded,
                                      size: 11,
                                      color: sub,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      item.venue!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'Nunito',
                                        color: sub,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Right: countdown + gifts
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (item.date != null)
                          Text(
                            _countdown(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: _countdownColor(isDark),
                            ),
                          ),
                        if (item.gifts.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.giftsTotal > 0
                                ? '🎁 ₹${item.giftsTotal.toStringAsFixed(0)} · ${item.gifts.map((g) => g.category).join(', ')}'
                                : '🎁 ${item.gifts.map((g) => g.category).join(', ')}',
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'Nunito',
                              color: _funcColor,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Repay when they host next',
                            style: TextStyle(
                              fontSize: 9,
                              fontFamily: 'Nunito',
                              color: sub,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Upcoming card ─────────────────────────────────────────────────────────────
class _UpcomingCard extends StatelessWidget {
  final UpcomingFunction item;
  final bool isDark;
  final VoidCallback onTap;
  const _UpcomingCard({
    required this.item,
    required this.isDark,
    required this.onTap,
  });

  String _countdown() {
    if (item.date == null) return '';
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final d = DateTime(item.date!.year, item.date!.month, item.date!.day);
    final diff = d.difference(today).inDays;
    if (diff == 0) return '🎉 Today!';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff > 1) {
      if (diff >= 365) {
        final y = (diff / 365).floor();
        return 'In $y yr${y > 1 ? 's' : ''}';
      }
      return 'In $diff days';
    }
    final abs = diff.abs();
    if (abs >= 365) {
      final y = (abs / 365).floor();
      return '$y yr${y > 1 ? 's' : ''} ago';
    }
    return '$abs days ago';
  }

  Color _countdownColor(bool isDark) {
    if (item.date == null) return Colors.transparent;
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final d = DateTime(item.date!.year, item.date!.month, item.date!.day);
    final diff = d.difference(today).inDays;
    if (diff == 0) return AppColors.income;
    if (diff == 1 || (diff < 0 && diff >= -1)) return AppColors.expense;
    if (diff > 0 && diff <= 7) return AppColors.expense;
    if (diff > 7 && diff <= 30) return AppColors.lend;
    if (diff < 0) return isDark ? AppColors.subDark : AppColors.subLight;
    return isDark ? AppColors.subDark : AppColors.subLight;
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final title = item.functionTitle;

    return GestureDetector(
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left color strip
            Container(
              width: 5,
              decoration: const BoxDecoration(
                color: _funcColor,
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(20),
                ),
              ),
            ),
            // Card body
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.18 : 0.05,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Emoji badge
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _funcColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        item.type.emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Middle info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: tc,
                            ),
                          ),
                          if (item.personName.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              item.personName,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Nunito',
                                color: sub,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 3,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _funcColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.type.label,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                    color: _funcColor,
                                  ),
                                ),
                              ),
                              if (item.date != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 11,
                                      color: sub,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      fmtDateShort(item.date!),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontFamily: 'Nunito',
                                        color: sub,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          if (item.venue != null) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 11,
                                  color: sub,
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    item.venue!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'Nunito',
                                      color: sub,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Right: countdown + planned gift
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (item.date != null)
                          Text(
                            _countdown(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: _countdownColor(isDark),
                            ),
                          ),
                        if (item.plannedGifts.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '🎁 ${item.plannedGifts.map((g) => g.category).join(', ')}',
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'Nunito',
                              color: sub,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Upcoming detail ───────────────────────────────────────────────────────────

const _upcomingGiftCategories = [
  ('💵', 'Cash'),
  ('🥇', 'Gold'),
  ('🥈', 'Silver'),
  ('🎁', 'Gift Item'),
  ('✨', 'Others'),
];

class _UpcomingDetail extends StatefulWidget {
  final UpcomingFunction item;
  final bool isDark;
  final List<PlanMember> members;
  final VoidCallback onUpdate;
  const _UpcomingDetail({
    required this.item,
    required this.isDark,
    required this.members,
    required this.onUpdate,
  });
  @override
  State<_UpcomingDetail> createState() => _UpcomingDetailState();
}

class _UpcomingDetailState extends State<_UpcomingDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  // Info tab edit state
  late TextEditingController _titleCtrl;
  late TextEditingController _personCtrl;
  late TextEditingController _familyNameCtrl;
  late TextEditingController _venueCtrl;
  late TextEditingController _notesCtrl;
  late FunctionType _type;
  DateTime? _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    final item = widget.item;
    _titleCtrl = TextEditingController(text: item.functionTitle);
    _personCtrl = TextEditingController(text: item.personName);
    _familyNameCtrl = TextEditingController(text: item.familyName ?? '');
    _venueCtrl = TextEditingController(text: item.venue ?? '');
    _notesCtrl = TextEditingController(text: item.notes ?? '');
    _type = item.type;
    _date = item.date;
  }

  @override
  void dispose() {
    _tab.dispose();
    _titleCtrl.dispose();
    _personCtrl.dispose();
    _familyNameCtrl.dispose();
    _venueCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveInfo() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final item = widget.item;
    item
      ..functionTitle = _titleCtrl.text.trim()
      ..personName = _personCtrl.text.trim()
      ..familyName = _familyNameCtrl.text.trim().isEmpty ? null : _familyNameCtrl.text.trim()
      ..type = _type
      ..date = _date
      ..venue = _venueCtrl.text.trim().isEmpty ? null : _venueCtrl.text.trim()
      ..notes = _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();
    try {
      await FunctionsService.instance.updateUpcoming(item.id, item.toJson());
      widget.onUpdate();
      if (mounted) Navigator.pop(context);
      return;
    } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'my_functions_save_error');
      debugPrint('[UpcomingDetail] save error: $e');
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final item = widget.item;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          item.personName.isNotEmpty
              ? '${item.personName}\'s ${item.functionTitle}'
              : item.functionTitle,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            fontFamily: 'Nunito',
          ),
        ),
        bottom: TabBar(
          controller: _tab,
          dividerColor: Colors.transparent,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
            fontSize: 12,
          ),
          indicatorColor: _funcColor,
          labelColor: _funcColor,
          unselectedLabelColor: sub,
          tabs: const [
            Tab(text: 'Info'),
            Tab(text: 'Planning'),
            Tab(text: 'Voting'),
            Tab(text: 'Discuss'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // ── INFO ──────────────────────────────────────────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetLabel(text: 'FUNCTION TYPE'),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: FunctionType.values.map((t) => GestureDetector(
                      onTap: () => setState(() => _type = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: _type == t ? _funcColor.withValues(alpha: 0.15) : surfBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _type == t ? _funcColor : Colors.transparent),
                        ),
                        child: Row(
                          children: [
                            Text(t.emoji, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 5),
                            Text(t.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: _type == t ? _funcColor : sub)),
                          ],
                        ),
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                PlanInputField(controller: _personCtrl, hint: 'Person name (e.g. Priya)'),
                const SizedBox(height: 8),
                PlanInputField(controller: _familyNameCtrl, hint: 'Family name (e.g. Sharma family)'),
                const SizedBox(height: 8),
                PlanInputField(controller: _titleCtrl, hint: 'Function title *'),
                const SizedBox(height: 8),
                PlanInputField(controller: _venueCtrl, hint: 'Venue / Location'),
                const SizedBox(height: 8),
                LifeDateTile(
                  date: _date,
                  hint: 'Function date',
                  color: _funcColor,
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setState(() => _date = d);
                  },
                ),
                const SizedBox(height: 8),
                PlanInputField(controller: _notesCtrl, hint: 'Notes (optional)', maxLines: 3),
                const SizedBox(height: 16),
                SaveButton(
                  label: _saving ? 'Saving…' : 'Save Changes',
                  color: _funcColor,
                  onTap: () { if (!_saving) _saveInfo(); },
                ),
              ],
            ),
          ),

          // ── PLANNING ──────────────────────────────────────────────────────
          _UpcomingPlanningTab(
            item: item,
            isDark: isDark,
            surfBg: surfBg,
            onUpdate: () {
              setState(() {});
              widget.onUpdate();
            },
          ),

          // ── VOTING ────────────────────────────────────────────────────────
          _UpcomingVotingTab(
            item: item,
            isDark: isDark,
            members: widget.members,
            onUpdate: () {
              setState(() {});
              widget.onUpdate();
            },
          ),

          // ── DISCUSS ───────────────────────────────────────────────────────
          ChatWidget(
            messages: item.chat,
            isDark: isDark,
            textOf: (m) => (m as FunctionChatMessage).text,
            senderOf: (m) => (m as FunctionChatMessage).senderId,
            onSend: (text) async {
              setState(
                () => item.chat.add(
                  FunctionChatMessage(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    senderId: 'me',
                    text: text,
                    at: DateTime.now(),
                  ),
                ),
              );
              try {
                await FunctionsService.instance.updateUpcoming(item.id, item.toJson());
              } catch (e, stack) {
                ErrorLogger.log(e, stackTrace: stack, action: 'upcoming_chat_send');
              }
            },
          ),
        ],
      ),
    );
  }
}

// ── Planning tab ──────────────────────────────────────────────────────────────
class _UpcomingPlanningTab extends StatefulWidget {
  final UpcomingFunction item;
  final bool isDark;
  final Color surfBg;
  final VoidCallback onUpdate;
  const _UpcomingPlanningTab({
    required this.item,
    required this.isDark,
    required this.surfBg,
    required this.onUpdate,
  });
  @override
  State<_UpcomingPlanningTab> createState() => _UpcomingPlanningTabState();
}

class _UpcomingPlanningTabState extends State<_UpcomingPlanningTab> {
  String? _selected;
  final TextEditingController _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    if (_selected == null) return;
    final added = PlannedGiftItem(
      category: _selected!,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
    setState(() {
      widget.item.plannedGifts.add(added);
      _selected = null;
      _notesCtrl.clear();
    });
    widget.onUpdate();
    try {
      await FunctionsService.instance.updateUpcoming(
        widget.item.id,
        widget.item.toJson(),
      );
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'upcoming_add_planned_gift');
      if (!mounted) return;
      setState(() => widget.item.plannedGifts.remove(added));
      widget.onUpdate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save gift plan')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final gifts = widget.item.plannedGifts;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Added items list ──────────────────────────────────────────────
          if (gifts.isNotEmpty) ...[
            Text(
              'Planned Gifts',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
                color: sub,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),
            ...gifts.asMap().entries.map((entry) {
              final i = entry.key;
              final g = entry.value;
              final cat = _upcomingGiftCategories.firstWhere(
                (c) => c.$2 == g.category,
                orElse: () => ('🎁', g.category),
              );
              return SwipeTile(
                onDelete: () {
                  setState(() => gifts.removeAt(i));
                  widget.onUpdate();
                  FunctionsService.instance.updateUpcoming(
                    widget.item.id,
                    widget.item.toJson(),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Text(cat.$1, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              g.category,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                                color: tc,
                              ),
                            ),
                            if (g.notes != null)
                              Text(
                                g.notes!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Nunito',
                                  color: sub,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
            Divider(color: sub.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
          ],

          // ── Add new item ──────────────────────────────────────────────────
          Text(
            gifts.isEmpty ? 'What gifts are you planning?' : 'Add Another',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              fontFamily: 'Nunito',
              color: tc,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select a category — you can add multiple.',
            style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _upcomingGiftCategories.map((c) {
              final sel = _selected == c.$2;
              return GestureDetector(
                onTap: () => setState(() => _selected = sel ? null : c.$2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: sel
                        ? _funcColor.withValues(alpha: 0.12)
                        : widget.surfBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: sel ? _funcColor : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(c.$1, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        c.$2,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                          color: sel ? _funcColor : sub,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: widget.surfBg,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: TextField(
              controller: _notesCtrl,
              maxLines: 2,
              minLines: 1,
              style: TextStyle(fontSize: 14, color: tc, fontFamily: 'Nunito'),
              decoration: InputDecoration.collapsed(
                hintText: 'Amount or notes… (e.g. ${AppPrefs.cs}5000)',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: sub,
                  fontFamily: 'Nunito',
                ),
              ),
            ),
          ),
          SaveButton(
            label: '+ Add to Plan',
            color: _selected != null ? _funcColor : sub,
            onTap: _addItem,
          ),
        ],
      ),
    );
  }
}

// ── Voting tab ────────────────────────────────────────────────────────────────
class _UpcomingVotingTab extends StatefulWidget {
  final UpcomingFunction item;
  final bool isDark;
  final List<PlanMember> members;
  final VoidCallback onUpdate;
  const _UpcomingVotingTab({
    required this.item,
    required this.isDark,
    required this.members,
    required this.onUpdate,
  });
  @override
  State<_UpcomingVotingTab> createState() => _UpcomingVotingTabState();
}

class _UpcomingVotingTabState extends State<_UpcomingVotingTab> {
  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final votes = widget.item.votes;

    // Vote count per category
    final tally = <String, int>{};
    for (final cat in _upcomingGiftCategories) {
      tally[cat.$2] = 0;
    }
    for (final v in votes.values) {
      tally[v] = (tally[v] ?? 0) + 1;
    }
    final totalVotes = votes.length;
    final sortedTally = tally.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        // Tally summary
        if (totalVotes > 0) ...[
          Text(
            'Results  ($totalVotes vote${totalVotes != 1 ? 's' : ''})',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              fontFamily: 'Nunito',
              color: sub,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          ...sortedTally.map((e) {
            final cat = _upcomingGiftCategories.firstWhere(
              (c) => c.$2 == e.key,
              orElse: () => ('🎁', e.key),
            );
            final pct = totalVotes > 0 ? e.value / totalVotes : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(cat.$1, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        cat.$2,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                          color: tc,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${e.value} vote${e.value != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: _funcColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct.toDouble(),
                      minHeight: 6,
                      backgroundColor: _funcColor.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation(_funcColor),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
          Divider(color: sub.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
        ],
        // Member voting rows
        if (widget.members.isEmpty) ...[
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                const Text('🗳️', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 10),
                Text(
                  'No family group members',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    color: tc,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add members to your family group\nto enable voting.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Nunito',
                    color: sub,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Text(
            'Cast Your Vote',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              fontFamily: 'Nunito',
              color: sub,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          ...widget.members.map((member) {
            final myVote = votes[member.id];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(member.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        member.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                          color: tc,
                        ),
                      ),
                      if (myVote != null) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _funcColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            myVote,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: _funcColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _upcomingGiftCategories.map((cat) {
                      final sel = myVote == cat.$2;
                      return GestureDetector(
                        onTap: () async {
                          setState(() {
                            if (sel) {
                              widget.item.votes.remove(member.id);
                            } else {
                              widget.item.votes[member.id] = cat.$2;
                            }
                            widget.onUpdate();
                          });
                          try {
                            await FunctionsService.instance.updateUpcoming(
                              widget.item.id,
                              widget.item.toJson(),
                            );
                          } catch (e, stack) {
                            ErrorLogger.log(e, stackTrace: stack, action: 'upcoming_vote');
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: sel
                                ? _funcColor.withValues(alpha: 0.12)
                                : surfBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: sel ? _funcColor : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                cat.$1,
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                cat.$2,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Nunito',
                                  color: sel ? _funcColor : sub,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
        ], // end else members.isNotEmpty
      ],
    );
  }
}

