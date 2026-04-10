import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import 'package:wai_life_assistant/data/models/wallet/split_group_models.dart';
import 'package:wai_life_assistant/core/supabase/wallet_service.dart';
import 'package:wai_life_assistant/features/auth/auth_service.dart';
import 'package:wai_life_assistant/services/ai_parser.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/emoji_or_image.dart';

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
  final bool autoOpenAddExpense;

  const SplitGroupDetailScreen({
    super.key,
    required this.group,
    required this.onGroupUpdated,
    this.autoOpenAddExpense = false,
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
  RealtimeChannel? _chatChannel;
  bool _chatLoading = true;

  // Resolve current-user participant ID from the isMe flag (real DB IDs).
  // Falls back to 'me' for local/mock data.
  String get _myId {
    try {
      return _group.participants.firstWhere((p) => p.isMe).id;
    } catch (_) {
      return 'me';
    }
  }

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() => setState(() {}));
    _initChat();
    if (widget.autoOpenAddExpense) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tab.animateTo(1); // jump to Expenses tab
        _showAddExpense();
      });
    }
  }

  @override
  void dispose() {
    _chatChannel?.unsubscribe();
    _tab.dispose();
    _chatCtrl.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  // ── Chat: fetch history + subscribe to realtime ───────────────────────────
  Future<void> _initChat() async {
    try {
      final rows = await WalletService.instance.fetchMessages(_group.id);
      if (!mounted) return;
      setState(() {
        _group.messages
          ..clear()
          ..addAll(rows.map(SplitGroupMsg.fromRow));
        _chatLoading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _chatLoading = false);
    }

    _chatChannel = WalletService.instance.subscribeToMessages(
      _group.id,
      (row) {
        final msg = SplitGroupMsg.fromRow(row);
        // Skip messages already added locally (e.g. own messages via postMessage)
        if (_group.messages.any((m) => m.id == msg.id)) return;
        if (!mounted) return;
        setState(() => _group.messages.add(msg));
        _scrollToBottom();
      },
    );
  }

  void _scrollToBottom() {
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

  void _update() {
    final wasSettled = _group.isSettled;
    if (!wasSettled && _group.isFullySettled && _group.transactions.isNotEmpty) {
      _group.isSettled = true;
      _group.messages.add(
        SplitGroupMsg(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
          groupId: _group.id,
          senderId: 'system',
          senderName: 'System',
          senderEmoji: '🎉',
          text: '🎉 All payments settled! "${_group.name}" is now fully closed.',
          time: DateTime.now(),
          type: MsgType.settled,
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showGroupSettledSheet();
      });
    }
    setState(() {});
    widget.onGroupUpdated(_group);
  }

  // ── Group settled celebration ───────────────────────────────────────────────
  void _showGroupSettledSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 28),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Big emoji
            const Text('🎉', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),

            Text(
              'Group Fully Settled!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
                color: AppColors.income,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '"${_group.name}"\nAll payments confirmed. Group is now inactive.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Nunito',
                color: sub,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),

            // Stats row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.income.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.income.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SettledStat(
                    '₹${_group.totalSpend.toStringAsFixed(0)}',
                    'Total',
                    AppColors.income,
                    tc,
                    sub,
                  ),
                  Container(width: 1, height: 36, color: sub.withValues(alpha: 0.2)),
                  _SettledStat(
                    '${_group.transactions.length}',
                    'Expenses',
                    AppColors.split,
                    tc,
                    sub,
                  ),
                  Container(width: 1, height: 36, color: sub.withValues(alpha: 0.2)),
                  _SettledStat(
                    '${_group.participants.length}',
                    'Members',
                    const Color(0xFF9C27B0),
                    tc,
                    sub,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: const Text(
                  'Awesome!',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.income,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _participantName(String id) => _group.participantById(id)?.name ?? id;

  String _participantEmoji(String id) =>
      _group.participantById(id)?.emoji ?? '🧑';

  // ── Overview: Submit Proof for all my pending shares ───────────────────────
  void _showOverviewProofSheet(
    List<({SplitGroupTx tx, SplitShare share})> pending,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final totalAmt = pending.fold(0.0, (s, e) => s + e.share.amount);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ProofSheet(
        groupId: _group.id,
        totalAmount: totalAmt,
        pendingLabels: pending
            .map((e) => '${e.tx.title}  ₹${e.share.amount.toStringAsFixed(0)}')
            .toList(),
        isDark: isDark,
        surfBg: surfBg,
        tc: tc,
        sub: sub,
        onSubmit: (note, imagePath) {
          for (final e in pending) {
            e.share.status = SettleStatus.proofSubmitted;
            e.share.proofNote = note.isNotEmpty ? note : null;
            e.share.proofImagePath = imagePath;
            e.share.proofDate = DateTime.now();
          }
          _group.messages.add(
            SplitGroupMsg(
              id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
              groupId: _group.id,
              senderId: _myId,
              senderName: _participantName(_myId),
              senderEmoji: _participantEmoji(_myId),
              text:
                  'Submitted payment proof for ₹${totalAmt.toStringAsFixed(0)}'
                  '${note.isNotEmpty ? ': $note' : ''}',
              time: DateTime.now(),
              type: MsgType.settled,
            ),
          );
          _update();
        },
      ),
    );
  }

  // ── Overview: Request Extension for all my pending shares ──────────────────
  void _showOverviewExtensionSheet(
    List<({SplitGroupTx tx, SplitShare share})> pending,
  ) {
    final ctrl = TextEditingController();
    DateTime pickedDate = DateTime.now().add(const Duration(days: 5));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final totalAmt = pending.fold(0.0, (s, e) => s + e.share.amount);

    // Use the group's net settlement plan filtered to entries where I am the payer.
    // This correctly nets out mutual debts across all transactions.
    final mySettlements = _group.settlementPlan
        .where((e) => e.fromId == _myId)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Text('📅', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Request Extension',
                        style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito', color: tc,
                        )),
                    Text(
                      'For ₹${totalAmt.toStringAsFixed(0)} across ${pending.length} payment${pending.length > 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub),
                    ),
                  ]),
                ]),
                const SizedBox(height: 16),

                // ── To whom section ──────────────────────────────────────────
                Text('You need to settle with',
                    style: TextStyle(fontSize: 11, fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700, color: sub)),
                const SizedBox(height: 8),
                ...mySettlements.map((entry) {
                  final payerName = _participantName(entry.toId);
                  final payerEmoji = _participantEmoji(entry.toId);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.expense.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.expense.withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      Text(payerEmoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(payerName,
                            style: TextStyle(fontSize: 13, fontFamily: 'Nunito',
                                fontWeight: FontWeight.w700, color: tc)),
                      ),
                      Text('₹${entry.amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13, fontFamily: 'DM Mono',
                            fontWeight: FontWeight.w900, color: AppColors.expense,
                          )),
                    ]),
                  );
                }),
                const SizedBox(height: 14),

                // Date picker
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9C27B0).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF9C27B0)),
                      const SizedBox(width: 8),
                      Text('Pay by: ${_fmtDate(pickedDate)}',
                          style: const TextStyle(
                            fontFamily: 'Nunito', fontWeight: FontWeight.w700,
                            color: Color(0xFF9C27B0),
                          )),
                      const Spacer(),
                      const Icon(Icons.edit_rounded, size: 14, color: Color(0xFF9C27B0)),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                // Reason
                TextField(
                  controller: ctrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Reason e.g. salary credit on 5th',
                    hintStyle: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: sub),
                    filled: true,
                    fillColor: surfBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 20),
                // Buttons
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontFamily: 'Nunito')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (ctrl.text.trim().isEmpty) return;
                        final reason = ctrl.text.trim();
                        for (final e in pending) {
                          e.share.status = SettleStatus.extensionRequested;
                          e.share.extensionDate = pickedDate;
                          e.share.extensionReason = reason;
                          // Persist to DB
                          _persistShareStatus(
                            share: e.share,
                            txId: e.tx.id,
                            status: 'extension_requested',
                            extensionDate: pickedDate,
                            extensionReason: reason,
                          );
                        }
                        Navigator.pop(ctx);
                        _addAndPersistMessage(
                          text: '⏰ Requested extension till ${_fmtDate(pickedDate)}: $reason',
                          type: MsgType.extensionReq,
                        );
                        _update();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF9C27B0),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Request',
                          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Persist share status to DB (fire-and-forget) ───────────────────────────
  void _persistShareStatus({
    required SplitShare share,
    required String txId,
    required String status,
    DateTime? extensionDate,
    String? extensionReason,
    String? extensionResponseMsg,
    String? proofNote,
    String? proofImagePath,
    DateTime? proofDate,
  }) {
    if (!AuthService.instance.isLoggedIn) return;
    WalletService.instance.updateShareStatus(
      shareId: share.id,
      transactionId: txId,
      participantId: share.participantId,
      status: status,
      extensionDate: extensionDate,
      extensionReason: extensionReason,
      extensionResponseMsg: extensionResponseMsg,
      proofNote: proofNote,
      proofImagePath: proofImagePath,
      proofDate: proofDate,
    ).catchError((e) => debugPrint('[SplitGroupDetail] updateShareStatus failed: $e'));
  }

  // ── Add message locally + persist to DB ───────────────────────────────────
  Future<void> _addAndPersistMessage({
    required String text,
    MsgType type = MsgType.text,
  }) async {
    final msg = SplitGroupMsg(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      groupId: _group.id,
      senderId: _myId,
      senderName: _participantName(_myId),
      senderEmoji: _participantEmoji(_myId),
      text: text,
      time: DateTime.now(),
      type: type,
    );
    setState(() => _group.messages.add(msg));
    widget.onGroupUpdated(_group);
    if (!AuthService.instance.isLoggedIn) return;
    try {
      await WalletService.instance.postMessage(
        groupId: _group.id,
        senderId: _myId,
        senderName: _participantName(_myId),
        senderEmoji: _participantEmoji(_myId),
        text: text,
        type: type.name,
      );
    } catch (e) {
      debugPrint('[SplitGroupDetail] postMessage failed: $e');
    }
  }

  // ── Send reminder ──────────────────────────────────────────────────────────
  void _showReminderSheet(SplitParticipant p, double owedAmount, {VoidCallback? onReminderSent}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    final firstName = p.name.split(' ')[0];
    final message =
        'Hey $firstName! 👋 Just a gentle reminder to settle your share of '
        '₹${owedAmount.toStringAsFixed(0)} in "${_group.name}". '
        'Thanks! 🙏';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.expense.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.notifications_rounded,
                    color: AppColors.expense,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Send Reminder',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                    Text(
                      'to ${p.name}  ${p.emoji}',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Nunito',
                        color: sub,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Message preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.expense.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Nunito',
                  color: tc,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Amount chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.expense.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.expense.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 14,
                    color: AppColors.expense,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${p.name} owes ₹${owedAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      color: AppColors.expense,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final nav = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      await Clipboard.setData(ClipboardData(text: message));
                      onReminderSent?.call();
                      nav.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.copy_rounded,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Message copied to clipboard!',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: AppColors.split,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          margin: const EdgeInsets.all(16),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text(
                      'Copy Message',
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
                if (p.phone != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        final phone = p.phone!.replaceAll(RegExp(r'[^\d]'), '');
                        final encoded = Uri.encodeComponent(message);
                        final waUri = Uri.parse('https://wa.me/91$phone?text=$encoded');
                        onReminderSent?.call();
                        nav.pop();
                        if (await canLaunchUrl(waUri)) {
                          await launchUrl(waUri, mode: LaunchMode.externalApplication);
                        } else {
                          // Fallback: copy message to clipboard
                          await Clipboard.setData(ClipboardData(text: message));
                          messenger.showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'WhatsApp not found — message copied!',
                                    style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFF25D366),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              margin: const EdgeInsets.all(16),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: const Text('💬', style: TextStyle(fontSize: 14)),
                      label: const Text(
                        'WhatsApp',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
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
        _persistSplitTransaction(tx); // fire-and-forget
      },
    );
  }

  Future<void> _persistSplitTransaction(SplitGroupTx tx) async {
    if (!AuthService.instance.isLoggedIn) return;
    try {
      final row = await WalletService.instance.addSplitTransaction(
        groupId: _group.id,
        addedByParticipantId: tx.addedById,
        title: tx.title,
        totalAmount: tx.totalAmount,
        splitType: tx.splitType.name,
        shares: tx.shares
            .map((s) => (
                  participantId: s.participantId,
                  amount: s.amount,
                  percentage: s.percentage,
                ))
            .toList(),
        note: tx.note,
        date: tx.date,
      );
      if (!mounted) return;
      // Replace local placeholder id with real DB id
      final realId = row['id'] as String;
      setState(() {
        final idx = _group.transactions.indexWhere((t) => t.id == tx.id);
        if (idx >= 0) {
          _group.transactions[idx] = SplitGroupTx(
            id: realId,
            groupId: tx.groupId,
            addedById: tx.addedById,
            title: tx.title,
            totalAmount: tx.totalAmount,
            splitType: tx.splitType,
            shares: tx.shares,
            date: tx.date,
            note: tx.note,
          );
        }
      });
    } catch (e) {
      debugPrint('[SplitGroupDetail] addSplitTransaction failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save expense: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  // ── Send chat message ──────────────────────────────────────────────────────
  Future<void> _sendMessage() async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    _chatCtrl.clear();
    try {
      final row = await WalletService.instance.postMessage(
        groupId: _group.id,
        senderId: _myId,
        senderName: _participantName(_myId),
        senderEmoji: _participantEmoji(_myId),
        text: text,
      );
      if (!mounted) return;
      setState(() => _group.messages.add(SplitGroupMsg.fromRow(row)));
      widget.onGroupUpdated(_group);
      _scrollToBottom();
    } catch (_) {
      // Realtime subscription will deliver the message if DB write eventually succeeds
    }
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
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('💸 '),
                        const Text('Expenses'),
                        if (_group.transactions.isNotEmpty) ...[
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
                              '${_group.transactions.length}',
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
      titleSpacing: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          EmojiOrImage(value: _group.emoji, size: 28, borderRadius: 8),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _group.name,
                  overflow: TextOverflow.ellipsis,
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
                  overflow: TextOverflow.ellipsis,
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
        // Settled banner
        if (_group.isFullySettled) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00C897), Color(0xFF4CAF50)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Text('🎉', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Group Fully Settled!',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito',
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'All payments confirmed · Group inactive',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Nunito',
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'SETTLED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Total spend card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A9EFF), Color(0xFF0066CC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Group Spend',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Nunito',
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${_group.totalSpend.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'DM Mono',
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
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
        const SizedBox(height: 12),

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

          // Pending shares for "me" — used to show Submit Proof / Extension
          final myPending = p.isMe
              ? _group.transactions
                  .expand((tx) => tx.shares.map((s) => (tx: tx, share: s)))
                  .where(
                    (e) =>
                        e.share.participantId == p.id &&
                        e.share.status == SettleStatus.pending,
                  )
                  .toList()
              : <({SplitGroupTx tx, SplitShare share})>[];

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: isEven ? 0.1 : 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
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
                    if (!isEven) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color.withValues(alpha: 0.3)),
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
                      // Remind button — only for non-me members who owe
                      if (!p.isMe && !isOwed) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _showReminderSheet(p, bal.abs());
                          },
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.expense.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.expense.withValues(alpha: 0.3),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.notifications_rounded,
                              size: 16,
                              color: AppColors.expense,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),

                // ── Action buttons for ME when I owe and have pending shares ──
                if (p.isMe && !isEven && !isOwed && myPending.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            _showOverviewProofSheet(myPending);
                          },
                          icon: const Text(
                            '💳',
                            style: TextStyle(fontSize: 13),
                          ),
                          label: const Text(
                            'Submit Proof',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.split,
                            side: BorderSide(
                              color: AppColors.split.withValues(alpha: 0.5),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            _showOverviewExtensionSheet(myPending);
                          },
                          icon: const Text(
                            '⏰',
                            style: TextStyle(fontSize: 13),
                          ),
                          label: const Text(
                            'Extension',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF9C27B0),
                            side: BorderSide(
                              color: const Color(0xFF9C27B0).withValues(
                                alpha: 0.5,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        }),

        const SizedBox(height: 20),

        // Settle up plan
        Text(
          'SETTLE UP',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            fontFamily: 'Nunito',
            color: sub,
          ),
        ),
        const SizedBox(height: 10),

        Builder(builder: (_) {
          final plan = _group.settlementPlan;
          if (plan.isEmpty) {
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    'All settled up!',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: AppColors.income,
                    ),
                  ),
                ],
              ),
            );
          }
          return Column(
            children: plan.map((s) {
              final from = _group.participantById(s.fromId);
              final to = _group.participantById(s.toId);
              final fromName = from?.isMe == true
                  ? 'You'
                  : (from?.name.split(' ')[0] ?? s.fromId);
              final toName = to?.isMe == true
                  ? 'You'
                  : (to?.name.split(' ')[0] ?? s.toId);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.split.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      from?.emoji ?? '🧑',
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$fromName pays $toName',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: tc,
                            ),
                          ),
                          Text(
                            from?.isMe == true
                                ? 'You need to pay'
                                : to?.isMe == true
                                ? 'You will receive'
                                : 'Settlement required',
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'Nunito',
                              color: sub,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: AppColors.split,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      to?.emoji ?? '🧑',
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.split.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.split.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '₹${s.amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'DM Mono',
                          color: AppColors.split,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        }),

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
          onSendReminder: (share, tx) {
            final p = _group.participantById(share.participantId);
            if (p == null) return;
            _showReminderSheet(p, share.amount, onReminderSent: () {
              share.reminderCount = (share.reminderCount ?? 0) + 1;
              share.lastReminderAt = DateTime.now();
              share.lastReminderBy = _participantName(_myId);
              _group.messages.add(SplitGroupMsg(
                id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
                groupId: _group.id,
                senderId: _myId,
                senderName: _participantName(_myId),
                senderEmoji: _participantEmoji(_myId),
                text: 'Sent a payment reminder to ${p.name} for ₹${share.amount.toStringAsFixed(0)} 🔔',
                time: DateTime.now(),
                type: MsgType.reminder,
              ));
              _update();
              WalletService.instance.recordReminderSent(
                transactionId: tx.id,
                participantId: share.participantId,
                sentBy: _participantName(_myId),
              ).catchError((_) {});
            });
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
          child: _chatLoading
              ? const Center(child: CircularProgressIndicator())
              : _group.messages.isEmpty
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
  final void Function(SplitShare, SplitGroupTx) onSendReminder;

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
    required this.onSendReminder,
  });

  @override
  State<_ExpenseTile> createState() => _ExpenseTileState();
}

class _ExpenseTileState extends State<_ExpenseTile> {
  bool _expanded = false;

  String _name(String id) => widget.group.participantById(id)?.name ?? id;
  String _emoji(String id) => widget.group.participantById(id)?.emoji ?? '🧑';

  static String _fmtDateTime(DateTime d) {
    final now = DateTime.now();
    final isToday =
        d.year == now.year && d.month == now.month && d.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = d.year == yesterday.year &&
        d.month == yesterday.month &&
        d.day == yesterday.day;
    final months = [
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
    final dateStr = isToday
        ? 'Today'
        : isYesterday
        ? 'Yesterday'
        : '${d.day} ${months[d.month]}';
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final m = d.minute.toString().padLeft(2, '0');
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '$dateStr · $h:$m $period';
  }

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
                      color: tx.splitType.color.withValues(alpha: 0.12),
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
                        Text(
                          _fmtDateTime(tx.date),
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'Nunito',
                            color: sub.withValues(alpha: 0.7),
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
                      backgroundColor: AppColors.expense.withValues(alpha: 0.15),
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
                onSendReminder: () => widget.onSendReminder(share, widget.tx),
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
  final VoidCallback? onSendReminder;

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
    this.onSendReminder,
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
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
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
                  color: color.withValues(alpha: 0.07),
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
                          color: color.withValues(alpha: 0.8),
                        ),
                      ),
                    if (share.extensionResponseMsg != null &&
                        share.extensionResponseMsg!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            st == SettleStatus.extensionGranted ? '🤝 ' : '❌ ',
                            style: const TextStyle(fontSize: 10),
                          ),
                          Expanded(
                            child: Text(
                              share.extensionResponseMsg!,
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'Nunito',
                                fontStyle: FontStyle.italic,
                                color: color.withValues(alpha: 0.9),
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

          // Proof info (image + note)
          if (st == SettleStatus.proofSubmitted) ...[
            if (share.proofImagePath != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: share.proofImagePath!.startsWith('http')
                      ? Image.network(
                          share.proofImagePath!,
                          height: 110,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 110,
                            color: const Color(0xFF2196F3).withValues(alpha: 0.07),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                              color: Color(0xFF2196F3),
                            ),
                          ),
                        )
                      : Image.file(
                          File(share.proofImagePath!),
                          height: 110,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 110,
                            color: const Color(0xFF2196F3).withValues(alpha: 0.07),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                              color: Color(0xFF2196F3),
                            ),
                          ),
                        ),
                ),
              ),
            if (share.proofNote != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.07),
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
          ],

          // Reminder history
          if ((share.reminderCount ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.notifications_rounded, size: 11, color: AppColors.lend),
                  const SizedBox(width: 4),
                  Text(
                    '${share.reminderCount} reminder${(share.reminderCount ?? 0) > 1 ? 's' : ''} sent'
                    '${share.lastReminderBy != null ? ' by ${share.lastReminderBy}' : ''}'
                    '${share.lastReminderAt != null ? ' · ${_fmtDate(share.lastReminderAt!)}' : ''}',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'Nunito',
                      color: AppColors.lend.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),

          // Action buttons
          _buildActions(context, st),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, SettleStatus st) {
    final actions = <Widget>[];

    // I AM the payer — someone submitted proof or wants extension
    if (_iAmPayer && !_isMyShare) {
      if (st == SettleStatus.proofSubmitted) {
        actions.addAll([
          _ActionBtn('✅ Mark Received', AppColors.income, () {
            share.status = SettleStatus.settled;
            _persistShare(context, 'settled');
            onAddChatMsg('Marked ₹${share.amount.toStringAsFixed(0)} from $personName as settled ✓');
            onUpdate();
          }),
          _ActionBtn('❌ Dispute', AppColors.expense, () {
            share.status = SettleStatus.pending;
            share.proofNote = null;
            _persistShare(context, 'pending');
            onUpdate();
          }),
        ]);
      } else if (st == SettleStatus.extensionRequested) {
        actions.addAll([
          _ActionBtn('✅ Agree', const Color(0xFF00BCD4), () {
            _showExtensionResponseSheet(context, agree: true);
          }),
          _ActionBtn('❌ Disagree', AppColors.expense, () {
            _showExtensionResponseSheet(context, agree: false);
          }),
        ]);
      }
    }

    // Reminder button (payer can send to pending shares)
    if (_iAmPayer && !_isMyShare && st == SettleStatus.pending) {
      actions.add(
        _ActionBtn('🔔 Send Reminder', AppColors.lend, onSendReminder ?? () {}),
      );
    }

    if (actions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(spacing: 6, runSpacing: 6, children: actions),
    );
  }

  void _persistShare(BuildContext context, String status, {String? responseMsg}) {
    WalletService.instance.updateShareStatus(
      shareId: share.id,
      transactionId: tx.id,
      participantId: share.participantId,
      status: status,
      extensionDate: share.extensionDate,
      extensionReason: share.extensionReason,
      extensionResponseMsg: responseMsg,
    ).catchError((e) => debugPrint('[ShareRow] updateShareStatus failed: $e'));
  }

  void _showExtensionResponseSheet(BuildContext context, {required bool agree}) {
    final ctrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final color = agree ? const Color(0xFF00BCD4) : AppColors.expense;
    final dateStr = share.extensionDate != null ? _fmtDate(share.extensionDate!) : 'agreed date';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(agree ? '🤝' : '❌', style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(agree ? 'Grant Extension' : 'Decline Extension',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900,
                            fontFamily: 'Nunito', color: tc)),
                    Text(
                      agree
                          ? 'Extension for $personName till $dateStr'
                          : 'Decline $personName\'s extension request',
                      style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub),
                    ),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),

              // Extension details (shown to payer for context)
              if (share.extensionDate != null || share.extensionReason != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (share.extensionDate != null)
                        Text('Requested till: $dateStr',
                            style: const TextStyle(fontSize: 12, fontFamily: 'Nunito',
                                fontWeight: FontWeight.w700, color: Color(0xFF9C27B0))),
                      if (share.extensionReason != null) ...[
                        const SizedBox(height: 2),
                        Text(share.extensionReason!,
                            style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub)),
                      ],
                    ],
                  ),
                ),

              // Message field
              TextField(
                controller: ctrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: agree
                      ? 'Add a note e.g. Sure, please pay by then!'
                      : 'Add a reason e.g. Need it urgently',
                  hintStyle: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: sub),
                  filled: true,
                  fillColor: surfBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontFamily: 'Nunito')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      final msg = ctrl.text.trim();
                      Navigator.pop(context);
                      if (agree) {
                        share.status = SettleStatus.extensionGranted;
                        share.extensionResponseMsg = msg.isEmpty ? null : msg;
                        _persistShare(context, 'extension_granted', responseMsg: msg.isEmpty ? null : msg);
                        onAddChatMsg(
                          '🤝 Extension granted for $personName till $dateStr'
                          '${msg.isNotEmpty ? ': $msg' : ''}',
                        );
                      } else {
                        share.status = SettleStatus.pending;
                        share.extensionDate = null;
                        share.extensionReason = null;
                        share.extensionResponseMsg = msg.isEmpty ? null : msg;
                        _persistShare(context, 'pending', responseMsg: msg.isEmpty ? null : msg);
                        onAddChatMsg(
                          '❌ Extension declined for $personName'
                          '${msg.isNotEmpty ? ': $msg' : ''}',
                        );
                      }
                      onUpdate();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      agree ? 'Grant Extension' : 'Decline',
                      style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ]),
            ],
          ),
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
// PROOF SHEET — attach image + note, then submit
// ─────────────────────────────────────────────────────────────────────────────

class _ProofSheet extends StatefulWidget {
  final String groupId;
  final double totalAmount;
  final List<String> pendingLabels;
  final bool isDark;
  final Color surfBg, tc, sub;
  final void Function(String note, String? imageUrl) onSubmit;

  const _ProofSheet({
    required this.groupId,
    required this.totalAmount,
    required this.pendingLabels,
    required this.isDark,
    required this.surfBg,
    required this.tc,
    required this.sub,
    required this.onSubmit,
  });

  @override
  State<_ProofSheet> createState() => _ProofSheetState();
}

class _ProofSheetState extends State<_ProofSheet> {
  final _noteCtrl = TextEditingController();
  XFile? _pickedImage;
  bool _submitting = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: source, imageQuality: 75);
    if (img != null) setState(() => _pickedImage = img);
  }

  Future<void> _submit() async {
    if (_noteCtrl.text.trim().isEmpty && _pickedImage == null) return;
    setState(() => _submitting = true);
    String? imageUrl;
    if (_pickedImage != null) {
      try {
        final bytes = await _pickedImage!.readAsBytes();
        final ext = _pickedImage!.path.split('.').last.toLowerCase();
        imageUrl = await WalletService.instance.uploadProofImage(
          groupId: widget.groupId,
          imageBytes: bytes,
          extension: ext.isEmpty ? 'jpg' : ext,
        );
      } catch (_) {
        // fallback: store local path if upload fails
        imageUrl = _pickedImage!.path;
      }
    }
    widget.onSubmit(_noteCtrl.text.trim(), imageUrl);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cardBg =
        widget.isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = widget.tc;
    final sub = widget.sub;
    final surf = widget.surfBg;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.split.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: AppColors.split,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Submit Payment Proof',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                    Text(
                      '₹${widget.totalAmount.toStringAsFixed(0)} total · ${widget.pendingLabels.length} payment${widget.pendingLabels.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Nunito',
                        color: sub,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Image attachment section
            if (_pickedImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_pickedImage!.path),
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 14, color: AppColors.income),
                  const SizedBox(width: 4),
                  Text(
                    'Screenshot attached',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Nunito',
                      color: AppColors.income,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _pickedImage = null),
                    child: Text(
                      'Remove',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Nunito',
                        color: AppColors.expense,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ] else ...[
              // Attach image buttons
              Row(
                children: [
                  Expanded(
                    child: _AttachBtn(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      surf: surf,
                      sub: sub,
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AttachBtn(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      surf: surf,
                      sub: sub,
                      onTap: () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Note field
            Text(
              'PAYMENT REFERENCE (OPTIONAL)',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                fontFamily: 'Nunito',
                color: sub,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'Nunito',
                color: tc,
              ),
              decoration: InputDecoration(
                hintText:
                    'e.g. GPay ref# 48219 sent ₹${widget.totalAmount.toStringAsFixed(0)}',
                hintStyle: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  color: sub,
                ),
                filled: true,
                fillColor: surf,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 20),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 18),
                label: Text(
                  _submitting ? 'Submitting…' : 'Mark as Done Payment',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.split,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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

class _AttachBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color surf, sub;
  final VoidCallback onTap;
  const _AttachBtn({
    required this.icon,
    required this.label,
    required this.surf,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.split.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.split, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              color: sub,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTLED STAT — one metric cell in the group-settled celebration sheet
// ─────────────────────────────────────────────────────────────────────────────

class _SettledStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final Color tc;
  final Color sub;

  const _SettledStat(this.value, this.label, this.color, this.tc, this.sub);

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          fontFamily: 'DM Mono',
          color: color,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub),
      ),
    ],
  );
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

class _AddExpenseSheetState extends State<_AddExpenseSheet>
    with SingleTickerProviderStateMixin {
  late TabController _mode;

  // AI Parse state
  final _aiCtrl = TextEditingController();
  bool _aiLoading = false;
  String? _aiError;

  // Manual form state
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  SplitType _splitType = SplitType.equal;
  late String _paidById;
  DateTime _expenseDate = DateTime.now();
  late Map<String, TextEditingController> _shareCtrl;

  @override
  void initState() {
    super.initState();
    _mode = TabController(length: 2, vsync: this);
    _mode.addListener(() => setState(() {}));
    // Default payer = current user; resolve via isMe flag for real DB IDs.
    try {
      _paidById = widget.group.participants.firstWhere((p) => p.isMe).id;
    } catch (_) {
      _paidById = widget.group.participants.isNotEmpty
          ? widget.group.participants.first.id
          : 'me';
    }
    _shareCtrl = {
      for (final p in widget.group.participants) p.id: TextEditingController(),
    };
  }

  @override
  void dispose() {
    _mode.dispose();
    _aiCtrl.dispose();
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    for (final c in _shareCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _parseAI() async {
    final text = _aiCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() { _aiLoading = true; _aiError = null; });
    try {
      final membersList = widget.group.participants
          .map((p) => p.isMe ? 'You' : p.name.split(' ')[0])
          .toList();
      final result = await AIParser.parseText(
        feature: 'wallet',
        subFeature: 'split_expense',
        text: text,
        context: {'members': membersList},
      );
      if (!mounted) return;
      if (!result.success || result.data == null) {
        setState(() {
          _aiLoading = false;
          _aiError = result.error ?? 'Could not understand. Try rephrasing.';
        });
        return;
      }
      final data = result.data!;

      // Pre-fill title
      _titleCtrl.text = data['description'] as String? ?? '';

      // Pre-fill amount
      final rawAmount = data['amount'];
      if (rawAmount != null) {
        final amt = (rawAmount as num).toDouble();
        _amountCtrl.text = amt == amt.roundToDouble()
            ? amt.toInt().toString()
            : amt.toStringAsFixed(2);
      }

      // Match paid_by to a participant
      final rawPaidBy = (data['paid_by'] as String? ?? '').toLowerCase();
      if (rawPaidBy.isNotEmpty && rawPaidBy != 'null') {
        final match = widget.group.participants.where((p) {
          final name = (p.isMe ? 'you' : p.name.toLowerCase());
          return name.contains(rawPaidBy) || rawPaidBy.contains(name.split(' ')[0]);
        }).firstOrNull;
        if (match != null) _paidById = match.id;
      }

      // Split type
      final rawSplit = (data['split_type'] as String? ?? 'equally').toLowerCase();
      _splitType = rawSplit.contains('unequal') ? SplitType.unequal
                 : rawSplit.contains('percent') ? SplitType.percentage
                 : SplitType.equal;

      // Map participants to per-person share fields
      final rawParticipants = data['participants'];
      if (rawParticipants is List && rawParticipants.isNotEmpty) {
        // If AI returned per-person amounts, switch to unequal split
        final firstEntry = rawParticipants.first;
        if (firstEntry is Map) {
          final hasAmount = firstEntry.containsKey('amount');
          final hasPct = firstEntry.containsKey('percentage') || firstEntry.containsKey('percent');
          if (hasAmount || hasPct) {
            _splitType = hasPct ? SplitType.percentage : SplitType.unequal;
            for (final entry in rawParticipants) {
              if (entry is! Map) continue;
              final nameRaw = (entry['name'] as String? ?? '').toLowerCase().trim();
              if (nameRaw.isEmpty) continue;
              // Match by name or "you" keyword
              final match = widget.group.participants.where((p) {
                final pName = (p.isMe ? 'you' : p.name.toLowerCase());
                return pName.contains(nameRaw) ||
                    nameRaw.contains(p.name.toLowerCase().split(' ')[0]) ||
                    (p.isMe && (nameRaw == 'you' || nameRaw == 'me'));
              }).firstOrNull;
              if (match == null) continue;
              final val = (entry['amount'] ?? entry['percentage'] ?? entry['percent']) as num?;
              if (val != null) {
                final v = val.toDouble();
                _shareCtrl[match.id]?.text = v == v.roundToDouble()
                    ? v.toInt().toString()
                    : v.toStringAsFixed(2);
              }
            }
          }
        }
      }

      setState(() => _aiLoading = false);
      _mode.animateTo(1);
    } catch (e) {
      if (mounted) setState(() { _aiLoading = false; _aiError = 'Parse failed. Fill manually.'; });
    }
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

    // Validate share totals for non-equal splits
    if (_splitType == SplitType.unequal) {
      final shareSum = shares.fold(0.0, (s, e) => s + e.amount);
      if ((shareSum - total).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Shares total ₹${shareSum.toStringAsFixed(2)} must equal ₹${total.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.red.shade700,
        ));
        return;
      }
    } else if (_splitType == SplitType.percentage) {
      final pctSum = widget.group.participants.fold(
        0.0,
        (s, p) => s + (double.tryParse(_shareCtrl[p.id]?.text ?? '0') ?? 0),
      );
      if ((pctSum - 100).abs() > 0.1) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Percentages must sum to 100% (currently ${pctSum.toStringAsFixed(1)}%)',
          ),
          backgroundColor: Colors.red.shade700,
        ));
        return;
      }
    } else if (_splitType == SplitType.custom) {
      final shareSum = shares.fold(0.0, (s, e) => s + e.amount);
      if (shareSum > total + 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Shares total ₹${shareSum.toStringAsFixed(2)} exceeds ₹${total.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.red.shade700,
        ));
        return;
      }
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
        date: _expenseDate,
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
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💸  Add Expense',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                      color: tc,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ── Mode switcher ────────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: surfBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: TabBar(
                      controller: _mode,
                      indicator: BoxDecoration(
                        color: AppColors.split,
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
                        Tab(height: 36, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('✨', style: TextStyle(fontSize: 14)), SizedBox(width: 6), Text('AI Parse'),
                        ])),
                        Tab(height: 36, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.edit_outlined, size: 14), SizedBox(width: 6), Text('Manual'),
                        ])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── AI Parse tab ────────────────────────────────────
                    if (_mode.index == 0) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.split.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.split.withValues(alpha: 0.2)),
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('✨', style: TextStyle(fontSize: 15)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            'Describe the expense — e.g. "Ravi paid ₹1200 for dinner, split equally"',
                            style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub, height: 1.4),
                          )),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: surfBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: TextField(
                          controller: _aiCtrl,
                          maxLines: 3,
                          minLines: 2,
                          style: TextStyle(fontSize: 14, fontFamily: 'Nunito', color: tc),
                          decoration: InputDecoration.collapsed(
                            hintText: 'e.g. "Lunch ₹840, Priya paid, split equally"',
                            hintStyle: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: sub),
                          ),
                        ),
                      ),
                      if (_aiError != null) ...[
                        const SizedBox(height: 8),
                        Text(_aiError!, style: const TextStyle(fontSize: 12, fontFamily: 'Nunito', color: AppColors.expense)),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: _aiLoading ? null : _parseAI,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.split,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: _aiLoading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('✨', style: TextStyle(fontSize: 16)),
                          label: Text(
                            _aiLoading ? 'Parsing…' : 'Parse & Fill',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Nunito', fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () => _mode.animateTo(1),
                          child: Text('Fill manually instead',
                              style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub)),
                        ),
                      ),
                    ],

                    // ── Manual tab ──────────────────────────────────────
                    if (_mode.index == 1) ...[
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
                          color: AppColors.split.withValues(alpha: 0.6),
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
                                    ? AppColors.split.withValues(alpha: 0.12)
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
                                      ? t.color.withValues(alpha: 0.12)
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
                    // Date & Time
                    _Lbl('DATE & TIME', sub),
                    GestureDetector(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _expenseDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now(),
                        );
                        if (date == null || !mounted) return;
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(_expenseDate),
                        );
                        if (!mounted) return;
                        setState(() {
                          _expenseDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time?.hour ?? _expenseDate.hour,
                            time?.minute ?? _expenseDate.minute,
                          );
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: surfBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 16,
                              color: AppColors.split,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _fmtExpenseDate(_expenseDate),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Nunito',
                                  color: tc,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.edit_calendar_rounded,
                              size: 16,
                              color: sub,
                            ),
                          ],
                        ),
                      ),
                    ),
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
                    ], // end if (_mode.index == 1)
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtExpenseDate(DateTime d) {
    final now = DateTime.now();
    final isToday =
        d.year == now.year && d.month == now.month && d.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = d.year == yesterday.year &&
        d.month == yesterday.month &&
        d.day == yesterday.day;
    final months = [
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
    final dateStr = isToday
        ? 'Today'
        : isYesterday
        ? 'Yesterday'
        : '${d.day} ${months[d.month]}';
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final m = d.minute.toString().padLeft(2, '0');
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '$dateStr, $h:$m $period';
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
                color: AppColors.split.withValues(alpha: 0.12),
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
        color: sub.withValues(alpha: 0.08),
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
