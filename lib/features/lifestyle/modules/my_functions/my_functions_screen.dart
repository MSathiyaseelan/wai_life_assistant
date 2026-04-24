import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/core/widgets/emoji_or_image.dart';
import 'package:wai_life_assistant/core/supabase/profile_service.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyle_models.dart';
import 'package:wai_life_assistant/services/ai_parser.dart';
import 'package:wai_life_assistant/core/supabase/functions_service.dart';
import '../../widgets/life_widgets.dart';
import 'package:wai_life_assistant/features/planit/widgets/plan_widgets.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';

const _funcColor = Color(0xFF6C63FF);

const _fnIconEmojis = [
  '🎊', '🎉', '💍', '🥂', '🎂', '🙏', '🎁', '🌸',
  '🏠', '🎵', '🌺', '🌟', '🎀', '🥳', '🍾', '🕌',
  '⛪', '🎶', '💐', '🎠',
];

class MyFunctionsScreen extends StatefulWidget {
  final String walletId;
  final String walletName;
  final String walletEmoji;
  final bool openAdd;
  final int initialTab;

  /// Lifted list from PlanItScreen — only used in Personal view for merged data.
  final List<FunctionModel>? parentFunctions;

  /// Family wallet ID → display label. Non-empty only in Personal view.
  final Map<String, String> familyWalletNames;
  final List<PlanMember> members;
  const MyFunctionsScreen({
    super.key,
    required this.walletId,
    this.walletName = 'Personal',
    this.walletEmoji = '🎊',
    this.openAdd = false,
    this.initialTab = 0,
    this.parentFunctions,
    this.familyWalletNames = const {},
    this.members = const [],
  });
  @override
  State<MyFunctionsScreen> createState() => _MyFunctionsScreenState();
}

class _MyFunctionsScreenState extends State<MyFunctionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _loading = true;
  final List<FunctionModel> _functions = [];
  final List<AttendedFunction> _attended = [];
  final List<UpcomingFunction> _upcoming = [];
  final _attendedSearchCtrl = TextEditingController();
  String _attendedSearch = '';

  // All data is scoped to walletId — no client-side filter needed,
  // but keep getters so the rest of the UI code stays unchanged.
  List<FunctionModel> get _myFuncs => _functions;
  List<AttendedFunction> get _myAttended => _attended;
  List<UpcomingFunction> get _myUpcoming => _upcoming;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadData();
    if (widget.openAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
        _showAdd(context, isDark, surfBg);
      });
    }
  }

  Future<void> _loadData() async {
    // Personal view: functions_my from all wallets; upcoming+attended from personal wallet only.
    if (widget.familyWalletNames.isNotEmpty) {
      final allIds = [widget.walletId, ...widget.familyWalletNames.keys];
      final svc = FunctionsService.instance;
      final rawMyResults = await Future.wait(
        allIds.map(
          (id) => svc.fetchMyFunctions(id).catchError((e) {
            debugPrint('[MyFunctions] fetch error for wallet $id: $e');
            return <Map<String, dynamic>>[];
          }),
        ),
      );
      final rawUpcoming = await svc.fetchUpcoming(widget.walletId).catchError((
        e,
      ) {
        debugPrint('[MyFunctions] fetch upcoming error: $e');
        return <Map<String, dynamic>>[];
      });
      final rawAttended = await svc.fetchAttended(widget.walletId).catchError((
        e,
      ) {
        debugPrint('[MyFunctions] fetch attended error: $e');
        return <Map<String, dynamic>>[];
      });
      if (!mounted) return;

      final loaded = <FunctionModel>[];
      for (final row in rawMyResults.expand((r) => r)) {
        try {
          loaded.add(FunctionModel.fromJson(row));
        } catch (e) {
          debugPrint('[MyFunctions] parse error: $e | row: $row');
        }
      }
      final upcoming = <UpcomingFunction>[];
      for (final row in rawUpcoming) {
        try {
          upcoming.add(UpcomingFunction.fromJson(row));
        } catch (e) {
          debugPrint('[MyFunctions] upcoming parse error: $e | row: $row');
        }
      }
      final attended = <AttendedFunction>[];
      for (final row in rawAttended) {
        try {
          attended.add(AttendedFunction.fromJson(row));
        } catch (e) {
          debugPrint('[MyFunctions] attended parse error: $e | row: $row');
        }
      }

      widget.parentFunctions
        ?..clear()
        ..addAll(loaded);
      setState(() {
        _functions
          ..clear()
          ..addAll(loaded);
        _upcoming
          ..clear()
          ..addAll(upcoming);
        _attended
          ..clear()
          ..addAll(attended);
        _loading = false;
      });
      return;
    }

    List<Map<String, dynamic>> rawFunctions = [];
    List<Map<String, dynamic>> rawUpcoming = [];
    List<Map<String, dynamic>> rawAttended = [];
    try {
      final svc = FunctionsService.instance;
      final results = await Future.wait([
        svc.fetchMyFunctions(widget.walletId),
        svc.fetchUpcoming(widget.walletId),
        svc.fetchAttended(widget.walletId),
      ]);
      rawFunctions = results[0];
      rawUpcoming = results[1];
      rawAttended = results[2];
    } catch (e) {
      debugPrint('[MyFunctions] fetch error: $e');
    }
    if (!mounted) return;

    // Parse each list independently — a failure in one must not block others.
    final functions = <FunctionModel>[];
    for (final row in rawFunctions) {
      try {
        functions.add(FunctionModel.fromJson(row));
      } catch (e) {
        debugPrint('[MyFunctions] functions parse error: $e | row: $row');
      }
    }
    final upcoming = <UpcomingFunction>[];
    for (final row in rawUpcoming) {
      try {
        upcoming.add(UpcomingFunction.fromJson(row));
      } catch (e) {
        debugPrint('[MyFunctions] upcoming parse error: $e | row: $row');
      }
    }
    final attended = <AttendedFunction>[];
    for (final row in rawAttended) {
      try {
        attended.add(AttendedFunction.fromJson(row));
      } catch (e) {
        debugPrint('[MyFunctions] attended parse error: $e | row: $row');
      }
    }

    setState(() {
      _functions
        ..clear()
        ..addAll(functions);
      _upcoming
        ..clear()
        ..addAll(upcoming);
      _attended
        ..clear()
        ..addAll(attended);
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _attendedSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Text('🎊', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            const Text(
              'Functions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
              ),
            ),
          ],
        ),
        actions: [
          if (widget.walletName != 'Personal')
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              constraints: const BoxConstraints(maxWidth: 110),
              decoration: BoxDecoration(
                color: _funcColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.walletEmoji,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      widget.walletName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito',
                        color: _funcColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
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
          tabs: [
            Tab(text: 'Our Functions (${_myFuncs.length})'),
            Tab(text: 'Upcoming (${_myUpcoming.length})'),
            Tab(text: 'Attended (${_myAttended.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAdd(context, isDark, surfBg),
        backgroundColor: _funcColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
            color: Colors.white,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _funcColor))
          : TabBarView(
              controller: _tab,
              children: [
                // OUR FUNCTIONS tab (index 0)
                _myFuncs.isEmpty
                    ? const PlanEmptyState(
                        emoji: '🎊',
                        title: 'No functions yet',
                        subtitle: 'Record your family celebrations',
                      )
                    : _GroupedFunctionsList(
                        functions: _myFuncs,
                        isDark: isDark,
                        familyWalletNames: widget.familyWalletNames,
                        onDelete: (fn) {
                          HapticFeedback.mediumImpact();
                          setState(() => _functions.remove(fn));
                          FunctionsService.instance.deleteMyFunction(fn.id);
                        },
                        onTap: (fn) {
                          if (widget.familyWalletNames[fn.walletId] == null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => fn.isPlanned
                                    ? _PlannedFunctionDetail(
                                        fn: fn,
                                        isDark: isDark,
                                        onUpdate: () => setState(() {
                                          _functions.removeWhere(
                                            (f) => f.walletId != widget.walletId,
                                          );
                                        }),
                                        familyWalletNames: widget.familyWalletNames,
                                      )
                                    : _FunctionDetail(
                                        fn: fn,
                                        isDark: isDark,
                                        onUpdate: () => setState(() {
                                          _functions.removeWhere(
                                            (f) => f.walletId != widget.walletId,
                                          );
                                        }),
                                        familyWalletNames: widget.familyWalletNames,
                                      ),
                              ),
                            );
                          }
                        },
                      ),

                // UPCOMING tab (index 1)
                _myUpcoming.isEmpty
                    ? const PlanEmptyState(
                        emoji: '📅',
                        title: 'No upcoming functions',
                        subtitle: 'Plan for functions you\'re attending',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: _myUpcoming.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: SwipeTile(
                            onDelete: () {
                              HapticFeedback.mediumImpact();
                              final item = _myUpcoming[i];
                              setState(() => _upcoming.remove(item));
                              FunctionsService.instance.deleteUpcoming(item.id);
                            },
                            child: _UpcomingCard(
                              item: _myUpcoming[i],
                              isDark: isDark,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _UpcomingDetail(
                                    item: _myUpcoming[i],
                                    isDark: isDark,
                                    members: widget.members,
                                    onUpdate: () => setState(() {}),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                // ATTENDED tab (index 2)
                Builder(
                  builder: (context) {
                    final q = _attendedSearch.toLowerCase();
                    final filtered = _myAttended.where((a) {
                      if (q.isEmpty) return true;
                      return a.functionName.toLowerCase().contains(q) ||
                          (a.venue?.toLowerCase().contains(q) ?? false) ||
                          a.type.label.toLowerCase().contains(q) ||
                          a.gifts.any(
                            (g) => g.category.toLowerCase().contains(q),
                          );
                    }).toList();
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: surfBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _attendedSearchCtrl,
                              onChanged: (v) =>
                                  setState(() => _attendedSearch = v.trim()),
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'Nunito',
                                color: isDark
                                    ? AppColors.textDark
                                    : AppColors.textLight,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    'Search by name, venue, type, gift...',
                                hintStyle: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Nunito',
                                  color: isDark
                                      ? AppColors.subDark
                                      : AppColors.subLight,
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  size: 18,
                                  color: isDark
                                      ? AppColors.subDark
                                      : AppColors.subLight,
                                ),
                                suffixIcon: _attendedSearch.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                        ),
                                        onPressed: () => setState(() {
                                          _attendedSearch = '';
                                          _attendedSearchCtrl.clear();
                                        }),
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: filtered.isEmpty
                              ? PlanEmptyState(
                                  emoji: '✅',
                                  title: _attendedSearch.isNotEmpty
                                      ? 'No results for "$_attendedSearch"'
                                      : 'No attended functions recorded',
                                  subtitle: _attendedSearch.isNotEmpty
                                      ? 'Try a different search'
                                      : 'Track functions you\'ve attended and what you gave',
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    100,
                                  ),
                                  itemCount: filtered.length,
                                  itemBuilder: (_, i) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: SwipeTile(
                                      onDelete: () {
                                        HapticFeedback.mediumImpact();
                                        final item = filtered[i];
                                        setState(() => _attended.remove(item));
                                        FunctionsService.instance
                                            .deleteAttended(item.id);
                                      },
                                      child: _AttendedCard(
                                        item: filtered[i],
                                        isDark: isDark,
                                        onTap: () => _showEditAttended(
                                          context,
                                          isDark,
                                          surfBg,
                                          filtered[i],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }

  void _showAdd(BuildContext ctx, bool isDark, Color surfBg) {
    final tabIdx = _tab.index;
    showPlanSheet(
      ctx,
      child: _FunctionAddSheet(
        tabIdx: tabIdx,
        isDark: isDark,
        surfBg: surfBg,
        walletId: widget.walletId,
        upcomingList: _upcoming,
        onSave:
            (
              title,
              type,
              customType,
              venue,
              date,
              personName,
              familyName,
              isPlanned,
              icon,
            ) async {
              final svc = FunctionsService.instance;
              try {
                if (tabIdx == 0) {
                  final row = await svc.addMyFunction(
                    FunctionModel(
                      id: '',
                      walletId: widget.walletId,
                      type: type,
                      title: title,
                      whoFunction: '',
                      customType: customType,
                      functionDate: date,
                      venue: venue,
                      isPlanned: isPlanned,
                      icon: icon,
                    ).toJson(),
                  );
                  if (mounted)
                    setState(
                      () => _functions.insert(0, FunctionModel.fromJson(row)),
                    );
                } else if (tabIdx == 1) {
                  final row = await svc.addUpcoming(
                    UpcomingFunction(
                      id: '',
                      walletId: widget.walletId,
                      memberId: 'me',
                      type: type,
                      personName: personName ?? '',
                      familyName: familyName,
                      functionTitle: title,
                      date: date,
                      venue: venue,
                    ).toJson(),
                  );
                  if (mounted)
                    setState(
                      () => _upcoming.insert(0, UpcomingFunction.fromJson(row)),
                    );
                } else if (tabIdx == 2) {
                  final row = await svc.addAttended(
                    AttendedFunction(
                      id: '',
                      walletId: widget.walletId,
                      type: type,
                      functionName: title,
                      personName: personName,
                      familyName: familyName,
                      date: date,
                      venue: venue,
                    ).toJson(),
                  );
                  if (mounted)
                    setState(
                      () => _attended.insert(0, AttendedFunction.fromJson(row)),
                    );
                }
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                debugPrint('[Functions] save error: $e');
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Failed to save: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
      ),
    );
  }

  void _showEditAttended(
    BuildContext ctx,
    bool isDark,
    Color surfBg,
    AttendedFunction item,
  ) {
    final nameCtrl = TextEditingController(text: item.functionName);
    final personCtrl = TextEditingController(text: item.personName ?? '');
    final familyNameCtrl = TextEditingController(text: item.familyName ?? '');
    final venueCtrl = TextEditingController(text: item.venue ?? '');
    var type = item.type;
    DateTime? date = item.date;
    String? newCategory;
    final notesCtrl = TextEditingController();

    showPlanSheet(
      ctx,
      child: StatefulBuilder(
        builder: (sheetCtx, ss) {
          final sub = isDark ? AppColors.subDark : AppColors.subLight;
          final tc = isDark ? AppColors.textDark : AppColors.textLight;
          final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 36,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Edit Attended Function',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Nunito',
                  ),
                ),
                const SheetLabel(text: 'FUNCTION TYPE'),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: FunctionType.values
                        .map(
                          (t) => GestureDetector(
                            onTap: () => ss(() => type = t),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: type == t
                                    ? _funcColor.withValues(alpha: 0.15)
                                    : surfBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: type == t
                                      ? _funcColor
                                      : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    t.emoji,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    t.label,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Nunito',
                                      color: type == t ? _funcColor : sub,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
                PlanInputField(
                  controller: personCtrl,
                  hint: 'Person name (e.g. Priya)',
                ),
                const SizedBox(height: 8),
                PlanInputField(
                  controller: familyNameCtrl,
                  hint: 'Family name (e.g. Sharma family)',
                ),
                const SizedBox(height: 8),
                PlanInputField(controller: nameCtrl, hint: 'Function name *'),
                const SizedBox(height: 8),
                PlanInputField(controller: venueCtrl, hint: 'Venue / Location'),
                const SizedBox(height: 8),
                LifeDateTile(
                  date: date,
                  hint: 'Function date',
                  color: _funcColor,
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: date ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) ss(() => date = d);
                  },
                ),
                const SizedBox(height: 16),
                // ── What was given ──
                if (item.gifts.isNotEmpty) ...[
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
                  ...item.gifts.asMap().entries.map((e) {
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
                                Text(
                                  e.value.category,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Nunito',
                                    color: tc,
                                  ),
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
                            onTap: () => ss(() {
                              item.gifts.removeAt(e.key);
                              setState(() {});
                            }),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: sub,
                            ),
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
                    final sel = newCategory == c.$2;
                    return GestureDetector(
                      onTap: () => ss(() => newCategory = sel ? null : c.$2),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: sel
                              ? _funcColor.withValues(alpha: 0.12)
                              : surfBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel ? _funcColor : Colors.transparent,
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
                                color: sel ? _funcColor : sub,
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
                  controller: notesCtrl,
                  hint: 'Amount or notes (optional)',
                ),
                GestureDetector(
                  onTap: () {
                    if (newCategory == null) return;
                    ss(() {
                      item.gifts.add(
                        PlannedGiftItem(
                          category: newCategory!,
                          notes: notesCtrl.text.trim().isEmpty
                              ? null
                              : notesCtrl.text.trim(),
                        ),
                      );
                      newCategory = null;
                      notesCtrl.clear();
                      setState(() {});
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: newCategory != null
                          ? _funcColor.withValues(alpha: 0.1)
                          : surfBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: newCategory != null
                            ? _funcColor
                            : Colors.transparent,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '+ Add',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Nunito',
                        color: newCategory != null ? _funcColor : sub,
                      ),
                    ),
                  ),
                ),
                SaveButton(
                  label: 'Save Changes',
                  color: _funcColor,
                  onTap: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    setState(() {
                      item.functionName = nameCtrl.text.trim();
                      item.personName = personCtrl.text.trim().isEmpty
                          ? null
                          : personCtrl.text.trim();
                      item.familyName = familyNameCtrl.text.trim().isEmpty
                          ? null
                          : familyNameCtrl.text.trim();
                      item.type = type;
                      item.date = date;
                      item.venue = venueCtrl.text.trim().isEmpty
                          ? null
                          : venueCtrl.text.trim();
                    });
                    await FunctionsService.instance.updateAttended(
                      item.id,
                      item.toJson(),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Grouped functions list ────────────────────────────────────────────────────
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

// ── Planned function detail ───────────────────────────────────────────────────

class _PlannedFunctionDetail extends StatefulWidget {
  final FunctionModel fn;
  final bool isDark;
  final VoidCallback onUpdate;
  final Map<String, String> familyWalletNames;
  const _PlannedFunctionDetail({
    required this.fn,
    required this.isDark,
    required this.onUpdate,
    this.familyWalletNames = const {},
  });
  @override
  State<_PlannedFunctionDetail> createState() => _PlannedFunctionDetailState();
}

class _PlannedFunctionDetailState extends State<_PlannedFunctionDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  // Participants
  final List<FunctionParticipant> _participants = [];
  // Clothing families
  final List<ClothingFamily> _clothingFamilies = [];
  // Bridal essentials
  final List<BridalEssential> _bridals = [];
  // Return gifts
  final List<FunctionReturnGift> _returnGifts = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 7, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final svc = FunctionsService.instance;
    final id = widget.fn.id;
    try {
      final results = await Future.wait([
        svc.fetchParticipants(id),
        svc.fetchClothingFamilies(id),
        svc.fetchBridalEssentials(id),
        svc.fetchReturnGifts(id),
      ]);
      if (!mounted) return;
      setState(() {
        _participants
          ..clear()
          ..addAll(results[0].map((r) => FunctionParticipant.fromJson(r)));
        _clothingFamilies
          ..clear()
          ..addAll(results[1].map((r) => ClothingFamily.fromJson(r)));
        _bridals
          ..clear()
          ..addAll(results[2].map((r) => BridalEssential.fromJson(r)));
        _returnGifts
          ..clear()
          ..addAll(results[3].map((r) => FunctionReturnGift.fromJson(r)));
        _loading = false;
      });
    } catch (e) {
      debugPrint('[PlannedDetail] load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final fn = widget.fn;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        title: Text(
          fn.title,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            fontFamily: 'Nunito',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => _showEditPlanned(context, isDark, surfBg),
            tooltip: 'Edit Function',
          ),
        ],
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
          indicatorColor: AppColors.income,
          labelColor: AppColors.income,
          unselectedLabelColor: sub,
          tabs: const [
            Tab(text: 'Info'),
            Tab(text: 'Participants'),
            Tab(text: 'Clothing Gifts'),
            Tab(text: 'Bridal Essentials'),
            Tab(text: 'Return Gift'),
            Tab(text: 'Vendors'),
            Tab(text: 'Messages'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.income))
          : TabBarView(
              controller: _tab,
              children: [
                // INFO
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.income.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.income.withValues(alpha: 0.18)),
                        ),
                        child: Column(
                          children: [
                            _InfoDetailRow(
                              label: 'Function Type',
                              value: '${fn.type.emoji}  ${fn.type == FunctionType.other && fn.customType != null ? fn.customType! : fn.type.label}',
                              isDark: isDark,
                              tc: isDark ? AppColors.textDark : AppColors.textLight,
                              sub: isDark ? AppColors.subDark : AppColors.subLight,
                            ),
                            _InfoDetailRow(
                              label: 'Function Name',
                              value: fn.title,
                              isDark: isDark,
                              tc: isDark ? AppColors.textDark : AppColors.textLight,
                              sub: isDark ? AppColors.subDark : AppColors.subLight,
                            ),
                            if (fn.functionDate != null)
                              _InfoDetailRow(
                                label: 'Planned Date',
                                value: fmtDate(fn.functionDate!),
                                isDark: isDark,
                                tc: isDark ? AppColors.textDark : AppColors.textLight,
                                sub: isDark ? AppColors.subDark : AppColors.subLight,
                              ),
                            if (fn.venue != null)
                              _InfoDetailRow(
                                label: 'Venue',
                                value: fn.venue!,
                                isDark: isDark,
                                tc: isDark ? AppColors.textDark : AppColors.textLight,
                                sub: isDark ? AppColors.subDark : AppColors.subLight,
                                isLast: fn.address == null && fn.notes == null,
                              ),
                            if (fn.address != null)
                              _InfoDetailRow(
                                label: 'Address',
                                value: fn.address!,
                                isDark: isDark,
                                tc: isDark ? AppColors.textDark : AppColors.textLight,
                                sub: isDark ? AppColors.subDark : AppColors.subLight,
                                isLast: fn.notes == null,
                              ),
                            if (fn.notes != null)
                              _InfoDetailRow(
                                label: 'Notes',
                                value: fn.notes!,
                                isDark: isDark,
                                tc: isDark ? AppColors.textDark : AppColors.textLight,
                                sub: isDark ? AppColors.subDark : AppColors.subLight,
                                isLast: true,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _FuncStat(
                            label: 'Participants',
                            value: '${_participants.fold(0, (s, p) => s + p.totalCount)}',
                            emoji: '👥',
                            color: AppColors.income,
                          ),
                          const SizedBox(width: 10),
                          _FuncStat(
                            label: 'Clothing',
                            value: '${_clothingFamilies.fold(0, (s, f) => s + f.members.length)}',
                            emoji: '👗',
                            color: _funcColor,
                          ),
                          const SizedBox(width: 10),
                          _FuncStat(
                            label: 'Return Gifts',
                            value: '${_returnGifts.length}',
                            emoji: '🎁',
                            color: AppColors.lend,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                _ParticipantsTab(
                  functionId: fn.id,
                  participants: _participants,
                  isDark: isDark,
                  surfBg: surfBg,
                  onChanged: () => setState(() {}),
                ),
                _ClothingGiftsTab(
                  functionId: fn.id,
                  families: _clothingFamilies,
                  isDark: isDark,
                  surfBg: surfBg,
                  onChanged: () => setState(() {}),
                ),
                _BridalEssentialsTab(
                  functionId: fn.id,
                  essentials: _bridals,
                  isDark: isDark,
                  surfBg: surfBg,
                  onChanged: () => setState(() {}),
                ),
                _ReturnGiftsTab(
                  functionId: fn.id,
                  gifts: _returnGifts,
                  isDark: isDark,
                  surfBg: surfBg,
                  onChanged: () => setState(() {}),
                ),

                // VENDORS
                _AllVendorsTab(
                  fn: fn,
                  isDark: isDark,
                  onAdd: () => _showAddVendorPlanned(context, isDark, surfBg, fn),
                  onEdit: (v) => _showEditVendorPlanned(context, isDark, surfBg, v),
                  onDelete: (v) => setState(() => fn.vendors.remove(v)),
                ),

                // MESSAGES
                Expanded(
                  child: ChatWidget(
                    messages: fn.chat,
                    isDark: isDark,
                    textOf: (m) => (m as FunctionChatMessage).text,
                    senderOf: (m) => (m as FunctionChatMessage).senderId,
                    onSend: (text) => setState(
                      () => fn.chat.add(
                        FunctionChatMessage(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          senderId: 'me',
                          text: text,
                          at: DateTime.now(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showAddVendorPlanned(BuildContext ctx, bool isDark, Color surfBg, FunctionModel fn) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final advanceCtrl = TextEditingController();
    final eventCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    var category = VendorCategory.catering;
    showPlanSheet(
      ctx,
      child: StatefulBuilder(
        builder: (sheetCtx, ss) {
          final sub = isDark ? AppColors.subDark : AppColors.subLight;
          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 8,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 36,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Add Vendor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
                const SizedBox(height: 14),
                const SheetLabel(text: 'VENDOR NAME'),
                PlanInputField(controller: nameCtrl, hint: 'e.g. Sri Krishna Catering'),
                const SizedBox(height: 12),
                const SheetLabel(text: 'CATEGORY'),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: VendorCategory.values.map((c) {
                      final sel = category == c;
                      return GestureDetector(
                        onTap: () => ss(() => category = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel ? _funcColor.withValues(alpha: 0.15) : surfBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? _funcColor : Colors.transparent),
                          ),
                          child: Text('${c.emoji} ${c.label}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: sel ? _funcColor : sub)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                const SheetLabel(text: 'CONTACT'),
                PlanInputField(controller: phoneCtrl, hint: 'Phone number', inputType: TextInputType.phone),
                const SizedBox(height: 8),
                PlanInputField(controller: emailCtrl, hint: 'Email (optional)', inputType: TextInputType.emailAddress),
                const SizedBox(height: 8),
                PlanInputField(controller: addressCtrl, hint: 'Address (optional)'),
                const SizedBox(height: 12),
                const SheetLabel(text: 'COST'),
                Row(children: [
                  Expanded(child: PlanInputField(controller: costCtrl, hint: 'Total cost (₹)', inputType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: PlanInputField(controller: advanceCtrl, hint: 'Advance paid (₹)', inputType: TextInputType.number)),
                ]),
                const SizedBox(height: 12),
                const SheetLabel(text: 'EVENT LINKED'),
                PlanInputField(controller: eventCtrl, hint: 'e.g. Wedding, Housewarming'),
                const SizedBox(height: 12),
                const SheetLabel(text: 'NOTES'),
                PlanInputField(controller: notesCtrl, hint: 'Invoice details, notes…', maxLines: 3),
                SaveButton(
                  label: 'Add Vendor',
                  color: _funcColor,
                  onTap: () {
                    if (nameCtrl.text.trim().isEmpty) return;
                    setState(() => fn.vendors.add(FunctionVendor(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameCtrl.text.trim(),
                      category: category,
                      phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                      email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                      address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                      totalCost: double.tryParse(costCtrl.text.trim()),
                      advancePaid: double.tryParse(advanceCtrl.text.trim()),
                      eventLinked: eventCtrl.text.trim().isEmpty ? null : eventCtrl.text.trim(),
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                    )));
                    Navigator.pop(sheetCtx);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditVendorPlanned(BuildContext ctx, bool isDark, Color surfBg, FunctionVendor v) {
    final nameCtrl = TextEditingController(text: v.name);
    final phoneCtrl = TextEditingController(text: v.phone ?? '');
    final emailCtrl = TextEditingController(text: v.email ?? '');
    final addressCtrl = TextEditingController(text: v.address ?? '');
    final costCtrl = TextEditingController(text: v.totalCost?.toStringAsFixed(0) ?? '');
    final advanceCtrl = TextEditingController(text: v.advancePaid?.toStringAsFixed(0) ?? '');
    final eventCtrl = TextEditingController(text: v.eventLinked ?? '');
    final notesCtrl = TextEditingController(text: v.notes ?? '');
    var category = v.category;
    showPlanSheet(
      ctx,
      child: StatefulBuilder(
        builder: (sheetCtx, ss) {
          final sub = isDark ? AppColors.subDark : AppColors.subLight;
          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 8,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 36,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Edit Vendor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
                const SizedBox(height: 14),
                const SheetLabel(text: 'VENDOR NAME'),
                PlanInputField(controller: nameCtrl, hint: 'e.g. Sri Krishna Catering'),
                const SizedBox(height: 12),
                const SheetLabel(text: 'CATEGORY'),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: VendorCategory.values.map((c) {
                      final sel = category == c;
                      return GestureDetector(
                        onTap: () => ss(() => category = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel ? _funcColor.withValues(alpha: 0.15) : surfBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? _funcColor : Colors.transparent),
                          ),
                          child: Text('${c.emoji} ${c.label}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: sel ? _funcColor : sub)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                const SheetLabel(text: 'CONTACT'),
                PlanInputField(controller: phoneCtrl, hint: 'Phone number', inputType: TextInputType.phone),
                const SizedBox(height: 8),
                PlanInputField(controller: emailCtrl, hint: 'Email (optional)', inputType: TextInputType.emailAddress),
                const SizedBox(height: 8),
                PlanInputField(controller: addressCtrl, hint: 'Address (optional)'),
                const SizedBox(height: 12),
                const SheetLabel(text: 'COST'),
                Row(children: [
                  Expanded(child: PlanInputField(controller: costCtrl, hint: 'Total cost (₹)', inputType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: PlanInputField(controller: advanceCtrl, hint: 'Advance paid (₹)', inputType: TextInputType.number)),
                ]),
                const SizedBox(height: 12),
                const SheetLabel(text: 'EVENT LINKED'),
                PlanInputField(controller: eventCtrl, hint: 'e.g. Wedding, Housewarming'),
                const SizedBox(height: 12),
                const SheetLabel(text: 'NOTES'),
                PlanInputField(controller: notesCtrl, hint: 'Invoice details, notes…', maxLines: 3),
                SaveButton(
                  label: 'Save Changes',
                  color: _funcColor,
                  onTap: () {
                    if (nameCtrl.text.trim().isEmpty) return;
                    setState(() {
                      v.name = nameCtrl.text.trim();
                      v.category = category;
                      v.phone = phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim();
                      v.email = emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim();
                      v.address = addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim();
                      v.totalCost = double.tryParse(costCtrl.text.trim());
                      v.advancePaid = double.tryParse(advanceCtrl.text.trim());
                      v.eventLinked = eventCtrl.text.trim().isEmpty ? null : eventCtrl.text.trim();
                      v.notes = notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim();
                    });
                    Navigator.pop(sheetCtx);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditPlanned(BuildContext ctx, bool isDark, Color surfBg) {
    final fn = widget.fn;
    final titleCtrl = TextEditingController(text: fn.title);
    final customTypeCtrl = TextEditingController(text: fn.customType ?? '');
    final venueCtrl = TextEditingController(text: fn.venue ?? '');
    final notesCtrl = TextEditingController(text: fn.notes ?? '');
    DateTime? date = fn.functionDate;
    var type = fn.type;
    String? selectedWalletId;
    String icon = fn.icon;
    String? photoPath;

    final familyEntries = widget.familyWalletNames.entries.toList();

    showPlanSheet(
      ctx,
      child: StatefulBuilder(
        builder: (ctx2, ss) {
          final sub = isDark ? AppColors.subDark : AppColors.subLight;

          void pickIcon() {
            showModalBottomSheet(
              context: ctx2,
              backgroundColor: Colors.transparent,
              builder: (_) => StatefulBuilder(
                builder: (ctx3, setS3) => Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Choose Icon', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'Nunito')),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                Navigator.pop(ctx3);
                                final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
                                if (picked != null) ss(() => photoPath = picked.path);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(color: surfBg, borderRadius: BorderRadius.circular(12)),
                                child: const Column(children: [
                                  Icon(Icons.photo_library_rounded, size: 24, color: AppColors.income),
                                  SizedBox(height: 4),
                                  Text('Gallery', style: TextStyle(fontSize: 12, fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
                                ]),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                Navigator.pop(ctx3);
                                final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
                                if (picked != null) ss(() => photoPath = picked.path);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(color: surfBg, borderRadius: BorderRadius.circular(12)),
                                child: const Column(children: [
                                  Icon(Icons.camera_alt_rounded, size: 24, color: AppColors.income),
                                  SizedBox(height: 4),
                                  Text('Camera', style: TextStyle(fontSize: 12, fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
                                ]),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _fnIconEmojis.map((e) {
                          final selected = photoPath == null && icon == e;
                          return GestureDetector(
                            onTap: () {
                              ss(() { icon = e; photoPath = null; });
                              Navigator.pop(ctx3);
                            },
                            child: Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: selected ? AppColors.income.withValues(alpha: 0.15) : surfBg,
                                borderRadius: BorderRadius.circular(10),
                                border: selected ? Border.all(color: AppColors.income, width: 1.5) : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(e, style: const TextStyle(fontSize: 22)),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 8,
              bottom: MediaQuery.of(ctx2).viewInsets.bottom + 36,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Edit Function', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
                const SizedBox(height: 12),
                const SheetLabel(text: 'GROUP ICON'),
                GestureDetector(
                  onTap: pickIcon,
                  child: Row(
                    children: [
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.income.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.income.withValues(alpha: 0.3)),
                        ),
                        alignment: Alignment.center,
                        child: EmojiOrImage(value: photoPath ?? icon, size: 30),
                      ),
                      const SizedBox(width: 12),
                      Text('Tap to change icon', style: TextStyle(fontSize: 13, fontFamily: 'Nunito', fontWeight: FontWeight.w600, color: sub)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const SheetLabel(text: 'FUNCTION TYPE'),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: FunctionType.values.map((t) => GestureDetector(
                      onTap: () => ss(() => type = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: type == t ? AppColors.income.withValues(alpha: 0.15) : surfBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: type == t ? AppColors.income : Colors.transparent),
                        ),
                        child: Row(children: [
                          Text(t.emoji, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 5),
                          Text(t.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: type == t ? AppColors.income : sub)),
                        ]),
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                PlanInputField(controller: titleCtrl, hint: 'Function title *'),
                if (type == FunctionType.other) ...[
                  const SizedBox(height: 8),
                  PlanInputField(controller: customTypeCtrl, hint: 'Enter function type'),
                ],
                const SizedBox(height: 8),
                PlanInputField(controller: venueCtrl, hint: 'Venue / Location'),
                const SizedBox(height: 8),
                PlanInputField(controller: notesCtrl, hint: 'Notes'),
                const SizedBox(height: 8),
                LifeDateTile(
                  date: date,
                  hint: 'Function date',
                  color: AppColors.income,
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: date ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) ss(() => date = d);
                  },
                ),
                if (familyEntries.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const SheetLabel(text: 'MOVE TO GROUP'),
                  Wrap(
                    spacing: 8,
                    children: [
                      GestureDetector(
                        onTap: () => ss(() => selectedWalletId = null),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: selectedWalletId == null ? AppColors.income.withValues(alpha: 0.15) : surfBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: selectedWalletId == null ? AppColors.income : Colors.transparent),
                          ),
                          child: Text('Personal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: selectedWalletId == null ? AppColors.income : sub)),
                        ),
                      ),
                      ...familyEntries.map((e) => GestureDetector(
                        onTap: () => ss(() => selectedWalletId = e.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: selectedWalletId == e.key ? AppColors.income.withValues(alpha: 0.15) : surfBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: selectedWalletId == e.key ? AppColors.income : Colors.transparent),
                          ),
                          child: Text(e.value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: selectedWalletId == e.key ? AppColors.income : sub)),
                        ),
                      )),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                SaveButton(
                  label: 'Save Changes',
                  color: AppColors.income,
                  onTap: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    String finalIcon = icon;
                    if (photoPath != null) {
                      try {
                        finalIcon = await ProfileService.instance.uploadPhoto(
                          localPath: photoPath!,
                          folder: 'functions',
                          name: 'fn_${fn.id}',
                        );
                      } catch (e) {
                        debugPrint('[Functions] icon upload error: $e');
                      }
                    }
                    setState(() {
                      fn.type = type;
                      fn.title = titleCtrl.text.trim();
                      fn.customType = type == FunctionType.other && customTypeCtrl.text.trim().isNotEmpty ? customTypeCtrl.text.trim() : null;
                      fn.functionDate = date;
                      fn.venue = venueCtrl.text.trim().isEmpty ? null : venueCtrl.text.trim();
                      fn.notes = notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim();
                      fn.icon = finalIcon;
                      if (selectedWalletId != null) fn.walletId = selectedWalletId!;
                    });
                    await FunctionsService.instance.updateMyFunction(fn.id, fn.toJson());
                    widget.onUpdate();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Participants tab ──────────────────────────────────────────────────────────

class _ParticipantsTab extends StatelessWidget {
  final String functionId;
  final List<FunctionParticipant> participants;
  final bool isDark;
  final Color surfBg;
  final VoidCallback onChanged;

  const _ParticipantsTab({
    required this.functionId,
    required this.participants,
    required this.isDark,
    required this.surfBg,
    required this.onChanged,
  });

  void _showAddEdit(BuildContext ctx, {FunctionParticipant? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final placeCtrl = TextEditingController(text: existing?.place ?? '');
    final relationCtrl = TextEditingController(text: existing?.relation ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final List<ParticipantFamilyMember> familyMembers =
        existing?.familyMembers.map((m) => ParticipantFamilyMember(name: m.name, relation: m.relation)).toList() ?? [];

    final svc = FunctionsService.instance;

    showPlanSheet(
      ctx,
      child: StatefulBuilder(builder: (sheetCtx, ss) {
        final sub = isDark ? AppColors.subDark : AppColors.subLight;
        final tc = isDark ? AppColors.textDark : AppColors.textLight;
        return Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 8,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 36,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                existing == null ? 'Add Participant' : 'Edit Participant',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito'),
              ),
              const SizedBox(height: 12),
              const SheetLabel(text: 'NAME *'),
              PlanInputField(controller: nameCtrl, hint: 'Participant name'),
              const SizedBox(height: 8),
              const SheetLabel(text: 'RELATION'),
              PlanInputField(controller: relationCtrl, hint: 'e.g. Uncle, Friend, Colleague'),
              const SizedBox(height: 8),
              const SheetLabel(text: 'PLACE'),
              PlanInputField(controller: placeCtrl, hint: 'City / Town'),
              const SizedBox(height: 8),
              const SheetLabel(text: 'PHONE'),
              PlanInputField(controller: phoneCtrl, hint: 'Phone number', inputType: TextInputType.phone),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('FAMILY MEMBERS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: sub, letterSpacing: 0.5)),
                  GestureDetector(
                    onTap: () => ss(() => familyMembers.add(ParticipantFamilyMember(name: '', relation: ''))),
                    child: const Icon(Icons.add_circle_outline_rounded, size: 20, color: AppColors.income),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (familyMembers.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('No family members added', style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub)),
                ),
              ...familyMembers.asMap().entries.map((entry) {
                final i = entry.key;
                final m = entry.value;
                final mNameCtrl = TextEditingController(text: m.name);
                final mRelCtrl = TextEditingController(text: m.relation);
                mNameCtrl.addListener(() => m.name = mNameCtrl.text);
                mRelCtrl.addListener(() => m.relation = mRelCtrl.text);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: surfBg, borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            children: [
                              TextField(
                                controller: mNameCtrl,
                                style: TextStyle(fontSize: 13, color: tc, fontFamily: 'Nunito'),
                                decoration: InputDecoration.collapsed(hintText: 'Name', hintStyle: TextStyle(fontSize: 12, color: sub, fontFamily: 'Nunito')),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: mRelCtrl,
                                style: TextStyle(fontSize: 12, color: sub, fontFamily: 'Nunito'),
                                decoration: InputDecoration.collapsed(hintText: 'Relation (e.g. Wife, Son)', hintStyle: TextStyle(fontSize: 11, color: sub, fontFamily: 'Nunito')),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded, size: 18, color: AppColors.expense),
                        onPressed: () => ss(() => familyMembers.removeAt(i)),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              SaveButton(
                label: existing == null ? 'Add Participant' : 'Save Changes',
                color: AppColors.income,
                onTap: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final data = FunctionParticipant(
                    id: existing?.id ?? '',
                    functionId: functionId,
                    name: name,
                    place: placeCtrl.text.trim().isEmpty ? null : placeCtrl.text.trim(),
                    relation: relationCtrl.text.trim().isEmpty ? null : relationCtrl.text.trim(),
                    phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                    familyMembers: familyMembers.where((m) => m.name.isNotEmpty).toList(),
                  );
                  try {
                    if (existing == null) {
                      final row = await svc.addParticipant(data.toJson());
                      participants.insert(0, FunctionParticipant.fromJson(row));
                    } else {
                      await svc.updateParticipant(existing.id, {
                        ...data.toJson(),
                        'family_members': data.familyMembers.map((m) => m.toJson()).toList(),
                      });
                      final idx = participants.indexOf(existing);
                      if (idx >= 0) participants[idx] = FunctionParticipant.fromJson({...data.toJson(), 'id': existing.id, 'function_id': functionId});
                    }
                    onChanged();
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  } catch (e) {
                    if (sheetCtx.mounted) ScaffoldMessenger.of(sheetCtx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                },
              ),
            ],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = this.isDark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final totalPeople = participants.fold(0, (s, p) => s + p.totalCount);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEdit(context),
        backgroundColor: AppColors.income,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Add', style: TextStyle(color: Colors.white, fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
      ),
      body: participants.isEmpty
          ? const PlanEmptyState(emoji: '👥', title: 'No participants yet', subtitle: 'Add people you plan to invite')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.income.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.income.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Text('👥', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$totalPeople total people', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'Nunito', color: tc)),
                          Text('${participants.length} families / groups', style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub)),
                        ],
                      ),
                    ],
                  ),
                ),
                ...participants.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SwipeTile(
                    onDelete: () async {
                      await FunctionsService.instance.deleteParticipant(p.id);
                      participants.remove(p);
                      onChanged();
                    },
                    child: GestureDetector(
                      onTap: () => _showAddEdit(context, existing: p),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('👤', style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: tc)),
                                      if (p.relation != null || p.place != null)
                                        Text(
                                          [if (p.relation != null) p.relation!, if (p.place != null) p.place!].join(' • '),
                                          style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub),
                                        ),
                                    ],
                                  ),
                                ),
                                if (p.phone != null)
                                  Icon(Icons.phone_rounded, size: 14, color: sub),
                                if (p.familyMembers.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.income.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('+${p.familyMembers.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: AppColors.income)),
                                  ),
                              ],
                            ),
                            if (p.familyMembers.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: p.familyMembers.map((m) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: surfBg, borderRadius: BorderRadius.circular(8)),
                                  child: Text('${m.name} (${m.relation})', style: TextStyle(fontSize: 10, fontFamily: 'Nunito', color: sub)),
                                )).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                )),
              ],
            ),
    );
  }
}

// ── Clothing gifts tab ────────────────────────────────────────────────────────

class _ClothingGiftsTab extends StatelessWidget {
  final String functionId;
  final List<ClothingFamily> families;
  final bool isDark;
  final Color surfBg;
  final VoidCallback onChanged;

  const _ClothingGiftsTab({
    required this.functionId,
    required this.families,
    required this.isDark,
    required this.surfBg,
    required this.onChanged,
  });

  void _showAddFamily(BuildContext ctx, {ClothingFamily? existing}) {
    final nameCtrl = TextEditingController(text: existing?.familyName ?? '');
    final List<ClothingMember> members = existing?.members
        .map((m) => ClothingMember(name: m.name, gender: m.gender, dressType: m.dressType, size: m.size, brand: m.brand, budget: m.budget, purchased: m.purchased))
        .toList() ?? [];
    final svc = FunctionsService.instance;

    showPlanSheet(ctx, child: StatefulBuilder(builder: (sheetCtx, ss) {
      final sub = isDark ? AppColors.subDark : AppColors.subLight;
      final tc = isDark ? AppColors.textDark : AppColors.textLight;
      return Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              existing == null ? 'Add Family' : 'Edit Family',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito'),
            ),
            const SizedBox(height: 12),
            const SheetLabel(text: 'FAMILY NAME *'),
            PlanInputField(controller: nameCtrl, hint: 'e.g. Sharma Family, Uncle\'s Family'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('MEMBERS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: sub, letterSpacing: 0.5)),
                GestureDetector(
                  onTap: () => ss(() => members.add(ClothingMember(name: '', gender: FunctionClothingGender.men))),
                  child: const Icon(Icons.add_circle_outline_rounded, size: 20, color: _funcColor),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (members.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Add members to assign clothing', style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub)),
              ),
            ...members.asMap().entries.map((entry) {
              final i = entry.key;
              final m = entry.value;
              final mNameCtrl = TextEditingController(text: m.name);
              final mDressCtrl = TextEditingController(text: m.dressType ?? '');
              final mSizeCtrl = TextEditingController(text: m.size ?? '');
              final mBrandCtrl = TextEditingController(text: m.brand ?? '');
              final mBudgetCtrl = TextEditingController(text: m.budget?.toString() ?? '');
              mNameCtrl.addListener(() => m.name = mNameCtrl.text);
              mDressCtrl.addListener(() => m.dressType = mDressCtrl.text.isEmpty ? null : mDressCtrl.text);
              mSizeCtrl.addListener(() => m.size = mSizeCtrl.text.isEmpty ? null : mSizeCtrl.text);
              mBrandCtrl.addListener(() => m.brand = mBrandCtrl.text.isEmpty ? null : mBrandCtrl.text);
              mBudgetCtrl.addListener(() => m.budget = double.tryParse(mBudgetCtrl.text));
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: surfBg, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: mNameCtrl,
                            style: TextStyle(fontSize: 13, color: tc, fontFamily: 'Nunito', fontWeight: FontWeight.w700),
                            decoration: InputDecoration.collapsed(hintText: 'Member name *', hintStyle: TextStyle(fontSize: 12, color: sub, fontFamily: 'Nunito')),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded, size: 18, color: AppColors.expense),
                          onPressed: () => ss(() => members.removeAt(i)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: FunctionClothingGender.values.map((g) => GestureDetector(
                          onTap: () => ss(() => m.gender = g),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: m.gender == g ? _funcColor.withValues(alpha: 0.15) : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: m.gender == g ? _funcColor : sub.withValues(alpha: 0.3)),
                            ),
                            child: Text('${g.emoji} ${g.label}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: m.gender == g ? _funcColor : sub)),
                          ),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: TextField(controller: mDressCtrl, style: TextStyle(fontSize: 12, color: tc, fontFamily: 'Nunito'), decoration: InputDecoration.collapsed(hintText: 'Dress type (Saree, Shirt…)', hintStyle: TextStyle(fontSize: 11, color: sub, fontFamily: 'Nunito')))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: mSizeCtrl, style: TextStyle(fontSize: 12, color: tc, fontFamily: 'Nunito'), decoration: InputDecoration.collapsed(hintText: 'Size (M, L, 38…)', hintStyle: TextStyle(fontSize: 11, color: sub, fontFamily: 'Nunito')))),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: TextField(controller: mBrandCtrl, style: TextStyle(fontSize: 12, color: tc, fontFamily: 'Nunito'), decoration: InputDecoration.collapsed(hintText: 'Brand preference', hintStyle: TextStyle(fontSize: 11, color: sub, fontFamily: 'Nunito')))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: mBudgetCtrl, keyboardType: TextInputType.number, style: TextStyle(fontSize: 12, color: tc, fontFamily: 'Nunito'), decoration: InputDecoration.collapsed(hintText: '₹ Budget', hintStyle: TextStyle(fontSize: 11, color: sub, fontFamily: 'Nunito')))),
                    ]),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => ss(() => m.purchased = !m.purchased),
                      child: Row(children: [
                        Icon(m.purchased ? Icons.check_circle_rounded : Icons.circle_outlined, size: 16, color: m.purchased ? AppColors.income : sub),
                        const SizedBox(width: 6),
                        Text('Purchased', style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: m.purchased ? AppColors.income : sub)),
                      ]),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            SaveButton(
              label: existing == null ? 'Add Family' : 'Save Changes',
              color: _funcColor,
              onTap: () async {
                final familyName = nameCtrl.text.trim();
                if (familyName.isEmpty) return;
                final cf = ClothingFamily(
                  id: existing?.id ?? '',
                  functionId: functionId,
                  familyName: familyName,
                  members: members.where((m) => m.name.isNotEmpty).toList(),
                );
                try {
                  if (existing == null) {
                    final row = await svc.addClothingFamily(cf.toJson());
                    families.insert(0, ClothingFamily.fromJson(row));
                  } else {
                    await svc.updateClothingFamily(existing.id, cf.toJson());
                    final idx = families.indexOf(existing);
                    if (idx >= 0) {
                      families[idx] = ClothingFamily(id: existing.id, functionId: functionId, familyName: familyName, members: cf.members);
                    }
                  }
                  onChanged();
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                } catch (e) {
                  if (sheetCtx.mounted) ScaffoldMessenger.of(sheetCtx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              },
            ),
          ],
        ),
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final totalBudget = families.fold(0.0, (s, f) => s + f.totalBudget);
    final totalMembers = families.fold(0, (s, f) => s + f.members.length);
    final totalPurchased = families.fold(0, (s, f) => s + f.purchasedCount);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddFamily(context),
        backgroundColor: _funcColor,
        icon: const Icon(Icons.group_add_rounded, color: Colors.white),
        label: const Text('Add Family', style: TextStyle(color: Colors.white, fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
      ),
      body: families.isEmpty
          ? const PlanEmptyState(emoji: '👗', title: 'No clothing planned', subtitle: 'Add families and assign clothing gifts')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: _funcColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _funcColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Text('👗', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$totalMembers members across ${families.length} families', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: tc)),
                            Text('$totalPurchased purchased • ₹${totalBudget.toStringAsFixed(0)} total budget', style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ...families.map((family) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: SwipeTile(
                    onDelete: () async {
                      await FunctionsService.instance.deleteClothingFamily(family.id);
                      families.remove(family);
                      onChanged();
                    },
                    child: GestureDetector(
                      onTap: () => _showAddFamily(context, existing: family),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(family.familyName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: tc))),
                                if (family.totalBudget > 0)
                                  Text('₹${family.totalBudget.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: AppColors.income)),
                              ],
                            ),
                            if (family.members.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              ...family.members.map((m) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Text(m.gender.emoji, style: const TextStyle(fontSize: 14)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(m.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: tc)),
                                          Text(
                                            [
                                              m.gender.label,
                                              if (m.dressType != null) m.dressType!,
                                              if (m.size != null) 'Size: ${m.size}',
                                              if (m.brand != null) m.brand!,
                                            ].join(' • '),
                                            style: TextStyle(fontSize: 10, fontFamily: 'Nunito', color: sub),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (m.budget != null)
                                      Text('₹${m.budget!.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub)),
                                    const SizedBox(width: 6),
                                    Icon(
                                      m.purchased ? Icons.check_circle_rounded : Icons.circle_outlined,
                                      size: 16,
                                      color: m.purchased ? AppColors.income : sub,
                                    ),
                                  ],
                                ),
                              )),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                )),
              ],
            ),
    );
  }
}

// ── Bridal essentials tab ─────────────────────────────────────────────────────

class _BridalEssentialsTab extends StatelessWidget {
  final String functionId;
  final List<BridalEssential> essentials;
  final bool isDark;
  final Color surfBg;
  final VoidCallback onChanged;

  const _BridalEssentialsTab({
    required this.functionId,
    required this.essentials,
    required this.isDark,
    required this.surfBg,
    required this.onChanged,
  });

  static const _categories = ['Dress', 'Makeup', 'Jewellery', 'Footwear', 'Hair', 'Mehendi', 'Photography', 'Other'];

  void _showAddEdit(BuildContext ctx, {BridalEssential? existing}) {
    final itemCtrl = TextEditingController(text: existing?.item ?? '');
    final detailsCtrl = TextEditingController(text: existing?.details ?? '');
    final vendorCtrl = TextEditingController(text: existing?.vendor ?? '');
    final costCtrl = TextEditingController(text: existing?.cost?.toString() ?? '');
    String? category = existing?.category ?? _categories[0];
    BridalStatus status = existing?.status ?? BridalStatus.pending;
    final svc = FunctionsService.instance;

    showPlanSheet(ctx, child: StatefulBuilder(builder: (sheetCtx, ss) {
      final sub = isDark ? AppColors.subDark : AppColors.subLight;
      return Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(existing == null ? 'Add Bridal Essential' : 'Edit Essential',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
            const SizedBox(height: 12),
            const SheetLabel(text: 'CATEGORY'),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _categories.map((c) => GestureDetector(
                  onTap: () => ss(() => category = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: category == c ? AppColors.lend.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: category == c ? AppColors.lend : sub.withValues(alpha: 0.3)),
                    ),
                    child: Text(c, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: category == c ? AppColors.lend : sub)),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 8),
            const SheetLabel(text: 'ITEM *'),
            PlanInputField(controller: itemCtrl, hint: 'e.g. Bridal lehenga, Foundation kit'),
            const SizedBox(height: 8),
            const SheetLabel(text: 'DETAILS'),
            PlanInputField(controller: detailsCtrl, hint: 'Color, style, notes…', maxLines: 2),
            const SizedBox(height: 8),
            const SheetLabel(text: 'VENDOR / SHOP'),
            PlanInputField(controller: vendorCtrl, hint: 'Vendor or shop name'),
            const SizedBox(height: 8),
            const SheetLabel(text: 'COST (₹)'),
            PlanInputField(controller: costCtrl, hint: 'Estimated cost', inputType: TextInputType.number),
            const SizedBox(height: 12),
            const SheetLabel(text: 'STATUS'),
            Row(children: BridalStatus.values.map((s) => GestureDetector(
              onTap: () => ss(() => status = s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: status == s ? AppColors.income.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: status == s ? AppColors.income : sub.withValues(alpha: 0.3)),
                ),
                child: Text('${s.emoji} ${s.label}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Nunito', color: status == s ? AppColors.income : sub)),
              ),
            )).toList()),
            const SizedBox(height: 8),
            SaveButton(
              label: existing == null ? 'Add Item' : 'Save Changes',
              color: AppColors.lend,
              onTap: () async {
                final item = itemCtrl.text.trim();
                if (item.isEmpty) return;
                final data = BridalEssential(
                  id: existing?.id ?? '',
                  functionId: functionId,
                  item: item,
                  category: category,
                  details: detailsCtrl.text.trim().isEmpty ? null : detailsCtrl.text.trim(),
                  vendor: vendorCtrl.text.trim().isEmpty ? null : vendorCtrl.text.trim(),
                  status: status,
                  cost: double.tryParse(costCtrl.text),
                );
                try {
                  if (existing == null) {
                    final row = await svc.addBridalEssential(data.toJson());
                    essentials.add(BridalEssential.fromJson(row));
                  } else {
                    await svc.updateBridalEssential(existing.id, data.toJson());
                    final idx = essentials.indexOf(existing);
                    if (idx >= 0) essentials[idx] = BridalEssential.fromJson({...data.toJson(), 'id': existing.id, 'function_id': functionId});
                  }
                  onChanged();
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                } catch (e) {
                  if (sheetCtx.mounted) ScaffoldMessenger.of(sheetCtx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              },
            ),
          ],
        ),
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final totalCost = essentials.fold(0.0, (s, e) => s + (e.cost ?? 0));
    final done = essentials.where((e) => e.status == BridalStatus.done).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEdit(context),
        backgroundColor: AppColors.lend,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Item', style: TextStyle(color: Colors.white, fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
      ),
      body: essentials.isEmpty
          ? const PlanEmptyState(emoji: '💍', title: 'No bridal essentials', subtitle: 'Track dresses, makeup, jewellery and more')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.lend.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.lend.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    const Text('💍', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${essentials.length} items • $done done', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: tc)),
                      Text('₹${totalCost.toStringAsFixed(0)} estimated', style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub)),
                    ])),
                  ]),
                ),
                ...essentials.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SwipeTile(
                    onDelete: () async {
                      await FunctionsService.instance.deleteBridalEssential(e.id);
                      essentials.remove(e);
                      onChanged();
                    },
                    child: GestureDetector(
                      onTap: () => _showAddEdit(context, existing: e),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.lend.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(e.status.emoji, style: const TextStyle(fontSize: 18)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  if (e.category != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: AppColors.lend.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                      child: Text(e.category!, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: AppColors.lend)),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Expanded(child: Text(e.item, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: tc), overflow: TextOverflow.ellipsis)),
                                ]),
                                if (e.details != null)
                                  Text(e.details!, style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub), maxLines: 1, overflow: TextOverflow.ellipsis),
                                if (e.vendor != null)
                                  Text('🏪 ${e.vendor}', style: TextStyle(fontSize: 10, fontFamily: 'Nunito', color: sub)),
                              ]),
                            ),
                            if (e.cost != null)
                              Text('₹${e.cost!.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: AppColors.income)),
                          ],
                        ),
                      ),
                    ),
                  ),
                )),
              ],
            ),
    );
  }
}

// ── Return gifts tab ──────────────────────────────────────────────────────────

class _ReturnGiftsTab extends StatelessWidget {
  final String functionId;
  final List<FunctionReturnGift> gifts;
  final bool isDark;
  final Color surfBg;
  final VoidCallback onChanged;

  const _ReturnGiftsTab({
    required this.functionId,
    required this.gifts,
    required this.isDark,
    required this.surfBg,
    required this.onChanged,
  });

  void _showAddEdit(BuildContext ctx, {FunctionReturnGift? existing}) {
    final nameCtrl = TextEditingController(text: existing?.giftName ?? '');
    final priceCtrl = TextEditingController(text: existing?.approxPrice?.toString() ?? '');
    final whereCtrl = TextEditingController(text: existing?.whereToBuy ?? '');
    final vendorCtrl = TextEditingController(text: existing?.vendor ?? '');
    final qtyCtrl = TextEditingController(text: existing?.quantity.toString() ?? '1');
    final svc = FunctionsService.instance;

    showPlanSheet(ctx, child: StatefulBuilder(builder: (sheetCtx, ss) {
      return Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(existing == null ? 'Add Return Gift' : 'Edit Return Gift',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
            const SizedBox(height: 12),
            const SheetLabel(text: 'GIFT NAME *'),
            PlanInputField(controller: nameCtrl, hint: 'e.g. Silk saree, Sweet box, Steel plate'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SheetLabel(text: 'APPROX PRICE (₹)'),
                PlanInputField(controller: priceCtrl, hint: '₹ per item', inputType: TextInputType.number),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SheetLabel(text: 'QUANTITY'),
                PlanInputField(controller: qtyCtrl, hint: 'How many', inputType: TextInputType.number),
              ])),
            ]),
            const SizedBox(height: 8),
            const SheetLabel(text: 'WHERE TO BUY'),
            PlanInputField(controller: whereCtrl, hint: 'Shop / Market / Online'),
            const SizedBox(height: 8),
            const SheetLabel(text: 'VENDOR'),
            PlanInputField(controller: vendorCtrl, hint: 'Vendor name / contact'),
            const SizedBox(height: 8),
            SaveButton(
              label: existing == null ? 'Add Gift' : 'Save Changes',
              color: _funcColor,
              onTap: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final data = FunctionReturnGift(
                  id: existing?.id ?? '',
                  functionId: functionId,
                  giftName: name,
                  approxPrice: double.tryParse(priceCtrl.text),
                  whereToBuy: whereCtrl.text.trim().isEmpty ? null : whereCtrl.text.trim(),
                  vendor: vendorCtrl.text.trim().isEmpty ? null : vendorCtrl.text.trim(),
                  quantity: int.tryParse(qtyCtrl.text) ?? 1,
                );
                try {
                  if (existing == null) {
                    final row = await svc.addReturnGift(data.toJson());
                    gifts.add(FunctionReturnGift.fromJson(row));
                  } else {
                    await svc.updateReturnGift(existing.id, data.toJson());
                    final idx = gifts.indexOf(existing);
                    if (idx >= 0) gifts[idx] = FunctionReturnGift.fromJson({...data.toJson(), 'id': existing.id, 'function_id': functionId});
                  }
                  onChanged();
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                } catch (e) {
                  if (sheetCtx.mounted) ScaffoldMessenger.of(sheetCtx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              },
            ),
          ],
        ),
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final totalCost = gifts.fold(0.0, (s, g) => s + g.totalCost);
    final totalQty = gifts.fold(0, (s, g) => s + g.quantity);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEdit(context),
        backgroundColor: _funcColor,
        icon: const Icon(Icons.card_giftcard_rounded, color: Colors.white),
        label: const Text('Add Gift', style: TextStyle(color: Colors.white, fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
      ),
      body: gifts.isEmpty
          ? const PlanEmptyState(emoji: '🎁', title: 'No return gifts planned', subtitle: 'Plan what gifts to give back to guests')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: _funcColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _funcColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    const Text('🎁', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${gifts.length} gift types • $totalQty total items', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: tc)),
                      Text('₹${totalCost.toStringAsFixed(0)} estimated total', style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub)),
                    ])),
                  ]),
                ),
                ...gifts.map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SwipeTile(
                    onDelete: () async {
                      await FunctionsService.instance.deleteReturnGift(g.id);
                      gifts.remove(g);
                      onChanged();
                    },
                    child: GestureDetector(
                      onTap: () => _showAddEdit(context, existing: g),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
                        child: Row(children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(color: _funcColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                            alignment: Alignment.center,
                            child: const Text('🎁', style: TextStyle(fontSize: 18)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(g.giftName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: tc)),
                            Text(
                              [
                                'Qty: ${g.quantity}',
                                if (g.whereToBuy != null) g.whereToBuy!,
                                if (g.vendor != null) g.vendor!,
                              ].join(' • '),
                              style: TextStyle(fontSize: 10, fontFamily: 'Nunito', color: sub),
                            ),
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            if (g.approxPrice != null)
                              Text('₹${g.approxPrice!.toStringAsFixed(0)}/item', style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub)),
                            if (g.totalCost > 0)
                              Text('₹${g.totalCost.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'Nunito', color: AppColors.income)),
                          ]),
                        ]),
                      ),
                    ),
                  ),
                )),
              ],
            ),
    );
  }
}

// ── Function detail ───────────────────────────────────────────────────────────
class _FunctionDetail extends StatefulWidget {
  final FunctionModel fn;
  final bool isDark;
  final VoidCallback onUpdate;
  final Map<String, String> familyWalletNames;
  const _FunctionDetail({
    required this.fn,
    required this.isDark,
    required this.onUpdate,
    this.familyWalletNames = const {},
  });
  @override
  State<_FunctionDetail> createState() => _FunctionDetailState();
}

class _FunctionDetailState extends State<_FunctionDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
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

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        title: Text(
          fn.title,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            fontFamily: 'Nunito',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => _showEditFunction(context, isDark, surfBg),
            tooltip: 'Edit Function',
          ),
        ],
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
            Tab(text: 'Cash'),
            Tab(text: 'Gold / Silver'),
            Tab(text: 'Gifts'),
            Tab(text: 'Vendors'),
            Tab(text: 'Messages'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // INFO
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Details card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _funcColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _funcColor.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    children: [
                      _InfoDetailRow(
                        label: 'Function Type',
                        value:
                            '${fn.type.emoji}  ${fn.type == FunctionType.other && fn.customType != null ? fn.customType! : fn.type.label}',
                        isDark: isDark,
                        tc: tc,
                        sub: sub,
                      ),
                      _InfoDetailRow(
                        label: 'Function Name',
                        value: fn.title,
                        isDark: isDark,
                        tc: tc,
                        sub: sub,
                      ),
                      if (fn.functionDate != null)
                        _InfoDetailRow(
                          label: 'Date',
                          value: fmtDate(fn.functionDate!),
                          isDark: isDark,
                          tc: tc,
                          sub: sub,
                        ),
                      if (fn.venue != null)
                        _InfoDetailRow(
                          label: 'Venue',
                          value: fn.venue!,
                          isDark: isDark,
                          tc: tc,
                          sub: sub,
                          isLast: fn.address == null && fn.notes == null,
                        ),
                      if (fn.address != null)
                        _InfoDetailRow(
                          label: 'Address',
                          value: fn.address!,
                          isDark: isDark,
                          tc: tc,
                          sub: sub,
                          isLast: fn.notes == null,
                        ),
                      if (fn.notes != null)
                        _InfoDetailRow(
                          label: 'Notes',
                          value: fn.notes!,
                          isDark: isDark,
                          tc: tc,
                          sub: sub,
                          isLast: true,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Summary stats
                Row(
                  children: [
                    _FuncStat(
                      label: 'Cash',
                      value: '₹${fn.totalCash.toStringAsFixed(0)}',
                      emoji: '💵',
                      color: AppColors.income,
                    ),
                    const SizedBox(width: 10),
                    _FuncStat(
                      label: 'Gold',
                      value: '${fn.totalGold}g',
                      emoji: '🥇',
                      color: AppColors.lend,
                    ),
                    const SizedBox(width: 10),
                    _FuncStat(
                      label: 'Total Gifts',
                      value: '${fn.gifts.length}',
                      emoji: '🎁',
                      color: _funcColor,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // CASH (Moi)
          _MoiTab(fn: fn, isDark: isDark, onUpdate: () => setState(() {})),

          // GOLD / SILVER
          _FilteredGiftTab(
            gifts: fn.gifts
                .where(
                  (g) =>
                      g.giftType == GiftType.gold ||
                      g.giftType == GiftType.silver,
                )
                .toList(),
            isDark: isDark,
            label: 'Gold / Silver',
            emoji: '🥇',
            emptySubtitle: 'No gold or silver gifts recorded',
            summaryLabel: [
              if (fn.totalGold > 0) '${fn.totalGold}g gold',
              if (fn.totalSilver > 0) '${fn.totalSilver}g silver',
            ].join('  •  '),
            addLabel: 'Add Item',
            onAdd: () => _showAddGift(context, isDark, surfBg, fn),
            onEdit: (g) => _showEditGift(context, isDark, surfBg, g),
          ),

          // GIFTS
          _FilteredGiftTab(
            gifts: fn.gifts
                .where(
                  (g) =>
                      g.giftType != GiftType.gold &&
                      g.giftType != GiftType.silver,
                )
                .toList(),
            isDark: isDark,
            label: 'Gift Items',
            emoji: '🎁',
            emptySubtitle:
                'Tap Add Gift to record household, clothing and other items',
            summaryLabel: '',
            onAdd: () => _showAddGift(
              context,
              isDark,
              surfBg,
              fn,
              types: _giftItemTypes,
            ),
            onEdit: (g) => _showEditGift(
              context,
              isDark,
              surfBg,
              g,
              types: _giftItemTypes,
            ),
          ),

          // VENDORS
          _AllVendorsTab(
            fn: fn,
            isDark: isDark,
            onAdd: () => _showAddVendor(context, isDark, surfBg, fn),
            onEdit: (v) => _showEditVendor(context, isDark, surfBg, v),
            onDelete: (v) => setState(() => fn.vendors.remove(v)),
          ),

          // MESSAGES
          Expanded(
            child: ChatWidget(
              messages: fn.chat,
              isDark: isDark,
              textOf: (m) => (m as FunctionChatMessage).text,
              senderOf: (m) => (m as FunctionChatMessage).senderId,
              onSend: (text) => setState(
                () => fn.chat.add(
                  FunctionChatMessage(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    senderId: 'me',
                    text: text,
                    at: DateTime.now(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddVendor(
    BuildContext ctx,
    bool isDark,
    Color surfBg,
    FunctionModel fn,
  ) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final advanceCtrl = TextEditingController();
    final eventCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    var category = VendorCategory.catering;
    showPlanSheet(
      ctx,
      child: StatefulBuilder(
        builder: (sheetCtx, ss) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 36,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Vendor',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(height: 14),
              const SheetLabel(text: 'VENDOR NAME'),
              PlanInputField(
                controller: nameCtrl,
                hint: 'e.g. Sri Krishna Catering',
              ),
              const SizedBox(height: 12),
              const SheetLabel(text: 'CATEGORY'),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: VendorCategory.values.map((c) {
                    final sel = category == c;
                    return GestureDetector(
                      onTap: () => ss(() => category = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: sel
                              ? _funcColor.withValues(alpha: 0.15)
                              : surfBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel ? _funcColor : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          '${c.emoji} ${c.label}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                            color: sel
                                ? _funcColor
                                : (isDark
                                      ? AppColors.subDark
                                      : AppColors.subLight),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              const SheetLabel(text: 'CONTACT'),
              PlanInputField(
                controller: phoneCtrl,
                hint: 'Phone number',
                inputType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              PlanInputField(
                controller: emailCtrl,
                hint: 'Email (optional)',
                inputType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 8),
              PlanInputField(
                controller: addressCtrl,
                hint: 'Address (optional)',
              ),
              const SizedBox(height: 12),
              const SheetLabel(text: 'COST'),
              Row(
                children: [
                  Expanded(
                    child: PlanInputField(
                      controller: costCtrl,
                      hint: 'Total cost (₹)',
                      inputType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PlanInputField(
                      controller: advanceCtrl,
                      hint: 'Advance paid (₹)',
                      inputType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const SheetLabel(text: 'EVENT LINKED'),
              PlanInputField(
                controller: eventCtrl,
                hint: 'e.g. Wedding, Housewarming',
              ),
              const SizedBox(height: 12),
              const SheetLabel(text: 'NOTES'),
              PlanInputField(
                controller: notesCtrl,
                hint: 'Invoice details, notes…',
                maxLines: 3,
              ),
              SaveButton(
                label: 'Add Vendor',
                color: _funcColor,
                onTap: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  setState(() {
                    fn.vendors.add(
                      FunctionVendor(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameCtrl.text.trim(),
                        category: category,
                        phone: phoneCtrl.text.trim().isEmpty
                            ? null
                            : phoneCtrl.text.trim(),
                        email: emailCtrl.text.trim().isEmpty
                            ? null
                            : emailCtrl.text.trim(),
                        address: addressCtrl.text.trim().isEmpty
                            ? null
                            : addressCtrl.text.trim(),
                        totalCost: double.tryParse(costCtrl.text.trim()),
                        advancePaid: double.tryParse(advanceCtrl.text.trim()),
                        eventLinked: eventCtrl.text.trim().isEmpty
                            ? null
                            : eventCtrl.text.trim(),
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                      ),
                    );
                  });
                  Navigator.pop(sheetCtx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditVendor(
    BuildContext ctx,
    bool isDark,
    Color surfBg,
    FunctionVendor v,
  ) {
    final nameCtrl = TextEditingController(text: v.name);
    final phoneCtrl = TextEditingController(text: v.phone ?? '');
    final emailCtrl = TextEditingController(text: v.email ?? '');
    final addressCtrl = TextEditingController(text: v.address ?? '');
    final costCtrl = TextEditingController(
      text: v.totalCost?.toStringAsFixed(0) ?? '',
    );
    final advanceCtrl = TextEditingController(
      text: v.advancePaid?.toStringAsFixed(0) ?? '',
    );
    final eventCtrl = TextEditingController(text: v.eventLinked ?? '');
    final notesCtrl = TextEditingController(text: v.notes ?? '');
    var category = v.category;
    showPlanSheet(
      ctx,
      child: StatefulBuilder(
        builder: (sheetCtx, ss) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 36,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Edit Vendor',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(height: 14),
              const SheetLabel(text: 'VENDOR NAME'),
              PlanInputField(controller: nameCtrl, hint: 'Vendor name'),
              const SizedBox(height: 12),
              const SheetLabel(text: 'CATEGORY'),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: VendorCategory.values.map((c) {
                    final sel = category == c;
                    return GestureDetector(
                      onTap: () => ss(() => category = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: sel
                              ? _funcColor.withValues(alpha: 0.15)
                              : surfBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel ? _funcColor : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          '${c.emoji} ${c.label}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                            color: sel
                                ? _funcColor
                                : (isDark
                                      ? AppColors.subDark
                                      : AppColors.subLight),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              const SheetLabel(text: 'CONTACT'),
              PlanInputField(
                controller: phoneCtrl,
                hint: 'Phone number',
                inputType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              PlanInputField(
                controller: emailCtrl,
                hint: 'Email (optional)',
                inputType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 8),
              PlanInputField(
                controller: addressCtrl,
                hint: 'Address (optional)',
              ),
              const SizedBox(height: 12),
              const SheetLabel(text: 'COST'),
              Row(
                children: [
                  Expanded(
                    child: PlanInputField(
                      controller: costCtrl,
                      hint: 'Total cost (₹)',
                      inputType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PlanInputField(
                      controller: advanceCtrl,
                      hint: 'Advance paid (₹)',
                      inputType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const SheetLabel(text: 'EVENT LINKED'),
              PlanInputField(
                controller: eventCtrl,
                hint: 'e.g. Wedding, Housewarming',
              ),
              const SizedBox(height: 12),
              const SheetLabel(text: 'NOTES'),
              PlanInputField(
                controller: notesCtrl,
                hint: 'Invoice details, notes…',
                maxLines: 3,
              ),
              SaveButton(
                label: 'Save Changes',
                color: _funcColor,
                onTap: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  setState(() {
                    v.name = nameCtrl.text.trim();
                    v.category = category;
                    v.phone = phoneCtrl.text.trim().isEmpty
                        ? null
                        : phoneCtrl.text.trim();
                    v.email = emailCtrl.text.trim().isEmpty
                        ? null
                        : emailCtrl.text.trim();
                    v.address = addressCtrl.text.trim().isEmpty
                        ? null
                        : addressCtrl.text.trim();
                    v.totalCost = double.tryParse(costCtrl.text.trim());
                    v.advancePaid = double.tryParse(advanceCtrl.text.trim());
                    v.eventLinked = eventCtrl.text.trim().isEmpty
                        ? null
                        : eventCtrl.text.trim();
                    v.notes = notesCtrl.text.trim().isEmpty
                        ? null
                        : notesCtrl.text.trim();
                  });
                  Navigator.pop(sheetCtx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditFunction(BuildContext ctx, bool isDark, Color surfBg) {
    final fn = widget.fn;
    final titleCtrl = TextEditingController(text: fn.title);
    final customTypeCtrl = TextEditingController(text: fn.customType ?? '');
    final venueCtrl = TextEditingController(text: fn.venue ?? '');
    final notesCtrl = TextEditingController(text: fn.notes ?? '');
    DateTime? date = fn.functionDate;
    var type = fn.type;
    String? selectedWalletId;
    String icon = fn.icon;
    String? photoPath;
    final familyEntries = widget.familyWalletNames.entries.toList();
    showPlanSheet(
      ctx,
      child: StatefulBuilder(
        builder: (ctx2, ss) {
          final sub = isDark ? AppColors.subDark : AppColors.subLight;

          void pickIcon() {
            showModalBottomSheet(
              context: ctx2,
              backgroundColor: Colors.transparent,
              builder: (_) => StatefulBuilder(
                builder: (ctx3, setS3) => Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Choose Icon', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'Nunito')),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                Navigator.pop(ctx3);
                                final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
                                if (picked != null) ss(() => photoPath = picked.path);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(color: surfBg, borderRadius: BorderRadius.circular(12)),
                                child: const Column(children: [
                                  Icon(Icons.photo_library_rounded, size: 24, color: _funcColor),
                                  SizedBox(height: 4),
                                  Text('Gallery', style: TextStyle(fontSize: 12, fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
                                ]),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                Navigator.pop(ctx3);
                                final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
                                if (picked != null) ss(() => photoPath = picked.path);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(color: surfBg, borderRadius: BorderRadius.circular(12)),
                                child: const Column(children: [
                                  Icon(Icons.camera_alt_rounded, size: 24, color: _funcColor),
                                  SizedBox(height: 4),
                                  Text('Camera', style: TextStyle(fontSize: 12, fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
                                ]),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _fnIconEmojis.map((e) {
                          final selected = photoPath == null && icon == e;
                          return GestureDetector(
                            onTap: () {
                              ss(() { icon = e; photoPath = null; });
                              Navigator.pop(ctx3);
                            },
                            child: Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: selected ? _funcColor.withValues(alpha: 0.15) : surfBg,
                                borderRadius: BorderRadius.circular(10),
                                border: selected ? Border.all(color: _funcColor, width: 1.5) : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(e, style: const TextStyle(fontSize: 22)),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Edit Function',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const SheetLabel(text: 'GROUP ICON'),
              GestureDetector(
                onTap: pickIcon,
                child: Row(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: _funcColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _funcColor.withValues(alpha: 0.3)),
                      ),
                      alignment: Alignment.center,
                      child: EmojiOrImage(value: photoPath ?? icon, size: 30),
                    ),
                    const SizedBox(width: 12),
                    Text('Tap to change icon', style: TextStyle(fontSize: 13, fontFamily: 'Nunito', fontWeight: FontWeight.w600, color: sub)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const SheetLabel(text: 'FUNCTION TYPE'),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: FunctionType.values
                      .map(
                        (t) => GestureDetector(
                          onTap: () => ss(() => type = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: type == t
                                  ? _funcColor.withValues(alpha: 0.15)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: type == t
                                    ? _funcColor
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  t.emoji,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  t.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                    color: type == t
                                        ? _funcColor
                                        : (isDark
                                              ? AppColors.subDark
                                              : AppColors.subLight),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              PlanInputField(controller: titleCtrl, hint: 'Function title *'),
              if (type == FunctionType.other) ...[
                const SizedBox(height: 8),
                PlanInputField(
                  controller: customTypeCtrl,
                  hint: 'Enter function type',
                ),
              ],
              const SizedBox(height: 8),
              PlanInputField(controller: venueCtrl, hint: 'Venue / Location'),
              const SizedBox(height: 8),
              PlanInputField(controller: notesCtrl, hint: 'Notes'),
              const SizedBox(height: 8),
              LifeDateTile(
                date: date,
                hint: 'Function date',
                color: _funcColor,
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: date ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) ss(() => date = d);
                },
              ),
              if (familyEntries.isNotEmpty) ...[
                const SizedBox(height: 12),
                const SheetLabel(text: 'MOVE TO GROUP'),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    GestureDetector(
                      onTap: () => ss(() => selectedWalletId = null),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: selectedWalletId == null ? _funcColor.withValues(alpha: 0.15) : surfBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: selectedWalletId == null ? _funcColor : Colors.transparent),
                        ),
                        child: Text(
                          'Personal',
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Nunito',
                            color: selectedWalletId == null ? _funcColor : (isDark ? AppColors.subDark : AppColors.subLight),
                          ),
                        ),
                      ),
                    ),
                    ...familyEntries.map((e) => GestureDetector(
                      onTap: () => ss(() => selectedWalletId = e.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: selectedWalletId == e.key ? _funcColor.withValues(alpha: 0.15) : surfBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: selectedWalletId == e.key ? _funcColor : Colors.transparent),
                        ),
                        child: Text(
                          e.value,
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Nunito',
                            color: selectedWalletId == e.key ? _funcColor : (isDark ? AppColors.subDark : AppColors.subLight),
                          ),
                        ),
                      ),
                    )),
                  ],
                ),
              ],
              SaveButton(
                label: 'Save Changes',
                color: _funcColor,
                onTap: () async {
                  if (titleCtrl.text.trim().isEmpty) return;
                  String finalIcon = icon;
                  if (photoPath != null) {
                    try {
                      finalIcon = await ProfileService.instance.uploadPhoto(
                        localPath: photoPath!,
                        folder: 'functions',
                        name: 'fn_${fn.id}',
                      );
                    } catch (e) {
                      debugPrint('[Functions] icon upload error: $e');
                    }
                  }
                  setState(() {
                    fn.type = type;
                    fn.title = titleCtrl.text.trim();
                    fn.customType =
                        type == FunctionType.other &&
                            customTypeCtrl.text.trim().isNotEmpty
                        ? customTypeCtrl.text.trim()
                        : null;
                    fn.functionDate = date;
                    fn.venue = venueCtrl.text.trim().isEmpty
                        ? null
                        : venueCtrl.text.trim();
                    fn.notes = notesCtrl.text.trim().isEmpty
                        ? null
                        : notesCtrl.text.trim();
                    fn.icon = finalIcon;
                    if (selectedWalletId != null) fn.walletId = selectedWalletId!;
                  });
                  await FunctionsService.instance.updateMyFunction(
                    fn.id,
                    fn.toJson(),
                  );
                  widget.onUpdate();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
        },
      ),
    );
  }

  static const _goldSilverTypes = [GiftType.gold, GiftType.silver];
  static const _giftItemTypes = [
    GiftType.household,
    GiftType.clothing,
    GiftType.giftItem,
    GiftType.giftCard,
    GiftType.other,
  ];

  void _showAddGift(
    BuildContext ctx,
    bool isDark,
    Color surfBg,
    FunctionModel fn, {
    List<GiftType> types = _goldSilverTypes,
  }) {
    final nameCtrl = TextEditingController();
    final placeCtrl = TextEditingController();
    final relationCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    var giftType = types.first;
    showPlanSheet(
      ctx,
      child: StatefulBuilder(
        builder: (ctx2, ss) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Item',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const SheetLabel(text: 'GIFT TYPE'),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: types
                      .map(
                        (t) => GestureDetector(
                          onTap: () => ss(() => giftType = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: giftType == t
                                  ? _funcColor.withValues(alpha: 0.15)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: giftType == t
                                    ? _funcColor
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  t.emoji,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  t.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                    color: giftType == t
                                        ? _funcColor
                                        : (isDark
                                              ? AppColors.subDark
                                              : AppColors.subLight),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              PlanInputField(controller: nameCtrl, hint: 'Guest name *'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: PlanInputField(controller: placeCtrl, hint: 'Place'),
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
                controller: amtCtrl,
                hint: giftType == GiftType.gold
                    ? 'Gold grams *'
                    : giftType == GiftType.silver
                    ? 'Silver grams *'
                    : giftType == GiftType.giftCard
                    ? 'Card value'
                    : 'Description',
                inputType:
                    (giftType == GiftType.gold || giftType == GiftType.silver)
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
              ),
              const SizedBox(height: 8),
              PlanInputField(controller: notesCtrl, hint: 'Notes'),
              SaveButton(
                label: 'Add Item',
                color: _funcColor,
                onTap: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final num = double.tryParse(amtCtrl.text.trim());
                  setState(
                    () => fn.gifts.add(
                      GiftEntry(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        guestName: nameCtrl.text.trim(),
                        giftType: giftType,
                        guestPlace: placeCtrl.text.trim().isEmpty
                            ? null
                            : placeCtrl.text.trim(),
                        relation: relationCtrl.text.trim().isEmpty
                            ? null
                            : relationCtrl.text.trim(),
                        goldGrams: giftType == GiftType.gold ? num : null,
                        silverGrams: giftType == GiftType.silver ? num : null,
                        giftCardValue: giftType == GiftType.giftCard
                            ? amtCtrl.text.trim().isEmpty
                                  ? null
                                  : amtCtrl.text.trim()
                            : null,
                        itemDescription:
                            (giftType == GiftType.other ||
                                giftType == GiftType.household ||
                                giftType == GiftType.clothing ||
                                giftType == GiftType.giftItem)
                            ? amtCtrl.text.trim().isEmpty
                                  ? null
                                  : amtCtrl.text.trim()
                            : null,
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                      ),
                    ),
                  );
                  widget.onUpdate();
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditGift(
    BuildContext ctx,
    bool isDark,
    Color surfBg,
    GiftEntry gift, {
    List<GiftType> types = _goldSilverTypes,
  }) {
    final nameCtrl = TextEditingController(text: gift.guestName);
    final placeCtrl = TextEditingController(text: gift.guestPlace ?? '');
    final relationCtrl = TextEditingController(text: gift.relation ?? '');
    final notesCtrl = TextEditingController(text: gift.notes ?? '');
    final amtCtrl = TextEditingController(
      text:
          gift.goldGrams?.toStringAsFixed(1) ??
          gift.silverGrams?.toStringAsFixed(1) ??
          gift.giftCardValue ??
          gift.itemDescription ??
          '',
    );
    var giftType = gift.giftType;
    showPlanSheet(
      ctx,
      child: StatefulBuilder(
        builder: (ctx2, ss) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Edit Item',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const SheetLabel(text: 'GIFT TYPE'),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: types
                      .map(
                        (t) => GestureDetector(
                          onTap: () => ss(() => giftType = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: giftType == t
                                  ? _funcColor.withValues(alpha: 0.15)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: giftType == t
                                    ? _funcColor
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  t.emoji,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  t.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                    color: giftType == t
                                        ? _funcColor
                                        : (isDark
                                              ? AppColors.subDark
                                              : AppColors.subLight),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              PlanInputField(controller: nameCtrl, hint: 'Guest name *'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: PlanInputField(controller: placeCtrl, hint: 'Place'),
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
                controller: amtCtrl,
                hint: giftType == GiftType.gold
                    ? 'Gold grams'
                    : giftType == GiftType.silver
                    ? 'Silver grams'
                    : giftType == GiftType.giftCard
                    ? 'Card value'
                    : 'Description',
                inputType:
                    (giftType == GiftType.gold || giftType == GiftType.silver)
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
              ),
              const SizedBox(height: 8),
              PlanInputField(controller: notesCtrl, hint: 'Notes'),
              SaveButton(
                label: 'Save Changes',
                color: _funcColor,
                onTap: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final num = double.tryParse(amtCtrl.text.trim());
                  setState(() {
                    gift.guestName = nameCtrl.text.trim();
                    gift.giftType = giftType;
                    gift.guestPlace = placeCtrl.text.trim().isEmpty
                        ? null
                        : placeCtrl.text.trim();
                    gift.relation = relationCtrl.text.trim().isEmpty
                        ? null
                        : relationCtrl.text.trim();
                    gift.goldGrams = giftType == GiftType.gold ? num : null;
                    gift.silverGrams = giftType == GiftType.silver ? num : null;
                    gift.giftCardValue = giftType == GiftType.giftCard
                        ? amtCtrl.text.trim().isEmpty
                              ? null
                              : amtCtrl.text.trim()
                        : null;
                    gift.itemDescription =
                        (giftType == GiftType.other ||
                            giftType == GiftType.household ||
                            giftType == GiftType.clothing ||
                            giftType == GiftType.giftItem)
                        ? amtCtrl.text.trim().isEmpty
                              ? null
                              : amtCtrl.text.trim()
                        : null;
                    gift.notes = notesCtrl.text.trim().isEmpty
                        ? null
                        : notesCtrl.text.trim();
                  });
                  widget.onUpdate();
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FuncStat extends StatelessWidget {
  final String label, value, emoji;
  final Color color;
  const _FuncStat({
    required this.label,
    required this.value,
    required this.emoji,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
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

class _GiftEntryCard extends StatelessWidget {
  final GiftEntry gift;
  final bool isDark;
  final VoidCallback? onEdit;
  const _GiftEntryCard({required this.gift, required this.isDark, this.onEdit});
  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _funcColor.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _funcColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                gift.giftType.emoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gift.guestName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: tc,
                    ),
                  ),
                  Row(
                    children: [
                      if (gift.guestPlace != null) ...[
                        Icon(Icons.location_on_rounded, size: 11, color: sub),
                        const SizedBox(width: 3),
                        Text(
                          gift.guestPlace!,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Nunito',
                            color: sub,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (gift.relation != null)
                        LifeBadge(text: gift.relation!, color: _funcColor),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  gift.summary,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'DM Mono',
                    color: gift.giftType == GiftType.silver
                        ? AppColors.subDark
                        : AppColors.lend,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilteredGiftTab extends StatelessWidget {
  final List<GiftEntry> gifts;
  final bool isDark;
  final String label;
  final String emoji;
  final String emptySubtitle;
  final String summaryLabel;
  final String addLabel;
  final VoidCallback onAdd;
  final void Function(GiftEntry) onEdit;

  const _FilteredGiftTab({
    required this.gifts,
    required this.isDark,
    required this.label,
    required this.emoji,
    required this.emptySubtitle,
    required this.summaryLabel,
    this.addLabel = 'Add Gift',
    required this.onAdd,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    return Column(
      children: [
        Container(
          color: cardBg,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: tc,
                    ),
                  ),
                  if (summaryLabel.isNotEmpty)
                    Text(
                      summaryLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'Nunito',
                        color: AppColors.income,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _funcColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        addLabel,
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
              ),
            ],
          ),
        ),
        Expanded(
          child: gifts.isEmpty
              ? PlanEmptyState(
                  emoji: emoji,
                  title: 'No gifts recorded',
                  subtitle: emptySubtitle,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: gifts.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _GiftEntryCard(
                      gift: gifts[i],
                      isDark: isDark,
                      onEdit: () => onEdit(gifts[i]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _AllVendorsTab extends StatelessWidget {
  final FunctionModel fn;
  final bool isDark;
  final VoidCallback onAdd;
  final void Function(FunctionVendor) onEdit;
  final void Function(FunctionVendor) onDelete;
  const _AllVendorsTab({
    required this.fn,
    required this.isDark,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = this.isDark;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);

    if (fn.vendors.isEmpty) {
      return PlanEmptyState(
        emoji: '🤝',
        title: 'No vendors yet',
        subtitle:
            'Tap + Add Vendor to record catering, venue, decoration and more',
        buttonLabel: '+ Add Vendor',
        onButton: onAdd,
      );
    }

    // Group by category
    final grouped = <VendorCategory, List<FunctionVendor>>{};
    for (final v in fn.vendors) {
      grouped.putIfAbsent(v.category, () => []).add(v);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // Summary row
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _VendorStat(
                label: 'Vendors',
                value: '${fn.vendors.length}',
                color: _funcColor,
                isDark: isDark,
              ),
              _VendorStat(
                label: 'Total Cost',
                value:
                    '₹${fn.vendors.fold(0.0, (s, v) => s + (v.totalCost ?? 0)).toStringAsFixed(0)}',
                color: AppColors.expense,
                isDark: isDark,
              ),
              _VendorStat(
                label: 'Balance Due',
                value:
                    '₹${fn.vendors.fold(0.0, (s, v) => s + v.balance).toStringAsFixed(0)}',
                color: AppColors.lend,
                isDark: isDark,
              ),
            ],
          ),
        ),
        // Add button
        GestureDetector(
          onTap: onAdd,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _funcColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _funcColor.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: _funcColor, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Add Vendor',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    color: _funcColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Category sections
        ...grouped.entries.map(
          (e) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Row(
                  children: [
                    Text(e.key.emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      e.key.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: sub,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              ...e.value.map(
                (v) => SwipeTile(
                  onDelete: () => onDelete(v),
                  child: GestureDetector(
                    onTap: () => onEdit(v),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  v.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Nunito',
                                    color: tc,
                                  ),
                                ),
                              ),
                              if (v.totalCost != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.expense.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '₹${v.totalCost!.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'Nunito',
                                      color: AppColors.expense,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (v.phone != null || v.email != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (v.phone != null) ...[
                                  Icon(
                                    Icons.phone_rounded,
                                    size: 12,
                                    color: sub,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    v.phone!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'Nunito',
                                      color: sub,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                if (v.email != null) ...[
                                  Icon(
                                    Icons.email_rounded,
                                    size: 12,
                                    color: sub,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      v.email!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'Nunito',
                                        color: sub,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                          if (v.totalCost != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _CostChip(
                                  label: 'Advance',
                                  value: v.advancePaid ?? 0,
                                  color: AppColors.income,
                                ),
                                const SizedBox(width: 8),
                                _CostChip(
                                  label: 'Balance',
                                  value: v.balance,
                                  color: v.balance > 0
                                      ? AppColors.lend
                                      : AppColors.income,
                                ),
                              ],
                            ),
                          ],
                          if (v.eventLinked != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.event_rounded, size: 12, color: sub),
                                const SizedBox(width: 4),
                                Text(
                                  v.eventLinked!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'Nunito',
                                    color: sub,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (v.notes != null && v.notes!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.notes_rounded, size: 12, color: sub),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    v.notes!,
                                    style: TextStyle(
                                      fontSize: 12,
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
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ],
    );
  }
}

class _VendorStat extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool isDark;
  const _VendorStat({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            fontFamily: 'Nunito',
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub),
        ),
      ],
    );
  }
}

class _CostChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _CostChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      '$label: ₹${value.toStringAsFixed(0)}',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        fontFamily: 'Nunito',
        color: color,
      ),
    ),
  );
}

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
                            '🎁 ${item.gifts.map((g) => g.category).join(', ')}',
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'Nunito',
                              color: _funcColor,
                              fontWeight: FontWeight.w700,
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
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _funcColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _funcColor.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    children: [
                      _InfoDetailRow(
                        label: 'Function Type',
                        value: '${item.type.emoji}  ${item.type.label}',
                        isDark: isDark,
                        tc: tc,
                        sub: sub,
                      ),
                      _InfoDetailRow(
                        label: 'Person',
                        value: item.personName,
                        isDark: isDark,
                        tc: tc,
                        sub: sub,
                      ),
                      _InfoDetailRow(
                        label: 'Function',
                        value: item.functionTitle,
                        isDark: isDark,
                        tc: tc,
                        sub: sub,
                      ),
                      if (item.date != null)
                        _InfoDetailRow(
                          label: 'Date',
                          value: fmtDate(item.date!),
                          isDark: isDark,
                          tc: tc,
                          sub: sub,
                        ),
                      if (item.venue != null)
                        _InfoDetailRow(
                          label: 'Venue',
                          value: item.venue!,
                          isDark: isDark,
                          tc: tc,
                          sub: sub,
                          isLast: item.notes == null,
                        ),
                      if (item.notes != null)
                        _InfoDetailRow(
                          label: 'Notes',
                          value: item.notes!,
                          isDark: isDark,
                          tc: tc,
                          sub: sub,
                          isLast: true,
                        ),
                    ],
                  ),
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
            onSend: (text) => setState(
              () => item.chat.add(
                FunctionChatMessage(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  senderId: 'me',
                  text: text,
                  at: DateTime.now(),
                ),
              ),
            ),
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

  void _addItem() {
    if (_selected == null) return;
    setState(() {
      widget.item.plannedGifts.add(
        PlannedGiftItem(
          category: _selected!,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        ),
      );
      _selected = null;
      _notesCtrl.clear();
    });
    widget.onUpdate();
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
                onDelete: () => setState(() {
                  gifts.removeAt(i);
                  widget.onUpdate();
                }),
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
                hintText: 'Amount or notes… (e.g. ₹5000)',
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
                        onTap: () => setState(() {
                          if (sel) {
                            widget.item.votes.remove(member.id);
                          } else {
                            widget.item.votes[member.id] = cat.$2;
                          }
                          widget.onUpdate();
                        }),
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

  @override
  void initState() {
    super.initState();
    _filter = TabController(length: 3, vsync: this);
    _filter.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _filter.dispose();
    _searchCtrl.dispose();
    super.dispose();
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
                    '₹${totalReceived.toStringAsFixed(0)}',
                    _moiColor,
                  ),
                  const SizedBox(width: 8),
                  _MoiStat(
                    'Returned',
                    '₹${totalReturned.toStringAsFixed(0)}',
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

        // ── List ─────────────────────────────────────────────────────────────
        Expanded(
          child: listToShow.isEmpty
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
                    onDelete: () => setState(() {
                      fn.moi.remove(listToShow[i]);
                      widget.onUpdate();
                    }),
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
    final nameCtrl = TextEditingController();
    final familyNameCtrl = TextEditingController();
    final placeCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final relationCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    var kind = MoiKind.newMoi;

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
                          const Text(
                            'Add Moi Entry',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Nunito',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Record moi received at this function',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Nunito',
                              color: isDark
                                  ? AppColors.subDark
                                  : AppColors.subLight,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Moi Type toggle
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

                          // Fields
                          _SheetLabel(text: 'PERSON DETAILS'),
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
                            hint: 'Amount received (₹) *',
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
                            label: 'Save Moi Entry',
                            color: kind.color,
                            onTap: () {
                              if (nameCtrl.text.trim().isEmpty) return;
                              final amt = double.tryParse(
                                amountCtrl.text.trim(),
                              );
                              if (amt == null || amt <= 0) return;
                              setState(
                                () => widget.fn.moi.add(
                                  MoiEntry(
                                    id: DateTime.now().millisecondsSinceEpoch
                                        .toString(),
                                    personName: nameCtrl.text.trim(),
                                    familyName:
                                        familyNameCtrl.text.trim().isEmpty
                                        ? null
                                        : familyNameCtrl.text.trim(),
                                    amount: amt,
                                    kind: kind,
                                    place: placeCtrl.text.trim().isEmpty
                                        ? null
                                        : placeCtrl.text.trim(),
                                    phone: phoneCtrl.text.trim().isEmpty
                                        ? null
                                        : phoneCtrl.text.trim(),
                                    relation: relationCtrl.text.trim().isEmpty
                                        ? null
                                        : relationCtrl.text.trim(),
                                    notes: notesCtrl.text.trim().isEmpty
                                        ? null
                                        : notesCtrl.text.trim(),
                                  ),
                                ),
                              );
                              widget.onUpdate();
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
                                      '₹${entry.amount.toStringAsFixed(0)}',
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
                            hint: 'Return amount (₹)',
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
                            hint: 'Amount received (₹) *',
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
// MOI CARD
// ─────────────────────────────────────────────────────────────────────────────

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
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: entry.returned
                  ? AppColors.income.withOpacity(0.25)
                  : kindColor.withOpacity(0.2),
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
                          '₹${entry.amount.toStringAsFixed(0)}',
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
                            '₹${entry.returnedAmount!.toStringAsFixed(0)} returned',
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

// ─────────────────────────────────────────────────────────────────────────────
// SHARED SMALL HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _SheetLabel extends StatelessWidget {
  final String text;
  const _SheetLabel({required this.text});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          fontFamily: 'Nunito',
          color: isDark ? AppColors.subDark : AppColors.subLight,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INFO TAB LABELED ROW
// ─────────────────────────────────────────────────────────────────────────────
class _InfoDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final Color tc;
  final Color sub;
  final bool isLast;
  const _InfoDetailRow({
    required this.label,
    required this.value,
    required this.isDark,
    required this.tc,
    required this.sub,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    color: sub,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    color: tc,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, color: _funcColor.withValues(alpha: 0.12)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION ADD SHEET  —  AI Parse tab  +  Manual tab
// ─────────────────────────────────────────────────────────────────────────────

class _FunctionAddSheet extends StatefulWidget {
  final int tabIdx;
  final bool isDark;
  final Color surfBg;
  final String walletId;
  final List<UpcomingFunction> upcomingList;
  final Future<void> Function(
    String,
    FunctionType,
    String?,
    String?,
    DateTime?,
    String?,
    String?,
    bool,
    String,
  )
  onSave;
  // (title, type, customType, venue, date, personName, familyName, isPlanned, icon)

  const _FunctionAddSheet({
    required this.tabIdx,
    required this.isDark,
    required this.surfBg,
    required this.walletId,
    required this.upcomingList,
    required this.onSave,
  });

  @override
  State<_FunctionAddSheet> createState() => _FunctionAddSheetState();
}

class _FunctionAddSheetState extends State<_FunctionAddSheet>
    with SingleTickerProviderStateMixin {
  late TabController _mode;

  final _aiCtrl = TextEditingController();
  bool _aiParsing = false;
  _ParsedFunction? _aiPreview;
  String? _aiError;

  final _titleCtrl = TextEditingController();
  final _customTypeCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  final _personCtrl = TextEditingController();
  final _familyNameCtrl = TextEditingController();
  var _type = FunctionType.wedding;
  DateTime? _date;

  bool _isFunctionPlanned = false;
  String _icon = '🎊';
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    _mode = TabController(length: 2, vsync: this);
    _mode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _mode.dispose();
    _aiCtrl.dispose();
    _titleCtrl.dispose();
    _customTypeCtrl.dispose();
    _venueCtrl.dispose();
    _personCtrl.dispose();
    _familyNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _parseAI(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _aiParsing = true;
      _aiError = null;
      _aiPreview = null;
    });
    _ParsedFunction? result;
    try {
      result = await _FunctionAIParser.parse(text.trim(), widget.tabIdx);
    } catch (_) {
      result = _FunctionNlpParser.parse(text.trim(), widget.tabIdx);
    }
    if (!mounted) return;
    setState(() {
      _aiPreview = result;
      _aiParsing = false;
      _titleCtrl.text = result!.title;
      _venueCtrl.text = result.venue ?? '';
      _personCtrl.text = result.personName ?? '';
      _familyNameCtrl.text = result.familyName ?? '';
      _type = result.type;
      _date = result.date;
    });
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      if (_mode.index == 0) _mode.animateTo(1);
      return;
    }
    String icon = _icon;
    if (_photoPath != null) {
      try {
        icon = await ProfileService.instance.uploadPhoto(
          localPath: _photoPath!,
          folder: 'functions',
          name: 'fn_${DateTime.now().millisecondsSinceEpoch}',
        );
      } catch (e) {
        debugPrint('[Functions] icon upload error: $e');
      }
    }
    final needsPersonFields = widget.tabIdx == 1 || widget.tabIdx == 2;
    await widget.onSave(
      title,
      _type,
      _type == FunctionType.other && _customTypeCtrl.text.trim().isNotEmpty
          ? _customTypeCtrl.text.trim()
          : null,
      _venueCtrl.text.trim().isEmpty ? null : _venueCtrl.text.trim(),
      _date,
      needsPersonFields
          ? (_personCtrl.text.trim().isEmpty ? null : _personCtrl.text.trim())
          : null,
      needsPersonFields
          ? (_familyNameCtrl.text.trim().isEmpty
                ? null
                : _familyNameCtrl.text.trim())
          : null,
      _isFunctionPlanned,
      icon,
    );
  }

  void _pickIcon(BuildContext ctx) {
    final isDark = widget.isDark;
    final surfBg = widget.surfBg;
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setS) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose Icon',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx2);
                        final picked = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 80,
                        );
                        if (picked != null && mounted) {
                          setState(() => _photoPath = picked.path);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: surfBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.photo_library_rounded, size: 24, color: _funcColor),
                            SizedBox(height: 4),
                            Text('Gallery', style: TextStyle(fontSize: 12, fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx2);
                        final picked = await ImagePicker().pickImage(
                          source: ImageSource.camera,
                          imageQuality: 80,
                        );
                        if (picked != null && mounted) {
                          setState(() => _photoPath = picked.path);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: surfBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.camera_alt_rounded, size: 24, color: _funcColor),
                            SizedBox(height: 4),
                            Text('Camera', style: TextStyle(fontSize: 12, fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _fnIconEmojis.map((e) {
                  final selected = _photoPath == null && _icon == e;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _icon = e;
                        _photoPath = null;
                      });
                      Navigator.pop(ctx2);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected
                            ? _funcColor.withValues(alpha: 0.15)
                            : surfBg,
                        borderRadius: BorderRadius.circular(10),
                        border: selected
                            ? Border.all(color: _funcColor, width: 1.5)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final surfBg = widget.surfBg;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final sheetTitle = widget.tabIdx == 0
        ? 'Add Function'
        : widget.tabIdx == 1
        ? 'Add Upcoming'
        : 'Record Attended';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      shrinkWrap: true,
      children: [
        Text(
          sheetTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            fontFamily: 'Nunito',
          ),
        ),
        const SizedBox(height: 14),
        // Mode switcher
        Container(
          decoration: BoxDecoration(
            color: surfBg,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(3),
          child: TabBar(
            controller: _mode,
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
            padding: EdgeInsets.zero,
            tabs: const [
              Tab(
                height: 36,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('✨', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text('AI Parse'),
                  ],
                ),
              ),
              Tab(
                height: 36,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_outlined, size: 14),
                    SizedBox(width: 6),
                    Text('Manual'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── AI TAB ─────────────────────────────────────────────────────────
        if (_mode.index == 0) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _funcColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _funcColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✨', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.tabIdx == 1
                        ? 'Describe the upcoming function — e.g. "Raj\'s wedding at ABC Hall on June 20"'
                        : widget.tabIdx == 2
                        ? 'Describe what you attended — e.g. "Priya\'s birthday at Grand Hall on 5th March"'
                        : 'Describe the function — e.g. "Son\'s wedding at ABC Mahal on June 20"',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Nunito',
                      color: tc,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: surfBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _funcColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: TextField(
                    controller: _aiCtrl,
                    maxLines: 3,
                    minLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      fontSize: 14,
                      color: tc,
                      fontFamily: 'Nunito',
                    ),
                    decoration: InputDecoration.collapsed(
                      hintText: widget.tabIdx == 1
                          ? '"Priya\'s wedding at Palace Hall on May 20"'
                          : '"Family wedding at ABC Mahal on June 15"',
                      hintStyle: TextStyle(
                        fontSize: 12.5,
                        color: sub,
                        fontFamily: 'Nunito',
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  indent: 14,
                  endIndent: 14,
                  color: _funcColor.withValues(alpha: 0.15),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 10, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Plain text → AI fills all fields',
                          style: TextStyle(
                            fontSize: 11,
                            color: sub,
                            fontFamily: 'Nunito',
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _aiParsing ? null : () => _parseAI(_aiCtrl.text),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: _aiParsing
                                ? _funcColor.withValues(alpha: 0.3)
                                : _funcColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: _aiParsing
                              ? const SizedBox(
                                  width: 64,
                                  height: 16,
                                  child: LinearProgressIndicator(
                                    backgroundColor: Colors.transparent,
                                    color: Colors.white,
                                    minHeight: 2,
                                  ),
                                )
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('✨', style: TextStyle(fontSize: 13)),
                                    SizedBox(width: 5),
                                    Text(
                                      'Parse',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
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
              ],
            ),
          ),
          if (_aiError != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.expense.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _aiError!,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Nunito',
                  color: AppColors.expense,
                ),
              ),
            ),
          ],
          if (_aiPreview != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.income.withValues(alpha: isDark ? 0.1 : 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.income.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _funcColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _aiPreview!.type.emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _aiPreview!.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Nunito',
                                color: tc,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.income.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '✨ AI Parsed',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.income,
                                  fontFamily: 'Nunito',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _mode.animateTo(1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: surfBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.income.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 12,
                                color: AppColors.income,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Edit',
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
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _FuncPreviewChip(
                        icon: Icons.celebration_rounded,
                        label: _aiPreview!.type.label,
                        color: _funcColor,
                      ),
                      if (_aiPreview!.date != null)
                        _FuncPreviewChip(
                          icon: Icons.calendar_today_rounded,
                          label:
                              '${_aiPreview!.date!.day}/${_aiPreview!.date!.month}/${_aiPreview!.date!.year}',
                          color: AppColors.income,
                        ),
                      if (_aiPreview!.venue != null)
                        _FuncPreviewChip(
                          icon: Icons.location_on_rounded,
                          label: _aiPreview!.venue!,
                          color: AppColors.lend,
                        ),
                      if (_aiPreview!.personName != null)
                        _FuncPreviewChip(
                          icon: Icons.person_rounded,
                          label: _aiPreview!.personName!,
                          color: AppColors.split,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SaveButton(label: 'Save →', color: _funcColor, onTap: _save),
          ],
        ],

        // ── MANUAL TAB ─────────────────────────────────────────────────────
        if (_mode.index == 1) ...[
          if (widget.tabIdx == 0) ...[
            const SheetLabel(text: 'QUICK OPTIONS'),
            Row(
              children: [
                _QuickOptionChip(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Completed Function',
                  active: !_isFunctionPlanned,
                  color: _funcColor,
                  onTap: () => setState(() => _isFunctionPlanned = false),
                ),
                const SizedBox(width: 8),
                _QuickOptionChip(
                  icon: Icons.event_rounded,
                  label: 'Plan for Function',
                  active: _isFunctionPlanned,
                  color: AppColors.income,
                  onTap: () => setState(() => _isFunctionPlanned = true),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isFunctionPlanned) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.income.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.income.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.event_rounded,
                      size: 14,
                      color: AppColors.income,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'This will be saved as a planned function',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: AppColors.income,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          if (widget.tabIdx == 0) ...[
            const SheetLabel(text: 'GROUP ICON'),
            GestureDetector(
              onTap: () => _pickIcon(context),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _funcColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _funcColor.withValues(alpha: 0.3)),
                    ),
                    alignment: Alignment.center,
                    child: EmojiOrImage(
                      value: _photoPath ?? _icon,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Tap to change icon',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.subDark : AppColors.subLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SheetLabel(text: 'FUNCTION TYPE'),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: FunctionType.values
                  .map(
                    (t) => GestureDetector(
                      onTap: () => setState(() => _type = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: _type == t
                              ? _funcColor.withValues(alpha: 0.15)
                              : surfBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _type == t ? _funcColor : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(t.emoji, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 5),
                            Text(
                              t.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Nunito',
                                color: _type == t ? _funcColor : sub,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          if (widget.tabIdx == 1 || widget.tabIdx == 2) ...[
            PlanInputField(
              controller: _personCtrl,
              hint: 'Person name (e.g. Priya)',
            ),
            const SizedBox(height: 8),
            PlanInputField(
              controller: _familyNameCtrl,
              hint: 'Family name (e.g. Sharma family)',
            ),
            const SizedBox(height: 8),
          ],
          PlanInputField(controller: _titleCtrl, hint: 'Function title *'),
          if (_type == FunctionType.other) ...[
            const SizedBox(height: 8),
            PlanInputField(
              controller: _customTypeCtrl,
              hint: 'Enter function type',
            ),
          ],
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
          SaveButton(label: 'Save', color: _funcColor, onTap: _save),
        ],
      ],
    );
  }
}

// ── Quick option chip ──────────────────────────────────────────────────────────
class _QuickOptionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _QuickOptionChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.15)
              : (isDark ? AppColors.surfDark : const Color(0xFFEDEEF5)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? color : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: active ? color : sub),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'Nunito',
                color: active ? color : sub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Preview chip ───────────────────────────────────────────────────────────────
class _FuncPreviewChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _FuncPreviewChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFamily: 'Nunito',
            color: color,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PARSED FUNCTION MODEL
// ─────────────────────────────────────────────────────────────────────────────

class _ParsedFunction {
  final String title;
  final FunctionType type;
  final String? venue, personName, familyName;
  final DateTime? date;
  const _ParsedFunction({
    required this.title,
    required this.type,
    this.venue,
    this.date,
    this.personName,
    this.familyName,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// CLAUDE AI PARSER
// ─────────────────────────────────────────────────────────────────────────────

class _FunctionAIParser {
  static Future<_ParsedFunction> parse(String text, int tabIdx) async {
    final subFeature = tabIdx == 0
        ? 'my_function'
        : tabIdx == 1
        ? 'upcoming_function'
        : 'attended_function';
    final result = await AIParser.parseText(
      feature: 'functions',
      subFeature: subFeature,
      text: text,
    );
    if (!result.success || result.data == null)
      throw Exception(result.error ?? 'AI parse failed');
    final data = result.data!;
    DateTime? date;
    try {
      final raw = data['function_date'] ?? data['date'];
      if (raw != null &&
          raw.toString().isNotEmpty &&
          raw.toString() != 'null') {
        final parsed = DateTime.parse(raw.toString());
        // Sanity check: reject years far outside the current range (e.g. AI hallucination)
        final now = DateTime.now();
        if (parsed.year >= now.year - 1 && parsed.year <= now.year + 10) {
          date = parsed;
        } else {
          // Try to fix a 2-digit-year misparse (e.g. AI returned 2016 instead of 2026)
          final fixed = DateTime(now.year, parsed.month, parsed.day);
          if (fixed.isBefore(now)) {
            date = DateTime(now.year + 1, parsed.month, parsed.day);
          } else {
            date = fixed;
          }
        }
      }
    } catch (_) {}
    const typeMap = {
      'wedding': FunctionType.wedding,
      'birthday': FunctionType.birthday,
      'housewarming': FunctionType.houseWarming,
      'house_warming': FunctionType.houseWarming,
      'house warming': FunctionType.houseWarming,
      'naming': FunctionType.naming,
      'naming_ceremony': FunctionType.naming,
      'ear_piercing': FunctionType.earPiercing,
      'ear piercing': FunctionType.earPiercing,
      'engagement': FunctionType.engagement,
      'graduation': FunctionType.graduation,
      'anniversary': FunctionType.anniversary,
      'puberty': FunctionType.puberty,
      'puberty_ceremony': FunctionType.puberty,
    };
    // upcoming_function prompt returns 'function_type'; others return 'type'
    final rawType = (data['type'] ?? data['function_type'] as String? ?? '')
        .toString()
        .toLowerCase();
    final type = typeMap[rawType] ?? FunctionType.other;
    String? venue =
        (data['venue'] ?? data['function_venue'] ?? data['location'])
            as String?;
    if (venue == 'null' || venue == '') venue = null;
    // upcoming_function prompt returns 'contact_name'; others return 'person_name'
    String? personName =
        (data['person_name'] ??
                data['contact_name'] ??
                data['host_name'] ??
                data['person'])
            as String?;
    if (personName == 'null' || personName == '') personName = null;
    String? familyName =
        (data['family_name'] ?? data['contact_family'] ?? data['family'])
            as String?;
    if (familyName == 'null' || familyName == '') familyName = null;

    return _ParsedFunction(
      title: (data['function_name'] ?? data['title']) as String? ?? text,
      type: type,
      venue: venue,
      date: date,
      personName: personName,
      familyName: familyName,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCAL NLP PARSER  — rule-based fallback, zero network calls
// ─────────────────────────────────────────────────────────────────────────────

class _FunctionNlpParser {
  static _ParsedFunction parse(String raw, int tabIdx) {
    final text = raw.trim();
    final lower = text.toLowerCase();
    final now = DateTime.now();

    FunctionType type = FunctionType.other;
    if (lower.contains('wedding') ||
        lower.contains('marriage') ||
        lower.contains('kalyanam')) {
      type = FunctionType.wedding;
    } else if (lower.contains('birthday') || lower.contains('bday')) {
      type = FunctionType.birthday;
    } else if (lower.contains('housewarming') ||
        lower.contains('graha pravesh')) {
      type = FunctionType.houseWarming;
    } else if (lower.contains('naming') || lower.contains('name ceremony')) {
      type = FunctionType.naming;
    } else if (lower.contains('engagement') ||
        lower.contains('nichayathartham')) {
      type = FunctionType.engagement;
    } else if (lower.contains('graduation')) {
      type = FunctionType.graduation;
    } else if (lower.contains('anniversary')) {
      type = FunctionType.anniversary;
    } else if (lower.contains('ear piercing') || lower.contains('karnavedha')) {
      type = FunctionType.earPiercing;
    } else if (lower.contains('puberty') || lower.contains('seemantham')) {
      type = FunctionType.puberty;
    }

    DateTime? date;
    if (lower.contains('today')) {
      date = now;
    } else if (lower.contains('tomorrow')) {
      date = now.add(const Duration(days: 1));
    } else if (lower.contains('next week')) {
      date = now.add(const Duration(days: 7));
    } else if (lower.contains('next month')) {
      date = DateTime(now.year, now.month + 1, now.day);
    } else {
      final monthMatch = RegExp(
        r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s*(\d{1,2})?|(\d{1,2})\s*(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)',
        caseSensitive: false,
      ).firstMatch(lower);
      if (monthMatch != null) {
        const months = {
          'jan': 1,
          'feb': 2,
          'mar': 3,
          'apr': 4,
          'may': 5,
          'jun': 6,
          'jul': 7,
          'aug': 8,
          'sep': 9,
          'oct': 10,
          'nov': 11,
          'dec': 12,
        };
        final m1 = monthMatch.group(1)?.toLowerCase().substring(0, 3);
        final m2 = monthMatch.group(4)?.toLowerCase().substring(0, 3);
        final monthKey = m1 ?? m2;
        final month = months[monthKey] ?? now.month;
        final day =
            int.tryParse(monthMatch.group(2) ?? monthMatch.group(3) ?? '') ?? 1;
        date = DateTime(now.year, month, day);
        if (date.isBefore(now)) date = DateTime(now.year + 1, month, day);
      } else {
        final onDay = RegExp(
          r'on (?:the )?(\d{1,2})(?:st|nd|rd|th)?',
        ).firstMatch(lower);
        if (onDay != null) {
          final day = int.parse(onDay.group(1)!);
          date = DateTime(now.year, now.month, day);
          if (date.isBefore(now)) date = DateTime(now.year, now.month + 1, day);
        }
      }
    }

    String? venue;
    final atMatch = RegExp(
      r'at\s+([A-Z][^,\.]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (atMatch != null) venue = atMatch.group(1)?.trim();

    String? personName;
    if (tabIdx == 1) {
      final possessive = RegExp(r"^([A-Za-z]+)'s").firstMatch(text);
      if (possessive != null) personName = possessive.group(1);
    }

    final title = personName != null
        ? "$personName's ${type.label}"
        : type != FunctionType.other
        ? type.label
        : text.split('\n').first;

    return _ParsedFunction(
      title: title,
      type: type,
      venue: venue,
      date: date,
      personName: personName,
    );
  }
}
