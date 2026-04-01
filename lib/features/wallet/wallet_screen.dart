import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wai_life_assistant/features/wallet/widgets/month_year_picker.dart';
import 'package:wai_life_assistant/features/wallet/widgets/family_switcher_sheet.dart';
import 'package:wai_life_assistant/features/wallet/widgets/chat_input_bar.dart';
import 'package:wai_life_assistant/features/wallet/widgets/tx_tile.dart';
import 'package:wai_life_assistant/features/wallet/widgets/wallet_card_widget.dart';
import 'package:wai_life_assistant/core/widgets/wallet_switcher_pill.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/data/models/wallet/split_group_models.dart';
import 'package:wai_life_assistant/features/wallet/splits/split_group_sheet.dart';
import 'package:wai_life_assistant/features/wallet/splits/split_group_detail_screen.dart';
import '../../../../core/theme/app_theme.dart';
import 'flow_selector_sheet.dart';
import 'conversation_screen.dart';
import 'package:wai_life_assistant/data/models/wallet/flow_models.dart';
import 'package:wai_life_assistant/features/wallet/AI/IntentConfirmSheet.dart';
import 'package:wai_life_assistant/features/wallet/AI/nlp_parser.dart';
import 'package:wai_life_assistant/services/ai_parser.dart';
import 'package:wai_life_assistant/features/AppStateNotifier.dart';
import 'package:wai_life_assistant/features/auth/auth_service.dart';
import 'package:wai_life_assistant/core/supabase/wallet_service.dart';
import 'package:wai_life_assistant/core/services/network_service.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';
import 'package:wai_life_assistant/features/planit/modules/bill_watch/bill_watch_screen.dart';
import 'package:wai_life_assistant/features/wallet/wallet_reports_sheet.dart';
import 'package:wai_life_assistant/features/wallet/widgets/tx_detail_sheet.dart';
import 'package:wai_life_assistant/features/wallet/widgets/tx_group_card.dart';
import 'package:speech_to_text/speech_to_text.dart';

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
  // Filter tab
  WalletTab _activeTab = WalletTab.wallet;
  late TabController _tabCtrl;

  // Calendar
  MonthRange _selectedRange = MonthRange.thisMonth();

  // Voice / speech-to-text
  bool _isListening = false;
  String _speechLocale = 'en-IN';
  final _chatBarKey = GlobalKey<ChatInputBarState>();
  final SpeechToText _speech = SpeechToText();

  // Live transaction list (loaded async)
  List<TxModel> _transactions = [];
  bool _txLoading = true;

  // Split groups
  late List<SplitGroup> _splitGroups;
  bool _sgLoading = true;

  // Transaction groups (named expense bundles)
  List<TxGroup> _txGroups = [];

  // Wallets list (from AppStateScope)
  List<WalletModel> _allWallets = [];

  // Bill Watch — lifted state + key to trigger add-sheet from bottom bar
  final List<BillModel> _bills = [];
  final _billWatchKey = GlobalKey<BillWatchScreenState>();

  // Family tab card pager
  PageController? _familyPageCtrl;

  WalletModel get _currentWallet => _allWallets.firstWhere(
    (w) => w.id == widget.activeWalletId,
    orElse: () => _allWallets.isNotEmpty ? _allWallets.first : personalWallet,
  );

  late AppStateNotifier _appState;
  bool _wasOnline = true;

  void _onNetworkChange() {
    final online = NetworkService.instance.isOnline.value;
    if (online && !_wasOnline) _refreshAll();
    _wasOnline = online;
  }

  /// Reloads AppState (to get real wallet UUID) then fetches transactions and split groups.
  Future<void> _refreshAll() async {
    await _appState.reload();
    await Future.wait([_loadTransactions(), _loadSplitGroups(), _loadTxGroups()]);
  }

  @override
  void initState() {
    super.initState();
    _splitGroups = [];
    _wasOnline = NetworkService.instance.isOnline.value;
    NetworkService.instance.isOnline.addListener(_onNetworkChange);
    WalletService.txChangeSignal.addListener(_onExternalTxChange);
    _tabCtrl = TabController(length: kV1WalletTabs.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        final tab = kV1WalletTabs[_tabCtrl.index];
        setState(() => _activeTab = tab);
        _autoSwitchWalletForTab(tab);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = AppStateScope.of(context);
    final newWallets = _appState.wallets;
    if (newWallets != _allWallets) {
      _allWallets = newWallets;
      // Reset family page controller so it reinitialises with correct page count
      _familyPageCtrl?.dispose();
      _familyPageCtrl = null;
    }
    // Initial transaction load
    if (_txLoading) _loadTransactions();
    if (_sgLoading) _loadSplitGroups();
    if (_txGroups.isEmpty) _loadTxGroups();
    WalletService.instance.loadCategories();
  }

  @override
  void didUpdateWidget(WalletScreen old) {
    super.didUpdateWidget(old);
    if (old.activeWalletId != widget.activeWalletId) {
      _loadTransactions();
      _loadSplitGroups();
      _loadTxGroups();
      _syncFamilyPage();
    }
  }

  void _syncFamilyPage() {
    final ctrl = _familyPageCtrl;
    if (ctrl == null || !ctrl.hasClients) return;
    final familyWallets = _allWallets.where((w) => !w.isPersonal).toList();
    final idx = familyWallets.indexWhere((w) => w.id == widget.activeWalletId);
    if (idx >= 0 && ctrl.page?.round() != idx) {
      ctrl.animateToPage(
        idx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _loadTransactions() async {
    setState(() => _txLoading = true);
    // Prefer the freshly-loaded wallet ID from AppState over the widget prop
    // (widget prop can be stale "personal" if AppState failed on first load)
    final walletId =
        _appState.activeWalletId.isNotEmpty &&
            _appState.activeWalletId != 'personal'
        ? _appState.activeWalletId
        : widget.activeWalletId;

    if (!AuthService.instance.isLoggedIn ||
        walletId.isEmpty ||
        walletId == 'personal') {
      if (mounted) {
        setState(() {
          _transactions = [];
          _txLoading = false;
        });
      }
      return;
    }
    try {
      final rows = await WalletService.instance.fetchTransactions(walletId);
      if (mounted) {
        setState(() {
          _transactions = rows.map(TxModel.fromRow).toList();
          _txLoading = false;
        });
        // Rebuild group membership from freshly loaded txs
        _loadTxGroups();
      }
    } catch (e) {
      debugPrint('[WalletScreen] fetchTransactions error: $e');
      if (mounted) setState(() => _txLoading = false);
    }
  }

  Future<void> _loadTxGroups() async {
    final walletId =
        _appState.activeWalletId.isNotEmpty &&
                _appState.activeWalletId != 'personal'
            ? _appState.activeWalletId
            : widget.activeWalletId;
    if (!AuthService.instance.isLoggedIn ||
        walletId.isEmpty ||
        walletId == 'personal') {
      if (mounted) setState(() => _txGroups = []);
      return;
    }
    try {
      final rows = await WalletService.instance.fetchTxGroups(walletId);
      if (!mounted) return;
      // Build group objects; member txs are matched from _transactions
      final groups = rows.map((r) {
        final g = TxGroup.fromRow(r);
        final members = _transactions
            .where((t) => t.groupId == g.id)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        return g.withTransactions(members);
      }).toList();
      setState(() => _txGroups = groups);
    } catch (e) {
      debugPrint('[WalletScreen] fetchTxGroups error: $e');
    }
  }

  // Push the current pinned groups to the notifier so Dashboard can display them.
  void _syncPinnedGroups() {
    pinnedSplitGroupsNotifier.value = _splitGroups
        .where((g) => g.pinnedToDashboard && !g.isFullySettled)
        .toList();
  }

  Future<void> _loadSplitGroups() async {
    setState(() => _sgLoading = true);
    final walletId =
        _appState.activeWalletId.isNotEmpty &&
            _appState.activeWalletId != 'personal'
        ? _appState.activeWalletId
        : widget.activeWalletId;

    if (!AuthService.instance.isLoggedIn ||
        walletId.isEmpty ||
        walletId == 'personal') {
      if (mounted) {
        setState(() {
          _splitGroups = [];
          _sgLoading = false;
        });
        _syncPinnedGroups();
      }
      return;
    }
    try {
      final rows = await WalletService.instance.fetchSplitGroups(walletId);
      if (mounted) {
        setState(() {
          _splitGroups = rows.map(_splitGroupFromRow).toList();
          _sgLoading = false;
        });
        _syncPinnedGroups();
      }
    } catch (e) {
      debugPrint('[WalletScreen] fetchSplitGroups error: $e');
      if (mounted) setState(() => _sgLoading = false);
    }
  }

  // Delegates to shared top-level splitGroupFromRow in split_group_models.dart
  SplitGroup _splitGroupFromRow(Map<String, dynamic> row) =>
      splitGroupFromRow(row);

  void _onExternalTxChange() {
    _loadTransactions();
    _loadTxGroups();
  }

  @override
  void dispose() {
    NetworkService.instance.isOnline.removeListener(_onNetworkChange);
    WalletService.txChangeSignal.removeListener(_onExternalTxChange);
    _tabCtrl.dispose();
    _familyPageCtrl?.dispose();
    _speech.stop();
    super.dispose();
  }

  /// IDs of all transactions that belong to a tx_group.
  Set<String> get _groupedTxIds {
    final ids = <String>{};
    for (final g in _txGroups) {
      for (final t in g.transactions) {
        ids.add(t.id);
      }
    }
    return ids;
  }

  /// TxGroups belonging to the currently active wallet.
  List<TxGroup> get _activeWalletTxGroups =>
      _txGroups.where((g) => g.walletId == widget.activeWalletId).toList();

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

  // Compute period-filtered breakdown from local transactions for a wallet
  ({double cashIn, double cashOut, double onlineIn, double onlineOut})
  _periodStats(String walletId) {
    final txs = _transactions
        .where((t) => t.walletId == walletId && _selectedRange.contains(t.date))
        .toList();
    double cashIn = 0, cashOut = 0, onlineIn = 0, onlineOut = 0;
    for (final t in txs) {
      final isIn = t.type == TxType.income || t.type == TxType.borrow;
      final isOut =
          t.type == TxType.expense ||
          t.type == TxType.lend ||
          t.type == TxType.split;
      if (t.payMode == PayMode.cash) {
        if (isIn) cashIn += t.amount;
        if (isOut) cashOut += t.amount;
      } else if (t.payMode == PayMode.online) {
        if (isIn) onlineIn += t.amount;
        if (isOut) onlineOut += t.amount;
      }
    }
    return (
      cashIn: cashIn,
      cashOut: cashOut,
      onlineIn: onlineIn,
      onlineOut: onlineOut,
    );
  }

  void _switchWallet(String id) {
    setState(() => widget.onWalletChange(id));
  }

  void _autoSwitchWalletForTab(WalletTab tab) {
    // No auto-switch — the wallet pill handles wallet switching across all tabs
  }

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
          wallets: _allWallets,
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

  void _onTransactionSaved(TxModel tx) {
    // Optimistically show in list immediately
    setState(() => _transactions.insert(0, tx));
    final group = _pendingGroupForNextTx;
    _pendingGroupForNextTx = null;
    _persistTransaction(tx, groupOverride: group); // fire-and-forget
  }

  Future<void> _persistTransaction(TxModel tx, {TxGroup? groupOverride}) async {
    if (!AuthService.instance.isLoggedIn) {
      return;
    }
    // Always save the category — runs regardless of whether addTransaction succeeds
    WalletService.instance.ensureCategory(tx.category, tx.type.name);
    try {
      final row = await WalletService.instance.addTransaction(
        walletId: tx.walletId,
        type: tx.type.name,
        amount: tx.amount,
        category: tx.category,
        payMode: tx.payMode?.name,
        title: tx.title,
        note: tx.note,
        person: tx.person,
        persons: tx.persons,
        dueDate: tx.dueDate,
        date: tx.date,
      );
      if (!mounted) return;
      // Replace local placeholder id with real DB row
      final saved = TxModel.fromRow(row);
      setState(() {
        final idx = _transactions.indexWhere((t) => t.id == tx.id);
        if (idx >= 0) _transactions[idx] = saved;
      });
      // If this tx was created via "Add to group", assign it now
      if (groupOverride != null) {
        await _assignTxToGroup(saved, groupOverride);
      }
      // Reload wallet so the card reflects updated balance
      await AppStateScope.of(context).reload();
      if (!mounted) return;
      // ConversationScreen may still be on top (it pops after a 1800ms delay).
      // Wait until WalletScreen's route is active before starting the snackbar
      // timer — otherwise the timer expires while the screen is hidden and the
      // snackbar appears permanently stuck when the user returns.
      while (mounted && ModalRoute.of(context)?.isCurrent == false) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (!mounted) return;
      final otherWallets = _allWallets
          .where((w) => w.id != saved.walletId)
          .toList();
      _showTxSnackBar(saved, otherWallets);
    } catch (e) {
      debugPrint('[WalletScreen] addTransaction failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _showTxSnackBar(TxModel tx, List<WalletModel> otherWallets) {
    final hasMove = otherWallets.isNotEmpty;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(tx.type.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${tx.type.label} of ₹${tx.amount.toStringAsFixed(0)} saved!',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: tx.type.color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: hasMove ? 5 : 3),
        action: hasMove
            ? SnackBarAction(
                label: otherWallets.length == 1
                    ? 'Move to ${otherWallets[0].name}'
                    : 'Move to...',
                textColor: Colors.white,
                onPressed: () {
                  if (otherWallets.length == 1) {
                    _moveTxToWallet(tx, otherWallets[0]);
                  } else {
                    _showMoveWalletPicker(tx, otherWallets);
                  }
                },
              )
            : null,
      ),
    );
  }

  Future<void> _moveTxToWallet(TxModel tx, WalletModel target) async {
    setState(() => _transactions.removeWhere((t) => t.id == tx.id));
    try {
      await WalletService.instance.deleteTransaction(tx.id);
      await WalletService.instance.addTransaction(
        walletId: target.id,
        type: tx.type.name,
        amount: tx.amount,
        category: tx.category,
        payMode: tx.payMode?.name,
        title: tx.title,
        note: tx.note,
        person: tx.person,
        persons: tx.persons,
        dueDate: tx.dueDate,
        date: tx.date,
      );
      WalletService.txChangeSignal.value++;
      if (mounted) await AppStateScope.of(context).reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Moved to ${target.name} ${target.isPersonal ? '👤' : '👨‍👩‍👧'}',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
              ),
            ),
            backgroundColor: const Color(0xFF00C897),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('[Wallet] moveTx failed: $e');
      if (mounted) setState(() => _transactions.insert(0, tx)); // revert
    }
  }

  void _showMoveWalletPicker(TxModel tx, List<WalletModel> wallets) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Move to wallet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
                color: tc,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${tx.type.emoji} ${tx.type.label} · ₹${tx.amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 12,
                color: sub,
                fontFamily: 'Nunito',
              ),
            ),
            const SizedBox(height: 16),
            ...wallets.map((w) => GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _moveTxToWallet(tx, w);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: (w.isPersonal
                              ? AppColors.primary
                              : AppColors.income)
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: (w.isPersonal
                                ? AppColors.primary
                                : AppColors.income)
                            .withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          w.emoji.startsWith('http') || w.emoji.isEmpty
                              ? (w.isPersonal ? '👤' : '👨‍👩‍👧')
                              : w.emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                w.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Nunito',
                                  color: tc,
                                ),
                              ),
                              Text(
                                w.isPersonal ? 'Personal wallet' : 'Family wallet',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: sub,
                                  fontFamily: 'Nunito',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: sub,
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  static const _splitKeywords = [
    'split',
    'splits',
    'equally',
    'divide',
    'divided',
    'share',
    'shared',
    'dutch',
    'between us',
    'among us',
    'split equally',
    'split between',
  ];

  bool _looksLikeSplit(String text) {
    final lower = text.toLowerCase();
    return _splitKeywords.any((k) => lower.contains(k));
  }

  Future<void> _onChatSubmit(String text) async {
    final isSplit = _looksLikeSplit(text);
    final subFeature = isSplit ? 'split' : 'expense';

    // Show parsing indicator
    final sm = ScaffoldMessenger.of(context);
    sm.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text(isSplit ? 'Parsing split with AI…' : 'Parsing with AI…'),
          ],
        ),
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final result = await AIParser.parseText(
      feature: 'wallet',
      subFeature: subFeature,
      text: text,
    );

    sm.hideCurrentSnackBar();
    if (!mounted) return;

    debugPrint(
      '🤖 AI parse ($subFeature): success=${result.success} error=${result.error} data=${result.data}',
    );

    ParsedIntent intent;
    if (result.success && result.data != null) {
      intent = isSplit
          ? _splitResultToIntent(result.data!)
          : _aiResultToIntent(result.data!);
    } else {
      debugPrint(
        '⚠️ AI failed, falling back to NlpParser. Reason: ${result.error}',
      );
      intent = NlpParser.parse(text);
    }

    IntentConfirmSheet.show(
      context,
      intent: intent,
      walletId: widget.activeWalletId,
      onSave: _onTransactionSaved,
      onOpenFlow: () => _openConversation(intent.flowType),
    );
  }

  // Maps wallet/split AI response → ParsedIntent
  ParsedIntent _splitResultToIntent(Map<String, dynamic> data) {
    DateTime? date;
    final dateStr = data['date'] as String?;
    if (dateStr != null) date = DateTime.tryParse(dateStr);

    return ParsedIntent(
      flowType: FlowType.split,
      amount: (data['total_amount'] as num?)?.toDouble(),
      category: data['category'] as String?,
      person: data['paid_by'] as String?,
      note: data['title'] as String?,
      date: date,
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0.8,
    );
  }

  ParsedIntent _aiResultToIntent(Map<String, dynamic> data) {
    FlowType flowType;
    switch ((data['type'] as String? ?? '').toLowerCase()) {
      case 'income':
        flowType = FlowType.income;
      case 'lend':
        flowType = FlowType.lend;
      case 'borrow':
        flowType = FlowType.borrow;
      default:
        flowType = FlowType.expense;
    }

    PayMode? payMode;
    final pm = (data['payment_mode'] as String? ?? '').toLowerCase();
    if (pm == 'cash') {
      payMode = PayMode.cash;
    } else if (pm.isNotEmpty && pm != 'null') {
      payMode = PayMode.online;
    }

    DateTime? date;
    final dateStr = data['date'] as String?;
    if (dateStr != null) date = DateTime.tryParse(dateStr);

    return ParsedIntent(
      flowType: flowType,
      amount: (data['amount'] as num?)?.toDouble(),
      category: data['category'] as String?,
      person: data['person'] as String?,
      payMode: payMode,
      title: data['title'] as String?,
      note: data['note'] as String?,
      date: date,
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0.8,
    );
  }

  Future<void> _onMicTap() async {
    HapticFeedback.mediumImpact();
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }
    final available = await _speech.initialize(
      onStatus: (s) {
        if ((s == 'done' || s == 'notListening') && mounted) {
          setState(() => _isListening = false);
        }
      },
      onError: (e) {
        if (mounted) setState(() => _isListening = false);
      },
    );
    if (!available || !mounted) return;
    setState(() => _isListening = true);
    await _speech.listen(
      localeId: _speechLocale,
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(seconds: 30),
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
      ),
      onResult: (result) {
        if (!mounted) return;
        if (result.finalResult) {
          setState(() => _isListening = false);
          if (result.recognizedWords.trim().isNotEmpty) {
            _chatBarKey.currentState?.setTextFromSpeech(result.recognizedWords);
          }
        }
      },
    );
  }

  Future<void> _onMicLongPress() => _showLanguagePicker();

  static const _indianLanguages = [
    ('en-IN', 'English', '🇮🇳'),
    ('hi-IN', 'Hindi', '🇮🇳'),
    ('ta-IN', 'Tamil', '🇮🇳'),
    ('te-IN', 'Telugu', '🇮🇳'),
    ('kn-IN', 'Kannada', '🇮🇳'),
    ('ml-IN', 'Malayalam', '🇮🇳'),
    ('bn-IN', 'Bengali', '🇮🇳'),
    ('mr-IN', 'Marathi', '🇮🇳'),
    ('gu-IN', 'Gujarati', '🇮🇳'),
    ('pa-IN', 'Punjabi', '🇮🇳'),
  ];

  Future<void> _showLanguagePicker() async {
    // Initialise STT to get available device locales
    final available = await _speech.initialize();
    final supported = available
        ? (await _speech.locales()).map((l) => l.localeId).toSet()
        : <String>{};

    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🎤', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    'Speech Language',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                      color: tc,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Long-press mic anytime to change',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Nunito',
                  color: sub,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _indianLanguages.map((lang) {
                  final localeId = lang.$1;
                  final name = lang.$2;
                  final isSelected = _speechLocale == localeId;
                  // Locale is either confirmed supported, or STT wasn't available to check
                  final isSupported =
                      !available || supported.contains(localeId);
                  return GestureDetector(
                    onTap: isSupported
                        ? () {
                            setState(() => _speechLocale = localeId);
                            Navigator.pop(ctx);
                          }
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : isSupported
                            ? surfBg
                            : surfBg.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: isSelected
                                  ? AppColors.primary
                                  : isSupported
                                  ? tc
                                  : sub,
                            ),
                          ),
                          if (!isSupported) ...[
                            const SizedBox(height: 2),
                            Text(
                              'unavailable',
                              style: TextStyle(
                                fontSize: 9,
                                fontFamily: 'Nunito',
                                color: sub,
                              ),
                            ),
                          ],
                        ],
                      ),
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

  // ── Split Group handlers ─────────────────────────────────────────────────

  void _openCreateGroup() {
    SplitGroupSheet.show(
      context,
      walletId: widget.activeWalletId,
      onSave: (group) {
        setState(() => _splitGroups.insert(0, group));
        _persistSplitGroup(group); // fire-and-forget
      },
    );
  }

  Future<void> _persistSplitGroup(SplitGroup group) async {
    if (!AuthService.instance.isLoggedIn) return;
    try {
      final row = await WalletService.instance.createSplitGroup(
        walletId: group.walletId,
        name: group.name,
        emoji: group.emoji,
        participants: group.participants
            .map(
              (p) =>
                  (name: p.name, emoji: p.emoji, phone: p.phone, isMe: p.isMe),
            )
            .toList(),
      );
      if (!mounted) return;
      // Replace local placeholder ids with real DB ids (group + participants)
      final realId = row['id'] as String;
      final rawParts = (row['split_participants'] as List? ?? []);
      final realParticipants = rawParts
          .map(
            (p) => SplitParticipant(
              id: p['id'] as String,
              name: p['name'] as String,
              emoji: p['emoji'] as String? ?? '👤',
              phone: p['phone'] as String?,
              isMe: p['is_me'] as bool? ?? false,
            ),
          )
          .toList();
      setState(() {
        final idx = _splitGroups.indexWhere((g) => g.id == group.id);
        if (idx >= 0) {
          _splitGroups[idx] = SplitGroup(
            id: realId,
            name: group.name,
            emoji: group.emoji,
            walletId: group.walletId,
            participants: realParticipants,
            transactions: group.transactions,
            messages: group.messages,
            createdAt: group.createdAt,
          );
        }
      });
    } catch (e) {
      debugPrint('[WalletScreen] createSplitGroup failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save group: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _openEditGroup(SplitGroup group) {
    SplitGroupSheet.show(
      context,
      existing: group,
      walletId: widget.activeWalletId,
      onSave: (updated) {
        setState(() {
          final idx = _splitGroups.indexWhere((g) => g.id == updated.id);
          if (idx >= 0) _splitGroups[idx] = updated;
        });
        _syncPinnedGroups();
        if (AuthService.instance.isLoggedIn) {
          WalletService.instance.updateSplitGroupPin(
            updated.id,
            pinned: updated.pinnedToDashboard,
          );
        }
      },
      onDelete: () {
        setState(() => _splitGroups.removeWhere((g) => g.id == group.id));
        _syncPinnedGroups();
      },
    );
  }

  void _openGroupDetail(SplitGroup group, {bool autoAddExpense = false}) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => SplitGroupDetailScreen(
          group: group,
          autoOpenAddExpense: autoAddExpense,
          onGroupUpdated: (updated) {
            setState(() {
              final idx = _splitGroups.indexWhere((g) => g.id == updated.id);
              if (idx >= 0) _splitGroups[idx] = updated;
            });
            _syncPinnedGroups();
          },
        ),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 340),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;

    // Scoped ScaffoldMessenger so snackbars always render in this specific
    // Scaffold, not in whichever tab happens to be last-registered with the
    // app-level ScaffoldMessenger (which could be an invisible IndexedStack tab).
    return ScaffoldMessenger(
      child: Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(isDark, textColor),
      body: Column(
        children: [
          Expanded(
            child: NestedScrollView(
              headerSliverBuilder: (_, __) => [
                // Tab bar sticks at the top
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyTabDelegate(child: _buildTabBar(isDark)),
                ),
              ],
              body: TabBarView(
                controller: _tabCtrl,
                children: kV1WalletTabs.map((t) {
                  switch (t) {
                    case WalletTab.wallet:
                      return _buildWalletBody(isDark);
                    case WalletTab.splits:
                      return _buildSplitsBody(isDark);
                    case WalletTab.billWatch: // V2 — not reachable in V1
                      return _buildBillWatchBody(isDark, context);
                  }
                }).toList(),
              ),
            ),
          ),

          if (_activeTab != WalletTab.splits)
            ChatInputBar(
              key: _chatBarKey,
              onSubmit: _onChatSubmit,
              onMicTap: _onMicTap,
              onAddTap: _activeTab == WalletTab.billWatch
                  ? () {
                      final ctx = context;
                      final isDark =
                          Theme.of(ctx).brightness == Brightness.dark;
                      final surfBg = isDark
                          ? AppColors.surfDark
                          : const Color(0xFFEDEEF5);
                      _billWatchKey.currentState?.openAddSheet(
                        ctx,
                        isDark,
                        surfBg,
                      );
                    }
                  : _openFlowSelector,
              isListening: _isListening,
              speechLocale: _speechLocale,
              onMicLongPress: _onMicLongPress,
            ),
        ],
      ),
      ),
    );
  }

  // ── Wallet tab body — adapts to personal vs family active wallet ───────────
  Widget _buildWalletBody(bool isDark) {
    if (_currentWallet.isPersonal) {
      final wallets = _allWallets.where((w) => w.isPersonal).toList();
      final ids = wallets.map((w) => w.id).toSet();
      return _buildWalletTabBody(
        wallets: wallets,
        walletIds: ids,
        isDark: isDark,
        extraHeader: _buildContactStrip(ids, isDark),
      );
    } else {
      final wallets = _allWallets.where((w) => !w.isPersonal).toList();
      if (wallets.isEmpty) return _buildNoFamilyEmpty(isDark);
      if (_familyPageCtrl == null) {
        final initialPage = wallets.indexWhere(
          (w) => w.id == widget.activeWalletId,
        );
        _familyPageCtrl = PageController(
          viewportFraction: 0.88,
          initialPage: initialPage < 0 ? 0 : initialPage,
        );
      }
      final ids = {widget.activeWalletId};
      return _buildWalletTabBody(
        wallets: wallets,
        walletIds: ids,
        isDark: isDark,
        familyPageCtrl: _familyPageCtrl,
        extraHeader: _buildContactStrip(ids, isDark),
      );
    }
  }

  // ── Bill Watch tab body ───────────────────────────────────────────────────
  Widget _buildBillWatchBody(bool isDark, BuildContext hostContext) {
    return BillWatchScreen(
      key: _billWatchKey,
      walletId: widget.activeWalletId,
      walletName: _currentWallet.name,
      walletEmoji: _currentWallet.emoji,
      bills: _bills,
      hostContext: hostContext,
    );
  }

  // ── Contact strip (lend/borrow summary) ───────────────────────────────────
  Widget _buildContactStrip(Set<String> walletIds, bool isDark) {
    final txs = _transactions
        .where((t) => walletIds.contains(t.walletId))
        .where((t) => _selectedRange.contains(t.date))
        .where((t) => t.type == TxType.lend || t.type == TxType.borrow || t.type == TxType.returned)
        .toList();

    if (txs.isEmpty) return const SizedBox.shrink();

    // Net per person + per-person tx list
    // lend: +amount (they owe you), borrow: -amount (you owe them),
    // returned: +amount (I paid back, reduces my negative borrow balance)
    // Group by normalized key (trimmed + lowercase) so "Alice" and "alice kumar"
    // still club together if the user typed slightly different names.
    final Map<String, double> netByKey = {};
    final Map<String, String> displayName = {}; // normalized key → best display name
    final Map<String, List<TxModel>> txsByKey = {};
    for (final tx in txs) {
      final raw = (tx.person ?? 'Unknown').trim();
      final key = raw.toLowerCase();
      final delta = tx.type == TxType.lend ? tx.amount
                  : tx.type == TxType.returned ? tx.amount
                  : -tx.amount;
      netByKey[key] = (netByKey[key] ?? 0) + delta;
      // Keep the longest name variant as the display name
      if (!displayName.containsKey(key) || raw.length > displayName[key]!.length) {
        displayName[key] = raw;
      }
      (txsByKey[key] ??= []).add(tx);
    }
    // Re-key by display name for the rest of the method
    final Map<String, double> personNet = {
      for (final e in netByKey.entries) displayName[e.key]!: e.value,
    };
    final Map<String, List<TxModel>> personTxs = {
      for (final e in txsByKey.entries) displayName[e.key]!: e.value,
    };

    final toReceive = personNet.values
        .where((v) => v > 0)
        .fold(0.0, (s, v) => s + v);
    final toGive = personNet.values
        .where((v) => v < 0)
        .fold(0.0, (s, v) => s + v.abs());

    final contacts = personNet.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: GestureDetector(
        onTap: () => _showContactsSheet(contacts, personTxs, isDark),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Amounts column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.expense,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'To give ',
                          style: TextStyle(
                            fontSize: 11,
                            color: sub,
                            fontFamily: 'Nunito',
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '₹${toGive.toStringAsFixed(0)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: AppColors.expense,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.income,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'To receive ',
                          style: TextStyle(
                            fontSize: 11,
                            color: sub,
                            fontFamily: 'Nunito',
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '₹${toReceive.toStringAsFixed(0)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: AppColors.income,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Avatars + chevron (fixed right section, max 3 avatars)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...contacts.take(3).map((e) {
                    final initials = e.key.isNotEmpty
                        ? e.key[0].toUpperCase()
                        : '?';
                    final isOwed = e.value > 0;
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: isOwed
                            ? AppColors.income.withValues(alpha: 0.15)
                            : AppColors.expense.withValues(alpha: 0.15),
                        child: Text(
                          initials,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: isOwed
                                ? AppColors.income
                                : AppColors.expense,
                          ),
                        ),
                      ),
                    );
                  }),
                  if (contacts.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: sub.withValues(alpha: 0.12),
                        child: Text(
                          '+${contacts.length - 3}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: sub,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: sub, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContactsSheet(
    List<MapEntry<String, double>> contacts,
    Map<String, List<TxModel>> personTxs,
    bool isDark,
  ) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scroll) => Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: sub.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                child: Row(
                  children: [
                    Text(
                      'Lend & Borrow',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: surfBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${contacts.length} contacts',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: sub,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scroll,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  itemCount: contacts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final entry = contacts[i];
                    final isOwed = entry.value > 0;
                    final amt = entry.value.abs();
                    final initials = entry.key.isNotEmpty
                        ? entry.key[0].toUpperCase()
                        : '?';
                    final txList = personTxs[entry.key] ?? [];
                    final hasMultiple = txList.length > 1;
                    return GestureDetector(
                      onTap: hasMultiple
                          ? () => Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                builder: (_) => _ContactTxPage(
                                  name: entry.key,
                                  netAmount: entry.value,
                                  transactions: txList,
                                  isDark: isDark,
                                ),
                              ),
                            )
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: surfBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: isOwed
                                  ? AppColors.income.withValues(alpha: 0.15)
                                  : AppColors.expense.withValues(alpha: 0.15),
                              child: Text(
                                initials,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Nunito',
                                  color: isOwed
                                      ? AppColors.income
                                      : AppColors.expense,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.key,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'Nunito',
                                      color: tc,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isOwed ? 'Owes you' : 'You owe',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'Nunito',
                                      color: sub,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₹${amt.toStringAsFixed(0)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'DM Mono',
                                color: isOwed
                                    ? AppColors.income
                                    : AppColors.expense,
                              ),
                            ),
                            if (hasMultiple) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: sub,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoFamilyEmpty(bool isDark) {
    final appState = AppStateScope.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 54)),
          const SizedBox(height: 14),
          Text(
            'No family group yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'Nunito',
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create a family group to track shared expenses',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final newId = await showAddFamilySheet(context, isDark, appState);
              if (newId != null && mounted) {
                widget.onWalletChange(newId);
                await appState.reload();
              }
            },
            icon: const Icon(Icons.group_add_rounded),
            label: const Text(
              'Add Family',
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

  // ── Shared wallet-tab body (card + transactions) ───────────────────────────
  Widget _buildWalletTabBody({
    required List<WalletModel> wallets,
    required Set<String> walletIds,
    required bool isDark,
    PageController? familyPageCtrl,
    Widget? extraHeader,
  }) {
    final groupedIds = _groupedTxIds;
    final base = _transactions
        .where((t) => walletIds.contains(t.walletId))
        .where((t) => _selectedRange.contains(t.date))
        .where((t) => !groupedIds.contains(t.id)) // grouped txs render inside TxGroupCard
        .toList();

    final grouped = <String, List<TxModel>>{};
    final sectionDates = <String, DateTime>{};
    for (final tx in base) {
      final diff = DateTime.now().difference(tx.date).inDays;
      final label = diff == 0
          ? 'Today'
          : diff == 1
          ? 'Yesterday'
          : '${tx.date.day} ${_monthName(tx.date.month)}';
      grouped.putIfAbsent(label, () => []).add(tx);
      sectionDates.putIfAbsent(label, () => tx.date);
    }
    // Ensure date-sections hosting only TxGroupCards also appear
    for (final g in _activeWalletTxGroups) {
      if (g.transactions.isEmpty) continue;
      if (!_selectedRange.contains(g.latestDate)) continue;
      final diff = DateTime.now().difference(g.latestDate).inDays;
      final label = diff == 0
          ? 'Today'
          : diff == 1
          ? 'Yesterday'
          : '${g.latestDate.day} ${_monthName(g.latestDate.month)}';
      grouped.putIfAbsent(label, () => []);
      sectionDates.putIfAbsent(label, () => g.latestDate);
    }

    // Sort sections newest-first so group-only date sections (e.g. a group
    // whose latest tx is 4 Mar) appear above older sections (3 Mar).
    final entries = grouped.entries.toList()
      ..sort((a, b) => (sectionDates[b.key] ?? DateTime(0))
          .compareTo(sectionDates[a.key] ?? DateTime(0)));
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Wallet card(s) at the top of the tab
          if (wallets.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildInlineWalletCards(
                wallets,
                isDark,
                pageCtrl: familyPageCtrl,
              ),
            ),
          if (extraHeader != null) SliverToBoxAdapter(child: extraHeader),
          // Transactions list or empty state
          if (entries.isEmpty)
            SliverFillRemaining(child: _buildEmpty(isDark))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _buildGroup(entries[i], isDark),
                  childCount: entries.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Inline wallet card(s) inside a tab ─────────────────────────────────────
  Widget _buildInlineWalletCards(
    List<WalletModel> wallets,
    bool isDark, {
    PageController? pageCtrl,
  }) {
    return Column(
      children: [
        const SizedBox(height: 8),
        if (wallets.length == 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Builder(
              builder: (_) {
                final ps = _periodStats(wallets[0].id);
                return WalletCardWidget(
                  wallet: wallets[0],
                  isActive: true,
                  periodCashIn: ps.cashIn,
                  periodCashOut: ps.cashOut,
                  periodOnlineIn: ps.onlineIn,
                  periodOnlineOut: ps.onlineOut,
                  onTap: () {},
                  onReports: () => WalletReportsSheet.show(
                    context,
                    transactions: _transactions
                        .where((t) => t.walletId == wallets[0].id)
                        .toList(),
                    wallet: wallets[0],
                  ),
                );
              },
            ),
          )
        else
          SizedBox(
            height: 220,
            child: PageView.builder(
              controller: pageCtrl ?? PageController(viewportFraction: 0.88),
              onPageChanged: pageCtrl != null
                  ? (i) => widget.onWalletChange(wallets[i].id)
                  : null,
              itemCount: wallets.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Builder(
                  builder: (_) {
                    final ps = _periodStats(wallets[i].id);
                    return WalletCardWidget(
                      wallet: wallets[i],
                      isActive: wallets[i].id == widget.activeWalletId,
                      periodCashIn: ps.cashIn,
                      periodCashOut: ps.cashOut,
                      periodOnlineIn: ps.onlineIn,
                      periodOnlineOut: ps.onlineOut,
                      onTap: () {},
                      onReports: () => WalletReportsSheet.show(
                        context,
                        transactions: _transactions
                            .where((t) => t.walletId == wallets[i].id)
                            .toList(),
                        wallet: wallets[i],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── SPLITS body ───────────────────────────────────────────────────────────
  Widget _buildSplitsBody(bool isDark) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    final groups = _splitGroups
        .where((g) => g.walletId == widget.activeWalletId)
        .toList();

    if (groups.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshAll,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(child: _buildSplitsEmpty(isDark, tc, sub)),
          ],
        ),
      );
    }

    // Build item list: [summary, create banner, ...groups]
    final itemCount = groups.length + 2;
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((_, i) {
                if (i == 0) {
                  return _buildSplitsSummary(groups, isDark, cardBg, tc, sub);
                }
                if (i == 1) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CreateGroupBanner(onTap: _openCreateGroup),
                  );
                }
                final g = groups[i - 2];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SplitGroupCard(
                    group: g,
                    isDark: isDark,
                    cardBg: cardBg,
                    surfBg: surfBg,
                    tc: tc,
                    sub: sub,
                    onTap: () => _openGroupDetail(g),
                    onEdit: () => _openEditGroup(g),
                    onAddExpense: () =>
                        _openGroupDetail(g, autoAddExpense: true),
                  ),
                );
              }, childCount: itemCount),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitsSummary(
    List<SplitGroup> groups,
    bool isDark,
    Color cardBg,
    Color tc,
    Color sub,
  ) {
    if (groups.isEmpty) return const SizedBox(height: 8);

    final totalSpend = groups.fold(0.0, (s, g) => s + g.totalSpend);
    final totalPending = groups.fold(0, (s, g) => s + g.pendingCount);
    final activeGroups = groups
        .where((g) => !g.transactions.every((t) => t.isFullySettled))
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4A9EFF), Color(0xFF0055CC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Split Spend',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Nunito',
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${totalSpend.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'DM Mono',
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _SummaryChip('${groups.length} groups', Icons.group_rounded),
                const SizedBox(height: 6),
                _SummaryChip(
                  '$activeGroups active',
                  Icons.radio_button_on_rounded,
                ),
                const SizedBox(height: 6),
                _SummaryChip('$totalPending pending', Icons.schedule_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitsEmpty(bool isDark, Color tc, Color sub) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🤝', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'No split groups yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                fontFamily: 'Nunito',
                color: tc,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create a group to split expenses\nwith friends or family',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: sub),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _openCreateGroup,
              icon: const Icon(Icons.group_add_rounded),
              label: const Text(
                'Create Group',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.split,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────
  AppBar _buildAppBar(bool isDark, Color textColor) {
    return AppBar(
      title: MonthYearPicker(
        selected: _selectedRange,
        onTap: () async {
          final picked = await MonthYearPicker.showPicker(
            context,
            _selectedRange,
          );
          if (picked != null) setState(() => _selectedRange = picked);
        },
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
            fontSize: 11,
            fontFamily: 'Nunito',
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 11,
            fontFamily: 'Nunito',
          ),
          padding: EdgeInsets.zero,
          tabs: kV1WalletTabs.map((t) {
            final label = t == WalletTab.wallet
                ? (_currentWallet.isPersonal ? 'Personal' : _currentWallet.name)
                : t.label;
            return Tab(text: label, height: 36);
          }).toList(),
        ),
      ),
    );
  }

  // ── Empty state (non-splits) ─────────────────────────────────────────────────
  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔍', style: TextStyle(fontSize: 50)),
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
          const SizedBox(height: 4),
          Text(
            'Tap + below to add one!',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
          const SizedBox(height: 12),
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

  // ── Transaction date-section ────────────────────────────────────────────────
  Widget _buildGroup(MapEntry<String, List<TxModel>> entry, bool isDark) {
    // Groups whose latest tx falls in this date-label section
    final sectionGroups = _activeWalletTxGroups
        .where((g) {
          if (g.transactions.isEmpty) return false;
          final diff = DateTime.now().difference(g.latestDate).inDays;
          final label = diff == 0
              ? 'Today'
              : diff == 1
              ? 'Yesterday'
              : '${g.latestDate.day} ${_monthName(g.latestDate.month)}';
          return label == entry.key;
        })
        .toList();

    final totalCount = entry.value.length + sectionGroups.length;

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
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.07),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$totalCount',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
        // TxGroup master cards first
        ...sectionGroups.map((g) => TxGroupCard(
              group: g,
              isDark: isDark,
              onTxTap: (tx) => _showDetail(tx),
              onTxLongPress: (tx) => _duplicateTx(tx),
              onAddExpense: () => _addToGroup(g),
              onRename: (name, emoji) => _renameTxGroup(g, name, emoji),
              onDeleteGroup: () => _deleteTxGroup(g),
            )),
        // Individual (ungrouped) tiles
        ...entry.value.map((tx) {
          final currentUid = AuthService.instance.currentUser?.id;
          final isRecipient =
              tx.type == TxType.request && tx.userId != currentUid;
          return TxTile(
            tx: tx,
            onTap: () => _showDetail(tx),
            onLongPress: () => _duplicateTx(tx),
            onAccept: isRecipient
                ? () => _handleRequestResponse(tx, accept: true)
                : null,
            onReject: isRecipient
                ? () => _handleRequestResponse(tx, accept: false)
                : null,
          );
        }),
      ],
    );
  }

  // ── Request accept / reject ─────────────────────────────────────────────────
  void _handleRequestResponse(TxModel tx, {required bool accept}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RequestResponseSheet(
        isAccept: accept,
        personName: tx.person,
        amount: tx.amount,
        onConfirm: (comment) async {
          final newStatus = accept ? 'Accepted' : 'Rejected';
          try {
            await WalletService.instance.updateTransaction(tx.id, {
              'status': newStatus,
              if (comment != null) 'note': comment,
            });
            final updated = TxModel(
              id: tx.id,
              type: tx.type,
              amount: tx.amount,
              category: tx.category,
              date: tx.date,
              walletId: tx.walletId,
              payMode: tx.payMode,
              note: comment ?? tx.note,
              person: tx.person,
              persons: tx.persons,
              status: newStatus,
              dueDate: tx.dueDate,
              userId: tx.userId,
            );
            setState(() {
              final idx = _transactions.indexWhere((t) => t.id == tx.id);
              if (idx >= 0) _transactions[idx] = updated;
            });
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to update: $e')),
              );
            }
          }
        },
      ),
    );
  }

  // ── Duplicate transaction ───────────────────────────────────────────────────
  void _duplicateTx(TxModel tx) {
    // Map TxType → FlowType
    final flowType = switch (tx.type) {
      TxType.income    => FlowType.income,
      TxType.lend      => FlowType.lend,
      TxType.borrow    => FlowType.borrow,
      TxType.split     => FlowType.split,
      TxType.request   => FlowType.request,
      TxType.returned  => FlowType.returned,
      _                => FlowType.expense,
    };

    final intent = ParsedIntent(
      flowType: flowType,
      amount: tx.amount,
      category: tx.category,
      title: tx.title,
      person: tx.person,
      payMode: tx.payMode,
      note: tx.note,
      date: DateTime.now(), // always today for duplicates
      confidence: 1.0,
    );

    IntentConfirmSheet.show(
      context,
      intent: intent,
      walletId: widget.activeWalletId,
      onSave: (saved) {
        _onTransactionSaved(saved);
      },
      onOpenFlow: () {
        // open the conversation flow for this type
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConversationScreen(
              flowType: flowType,
              walletId: widget.activeWalletId,
              wallets: _allWallets,
              onComplete: _onTransactionSaved,
            ),
          ),
        );
      },
    );
  }

  // ── Detail / Edit sheet ─────────────────────────────────────────────────────
  void _showDetail(TxModel tx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final otherWallets = _allWallets.where((w) => w.id != tx.walletId).toList();
    final walletGroups = _activeWalletTxGroups;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => TxDetailSheet(
        tx: tx,
        isDark: isDark,
        otherWallets: otherWallets,
        groups: walletGroups,
        onMove: (target) {
          Navigator.pop(context);
          _moveTxToWallet(tx, target);
        },
        onEdit: (updated) async {
          setState(() {
            final idx = _transactions.indexWhere((t) => t.id == updated.id);
            if (idx >= 0) _transactions[idx] = updated;
          });
          WalletService.instance.ensureCategory(updated.category, updated.type.name);
          try {
            final fields = <String, dynamic>{
              'type': updated.type.name,
              'amount': updated.amount,
              'category': updated.category,
              'date': updated.date.toIso8601String().substring(0, 10),
              'pay_mode': updated.payMode?.name,
              'note': updated.note,
              'person': updated.person,
            };
            if (updated.title != null) fields['title'] = updated.title;
            await WalletService.instance.updateTransaction(updated.id, fields);
            WalletService.txChangeSignal.value++;
          } catch (e) {
            debugPrint('[Wallet] updateTransaction failed: $e');
          }
        },
        onDelete: () async {
          setState(() => _transactions.removeWhere((t) => t.id == tx.id));
          try {
            await WalletService.instance.deleteTransaction(tx.id);
            WalletService.txChangeSignal.value++;
          } catch (e) {
            if (!mounted) return;
            setState(() => _transactions.add(tx));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete: $e')),
            );
          }
        },
        onAddToGroup: (picked) => _assignTxToGroup(tx, picked),
        onRemoveFromGroup: tx.groupId != null
            ? () => _unassignTxFromGroup(tx)
            : null,
      ),
    );
  }

  // ── Transaction Group management ────────────────────────────────────────────

  /// Open the conversation screen pre-set to expense, with group pre-assigned.
  void _addToGroup(TxGroup group) {
    _openConversation(FlowType.expense);
    // After save, _onTransactionSaved fires → we then assign group_id
    _pendingGroupForNextTx = group;
  }

  TxGroup? _pendingGroupForNextTx;

  /// Assign tx to a group. Creates the group first if its id is empty.
  Future<void> _assignTxToGroup(TxModel tx, TxGroup picked) async {
    try {
      String groupId = picked.id;
      if (groupId.isEmpty) {
        // New group — create it
        final row = await WalletService.instance.createTxGroup(
          walletId: tx.walletId,
          name: picked.name,
          emoji: picked.emoji,
        );
        groupId = row['id'] as String;
      }
      await WalletService.instance.setTxGroup(tx.id, groupId);
      // Update local tx
      final idx = _transactions.indexWhere((t) => t.id == tx.id);
      if (idx >= 0) {
        _transactions[idx] = TxModel(
          id: tx.id, type: tx.type, amount: tx.amount,
          category: tx.category, date: tx.date, walletId: tx.walletId,
          payMode: tx.payMode, title: tx.title, note: tx.note,
          person: tx.person, persons: tx.persons, status: tx.status,
          dueDate: tx.dueDate, userId: tx.userId, groupId: groupId,
        );
      }
      WalletService.txChangeSignal.value++;
      if (mounted) await _loadTxGroups();
    } catch (e) {
      debugPrint('[Wallet] assignTxToGroup failed: $e');
    }
  }

  Future<void> _unassignTxFromGroup(TxModel tx) async {
    try {
      await WalletService.instance.setTxGroup(tx.id, null);
      final idx = _transactions.indexWhere((t) => t.id == tx.id);
      if (idx >= 0) {
        _transactions[idx] = TxModel(
          id: tx.id, type: tx.type, amount: tx.amount,
          category: tx.category, date: tx.date, walletId: tx.walletId,
          payMode: tx.payMode, title: tx.title, note: tx.note,
          person: tx.person, persons: tx.persons, status: tx.status,
          dueDate: tx.dueDate, userId: tx.userId, groupId: null,
        );
      }
      WalletService.txChangeSignal.value++;
      if (mounted) await _loadTxGroups();
    } catch (e) {
      debugPrint('[Wallet] unassignTxFromGroup failed: $e');
    }
  }

  Future<void> _renameTxGroup(TxGroup g, String name, String emoji) async {
    try {
      await WalletService.instance.updateTxGroup(g.id, name: name, emoji: emoji);
      if (mounted) await _loadTxGroups();
    } catch (e) {
      debugPrint('[Wallet] renameTxGroup failed: $e');
    }
  }

  Future<void> _deleteTxGroup(TxGroup g) async {
    try {
      await WalletService.instance.deleteTxGroup(g.id);
      // group_id on member txs is set to NULL by DB (ON DELETE SET NULL)
      // Reload so those txs reappear as ungrouped
      if (mounted) {
        await _loadTransactions();
      }
    } catch (e) {
      debugPrint('[Wallet] deleteTxGroup failed: $e');
    }
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// CREATE GROUP BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _CreateGroupBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateGroupBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.split.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.split.withValues(alpha: 0.3),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.split,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.group_add_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create New Group',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                      color: AppColors.split,
                    ),
                  ),
                  Text(
                    'Split expenses with friends & family',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Nunito',
                      color: AppColors.split,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.split,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SPLIT GROUP CARD
// ─────────────────────────────────────────────────────────────────────────────

class _SplitGroupCard extends StatelessWidget {
  final SplitGroup group;
  final bool isDark;
  final Color cardBg, surfBg, tc, sub;
  final VoidCallback onTap, onEdit, onAddExpense;

  const _SplitGroupCard({
    required this.group,
    required this.isDark,
    required this.cardBg,
    required this.surfBg,
    required this.tc,
    required this.sub,
    required this.onTap,
    required this.onEdit,
    required this.onAddExpense,
  });

  @override
  Widget build(BuildContext context) {
    final balances = group.netBalances;
    final meId = group.participants
        .firstWhere(
          (p) => p.isMe,
          orElse: () => SplitParticipant(id: 'me', name: 'Me', emoji: '🧑'),
        )
        .id;
    final myBalance = balances[meId] ?? 0;
    final isOwed = myBalance > 0;
    final isEven = myBalance.abs() < 0.01;
    final balColor = isEven
        ? sub
        : (isOwed ? AppColors.income : AppColors.expense);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Emoji circle
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.split.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    group.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito',
                          color: tc,
                        ),
                      ),
                      Text(
                        '${group.participants.length} members · '
                        '${group.transactions.length} expenses',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Nunito',
                          color: sub,
                        ),
                      ),
                    ],
                  ),
                ),
                // Edit button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onEdit();
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: surfBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.edit_rounded, size: 16, color: sub),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Stats row
            Row(
              children: [
                _StatPill(
                  label: '₹${group.totalSpend.toStringAsFixed(0)}',
                  sublabel: 'Total Spend',
                  color: AppColors.split,
                ),
                const SizedBox(width: 8),
                _StatPill(
                  label: '${group.pendingCount}',
                  sublabel: 'Pending',
                  color: group.pendingCount > 0
                      ? AppColors.expense
                      : AppColors.income,
                ),
                const SizedBox(width: 8),
                _StatPill(
                  label: isEven
                      ? 'Settled'
                      : isOwed
                      ? '+₹${myBalance.abs().toStringAsFixed(0)}'
                      : '-₹${myBalance.abs().toStringAsFixed(0)}',
                  sublabel: isEven
                      ? 'Your status'
                      : isOwed
                      ? 'You get back'
                      : 'You owe',
                  color: balColor,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Participant avatars row
            Row(
              children: [
                SizedBox(
                  height: 28,
                  width: 20.0 + (group.participants.length.clamp(0, 5) * 20),
                  child: Stack(
                    children: group.participants
                        .take(5)
                        .toList()
                        .asMap()
                        .entries
                        .map((e) {
                          final i = e.key;
                          final p = e.value;
                          return Positioned(
                            left: i * 20.0,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.split.withValues(alpha: 0.12),
                                border: Border.all(color: cardBg, width: 1.5),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                p.emoji,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          );
                        })
                        .toList(),
                  ),
                ),
                if (group.participants.length > 5) ...[
                  const SizedBox(width: 4),
                  Text(
                    '+${group.participants.length - 5} more',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'Nunito',
                      color: sub,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 10),

            // Actions row: Add Expense + settlement progress
            Row(
              children: [
                // Quick add expense button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onAddExpense();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.split.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.split.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 14,
                          color: AppColors.split,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Add Expense',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                            color: AppColors.split,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // Settlement progress
                if (group.transactions.isNotEmpty) ...[
                  Text(
                    '${group.transactions.where((t) => t.isFullySettled).length}'
                    '/${group.transactions.length} settled',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'Nunito',
                      color: sub,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: group.transactions.isEmpty
                            ? 0
                            : group.transactions
                                      .where((t) => t.isFullySettled)
                                      .length /
                                  group.transactions.length,
                        backgroundColor: AppColors.expense.withValues(
                          alpha: 0.15,
                        ),
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.income,
                        ),
                        minHeight: 5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAT PILL widget
// ─────────────────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String label, sublabel;
  final Color color;
  const _StatPill({
    required this.label,
    required this.sublabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              fontFamily: 'DM Mono',
              color: color,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            sublabel,
            style: TextStyle(
              fontSize: 9,
              fontFamily: 'Nunito',
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY CHIP (inside hero card)
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SummaryChip(this.label, this.icon);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: Colors.white70),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontFamily: 'Nunito',
            color: Colors.white70,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

// ── Contact Transaction Detail Page ─────────────────────────────────────────
class _ContactTxPage extends StatelessWidget {
  final String name;
  final double netAmount; // positive = they owe me, negative = I owe them
  final List<TxModel> transactions;
  final bool isDark;

  const _ContactTxPage({
    required this.name,
    required this.netAmount,
    required this.transactions,
    required this.isDark,
  });

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 10000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  String _dateLabel(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
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
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final scaffoldBg = isDark ? AppColors.bgDark : AppColors.bgLight;

    final isOwed = netAmount > 0;
    final netColor = isOwed ? AppColors.income : AppColors.expense;
    final sorted = [...transactions]..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: scaffoldBg,
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
            CircleAvatar(
              radius: 16,
              backgroundColor: netColor.withValues(alpha: 0.15),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Nunito',
                  color: netColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                  color: tc,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Net summary banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: netColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: netColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Text(
                  isOwed ? 'Net: Owes you' : 'Net: You owe',
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Nunito',
                    color: sub,
                  ),
                ),
                const Spacer(),
                Text(
                  '₹${_fmt(netAmount.abs())}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'DM Mono',
                    color: netColor,
                  ),
                ),
              ],
            ),
          ),
          // Transaction list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: sorted.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final tx = sorted[i];
                final txColor = tx.type == TxType.lend ? AppColors.expense
                             : tx.type == TxType.returned ? AppColors.returned
                             : AppColors.income;
                final txLabel = tx.type == TxType.lend ? 'Lent'
                             : tx.type == TxType.returned ? 'Returned'
                             : 'Borrowed';
                final txEmoji = tx.type == TxType.lend ? '📤'
                             : tx.type == TxType.returned ? '↩️'
                             : '📥';
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: surfBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: txColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          txEmoji,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx.note ?? tx.category,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Nunito',
                                color: tc,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _dateLabel(tx.date),
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Nunito',
                                color: sub,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${_fmt(tx.amount)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'DM Mono',
                              color: txColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: txColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              txLabel,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                                color: txColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
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

// ─────────────────────────────────────────────────────────────────────────────
// REQUEST ACCEPT / REJECT SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _RequestResponseSheet extends StatefulWidget {
  final bool isAccept;
  final String? personName;
  final double amount;
  final void Function(String? comment) onConfirm;

  const _RequestResponseSheet({
    required this.isAccept,
    required this.amount,
    this.personName,
    required this.onConfirm,
  });

  @override
  State<_RequestResponseSheet> createState() => _RequestResponseSheetState();
}

class _RequestResponseSheetState extends State<_RequestResponseSheet> {
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  String _fmtAmt(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}K' : v.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final isAccept = widget.isAccept;
    final actionColor =
        isAccept ? const Color(0xFF00C897) : const Color(0xFFFF5C7A);
    final actionEmoji = isAccept ? '✅' : '❌';
    final title = isAccept ? 'Accept Request?' : 'Reject Request?';
    final hint = isAccept
        ? 'Add a comment (optional)'
        : 'Reason for rejection (optional)';
    final buttonLabel = isAccept ? 'Confirm Accept' : 'Confirm Rejection';

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Emoji + title
            Text(actionEmoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
                color: isDark ? AppColors.textDark : AppColors.textLight,
              ),
            ),

            // Request summary
            const SizedBox(height: 6),
            Text(
              '₹${_fmtAmt(widget.amount)}'
              '${widget.personName != null ? ' from ${widget.personName}' : ''}',
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Nunito',
                color: isDark ? AppColors.subDark : AppColors.subLight,
              ),
            ),

            const SizedBox(height: 20),

            // Comment / reason field
            TextField(
              controller: _commentCtrl,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: isDark ? AppColors.subDark : AppColors.subLight,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF242436)
                    : const Color(0xFFF5F5F8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              minLines: 2,
              maxLines: 4,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Nunito',
                color: isDark ? AppColors.textDark : AppColors.textLight,
              ),
            ),

            const SizedBox(height: 16),

            // Confirm button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final comment = _commentCtrl.text.trim().isEmpty
                      ? null
                      : _commentCtrl.text.trim();
                  Navigator.pop(context);
                  widget.onConfirm(comment);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: actionColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
