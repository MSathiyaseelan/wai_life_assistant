import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wai_life_assistant/data/models/wallet/split_group_models.dart';
import '../../../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SPLIT GROUP DETAIL SCREEN
// Full-page view. Three inner tabs:
//   Overview  — group stats, member balances, quick settle nudge
//   Expenses  — all transactions with split breakdown + settle per share
//   Chat      — group message thread
// ─────────────────────────────────────────────────────────────────────────────

class SplitGroupDetailScreen extends StatefulWidget {
  final SplitGroup group;
  final void Function(SplitGroup) onGroupUpdated;

  const SplitGroupDetailScreen({
    super.key,
    required this.group,
    required this.onGroupUpdated,
  });

  @override
  State<SplitGroupDetailScreen> createState() => _SplitGroupDetailScreenState();
}

class _SplitGroupDetailScreenState extends State<SplitGroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late SplitGroup _group;
  late TabController _tab;
  final _chatCtrl = TextEditingController();
  final _chatScroll = ScrollController();

  static const String _myId = 'me';

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    _chatCtrl.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  void _update() {
    setState(() {});
    widget.onGroupUpdated(_group);
  }

  String _participantName(String id) => _group.participantById(id)?.name ?? id;

  String _participantEmoji(String id) =>
      _group.participantById(id)?.emoji ?? '🧑';

  // ── Add expense ────────────────────────────────────────────────────────────
  void _showAddExpense() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _AddExpenseSheet.show(
      context,
      isDark: isDark,
      group: _group,
      onSave: (tx) {
        setState(() => _group.transactions.insert(0, tx));
        _group.messages.add(
          SplitGroupMsg(
            id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
            groupId: _group.id,
            senderId: _myId,
            senderName: _participantName(_myId),
            senderEmoji: _participantEmoji(_myId),
            text:
                'Added expense: ${tx.title} ₹${tx.totalAmount.toStringAsFixed(0)} — ${tx.splitType.label} split',
            time: DateTime.now(),
            type: MsgType.txAdded,
          ),
        );
        _update();
      },
    );
  }

  // ── Send chat message ──────────────────────────────────────────────────────
  void _sendMessage() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _group.messages.add(
        SplitGroupMsg(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
          groupId: _group.id,
          senderId: _myId,
          senderName: _participantName(_myId),
          senderEmoji: _participantEmoji(_myId),
          text: text,
          time: DateTime.now(),
        ),
      );
    });
    _chatCtrl.clear();
    widget.onGroupUpdated(_group);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(isDark, cardBg, tc, sub),
      body: Column(
        children: [
          // Tab bar
          Container(
            color: cardBg,
            child: TabBar(
              controller: _tab,
              isScrollable: false,
              indicator: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.split, width: 3),
                ),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: isDark ? Colors.white12 : Colors.black12,
              labelColor: AppColors.split,
              unselectedLabelColor: sub,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                fontFamily: 'Nunito',
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                fontFamily: 'Nunito',
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [const Text('📊 '), const Text('Overview')],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('💸 '),
                      const Text('Expenses'),
                      if (_group.pendingCount > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.expense,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_group.pendingCount}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [Text('💬 '), Text('Chat')],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _buildOverview(isDark, cardBg, surfBg, tc, sub),
                _buildExpenses(isDark, bg, cardBg, surfBg, tc, sub),
                _buildChat(isDark, bg, cardBg, surfBg, tc, sub),
              ],
            ),
          ),
        ],
      ),

      // FAB — add expense
      floatingActionButton: _tab.index == 1
          ? FloatingActionButton.extended(
              onPressed: _showAddExpense,
              backgroundColor: AppColors.split,
              foregroundColor: Colors.white,
              elevation: 6,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add Expense',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
            )
          : null,
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────
  AppBar _buildAppBar(bool isDark, Color cardBg, Color tc, Color sub) {
    return AppBar(
      backgroundColor: cardBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Text(_group.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _group.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Nunito',
                    color: tc,
                  ),
                ),
                Text(
                  '${_group.participants.length} members · '
                  '₹${_group.totalSpend.toStringAsFixed(0)} total',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Nunito',
                    color: sub,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── OVERVIEW TAB ───────────────────────────────────────────────────────────
  Widget _buildOverview(
    bool isDark,
    Color cardBg,
    Color surfBg,
    Color tc,
    Color sub,
  ) {
    final balances = _group.netBalances;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Total spend card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A9EFF), Color(0xFF0066CC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Group Spend',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Nunito',
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '₹${_group.totalSpend.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'DM Mono',
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _InfoChip(
                    '${_group.transactions.length} expenses',
                    Icons.receipt_rounded,
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    '${_group.pendingCount} pending',
                    Icons.schedule_rounded,
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    '${_group.participants.length} members',
                    Icons.people_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Members header
        Text(
          'MEMBER BALANCES',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            fontFamily: 'Nunito',
            color: sub,
          ),
        ),
        const SizedBox(height: 10),

        // Balance cards
        ..._group.participants.map((p) {
          final bal = balances[p.id] ?? 0;
          final isOwed = bal > 0;
          final isEven = bal.abs() < 0.01;
          final color = isEven
              ? sub
              : (isOwed ? AppColors.income : AppColors.expense);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(isEven ? 0.1 : 0.25)),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        p.emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    if (p.isMe)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppColors.split,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.person,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.isMe ? '${p.name} (You)' : p.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                          color: tc,
                        ),
                      ),
                      Text(
                        isEven
                            ? 'All settled up ✓'
                            : isOwed
                            ? 'Gets back ₹${bal.abs().toStringAsFixed(0)}'
                            : 'Owes ₹${bal.abs().toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Nunito',
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isEven && !p.isMe)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Text(
                      isOwed
                          ? '+ ₹${bal.abs().toStringAsFixed(0)}'
                          : '- ₹${bal.abs().toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'DM Mono',
                        color: color,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),

        const SizedBox(height: 20),
        // Expenses summary
        Text(
          'EXPENSE BREAKDOWN',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            fontFamily: 'Nunito',
            color: sub,
          ),
        ),
        const SizedBox(height: 10),

        ..._group.transactions.map(
          (tx) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tx.splitType.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    tx.splitType.emoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                          color: tc,
                        ),
                      ),
                      Text(
                        'by ${_participantName(tx.addedById)} · ${_fmtDate(tx.date)}',
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
                      '₹${tx.totalAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'DM Mono',
                        color: tc,
                      ),
                    ),
                    Text(
                      '${tx.settledCount}/${tx.shares.length} settled',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'Nunito',
                        color: tx.isFullySettled
                            ? AppColors.income
                            : AppColors.expense,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  // ── EXPENSES TAB ───────────────────────────────────────────────────────────
  Widget _buildExpenses(
    bool isDark,
    Color bg,
    Color cardBg,
    Color surfBg,
    Color tc,
    Color sub,
  ) {
    if (_group.transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('💸', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'No expenses yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                fontFamily: 'Nunito',
                color: tc,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap + to add the first expense',
              style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: sub),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _group.transactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final tx = _group.transactions[i];
        return _ExpenseTile(
          tx: tx,
          group: _group,
          myId: _myId,
          isDark: isDark,
          cardBg: cardBg,
          surfBg: surfBg,
          tc: tc,
          sub: sub,
          onShareUpdated: () => _update(),
          onAddChatMsg: (msg) {
            _group.messages.add(
              SplitGroupMsg(
                id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
                groupId: _group.id,
                senderId: _myId,
                senderName: _participantName(_myId),
                senderEmoji: _participantEmoji(_myId),
                text: msg,
                time: DateTime.now(),
                type: MsgType.settled,
              ),
            );
            _update();
          },
        );
      },
    );
  }

  // ── CHAT TAB ────────────────────────────────────────────────────────────────
  Widget _buildChat(
    bool isDark,
    Color bg,
    Color cardBg,
    Color surfBg,
    Color tc,
    Color sub,
  ) {
    return Column(
      children: [
        Expanded(
          child: _group.messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('💬', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text(
                        'No messages yet',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                          color: tc,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Start the conversation!',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Nunito',
                          color: sub,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _chatScroll,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: _group.messages.length,
                  itemBuilder: (_, i) {
                    final msg = _group.messages[i];
                    final isMe = msg.senderId == _myId;
                    final isSystem = msg.type != MsgType.text;
                    if (isSystem) return _SystemMsgBubble(msg: msg, sub: sub);
                    return _ChatBubble(
                      msg: msg,
                      isMe: isMe,
                      isDark: isDark,
                      cardBg: cardBg,
                      tc: tc,
                      sub: sub,
                    );
                  },
                ),
        ),

        // Input row
        Container(
          color: cardBg,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: surfBg,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _chatCtrl,
                      maxLines: null,
                      minLines: 1,
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                      decoration: InputDecoration.collapsed(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Nunito',
                          color: sub,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.split,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _fmtDate(DateTime d) {
    final diff = DateTime.now().difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${d.day} ${['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month]}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPENSE TILE — expandable, shows per-person shares + settle actions
// ─────────────────────────────────────────────────────────────────────────────

class _ExpenseTile extends StatefulWidget {
  final SplitGroupTx tx;
  final SplitGroup group;
  final String myId;
  final bool isDark;
  final Color cardBg, surfBg, tc, sub;
  final VoidCallback onShareUpdated;
  final void Function(String) onAddChatMsg;

  const _ExpenseTile({
    required this.tx,
    required this.group,
    required this.myId,
    required this.isDark,
    required this.cardBg,
    required this.surfBg,
    required this.tc,
    required this.sub,
    required this.onShareUpdated,
    required this.onAddChatMsg,
  });

  @override
  State<_ExpenseTile> createState() => _ExpenseTileState();
}

class _ExpenseTileState extends State<_ExpenseTile> {
  bool _expanded = false;

  String _name(String id) => widget.group.participantById(id)?.name ?? id;
  String _emoji(String id) => widget.group.participantById(id)?.emoji ?? '🧑';

  @override
  Widget build(BuildContext context) {
    final tx = widget.tx;
    final c = widget.cardBg;
    final tc = widget.tc;
    final sub = widget.sub;

    return Container(
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header row
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Split type badge
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: tx.splitType.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      tx.splitType.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Nunito',
                            color: tc,
                          ),
                        ),
                        Text(
                          'Paid by ${_name(tx.addedById)} · ${tx.splitType.label} split',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Nunito',
                            color: sub,
                          ),
                        ),
                        if (tx.note != null)
                          Text(
                            tx.note!,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Nunito',
                              color: sub,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${tx.totalAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'DM Mono',
                          color: tc,
                        ),
                      ),
                      Text(
                        '${tx.settledCount}/${tx.shares.length} settled',
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'Nunito',
                          color: tx.isFullySettled
                              ? AppColors.income
                              : AppColors.expense,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: sub,
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded shares
          if (_expanded) ...[
            Divider(
              height: 1,
              color: widget.isDark ? Colors.white10 : Colors.black12,
            ),
            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Settlement Progress',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          fontFamily: 'Nunito',
                          color: sub,
                        ),
                      ),
                      Text(
                        '${tx.settledCount}/${tx.shares.length}',
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'Nunito',
                          color: sub,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: tx.shares.isEmpty
                          ? 0
                          : tx.settledCount / tx.shares.length,
                      backgroundColor: AppColors.expense.withOpacity(0.15),
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.income,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            // Per-person share rows
            ...tx.shares.map(
              (share) => _ShareRow(
                share: share,
                tx: tx,
                personName: _name(share.participantId),
                personEmoji: _emoji(share.participantId),
                isMe: share.participantId == widget.myId,
                isPayer: tx.addedById == share.participantId,
                myId: widget.myId,
                addedById: tx.addedById,
                isDark: widget.isDark,
                surfBg: widget.surfBg,
                tc: tc,
                sub: sub,
                onUpdate: () {
                  setState(() {});
                  widget.onShareUpdated();
                },
                onAddChatMsg: widget.onAddChatMsg,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARE ROW — one person's settlement status + actions
// ─────────────────────────────────────────────────────────────────────────────

class _ShareRow extends StatelessWidget {
  final SplitShare share;
  final SplitGroupTx tx;
  final String personName, personEmoji, myId, addedById;
  final bool isMe, isPayer, isDark;
  final Color surfBg, tc, sub;
  final VoidCallback onUpdate;
  final void Function(String) onAddChatMsg;

  const _ShareRow({
    required this.share,
    required this.tx,
    required this.personName,
    required this.personEmoji,
    required this.isMe,
    required this.isPayer,
    required this.myId,
    required this.addedById,
    required this.isDark,
    required this.surfBg,
    required this.tc,
    required this.sub,
    required this.onUpdate,
    required this.onAddChatMsg,
  });

  bool get _iAmPayer => addedById == myId; // I paid the bill
  bool get _isMyShare => share.participantId == myId; // This row is about me

  @override
  Widget build(BuildContext context) {
    final st = share.status;
    final color = st.color;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(personEmoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isMe ? '$personName (You)' : personName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: tc,
                          ),
                        ),
                        if (share.percentage != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '${share.percentage!.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'Nunito',
                              color: sub,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '₹${share.amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'DM Mono',
                        color: tc,
                      ),
                    ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(st.icon, size: 10, color: color),
                    const SizedBox(width: 3),
                    Text(
                      st.label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Nunito',
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Extension info
          if (st == SettleStatus.extensionRequested ||
              st == SettleStatus.extensionGranted)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (share.extensionDate != null)
                      Text(
                        'Extension till: ${_fmtDate(share.extensionDate!)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Nunito',
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (share.extensionReason != null)
                      Text(
                        share.extensionReason!,
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'Nunito',
                          color: color.withOpacity(0.8),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Proof info
          if (st == SettleStatus.proofSubmitted && share.proofNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withOpacity(0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.upload_rounded,
                      size: 12,
                      color: Color(0xFF2196F3),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        share.proofNote!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'Nunito',
                          color: Color(0xFF2196F3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Action buttons
          _buildActions(context, st),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, SettleStatus st) {
    // What actions are available depends on who's looking and the current status
    final actions = <Widget>[];

    // MY share, I need to pay
    if (_isMyShare && !isPayer) {
      if (st == SettleStatus.pending) {
        actions.addAll([
          _ActionBtn(
            '💳 Submit Proof',
            AppColors.split,
            () => _showProofDialog(context),
          ),
          _ActionBtn(
            '⏰ Request Extension',
            const Color(0xFF9C27B0),
            () => _showExtensionDialog(context),
          ),
        ]);
      } else if (st == SettleStatus.extensionGranted) {
        actions.add(
          _ActionBtn(
            '💳 Submit Proof',
            AppColors.split,
            () => _showProofDialog(context),
          ),
        );
      }
    }

    // I AM the payer — someone submitted proof or wants extension
    if (_iAmPayer && !_isMyShare) {
      if (st == SettleStatus.proofSubmitted) {
        actions.addAll([
          _ActionBtn('✅ Mark Received', AppColors.income, () {
            share.status = SettleStatus.settled;
            onAddChatMsg(
              'Marked ₹${share.amount.toStringAsFixed(0)} from $personName as settled ✓',
            );
            onUpdate();
          }),
          _ActionBtn('❌ Dispute', AppColors.expense, () {
            share.status = SettleStatus.pending;
            share.proofNote = null;
            onUpdate();
          }),
        ]);
      } else if (st == SettleStatus.extensionRequested) {
        actions.addAll([
          _ActionBtn('✅ Grant Extension', const Color(0xFF00BCD4), () {
            share.status = SettleStatus.extensionGranted;
            onAddChatMsg(
              'Extension granted for $personName till ${share.extensionDate != null ? _fmtDate(share.extensionDate!) : 'agreed date'} 🤝',
            );
            onUpdate();
          }),
          _ActionBtn('❌ Decline', AppColors.expense, () {
            share.status = SettleStatus.pending;
            share.extensionDate = null;
            share.extensionReason = null;
            onUpdate();
          }),
        ]);
      }
    }

    // Reminder button (payer can send to pending shares)
    if (_iAmPayer && !_isMyShare && st == SettleStatus.pending) {
      actions.add(
        _ActionBtn('🔔 Send Reminder', AppColors.lend, () {
          onAddChatMsg(
            'Hey $personName, gentle reminder to settle ₹${share.amount.toStringAsFixed(0)} 🙏',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Reminder sent to $personName',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                ),
              ),
              backgroundColor: AppColors.lend,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );
        }),
      );
    }

    if (actions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(spacing: 6, runSpacing: 6, children: actions),
    );
  }

  void _showProofDialog(BuildContext context) {
    final ctrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Submit Payment Proof',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Describe your payment (UPI ref, bank transfer ID, etc.)',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'e.g. GPay ref# 48219 sent ₹${share.amount.toStringAsFixed(0)}',
                hintStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 12),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Nunito')),
          ),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              share.status = SettleStatus.proofSubmitted;
              share.proofNote = ctrl.text.trim();
              share.proofDate = DateTime.now();
              Navigator.pop(context);
              onAddChatMsg(
                'Submitted payment proof for ₹${share.amount.toStringAsFixed(0)}: ${ctrl.text.trim()}',
              );
              onUpdate();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.split,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Submit',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExtensionDialog(BuildContext context) {
    final ctrl = TextEditingController();
    DateTime pickedDate = DateTime.now().add(const Duration(days: 5));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Request Extension',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose a new settlement date and give a reason.',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 12),
              ),
              const SizedBox(height: 12),
              // Date picker button
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: pickedDate,
                    firstDate: DateTime.now().add(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (d != null) setSt(() => pickedDate = d);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.split.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.split.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: AppColors.split,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pay by: ${_fmtDate(pickedDate)}',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          color: AppColors.split,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Reason e.g. salary credit on 5th',
                  hintStyle: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                  ),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(fontFamily: 'Nunito'),
              ),
            ),
            FilledButton(
              onPressed: () {
                if (ctrl.text.trim().isEmpty) return;
                share.status = SettleStatus.extensionRequested;
                share.extensionDate = pickedDate;
                share.extensionReason = ctrl.text.trim();
                Navigator.pop(context);
                onAddChatMsg(
                  'Requested extension till ${_fmtDate(pickedDate)}: ${ctrl.text.trim()}',
                );
                onUpdate();
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Request',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtDate(DateTime d) {
    final diff = DateTime.now().difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff == -1) return 'Tomorrow';
    return '${d.day} ${['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month]}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD EXPENSE SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _AddExpenseSheet extends StatefulWidget {
  final SplitGroup group;
  final bool isDark;
  final void Function(SplitGroupTx) onSave;

  const _AddExpenseSheet({
    required this.group,
    required this.isDark,
    required this.onSave,
  });

  static void show(
    BuildContext context, {
    required bool isDark,
    required SplitGroup group,
    required void Function(SplitGroupTx) onSave,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          _AddExpenseSheet(group: group, isDark: isDark, onSave: onSave),
    );
  }

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  SplitType _splitType = SplitType.equal;
  String _paidById = 'me';
  late Map<String, TextEditingController> _shareCtrl;

  @override
  void initState() {
    super.initState();
    _shareCtrl = {
      for (final p in widget.group.participants) p.id: TextEditingController(),
    };
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    for (final c in _shareCtrl.values) c.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    final total = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (title.isEmpty || total == null || total <= 0) return;
    HapticFeedback.mediumImpact();

    final n = widget.group.participants.length;
    List<SplitShare> shares;

    switch (_splitType) {
      case SplitType.equal:
        final each = total / n;
        shares = widget.group.participants
            .map(
              (p) => SplitShare(
                participantId: p.id,
                amount: each,
                status: p.id == _paidById
                    ? SettleStatus.settled
                    : SettleStatus.pending,
              ),
            )
            .toList();
      case SplitType.unequal:
      case SplitType.custom:
        shares = widget.group.participants.map((p) {
          final amt = double.tryParse(_shareCtrl[p.id]?.text ?? '0') ?? 0;
          return SplitShare(
            participantId: p.id,
            amount: amt,
            status: p.id == _paidById
                ? SettleStatus.settled
                : SettleStatus.pending,
          );
        }).toList();
      case SplitType.percentage:
        shares = widget.group.participants.map((p) {
          final pct = double.tryParse(_shareCtrl[p.id]?.text ?? '0') ?? 0;
          final amt = total * pct / 100;
          return SplitShare(
            participantId: p.id,
            amount: amt,
            percentage: pct,
            status: p.id == _paidById
                ? SettleStatus.settled
                : SettleStatus.pending,
          );
        }).toList();
    }

    widget.onSave(
      SplitGroupTx(
        id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        groupId: widget.group.id,
        addedById: _paidById,
        title: title,
        totalAmount: total,
        splitType: _splitType,
        shares: shares,
        date: DateTime.now(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
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

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Text(
                '💸  Add Expense',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                  color: tc,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    _Lbl('EXPENSE TITLE', sub),
                    _F(_titleCtrl, 'e.g. Dinner at Beach Shack', surfBg, tc),
                    const SizedBox(height: 14),
                    // Amount
                    _Lbl('TOTAL AMOUNT', sub),
                    TextField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'DM Mono',
                        color: AppColors.split,
                      ),
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        prefixStyle: TextStyle(
                          fontSize: 18,
                          color: AppColors.split.withOpacity(0.6),
                          fontFamily: 'DM Mono',
                        ),
                        hintText: '0',
                        hintStyle: TextStyle(
                          fontSize: 22,
                          fontFamily: 'DM Mono',
                          color: sub,
                          fontWeight: FontWeight.w900,
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
                    // Paid by
                    _Lbl('PAID BY', sub),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: widget.group.participants.map((p) {
                          final sel = p.id == _paidById;
                          return GestureDetector(
                            onTap: () => setState(() => _paidById = p.id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppColors.split.withOpacity(0.12)
                                    : surfBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: sel
                                      ? AppColors.split
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    p.emoji,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    p.isMe ? 'You' : p.name.split(' ')[0],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'Nunito',
                                      color: sel ? AppColors.split : sub,
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
                    // Split type
                    _Lbl('SPLIT TYPE', sub),
                    Row(
                      children: SplitType.values.map((t) {
                        final sel = t == _splitType;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: t != SplitType.custom ? 6 : 0,
                            ),
                            child: GestureDetector(
                              onTap: () => setState(() => _splitType = t),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? t.color.withOpacity(0.12)
                                      : surfBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: sel ? t.color : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      t.emoji,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      t.label,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        fontFamily: 'Nunito',
                                        color: sel ? t.color : sub,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    // Per-person inputs (unequal / percentage / custom)
                    if (_splitType != SplitType.equal) ...[
                      const SizedBox(height: 14),
                      _Lbl(
                        _splitType == SplitType.percentage
                            ? 'PERCENTAGE PER PERSON'
                            : 'AMOUNT PER PERSON',
                        sub,
                      ),
                      ...widget.group.participants.map(
                        (p) => Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: surfBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Text(
                                p.emoji,
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  p.isMe ? 'You' : p.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Nunito',
                                    color: tc,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 90,
                                child: TextField(
                                  controller: _shareCtrl[p.id],
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'DM Mono',
                                    color: tc,
                                  ),
                                  decoration: InputDecoration(
                                    prefixText:
                                        _splitType == SplitType.percentage
                                        ? ''
                                        : '₹',
                                    suffixText:
                                        _splitType == SplitType.percentage
                                        ? '%'
                                        : '',
                                    hintText: '0',
                                    hintStyle: TextStyle(color: sub),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),
                    // Note
                    _Lbl('NOTE (OPTIONAL)', sub),
                    _F(_noteCtrl, 'e.g. Rahul had extra drinks', surfBg, tc),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.split,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Add Expense',
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
          ],
        ),
      ),
    );
  }

  Widget _Lbl(String t, Color c) => Padding(
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
  Widget _F(TextEditingController c, String h, Color s, Color tc) => TextField(
    controller: c,
    style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: tc),
    decoration: InputDecoration(
      hintText: h,
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

// ── Tiny reusable widgets ─────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(this.label, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          fontFamily: 'Nunito',
          color: color,
        ),
      ),
    ),
  );
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _InfoChip(this.label, this.icon);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
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

class _ChatBubble extends StatelessWidget {
  final SplitGroupMsg msg;
  final bool isMe, isDark;
  final Color cardBg, tc, sub;
  const _ChatBubble({
    required this.msg,
    required this.isMe,
    required this.isDark,
    required this.cardBg,
    required this.tc,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe ? AppColors.split : cardBg;
    final textColor = isMe ? Colors.white : tc;
    final timeColor = isMe ? Colors.white60 : sub;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.split.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                msg.senderEmoji,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(
                      msg.senderName,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: AppColors.split,
                      ),
                    ),
                  Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Nunito',
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fmt(msg.time),
                    style: TextStyle(
                      fontSize: 9,
                      fontFamily: 'Nunito',
                      color: timeColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  String _fmt(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _SystemMsgBubble extends StatelessWidget {
  final SplitGroupMsg msg;
  final Color sub;
  const _SystemMsgBubble({required this.msg, required this.sub});

  String get _icon {
    switch (msg.type) {
      case MsgType.txAdded:
        return '💸';
      case MsgType.settled:
        return '✅';
      case MsgType.extensionReq:
        return '⏰';
      case MsgType.extensionGranted:
        return '🤝';
      case MsgType.reminder:
        return '🔔';
      default:
        return 'ℹ️';
    }
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: sub.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              msg.text,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'Nunito',
                color: sub,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    ),
  );
}
