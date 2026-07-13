import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/features/wallet/widgets/family_switcher_sheet.dart';
import 'package:wai_life_assistant/shared/widgets/wallet_switcher_pill.dart';
import 'package:wai_life_assistant/features/AppStateNotifier.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyle_models.dart';
import 'package:wai_life_assistant/data/services/functions_service.dart';
import 'package:wai_life_assistant/data/services/item_locator_service.dart';
import 'package:wai_life_assistant/data/services/wardrobe_service.dart';
import 'package:wai_life_assistant/data/services/health_service.dart';
import 'package:wai_life_assistant/features/lifestyle/modules/my_functions/my_functions_screen.dart';
import 'package:wai_life_assistant/features/lifestyle/modules/item_locator/itemLocatorScreen.dart';
import 'package:wai_life_assistant/features/lifestyle/modules/my_wardrobe/my_wardrobe_screen.dart';
import 'package:wai_life_assistant/features/lifestyle/modules/health_space/health_space_screen.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';
import 'package:wai_life_assistant/core/services/dash_nav_service.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';

class MyHubScreen extends StatefulWidget {
  final String activeWalletId;
  final void Function(String) onWalletChange;
  const MyHubScreen({
    super.key,
    required this.activeWalletId,
    required this.onWalletChange,
  });
  @override
  State<MyHubScreen> createState() => _MyHubScreenState();
}

class _MyHubScreenState extends State<MyHubScreen> {
  late AppStateNotifier _appState;
  List<WalletModel> _allWallets = [];

  WalletModel get _currentWallet => _allWallets.firstWhere(
        (w) => w.id == widget.activeWalletId,
        orElse: () => _allWallets.isNotEmpty ? _allWallets.first : personalWallet,
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = AppStateScope.of(context);
    _allWallets = _appState.wallets;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadData();
    });
  }

  final List<FunctionModel> _functions = [];
  final List<StorageContainer> _containers = [];
  final List<StoredItem> _items = [];
  final List<ClothingItem> _wardrobeItems = [];
  // ignore: prefer_final_fields
  int _healthMedications = 0;
  // ignore: prefer_final_fields
  int _healthAppointments = 0;
  DateTime? _nextAppointmentDate;
  String? _nextAppointmentDoctor;
  String? _loadedKey;
  // True only once _functions/_containers/_items/_wardrobeItems actually hold
  // real data — _loadedKey flips non-null before the fetch resolves, so it
  // alone isn't safe to gate "can a sub-screen skip its own fetch?" on.
  bool _hasLoadedOnce = false;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
    DashNavService.myHub.addListener(_onDashNavSignal);
  }

  @override
  void dispose() {
    DashNavService.myHub.removeListener(_onDashNavSignal);
    super.dispose();
  }

  void _onDashNavSignal() {
    final signal = DashNavService.myHub.value;
    if (signal == null) return;
    DashNavService.myHub.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (signal == 'functions') {
        _openFunctions(context);
      } else if (signal.startsWith('health:')) {
        final tabMap = {
          'health:meds': 1,
          'health:appointments': 4,
          'health:vaccines': 6,
        };
        final tab = tabMap[signal] ?? 0;
        _openHealthSpaceAt(context, tab);
      }
    });
  }

  void _openHealthSpaceAt(BuildContext context, int initialTab) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (ctx, anim, secondaryAnim) => HealthSpaceScreen(
          walletId: _currentWallet.id,
          members: _healthMembers,
          initialTab: initialTab,
        ),
        transitionsBuilder: (ctx, anim, secondaryAnim, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  @override
  void didUpdateWidget(MyHubScreen old) {
    super.didUpdateWidget(old);
    if (old.activeWalletId != widget.activeWalletId) {
      _loadedKey = null;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final wid = widget.activeWalletId;
    if (wid.isEmpty) return;
    final walletIds = _currentWallet.isPersonal
        ? [wid, ..._allWallets.where((w) => !w.isPersonal).map((w) => w.id)]
        : [wid];
    final loadKey = walletIds.join('|');
    if (loadKey == _loadedKey) return;
    _loadedKey = loadKey;
    try {
      final locSvc = ItemLocatorService.instance;
      final results = await Future.wait([
        Future.wait(walletIds.map((id) => FunctionsService.instance.fetchMyFunctions(id))),
        Future.wait(walletIds.map((id) => locSvc.fetchContainers(id))),
        Future.wait(walletIds.map((id) => locSvc.fetchItems(id))),
        Future.wait(walletIds.map((id) => WardrobeService.instance.fetchItems(id))),
        HealthService.instance.fetchSummary(wid),
        HealthService.instance.fetchAppointments(wid),
      ]);
      if (!mounted) return;
      final healthSummary = results[4] as Map<String, int>;
      final rawAppts = results[5] as List<Map<String, dynamic>>;
      // Find next upcoming appointment (sorted ascending by date)
      final today = DateTime.now();
      final upcoming = rawAppts.where((a) {
        final d = DateTime.tryParse(a['appt_date'] as String? ?? '');
        return d != null && !DateTime(d.year, d.month, d.day).isBefore(DateTime(today.year, today.month, today.day));
      }).toList()
        ..sort((a, b) => DateTime.parse(a['appt_date'] as String)
            .compareTo(DateTime.parse(b['appt_date'] as String)));
      setState(() {
        _functions
          ..clear()
          ..addAll((results[0] as List).expand((r) => r as List).map((r) => FunctionModel.fromJson(r as Map<String, dynamic>)));
        _containers
          ..clear()
          ..addAll((results[1] as List).expand((r) => r as List).map((r) => StorageContainer.fromJson(r as Map<String, dynamic>)));
        _items
          ..clear()
          ..addAll((results[2] as List).expand((r) => r as List).map((r) => StoredItem.fromJson(r as Map<String, dynamic>)));
        _wardrobeItems
          ..clear()
          ..addAll((results[3] as List).expand((r) => r as List).map((r) => ClothingItem.fromJson(r as Map<String, dynamic>)));
        _healthMedications = healthSummary['medications'] ?? 0;
        _healthAppointments = healthSummary['appointments'] ?? 0;
        if (upcoming.isNotEmpty) {
          _nextAppointmentDate = DateTime.tryParse(upcoming.first['appt_date'] as String? ?? '');
          _nextAppointmentDoctor = upcoming.first['doctor_name'] as String? ?? '';
        } else {
          _nextAppointmentDate = null;
          _nextAppointmentDoctor = null;
        }
        _hasLoadedOnce = true;
      });
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'myhub_load_data');
      _loadedKey = null; // allow retry — this load never completed
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to load MyHub data'),
          action: SnackBarAction(label: 'Retry', onPressed: _loadData),
        ),
      );
    }
  }

  Map<String, String> get _familyWalletNames {
    if (!_currentWallet.isPersonal) return const {};
    return {
      for (final w in _allWallets.where((w) => !w.isPersonal))
        w.id: '${w.emoji} ${w.name}',
    };
  }

  Map<String, String> get _allFamilyWalletNames => {
        for (final w in _allWallets.where((w) => !w.isPersonal))
          w.id: '${w.emoji} ${w.name}',
      };

  String get _personalWalletId =>
      _allWallets.firstWhere((w) => w.isPersonal, orElse: () => _allWallets.first).id;

  List<PlanMember> get _members {
    if (_currentWallet.isPersonal) return [];
    final family = _appState.families.firstWhere(
      (f) => f.walletId == _currentWallet.id,
      orElse: () => FamilyModel(id: '', name: '', emoji: '', colorIndex: 0),
    );
    return family.members
        .map((m) => PlanMember(id: m.id, name: m.name, emoji: m.emoji, phone: m.phone))
        .toList();
  }

  bool get _isPersonal => _currentWallet.isPersonal;

  String get _screenTitle => _isPersonal ? 'MyHub' : 'FamilyHub';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    const moduleColor = Color(0xFF6C63FF);

    final wid = widget.activeWalletId;
    final personal = _isPersonal;
    final functionsInView = _functions.where((f) => personal || f.walletId == wid).toList();
    final count = functionsInView.length;

    final summary = functionsInView.take(2).map((f) {
      final diff = f.functionDate?.difference(DateTime.now()).inDays;
      String when = '';
      if (diff != null) {
        if (diff < 0) {
          when = 'Past';
        } else if (diff == 0) {
          when = 'Today';
        } else if (diff == 1) {
          when = 'Tomorrow';
        } else {
          when = 'in $diff days';
        }
      }
      return '🎊 ${f.title}${when.isNotEmpty ? ' · $when' : ''}';
    }).toList();

    // Item Locator summary
    final containersInView = _containers.where((c) => personal || c.walletId == wid).toList();
    final itemsInView = _items.where((i) => personal || i.walletId == wid).toList();
    final itemCount = itemsInView.length;
    final importantCount = itemsInView.where((i) => i.isImportant).length;
    final lastImportant = (itemsInView.where((i) => i.isImportant).toList()
          ..sort((a, b) => b.storedOn.compareTo(a.storedOn)))
        .firstOrNull;
    final locatorSummary = (containersInView.isNotEmpty || itemsInView.isNotEmpty)
        ? [
            '📦  ${containersInView.length} ${containersInView.length == 1 ? 'Container' : 'Containers'} · $itemCount ${itemCount == 1 ? 'item' : 'items'}',
            if (lastImportant != null) '⭐  ${lastImportant.name}${lastImportant.description != null ? ' · ${lastImportant.description}' : ''}',
            if (lastImportant == null && importantCount > 0) '⭐  $importantCount important',
          ]
        : <String>[];

    // Wardrobe summary
    final wardrobeInView = _wardrobeItems.where((c) => personal || c.walletId == wid).toList();
    final wardrobeCount = wardrobeInView.where((c) => !c.wishlist).length;
    final wishlistCount = wardrobeInView.where((c) => c.wishlist).length;
    final lastWardrobe = (wardrobeInView.where((c) => !c.wishlist).toList()
          ..sort((a, b) => b.addedOn.compareTo(a.addedOn)))
        .firstOrNull;
    final wardrobeSummary = wardrobeInView.isNotEmpty
        ? [
            '👗  $wardrobeCount ${wardrobeCount == 1 ? 'item' : 'items'} in wardrobe${wishlistCount > 0 ? '  ·  💛 $wishlistCount wishlist' : ''}',
            if (lastWardrobe != null) '🆕  ${lastWardrobe.name}${lastWardrobe.color != null ? ' · ${lastWardrobe.color}' : ''}',
          ]
        : <String>[];

    // Health summary
    final healthSummary = (_healthMedications > 0 || _healthAppointments > 0)
        ? [
            if (_healthMedications > 0) '💊  $_healthMedications active ${_healthMedications == 1 ? 'medication' : 'medications'}',
            if (_nextAppointmentDate != null)
              '📅  ${_nextAppointmentDoctor?.isNotEmpty == true ? _nextAppointmentDoctor! : 'Appointment'} · ${_fmtDate(_nextAppointmentDate!)}'
            else if (_healthAppointments > 0)
              '📅  $_healthAppointments upcoming ${_healthAppointments == 1 ? 'appointment' : 'appointments'}',
          ]
        : <String>[];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Text(_isPersonal ? '🌟' : '👨‍👩‍👧‍👦', style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _screenTitle,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Nunito',
                    color: textColor,
                  ),
                ),
                Text(
                  _isPersonal ? 'Your personal space' : 'Family space',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Nunito',
                    color: isDark ? AppColors.subDark : AppColors.subLight,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          WalletSwitcherPill(
            wallet: _currentWallet,
            onTap: () => FamilySwitcherSheet.show(
              context,
              currentWalletId: widget.activeWalletId,
              onSelect: widget.onWalletChange,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadedKey = null;
          await _loadData();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Module cards ──────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildModuleCard(
                      context: context,
                      isDark: isDark,
                      cardBg: cardBg,
                      textColor: textColor,
                      color: moduleColor,
                      emoji: '🎊',
                      title: 'Functions',
                      subtitle: 'Celebrations & gifting',
                      count: count,
                      summary: summary,
                      emptyLabel: 'Tap ➕ to plan your first function',
                      onTap: () => _openFunctions(context),
                      quickActionLabel: '➕ New',
                      onQuickAction: () => _openFunctions(context, openAdd: true),
                    ),
                    const SizedBox(height: 12),
                    _buildModuleCard(
                      context: context,
                      isDark: isDark,
                      cardBg: cardBg,
                      textColor: textColor,
                      color: const Color(0xFF00897B),
                      emoji: '📍',
                      title: 'Item Locator',
                      subtitle: 'Find anything, anywhere at home',
                      count: itemCount,
                      summary: locatorSummary,
                      emptyLabel: 'Tap ➕ to store your first item',
                      onTap: () => _openItemLocator(context),
                      quickActionLabel: '🔍 Find',
                      onQuickAction: () => _openItemLocator(context),
                    ),
                    const SizedBox(height: 12),
                    _buildModuleCard(
                      context: context,
                      isDark: isDark,
                      cardBg: cardBg,
                      textColor: textColor,
                      color: const Color(0xFFFF5CA8),
                      emoji: '👗',
                      title: 'Wardrobe',
                      subtitle: 'Dresses, outfits & wishlist',
                      count: wardrobeCount,
                      summary: wardrobeSummary,
                      emptyLabel: 'Tap ➕ to add your first outfit',
                      onTap: () => _openWardrobe(context),
                      quickActionLabel: '➕ Add',
                      onQuickAction: () => showAddClothingSheet(
                        context,
                        walletId: _currentWallet.id,
                        memberId: _wardrobeMembers.first.id,
                        onItemAdded: (saved) =>
                            setState(() => _wardrobeItems.insert(0, saved)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildModuleCard(
                      context: context,
                      isDark: isDark,
                      cardBg: cardBg,
                      textColor: textColor,
                      color: const Color(0xFF00BFA5),
                      emoji: '🏥',
                      title: 'Health Space',
                      subtitle: 'Medications, vitals & records',
                      count: _healthMedications + _healthAppointments,
                      summary: healthSummary,
                      emptyLabel: 'Tap ➕ to log your first record',
                      onTap: () => _openHealthSpace(context),
                      quickActionLabel: '💊 Meds',
                      onQuickAction: () => _openHealthSpaceAt(context, 1),
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

  Widget _buildModuleCard({
    required BuildContext context,
    required bool isDark,
    required Color cardBg,
    required Color textColor,
    required Color color,
    required String emoji,
    required String title,
    required String subtitle,
    required int count,
    required List<String> summary,
    required String emptyLabel,
    required VoidCallback onTap,
    String? quickActionLabel,
    VoidCallback? onQuickAction,
  }) {
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.10 : 0.13),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Coloured header band ──────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.15 : 0.10),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isDark ? 0.25 : 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Nunito',
                                  color: textColor,
                                ),
                              ),
                            ),
                            if (count > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: isDark ? 0.30 : 0.20),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Nunito',
                                    color: color,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Nunito',
                            color: sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.7), size: 22),
                ],
              ),
            ),

            // ── Summary content + quick action ────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: summary.isNotEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: summary
                                .map(
                                  (s) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      s,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'Nunito',
                                        color: textColor,
                                        height: 1.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                          )
                        : Text(
                            emptyLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Nunito',
                              color: sub,
                            ),
                          ),
                  ),
                  if (quickActionLabel != null && onQuickAction != null) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onQuickAction();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: isDark ? 0.20 : 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color.withValues(alpha: 0.30)),
                        ),
                        child: Text(
                          quickActionLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: color,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openItemLocator(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (ctx, anim, secondaryAnim) => ItemLocatorScreen(
          walletId: _currentWallet.id,
          members: _wardrobeMembers,
          initialContainers: _hasLoadedOnce ? _containers : null,
          initialItems: _hasLoadedOnce ? _items : null,
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
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  List<LifeMember> get _wardrobeMembers {
    if (_isPersonal) {
      return const [LifeMember(id: 'me', name: 'Me', emoji: '🧑')];
    }
    final family = _appState.families.firstWhere(
      (f) => f.walletId == _currentWallet.id,
      orElse: () => FamilyModel(id: '', name: '', emoji: '', colorIndex: 0),
    );
    final members = family.members
        .map((m) => LifeMember(id: m.id, name: m.name, emoji: m.emoji))
        .toList();
    return members.isNotEmpty
        ? members
        : const [LifeMember(id: 'me', name: 'Me', emoji: '🧑')];
  }

  void _openWardrobe(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (ctx, anim, secondaryAnim) => MyWardrobeScreen(
          walletId: _currentWallet.id,
          members: _wardrobeMembers,
          initialItems: _hasLoadedOnce ? _wardrobeItems : null,
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
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  List<LifeMember> get _healthMembers {
    if (_isPersonal) {
      return const [LifeMember(id: 'me', name: 'Me', emoji: '🧑')];
    }
    final family = _appState.families.firstWhere(
      (f) => f.walletId == _currentWallet.id,
      orElse: () => FamilyModel(id: '', name: '', emoji: '', colorIndex: 0),
    );
    final members = family.members
        .map((m) => LifeMember(id: m.id, name: m.name, emoji: m.emoji))
        .toList();
    return members.isNotEmpty
        ? members
        : const [LifeMember(id: 'me', name: 'Me', emoji: '🧑')];
  }

  void _openHealthSpace(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (ctx, anim, secondaryAnim) => HealthSpaceScreen(
          walletId: _currentWallet.id,
          members: _healthMembers,
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
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  // ── Date formatter ────────────────────────────────────────────────────────
  String _fmtDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }

  void _openFunctions(BuildContext context, {bool openAdd = false}) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (ctx, anim, secondaryAnim) => MyFunctionsScreen(
          walletId: _currentWallet.id,
          walletName: _currentWallet.name,
          walletEmoji: _currentWallet.emoji,
          parentFunctions: _hasLoadedOnce ? _functions : null,
          familyWalletNames: _familyWalletNames,
          allFamilyWalletNames: _allFamilyWalletNames,
          personalWalletId: _personalWalletId,
          members: _members,
          openAdd: openAdd,
          initialTab: 0,
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
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }
}
