import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wai_life_assistant/features/wallet/widgets/month_year_picker.dart';
import 'package:wai_life_assistant/features/wallet/widgets/family_switcher_sheet.dart';
import 'package:wai_life_assistant/features/wallet/widgets/chat_input_bar.dart';
import 'package:wai_life_assistant/features/wallet/widgets/tx_tile.dart';
import 'package:wai_life_assistant/features/wallet/widgets/wallet_card_widget.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import '../../../../core/theme/app_theme.dart';
import 'flow_selector_sheet.dart';
import 'conversation_screen.dart';
import 'package:wai_life_assistant/data/models/wallet/flow_models.dart';
import 'package:wai_life_assistant/features/wallet/AI/IntentConfirmSheet.dart';
import 'package:wai_life_assistant/features/wallet/AI/nlp_parser.dart';

class WalletScreen extends StatefulWidget {
  final String activeWalletId;
  final void Function(String) onWalletChange;
  const WalletScreen({
    super.key,
    required this.activeWalletId,
    required this.onWalletChange,
  });
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  // Wallet state
  late PageController _pageCtrl;
  int _pageIdx = 0;

  // Filter tab
  WalletTab _activeTab = WalletTab.all;
  late TabController _tabCtrl;

  // Calendar
  DateTime _selectedMonth = DateTime.now();

  // Voice + speech simulation
  bool _isListening = false;
  // GlobalKey lets us call setTextFromSpeech() on the bar's state
  final _chatBarKey = GlobalKey<ChatInputBarState>();

  // Live transaction list (starts with mock data, grows as user adds)
  final List<TxModel> _transactions = List.from(mockTransactions);

  // All wallets list (personal + families)
  List<WalletModel> get _allWallets => [personalWallet, ...familyWallets];

  WalletModel get _currentWallet => _allWallets.firstWhere(
    (w) => w.id == widget.activeWalletId,
    orElse: () => personalWallet,
  );

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: WalletTab.values.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() => _activeTab = WalletTab.values[_tabCtrl.index]);
      }
    });
    _pageCtrl = PageController(viewportFraction: 0.82);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  List<TxModel> get _filteredTx {
    final base = _transactions
        .where((t) => t.walletId == widget.activeWalletId)
        .where(
          (t) =>
              t.date.year == _selectedMonth.year &&
              t.date.month == _selectedMonth.month,
        )
        .toList();

    switch (_activeTab) {
      case WalletTab.all:
        return base;
      case WalletTab.splits:
        return base.where((t) => t.type == TxType.split).toList();
      case WalletTab.borrow:
        return base.where((t) => t.type == TxType.borrow).toList();
      case WalletTab.lend:
        return base.where((t) => t.type == TxType.lend).toList();
      case WalletTab.requests:
        return base.where((t) => t.type == TxType.request).toList();
    }
  }

  Map<String, List<TxModel>> get _grouped {
    final m = <String, List<TxModel>>{};
    for (final tx in _filteredTx) {
      final diff = DateTime.now().difference(tx.date).inDays;
      final label = diff == 0
          ? 'Today'
          : diff == 1
          ? 'Yesterday'
          : '${tx.date.day} ${_monthName(tx.date.month)}';
      m.putIfAbsent(label, () => []).add(tx);
    }
    return m;
  }

  String _monthName(int m) => const [
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
  ][m];

  void _switchWallet(String id) {
    setState(() {
      widget.onWalletChange(id);
      final idx = _allWallets.indexWhere((w) => w.id == id);
      if (idx >= 0) {
        _pageIdx = idx;
        _pageCtrl.animateToPage(
          idx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutBack,
        );
      }
    });
  }

  // ── Open flow selector sheet → then push conversation screen ───────────────
  void _openFlowSelector() {
    FlowSelectorSheet.show(
      context,
      onSelect: (flowType) => _openConversation(flowType),
    );
  }

  void _openConversation(FlowType flowType) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => ConversationScreen(
          flowType: flowType,
          walletId: widget.activeWalletId,
          onComplete: _onTransactionSaved,
        ),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 380),
      ),
    );
  }

  // ── Called when ConversationFlow completes ──────────────────────────────────
  void _onTransactionSaved(TxModel tx) {
    setState(() => _transactions.insert(0, tx));
    // Show a quick snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(tx.type.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text(
              '${tx.type.label} of ₹${tx.amount.toStringAsFixed(0)} saved!',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        backgroundColor: tx.type.color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Text submit — run NLP, then show confirm sheet or flow selector ──────────
  void _onChatSubmit(String text) {
    final intent = NlpParser.parse(text);

    if (intent.confidence >= 0.5) {
      // Enough signal → show inline confirm sheet with pre-filled fields
      IntentConfirmSheet.show(
        context,
        intent: intent,
        walletId: widget.activeWalletId,
        onSave: _onTransactionSaved,
        onOpenFlow: () => _openConversation(intent.flowType),
      );
    } else if (intent.confidence >= 0.25) {
      // Partial signal → open the correct flow pre-identified, user fills rest
      _openConversation(intent.flowType);
    } else {
      // No signal → let user pick
      _openFlowSelector();
    }
  }

  // ── Mic tap — toggle listening, simulate STT after 3s ────────────────────
  void _onMicTap() {
    HapticFeedback.mediumImpact();
    if (_isListening) {
      // User stopped manually — clear listening state, text already in field
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      // Simulate speech recognition: after 3 seconds "transcribe" a sample
      // In production replace this with speech_to_text plugin callback
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted || !_isListening) return;
        setState(() => _isListening = false);

        // Sample phrases that would come from a real STT engine
        const _sttSamples = [
          'paid 500 for lunch via cash',
          'received 45000 salary online',
          'lent 2000 to Rahul',
          'spent 320 on auto travel',
          'split 1200 dinner with Priya',
        ];
        final sample = (_sttSamples..shuffle()).first;
        // Push text into the bar's text field
        _chatBarKey.currentState?.setTextFromSpeech(sample);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(isDark, textColor),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildWalletCards()),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyTabDelegate(child: _buildTabBar(isDark)),
                ),
                _grouped.isEmpty
                    ? SliverFillRemaining(child: _buildEmpty(isDark))
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => _buildGroup(
                              _grouped.entries.toList()[i],
                              isDark,
                            ),
                            childCount: _grouped.length,
                          ),
                        ),
                      ),
              ],
            ),
          ),

          // Chat input bar — tapping + sends opens flow selector
          ChatInputBar(
            key: _chatBarKey,
            onSubmit: _onChatSubmit,
            onMicTap: _onMicTap,
            onAddTap: _openFlowSelector,
            isListening: _isListening,
          ),
        ],
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────
  AppBar _buildAppBar(bool isDark, Color textColor) {
    return AppBar(
      title: MonthYearPicker(
        selected: _selectedMonth,
        onTap: () async {
          final picked = await MonthYearPicker.showPicker(
            context,
            _selectedMonth,
          );
          if (picked != null) setState(() => _selectedMonth = picked);
        },
      ),
      actions: [
        GestureDetector(
          onTap: () => FamilySwitcherSheet.show(
            context,
            currentWalletId: widget.activeWalletId,
            onSelect: widget.onWalletChange,
          ),
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _currentWallet.gradient),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentWallet.emoji,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 6),
                Text(
                  _currentWallet.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    fontFamily: 'Nunito',
                  ),
                ),
                if (_allWallets.length > 1) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Wallet Cards ────────────────────────────────────────────────────────────
  Widget _buildWalletCards() {
    return Column(
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 230,
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: _allWallets.length,
            onPageChanged: (i) => setState(() {
              _pageIdx = i;
              widget.onWalletChange(_allWallets[i].id);
            }),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: WalletCardWidget(
                wallet: _allWallets[i],
                isActive: i == _pageIdx,
                onTap: () => _pageCtrl.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutBack,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _allWallets.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _pageIdx ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i == _pageIdx
                    ? AppColors.primary
                    : Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Tab Bar ─────────────────────────────────────────────────────────────────
  Widget _buildTabBar(bool isDark) {
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16213E) : const Color(0xFFEDEDF5),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(4),
        child: TabBar(
          controller: _tabCtrl,
          isScrollable: false,
          indicator: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black45,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            fontFamily: 'Nunito',
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            fontFamily: 'Nunito',
          ),
          padding: EdgeInsets.zero,
          tabs: WalletTab.values
              .map((t) => Tab(text: t.label, height: 36))
              .toList(),
        ),
      ),
    );
  }

  // ── Empty state ─────────────────────────────────────────────────────────────
  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔍', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 14),
          Text(
            'No transactions found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'Nunito',
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + below to add one!',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _openFlowSelector,
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Add Transaction',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontFamily: 'Nunito',
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Group section ───────────────────────────────────────────────────────────
  Widget _buildGroup(MapEntry<String, List<TxModel>> entry, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 10),
          child: Row(
            children: [
              Text(
                entry.key.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  fontFamily: 'Nunito',
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Divider(
                  color: isDark
                      ? Colors.white.withOpacity(0.07)
                      : Colors.black.withOpacity(0.07),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${entry.value.length}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
        ...entry.value.map(
          (tx) => TxTile(tx: tx, onTap: () => _showDetail(tx)),
        ),
      ],
    );
  }

  // ── Detail sheet ────────────────────────────────────────────────────────────
  void _showDetail(TxModel tx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
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
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            TxTile(tx: tx),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text(
                      'Edit',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _transactions.remove(tx));
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text(
                      'Delete',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.expense,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
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

// ── Sticky Tab Delegate ─────────────────────────────────────────────────────
class _StickyTabDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _StickyTabDelegate({required this.child});
  @override
  double get minExtent => 58;
  @override
  double get maxExtent => 58;
  @override
  Widget build(_, __, ___) => child;
  @override
  bool shouldRebuild(covariant _StickyTabDelegate o) => o.child != child;
}

// import 'package:flutter/material.dart';
// import 'package:wai_life_assistant/features/wallet/walletsummarycard.dart';
// import 'package:wai_life_assistant/core/theme/app_spacing.dart';
// import 'package:wai_life_assistant/core/theme/app_text.dart';
// import 'package:wai_life_assistant/core/widgets/screen_padding.dart';
// import 'FloatingRail/walletFloatingRail.dart';
// import 'package:wai_life_assistant/data/enum/wallet_enums.dart';
// import 'package:wai_life_assistant/features/wallet/bottomsheet/wallet_transaction_bottom_sheet.dart';
// import 'package:wai_life_assistant/features/wallet/bottomsheet/wallet_features_bottomsheet.dart';
// import 'featurelistdata.dart';
// import 'package:flutter/services.dart';
// import 'AI/showSparkBottomSheet.dart';
// import 'package:wai_life_assistant/data/models/wallet/WalletTransaction.dart';
// import 'WalletTransactionCard.dart';

// class WalletScreen extends StatefulWidget {
//   const WalletScreen({super.key});

//   @override
//   State<WalletScreen> createState() => _WalletScreenState();
// }

// class _WalletScreenState extends State<WalletScreen> {
//   bool showCash = false;
//   bool showUpi = false;

//   final List<WalletTransaction> _transactions = [];

//   void _toggleCash() {
//     HapticFeedback.lightImpact();
//     setState(() {
//       showCash = !showCash;
//       showUpi = false;
//     });
//   }

//   void _toggleUpi() {
//     HapticFeedback.lightImpact();
//     setState(() {
//       showUpi = !showUpi;
//       showCash = false;
//     });
//   }

//   void _collapseRail() {
//     if (showCash || showUpi) {
//       setState(() {
//         showCash = false;
//         showUpi = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text(AppText.walletTitle)),
//       body: Stack(
//         children: [
//           ScreenPadding(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Row(children: [Expanded(child: WalletSummaryCard())]),

//                 const SizedBox(height: AppSpacing.gapL),

//                 Expanded(
//                   child: ListView.builder(
//                     itemCount: _transactions.length,
//                     itemBuilder: (context, index) {
//                       return WalletTransactionCard(
//                         transaction: _transactions[index],
//                       );
//                     },
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // 👇 THIS is where outside tap handling lives
//           if (showCash || showUpi)
//             Positioned.fill(
//               child: GestureDetector(
//                 behavior: HitTestBehavior.translucent,
//                 onTap: _collapseRail,
//                 child: const SizedBox.expand(),
//               ),
//             ),

//           // Floating rail always on top
//           WalletFloatingRail(
//             showCash: showCash,
//             showUpi: showUpi,
//             onCashTap: _toggleCash,
//             onUpiTap: _toggleUpi,
//             onCollapse: _collapseRail,
//             onSparkTap: () async {
//               final intent = await showSparkBottomSheet(context);

//               if (intent == null) return;

//               final transaction = WalletTransaction(
//                 walletType: WalletType.cash, // intent.walletType, // cash / upi
//                 action: WalletAction
//                     .decrement, // intent.action, // increment / decrement
//                 amount: intent.amount,
//                 purpose: intent.purpose.toString(),
//                 category: intent.category.toString(),
//                 //notes: intent.notes,
//               );

//               setState(() {
//                 _transactions.insert(0, transaction);
//               });
//             },

//             //onSparkTap: () => showSparkBottomSheet(context),
//             // onCashAdd: () => showWalletTransactionBottomSheet(
//             //   context: context,
//             //   walletType: WalletType.cash,
//             //   action: WalletAction.increment,
//             // ),
//             onCashAdd: () async {
//               final result = await showWalletTransactionBottomSheet(
//                 context: context,
//                 walletType: WalletType.cash,
//                 action: WalletAction.increment,
//               );

//               if (result != null) {
//                 setState(() {
//                   _transactions.insert(0, result);
//                 });
//               }
//             },
//             onCashRemove: () async {
//               final result = await showWalletTransactionBottomSheet(
//                 context: context,
//                 walletType: WalletType.cash,
//                 action: WalletAction.decrement,
//               );

//               if (result != null) {
//                 setState(() {
//                   _transactions.insert(0, result);
//                 });
//               }
//             },
//             onUpiAdd: () async {
//               final result = await showWalletTransactionBottomSheet(
//                 context: context,
//                 walletType: WalletType.upi,
//                 action: WalletAction.increment,
//               );

//               if (result != null) {
//                 setState(() {
//                   _transactions.insert(0, result);
//                 });
//               }
//             },
//             onUpiRemove: () async {
//               final result = await showWalletTransactionBottomSheet(
//                 context: context,
//                 walletType: WalletType.upi,
//                 action: WalletAction.decrement,
//               );

//               if (result != null) {
//                 setState(() {
//                   _transactions.insert(0, result);
//                 });
//               }
//             },
//             onMoreTap: () => showFeaturesBottomSheet(
//               context: context,
//               features: featuresByTab[1] ?? [],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
