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
import 'package:wai_life_assistant/features/lifestyle/modules/my_functions/my_functions_screen.dart';
import 'package:wai_life_assistant/features/lifestyle/modules/item_locator/itemLocatorScreen.dart';
import 'package:wai_life_assistant/features/lifestyle/modules/my_wardrobe/my_wardrobe_screen.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';

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
  String? _loadedKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
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
      ]);
      if (!mounted) return;
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
      });
    } catch (e) {
      debugPrint('[MyHub] _loadData error: $e');
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
      (f) => f.id == _currentWallet.id,
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
    final locatorSummary = (containersInView.isNotEmpty || itemsInView.isNotEmpty)
        ? [
            '📦  ${containersInView.length} ${containersInView.length == 1 ? 'Container' : 'Containers'}',
            '📍  $itemCount ${itemCount == 1 ? 'Item' : 'Items'} stored',
            '⭐  $importantCount Important',
          ]
        : <String>[];

    // Wardrobe summary
    final wardrobeInView = _wardrobeItems.where((c) => personal || c.walletId == wid).toList();
    final wardrobeCount = wardrobeInView.where((c) => !c.wishlist).length;
    final wishlistCount = wardrobeInView.where((c) => c.wishlist).length;
    final wardrobeSummary = wardrobeInView.isNotEmpty
        ? [
            '👗  $wardrobeCount ${wardrobeCount == 1 ? 'Item' : 'Items'} in wardrobe',
            '💛  $wishlistCount in wishlist',
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
                      emptyLabel: 'No functions yet',
                      onTap: () => _openFunctions(context),
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
                      emptyLabel: 'No items stored yet',
                      onTap: () => _openItemLocator(context),
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
                      emptyLabel: 'No clothing added yet',
                      onTap: () => _openWardrobe(context),
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
                  Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.5), size: 20),
                ],
              ),
            ),

            // ── Summary content ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: summary.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: summary
                          .map(
                            (s) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.only(right: 8, top: 1),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.50),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  Expanded(
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
                                ],
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
                        fontStyle: FontStyle.italic,
                      ),
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

  void _openFunctions(BuildContext context, {bool openAdd = false}) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (ctx, anim, secondaryAnim) => MyFunctionsScreen(
          walletId: _currentWallet.id,
          walletName: _currentWallet.name,
          walletEmoji: _currentWallet.emoji,
          parentFunctions: _functions,
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
