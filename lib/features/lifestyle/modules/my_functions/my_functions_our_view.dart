part of 'my_functions_screen.dart';

// ── Our Functions sub-tabbed view (Planned / Completed) ──────────────────────

class _OurFunctionsView extends StatefulWidget {
  final List<FunctionModel> functions;
  final bool isDark;
  final Map<String, String> familyWalletNames;
  final Map<String, String> allFamilyWalletNames;
  final String currentWalletId;
  final String personalWalletId;
  final void Function(FunctionModel) onDelete;
  final VoidCallback onUpdate;
  final void Function(bool isPlanned) onSubTabChanged;

  const _OurFunctionsView({
    required this.functions,
    required this.isDark,
    required this.familyWalletNames,
    required this.allFamilyWalletNames,
    required this.currentWalletId,
    required this.personalWalletId,
    required this.onDelete,
    required this.onUpdate,
    required this.onSubTabChanged,
  });

  @override
  State<_OurFunctionsView> createState() => _OurFunctionsViewState();
}

class _OurFunctionsViewState extends State<_OurFunctionsView>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      setState(() {});
      if (_tab.indexIsChanging) widget.onSubTabChanged(_tab.index == 0);
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  DateTime get _today =>
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  List<FunctionModel> get _planned => widget.functions
      .where((f) => f.isPlanned && (f.functionDate == null || !f.functionDate!.isBefore(_today)))
      .toList();

  List<FunctionModel> get _completedExplicit =>
      widget.functions.where((f) => !f.isPlanned).toList();

  List<FunctionModel> get _pastPlanned => widget.functions
      .where((f) => f.isPlanned && f.functionDate != null && f.functionDate!.isBefore(_today))
      .toList();

  /// Completed tab = explicitly-completed + past-planned (no duplicates)
  List<FunctionModel> get _completedTab {
    final result = [..._completedExplicit];
    for (final f in _pastPlanned) {
      if (!result.any((c) => c.id == f.id)) result.add(f);
    }
    return result;
  }

  void _navigate(FunctionModel fn, {bool forceCompleted = false}) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (ctx, anim, secondaryAnim) =>
            (fn.isPlanned && !forceCompleted)
                ? _PlannedFunctionDetail(
                    fn: fn,
                    isDark: widget.isDark,
                    currentWalletId: widget.currentWalletId,
                    personalWalletId: widget.personalWalletId,
                    allFamilyWalletNames: widget.allFamilyWalletNames,
                    onUpdate: widget.onUpdate,
                    familyWalletNames: widget.familyWalletNames,
                  )
                : _FunctionDetail(
                    fn: fn,
                    isDark: widget.isDark,
                    currentWalletId: widget.currentWalletId,
                    personalWalletId: widget.personalWalletId,
                    allFamilyWalletNames: widget.allFamilyWalletNames,
                    onUpdate: widget.onUpdate,
                    familyWalletNames: widget.familyWalletNames,
                    showPlanningTabs: fn.isPlanned,
                  ),
        transitionsBuilder: (ctx, anim, secondaryAnim, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  Widget _buildList(List<FunctionModel> fns, {bool asCompleted = false}) {
    if (fns.isEmpty) {
      return PlanEmptyState(
        emoji: asCompleted ? '✅' : '📋',
        title: asCompleted ? 'No completed functions' : 'No planned functions',
        subtitle: asCompleted
            ? 'Completed functions appear here'
            : 'Plan a function to get started',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: fns.length,
      itemBuilder: (_, i) {
        final fn = fns[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SwipeTile(
            onDelete: () => widget.onDelete(fn),
            child: _FunctionCard(
              fn: fn,
              isDark: widget.isDark,
              familyLabel: widget.familyWalletNames[fn.walletId],
              onTap: () => _navigate(fn, forceCompleted: asCompleted),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Container(
            decoration: BoxDecoration(
              color: surfBg,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(3),
            child: TabBar(
              controller: _tab,
              indicator: BoxDecoration(
                color: _funcColor,
                borderRadius: BorderRadius.circular(11),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: sub,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                fontFamily: 'Nunito',
              ),
              tabs: [
                Tab(text: 'Planned (${_planned.length})'),
                Tab(text: 'Completed (${_completedTab.length})'),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildList(_planned),
              _buildList(_completedTab, asCompleted: true),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Grouped functions list (legacy — kept for reference) ──────────────────────
class _GroupedFunctionsList extends StatelessWidget {
  final List<FunctionModel> functions;
  final bool isDark;
  final Map<String, String> familyWalletNames;
  final void Function(FunctionModel) onDelete;
  final void Function(FunctionModel) onTap;

  const _GroupedFunctionsList({
    required this.functions,
    required this.isDark,
    required this.familyWalletNames,
    required this.onDelete,
    required this.onTap,
  });

  Widget _sectionHeader(String label, Color color) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            fontFamily: 'Nunito',
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final planned = functions.where((f) => f.isPlanned).toList();
    final completed = functions.where((f) => !f.isPlanned).toList();

    Widget buildCard(FunctionModel fn) {
      final familyLabel = familyWalletNames[fn.walletId];
      final card = _FunctionCard(
        fn: fn,
        isDark: isDark,
        familyLabel: familyLabel,
        onTap: () => onTap(fn),
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: familyLabel != null
            ? card
            : SwipeTile(
                onDelete: () => onDelete(fn),
                child: card,
              ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (planned.isNotEmpty) ...[
          _sectionHeader('PLANNED', AppColors.income),
          ...planned.map(buildCard),
        ],
        if (completed.isNotEmpty) ...[
          _sectionHeader('COMPLETED', AppColors.primary),
          ...completed.map(buildCard),
        ],
      ],
    );
  }
}

// ── Function card ─────────────────────────────────────────────────────────────
class _FunctionCard extends StatelessWidget {
  final FunctionModel fn;
  final bool isDark;
  final VoidCallback onTap;
  final String? familyLabel;
  const _FunctionCard({
    required this.fn,
    required this.isDark,
    required this.onTap,
    this.familyLabel,
  });

  String get _typeLabel =>
      fn.type == FunctionType.other && fn.customType != null
      ? fn.customType!
      : fn.type.label;

  String _countdown(Color sub) {
    if (fn.functionDate == null) return '';
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final d = DateTime(
      fn.functionDate!.year,
      fn.functionDate!.month,
      fn.functionDate!.day,
    );
    final diff = d.difference(today).inDays;
    if (diff == 0) return '🎉 Today!';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff > 1) {
      if (diff >= 365) {
        final years = (diff / 365).floor();
        return 'In $years yr${years > 1 ? 's' : ''}';
      }
      return 'In $diff days';
    }
    final absDiff = diff.abs();
    if (absDiff >= 365) {
      final years = (absDiff / 365).floor();
      return '$years yr${years > 1 ? 's' : ''} ago';
    }
    return '$absDiff days ago';
  }

  Color _countdownColor(bool isDark) {
    if (fn.functionDate == null) return Colors.transparent;
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final d = DateTime(
      fn.functionDate!.year,
      fn.functionDate!.month,
      fn.functionDate!.day,
    );
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
              decoration: BoxDecoration(
                color: _funcColor,
                borderRadius: const BorderRadius.horizontal(
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
                    // Icon badge
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _funcColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: EmojiOrImage(value: fn.icon, size: 26),
                    ),
                    const SizedBox(width: 12),
                    // Middle info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fn.title,
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
                                  _typeLabel,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                    color: _funcColor,
                                  ),
                                ),
                              ),
                              if (fn.functionDate != null)
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
                                      fmtDateShort(fn.functionDate!),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontFamily: 'Nunito',
                                        color: sub,
                                      ),
                                    ),
                                  ],
                                ),
                              if (familyLabel != null)
                                FamilyBadge(label: familyLabel!),
                            ],
                          ),
                          if (fn.venue != null) ...[
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
                                    fn.venue!,
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
                    // Right: countdown + summary
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (fn.functionDate != null)
                          Text(
                            _countdown(sub),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: _countdownColor(isDark),
                            ),
                          ),
                        if (fn.gifts.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '🎁 ${fn.gifts.length}',
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'Nunito',
                              color: sub,
                            ),
                          ),
                        ],
                        if (fn.moi.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '💰 ${fn.moi.length}',
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'Nunito',
                              color: _moiColor,
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

