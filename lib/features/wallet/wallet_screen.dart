import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wai_life_assistant/features/wallet/widgets/month_year_picker.dart';
import 'package:wai_life_assistant/features/wallet/widgets/family_switcher_sheet.dart';
import 'package:wai_life_assistant/features/wallet/widgets/chat_input_bar.dart';
import 'package:wai_life_assistant/features/wallet/widgets/tx_tile.dart';
import 'package:wai_life_assistant/features/wallet/widgets/wallet_card_widget.dart';
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
import 'package:wai_life_assistant/features/AppStateNotifier.dart';
import 'package:wai_life_assistant/features/auth/auth_service.dart';
import 'package:wai_life_assistant/core/supabase/wallet_service.dart';

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
  WalletTab _activeTab = WalletTab.personal;
  late TabController _tabCtrl;

  // Calendar
  MonthRange _selectedRange = MonthRange.thisMonth();

  // Voice + speech simulation
  bool _isListening = false;
  final _chatBarKey = GlobalKey<ChatInputBarState>();

  // Live transaction list (loaded async)
  List<TxModel> _transactions = [];
  bool _txLoading = true;

  // Split groups
  late List<SplitGroup> _splitGroups;
  bool _sgLoading = true;

  // Wallets list (from AppStateScope)
  List<WalletModel> _allWallets = [];

  WalletModel get _currentWallet => _allWallets.firstWhere(
    (w) => w.id == widget.activeWalletId,
    orElse: () => _allWallets.isNotEmpty ? _allWallets.first : personalWallet,
  );

  @override
  void initState() {
    super.initState();
    _splitGroups = [];
    _tabCtrl = TabController(length: WalletTab.values.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        final tab = WalletTab.values[_tabCtrl.index];
        setState(() => _activeTab = tab);
        _autoSwitchWalletForTab(tab);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newWallets = AppStateScope.of(context).wallets;
    if (newWallets != _allWallets) {
      _allWallets = newWallets;
    }
    // Initial transaction load
    if (_txLoading) _loadTransactions();
    if (_sgLoading) _loadSplitGroups();
  }

  @override
  void didUpdateWidget(WalletScreen old) {
    super.didUpdateWidget(old);
    if (old.activeWalletId != widget.activeWalletId) {
      _loadTransactions();
      _loadSplitGroups();
    }
  }

  Future<void> _loadTransactions() async {
    setState(() => _txLoading = true);
    try {
      if (!AuthService.instance.isLoggedIn || widget.activeWalletId.isEmpty) {
        // Bypass mode: filter mock transactions for this wallet
        if (mounted) {
          setState(() {
            _transactions = mockTransactions
                .where((t) => t.walletId == widget.activeWalletId)
                .toList();
            _txLoading = false;
          });
        }
        return;
      }
      final rows = await WalletService.instance.fetchTransactions(
        widget.activeWalletId,
      );
      if (mounted) {
        setState(() {
          _transactions = rows.map(TxModel.fromRow).toList();
          _txLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _transactions = mockTransactions
              .where((t) => t.walletId == widget.activeWalletId)
              .toList();
          _txLoading = false;
        });
      }
    }
  }

  Future<void> _loadSplitGroups() async {
    setState(() => _sgLoading = true);
    try {
      if (!AuthService.instance.isLoggedIn || widget.activeWalletId.isEmpty) {
        if (mounted) {
          setState(() {
            _splitGroups = List.from(mockSplitGroups);
            _sgLoading = false;
          });
        }
        return;
      }
      final rows = await WalletService.instance.fetchSplitGroups(widget.activeWalletId);
      if (mounted) {
        setState(() {
          _splitGroups = rows.map(_splitGroupFromRow).toList();
          _sgLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[WalletScreen] fetchSplitGroups failed: $e');
      if (mounted) {
        setState(() {
          _splitGroups = List.from(mockSplitGroups);
          _sgLoading = false;
        });
      }
    }
  }

  SplitGroup _splitGroupFromRow(Map<String, dynamic> row) {
    final rawParticipants = (row['split_participants'] as List? ?? []);
    final participants = rawParticipants.map((p) => SplitParticipant(
      id: p['id'] as String,
      name: p['name'] as String,
      emoji: p['emoji'] as String? ?? '👤',
      phone: p['phone'] as String?,
      isMe: p['is_me'] as bool? ?? false,
    )).toList();

    final rawTxs = (row['split_group_transactions'] as List? ?? []);
    final transactions = rawTxs.map((t) {
      final rawShares = (t['split_shares'] as List? ?? []);
      final shares = rawShares.map((s) => SplitShare(
        participantId: s['participant_id'] as String,
        amount: (s['amount'] as num).toDouble(),
        percentage: s['percentage'] != null ? (s['percentage'] as num).toDouble() : null,
        status: _parseSettleStatus(s['status'] as String? ?? 'pending'),
      )).toList();
      return SplitGroupTx(
        id: t['id'] as String,
        groupId: t['group_id'] as String,
        addedById: t['added_by_id'] as String,
        title: t['title'] as String,
        totalAmount: (t['total_amount'] as num).toDouble(),
        splitType: _parseSplitType(t['split_type'] as String? ?? 'equal'),
        shares: shares,
        date: DateTime.parse(t['date'] as String),
        note: t['note'] as String?,
      );
    }).toList();

    return SplitGroup(
      id: row['id'] as String,
      name: row['name'] as String,
      emoji: row['emoji'] as String? ?? '🤝',
      walletId: row['wallet_id'] as String,
      participants: participants,
      transactions: transactions,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : null,
    );
  }

  SplitType _parseSplitType(String s) {
    switch (s) {
      case 'unequal':   return SplitType.unequal;
      case 'percentage': return SplitType.percentage;
      case 'custom':    return SplitType.custom;
      default:          return SplitType.equal;
    }
  }

  SettleStatus _parseSettleStatus(String s) {
    switch (s) {
      case 'proofSubmitted':      return SettleStatus.proofSubmitted;
      case 'settled':             return SettleStatus.settled;
      case 'extensionRequested':  return SettleStatus.extensionRequested;
      case 'extensionGranted':    return SettleStatus.extensionGranted;
      default:                    return SettleStatus.pending;
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  List<TxModel> get _filteredTx {
    final base = _transactions
        .where((t) => t.walletId == widget.activeWalletId)
        .where((t) => _selectedRange.contains(t.date))
        .toList();

    switch (_activeTab) {
      case WalletTab.personal:
      case WalletTab.family:
        return base;
      case WalletTab.splits:
        return base.where((t) => t.type == TxType.split).toList();
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

  // Compute period-filtered breakdown from local transactions for a wallet
  ({double cashIn, double cashOut, double onlineIn, double onlineOut})
      _periodStats(String walletId) {
    final txs = _transactions
        .where((t) => t.walletId == walletId && _selectedRange.contains(t.date))
        .toList();
    double cashIn = 0, cashOut = 0, onlineIn = 0, onlineOut = 0;
    for (final t in txs) {
      final isIn  = t.type == TxType.income || t.type == TxType.borrow;
      final isOut = t.type == TxType.expense || t.type == TxType.lend || t.type == TxType.split;
      if (t.payMode == PayMode.cash) {
        if (isIn)  cashIn  += t.amount;
        if (isOut) cashOut += t.amount;
      } else if (t.payMode == PayMode.online) {
        if (isIn)  onlineIn  += t.amount;
        if (isOut) onlineOut += t.amount;
      }
    }
    return (cashIn: cashIn, cashOut: cashOut, onlineIn: onlineIn, onlineOut: onlineOut);
  }

  void _switchWallet(String id) {
    setState(() => widget.onWalletChange(id));
  }

  void _autoSwitchWalletForTab(WalletTab tab) {
    final WalletModel? target;
    switch (tab) {
      case WalletTab.personal:
      case WalletTab.splits:
        target = _allWallets.where((w) => w.isPersonal).firstOrNull;
      case WalletTab.family:
        target = _allWallets.where((w) => !w.isPersonal).firstOrNull;
    }
    if (target != null && target.id != widget.activeWalletId) {
      widget.onWalletChange(target.id);
    }
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
    _showTxSnackBar(tx);
    _persistTransaction(tx); // fire-and-forget
  }

  Future<void> _persistTransaction(TxModel tx) async {
    if (!AuthService.instance.isLoggedIn) {
      // Bypass mode: keep in local list only
      mockTransactions.insert(0, tx);
      return;
    }
    try {
      final row = await WalletService.instance.addTransaction(
        walletId: tx.walletId,
        type:     tx.type.name,
        amount:   tx.amount,
        category: tx.category,
        payMode:  tx.payMode?.name,
        note:     tx.note,
        person:   tx.person,
        persons:  tx.persons,
        dueDate:  tx.dueDate,
        date:     tx.date,
      );
      if (!mounted) return;
      // Replace local placeholder id with real DB row
      final saved = TxModel.fromRow(row);
      setState(() {
        final idx = _transactions.indexWhere((t) => t.id == tx.id);
        if (idx >= 0) _transactions[idx] = saved;
      });
      // Reload wallet so the card reflects updated balance
      await AppStateScope.of(context).reload();
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

  void _showTxSnackBar(TxModel tx) {
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

  void _onChatSubmit(String text) {
    final intent = NlpParser.parse(text);
    if (intent.confidence >= 0.5) {
      IntentConfirmSheet.show(
        context,
        intent: intent,
        walletId: widget.activeWalletId,
        onSave: _onTransactionSaved,
        onOpenFlow: () => _openConversation(intent.flowType),
      );
    } else if (intent.confidence >= 0.25) {
      _openConversation(intent.flowType);
    } else {
      _openFlowSelector();
    }
  }

  void _onMicTap() {
    HapticFeedback.mediumImpact();
    if (_isListening) {
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted || !_isListening) return;
        setState(() => _isListening = false);
        const _sttSamples = [
          'paid 500 for lunch via cash',
          'received 45000 salary online',
          'lent 2000 to Rahul',
          'spent 320 on auto travel',
          'split 1200 dinner with Priya',
        ];
        final sample = (_sttSamples.toList()..shuffle()).first;
        _chatBarKey.currentState?.setTextFromSpeech(sample);
      });
    }
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
            .map((p) => (
                  name: p.name,
                  emoji: p.emoji,
                  phone: p.phone,
                  isMe: p.isMe,
                ))
            .toList(),
      );
      if (!mounted) return;
      // Replace local placeholder ids with real DB ids (group + participants)
      final realId = row['id'] as String;
      final rawParts = (row['split_participants'] as List? ?? []);
      final realParticipants = rawParts.map((p) => SplitParticipant(
        id: p['id'] as String,
        name: p['name'] as String,
        emoji: p['emoji'] as String? ?? '👤',
        phone: p['phone'] as String?,
        isMe: p['is_me'] as bool? ?? false,
      )).toList();
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
      },
      onDelete: () {
        setState(() => _splitGroups.removeWhere((g) => g.id == group.id));
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

    return Scaffold(
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
                children: [
                  _buildPersonalBody(isDark),
                  _buildFamilyBody(isDark),
                  _buildSplitsBody(isDark),
                ],
              ),
            ),
          ),

          ChatInputBar(
            key: _chatBarKey,
            onSubmit: _onChatSubmit,
            onMicTap: _onMicTap,
            onAddTap: _activeTab == WalletTab.splits
                ? _openCreateGroup
                : _openFlowSelector,
            isListening: _isListening,
          ),
        ],
      ),
    );
  }

  // ── Personal tab body ──────────────────────────────────────────────────────
  Widget _buildPersonalBody(bool isDark) {
    final wallets = _allWallets.where((w) => w.isPersonal).toList();
    final ids = wallets.map((w) => w.id).toSet();
    return _buildWalletTabBody(
      wallets: wallets,
      walletIds: ids,
      isDark: isDark,
      extraHeader: _buildContactStrip(ids, isDark),
    );
  }

  // ── Contact strip (lend/borrow summary) ───────────────────────────────────
  Widget _buildContactStrip(Set<String> walletIds, bool isDark) {
    final txs = _transactions
        .where((t) => walletIds.contains(t.walletId))
        .where((t) => _selectedRange.contains(t.date))
        .where((t) => t.type == TxType.lend || t.type == TxType.borrow)
        .toList();

    if (txs.isEmpty) return const SizedBox.shrink();

    // Net per person + per-person tx list
    final Map<String, double> personNet = {};
    final Map<String, List<TxModel>> personTxs = {};
    for (final tx in txs) {
      final name = tx.person ?? 'Unknown';
      final delta = tx.type == TxType.lend ? tx.amount : -tx.amount;
      personNet[name] = (personNet[name] ?? 0) + delta;
      (personTxs[name] ??= []).add(tx);
    }

    final toReceive =
        personNet.values.where((v) => v > 0).fold(0.0, (s, v) => s + v);
    final toGive =
        personNet.values.where((v) => v < 0).fold(0.0, (s, v) => s + v.abs());

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
                          'To give  ',
                          style: TextStyle(
                            fontSize: 11,
                            color: sub,
                            fontFamily: 'Nunito',
                          ),
                        ),
                        Text(
                          '₹${toGive.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: AppColors.expense,
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
                          'To receive  ',
                          style: TextStyle(
                            fontSize: 11,
                            color: sub,
                            fontFamily: 'Nunito',
                          ),
                        ),
                        Text(
                          '₹${toReceive.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: AppColors.income,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Avatars
              Row(
                children: [
                  ...contacts.take(4).map((e) {
                    final initials = e.key.isNotEmpty
                        ? e.key[0].toUpperCase()
                        : '?';
                    final isOwed = e.value > 0;
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: isOwed
                            ? AppColors.income.withValues(alpha: 0.15)
                            : AppColors.expense.withValues(alpha: 0.15),
                        child: Text(
                          initials,
                          style: TextStyle(
                            fontSize: 12,
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
                  if (contacts.length > 4)
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: sub.withValues(alpha: 0.12),
                      child: Text(
                        '+${contacts.length - 4}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                          color: sub,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: sub,
                size: 20,
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
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
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
                          horizontal: 10, vertical: 4),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                            horizontal: 14, vertical: 12),
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
                              style: TextStyle(
                                fontSize: 16,
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

  // ── Family tab body ────────────────────────────────────────────────────────
  Widget _buildFamilyBody(bool isDark) {
    final wallets = _allWallets.where((w) => !w.isPersonal).toList();
    final ids = wallets.map((w) => w.id).toSet();
    return _buildWalletTabBody(
      wallets: wallets,
      walletIds: ids,
      isDark: isDark,
      extraHeader: _buildContactStrip(ids, isDark),
    );
  }

  // ── Shared wallet-tab body (card + transactions) ───────────────────────────
  Widget _buildWalletTabBody({
    required List<WalletModel> wallets,
    required Set<String> walletIds,
    required bool isDark,
    Widget? extraHeader,
  }) {
    final base = _transactions
        .where((t) => walletIds.contains(t.walletId))
        .where((t) => _selectedRange.contains(t.date))
        .toList();

    final grouped = <String, List<TxModel>>{};
    for (final tx in base) {
      final diff = DateTime.now().difference(tx.date).inDays;
      final label = diff == 0
          ? 'Today'
          : diff == 1
          ? 'Yesterday'
          : '${tx.date.day} ${_monthName(tx.date.month)}';
      grouped.putIfAbsent(label, () => []).add(tx);
    }

    final entries = grouped.entries.toList();
    return CustomScrollView(
      slivers: [
        // Wallet card(s) at the top of the tab
        if (wallets.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildInlineWalletCards(wallets, isDark),
          ),
        if (extraHeader != null)
          SliverToBoxAdapter(child: extraHeader),
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
    );
  }

  // ── Inline wallet card(s) inside a tab ─────────────────────────────────────
  Widget _buildInlineWalletCards(List<WalletModel> wallets, bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 8),
        if (wallets.length == 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Builder(builder: (_) {
              final ps = _periodStats(wallets[0].id);
              return WalletCardWidget(
                wallet: wallets[0],
                isActive: true,
                periodCashIn: ps.cashIn,
                periodCashOut: ps.cashOut,
                periodOnlineIn: ps.onlineIn,
                periodOnlineOut: ps.onlineOut,
                onTap: () {},
              );
            }),
          )
        else
          SizedBox(
            height: 220,
            child: PageView.builder(
              controller: PageController(viewportFraction: 0.88),
              itemCount: wallets.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Builder(builder: (_) {
                  final ps = _periodStats(wallets[i].id);
                  return WalletCardWidget(
                    wallet: wallets[i],
                    isActive: true,
                    periodCashIn: ps.cashIn,
                    periodCashOut: ps.cashOut,
                    periodOnlineIn: ps.onlineIn,
                    periodOnlineOut: ps.onlineOut,
                    onTap: () {},
                  );
                }),
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
      return CustomScrollView(
        slivers: [
          SliverFillRemaining(child: _buildSplitsEmpty(isDark, tc, sub)),
        ],
      );
    }

    // Build item list: [summary, create banner, ...groups]
    final itemCount = groups.length + 2;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((_, i) {
              if (i == 0)
                return _buildSplitsSummary(groups, isDark, cardBg, tc, sub);
              if (i == 1)
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CreateGroupBanner(onTap: _openCreateGroup),
                );
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
                  onAddExpense: () => _openGroupDetail(g, autoAddExpense: true),
                ),
              );
            }, childCount: itemCount),
          ),
        ),
      ],
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
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
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
          tabs: WalletTab.values
              .map((t) => Tab(text: t.label, height: 36))
              .toList(),
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

  // ── Transaction Group section ───────────────────────────────────────────────
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
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.07),
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

  // ── Detail / Edit sheet ─────────────────────────────────────────────────────
  void _showDetail(TxModel tx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TxDetailSheet(
        tx: tx,
        isDark: isDark,
        onEdit: (updated) {
          setState(() {
            final idx = _transactions.indexWhere((t) => t.id == updated.id);
            if (idx >= 0) _transactions[idx] = updated;
          });
        },
        onDelete: () =>
            setState(() => _transactions.removeWhere((t) => t.id == tx.id)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TX DETAIL + EDIT SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _TxDetailSheet extends StatelessWidget {
  final TxModel tx;
  final bool isDark;
  final void Function(TxModel) onEdit;
  final VoidCallback onDelete;

  const _TxDetailSheet({
    required this.tx,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      decoration: BoxDecoration(
        color: bg,
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
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          TxTile(tx: tx),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) =>
                          _TxEditSheet(tx: tx, isDark: isDark, onSave: onEdit),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
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
                    onDelete();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TxEditSheet extends StatefulWidget {
  final TxModel tx;
  final bool isDark;
  final void Function(TxModel) onSave;

  const _TxEditSheet({
    required this.tx,
    required this.isDark,
    required this.onSave,
  });

  @override
  State<_TxEditSheet> createState() => _TxEditSheetState();
}

class _TxEditSheetState extends State<_TxEditSheet> {
  late TextEditingController _amtCtrl;
  late TextEditingController _catCtrl;
  late TextEditingController _noteCtrl;
  late TextEditingController _personCtrl;
  late TxType _type;
  late PayMode? _payMode;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final tx = widget.tx;
    _amtCtrl = TextEditingController(text: tx.amount.toStringAsFixed(0));
    _catCtrl = TextEditingController(text: tx.category);
    _noteCtrl = TextEditingController(text: tx.note ?? '');
    _personCtrl = TextEditingController(text: tx.person ?? '');
    _type = tx.type;
    _payMode = tx.payMode;
    _date = tx.date;
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    _catCtrl.dispose();
    _noteCtrl.dispose();
    _personCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final amount = double.tryParse(_amtCtrl.text.replaceAll(',', ''));
    final cat = _catCtrl.text.trim();
    if (amount == null || amount <= 0 || cat.isEmpty) return;
    HapticFeedback.mediumImpact();

    widget.onSave(
      TxModel(
        id: widget.tx.id,
        type: _type,
        amount: amount,
        category: cat,
        date: _date,
        walletId: widget.tx.walletId,
        payMode: _payMode,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        person: _personCtrl.text.trim().isEmpty
            ? null
            : _personCtrl.text.trim(),
        persons: widget.tx.persons,
        status: widget.tx.status,
        dueDate: widget.tx.dueDate,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    final showPerson =
        _type == TxType.lend ||
        _type == TxType.borrow ||
        _type == TxType.request;
    final showPayMode =
        _type == TxType.income ||
        _type == TxType.expense ||
        _type == TxType.lend ||
        _type == TxType.borrow;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle + header
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
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(_type.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Text(
                    'Edit Transaction',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                      color: tc,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Type chips
              _ELbl('TYPE', sub),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: TxType.values.map((t) {
                    final sel = t == _type;
                    return GestureDetector(
                      onTap: () => setState(() => _type = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: sel ? t.color.withValues(alpha: 0.12) : surfBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel ? t.color : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(t.emoji, style: const TextStyle(fontSize: 15)),
                            const SizedBox(width: 5),
                            Text(
                              t.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                                color: sel ? t.color : sub,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // Amount
              _ELbl('AMOUNT', sub),
              TextField(
                controller: _amtCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'DM Mono',
                  color: _type.color,
                ),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(
                    fontSize: 18,
                    color: _type.color.withValues(alpha: 0.6),
                    fontFamily: 'DM Mono',
                  ),
                  filled: true,
                  fillColor: surfBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Category
              _ELbl('CATEGORY', sub),
              _EField(_catCtrl, 'e.g. Food, Travel…', surfBg, tc),
              const SizedBox(height: 14),

              // Person (lend/borrow/request)
              if (showPerson) ...[
                _ELbl('PERSON', sub),
                _EField(_personCtrl, 'Name of person', surfBg, tc),
                const SizedBox(height: 14),
              ],

              // Pay mode chips
              if (showPayMode) ...[
                _ELbl('PAY MODE', sub),
                Row(
                  children: PayMode.values.map((m) {
                    final sel = _payMode == m;
                    final lbl = m == PayMode.cash ? '💵 Cash' : '📱 Online';
                    final col = m == PayMode.cash
                        ? const Color(0xFF43A047)
                        : const Color(0xFF1E88E5);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _payMode = m),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: sel ? col.withValues(alpha: 0.1) : surfBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: sel ? col : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            lbl,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Nunito',
                              color: sel ? col : sub,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
              ],

              // Date
              _ELbl('DATE', sub),
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) setState(() => _date = d);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: surfBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 16, color: sub),
                      const SizedBox(width: 10),
                      Text(
                        '${_date.day} ${['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][_date.month]} ${_date.year}',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          color: tc,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Note
              _ELbl('NOTE (OPTIONAL)', sub),
              _EField(_noteCtrl, 'Add a note…', surfBg, tc, maxLines: 2),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: _type.color,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                      color: Colors.white,
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

  Widget _ELbl(String t, Color c) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        fontFamily: 'Nunito',
        color: c,
      ),
    ),
  );

  Widget _EField(
    TextEditingController c,
    String hint,
    Color s,
    Color tc, {
    int maxLines = 1,
  }) => TextField(
    controller: c,
    maxLines: maxLines,
    style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: tc),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: 12,
        color: AppColors.subLight,
      ),
      filled: true,
      fillColor: s,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
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
        .firstWhere((p) => p.isMe, orElse: () => SplitParticipant(id: 'me', name: 'Me', emoji: '🧑'))
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.split.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.split.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_rounded, size: 14, color: AppColors.split),
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
                    ]),
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
                        backgroundColor: AppColors.expense.withValues(alpha: 0.15),
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
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
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
            Text(
              name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
                color: tc,
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
                final isLend = tx.type == TxType.lend;
                final txColor = isLend ? AppColors.expense : AppColors.income;
                final txLabel = isLend ? 'Lent' : 'Borrowed';
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
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
                          isLend ? '📤' : '📥',
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
                                horizontal: 6, vertical: 2),
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
