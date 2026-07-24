part of 'my_functions_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MOI TAB
// ─────────────────────────────────────────────────────────────────────────────

const _moiColor = Color(0xFFFF9800);

class _MoiTab extends StatefulWidget {
  final FunctionModel fn;
  final bool isDark;
  final VoidCallback onUpdate;
  const _MoiTab({
    required this.fn,
    required this.isDark,
    required this.onUpdate,
  });
  @override
  State<_MoiTab> createState() => _MoiTabState();
}

class _MoiTabState extends State<_MoiTab> with SingleTickerProviderStateMixin {
  late TabController _filter;
  final _searchCtrl = TextEditingController();
  String _search = '';
  bool _loading = false;
  bool _savingDrafts = false;

  // ── Draft persistence helpers ─────────────────────────────────────────────
  static String _draftKey(String fnId) => 'moi_draft_$fnId';

  Future<List<MoiEntry>> _loadDraftEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey(widget.fn.id));
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => MoiEntry.fromDraftJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _persistDrafts(List<MoiEntry> drafts) async {
    final prefs = await SharedPreferences.getInstance();
    if (drafts.isEmpty) {
      await prefs.remove(_draftKey(widget.fn.id));
    } else {
      await prefs.setString(
        _draftKey(widget.fn.id),
        jsonEncode(drafts.map((e) => e.toDraftJson()).toList()),
      );
    }
  }

  Future<void> _removeDraftEntry(String entryId) async {
    final drafts = await _loadDraftEntries();
    drafts.removeWhere((e) => e.id == entryId);
    await _persistDrafts(drafts);
  }

  Future<void> _saveAllDrafts() async {
    final drafts = widget.fn.moi.where((e) => e.isDraft).toList();
    if (drafts.isEmpty) return;
    setState(() => _savingDrafts = true);
    try {
      final dataList = drafts.map((e) => {
        'function_id': widget.fn.id,
        'wallet_id': widget.fn.walletId,
        'person_name': e.personName,
        'family_name': e.familyName,
        'place': e.place,
        'phone': e.phone,
        'relation': e.relation,
        'amount': e.amount,
        'kind': e.kind.name,
        'returned': false,
        'notes': e.notes,
      }).toList();
      await FunctionsService.instance.addMoiEntries(dataList);
      await _persistDrafts([]);
      await _loadMoi();
    } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'my_functions_savealldrafts_error');
      debugPrint('[MoiTab] saveAllDrafts error: $e');
    } finally {
      if (mounted) setState(() => _savingDrafts = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _filter = TabController(length: 3, vsync: this);
    _filter.addListener(() => setState(() {}));
    _loadMoi();
  }

  @override
  void dispose() {
    _filter.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMoi() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        FunctionsService.instance.fetchMoiEntries(widget.fn.id),
        _loadDraftEntries(),
      ]);
      if (!mounted) return;
      final dbEntries    = (results[0] as List).map((r) => MoiEntry.fromJson(r as Map<String, dynamic>)).toList();
      final draftEntries = results[1] as List<MoiEntry>;
      setState(() {
        widget.fn.moi
          ..clear()
          ..addAll([...draftEntries, ...dbEntries]);
      });
    } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'my_functions_load_error');
      debugPrint('[MoiTab] load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<MoiEntry> get _all => widget.fn.moi;
  List<MoiEntry> get _newMoi =>
      _all.where((m) => m.kind == MoiKind.newMoi).toList();
  List<MoiEntry> get _returned =>
      _all.where((m) => m.kind == MoiKind.returnMoi).toList();

  List<MoiEntry> get _current {
    List<MoiEntry> base;
    switch (_filter.index) {
      case 1:
        base = _newMoi;
        break;
      case 2:
        base = _returned;
        break;
      default:
        base = _all;
    }
    if (_search.isEmpty) return base;
    final q = _search.toLowerCase();
    return base
        .where(
          (m) =>
              m.personName.toLowerCase().contains(q) ||
              (m.familyName?.toLowerCase().contains(q) ?? false) ||
              (m.place?.toLowerCase().contains(q) ?? false) ||
              (m.relation?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final fn = widget.fn;

    // totals for current filter
    final listToShow = _current;
    final totalReceived = listToShow.fold(0.0, (s, m) => s + m.amount);
    final totalReturned = listToShow
        .where((m) => m.returned)
        .fold(0.0, (s, m) => s + (m.returnedAmount ?? m.amount));
    final pendingCount = listToShow.where((m) => !m.returned).length;

    return Column(
      children: [
        // ── Summary header ──────────────────────────────────────────────────
        Container(
          color: cardBg,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(
            children: [
              Row(
                children: [
                  _MoiStat(
                    'Received',
                    '${AppPrefs.cs}${totalReceived.toStringAsFixed(0)}',
                    _moiColor,
                  ),
                  const SizedBox(width: 8),
                  _MoiStat(
                    'Returned',
                    '${AppPrefs.cs}${totalReturned.toStringAsFixed(0)}',
                    AppColors.income,
                  ),
                  const SizedBox(width: 8),
                  _MoiStat(
                    'Pending',
                    '$pendingCount entries',
                    AppColors.expense,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Filter badges
              Row(
                children: [
                  _FilterBadge(
                    label: 'All',
                    count: _all.length,
                    selected: _filter.index == 0,
                    color: _moiColor,
                    sub: sub,
                    onTap: () => setState(() => _filter.animateTo(0)),
                  ),
                  const SizedBox(width: 8),
                  _FilterBadge(
                    label: '🆕 New',
                    count: _newMoi.length,
                    selected: _filter.index == 1,
                    color: MoiKind.newMoi.color,
                    sub: sub,
                    onTap: () => setState(() => _filter.animateTo(1)),
                  ),
                  const SizedBox(width: 8),
                  _FilterBadge(
                    label: '🔁 Return',
                    count: _returned.length,
                    selected: _filter.index == 2,
                    color: MoiKind.returnMoi.color,
                    sub: sub,
                    onTap: () => setState(() => _filter.animateTo(2)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Search bar
              Container(
                height: 38,
                decoration: BoxDecoration(
                  color: surfBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v.trim()),
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Nunito',
                    color: isDark ? AppColors.textDark : AppColors.textLight,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by name, place, relation...',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Nunito',
                      color: isDark ? AppColors.subDark : AppColors.subLight,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: isDark ? AppColors.subDark : AppColors.subLight,
                    ),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16),
                            onPressed: () => setState(() {
                              _search = '';
                              _searchCtrl.clear();
                            }),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),

        // ── Save all drafts banner ────────────────────────────────────────────
        if (!_loading) Builder(builder: (_) {
          final draftCount = _all.where((e) => e.isDraft).length;
          if (draftCount == 0) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_note_rounded, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$draftCount draft${draftCount == 1 ? '' : 's'} pending — not saved yet',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Nunito',
                      color: Colors.orange,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _savingDrafts
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.orange,
                        ),
                      )
                    : TextButton(
                        onPressed: _saveAllDrafts,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Save all',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
              ],
            ),
          );
        }),

        // ── List ─────────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : listToShow.isEmpty
              ? PlanEmptyState(
                  emoji: '💰',
                  title: _search.isNotEmpty
                      ? 'No results for "$_search"'
                      : 'No moi entries',
                  subtitle: _search.isNotEmpty
                      ? 'Try a different search'
                      : 'Tap + to record moi received at this function',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: listToShow.length,
                  itemBuilder: (_, i) => _MoiCard(
                    entry: listToShow[i],
                    isDark: isDark,
                    onMarkReturned: () =>
                        _showMarkReturned(context, listToShow[i], isDark),
                    onEdit: () =>
                        _showEditMoi(context, isDark, surfBg, listToShow[i]),
                    onUndo: () => setState(() {
                      listToShow[i].returned = false;
                      listToShow[i].returnedAmount = null;
                      listToShow[i].returnedOn = null;
                      widget.onUpdate();
                    }),
                    onDelete: () {
                      final entry = listToShow[i];
                      setState(() => fn.moi.remove(entry));
                      widget.onUpdate();
                      if (entry.isDraft) {
                        _removeDraftEntry(entry.id);
                      } else if (entry.id.contains('-')) {
                        FunctionsService.instance
                            .deleteMoiEntry(entry.id)
                            .catchError(
                              (e) => debugPrint('[Moi] delete error: $e'),
                            );
                      }
                    },
                  ),
                ),
        ),

        // ── FAB area ─────────────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.only(
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            right: 16,
          ),
          child: Align(
            alignment: Alignment.bottomRight,
            child: FloatingActionButton.extended(
              heroTag: 'moi_fab',
              onPressed: () => _showAddMoi(context, isDark, surfBg),
              backgroundColor: _moiColor,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Add Moi',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Nunito',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Add Moi sheet ─────────────────────────────────────────────────────────
  void _showAddMoi(BuildContext ctx, bool isDark, Color surfBg) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: _AddMoiSheet(
          fn: widget.fn,
          isDark: isDark,
          onDraft: (entries) async {
            final existing = await _loadDraftEntries();
            await _persistDrafts([...existing, ...entries]);
            _loadMoi();
          },
          onSave: _loadMoi,
        ),
      ),
    );
  }

  // ── Mark as returned sheet ───────────────────────────────────────────────
  void _showMarkReturned(BuildContext ctx, MoiEntry entry, bool isDark) {
    final amountCtrl = TextEditingController(
      text: entry.amount.toStringAsFixed(0),
    );
    final forFunctionCtrl = TextEditingController(
      text: entry.returnedForFunction ?? '',
    );
    DateTime returnDate = DateTime.now();

    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: StatefulBuilder(
                    builder: (ctx2, ss) => Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Text('✅', style: TextStyle(fontSize: 22)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Mark Moi as Returned',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'Nunito',
                                      ),
                                    ),
                                    Text(
                                      'to ${entry.personName}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'Nunito',
                                        color: AppColors.subDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Original amount chip
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _moiColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _moiColor.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  '💰',
                                  style: TextStyle(fontSize: 18),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Original moi received',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontFamily: 'Nunito',
                                        color: AppColors.subDark,
                                      ),
                                    ),
                                    Text(
                                      '${AppPrefs.cs}${entry.amount.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'DM Mono',
                                        color: _moiColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          const _SheetLabel(text: 'RETURNED FOR FUNCTION'),
                          PlanInputField(
                            controller: forFunctionCtrl,
                            hint: 'Function name (e.g. Raj\'s Wedding)',
                          ),
                          const SizedBox(height: 12),

                          const _SheetLabel(text: 'AMOUNT YOU ARE RETURNING'),
                          PlanInputField(
                            controller: amountCtrl,
                            hint: 'Return amount (${AppPrefs.cs})',
                            inputType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          const SizedBox(height: 12),

                          const _SheetLabel(text: 'RETURN DATE'),
                          LifeDateTile(
                            date: returnDate,
                            hint: 'Select date',
                            color: AppColors.income,
                            onTap: () async {
                              final d = await showDatePicker(
                                context: ctx,
                                initialDate: returnDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (d != null) ss(() => returnDate = d);
                            },
                          ),
                          const SizedBox(height: 16),

                          SaveButton(
                            label: 'Mark as Returned ✓',
                            color: AppColors.income,
                            onTap: () {
                              final amt = double.tryParse(
                                amountCtrl.text.trim(),
                              );
                              setState(() {
                                entry.returned = true;
                                entry.returnedAmount = amt ?? entry.amount;
                                entry.returnedOn = returnDate;
                                entry.returnedForFunction =
                                    forFunctionCtrl.text.trim().isEmpty
                                    ? null
                                    : forFunctionCtrl.text.trim();
                              });
                              widget.onUpdate();
                              if (entry.id.contains('-')) {
                                FunctionsService.instance
                                    .updateMoiEntry(entry.id, {
                                      'returned': true,
                                      'returned_amount': entry.returnedAmount,
                                      'returned_on': entry.returnedOn
                                          ?.toIso8601String()
                                          .split('T')
                                          .first,
                                      'returned_for_function':
                                          entry.returnedForFunction,
                                    })
                                    .catchError(
                                      (e) => debugPrint(
                                        '[Moi] mark returned error: $e',
                                      ),
                                    );
                              }
                              Navigator.pop(ctx);
                            },
                          ),
                        ],
                      ),
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

  // ── Edit Moi sheet ────────────────────────────────────────────────────────
  void _showEditMoi(
    BuildContext ctx,
    bool isDark,
    Color surfBg,
    MoiEntry entry,
  ) {
    final nameCtrl = TextEditingController(text: entry.personName);
    final familyNameCtrl = TextEditingController(text: entry.familyName ?? '');
    final placeCtrl = TextEditingController(text: entry.place ?? '');
    final phoneCtrl = TextEditingController(text: entry.phone ?? '');
    final relationCtrl = TextEditingController(text: entry.relation ?? '');
    final amountCtrl = TextEditingController(
      text: entry.amount.toStringAsFixed(0),
    );
    final notesCtrl = TextEditingController(text: entry.notes ?? '');
    var kind = entry.kind;

    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: StatefulBuilder(
                    builder: (ctx2, ss) => Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Edit Moi Entry',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Nunito',
                            ),
                          ),
                          const SizedBox(height: 12),
                          const _SheetLabel(text: 'MOI TYPE'),
                          Row(
                            children: MoiKind.values.map((k) {
                              final selected = kind == k;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () => ss(() => kind = k),
                                  child: Container(
                                    margin: EdgeInsets.only(
                                      right: k == MoiKind.newMoi ? 8 : 0,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? k.color.withValues(alpha: 0.12)
                                          : surfBg,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: selected
                                            ? k.color
                                            : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          k.emoji,
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          k.label,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            fontFamily: 'Nunito',
                                            color: selected
                                                ? k.color
                                                : (isDark
                                                      ? AppColors.subDark
                                                      : AppColors.subLight),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),
                          const _SheetLabel(text: 'PERSON DETAILS'),
                          PlanInputField(controller: nameCtrl, hint: 'Name *'),
                          const SizedBox(height: 8),
                          PlanInputField(
                            controller: familyNameCtrl,
                            hint: 'Family name / Surname',
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: PlanInputField(
                                  controller: placeCtrl,
                                  hint: 'Place / Town',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: PlanInputField(
                                  controller: relationCtrl,
                                  hint: 'Relation',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          PlanInputField(
                            controller: phoneCtrl,
                            hint: 'Phone number',
                            inputType: TextInputType.phone,
                          ),
                          const SizedBox(height: 14),
                          const _SheetLabel(text: 'MOI AMOUNT'),
                          PlanInputField(
                            controller: amountCtrl,
                            hint: 'Amount received (${AppPrefs.cs}) *',
                            inputType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          PlanInputField(
                            controller: notesCtrl,
                            hint: 'Notes (optional)',
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),
                          SaveButton(
                            label: 'Update Moi Entry',
                            color: kind.color,
                            onTap: () {
                              if (nameCtrl.text.trim().isEmpty) return;
                              final amt = double.tryParse(
                                amountCtrl.text.trim(),
                              );
                              if (amt == null || amt <= 0) return;
                              setState(() {
                                entry.personName = nameCtrl.text.trim();
                                entry.familyName =
                                    familyNameCtrl.text.trim().isEmpty
                                    ? null
                                    : familyNameCtrl.text.trim();
                                entry.amount = amt;
                                entry.kind = kind;
                                entry.place = placeCtrl.text.trim().isEmpty
                                    ? null
                                    : placeCtrl.text.trim();
                                entry.phone = phoneCtrl.text.trim().isEmpty
                                    ? null
                                    : phoneCtrl.text.trim();
                                entry.relation =
                                    relationCtrl.text.trim().isEmpty
                                    ? null
                                    : relationCtrl.text.trim();
                                entry.notes = notesCtrl.text.trim().isEmpty
                                    ? null
                                    : notesCtrl.text.trim();
                              });
                              widget.onUpdate();
                              if (entry.id.contains('-')) {
                                FunctionsService.instance
                                    .updateMoiEntry(entry.id, entry.toJson())
                                    .catchError(
                                      (e) => debugPrint(
                                        '[Moi] edit error: $e',
                                      ),
                                    );
                              }
                              Navigator.pop(ctx);
                            },
                          ),
                        ],
                      ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// BULK MOI ROW (data holder for spreadsheet)
// ─────────────────────────────────────────────────────────────────────────────

class _BulkMoiRow {
  final nameCtrl = TextEditingController();
  final familyCtrl = TextEditingController();
  final placeCtrl = TextEditingController();
  final relationCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  MoiKind kind = MoiKind.newMoi;

  bool get isValid {
    final name = nameCtrl.text.trim();
    final place = placeCtrl.text.trim();
    final amt = double.tryParse(amountCtrl.text.trim());
    return name.isNotEmpty && place.isNotEmpty && amt != null && amt > 0;
  }

  MoiEntry? toEntry() {
    final name = nameCtrl.text.trim();
    final amt = double.tryParse(amountCtrl.text.trim());
    if (name.isEmpty || amt == null || amt <= 0) return null;
    return MoiEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      personName: name,
      familyName: familyCtrl.text.trim().isEmpty ? null : familyCtrl.text.trim(),
      place: placeCtrl.text.trim().isEmpty ? null : placeCtrl.text.trim(),
      phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
      relation: relationCtrl.text.trim().isEmpty ? null : relationCtrl.text.trim(),
      amount: amt,
      kind: kind,
      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
    );
  }

  Map<String, dynamic> toData(String functionId, String walletId) => {
    'function_id': functionId,
    'wallet_id': walletId,
    'person_name': nameCtrl.text.trim(),
    'family_name': familyCtrl.text.trim().isEmpty ? null : familyCtrl.text.trim(),
    'place': placeCtrl.text.trim().isEmpty ? null : placeCtrl.text.trim(),
    'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
    'relation': relationCtrl.text.trim().isEmpty ? null : relationCtrl.text.trim(),
    'amount': double.parse(amountCtrl.text.trim()),
    'kind': kind.name,
    'returned': false,
    'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
  };

  void dispose() {
    nameCtrl.dispose();
    familyCtrl.dispose();
    placeCtrl.dispose();
    relationCtrl.dispose();
    phoneCtrl.dispose();
    amountCtrl.dispose();
    notesCtrl.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD MOI SHEET  (single entry + bulk spreadsheet tabs)
// ─────────────────────────────────────────────────────────────────────────────

class _AddMoiSheet extends StatefulWidget {
  final FunctionModel fn;
  final bool isDark;
  final void Function(List<MoiEntry>) onDraft;
  final void Function() onSave;

  const _AddMoiSheet({
    required this.fn,
    required this.isDark,
    required this.onDraft,
    required this.onSave,
  });

  @override
  State<_AddMoiSheet> createState() => _AddMoiSheetState();
}

class _AddMoiSheetState extends State<_AddMoiSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _saving = false;

  // Single entry state
  final _nameCtrl = TextEditingController();
  final _familyCtrl = TextEditingController();
  final _placeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _relationCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  MoiKind _kind = MoiKind.newMoi;

  // Bulk entry state
  final List<_BulkMoiRow> _rows = [];

  // Quick entry controllers (bulk tab)
  final _qNameCtrl   = TextEditingController();
  final _qPlaceCtrl  = TextEditingController();
  final _qFamilyCtrl = TextEditingController();
  final _qAmountCtrl = TextEditingController();
  final _qNameFocus  = FocusNode();
  MoiKind _qKind = MoiKind.newMoi;
  bool _csvLoading = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
    _rows.add(_BulkMoiRow());
  }

  @override
  void dispose() {
    _tab.dispose();
    _nameCtrl.dispose();
    _familyCtrl.dispose();
    _placeCtrl.dispose();
    _phoneCtrl.dispose();
    _relationCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    _qNameCtrl.dispose();
    _qPlaceCtrl.dispose();
    _qFamilyCtrl.dispose();
    _qAmountCtrl.dispose();
    _qNameFocus.dispose();
    for (final r in _rows) { r.dispose(); }
    super.dispose();
  }

  List<MoiEntry> _singleEntries() {
    final name = _nameCtrl.text.trim();
    final amt = double.tryParse(_amountCtrl.text.trim());
    if (name.isEmpty || amt == null || amt <= 0) return [];
    return [
      MoiEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        personName: name,
        familyName: _familyCtrl.text.trim().isEmpty ? null : _familyCtrl.text.trim(),
        place: _placeCtrl.text.trim().isEmpty ? null : _placeCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        relation: _relationCtrl.text.trim().isEmpty ? null : _relationCtrl.text.trim(),
        amount: amt,
        kind: _kind,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      ),
    ];
  }

  Map<String, dynamic> _singleData() => {
    'function_id': widget.fn.id,
    'wallet_id': widget.fn.walletId,
    'person_name': _nameCtrl.text.trim(),
    'family_name': _familyCtrl.text.trim().isEmpty ? null : _familyCtrl.text.trim(),
    'place': _placeCtrl.text.trim().isEmpty ? null : _placeCtrl.text.trim(),
    'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
    'relation': _relationCtrl.text.trim().isEmpty ? null : _relationCtrl.text.trim(),
    'amount': double.parse(_amountCtrl.text.trim()),
    'kind': _kind.name,
    'returned': false,
    'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
  };

  Future<void> _doDraft() async {
    List<MoiEntry> entries;
    if (_tab.index == 0) {
      final name  = _nameCtrl.text.trim();
      final place = _placeCtrl.text.trim();
      final amt   = double.tryParse(_amountCtrl.text.trim());
      if (name.isEmpty || place.isEmpty || amt == null || amt <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name, Place and Amount are required to save as draft')),
        );
        return;
      }
      entries = _singleEntries();
    } else {
      entries = _rows
          .where((r) => r.isValid)
          .map((r) => r.toEntry())
          .whereType<MoiEntry>()
          .toList();
    }
    if (entries.isEmpty) return;
    widget.onDraft(entries);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _doSave() async {
    setState(() => _saving = true);
    try {
      if (_tab.index == 0) {
        final entries = _singleEntries();
        if (entries.isEmpty) { setState(() => _saving = false); return; }
        await FunctionsService.instance.addMoiEntry(_singleData());
      } else {
        final dataList = _rows
            .where((r) => r.isValid)
            .map((r) => r.toData(widget.fn.id, widget.fn.walletId))
            .toList();
        if (dataList.isEmpty) { setState(() => _saving = false); return; }
        await FunctionsService.instance.addMoiEntries(dataList);
      }
      widget.onSave();
      if (mounted) Navigator.pop(context);
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'add_moi_save');
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Quick entry helper ────────────────────────────────────────────────────

  void _addQuickRow() {
    final name  = _qNameCtrl.text.trim();
    final place = _qPlaceCtrl.text.trim();
    final amt   = double.tryParse(_qAmountCtrl.text.trim());
    if (name.isEmpty || place.isEmpty || amt == null || amt <= 0) return;

    final row = _BulkMoiRow();
    row.nameCtrl.text   = name;
    row.placeCtrl.text  = place;
    row.familyCtrl.text = _qFamilyCtrl.text.trim();
    row.amountCtrl.text = amt.toStringAsFixed(amt.truncateToDouble() == amt ? 0 : 2);
    row.kind = _qKind;

    setState(() {
      _rows.add(row);
      _qNameCtrl.clear();
      _qPlaceCtrl.clear();
      _qFamilyCtrl.clear();
      _qAmountCtrl.clear();
      _qKind = MoiKind.newMoi;
    });
    _qNameFocus.requestFocus();
  }

  // ── CSV template download ─────────────────────────────────────────────────

  Future<void> _downloadTemplate() async {
    const headers = 'Name,Family,Place,Amount,Type\n';
    const sample  = 'Ravi Kumar,Kumar Family,Chennai,500,newMoi\n'
                    'Meena Devi,,Coimbatore,1000,newMoi\n';
    final csv = headers + sample;
    try {
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/moi_template.csv');
      await file.writeAsString(csv);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: 'Moi Entry Template',
        ),
      );
    } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'my_functions_template_download_error');
      debugPrint('[Moi] template download error: $e');
    }
  }

  // ── CSV import dialog ─────────────────────────────────────────────────────

  Future<void> _showCsvImportDialog() async {
    final imported = await showDialog<List<_BulkMoiRow>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CsvImportDialog(isDark: widget.isDark),
    );
    if (imported != null && imported.isNotEmpty) {
      setState(() => _rows.addAll(imported));
    }
  }

  Widget _buildSingleTab(bool isDark, Color surfBg, Color sub) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Record moi received at this function',
            style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub),
          ),
          const SizedBox(height: 12),
          const _SheetLabel(text: 'MOI TYPE'),
          Row(
            children: MoiKind.values.map((k) {
              final selected = _kind == k;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _kind = k),
                  child: Container(
                    margin: EdgeInsets.only(right: k == MoiKind.newMoi ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? k.color.withValues(alpha: 0.12)
                          : surfBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? k.color : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(k.emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          k.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: selected
                                ? k.color
                                : (isDark ? AppColors.subDark : AppColors.subLight),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          const _SheetLabel(text: 'PERSON DETAILS'),
          PlanInputField(controller: _nameCtrl, hint: 'Name *'),
          const SizedBox(height: 8),
          PlanInputField(controller: _familyCtrl, hint: 'Family name / Surname'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: PlanInputField(controller: _placeCtrl, hint: 'Place / Town'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PlanInputField(controller: _relationCtrl, hint: 'Relation'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          PlanInputField(
            controller: _phoneCtrl,
            hint: 'Phone number',
            inputType: TextInputType.phone,
          ),
          const SizedBox(height: 14),
          const _SheetLabel(text: 'MOI AMOUNT'),
          PlanInputField(
            controller: _amountCtrl,
            hint: 'Amount received (${AppPrefs.cs}) *',
            inputType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 8),
          PlanInputField(
            controller: _notesCtrl,
            hint: 'Notes (optional)',
            maxLines: 2,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildBulkTab(bool isDark, Color surfBg, Color sub) {
    final tc       = isDark ? AppColors.textDark  : AppColors.textLight;
    final inputBg  = isDark ? AppColors.surfDark  : const Color(0xFFEDEEF5);
    final totalAmt = _rows.fold(0.0, (s, r) {
      final a = double.tryParse(r.amountCtrl.text.trim()) ?? 0;
      return s + a;
    });

    // ── Shared input decoration ───────────────────────────────────────────
    InputDecoration inputDec(String hint, {bool required = false}) =>
        InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub),
          filled: true,
          fillColor: inputBg,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: required ? _moiColor : AppColors.primary,
              width: 1.5,
            ),
          ),
        );

    return Column(
      children: [

        // ── Top action bar ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _csvLoading ? null : _showCsvImportDialog,
                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                  label: const Text('Import CSV',
                      style: TextStyle(fontSize: 12, fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _moiColor,
                    side: BorderSide(color: _moiColor.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _downloadTemplate,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Template',
                      style: TextStyle(fontSize: 12, fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: sub,
                    side: BorderSide(color: sub.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Quick entry card ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: _moiColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _moiColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Kind toggle + Name
                Row(
                  children: [
                    // Kind toggle
                    GestureDetector(
                      onTap: () => setState(() => _qKind =
                          _qKind == MoiKind.newMoi
                              ? MoiKind.returnMoi
                              : MoiKind.newMoi),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: _qKind.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _qKind.color.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_qKind.emoji,
                                style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Text(
                              _qKind == MoiKind.newMoi ? 'New' : 'Return',
                              style: TextStyle(
                                fontSize: 11, fontFamily: 'Nunito',
                                fontWeight: FontWeight.w700,
                                color: _qKind.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Name
                    Expanded(
                      child: TextField(
                        controller: _qNameCtrl,
                        focusNode: _qNameFocus,
                        textCapitalization: TextCapitalization.words,
                        style: TextStyle(fontSize: 13, fontFamily: 'Nunito',
                            color: tc),
                        decoration: inputDec('Name *', required: true),
                        onSubmitted: (_) => _addQuickRow(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Row 2: Place + Family
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _qPlaceCtrl,
                        textCapitalization: TextCapitalization.words,
                        style: TextStyle(fontSize: 13, fontFamily: 'Nunito',
                            color: tc),
                        decoration: inputDec('Place *', required: true),
                        onSubmitted: (_) => _addQuickRow(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _qFamilyCtrl,
                        textCapitalization: TextCapitalization.words,
                        style: TextStyle(fontSize: 13, fontFamily: 'Nunito',
                            color: tc),
                        decoration: inputDec('Family (optional)'),
                        onSubmitted: (_) => _addQuickRow(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Row 3: Amount + Add button
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _qAmountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: TextStyle(fontSize: 13, fontFamily: 'Nunito',
                            color: tc),
                        decoration: inputDec('Amount ${AppPrefs.cs} *', required: true),
                        onSubmitted: (_) => _addQuickRow(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _addQuickRow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _moiColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add',
                          style: TextStyle(fontSize: 13, fontFamily: 'Nunito',
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Divider + count ─────────────────────────────────────────────
        if (_rows.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Text(
                  '${_rows.length} ${_rows.length == 1 ? 'entry' : 'entries'}',
                  style: TextStyle(
                    fontSize: 11, fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700, color: sub,
                  ),
                ),
                const Spacer(),
                Text(
                  'Total ${AppPrefs.cs}${totalAmt % 1 == 0 ? totalAmt.toInt() : totalAmt.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12, fontFamily: 'Nunito',
                    fontWeight: FontWeight.w900, color: _moiColor,
                  ),
                ),
              ],
            ),
          ),

        // ── Entries list ────────────────────────────────────────────────
        Expanded(
          child: _rows.isEmpty
              ? Center(
                  child: Text(
                    'Add entries above or import a CSV',
                    style: TextStyle(fontSize: 13, fontFamily: 'Nunito',
                        color: sub),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
                  itemCount: _rows.length,
                  itemBuilder: (_, i) {
                    final r = _rows[i];
                    final amt = double.tryParse(r.amountCtrl.text.trim());
                    return Dismissible(
                      key: ObjectKey(r),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: Colors.redAccent, size: 20),
                      ),
                      onDismissed: (_) =>
                          setState(() => _rows.removeAt(i)),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: surfBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Text(r.kind.emoji,
                                style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.nameCtrl.text,
                                    style: TextStyle(
                                      fontSize: 13, fontFamily: 'Nunito',
                                      fontWeight: FontWeight.w800, color: tc,
                                    ),
                                  ),
                                  Text(
                                    [
                                      r.placeCtrl.text,
                                      if (r.familyCtrl.text.isNotEmpty)
                                        r.familyCtrl.text,
                                    ].join(' · '),
                                    style: TextStyle(
                                      fontSize: 11, fontFamily: 'Nunito',
                                      color: sub,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${AppPrefs.cs}${amt == null ? '-' : amt % 1 == 0 ? amt.toInt() : amt.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 13, fontFamily: 'Nunito',
                                fontWeight: FontWeight.w900,
                                color: r.kind.color,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setState(() => _rows.removeAt(i)),
                              child: Icon(Icons.close_rounded,
                                  size: 16, color: sub),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Add Moi Entry',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                      color: tc,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Tab bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: surfBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tab,
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Nunito',
                  ),
                  labelColor: _moiColor,
                  unselectedLabelColor: sub,
                  indicator: BoxDecoration(
                    color: _moiColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _moiColor.withValues(alpha: 0.4)),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Add Entry'),
                    Tab(text: 'Bulk Entry'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Tab content
            Flexible(
              child: TabBarView(
                controller: _tab,
                children: [
                  _buildSingleTab(isDark, surfBg, sub),
                  _buildBulkTab(isDark, surfBg, sub),
                ],
              ),
            ),
            // Draft / Save buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : _doDraft,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _moiColor.withValues(alpha: 0.6)),
                        foregroundColor: _moiColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Draft',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _doSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _moiColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOI CARD
// ─────────────────────────────────────────────────────────────────────────────

// ── CSV Import Dialog ─────────────────────────────────────────────────────────
class _CsvImportDialog extends StatefulWidget {
  final bool isDark;
  const _CsvImportDialog({required this.isDark});

  @override
  State<_CsvImportDialog> createState() => _CsvImportDialogState();
}

class _CsvImportDialogState extends State<_CsvImportDialog> {
  final _pasteCtrl = TextEditingController();
  int _preview = 0;

  @override
  void dispose() {
    _pasteCtrl.dispose();
    super.dispose();
  }

  List<_BulkMoiRow> _parse() {
    final lines = _pasteCtrl.text.trim().split('\n')
        .where((l) => l.trim().isNotEmpty).toList();
    final hasHeader = lines.isNotEmpty &&
        lines.first.toLowerCase().contains('name');
    final dataLines = hasHeader ? lines.skip(1).toList() : lines;

    final result = <_BulkMoiRow>[];
    for (final line in dataLines) {
      final cols = line.split(',');
      if (cols.length < 4) continue;
      final name   = cols[0].trim();
      final family = cols.length > 1 ? cols[1].trim() : '';
      final place  = cols.length > 2 ? cols[2].trim() : '';
      final amt    = double.tryParse(cols[3].trim());
      final type   = cols.length > 4 ? cols[4].trim() : '';
      if (name.isEmpty || place.isEmpty || amt == null || amt <= 0) continue;
      final row = _BulkMoiRow();
      row.nameCtrl.text   = name;
      row.familyCtrl.text = family;
      row.placeCtrl.text  = place;
      row.amountCtrl.text = amt.toStringAsFixed(
          amt.truncateToDouble() == amt ? 0 : 2);
      row.kind = type == 'returnMoi' ? MoiKind.returnMoi : MoiKind.newMoi;
      result.add(row);
    }
    return result;
  }

  void _close() {
    FocusScope.of(context).unfocus();
    Navigator.pop(context);
  }

  void _import() {
    FocusScope.of(context).unfocus();
    Navigator.pop(context, _parse());
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = widget.isDark;
    final bg      = isDark ? AppColors.cardDark  : AppColors.cardLight;
    final tc      = isDark ? AppColors.textDark  : AppColors.textLight;
    final sub     = isDark ? AppColors.subDark   : AppColors.subLight;
    final surfBg  = isDark ? AppColors.surfDark  : const Color(0xFFEDEEF5);

    return AlertDialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Import CSV',
        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w900,
            fontSize: 17, color: tc)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Copy your CSV content and paste below.\nExpected columns: Name, Family, Place, Amount, Type',
              style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pasteCtrl,
              maxLines: 8,
              style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: tc),
              decoration: InputDecoration(
                hintText: 'Paste CSV here…',
                hintStyle: TextStyle(color: sub, fontSize: 12,
                    fontFamily: 'Nunito'),
                filled: true,
                fillColor: surfBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              onChanged: (v) {
                final lines = v.trim().split('\n')
                    .where((l) => l.trim().isNotEmpty).toList();
                final hasHeader = lines.isNotEmpty &&
                    lines.first.toLowerCase().contains('name');
                final dataLines =
                    hasHeader ? lines.skip(1).toList() : lines;
                setState(() => _preview = dataLines
                    .where((l) => l.split(',').length >= 4).length);
              },
            ),
            if (_preview > 0) ...[
              const SizedBox(height: 8),
              Text('$_preview valid rows detected',
                style: const TextStyle(fontSize: 12, fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700, color: _moiColor)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _close,
          child: Text('Cancel',
              style: TextStyle(color: sub, fontFamily: 'Nunito')),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _moiColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          onPressed: _preview == 0 ? null : _import,
          child: Text('Import $_preview rows',
            style: const TextStyle(fontFamily: 'Nunito',
                fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      ],
    );
  }
}

class _MoiCard extends StatelessWidget {
  final MoiEntry entry;
  final bool isDark;
  final VoidCallback onMarkReturned;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onUndo;

  const _MoiCard({
    required this.entry,
    required this.isDark,
    required this.onMarkReturned,
    required this.onDelete,
    required this.onEdit,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final kindColor = entry.kind.color;

    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false; // we handle deletion in onDelete
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.expense.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.expense,
          size: 24,
        ),
      ),
      child: GestureDetector(
        onTap: onEdit,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: entry.isDraft
                ? Colors.orange.withValues(alpha: 0.06)
                : cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: entry.isDraft
                  ? Colors.orange.withValues(alpha: 0.35)
                  : entry.returned
                      ? AppColors.income.withValues(alpha: 0.25)
                      : kindColor.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              // ── Top row ──────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kind indicator pill (left strip)
                    Container(
                      width: 4,
                      height: 52,
                      decoration: BoxDecoration(
                        color: kindColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Main content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name + returned badge
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.personName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        fontFamily: 'Nunito',
                                        color: tc,
                                        decoration: entry.returned
                                            ? TextDecoration.lineThrough
                                            : null,
                                        decorationColor: AppColors.income,
                                        decorationThickness: 2,
                                      ),
                                    ),
                                    if (entry.familyName != null)
                                      Text(
                                        entry.familyName!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'Nunito',
                                          color: sub,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Draft badge
                              if (entry.isDraft) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.orange.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: const Text(
                                    'DRAFT',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'Nunito',
                                      color: Colors.orange,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 6),
                              // Kind badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: kindColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: kindColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      entry.kind.emoji,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      entry.kind.label,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        fontFamily: 'Nunito',
                                        color: kindColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Place · Relation
                          Row(
                            children: [
                              if (entry.place != null) ...[
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 12,
                                  color: sub,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  entry.place!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'Nunito',
                                    color: sub,
                                  ),
                                ),
                                if (entry.relation != null)
                                  Text(
                                    ' · ',
                                    style: TextStyle(color: sub, fontSize: 11),
                                  ),
                              ],
                              if (entry.relation != null)
                                Text(
                                  entry.relation!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'Nunito',
                                    color: sub,
                                  ),
                                ),
                            ],
                          ),

                          if (entry.phone != null) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.phone_rounded, size: 11, color: sub),
                                const SizedBox(width: 3),
                                Text(
                                  entry.phone!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'Nunito',
                                    color: sub,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          if (entry.notes != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              entry.notes!,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Nunito',
                                color: sub,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Amount column (right)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${AppPrefs.cs}${entry.amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'DM Mono',
                            color: entry.returned ? sub : _moiColor,
                            decoration: entry.returned
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: AppColors.income,
                            decorationThickness: 2,
                          ),
                        ),
                        if (entry.returned && entry.returnedAmount != null)
                          Text(
                            '${AppPrefs.cs}${entry.returnedAmount!.toStringAsFixed(0)} returned',
                            style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'DM Mono',
                              color: AppColors.income,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Bottom action bar ─────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: entry.returned
                      ? AppColors.income.withOpacity(0.06)
                      : kindColor.withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    if (entry.returned) ...[
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: AppColors.income,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.returnedOn != null
                                  ? 'Returned on ${entry.returnedOn!.day} ${months[entry.returnedOn!.month]} ${entry.returnedOn!.year}'
                                  : 'Returned',
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'Nunito',
                                color: AppColors.income,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (entry.returnedForFunction != null)
                              Text(
                                'For: ${entry.returnedForFunction!}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'Nunito',
                                  color: AppColors.income,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Icon(
                        Icons.hourglass_top_rounded,
                        size: 13,
                        color: kindColor.withOpacity(0.7),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Pending return',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Nunito',
                          color: kindColor.withOpacity(0.8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (!entry.returned)
                      GestureDetector(
                        onTap: onMarkReturned,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.income,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Mark Returned',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Nunito',
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: onUndo,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.subLight.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Undo',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Nunito',
                              color: AppColors.subDark,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOI STAT CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _FilterBadge extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color color, sub;
  final VoidCallback onTap;
  const _FilterBadge({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? color : sub.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              fontFamily: 'Nunito',
              color: selected ? color : sub,
            ),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: selected ? color : sub.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
                color: selected ? Colors.white : sub,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MoiStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MoiStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              fontFamily: 'DM Mono',
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 9, fontFamily: 'Nunito', color: color),
          ),
        ],
      ),
    ),
  );
}

