import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/services/app_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/shared/widgets/emoji_or_image.dart';
import 'package:wai_life_assistant/data/services/profile_service.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyle_models.dart';
import 'package:wai_life_assistant/core/services/ai_parser.dart';
import 'package:wai_life_assistant/data/services/functions_service.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';
import 'package:wai_life_assistant/shared/utils/ai_limit_snackbar.dart';
import 'package:wai_life_assistant/shared/utils/overlay_toast.dart';
import '../../widgets/life_widgets.dart';
import 'package:wai_life_assistant/features/planit/widgets/plan_widgets.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';
import 'package:wai_life_assistant/core/services/family_notification_trigger.dart';
import 'package:wai_life_assistant/core/services/notification_prefs.dart';
import 'package:wai_life_assistant/features/AppStateNotifier.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'my_functions_gift_and_groups.dart';
part 'my_functions_our_view.dart';
part 'my_functions_planned_detail.dart';
part 'my_functions_detail.dart';
part 'my_functions_attended_upcoming.dart';
part 'my_functions_moi_tab.dart';
part 'my_functions_add_sheet.dart';
part 'my_functions_nlp_parser.dart';

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

  /// Full family wallet map — always populated regardless of current view.
  final Map<String, String> allFamilyWalletNames;

  /// Personal wallet ID — needed by edit sheets to offer "Move to Personal".
  final String personalWalletId;

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
    this.allFamilyWalletNames = const {},
    this.personalWalletId = '',
    this.members = const [],
  });
  @override
  State<MyFunctionsScreen> createState() => _MyFunctionsScreenState();
}

class _MyFunctionsScreenState extends State<MyFunctionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _loading = true;
  bool _ourFunctionsSubTabIsPlanned = true;
  final List<FunctionModel> _functions = [];
  final List<AttendedFunction> _attended = [];
  final List<UpcomingFunction> _upcoming = [];
  final List<AttendedFunctionGroup> _attendedGroups = [];
  final _attendedSearchCtrl = TextEditingController();
  String _attendedSearch = '';

  // All data is scoped to walletId — no client-side filter needed,
  // but keep getters so the rest of the UI code stays unchanged.
  List<FunctionModel> get _myFuncs => _functions;
  List<AttendedFunction> get _myAttended =>
      _attended.where((a) => a.date == null || !a.date!.isAfter(_today)).toList();
  List<UpcomingFunction> get _myUpcoming => _upcoming;

  DateTime get _today => DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  AttendedFunction _upcomingToAttended(UpcomingFunction u) => AttendedFunction(
        id: u.id,
        walletId: u.walletId,
        functionName: u.functionTitle,
        type: u.type,
        personName: u.personName.isNotEmpty ? u.personName : null,
        familyName: u.familyName,
        date: u.date,
        venue: u.venue,
        notes: u.notes,
        gifts: u.plannedGifts,
      );
  // Upcoming items still in the future (or with no date set)
  List<UpcomingFunction> get _activeUpcoming =>
      _myUpcoming.where((u) => u.date == null || !u.date!.isBefore(_today)).toList();
  // Upcoming items whose date has already passed — shown in Attended tab
  List<UpcomingFunction> get _pastUpcoming =>
      _myUpcoming.where((u) => u.date != null && u.date!.isBefore(_today)).toList();

  // Attended-function groups with their member functions attached (client-side join).
  List<AttendedFunctionGroup> get _attendedGroupsWithMembers => _attendedGroups
      .map((g) => g.withFunctions(_myAttended.where((a) => a.groupId == g.id).toList()))
      .where((g) => g.functions.isNotEmpty)
      .toList();

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
      final svc = FunctionsService.instance;

      // MyHubScreen already fetched fetchMyFunctions for every wallet id to
      // build its summary card — reuse that instead of re-fetching the same
      // rows here. This one is a real latency win (these calls are awaited
      // sequentially, not in the Future.wait below).
      List<FunctionModel> loaded;
      if (widget.parentFunctions != null) {
        loaded = List<FunctionModel>.from(widget.parentFunctions!);
      } else {
        final allIds = [widget.walletId, ...widget.familyWalletNames.keys];
        final rawMyResults = await Future.wait(
          allIds.map(
            (id) => svc.fetchMyFunctions(id).catchError((e) {
              debugPrint('[MyFunctions] fetch error for wallet $id: $e');
              return <Map<String, dynamic>>[];
            }),
          ),
        );
        loaded = [];
        for (final row in rawMyResults.expand((r) => r)) {
          try {
            loaded.add(FunctionModel.fromJson(row));
          } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'my_functions_parse_error');
            debugPrint('[MyFunctions] parse error: $e | row: $row');
          }
        }
      }

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
      final rawAttendedGroups = await svc.fetchAttendedGroups(widget.walletId).catchError((
        e,
      ) {
        debugPrint('[MyFunctions] fetch attended groups error: $e');
        return <Map<String, dynamic>>[];
      });
      if (!mounted) return;

      final upcoming = <UpcomingFunction>[];
      for (final row in rawUpcoming) {
        try {
          upcoming.add(UpcomingFunction.fromJson(row));
        } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'my_functions_upcoming_parse_error');
          debugPrint('[MyFunctions] upcoming parse error: $e | row: $row');
        }
      }
      final attended = <AttendedFunction>[];
      for (final row in rawAttended) {
        try {
          attended.add(AttendedFunction.fromJson(row));
        } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'my_functions_attended_parse_error');
          debugPrint('[MyFunctions] attended parse error: $e | row: $row');
        }
      }
      final attendedGroups = <AttendedFunctionGroup>[];
      for (final row in rawAttendedGroups) {
        try {
          attendedGroups.add(AttendedFunctionGroup.fromRow(row));
        } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'my_functions_attended_group_parse_error');
          debugPrint('[MyFunctions] attended group parse error: $e | row: $row');
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
        _attendedGroups
          ..clear()
          ..addAll(attendedGroups);
        _attended
          ..clear()
          ..addAll(attended);
        _loading = false;
      });
      return;
    }

    List<Map<String, dynamic>>? rawFunctions;
    List<Map<String, dynamic>> rawUpcoming = [];
    List<Map<String, dynamic>> rawAttended = [];
    List<Map<String, dynamic>> rawAttendedGroups = [];
    try {
      final svc = FunctionsService.instance;
      // Skip re-fetching functions when MyHubScreen already loaded them for
      // this wallet — saves one query even though it doesn't shorten wall
      // time here (the calls below run concurrently either way).
      final results = await Future.wait([
        if (widget.parentFunctions == null) svc.fetchMyFunctions(widget.walletId),
        svc.fetchUpcoming(widget.walletId),
        svc.fetchAttended(widget.walletId),
        svc.fetchAttendedGroups(widget.walletId),
      ]);
      final offset = widget.parentFunctions == null ? 1 : 0;
      if (offset == 1) rawFunctions = results[0];
      rawUpcoming = results[offset];
      rawAttended = results[offset + 1];
      rawAttendedGroups = results[offset + 2];
    } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'my_functions_fetch_error');
      debugPrint('[MyFunctions] fetch error: $e');
    }
    if (!mounted) return;

    // Parse each list independently — a failure in one must not block others.
    final functions = widget.parentFunctions != null
        ? List<FunctionModel>.from(widget.parentFunctions!)
        : <FunctionModel>[];
    for (final row in rawFunctions ?? const <Map<String, dynamic>>[]) {
      try {
        functions.add(FunctionModel.fromJson(row));
      } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'my_functions_functions_parse_error');
        debugPrint('[MyFunctions] functions parse error: $e | row: $row');
      }
    }
    final upcoming = <UpcomingFunction>[];
    for (final row in rawUpcoming) {
      try {
        upcoming.add(UpcomingFunction.fromJson(row));
      } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'my_functions_upcoming_parse_error');
        debugPrint('[MyFunctions] upcoming parse error: $e | row: $row');
      }
    }
    final attended = <AttendedFunction>[];
    for (final row in rawAttended) {
      try {
        attended.add(AttendedFunction.fromJson(row));
      } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'my_functions_attended_parse_error');
        debugPrint('[MyFunctions] attended parse error: $e | row: $row');
      }
    }
    final attendedGroups = <AttendedFunctionGroup>[];
    for (final row in rawAttendedGroups) {
      try {
        attendedGroups.add(AttendedFunctionGroup.fromRow(row));
      } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'my_functions_attended_group_parse_error');
        debugPrint('[MyFunctions] attended group parse error: $e | row: $row');
      }
    }

    setState(() {
      _functions
        ..clear()
        ..addAll(functions);
      _upcoming
        ..clear()
        ..addAll(upcoming);
      _attendedGroups
        ..clear()
        ..addAll(attendedGroups);
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
            Tab(text: 'Upcoming (${_activeUpcoming.length})'),
            Tab(text: 'Attended (${_myAttended.length + _pastUpcoming.length})'),
            Tab(text: 'Our Functions (${_myFuncs.length})'),
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
                // UPCOMING tab (index 0)
                _activeUpcoming.isEmpty
                    ? const PlanEmptyState(
                        emoji: '📅',
                        title: 'No upcoming functions',
                        subtitle: 'Plan for functions you\'re attending',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: _activeUpcoming.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: SwipeTile(
                            onDelete: () async {
                              HapticFeedback.mediumImpact();
                              final item = _activeUpcoming[i];
                              setState(() => _upcoming.remove(item));
                              try {
                                await FunctionsService.instance.deleteUpcoming(item.id);
                              } catch (e, stack) {
                                ErrorLogger.log(e, stackTrace: stack, action: 'delete_upcoming_function');
                                if (!mounted) return;
                                setState(() => _upcoming.add(item));
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Failed to delete function')),
                                );
                              }
                            },
                            child: _UpcomingCard(
                              item: _activeUpcoming[i],
                              isDark: isDark,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _UpcomingDetail(
                                    item: _activeUpcoming[i],
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

                // ATTENDED tab (index 1)
                Builder(
                  builder: (context) {
                    final q = _attendedSearch.toLowerCase();
                    final filtered = _myAttended.where((a) {
                      if (q.isEmpty) return true;
                      return a.functionName.toLowerCase().contains(q) ||
                          (a.venue?.toLowerCase().contains(q) ?? false) ||
                          a.type.label.toLowerCase().contains(q) ||
                          (a.personName?.toLowerCase().contains(q) ?? false) ||
                          a.gifts.any((g) => g.category.toLowerCase().contains(q));
                    }).toList();
                    final past = q.isEmpty
                        ? _pastUpcoming
                        : _pastUpcoming.where((u) =>
                            u.functionTitle.toLowerCase().contains(q) ||
                            u.personName.toLowerCase().contains(q) ||
                            (u.venue?.toLowerCase().contains(q) ?? false) ||
                            u.type.label.toLowerCase().contains(q) ||
                            u.plannedGifts.any((g) => g.category.toLowerCase().contains(q))).toList();
                    // Grouping is only shown while not searching, so search always
                    // surfaces a flat, easy-to-scan result list.
                    final groups = q.isEmpty ? _attendedGroupsWithMembers : const <AttendedFunctionGroup>[];
                    final ungroupedFiltered =
                        q.isEmpty ? filtered.where((a) => a.groupId == null).toList() : filtered;
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
                          child: (filtered.isEmpty && past.isEmpty && groups.isEmpty)
                              ? PlanEmptyState(
                                  emoji: '✅',
                                  title: _attendedSearch.isNotEmpty
                                      ? 'No results for "$_attendedSearch"'
                                      : 'No attended functions recorded',
                                  subtitle: _attendedSearch.isNotEmpty
                                      ? 'Try a different search'
                                      : 'Track functions you\'ve attended and what you gave',
                                )
                              : ListView(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                                  children: [
                                    for (final group in groups)
                                      _AttendedGroupCard(
                                        group: group,
                                        isDark: isDark,
                                        onFunctionTap: (fn) => _showEditAttended(
                                          context,
                                          isDark,
                                          surfBg,
                                          fn,
                                        ),
                                        onRename: (name, emoji) =>
                                            _renameAttendedGroup(group, name, emoji),
                                        onDeleteGroup: () => _deleteAttendedGroup(group),
                                      ),
                                    for (final item in past)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: SwipeTile(
                                          onDelete: () async {
                                            HapticFeedback.mediumImpact();
                                            setState(() => _upcoming.remove(item));
                                            try {
                                              await FunctionsService.instance.deleteUpcoming(item.id);
                                            } catch (e, stack) {
                                              ErrorLogger.log(e, stackTrace: stack, action: 'delete_past_upcoming_function');
                                              if (!mounted) return;
                                              setState(() => _upcoming.add(item));
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Failed to delete function')),
                                              );
                                            }
                                          },
                                          child: _AttendedCard(
                                            item: _upcomingToAttended(item),
                                            isDark: isDark,
                                            onTap: () => _showConvertToAttended(
                                              context,
                                              isDark,
                                              surfBg,
                                              item,
                                            ),
                                          ),
                                        ),
                                      ),
                                    for (int i = 0; i < ungroupedFiltered.length; i++)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: SwipeTile(
                                          onDelete: () async {
                                            HapticFeedback.mediumImpact();
                                            final item = ungroupedFiltered[i];
                                            setState(() => _attended.remove(item));
                                            try {
                                              await FunctionsService.instance.deleteAttended(item.id);
                                            } catch (e, stack) {
                                              ErrorLogger.log(e, stackTrace: stack, action: 'delete_attended_function');
                                              if (!mounted) return;
                                              setState(() => _attended.add(item));
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Failed to delete function')),
                                              );
                                            }
                                          },
                                          child: _AttendedCard(
                                            item: ungroupedFiltered[i],
                                            isDark: isDark,
                                            onTap: () => _showEditAttended(
                                              context,
                                              isDark,
                                              surfBg,
                                              ungroupedFiltered[i],
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      ],
                    );
                  },
                ),

                // OUR FUNCTIONS tab (index 2)
                _OurFunctionsView(
                  functions: _myFuncs,
                  isDark: isDark,
                  familyWalletNames: widget.familyWalletNames,
                  allFamilyWalletNames: widget.allFamilyWalletNames,
                  currentWalletId: widget.walletId,
                  personalWalletId: widget.personalWalletId,
                  onDelete: (fn) async {
                    HapticFeedback.mediumImpact();
                    setState(() => _functions.remove(fn));
                    try {
                      await FunctionsService.instance.deleteMyFunction(fn.id);
                    } catch (e, stack) {
                      ErrorLogger.log(e, stackTrace: stack, action: 'delete_my_function');
                      if (!mounted) return;
                      setState(() => _functions.add(fn));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to delete function')),
                      );
                    }
                  },
                  onUpdate: () => setState(() {
                    _functions.removeWhere((f) => f.walletId != widget.walletId);
                  }),
                  onSubTabChanged: (isPlanned) =>
                      setState(() => _ourFunctionsSubTabIsPlanned = isPlanned),
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
        isPlannedDefault: tabIdx == 2 ? _ourFunctionsSubTabIsPlanned : true,
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
              gifts,
            ) async {
              final svc = FunctionsService.instance;
              try {
                if (tabIdx == 0) {
                  // UPCOMING tab
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
                  if (mounted) {
                    setState(
                      () => _upcoming.insert(0, UpcomingFunction.fromJson(row)),
                    );
                  }
                  _notifyFamilyOfUpcomingFunction(title, date);
                } else if (tabIdx == 1) {
                  // ATTENDED tab
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
                      gifts: gifts,
                    ).toJson(),
                    personalWalletId: widget.personalWalletId.isNotEmpty
                        ? widget.personalWalletId
                        : widget.walletId,
                  );
                  if (mounted)
                    setState(
                      () => _attended.insert(0, AttendedFunction.fromJson(row)),
                    );
                } else if (tabIdx == 2) {
                  // OUR FUNCTIONS tab
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
                }
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e, stack) {
                final isLimitError = e is FunctionLimitExceededException;
                if (!isLimitError) {
                  ErrorLogger.log(e, stackTrace: stack, action: 'my_functions_save');
                }
                // The sheet is still open on failure (Navigator.pop only
                // runs on success above) — an Overlay toast (not a
                // ScaffoldMessenger SnackBar) is used so the message is
                // actually visible above the still-open sheet instead of
                // stacking invisibly behind it.
                if (ctx.mounted) {
                  showOverlayToast(ctx, isLimitError ? e.toString() : 'Failed to save: $e', backgroundColor: Colors.red);
                }
              }
            },
      ),
    );
  }

  /// Fire-and-forget push to other family members when an upcoming function
  /// is added, if this function's wallet belongs to a family.
  void _notifyFamilyOfUpcomingFunction(String title, DateTime? date) {
    if (!NotificationPrefs.instance.functionsUpcoming) return;
    final appState = AppStateScope.read(context);
    if (appState.isPersonal || appState.families.isEmpty) return;
    final matches = appState.families.where((f) => f.walletId == widget.walletId);
    if (matches.isEmpty) return;
    final family = matches.first;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final memberName = (uid != null ? appState.allMemberNames[uid] : null) ?? 'Someone';
    FamilyNotificationTrigger.notify(
      eventType: 'functions.upcoming_added',
      familyId: family.id,
      eventData: {
        'member_name': memberName,
        'function_name': title,
        'date': date != null ? date.toIso8601String().split('T').first : '',
      },
    );
  }

  // ── Attended function grouping ──────────────────────────────────────────

  Future<void> _assignAttendedToGroup(
    AttendedFunction item,
    AttendedFunctionGroup group,
  ) async {
    try {
      var groupId = group.id;
      if (groupId.isEmpty) {
        final row = await FunctionsService.instance.createAttendedGroup(
          walletId: widget.walletId,
          name: group.name,
          emoji: group.emoji,
        );
        groupId = row['id'] as String;
        if (mounted) {
          setState(() => _attendedGroups.add(AttendedFunctionGroup.fromRow(row)));
        }
      }
      await FunctionsService.instance.setAttendedGroup(item.id, groupId);
      if (mounted) setState(() => item.groupId = groupId);
    } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'my_functions_assign_group_error');
      debugPrint('[Functions] assign group error: $e');
    }
  }

  Future<void> _showAttendedGroupPicker(BuildContext ctx, bool isDark, AttendedFunction item) {
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    return showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => _AttendedGroupPickerSheet(
        isDark: isDark,
        bg: bg,
        sub: sub,
        tc: tc,
        groups: _attendedGroups,
        onPick: (g) => _assignAttendedToGroup(item, g),
      ),
    );
  }

  Future<void> _renameAttendedGroup(
    AttendedFunctionGroup group,
    String name,
    String emoji,
  ) async {
    try {
      await FunctionsService.instance.updateAttendedGroup(group.id, name: name, emoji: emoji);
      if (!mounted) return;
      setState(() {
        final idx = _attendedGroups.indexWhere((g) => g.id == group.id);
        if (idx != -1) {
          _attendedGroups[idx] = AttendedFunctionGroup(
            id: group.id,
            walletId: group.walletId,
            name: name,
            emoji: emoji,
          );
        }
      });
    } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'my_functions_rename_group_error');
      debugPrint('[Functions] rename group error: $e');
    }
  }

  Future<void> _deleteAttendedGroup(AttendedFunctionGroup group) async {
    try {
      await FunctionsService.instance.deleteAttendedGroup(group.id);
      if (!mounted) return;
      setState(() {
        _attendedGroups.removeWhere((g) => g.id == group.id);
        for (final a in _attended) {
          if (a.groupId == group.id) a.groupId = null;
        }
      });
    } catch (e, stack) { ErrorLogger.log(e, stackTrace: stack, action: 'my_functions_delete_group_error');
      debugPrint('[Functions] delete group error: $e');
    }
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

    showPlanSheet(
      ctx,
      child: StatefulBuilder(
        builder: (sheetCtx, ss) {
          final sub = isDark ? AppColors.subDark : AppColors.subLight;
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
                const SizedBox(height: 8),
                // ── Group (e.g. bundle by family) ──
                GestureDetector(
                  onTap: () => _showAttendedGroupPicker(sheetCtx, isDark, item).then(
                    (_) => ss(() {}),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: surfBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.folder_special_outlined, size: 18, color: _funcColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.groupId != null
                                ? _attendedGroups
                                      .firstWhere(
                                        (g) => g.id == item.groupId,
                                        orElse: () => AttendedFunctionGroup(
                                          id: '',
                                          walletId: '',
                                          name: 'Group',
                                          emoji: '👨‍👩‍👧',
                                        ),
                                      )
                                      .name
                                : 'Add to Group',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Nunito',
                              color: item.groupId != null ? _funcColor : sub,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 18, color: sub),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // ── What was given ──
                _GiftEntryEditor(
                  gifts: item.gifts,
                  funcColor: _funcColor,
                  onChanged: () => ss(() {}),
                ),
                SaveButton(
                  label: 'Save Changes',
                  color: _funcColor,
                  onTap: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final newDate = date;
                    final isFuture = newDate != null && newDate.isAfter(_today);
                    setState(() {
                      item.functionName = nameCtrl.text.trim();
                      item.personName = personCtrl.text.trim().isEmpty
                          ? null
                          : personCtrl.text.trim();
                      item.familyName = familyNameCtrl.text.trim().isEmpty
                          ? null
                          : familyNameCtrl.text.trim();
                      item.type = type;
                      item.date = newDate;
                      item.venue = venueCtrl.text.trim().isEmpty
                          ? null
                          : venueCtrl.text.trim();
                    });
                    if (isFuture) {
                      // Date moved to the future — promote to Upcoming locally first
                      final localUpcoming = UpcomingFunction(
                        id: item.id,
                        walletId: item.walletId,
                        personName: item.personName ?? '',
                        familyName: item.familyName,
                        functionTitle: item.functionName,
                        memberId: 'me',
                        type: item.type,
                        date: newDate,
                        venue: item.venue,
                        notes: item.notes,
                        plannedGifts: item.gifts,
                      );
                      setState(() {
                        _attended.remove(item);
                        _upcoming.add(localUpcoming);
                      });
                      // Persist: insert into upcoming, soft-delete from attended
                      final upcomingData = {
                        'wallet_id': item.walletId,
                        'type': item.type.name,
                        'person_name': item.personName ?? '',
                        if (item.familyName != null) 'family_name': item.familyName,
                        'function_title': item.functionName,
                        'date': newDate.toIso8601String().split('T')[0],
                        if (item.venue != null) 'venue': item.venue,
                        if (item.notes != null) 'notes': item.notes,
                        'planned_gifts': item.gifts.map((g) => g.toJson()).toList(),
                      };
                      FunctionsService.instance.addUpcoming(upcomingData)
                          .then((inserted) {
                            // Update the local id to the real DB id
                            final idx = _upcoming.indexOf(localUpcoming);
                            if (idx != -1) {
                              setState(() => _upcoming[idx] = UpcomingFunction(
                                id: inserted['id'] as String? ?? localUpcoming.id,
                                walletId: localUpcoming.walletId,
                                personName: localUpcoming.personName,
                                familyName: localUpcoming.familyName,
                                functionTitle: localUpcoming.functionTitle,
                                memberId: 'me',
                                type: localUpcoming.type,
                                date: localUpcoming.date,
                                venue: localUpcoming.venue,
                                notes: localUpcoming.notes,
                                plannedGifts: localUpcoming.plannedGifts,
                              ));
                            }
                            FunctionsService.instance.deleteAttended(item.id)
                                .catchError((e) => debugPrint('[Functions] deleteAttended failed: $e'));
                          })
                          .catchError((e) {
                            debugPrint('[Functions] addUpcoming failed: $e');
                            if (!mounted) return;
                            // Never actually persisted — undo the optimistic
                            // move so the UI doesn't show it in Upcoming while
                            // the DB still has it in Attended.
                            setState(() {
                              _upcoming.remove(localUpcoming);
                              _attended.add(item);
                            });
                            showOverlayToast(
                              context,
                              e is FunctionLimitExceededException ? e.toString() : 'Failed to reschedule. Please try again.',
                              backgroundColor: Colors.red,
                            );
                          });
                    } else {
                      await FunctionsService.instance.updateAttended(
                        item.id,
                        item.toJson(),
                        personalWalletId: widget.personalWalletId.isNotEmpty
                            ? widget.personalWalletId
                            : widget.walletId,
                      );
                    }
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

  void _showConvertToAttended(
    BuildContext ctx,
    bool isDark,
    Color surfBg,
    UpcomingFunction source,
  ) {
    final item = _upcomingToAttended(source);
    final nameCtrl = TextEditingController(text: item.functionName);
    final personCtrl = TextEditingController(text: item.personName ?? '');
    final familyNameCtrl = TextEditingController(text: item.familyName ?? '');
    final venueCtrl = TextEditingController(text: item.venue ?? '');
    var type = item.type;
    DateTime? date = item.date;

    showPlanSheet(
      ctx,
      child: StatefulBuilder(
        builder: (sheetCtx, ss) {
          final sub = isDark ? AppColors.subDark : AppColors.subLight;
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
                                  Text(t.emoji, style: const TextStyle(fontSize: 14)),
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
                PlanInputField(controller: personCtrl, hint: 'Person name (e.g. Priya)'),
                const SizedBox(height: 8),
                PlanInputField(controller: familyNameCtrl, hint: 'Family name (e.g. Sharma family)'),
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
                _GiftEntryEditor(
                  gifts: item.gifts,
                  funcColor: _funcColor,
                  onChanged: () => ss(() {}),
                ),
                SaveButton(
                  label: 'Save Changes',
                  color: _funcColor,
                  onTap: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    item
                      ..functionName = nameCtrl.text.trim()
                      ..personName = personCtrl.text.trim().isEmpty ? null : personCtrl.text.trim()
                      ..familyName = familyNameCtrl.text.trim().isEmpty ? null : familyNameCtrl.text.trim()
                      ..type = type
                      ..date = date
                      ..venue = venueCtrl.text.trim().isEmpty ? null : venueCtrl.text.trim();
                    try {
                      final row = await FunctionsService.instance.addAttended(
                        item.toJson(),
                        personalWalletId: widget.personalWalletId.isNotEmpty
                            ? widget.personalWalletId
                            : widget.walletId,
                      );
                      await FunctionsService.instance.deleteUpcoming(source.id);
                      if (mounted) {
                        setState(() {
                          _upcoming.remove(source);
                          _attended.insert(0, AttendedFunction.fromJson(row));
                        });
                      }
                    } catch (e, stack) {
                      debugPrint('[Functions] convert error: $e');
                      final isLimitError = e is FunctionLimitExceededException;
                      if (!isLimitError) {
                        ErrorLogger.log(e, stackTrace: stack, action: 'my_functions_convert_error');
                      }
                      if (ctx.mounted) {
                        showOverlayToast(
                          ctx,
                          isLimitError ? e.toString() : 'Failed to convert. Please try again.',
                          backgroundColor: Colors.red,
                        );
                      }
                      return; // keep the sheet open so the user knows it didn't save
                    }
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
