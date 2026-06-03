import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/features/wallet/widgets/family_switcher_sheet.dart';
import 'package:wai_life_assistant/shared/widgets/wallet_switcher_pill.dart';
import 'package:wai_life_assistant/features/AppStateNotifier.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyle_models.dart';
import 'package:wai_life_assistant/data/services/functions_service.dart';
import 'package:wai_life_assistant/features/lifestyle/modules/my_functions/my_functions_screen.dart';
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
      final results = await Future.wait(
        walletIds.map((id) => FunctionsService.instance.fetchMyFunctions(id)),
      );
      if (!mounted) return;
      setState(() {
        _functions
          ..clear()
          ..addAll(results.expand((r) => r).map(FunctionModel.fromJson));
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
                child: GestureDetector(
                  onTap: () => _openFunctions(context),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: moduleColor.withValues(alpha: 0.18)),
                      boxShadow: [
                        BoxShadow(
                          color: moduleColor.withValues(alpha: isDark ? 0.07 : 0.09),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 4,
                            decoration: const BoxDecoration(
                              color: moduleColor,
                              borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: moduleColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: const Text('🎊', style: TextStyle(fontSize: 22)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Functions',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            fontFamily: 'Nunito',
                                            color: textColor,
                                          ),
                                        ),
                                      ),
                                      if (count > 0)
                                        Container(
                                          margin: const EdgeInsets.only(right: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: moduleColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '$count',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              fontFamily: 'Nunito',
                                              color: moduleColor,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Celebrations & gifting',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'Nunito',
                                      color: isDark ? AppColors.subDark : AppColors.subLight,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Divider(height: 1, color: moduleColor.withValues(alpha: 0.15)),
                                  const SizedBox(height: 6),
                                  if (summary.isNotEmpty)
                                    ...summary.map(
                                      (s) => Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 5,
                                              height: 5,
                                              margin: const EdgeInsets.only(right: 7, top: 1),
                                              decoration: BoxDecoration(
                                                color: moduleColor.withValues(alpha: 0.55),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                s,
                                                style: TextStyle(
                                                  fontSize: 11,
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
                                  else
                                    Text(
                                      'No functions yet',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'Nunito',
                                        color: isDark ? AppColors.subDark : AppColors.subLight,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: GestureDetector(
                                onTap: () => _openFunctions(context, openAdd: true),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: moduleColor.withValues(alpha: 0.13),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.add_rounded, color: moduleColor, size: 20),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
          initialTab: openAdd ? 2 : 0,
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
