import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';
import 'package:wai_life_assistant/core/supabase/special_day_service.dart';
import 'package:wai_life_assistant/core/services/network_service.dart';
import 'package:wai_life_assistant/services/ai_parser.dart';
import '../../widgets/plan_widgets.dart';
import 'package:wai_life_assistant/core/widgets/emoji_or_image.dart';

// ─────────────────────────────────────────────────────────────────────────────
// REGION PRESET DATA
// ─────────────────────────────────────────────────────────────────────────────

class _PresetDay {
  final String title, emoji;
  final int month, day;
  const _PresetDay(this.title, this.emoji, this.month, this.day);
}

class _RegionPreset {
  final String region, flag, countryCode;
  final List<_PresetDay> govtHolidays, festivals;
  const _RegionPreset({
    required this.region,
    required this.flag,
    required this.countryCode,
    required this.govtHolidays,
    required this.festivals,
  });
}

// Universal public holidays (UN-designated)
const _universalHolidays = <_PresetDay>[
  _PresetDay("New Year's Day", '🎆', 1, 1),
  _PresetDay('International Workers Day', '⚒️', 5, 1),
  _PresetDay("International Women's Day", '👩', 3, 8),
  _PresetDay('World Environment Day', '🌿', 6, 5),
  _PresetDay('World Health Day', '❤️', 4, 7),
  _PresetDay('Human Rights Day', '✊', 12, 10),
  _PresetDay('International Peace Day', '🕊️', 9, 21),
  _PresetDay('Christmas Day', '🎄', 12, 25),
];

const _regionPresets = <_RegionPreset>[
  _RegionPreset(
    region: 'India',
    flag: '🇮🇳',
    countryCode: 'IN',
    govtHolidays: [
      _PresetDay('Republic Day', '🇮🇳', 1, 26),
      _PresetDay('Independence Day', '🇮🇳', 8, 15),
      _PresetDay('Gandhi Jayanti', '🕊️', 10, 2),
      _PresetDay('Ambedkar Jayanti', '📖', 4, 14),
      _PresetDay('Christmas Day', '🎄', 12, 25),
    ],
    festivals: [
      _PresetDay('Diwali', '🪔', 11, 1),
      _PresetDay('Holi', '🎨', 3, 25),
      _PresetDay('Eid ul-Fitr', '🌙', 4, 10),
      _PresetDay('Durga Puja', '🙏', 10, 2),
      _PresetDay('Navratri', '💃', 10, 3),
      _PresetDay('Dussehra', '🏹', 10, 12),
      _PresetDay('Raksha Bandhan', '🧡', 8, 19),
      _PresetDay('Janmashtami', '🦚', 8, 26),
      _PresetDay('Ganesh Chaturthi', '🐘', 9, 7),
      _PresetDay('Pongal', '🌾', 1, 14),
      _PresetDay('Onam', '🌸', 8, 29),
      _PresetDay('Baisakhi', '🌾', 4, 13),
      _PresetDay('Guru Nanak Jayanti', '🙏', 11, 15),
      _PresetDay('Mahavir Jayanti', '🕊️', 4, 21),
      _PresetDay('Buddha Purnima', '🙏', 5, 23),
      _PresetDay('Christmas', '🎄', 12, 25),
    ],
  ),
  _RegionPreset(
    region: 'United States',
    flag: '🇺🇸',
    countryCode: 'US',
    govtHolidays: [
      _PresetDay("New Year's Day", '🎆', 1, 1),
      _PresetDay('Martin Luther King Day', '✊', 1, 20),
      _PresetDay("Presidents' Day", '🇺🇸', 2, 17),
      _PresetDay('Memorial Day', '🕊️', 5, 26),
      _PresetDay('Juneteenth', '✊', 6, 19),
      _PresetDay('Independence Day', '🎆', 7, 4),
      _PresetDay('Labor Day', '⚒️', 9, 1),
      _PresetDay('Columbus Day', '🗺️', 10, 13),
      _PresetDay('Veterans Day', '🎖️', 11, 11),
      _PresetDay('Thanksgiving', '🦃', 11, 27),
      _PresetDay('Christmas Day', '🎄', 12, 25),
    ],
    festivals: [
      _PresetDay('Valentine\'s Day', '❤️', 2, 14),
      _PresetDay('St. Patrick\'s Day', '☘️', 3, 17),
      _PresetDay('Easter', '🐣', 4, 20),
      _PresetDay('Mother\'s Day', '🌷', 5, 11),
      _PresetDay('Father\'s Day', '👔', 6, 15),
      _PresetDay('Halloween', '🎃', 10, 31),
      _PresetDay('Hanukkah', '🕎', 12, 26),
    ],
  ),
  _RegionPreset(
    region: 'United Kingdom',
    flag: '🇬🇧',
    countryCode: 'GB',
    govtHolidays: [
      _PresetDay("New Year's Day", '🎆', 1, 1),
      _PresetDay('Good Friday', '🙏', 4, 18),
      _PresetDay('Easter Monday', '🐣', 4, 21),
      _PresetDay('Early May Bank Holiday', '🌷', 5, 5),
      _PresetDay('Spring Bank Holiday', '🌸', 5, 26),
      _PresetDay('Summer Bank Holiday', '☀️', 8, 25),
      _PresetDay('Christmas Day', '🎄', 12, 25),
      _PresetDay('Boxing Day', '🎁', 12, 26),
    ],
    festivals: [
      _PresetDay('Burns Night', '🏴󠁧󠁢󠁳󠁣󠁴󠁿', 1, 25),
      _PresetDay('Valentine\'s Day', '❤️', 2, 14),
      _PresetDay('St. Patrick\'s Day', '☘️', 3, 17),
      _PresetDay('St. George\'s Day', '🏴󠁧󠁢󠁥󠁮󠁧󠁿', 4, 23),
      _PresetDay('Guy Fawkes Night', '🎆', 11, 5),
      _PresetDay('Remembrance Day', '🌹', 11, 11),
    ],
  ),
  _RegionPreset(
    region: 'Australia',
    flag: '🇦🇺',
    countryCode: 'AU',
    govtHolidays: [
      _PresetDay("New Year's Day", '🎆', 1, 1),
      _PresetDay('Australia Day', '🇦🇺', 1, 27),
      _PresetDay('Good Friday', '🙏', 4, 18),
      _PresetDay('Easter Monday', '🐣', 4, 21),
      _PresetDay('ANZAC Day', '🌹', 4, 25),
      _PresetDay('Queen\'s Birthday', '👑', 6, 9),
      _PresetDay('Christmas Day', '🎄', 12, 25),
      _PresetDay('Boxing Day', '🎁', 12, 26),
    ],
    festivals: [
      _PresetDay('Australia Day', '🇦🇺', 1, 26),
      _PresetDay('Valentine\'s Day', '❤️', 2, 14),
      _PresetDay('Mother\'s Day', '🌷', 5, 11),
      _PresetDay('Father\'s Day', '👔', 9, 7),
      _PresetDay('Halloween', '🎃', 10, 31),
      _PresetDay('Melbourne Cup Day', '🏇', 11, 4),
    ],
  ),
  _RegionPreset(
    region: 'Germany',
    flag: '🇩🇪',
    countryCode: 'DE',
    govtHolidays: [
      _PresetDay("New Year's Day", '🎆', 1, 1),
      _PresetDay('Good Friday', '🙏', 4, 18),
      _PresetDay('Easter Monday', '🐣', 4, 21),
      _PresetDay('Labour Day', '⚒️', 5, 1),
      _PresetDay('Ascension Day', '🙏', 5, 29),
      _PresetDay('Whit Monday', '🌿', 6, 9),
      _PresetDay('German Unity Day', '🇩🇪', 10, 3),
      _PresetDay('Christmas Day', '🎄', 12, 25),
      _PresetDay('Boxing Day', '🎁', 12, 26),
    ],
    festivals: [
      _PresetDay('Carnival / Karneval', '🎭', 3, 4),
      _PresetDay('Valentine\'s Day', '❤️', 2, 14),
      _PresetDay('Easter', '🐣', 4, 20),
      _PresetDay('Oktoberfest', '🍺', 9, 20),
      _PresetDay('St. Martin\'s Day', '🕯️', 11, 11),
      _PresetDay('St. Nicholas Day', '🎅', 12, 6),
      _PresetDay('Christmas Eve', '🎄', 12, 24),
    ],
  ),
  _RegionPreset(
    region: 'Japan',
    flag: '🇯🇵',
    countryCode: 'JP',
    govtHolidays: [
      _PresetDay("New Year's Day", '🎍', 1, 1),
      _PresetDay('Coming of Age Day', '👘', 1, 13),
      _PresetDay('National Foundation', '🇯🇵', 2, 11),
      _PresetDay('Emperor\'s Birthday', '👑', 2, 23),
      _PresetDay('Vernal Equinox', '🌸', 3, 20),
      _PresetDay('Showa Day', '🏯', 4, 29),
      _PresetDay('Constitution Day', '📜', 5, 3),
      _PresetDay('Greenery Day', '🌿', 5, 4),
      _PresetDay('Children\'s Day', '🎏', 5, 5),
      _PresetDay('Marine Day', '🌊', 7, 21),
      _PresetDay('Mountain Day', '⛰️', 8, 11),
      _PresetDay('Respect for the Aged', '🧓', 9, 15),
      _PresetDay('Sports Day', '🏅', 10, 13),
      _PresetDay('Culture Day', '🎌', 11, 3),
      _PresetDay('Labour Day', '⚒️', 11, 23),
    ],
    festivals: [
      _PresetDay('Oshogatsu (New Year)', '🎍', 1, 1),
      _PresetDay('Setsubun', '🫘', 2, 3),
      _PresetDay('Hinamatsuri', '🎎', 3, 3),
      _PresetDay('Cherry Blossom', '🌸', 3, 25),
      _PresetDay('Golden Week', '🎏', 4, 29),
      _PresetDay('Tanabata', '🌠', 7, 7),
      _PresetDay('Obon Festival', '🏮', 8, 13),
      _PresetDay('Shichi-Go-San', '🧒', 11, 15),
    ],
  ),
  _RegionPreset(
    region: 'UAE',
    flag: '🇦🇪',
    countryCode: 'AE',
    govtHolidays: [
      _PresetDay("New Year's Day", '🎆', 1, 1),
      _PresetDay('Eid ul-Fitr', '🌙', 3, 30),
      _PresetDay('Eid ul-Adha', '🌙', 6, 6),
      _PresetDay('Islamic New Year', '🌙', 7, 27),
      _PresetDay('Prophet\'s Birthday', '🌙', 9, 4),
      _PresetDay('Commemoration Day', '🇦🇪', 12, 1),
      _PresetDay('UAE National Day', '🇦🇪', 12, 2),
    ],
    festivals: [
      _PresetDay('Dubai Shopping Festival', '🛍️', 1, 15),
      _PresetDay('Ramadan', '🌙', 3, 1),
      _PresetDay('Dubai Food Festival', '🍽️', 3, 20),
      _PresetDay('Abu Dhabi Festival', '🎭', 4, 1),
      _PresetDay('Dubai Summer Surprises', '☀️', 6, 25),
    ],
  ),
  _RegionPreset(
    region: 'Singapore',
    flag: '🇸🇬',
    countryCode: 'SG',
    govtHolidays: [
      _PresetDay("New Year's Day", '🎆', 1, 1),
      _PresetDay('Chinese New Year', '🧧', 1, 29),
      _PresetDay('Good Friday', '🙏', 4, 18),
      _PresetDay('Hari Raya Puasa', '🌙', 3, 31),
      _PresetDay('Labour Day', '⚒️', 5, 1),
      _PresetDay('Vesak Day', '🙏', 5, 12),
      _PresetDay('Hari Raya Haji', '🌙', 6, 6),
      _PresetDay('National Day', '🇸🇬', 8, 9),
      _PresetDay('Deepavali', '🪔', 10, 20),
      _PresetDay('Christmas Day', '🎄', 12, 25),
    ],
    festivals: [
      _PresetDay('Chingay Parade', '🎭', 2, 1),
      _PresetDay('Mid-Autumn Festival', '🥮', 9, 6),
      _PresetDay('Singapore Grand Prix', '🏎️', 9, 20),
      _PresetDay('ZoukOut', '🎵', 12, 6),
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class SpecialDaysScreen extends StatefulWidget {
  final String walletId;
  final String walletName;
  final String walletEmoji;
  final List<PlanMember> members;
  final List<SpecialDayModel> days;
  final bool openAdd;
  /// Family wallet ID → display label. Non-empty only in Personal view.
  final Map<String, String> familyWalletNames;
  const SpecialDaysScreen({
    super.key,
    required this.walletId,
    this.walletName = 'Personal',
    this.walletEmoji = '👤',
    this.members = const [],
    required this.days,
    this.openAdd = false,
    this.familyWalletNames = const {},
  });
  @override
  State<SpecialDaysScreen> createState() => _SpecialDaysScreenState();
}

class _SpecialDaysScreenState extends State<SpecialDaysScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<SpecialDayModel> _days = [];
  bool _loading = false;
  bool _wasOnline = true;
  SpecialDayType? _filterType;

  List<SpecialDayModel> get _mine => _days;

  List<SpecialDayModel> get _filtered {
    var list = _mine;
    if (_filterType != null) {
      list = list.where((d) => d.type == _filterType).toList();
    }
    return list;
  }

  // This year's date — never jumps to next year.
  DateTime _thisYear(DateTime date) =>
      DateTime(DateTime.now().year, date.month, date.day);

  // Next occurrence for countdown display only.
  DateTime _nextOccurrence(DateTime date) {
    final now = DateTime.now();
    final flat = DateTime(now.year, now.month, now.day);
    final ty = _thisYear(date);
    return ty.isBefore(flat)
        ? DateTime(now.year + 1, date.month, date.day)
        : ty;
  }

  List<SpecialDayModel> _upcoming() {
    final flat = DateTime.now();
    final today = DateTime(flat.year, flat.month, flat.day);
    // Yearly-recurring events always appear in Upcoming (next occurrence may be next year).
    // One-off events appear here only if this year's date hasn't passed yet.
    return _filtered
        .where((d) => d.yearlyRecur || !_thisYear(d.date).isBefore(today))
        .toList()
      ..sort((a, b) => _nextOccurrence(a.date).compareTo(_nextOccurrence(b.date)));
  }

  List<SpecialDayModel> _past() {
    final flat = DateTime.now();
    final today = DateTime(flat.year, flat.month, flat.day);
    // All events (recurring or not) whose date has already passed this year.
    return _filtered
        .where((d) => _thisYear(d.date).isBefore(today))
        .toList()
      ..sort((a, b) => _thisYear(b.date).compareTo(_thisYear(a.date)));
  }

  void _onNetworkChange() {
    final online = NetworkService.instance.isOnline.value;
    if (online && !_wasOnline) _loadDays();
    _wasOnline = online;
  }

  @override
  void initState() {
    super.initState();
    _wasOnline = NetworkService.instance.isOnline.value;
    NetworkService.instance.isOnline.addListener(_onNetworkChange);
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
    _loadDays();
    if (widget.openAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
        _openAddSheet(context, isDark, surfBg);
      });
    }
  }

  @override
  void dispose() {
    NetworkService.instance.isOnline.removeListener(_onNetworkChange);
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadDays() async {
    if (widget.walletId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    if (widget.walletId == 'personal') {
      // Personal view: fetch independently from personal + all family wallets.
      setState(() => _loading = true);
      try {
        final allIds = ['personal', ...widget.familyWalletNames.keys];
        final results = await Future.wait(
          allIds.map((id) => SpecialDayService.instance.fetchDays(id)),
        );
        if (!mounted) return;
        final loaded = results.expand((rows) => rows.map(SpecialDayModel.fromRow)).toList();
        setState(() {
          _days = loaded;
          widget.days..clear()..addAll(loaded);
          _loading = false;
        });
      } catch (e) {
        debugPrint('[SpecialDays] personal load error: $e');
        if (mounted) setState(() => _loading = false);
      }
      return;
    }
    setState(() => _loading = true);
    try {
      final rows = await SpecialDayService.instance.fetchDays(widget.walletId);
      if (!mounted) return;
      final loaded = rows.map(SpecialDayModel.fromRow).toList();
      setState(() {
        _days = loaded;
        widget.days
          ..clear()
          ..addAll(loaded);
        _loading = false;
      });
    } catch (e) {
      debugPrint('[SpecialDays] load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add(SpecialDayModel d) async {
    try {
      final row = await SpecialDayService.instance.addDay(d.toRow());
      final saved = SpecialDayModel.fromRow(row);
      if (mounted) setState(() => _days.add(saved));
    } catch (e) {
      debugPrint('[SpecialDays] add error: $e');
      if (mounted) setState(() => _days.add(d));
    }
  }

  Future<void> _delete(SpecialDayModel d) async {
    setState(() => _days.remove(d));
    try {
      await SpecialDayService.instance.deleteDay(d.id);
    } catch (_) {}
  }

  Future<void> _update(SpecialDayModel updated) async {
    setState(() {
      final i = _days.indexWhere((d) => d.id == updated.id);
      if (i >= 0) _days[i] = updated;
    });
    try {
      await SpecialDayService.instance.updateDay(updated.id, updated.toRow());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final subColor = isDark ? AppColors.subDark : AppColors.subLight;

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
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('🎂', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Special Days',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (widget.walletName != 'Personal')
            Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  EmojiOrImage(value: widget.walletEmoji, size: 18, borderRadius: 4),
                  const SizedBox(width: 5),
                  SizedBox(
                    width: 75,
                    child: Text(
                      widget.walletName,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Nunito',
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tab,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
            fontSize: 12,
          ),
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: subColor,
          tabs: [
            Tab(text: 'Upcoming (${_upcoming().length})'),
            Tab(text: 'Past (${_past().length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context, isDark, surfBg),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Day',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
          ),
        ),
      ),
      body: Column(
        children: [
          // Type filter chips
          _TypeFilter(
            selected: _filterType,
            subColor: subColor,
            onSelect: (t) => setState(() => _filterType = t),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                RefreshIndicator(
                  onRefresh: _loadDays,
                  child: _DayList(
                    key: ValueKey('upcoming-${_upcoming().length}'),
                    days: _upcoming(),
                    isDark: isDark,
                    nextOccurrence: _nextOccurrence,
                    onDelete: _delete,
                    onTap: (d) => _openDetailSheet(context, d, isDark, surfBg),
                    familyWalletNames: widget.familyWalletNames,
                  ),
                ),
                RefreshIndicator(
                  onRefresh: _loadDays,
                  child: _DayList(
                    key: ValueKey('past-${_past().length}'),
                    days: _past(),
                    isDark: isDark,
                    isPast: true,
                    nextOccurrence: _nextOccurrence,
                    onDelete: _delete,
                    onTap: (d) => _openDetailSheet(context, d, isDark, surfBg),
                    familyWalletNames: widget.familyWalletNames,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openAddSheet(BuildContext ctx, bool isDark, Color surfBg) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DaySheetHost(
        isDark: isDark,
        surfBg: surfBg,
        walletId: widget.walletId,
        onSave: _add,
      ),
    );
  }

  void _openDetailSheet(
    BuildContext ctx,
    SpecialDayModel d,
    bool isDark,
    Color surfBg,
  ) {
    showPlanSheet(
      ctx,
      child: _DayDetailSheet(
        day: d,
        isDark: isDark,
        nextOccurrence: _nextOccurrence,
        onDelete: () {
          _delete(d);
          Navigator.pop(ctx);
        },
        onEdit: () {
          Navigator.pop(ctx);
          _openEditSheet(ctx, d, isDark, surfBg);
        },
      ),
    );
  }

  void _openEditSheet(
    BuildContext ctx,
    SpecialDayModel existing,
    bool isDark,
    Color surfBg,
  ) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DaySheetHost(
        isDark: isDark,
        surfBg: surfBg,
        walletId: widget.walletId,
        existing: existing,
        onSave: _update,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TYPE FILTER
// ─────────────────────────────────────────────────────────────────────────────

class _TypeFilter extends StatelessWidget {
  final SpecialDayType? selected;
  final Color subColor;
  final void Function(SpecialDayType?) onSelect;
  const _TypeFilter({
    required this.selected,
    required this.subColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        children: [
          _Pill(
            label: '🌟 All',
            selected: selected == null,
            color: AppColors.primary,
            onTap: () => onSelect(null),
          ),
          ...SpecialDayType.values.map(
            (t) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _Pill(
                label: '${t.emoji} ${t.label}',
                selected: selected == t,
                color: t.color,
                onTap: () => onSelect(selected == t ? null : t),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _Pill({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? color
                : (isDark ? AppColors.surfDark : const Color(0xFFE0E0EC)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFamily: 'Nunito',
            color: selected
                ? color
                : (isDark ? AppColors.subDark : AppColors.subLight),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DAY LIST
// ─────────────────────────────────────────────────────────────────────────────

class _DayList extends StatelessWidget {
  final List<SpecialDayModel> days;
  final bool isDark;
  final bool isPast;
  final DateTime Function(DateTime) nextOccurrence;
  final void Function(SpecialDayModel) onDelete;
  final void Function(SpecialDayModel) onTap;
  final Map<String, String> familyWalletNames;
  const _DayList({
    super.key,
    required this.days,
    required this.isDark,
    required this.nextOccurrence,
    required this.onDelete,
    required this.onTap,
    this.isPast = false,
    this.familyWalletNames = const {},
  });

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return const PlanEmptyState(
        emoji: '📅',
        title: 'Nothing here',
        subtitle: 'Add your special days',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: days.length,
      itemBuilder: (_, i) {
        final d = days[i];
        final familyLabel = familyWalletNames[d.walletId];
        final card = _DayCard(
          day: d,
          isDark: isDark,
          isPast: isPast,
          nextOccurrence: nextOccurrence,
          onTap: familyLabel == null ? () => onTap(d) : () {},
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: familyLabel != null
              ? Stack(
                  children: [
                    card,
                    Positioned(
                      top: 8,
                      right: 8,
                      child: FamilyBadge(label: familyLabel),
                    ),
                  ],
                )
              : SwipeTile(onDelete: () => onDelete(d), child: card),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DAY CARD
// ─────────────────────────────────────────────────────────────────────────────

class _DayCard extends StatelessWidget {
  final SpecialDayModel day;
  final bool isDark;
  final bool isPast;
  final DateTime Function(DateTime) nextOccurrence;
  final VoidCallback onTap;
  const _DayCard({
    required this.day,
    required this.isDark,
    required this.nextOccurrence,
    required this.onTap,
    this.isPast = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final color = day.type.color;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final thisYear = DateTime(today.year, day.date.month, day.date.day);

    String countdown;
    Color countColor;
    if (isPast) {
      final daysAgo = today.difference(thisYear).inDays;
      if (daysAgo == 0) {
        countdown = '🎉 Today!';
        countColor = AppColors.income;
      } else if (daysAgo == 1) {
        countdown = 'Yesterday';
        countColor = AppColors.expense;
      } else {
        countdown = '$daysAgo days ago';
        countColor = sub;
      }
    } else {
      final next = nextOccurrence(day.date);
      final days = next.difference(today).inDays;
      if (days == 0) {
        countdown = '🎉 Today!';
        countColor = AppColors.income;
      } else if (days <= 7) {
        countdown = 'In $days days';
        countColor = AppColors.expense;
      } else if (days <= 30) {
        countdown = 'In $days days';
        countColor = AppColors.lend;
      } else {
        countdown = '${(days / 30).floor()} months away';
        countColor = sub;
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Color strip
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(20),
                ),
              ),
            ),
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
                      color: Colors.black.withOpacity(isDark ? 0.18 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Date badge — shows actual month/day to avoid the
                    // platform 📅 emoji always rendering as "July 17".
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            color: color.withValues(alpha: 0.5),
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              _monthName(day.date.month).substring(0, 3),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Nunito',
                                color: color,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                '${day.date.day}',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'DM Mono',
                                  color: color,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            day.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: tc,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  day.type.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                    color: color,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_monthName(day.date.month)} ${day.date.day}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'Nunito',
                                  color: sub,
                                ),
                              ),
                            ],
                          ),
                          if (day.note != null && day.note!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              day.note!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Nunito',
                                color: sub,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Countdown
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          countdown,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: countColor,
                          ),
                        ),
                        if (day.alertDaysBefore > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.notifications_outlined,
                                size: 11,
                                color: sub,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${day.alertDaysBefore}d before',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'Nunito',
                                  color: sub,
                                ),
                              ),
                            ],
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

// ─────────────────────────────────────────────────────────────────────────────
// DAY DETAIL SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _DayDetailSheet extends StatelessWidget {
  final SpecialDayModel day;
  final bool isDark;
  final DateTime Function(DateTime) nextOccurrence;
  final VoidCallback onDelete, onEdit;
  const _DayDetailSheet({
    required this.day,
    required this.isDark,
    required this.nextOccurrence,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final next = nextOccurrence(day.date);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = next.difference(today).inDays;
    final color = day.type.color;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(day.emoji, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${day.type.emoji} ${day.type.label}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Date + countdown
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_monthName(day.date.month)} ${day.date.day}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito',
                          color: tc,
                        ),
                      ),
                      Text(
                        diff == 0 ? 'Today! 🎉' : 'In $diff days',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Nunito',
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (day.alertDaysBefore > 0)
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_active_outlined,
                        color: color,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${day.alertDaysBefore} days before',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          if (day.note != null && day.note!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              day.note!,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'Nunito',
                color: sub,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Edit button
          GestureDetector(
            onTap: onEdit,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Edit Day',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.expense.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.expense.withOpacity(0.3)),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: AppColors.expense,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Nunito',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET HOST — keyboard-aware wrapper (same pattern as MyTasks)
// ─────────────────────────────────────────────────────────────────────────────

class _DaySheetHost extends StatelessWidget {
  final bool isDark;
  final Color surfBg;
  final String walletId;
  final SpecialDayModel? existing;
  final void Function(SpecialDayModel) onSave;

  const _DaySheetHost({
    required this.isDark,
    required this.surfBg,
    required this.walletId,
    this.existing,
    required this.onSave,
  });

  @override
  Widget build(BuildContext hostCtx) {
    final isEdit = existing != null;
    final mq = MediaQuery.of(hostCtx);
    final kb = mq.viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: kb),
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.92),
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
              child: _AddDaySheet(
                isDark: isDark,
                surfBg: surfBg,
                walletId: walletId,
                existing: existing,
                onSave: (d) {
                  Navigator.pop(hostCtx);
                  onSave(d);
                  ScaffoldMessenger.of(hostCtx).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEdit
                            ? '${d.emoji} "${d.title}" updated!'
                            : '${d.emoji} "${d.title}" added!',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      backgroundColor: AppColors.income,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      margin: const EdgeInsets.all(16),
                      duration: const Duration(seconds: 2),
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
// ADD / EDIT DAY SHEET  — AI Parse + Manual tabs
// ─────────────────────────────────────────────────────────────────────────────

class _AddDaySheet extends StatefulWidget {
  final bool isDark;
  final Color surfBg;
  final String walletId;
  final SpecialDayModel? existing;
  final void Function(SpecialDayModel) onSave;
  const _AddDaySheet({
    required this.isDark,
    required this.surfBg,
    required this.walletId,
    this.existing,
    required this.onSave,
  });
  @override
  State<_AddDaySheet> createState() => _AddDaySheetState();
}

class _AddDaySheetState extends State<_AddDaySheet>
    with SingleTickerProviderStateMixin {
  late TabController _mode;

  // AI
  final _aiCtrl = TextEditingController();
  bool _aiParsing = false;
  _ParsedDay? _aiPreview;
  String? _aiError;
  bool _usingClaude = false;

  // Manual / shared state
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  SpecialDayType _type = SpecialDayType.birthday;
  String _emoji = '🎂';
  DateTime? _date;
  int _remindDays = 1;
  bool _titleError = false;

  // Region / preset
  String _selectedRegion = 'India';

  static const _reminderOptions = [0, 1, 3, 7, 14, 30];

  static const _typeEmojis = <SpecialDayType, List<String>>{
    SpecialDayType.birthday: ['🎂', '🎉', '🎈', '🥳', '🎁', '💐', '🎊', '🫶'],
    SpecialDayType.anniversary: ['💍', '❤️', '🥂', '🌹', '💑', '💝', '🫀', '✨'],
    SpecialDayType.festival: ['🎉', '🎊', '🪔', '🌸', '🎆', '🎎', '🎏', '🏮'],
    SpecialDayType.govtHoliday: [
      '🏛️',
      '🇮🇳',
      '📜',
      '🗳️',
      '⚒️',
      '🌿',
      '✊',
      '🕊️',
    ],
    SpecialDayType.holiday: ['🌟', '🏖️', '🌴', '☀️', '🏕️', '✈️', '⛺', '🎒'],
    SpecialDayType.custom: ['📅', '⭐', '🔖', '💫', '🌈', '🎯', '💡', '🗓️'],
  };

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _mode = TabController(
      length: 2,
      vsync: this,
      initialIndex: e != null ? 1 : 0,
    );
    _mode.addListener(() => setState(() {}));

    if (e != null) {
      _titleCtrl.text = e.title;
      _noteCtrl.text = e.note ?? '';
      _type = e.type;
      _emoji = e.emoji;
      _date = e.date;
      _remindDays = e.alertDaysBefore;
    }
  }

  @override
  void dispose() {
    _mode.dispose();
    _aiCtrl.dispose();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── AI parse ──────────────────────────────────────────────────────────────
  Future<void> _parseAI(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _aiParsing = true;
      _aiError = null;
      _aiPreview = null;
      _usingClaude = false;
    });

    _ParsedDay? result;
    try {
      final aiResult = await AIParser.parseText(
        feature: 'planit',
        subFeature: 'special_day',
        text: text.trim(),
      );
      if (aiResult.success && aiResult.data != null) {
        result = _parsedDayFromAI(aiResult.data!);
        _usingClaude = true;
      } else {
        throw Exception(aiResult.error);
      }
    } catch (_) {
      result = _DayNlpParser.parse(text.trim());
    }

    if (!mounted) return;
    setState(() {
      _aiParsing = false;
      _aiPreview = result;
      _titleCtrl.text = result!.title;
      _noteCtrl.text = result.note ?? '';
      _type = result.type;
      _emoji = result.emoji;
      _date = result.date;
      _remindDays = result.remindDays;
    });
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = true);
      return;
    }
    if (_date == null) {
      setState(() => _titleError = false);
      return;
    }
    setState(() => _titleError = false);
    final e = widget.existing;
    widget.onSave(
      SpecialDayModel(
        id: e?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        emoji: _emoji,
        type: _type,
        date: _date!,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        alertDaysBefore: _remindDays,
        walletId: widget.walletId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final sub = widget.isDark ? AppColors.subDark : AppColors.subLight;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      children: [
        // Header
        Row(
          children: [
            const Text('📅', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Text(
              widget.existing != null ? 'Edit Day' : 'New Special Day',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
                color: tc,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Mode tabs
        Container(
          decoration: BoxDecoration(
            color: widget.surfBg,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(3),
          child: TabBar(
            controller: _mode,
            indicator: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFFFF6B6B)],
              ),
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

        // ── AI TAB ────────────────────────────────────────────────────────
        if (_mode.index == 0) ...[
          _AiHint(isDark: widget.isDark),
          const SizedBox(height: 12),
          _AiInputBox(
            ctrl: _aiCtrl,
            surfBg: widget.surfBg,
            isDark: widget.isDark,
            isParsing: _aiParsing,
            onParse: () => _parseAI(_aiCtrl.text),
          ),
          if (_aiError != null) ...[
            const SizedBox(height: 10),
            _ErrorBanner(message: _aiError!),
          ],
          if (_aiPreview != null) ...[
            const SizedBox(height: 12),
            _AiPreviewCard(
              preview: _aiPreview!,
              isDark: widget.isDark,
              surfBg: widget.surfBg,
              usedClaude: _usingClaude,
              onEdit: () => _mode.animateTo(1),
            ),
            const SizedBox(height: 16),
            SaveButton(
              label: widget.existing != null ? 'Update Day →' : 'Save Day →',
              color: AppColors.primary,
              onTap: _save,
            ),
          ],
          if (_aiPreview == null && !_aiParsing) ...[
            const SizedBox(height: 12),
            _AiExamples(
              surfBg: widget.surfBg,
              sub: sub,
              onTap: (s) {
                _aiCtrl.text = s;
              },
            ),
            const SizedBox(height: 20),
            // Region presets section
            _RegionPresetsPanel(
              isDark: widget.isDark,
              surfBg: widget.surfBg,
              selectedRegion: _selectedRegion,
              onRegionChanged: (r) => setState(() => _selectedRegion = r),
              onPresetTap: (preset, type) {
                final now = DateTime.now();
                setState(() {
                  _titleCtrl.text = preset.title;
                  _emoji = preset.emoji;
                  _type = type;
                  _date = DateTime(now.year, preset.month, preset.day);
                  _remindDays = 7;
                });
                _mode.animateTo(1);
              },
            ),
          ],
        ],

        // ── MANUAL TAB ────────────────────────────────────────────────────
        if (_mode.index == 1) ...[
          _ManualForm(
            isDark: widget.isDark,
            surfBg: widget.surfBg,
            titleCtrl: _titleCtrl,
            noteCtrl: _noteCtrl,
            type: _type,
            emoji: _emoji,
            date: _date,
            remindDays: _remindDays,
            titleError: _titleError,
            typeEmojis: _typeEmojis,
            reminderOptions: _reminderOptions,
            onTypeChanged: (t) => setState(() {
              _type = t;
              _emoji = (_typeEmojis[t] ?? ['📅']).first;
            }),
            onEmojiChanged: (e) => setState(() => _emoji = e),
            onDateChanged: (d) => setState(() => _date = d),
            onRemindChanged: (r) => setState(() => _remindDays = r),
          ),
          const SizedBox(height: 16),
          if (_date == null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.lend.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.lend.withOpacity(0.4)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: AppColors.lend,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Please select a date',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Nunito',
                      color: AppColors.lend,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          SaveButton(
            label: widget.existing != null ? 'Update Day →' : 'Save Day →',
            color: AppColors.primary,
            onTap: _save,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REGION PRESETS PANEL
// ─────────────────────────────────────────────────────────────────────────────

class _RegionPresetsPanel extends StatefulWidget {
  final bool isDark;
  final Color surfBg;
  final String selectedRegion;
  final void Function(String) onRegionChanged;
  final void Function(_PresetDay, SpecialDayType) onPresetTap;

  const _RegionPresetsPanel({
    required this.isDark,
    required this.surfBg,
    required this.selectedRegion,
    required this.onRegionChanged,
    required this.onPresetTap,
  });

  @override
  State<_RegionPresetsPanel> createState() => _RegionPresetsPanelState();
}

class _RegionPresetsPanelState extends State<_RegionPresetsPanel> {
  // which section is expanded: 'govt', 'festival', or null
  String? _expanded = 'festival';

  @override
  Widget build(BuildContext context) {
    final tc = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final sub = widget.isDark ? AppColors.subDark : AppColors.subLight;

    final preset = _regionPresets.firstWhere(
      (r) => r.region == widget.selectedRegion,
      orElse: () => _regionPresets.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Or pick from presets',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
            color: tc,
          ),
        ),
        const SizedBox(height: 10),

        // Region selector
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _regionPresets
                .map(
                  (r) => GestureDetector(
                    onTap: () => widget.onRegionChanged(r.region),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: widget.selectedRegion == r.region
                            ? AppColors.primary.withOpacity(0.15)
                            : widget.surfBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: widget.selectedRegion == r.region
                              ? AppColors.primary
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        '${r.flag} ${r.region}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: widget.selectedRegion == r.region
                              ? AppColors.primary
                              : sub,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Universal holidays
        _PresetSection(
          title: '🌍 Universal Holidays',
          color: AppColors.income,
          expanded: _expanded == 'universal',
          onToggle: () => setState(
            () => _expanded = _expanded == 'universal' ? null : 'universal',
          ),
          days: _universalHolidays,
          isDark: widget.isDark,
          surfBg: widget.surfBg,
          onTap: (d) => widget.onPresetTap(d, SpecialDayType.govtHoliday),
        ),
        const SizedBox(height: 8),

        // Govt holidays
        _PresetSection(
          title: '🏛️ ${preset.flag} Govt Holidays',
          color: SpecialDayType.govtHoliday.color,
          expanded: _expanded == 'govt',
          onToggle: () =>
              setState(() => _expanded = _expanded == 'govt' ? null : 'govt'),
          days: preset.govtHolidays,
          isDark: widget.isDark,
          surfBg: widget.surfBg,
          onTap: (d) => widget.onPresetTap(d, SpecialDayType.govtHoliday),
        ),
        const SizedBox(height: 8),

        // Festivals
        _PresetSection(
          title: '🎉 ${preset.flag} Festivals',
          color: SpecialDayType.festival.color,
          expanded: _expanded == 'festival',
          onToggle: () => setState(
            () => _expanded = _expanded == 'festival' ? null : 'festival',
          ),
          days: preset.festivals,
          isDark: widget.isDark,
          surfBg: widget.surfBg,
          onTap: (d) => widget.onPresetTap(d, SpecialDayType.festival),
        ),
      ],
    );
  }
}

class _PresetSection extends StatelessWidget {
  final String title;
  final Color color;
  final bool expanded;
  final VoidCallback onToggle;
  final List<_PresetDay> days;
  final bool isDark;
  final Color surfBg;
  final void Function(_PresetDay) onTap;

  const _PresetSection({
    required this.title,
    required this.color,
    required this.expanded,
    required this.onToggle,
    required this.days,
    required this.isDark,
    required this.surfBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    return Container(
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: expanded ? color.withOpacity(0.4) : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: expanded ? 0.5 : 0,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: color.withOpacity(0.15)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: days
                    .map(
                      (d) => GestureDetector(
                        onTap: () => onTap(d),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: color.withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                d.emoji,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                d.title,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Nunito',
                                  color: color,
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
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MANUAL FORM
// ─────────────────────────────────────────────────────────────────────────────

class _ManualForm extends StatelessWidget {
  final bool isDark;
  final Color surfBg;
  final TextEditingController titleCtrl, noteCtrl;
  final SpecialDayType type;
  final String emoji;
  final DateTime? date;
  final int remindDays;
  final bool titleError;
  final Map<SpecialDayType, List<String>> typeEmojis;
  final List<int> reminderOptions;
  final void Function(SpecialDayType) onTypeChanged;
  final void Function(String) onEmojiChanged;
  final void Function(DateTime?) onDateChanged;
  final void Function(int) onRemindChanged;

  const _ManualForm({
    required this.isDark,
    required this.surfBg,
    required this.titleCtrl,
    required this.noteCtrl,
    required this.type,
    required this.emoji,
    required this.date,
    required this.remindDays,
    required this.titleError,
    required this.typeEmojis,
    required this.reminderOptions,
    required this.onTypeChanged,
    required this.onEmojiChanged,
    required this.onDateChanged,
    required this.onRemindChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final emojis = typeEmojis[type] ?? ['📅'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type selector
        const SheetLabel(text: 'TYPE'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SpecialDayType.values
              .map(
                (t) => GestureDetector(
                  onTap: () => onTypeChanged(t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: type == t ? t.color.withOpacity(0.15) : surfBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: type == t ? t.color : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      '${t.emoji} ${t.label}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito',
                        color: type == t ? t.color : sub,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),

        // Emoji for type
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: emojis
                .map(
                  (e) => GestureDetector(
                    onTap: () => onEmojiChanged(e),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: emoji == e
                            ? type.color.withOpacity(0.15)
                            : surfBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: emoji == e ? type.color : Colors.transparent,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Title
        Container(
          decoration: BoxDecoration(
            color: surfBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: titleError ? AppColors.expense : Colors.transparent,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleCtrl,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(fontSize: 14, color: tc, fontFamily: 'Nunito'),
                decoration: InputDecoration.collapsed(
                  hintText: 'Event name *',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: titleError ? AppColors.expense : sub,
                    fontFamily: 'Nunito',
                  ),
                ),
              ),
              if (titleError) ...[
                const SizedBox(height: 4),
                const Text(
                  'Name is required',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.expense,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        PlanInputField(
          controller: noteCtrl,
          hint: 'Note (optional)',
          maxLines: 2,
        ),
        const SizedBox(height: 14),

        // Date picker
        const SheetLabel(text: 'DATE'),
        GestureDetector(
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );
            if (d != null) onDateChanged(d);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: surfBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: date == null
                    ? AppColors.lend.withOpacity(0.5)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: date != null ? type.color : sub,
                ),
                const SizedBox(width: 10),
                Text(
                  date != null
                      ? '${_monthName(date!.month)} ${date!.day}, ${date!.year}'
                      : 'Select date *',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Nunito',
                    color: date != null ? tc : sub,
                  ),
                ),
                const Spacer(),
                if (date != null)
                  Text(
                    '${_monthName(date!.month)} ${date!.day} every year',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'Nunito',
                      color: sub,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Reminder
        const SheetLabel(text: 'REMIND ME'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: reminderOptions
              .map(
                (n) => GestureDetector(
                  onTap: () => onRemindChanged(n),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: remindDays == n
                          ? type.color.withOpacity(0.15)
                          : surfBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: remindDays == n
                            ? type.color
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      n == 0
                          ? 'No reminder'
                          : n == 1
                          ? '1 day before'
                          : '$n days before',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito',
                        color: remindDays == n ? type.color : sub,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _AiHint extends StatelessWidget {
  final bool isDark;
  const _AiHint({required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('✨', style: TextStyle(fontSize: 15)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Describe the day in plain English — AI will extract the title, date, type and more.',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Nunito',
              color: isDark ? AppColors.textDark : AppColors.textLight,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AiInputBox extends StatelessWidget {
  final TextEditingController ctrl;
  final Color surfBg;
  final bool isDark, isParsing;
  final VoidCallback onParse;
  const _AiInputBox({
    required this.ctrl,
    required this.surfBg,
    required this.isDark,
    required this.isParsing,
    required this.onParse,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return Container(
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: TextField(
              controller: ctrl,
              maxLines: 3,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(fontSize: 14, color: tc, fontFamily: 'Nunito'),
              decoration: InputDecoration.collapsed(
                hintText:
                    '"Mum\'s birthday on March 15" or "Diwali November 1st, remind 7 days before"',
                hintStyle: TextStyle(
                  fontSize: 12,
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
            color: AppColors.primary.withOpacity(0.15),
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
                  onTap: isParsing ? null : onParse,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      gradient: isParsing
                          ? null
                          : const LinearGradient(
                              colors: [AppColors.primary, Color(0xFFFF6B6B)],
                            ),
                      color: isParsing
                          ? AppColors.primary.withOpacity(0.3)
                          : null,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: isParsing
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
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.expense.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.expense.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.expense,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Nunito',
              color: AppColors.expense,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AiPreviewCard extends StatelessWidget {
  final _ParsedDay preview;
  final bool isDark, usedClaude;
  final Color surfBg;
  final VoidCallback onEdit;
  const _AiPreviewCard({
    required this.preview,
    required this.isDark,
    required this.surfBg,
    required this.usedClaude,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final color = preview.type.color;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.income.withOpacity(isDark ? 0.1 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.income.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  preview.emoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview.title,
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
                        color: AppColors.income.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        usedClaude ? '🤖 AI Parsed' : '✨ AI Parsed',
                        style: const TextStyle(
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
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: surfBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.income.withOpacity(0.3),
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Chip(
                label: '${preview.type.emoji} ${preview.type.label}',
                color: color,
              ),
              if (preview.date != null)
                _Chip(
                  label:
                      '📅 ${_monthName(preview.date!.month)} ${preview.date!.day}',
                  color: AppColors.primary,
                ),
              if (preview.remindDays > 0)
                _Chip(
                  label: '🔔 ${preview.remindDays}d before',
                  color: AppColors.split,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFamily: 'Nunito',
          color: color,
        ),
      ),
    );
  }
}

class _AiExamples extends StatelessWidget {
  final Color surfBg, sub;
  final void Function(String) onTap;
  const _AiExamples({
    required this.surfBg,
    required this.sub,
    required this.onTap,
  });

  static const _examples = [
    "Mum's birthday on March 15, remind 7 days before",
    "Wedding anniversary July 22nd",
    "Diwali November 1st, festival",
    "Republic Day January 26, govt holiday",
    "New Year's Eve December 31st",
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Try an example',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFamily: 'Nunito',
          color: sub,
        ),
      ),
      const SizedBox(height: 8),
      ..._examples.map(
        (e) => GestureDetector(
          onTap: () => onTap(e),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: surfBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                const Text('💬', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Nunito',
                      color: sub,
                    ),
                  ),
                ),
                Icon(
                  Icons.north_west_rounded,
                  size: 12,
                  color: AppColors.primary.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CLAUDE AI PARSER
// ─────────────────────────────────────────────────────────────────────────────

class _ParsedDay {
  final String title, emoji;
  final SpecialDayType type;
  final DateTime? date;
  final String? note;
  final int remindDays;
  const _ParsedDay({
    required this.title,
    required this.emoji,
    required this.type,
    required this.remindDays,
    this.date,
    this.note,
  });
}

/// Maps AI edge-function response to [_ParsedDay].
_ParsedDay _parsedDayFromAI(Map<String, dynamic> data) {
  const tm = {
    'birthday': SpecialDayType.birthday,
    'anniversary': SpecialDayType.anniversary,
    'festival': SpecialDayType.festival,
    'govtHoliday': SpecialDayType.govtHoliday,
    'holiday': SpecialDayType.holiday,
    'custom': SpecialDayType.custom,
  };
  DateTime? date;
  try {
    if (data['date'] != null) date = DateTime.parse(data['date'] as String);
  } catch (_) {}
  return _ParsedDay(
    title: data['title'] as String? ?? '',
    emoji: data['emoji'] as String? ?? '📅',
    type: tm[data['type']] ?? SpecialDayType.custom,
    date: date,
    note: data['note'] as String?,
    remindDays: (data['remind_days'] as num?)?.toInt() ?? 1,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCAL NLP PARSER — fallback
// ─────────────────────────────────────────────────────────────────────────────

class _DayNlpParser {
  static _ParsedDay parse(String raw) {
    final lower = raw.toLowerCase();
    final now = DateTime.now();

    // Type detection
    SpecialDayType type = SpecialDayType.custom;
    if (lower.contains('birthday') ||
        lower.contains('bday') ||
        lower.contains('born')) {
      type = SpecialDayType.birthday;
    } else if (lower.contains('anniversary') || lower.contains('wedding'))
      type = SpecialDayType.anniversary;
    else if (lower.contains('festival') ||
        lower.contains('diwali') ||
        lower.contains('holi') ||
        lower.contains('eid') ||
        lower.contains('christmas') ||
        lower.contains('pongal') ||
        lower.contains('onam') ||
        lower.contains('navratri') ||
        lower.contains('durga'))
      type = SpecialDayType.festival;
    else if (lower.contains('holiday') &&
        (lower.contains('govt') ||
            lower.contains('national') ||
            lower.contains('republic') ||
            lower.contains('independence')))
      type = SpecialDayType.govtHoliday;
    else if (lower.contains('holiday') ||
        lower.contains('vacation') ||
        lower.contains('leave'))
      type = SpecialDayType.holiday;

    // Emoji
    String emoji;
    switch (type) {
      case SpecialDayType.birthday:
        emoji = '🎂';
        break;
      case SpecialDayType.anniversary:
        emoji = '💍';
        break;
      case SpecialDayType.festival:
        emoji = '🎉';
        break;
      case SpecialDayType.govtHoliday:
        emoji = '🏛️';
        break;
      case SpecialDayType.holiday:
        emoji = '🌟';
        break;
      default:
        emoji = '📅';
    }
    if (lower.contains('diwali')) {
      emoji = '🪔';
    } else if (lower.contains('christmas'))
      emoji = '🎄';
    else if (lower.contains('holi'))
      emoji = '🎨';
    else if (lower.contains('eid'))
      emoji = '🌙';
    else if (lower.contains('pongal') ||
        lower.contains('onam') ||
        lower.contains('baisakhi'))
      emoji = '🌾';

    // Remind days
    int remindDays = 1;
    final rdMatch = RegExp(r'remind[^\d]*(\d+)\s*days?').firstMatch(lower);
    if (rdMatch != null) {
      remindDays = int.parse(rdMatch.group(1)!);
    } else if (lower.contains('week before'))
      remindDays = 7;
    else if (lower.contains('month before'))
      remindDays = 30;

    // Date parsing
    DateTime? date;
    const months = [
      'january',
      'february',
      'march',
      'april',
      'may',
      'june',
      'july',
      'august',
      'september',
      'october',
      'november',
      'december',
    ];
    for (int mi = 0; mi < months.length; mi++) {
      if (lower.contains(months[mi])) {
        final dayM = RegExp(
          '${months[mi]}\\s*(\\d{1,2})|(\\d{1,2})\\s*${months[mi]}',
        ).firstMatch(lower);
        final dayNum = int.tryParse(dayM?.group(1) ?? dayM?.group(2) ?? '');
        if (dayNum != null) {
          date = DateTime(now.year, mi + 1, dayNum);
        }
        break;
      }
    }

    // Title cleanup
    String title = raw
        .trim()
        .replaceAll(RegExp(r',?\s*remind.*', caseSensitive: false), '')
        .replaceAll(
          RegExp(
            r',?\s*(govt|national|festival|holiday)',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    if (title.isEmpty) title = raw.trim();
    if (title.isNotEmpty) title = title[0].toUpperCase() + title.substring(1);

    return _ParsedDay(
      title: title,
      emoji: emoji,
      type: type,
      date: date,
      remindDays: remindDays,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

String _monthName(int month) {
  const names = [
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
  return names[(month - 1).clamp(0, 11)];
}
