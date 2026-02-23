import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';
import '../../widgets/plan_widgets.dart';

class TravelBoardScreen extends StatefulWidget {
  final String walletId;
  const TravelBoardScreen({super.key, required this.walletId});
  @override
  State<TravelBoardScreen> createState() => _TravelBoardScreenState();
}

class _TravelBoardScreenState extends State<TravelBoardScreen> {
  final List<TripModel> _trips = List.from(mockTrips);

  List<TripModel> get _myTrips =>
      _trips.where((t) => t.walletId == widget.walletId).toList();

  void _add(TripModel t) => setState(() => _trips.add(t));
  void _delete(TripModel t) => setState(() => _trips.remove(t));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);

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
        title: const Row(
          children: [
            Text('✈️', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'Travel Board',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showPlanSheet(
          context,
          child: _AddTripSheet(
            isDark: isDark,
            surfBg: surfBg,
            walletId: widget.walletId,
            onSave: (t) {
              _add(t);
              Navigator.pop(context);
            },
          ),
        ),
        backgroundColor: const Color(0xFF4A9EFF),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Plan Trip',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
          ),
        ),
      ),
      body: _myTrips.isEmpty
          ? const PlanEmptyState(
              emoji: '✈️',
              title: 'No trips planned',
              subtitle: 'Tap + to plan your next adventure',
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: _myTrips.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SwipeTile(
                  onDelete: () => _delete(_myTrips[i]),
                  child: _TripCard(
                    trip: _myTrips[i],
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _TripDetailScreen(
                          trip: _myTrips[i],
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

// ── Trip card ────────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  final TripModel trip;
  final bool isDark;
  final VoidCallback onTap;
  const _TripCard({
    required this.trip,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    const color = Color(0xFF4A9EFF);

    final progress = trip.budget != null && trip.budget! > 0
        ? (trip.spent / trip.budget!).clamp(0.0, 1.0)
        : 0.0;

    final doneTasks = trip.tasks.where((t) => t.done).length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: const BoxDecoration(
                color: color,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Text(trip.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Nunito',
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          trip.destination,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'Nunito',
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      trip.travelMode.emoji,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dates
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 13, color: sub),
                      const SizedBox(width: 5),
                      Text(
                        trip.startDate != null
                            ? '${fmtDateShort(trip.startDate!)} → ${fmtDateShort(trip.endDate ?? trip.startDate!)}'
                            : 'Dates TBD',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Nunito',
                          color: sub,
                        ),
                      ),
                      const Spacer(),
                      // Members
                      Row(
                        children: trip.memberIds
                            .take(4)
                            .map(
                              (id) => Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: MemberAvatar(memberId: id, size: 24),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Budget bar
                  if (trip.budget != null) ...[
                    Row(
                      children: [
                        Text(
                          '₹${trip.spent.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'DM Mono',
                            color: tc,
                          ),
                        ),
                        Text(
                          ' / ₹${trip.budget!.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Nunito',
                            color: sub,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}% spent',
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
                        value: progress,
                        minHeight: 6,
                        backgroundColor: color.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation(
                          progress > 0.85 ? AppColors.expense : color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Tasks + messages row
                  Row(
                    children: [
                      if (trip.tasks.isNotEmpty) ...[
                        Icon(Icons.task_alt_rounded, size: 13, color: sub),
                        const SizedBox(width: 4),
                        Text(
                          '$doneTasks/${trip.tasks.length} tasks',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Nunito',
                            color: sub,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (trip.messages.isNotEmpty) ...[
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 13,
                          color: sub,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${trip.messages.length} msgs',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Nunito',
                            color: sub,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (trip.votes.isNotEmpty) ...[
                        Icon(
                          Icons.how_to_vote_rounded,
                          size: 13,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${trip.votes.length} votes',
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'Nunito',
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Trip Detail Screen ────────────────────────────────────────────────────────

class _TripDetailScreen extends StatefulWidget {
  final TripModel trip;
  final bool isDark;
  const _TripDetailScreen({required this.trip, required this.isDark});
  @override
  State<_TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<_TripDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _msgCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_msgCtrl.text.trim().isEmpty) return;
    setState(() {
      widget.trip.messages.add(
        TripMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          senderId: 'me',
          text: _msgCtrl.text.trim(),
          at: DateTime.now(),
        ),
      );
    });
    _msgCtrl.clear();
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    const color = Color(0xFF4A9EFF);

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
            Text(widget.trip.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.trip.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tab,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
          ),
          indicatorColor: color,
          labelColor: color,
          unselectedLabelColor: sub,
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Tasks'),
            Tab(text: 'Group'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // ── DETAILS ──
          _TripDetailsTab(trip: widget.trip, isDark: isDark),
          // ── TASKS ──
          _TripTasksTab(
            trip: widget.trip,
            isDark: isDark,
            onToggle: (t) => setState(() => t.done = !t.done),
          ),
          // ── GROUP (chat + votes) ──
          _TripGroupTab(
            trip: widget.trip,
            isDark: isDark,
            msgCtrl: _msgCtrl,
            onSend: _sendMessage,
            onVote: (vote, optIdx) => setState(() {
              vote.votes[optIdx] = (vote.votes[optIdx] ?? 0) + 1;
            }),
          ),
        ],
      ),
    );
  }
}

class _TripDetailsTab extends StatelessWidget {
  final TripModel trip;
  final bool isDark;
  const _TripDetailsTab({required this.trip, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);

    final progress = trip.budget != null && trip.budget! > 0
        ? (trip.spent / trip.budget!).clamp(0.0, 1.0)
        : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoRow(
                icon: Icons.location_on_rounded,
                label: trip.destination,
                iconColor: AppColors.expense,
              ),
              InfoRow(
                icon: Icons.airplanemode_active_rounded,
                label: '${trip.travelMode.emoji} ${trip.travelMode.label}',
                iconColor: const Color(0xFF4A9EFF),
              ),
              if (trip.startDate != null)
                InfoRow(
                  icon: Icons.calendar_today_rounded,
                  label:
                      '${fmtDate(trip.startDate!)} → ${fmtDate(trip.endDate ?? trip.startDate!)}',
                  iconColor: AppColors.primary,
                ),
              if (trip.notes != null)
                InfoRow(icon: Icons.notes_rounded, label: trip.notes!),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Budget
        if (trip.budget != null) ...[
          Text(
            'Budget',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              fontFamily: 'Nunito',
              color: tc,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      '₹${trip.spent.toStringAsFixed(0)} spent',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'DM Mono',
                        color: tc,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'of ₹${trip.budget!.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Nunito',
                        color: sub,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: const Color(0xFF4A9EFF).withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation(
                      progress > 0.85
                          ? AppColors.expense
                          : const Color(0xFF4A9EFF),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Members
        Text(
          'Travellers',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            fontFamily: 'Nunito',
            color: tc,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: trip.memberIds.map((id) {
            final m = mockMembers.firstWhere(
              (m) => m.id == id,
              orElse: () => const PlanMember(id: '?', name: '?', emoji: '👤'),
            );
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: surfBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(m.emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    m.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Nunito',
                      color: tc,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _TripTasksTab extends StatelessWidget {
  final TripModel trip;
  final bool isDark;
  final void Function(TripTask) onToggle;
  const _TripTasksTab({
    required this.trip,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    if (trip.tasks.isEmpty) {
      return const PlanEmptyState(
        emoji: '✅',
        title: 'No tasks yet',
        subtitle: 'Add tasks to track trip preparation',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: trip.tasks.length,
      itemBuilder: (_, i) {
        final t = trip.tasks[i];
        final m = mockMembers.firstWhere(
          (m) => m.id == t.assignedTo,
          orElse: () => const PlanMember(id: '?', name: '?', emoji: '👤'),
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => onToggle(t),
                  child: Icon(
                    t.done
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: t.done ? AppColors.income : sub,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: tc,
                          decoration: t.done
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      Row(
                        children: [
                          Text(m.emoji, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(
                            m.name,
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'Nunito',
                              color: sub,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TripGroupTab extends StatelessWidget {
  final TripModel trip;
  final bool isDark;
  final TextEditingController msgCtrl;
  final VoidCallback onSend;
  final void Function(TripVote, int) onVote;
  const _TripGroupTab({
    required this.trip,
    required this.isDark,
    required this.msgCtrl,
    required this.onSend,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;

    return Column(
      children: [
        // Votes section
        if (trip.votes.isNotEmpty)
          Container(
            color: cardBg,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🗳️ Group Votes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    color: tc,
                  ),
                ),
                const SizedBox(height: 10),
                ...trip.votes.map((v) {
                  final total = v.votes.values.fold(0, (a, b) => a + b);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.question,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                            color: tc,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...v.options.asMap().entries.map((e) {
                          final pct = total > 0
                              ? (v.votes[e.key] ?? 0) / total
                              : 0.0;
                          return GestureDetector(
                            onTap: () => onVote(v, e.key),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Stack(
                                      children: [
                                        Container(
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: surfBg,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        FractionallySizedBox(
                                          widthFactor: pct.clamp(0.0, 1.0),
                                          child: Container(
                                            height: 30,
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF4A9EFF,
                                              ).withOpacity(0.3),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                        Positioned.fill(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    e.value,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontFamily: 'Nunito',
                                                      color: tc,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  '${v.votes[e.key] ?? 0}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    fontFamily: 'Nunito',
                                                    color: sub,
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
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

        // Chat
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            itemCount: trip.messages.length,
            itemBuilder: (_, i) {
              final msg = trip.messages[i];
              final isMe = msg.senderId == 'me';
              final m = mockMembers.firstWhere(
                (m) => m.id == msg.senderId,
                orElse: () => const PlanMember(id: '?', name: '?', emoji: '👤'),
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: isMe
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isMe) ...[
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.primary.withOpacity(0.12),
                        child: Text(
                          m.emoji,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.65,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isMe
                            ? const Color(0xFF4A9EFF)
                            : (isDark ? AppColors.cardDark : Colors.white),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isMe ? 16 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMe)
                            Text(
                              m.name,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                                color: AppColors.primary,
                              ),
                            ),
                          Text(
                            msg.text,
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'Nunito',
                              color: isMe ? Colors.white : tc,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Input bar
        Container(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            8 + MediaQuery.of(context).viewInsets.bottom,
          ),
          color: cardBg,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: surfBg,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: TextField(
                    controller: msgCtrl,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Nunito',
                      color: isDark ? AppColors.textDark : AppColors.textLight,
                    ),
                    decoration: InputDecoration.collapsed(
                      hintText: 'Type a message…',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Nunito',
                        color: sub,
                      ),
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onSend,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4A9EFF),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Add Trip Sheet ────────────────────────────────────────────────────────────

class _AddTripSheet extends StatefulWidget {
  final bool isDark;
  final Color surfBg;
  final String walletId;
  final void Function(TripModel) onSave;
  const _AddTripSheet({
    required this.isDark,
    required this.surfBg,
    required this.walletId,
    required this.onSave,
  });
  @override
  State<_AddTripSheet> createState() => _AddTripSheetState();
}

class _AddTripSheetState extends State<_AddTripSheet> {
  final _titleCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _emoji = '✈️';
  TravelMode _mode = TravelMode.flight;
  DateTime? _start;
  DateTime? _end;
  List<String> _members = ['me'];

  final _emojis = ['✈️', '🏖️', '🌿', '🗺️', '🏔️', '🏕️', '🌍', '🚢', '🚂'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _destCtrl.dispose();
    _budgetCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final sub = widget.isDark ? AppColors.subDark : AppColors.subLight;
    const color = Color(0xFF4A9EFF);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Plan a Trip',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFamily: 'Nunito',
              color: tc,
            ),
          ),
          const SizedBox(height: 16),

          // Emoji
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _emojis
                  .map(
                    (e) => GestureDetector(
                      onTap: () => setState(() => _emoji = e),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _emoji == e
                              ? color.withOpacity(0.15)
                              : widget.surfBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _emoji == e ? color : Colors.transparent,
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

          PlanInputField(controller: _titleCtrl, hint: 'Trip title *'),
          const SizedBox(height: 8),
          PlanInputField(controller: _destCtrl, hint: 'Destination *'),
          const SizedBox(height: 8),
          PlanInputField(
            controller: _budgetCtrl,
            hint: 'Budget (₹)',
            inputType: TextInputType.number,
          ),
          const SizedBox(height: 12),

          // Travel mode
          const SheetLabel(text: 'TRAVEL MODE'),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: TravelMode.values
                  .map(
                    (m) => GestureDetector(
                      onTap: () => setState(() => _mode = m),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _mode == m
                              ? color.withOpacity(0.15)
                              : widget.surfBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _mode == m ? color : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(m.emoji, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Text(
                              m.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Nunito',
                                color: _mode == m ? color : sub,
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
          const SizedBox(height: 12),

          // Dates
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (d != null) setState(() => _start = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: widget.surfBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.flight_takeoff_rounded,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _start != null ? fmtDateShort(_start!) : 'Start',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _start ?? DateTime.now(),
                      firstDate: _start ?? DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (d != null) setState(() => _end = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: widget.surfBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.flight_land_rounded,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _end != null ? fmtDateShort(_end!) : 'End',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Travellers
          const SheetLabel(text: 'TRAVELLERS'),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: mockMembers.map((m) {
                final sel = _members.contains(m.id);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (sel && m.id != 'me')
                      _members.remove(m.id);
                    else if (!sel)
                      _members.add(m.id);
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: sel ? color.withOpacity(0.15) : widget.surfBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: sel ? color : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(m.emoji, style: const TextStyle(fontSize: 18)),
                        Text(
                          m.name.split(' ')[0],
                          style: TextStyle(
                            fontSize: 8,
                            fontFamily: 'Nunito',
                            color: sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          PlanInputField(
            controller: _notesCtrl,
            hint: 'Notes (optional)',
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          SaveButton(
            label: 'Save Trip',
            color: color,
            onTap: () {
              if (_titleCtrl.text.trim().isEmpty ||
                  _destCtrl.text.trim().isEmpty)
                return;
              widget.onSave(
                TripModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: _titleCtrl.text.trim(),
                  emoji: _emoji,
                  destination: _destCtrl.text.trim(),
                  travelMode: _mode,
                  walletId: widget.walletId,
                  startDate: _start,
                  endDate: _end,
                  budget: double.tryParse(_budgetCtrl.text.trim()),
                  memberIds: _members,
                  tasks: [],
                  messages: [],
                  votes: [],
                  notes: _notesCtrl.text.trim().isEmpty
                      ? null
                      : _notesCtrl.text.trim(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
