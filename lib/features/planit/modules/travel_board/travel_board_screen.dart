import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';
import '../../widgets/plan_widgets.dart';
import 'package:wai_life_assistant/core/widgets/emoji_or_image.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TRAVEL BOARD SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class TravelBoardScreen extends StatefulWidget {
  final String walletId;
  final String walletName;
  final String walletEmoji;
  final List<PlanMember> members;
  final List<TripModel> trips;

  const TravelBoardScreen({
    super.key,
    required this.walletId,
    this.walletName = 'Personal',
    this.walletEmoji = '👤',
    this.members = const [],
    required this.trips,
  });

  @override
  State<TravelBoardScreen> createState() => _TravelBoardScreenState();
}

class _TravelBoardScreenState extends State<TravelBoardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  TripStatus? _filterStatus;

  List<TripModel> get _allTrips =>
      widget.trips.where((t) => t.walletId == widget.walletId).toList();

  List<TripModel> get _filtered {
    var list = _allTrips;
    if (_filterStatus != null)
      list = list.where((t) => t.status == _filterStatus).toList();
    list.sort((a, b) {
      if (a.startDate == null && b.startDate == null) return 0;
      if (a.startDate == null) return 1;
      if (b.startDate == null) return -1;
      return a.startDate!.compareTo(b.startDate!);
    });
    return list;
  }

  List<TripModel> get _upcoming => _allTrips
      .where(
        (t) =>
            t.status != TripStatus.completed &&
            t.status != TripStatus.cancelled,
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _add(TripModel t) => setState(() => widget.trips.add(t));
  void _delete(TripModel t) => setState(() => widget.trips.remove(t));
  void _update(TripModel updated) => setState(() {
    final i = widget.trips.indexWhere((t) => t.id == updated.id);
    if (i >= 0) widget.trips[i] = updated;
  });

  void _openAddSheet(BuildContext ctx, bool isDark, Color surfBg) =>
      _openTripSheet(ctx, isDark, surfBg, null);

  void _openTripSheet(
    BuildContext ctx,
    bool isDark,
    Color surfBg,
    TripModel? existing,
  ) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _TripSheetHost(
        isDark: isDark,
        surfBg: surfBg,
        walletId: widget.walletId,
        members: widget.members,
        existing: existing,
        onSave: existing != null ? _update : _add,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(isDark, cardBg),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.selectionClick();
          _openAddSheet(context, isDark, surfBg);
        },
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
      body: Column(
        children: [
          _buildStatsBar(isDark, cardBg),
          _buildStatusFilter(isDark, cardBg),
          Expanded(
            child: _filtered.isEmpty
                ? _buildEmpty(isDark)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) => _TripCard(
                      trip: _filtered[i],
                      members: widget.members,
                      isDark: isDark,
                      onTap: () =>
                          _openDetailSheet(ctx, _filtered[i], isDark, surfBg),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  AppBar _buildAppBar(bool isDark, Color cardBg) {
    return AppBar(
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
      actions: [
        if (widget.walletName != 'Personal')
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF4A9EFF).withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF4A9EFF).withOpacity(0.3),
              ),
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
                      color: Color(0xFF4A9EFF),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Stats bar ──────────────────────────────────────────────────────────────
  Widget _buildStatsBar(bool isDark, Color cardBg) {
    final all = _allTrips;
    final upcoming = all
        .where(
          (t) =>
              t.status == TripStatus.confirmed ||
              t.status == TripStatus.planning,
        )
        .length;
    final ongoing = all.where((t) => t.status == TripStatus.ongoing).length;
    final done = all.where((t) => t.status == TripStatus.completed).length;
    final total = all.fold(0.0, (s, t) => s + t.totalSpent);

    final stats = [
      (
        emoji: '📅',
        value: '$upcoming',
        label: 'Upcoming',
        color: const Color(0xFF4A9EFF),
      ),
      (
        emoji: '🚀',
        value: '$ongoing',
        label: 'Ongoing',
        color: AppColors.income,
      ),
      (emoji: '🏁', value: '$done', label: 'Completed', color: AppColors.split),
      (
        emoji: '💰',
        value: '₹${_fmtK(total)}',
        label: 'Spent',
        color: AppColors.expense,
      ),
    ];

    return Container(
      color: cardBg,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        children: stats.asMap().entries.map((e) {
          final s = e.value;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: e.key > 0 ? 8 : 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: s.color.withOpacity(isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: s.color.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Text(s.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                      s.value,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'DM Mono',
                        color: s.color,
                      ),
                    ),
                    Text(
                      s.label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito',
                        color: s.color.withOpacity(0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Status filter chips ────────────────────────────────────────────────────
  Widget _buildStatusFilter(bool isDark, Color cardBg) {
    const color = Color(0xFF4A9EFF);
    final statuses = [null, ...TripStatus.values];
    return Container(
      color: cardBg,
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: statuses.map((s) {
          final selected = _filterStatus == s;
          final label = s == null ? 'All' : s.label;
          final emoji = s == null ? '✈️' : s.emoji;
          return GestureDetector(
            onTap: () => setState(() => _filterStatus = s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? color : color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? color : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: selected ? Colors.white : color,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✈️', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          Text(
            'No trips yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontFamily: 'Nunito',
              color: isDark ? AppColors.textDark : AppColors.textLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + Plan Trip to start planning\nyour next adventure!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Nunito',
              color: isDark ? AppColors.subDark : AppColors.subLight,
            ),
          ),
        ],
      ),
    );
  }

  // ── Detail sheet ───────────────────────────────────────────────────────────
  void _openDetailSheet(
    BuildContext ctx,
    TripModel trip,
    bool isDark,
    Color surfBg,
  ) {
    showPlanSheet(
      ctx,
      child: _TripDetailSheet(
        trip: trip,
        members: widget.members,
        isDark: isDark,
        surfBg: surfBg,
        onEdit: () {
          Navigator.pop(ctx);
          _openTripSheet(ctx, isDark, surfBg, trip);
        },
        onDelete: () {
          _delete(trip);
          Navigator.pop(ctx);
        },
        onUpdate: (t) => setState(() {
          final i = widget.trips.indexWhere((x) => x.id == t.id);
          if (i >= 0) widget.trips[i] = t;
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRIP CARD
// ─────────────────────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  final TripModel trip;
  final List<PlanMember> members;
  final bool isDark;
  final VoidCallback onTap;

  const _TripCard({
    required this.trip,
    required this.members,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF4A9EFF);
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final statusColor = _statusColor(trip.status);

    final daysLeft = trip.startDate != null
        ? trip.startDate!.difference(DateTime.now()).inDays
        : null;
    final budgetPct = (trip.budget != null && trip.budget! > 0)
        ? (trip.totalSpent / trip.budget!).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isDark ? 0.06 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top colour strip
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.4)],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      Text(trip.emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Nunito',
                                color: tc,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  size: 12,
                                  color: Color(0xFF4A9EFF),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    trip.destinationLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'Nunito',
                                      color: color,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: statusColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '${trip.status.emoji} ${trip.status.label}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Date + travel mode row
                  Row(
                    children: [
                      _InfoChip(
                        icon: trip.travelMode.emoji,
                        label: trip.travelMode.label,
                        color: sub,
                      ),
                      const SizedBox(width: 8),
                      if (trip.startDate != null) ...[
                        _InfoChip(
                          icon: '📅',
                          label: _fmtDateRange(trip.startDate, trip.endDate),
                          color: sub,
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (daysLeft != null && daysLeft >= 0)
                        _InfoChip(
                          icon: '⏳',
                          label: daysLeft == 0
                              ? 'Today!'
                              : '$daysLeft days left',
                          color: daysLeft <= 3 ? AppColors.expense : sub,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Budget progress
                  if (trip.budget != null) ...[
                    Row(
                      children: [
                        Text(
                          '₹${_fmtK(trip.totalSpent)} / ₹${_fmtK(trip.budget!)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'DM Mono',
                            color: budgetPct > 0.8 ? AppColors.expense : sub,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${(budgetPct * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'DM Mono',
                            color: budgetPct > 0.8 ? AppColors.expense : color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: budgetPct,
                        backgroundColor: color.withOpacity(0.12),
                        valueColor: AlwaysStoppedAnimation(
                          budgetPct > 0.9 ? AppColors.expense : color,
                        ),
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Members + tasks row
                  Row(
                    children: [
                      // Member avatars — simple Row, no Stack
                      ...trip.memberIds.take(4).map((id) {
                        final m = (members.isNotEmpty ? members : mockMembers)
                            .firstWhere(
                              (x) => x.id == id,
                              orElse: () => const PlanMember(
                                id: '?',
                                name: '?',
                                emoji: '👤',
                              ),
                            );
                        return Container(
                          width: 26,
                          height: 26,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: cardBg, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            m.emoji,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }),
                      const Spacer(),
                      // Task progress
                      if (trip.tasksTotal > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.income.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 12,
                                color: AppColors.income,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${trip.tasksDone}/${trip.tasksTotal} tasks',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Nunito',
                                  color: AppColors.income,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Color(0xFF4A9EFF),
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
  }
}

class _InfoChip extends StatelessWidget {
  final String icon, label;
  final Color color;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(icon, style: const TextStyle(fontSize: 11)),
      const SizedBox(width: 3),
      Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TRIP DETAIL SHEET — full-screen bottom sheet with tabs
// ─────────────────────────────────────────────────────────────────────────────

class _TripDetailSheet extends StatefulWidget {
  final TripModel trip;
  final List<PlanMember> members;
  final bool isDark;
  final Color surfBg;
  final VoidCallback onEdit, onDelete;
  final void Function(TripModel) onUpdate;

  const _TripDetailSheet({
    required this.trip,
    required this.members,
    required this.isDark,
    required this.surfBg,
    required this.onEdit,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  State<_TripDetailSheet> createState() => _TripDetailSheetState();
}

class _TripDetailSheetState extends State<_TripDetailSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  TripModel get t => widget.trip;
  List<PlanMember> get _effectiveMembers =>
      widget.members.isNotEmpty ? widget.members : mockMembers;

  PlanMember _member(String id) => _effectiveMembers.firstWhere(
    (m) => m.id == id,
    orElse: () => const PlanMember(id: '?', name: '?', emoji: '👤'),
  );

  void _save() => widget.onUpdate(widget.trip);

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    const color = Color(0xFF4A9EFF);
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                Text(t.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito',
                          color: tc,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 12,
                            color: color,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              t.destinationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: color,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Nunito',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(t.status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${t.status.emoji} ${t.status.label}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: _statusColor(t.status),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Edit & delete
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: sub),
                  onSelected: (v) {
                    if (v == 'edit') widget.onEdit();
                    if (v == 'delete') widget.onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, size: 16),
                          SizedBox(width: 8),
                          Text('Edit trip'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_rounded,
                            size: 16,
                            color: AppColors.expense,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Delete',
                            style: TextStyle(color: AppColors.expense),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Date + budget strip
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                if (t.startDate != null) ...[
                  _DetailChip(
                    icon: '📅',
                    label: _fmtDateRange(t.startDate, t.endDate),
                    color: color,
                  ),
                  const SizedBox(width: 8),
                ],
                _DetailChip(
                  icon: t.travelMode.emoji,
                  label: t.travelMode.label,
                  color: sub,
                ),
                const Spacer(),
                if (t.budget != null)
                  _DetailChip(
                    icon: '💰',
                    label: '₹${_fmtK(t.totalSpent)} / ₹${_fmtK(t.budget!)}',
                    color: t.totalSpent > t.budget!
                        ? AppColors.expense
                        : AppColors.income,
                  ),
              ],
            ),
          ),

          // Tabs
          TabBar(
            controller: _tab,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontFamily: 'Nunito',
              fontSize: 12,
            ),
            indicatorColor: color,
            labelColor: color,
            unselectedLabelColor: sub,
            isScrollable: true,
            tabs: const [
              Tab(text: '📋 Overview'),
              Tab(text: '✅ Tasks'),
              Tab(text: '💰 Expenses'),
              Tab(text: '💬 Chat'),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _OverviewTab(
                  trip: t,
                  members: _effectiveMembers,
                  isDark: isDark,
                  surfBg: widget.surfBg,
                ),
                _TasksTab(
                  trip: t,
                  members: _effectiveMembers,
                  isDark: isDark,
                  surfBg: widget.surfBg,
                  onUpdate: _save,
                ),
                _ExpensesTab(
                  trip: t,
                  members: _effectiveMembers,
                  isDark: isDark,
                  surfBg: widget.surfBg,
                  onUpdate: _save,
                ),
                _ChatTab(
                  trip: t,
                  members: _effectiveMembers,
                  isDark: isDark,
                  surfBg: widget.surfBg,
                  onUpdate: _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String icon, label;
  final Color color;
  const _DetailChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// OVERVIEW TAB
// ─────────────────────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final TripModel trip;
  final List<PlanMember> members;
  final bool isDark;
  final Color surfBg;
  const _OverviewTab({
    required this.trip,
    required this.members,
    required this.isDark,
    required this.surfBg,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    const color = Color(0xFF4A9EFF);

    PlanMember member(String id) => members.firstWhere(
      (m) => m.id == id,
      orElse: () => const PlanMember(id: '?', name: '?', emoji: '👤'),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // Destinations section
        _SectionHeader(title: 'DESTINATIONS', icon: '📍'),
        const SizedBox(height: 8),
        ...trip.destinations.asMap().entries.map((e) {
          final d = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${e.key + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'DM Mono',
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                          color: tc,
                        ),
                      ),
                      if (d.notes != null)
                        Text(
                          d.notes!,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Nunito',
                            color: sub,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trip.destinations.length > 1 &&
                    e.key < trip.destinations.length - 1)
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: color,
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),

        // Members section
        _SectionHeader(title: 'WHO\'S GOING', icon: '👥'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surfBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              ...trip.memberIds.map((id) {
                final m = member(id);
                final isCreator = id == trip.createdBy;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          m.emoji,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          m.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                            color: tc,
                          ),
                        ),
                      ),
                      if (isCreator)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Organiser',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: color,
                            ),
                          ),
                        ),
                      // Their expenses total
                      const SizedBox(width: 6),
                      Text(
                        '₹${_fmtK(trip.expenses.where((e) => e.paidBy == id).fold(0.0, (s, e) => s + e.amount))}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'DM Mono',
                          color: AppColors.income,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Votes section
        if (trip.votes.isNotEmpty) ...[
          _SectionHeader(title: 'POLLS & VOTES', icon: '🗳️'),
          const SizedBox(height: 8),
          ...trip.votes.map(
            (v) => _VoteCard(vote: v, isDark: isDark, surfBg: surfBg),
          ),
          const SizedBox(height: 16),
        ],

        // Notes section
        if (trip.notes != null && trip.notes!.isNotEmpty) ...[
          _SectionHeader(title: 'NOTES', icon: '📝'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              trip.notes!,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'Nunito',
                color: tc,
                height: 1.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _VoteCard extends StatelessWidget {
  final TripVote vote;
  final bool isDark;
  final Color surfBg;
  const _VoteCard({
    required this.vote,
    required this.isDark,
    required this.surfBg,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    const color = Color(0xFF4A9EFF);
    final total = vote.tally.values.fold(0, (s, v) => s + v);
    final winner = vote.tally.isEmpty
        ? -1
        : vote.tally.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vote.question,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              fontFamily: 'Nunito',
              color: tc,
            ),
          ),
          const SizedBox(height: 8),
          ...vote.options.asMap().entries.map((e) {
            final count = vote.tally[e.key] ?? 0;
            final pct = total > 0 ? count / total : 0.0;
            final isWin = e.key == winner && total > 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isWin)
                        const Text('🏆 ', style: TextStyle(fontSize: 11)),
                      Expanded(
                        child: Text(
                          e.value,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                            color: isWin ? AppColors.income : tc,
                          ),
                        ),
                      ),
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'DM Mono',
                          fontWeight: FontWeight.w700,
                          color: isWin ? AppColors.income : color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 4,
                      backgroundColor: color.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation(
                        isWin ? AppColors.income : color,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TASKS TAB
// ─────────────────────────────────────────────────────────────────────────────

class _TasksTab extends StatefulWidget {
  final TripModel trip;
  final List<PlanMember> members;
  final bool isDark;
  final Color surfBg;
  final VoidCallback onUpdate;
  const _TasksTab({
    required this.trip,
    required this.members,
    required this.isDark,
    required this.surfBg,
    required this.onUpdate,
  });

  @override
  State<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<_TasksTab> {
  TaskCategory? _filterCat;

  List<TripTask> get _filtered => _filterCat == null
      ? widget.trip.tasks
      : widget.trip.tasks.where((t) => t.category == _filterCat).toList();

  List<TripTask> get _pending => _filtered.where((t) => !t.done).toList();
  List<TripTask> get _done => _filtered.where((t) => t.done).toList();

  PlanMember _member(String id) => widget.members.firstWhere(
    (m) => m.id == id,
    orElse: () => const PlanMember(id: '?', name: '?', emoji: '👤'),
  );

  void _toggle(TripTask task) {
    setState(() => task.done = !task.done);
    widget.onUpdate();
  }

  void _deleteTask(TripTask task) {
    setState(() => widget.trip.tasks.remove(task));
    widget.onUpdate();
  }

  void _openAddTask(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _TripTaskSheet(
        isDark: widget.isDark,
        surfBg: widget.surfBg,
        members: widget.members,
        onSave: (task) {
          setState(() => widget.trip.tasks.add(task));
          widget.onUpdate();
        },
      ),
    );
  }

  void _openEditTask(BuildContext ctx, TripTask task) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _TripTaskSheet(
        isDark: widget.isDark,
        surfBg: widget.surfBg,
        members: widget.members,
        existing: task,
        onSave: (updated) {
          setState(() {
            final i = widget.trip.tasks.indexWhere((t) => t.id == updated.id);
            if (i >= 0) widget.trip.tasks[i] = updated;
          });
          widget.onUpdate();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final sub = widget.isDark ? AppColors.subDark : AppColors.subLight;
    const color = Color(0xFF4A9EFF);

    return Column(
      children: [
        // Category filter
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [null, ...TaskCategory.values].map((cat) {
              final sel = _filterCat == cat;
              final lbl = cat == null ? 'All' : cat.label;
              final ico = cat == null ? '📋' : cat.emoji;
              return GestureDetector(
                onTap: () => setState(() => _filterCat = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: sel ? color : color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? color : Colors.transparent),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(ico, style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Text(
                        lbl,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                          color: sel ? Colors.white : color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Add task button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: GestureDetector(
            onTap: () => _openAddTask(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withOpacity(0.25),
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_rounded, size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(
                    'Add task / preparation item…',
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
          ),
        ),

        // Task list
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              if (_pending.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'PENDING (${_pending.length})',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                      color: sub,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                ..._pending.map(
                  (task) => _TaskTile(
                    task: task,
                    member: _member(task.assignedTo),
                    addedByMember: _member(task.addedBy),
                    isDark: widget.isDark,
                    surfBg: widget.surfBg,
                    onToggle: () => _toggle(task),
                    onEdit: () => _openEditTask(context, task),
                    onDelete: () => _deleteTask(task),
                  ),
                ),
              ],
              if (_done.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'DONE (${_done.length})',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                      color: sub,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                ..._done.map(
                  (task) => _TaskTile(
                    task: task,
                    member: _member(task.assignedTo),
                    addedByMember: _member(task.addedBy),
                    isDark: widget.isDark,
                    surfBg: widget.surfBg,
                    onToggle: () => _toggle(task),
                    onEdit: () => _openEditTask(context, task),
                    onDelete: () => _deleteTask(task),
                  ),
                ),
              ],
              if (_filtered.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Text(
                      'No tasks yet',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Nunito',
                        color: sub,
                      ),
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

class _TaskTile extends StatelessWidget {
  final TripTask task;
  final PlanMember member;
  final PlanMember addedByMember;
  final bool isDark;
  final Color surfBg;
  final VoidCallback onToggle, onEdit, onDelete;

  const _TaskTile({
    required this.task,
    required this.member,
    required this.addedByMember,
    required this.isDark,
    required this.surfBg,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    const color = Color(0xFF4A9EFF);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: task.done
              ? AppColors.income.withOpacity(0.2)
              : color.withOpacity(0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: task.done ? AppColors.income : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: task.done ? AppColors.income : color.withOpacity(0.4),
                  width: 2,
                ),
              ),
              child: task.done
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      task.category.emoji,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: task.done ? sub : tc,
                          decoration: task.done
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Assigned to + added by
                Row(
                  children: [
                    Text(member.emoji, style: const TextStyle(fontSize: 11)),
                    const SizedBox(width: 3),
                    Text(
                      member.name,
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    Text(
                      ' · added by ${addedByMember.name}',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'Nunito',
                        color: sub,
                      ),
                    ),
                    if (task.cost != null) ...[
                      const Spacer(),
                      Text(
                        '₹${_fmtK(task.cost!)}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'DM Mono',
                          color: AppColors.expense,
                        ),
                      ),
                    ],
                  ],
                ),
                if (task.notes != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    task.notes!,
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'Nunito',
                      color: sub,
                      height: 1.3,
                    ),
                  ),
                ],
                if (task.dueDate != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 10, color: sub),
                      const SizedBox(width: 3),
                      Text(
                        fmtDateShort(task.dueDate!),
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
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            iconSize: 16,
            icon: Icon(Icons.more_vert_rounded, size: 16, color: sub),
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete',
                  style: TextStyle(color: AppColors.expense),
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
// EXPENSES TAB
// ─────────────────────────────────────────────────────────────────────────────

class _ExpensesTab extends StatefulWidget {
  final TripModel trip;
  final List<PlanMember> members;
  final bool isDark;
  final Color surfBg;
  final VoidCallback onUpdate;
  const _ExpensesTab({
    required this.trip,
    required this.members,
    required this.isDark,
    required this.surfBg,
    required this.onUpdate,
  });

  @override
  State<_ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<_ExpensesTab> {
  final _descCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  String _paidBy = 'me';

  PlanMember _member(String id) => widget.members.firstWhere(
    (m) => m.id == id,
    orElse: () => const PlanMember(id: '?', name: '?', emoji: '👤'),
  );

  @override
  void dispose() {
    _descCtrl.dispose();
    _amtCtrl.dispose();
    super.dispose();
  }

  void _addExpense() {
    final amt = double.tryParse(_amtCtrl.text.trim());
    final desc = _descCtrl.text.trim();
    if (amt == null || desc.isEmpty) return;
    setState(() {
      widget.trip.expenses.add(
        TripExpense(
          id: 'te_${DateTime.now().millisecondsSinceEpoch}',
          paidBy: _paidBy,
          description: desc,
          amount: amt,
          at: DateTime.now(),
        ),
      );
    });
    _descCtrl.clear();
    _amtCtrl.clear();
    widget.onUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    const color = Color(0xFF4A9EFF);
    final t = widget.trip;

    // Per-member totals
    final memberTotals = <String, double>{};
    for (final e in t.expenses) {
      memberTotals[e.paidBy] = (memberTotals[e.paidBy] ?? 0) + e.amount;
    }
    final sorted = memberTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // Budget summary card
        if (t.budget != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Budget',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito',
                        color: sub,
                      ),
                    ),
                    Text(
                      '₹${_fmtK(t.budget!)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'DM Mono',
                        color: tc,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Spent',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito',
                        color: sub,
                      ),
                    ),
                    Text(
                      '₹${_fmtK(t.totalSpent)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'DM Mono',
                        color: t.totalSpent > t.budget!
                            ? AppColors.expense
                            : AppColors.income,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Remaining',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito',
                        color: sub,
                      ),
                    ),
                    Text(
                      '₹${_fmtK((t.budget! - t.totalSpent).abs())}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'DM Mono',
                        color: t.totalSpent > t.budget!
                            ? AppColors.expense
                            : color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (t.totalSpent / t.budget!).clamp(0, 1.0),
                    minHeight: 6,
                    backgroundColor: color.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation(
                      t.totalSpent > t.budget! ? AppColors.expense : color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Who paid what
        if (sorted.isNotEmpty) ...[
          _SectionHeader(title: 'WHO PAID', icon: '💳'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.surfBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: sorted.map((entry) {
                final m = _member(entry.key);
                final pct = t.totalSpent > 0 ? entry.value / t.totalSpent : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(m.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  m.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                    color: tc,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '₹${_fmtK(entry.value)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'DM Mono',
                                    color: AppColors.income,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 4,
                                backgroundColor: color.withOpacity(0.1),
                                valueColor: const AlwaysStoppedAnimation(
                                  AppColors.income,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Add expense
        _SectionHeader(title: 'ADD EXPENSE', icon: '➕'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.surfBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              PlanInputField(
                controller: _descCtrl,
                hint: 'Description (e.g. Hotel booking)',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: PlanInputField(
                      controller: _amtCtrl,
                      hint: 'Amount (₹)',
                      inputType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Paid by picker
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.bgDark : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        children:
                            (widget.members.isNotEmpty
                                    ? widget.members
                                    : mockMembers)
                                .take(4)
                                .map(
                                  (m) => GestureDetector(
                                    onTap: () => setState(() => _paidBy = m.id),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 150,
                                      ),
                                      margin: const EdgeInsets.only(right: 6),
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: _paidBy == m.id
                                            ? AppColors.income.withOpacity(0.2)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _paidBy == m.id
                                              ? AppColors.income
                                              : Colors.transparent,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        m.emoji,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SaveButton(
                label: 'Add Expense →',
                color: AppColors.income,
                onTap: _addExpense,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Expense list
        if (t.expenses.isNotEmpty) ...[
          _SectionHeader(title: 'ALL EXPENSES', icon: '🧾'),
          const SizedBox(height: 8),
          ...t.expenses.reversed.map((e) {
            final m = _member(e.paidBy);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.surfBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.income.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.income.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(m.emoji, style: const TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.description,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                            color: tc,
                          ),
                        ),
                        Text(
                          'Paid by ${m.name} · ${fmtDateShort(e.at)}',
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'Nunito',
                            color: sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${_fmtK(e.amount)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'DM Mono',
                      color: AppColors.income,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      setState(() => t.expenses.remove(e));
                      widget.onUpdate();
                    },
                    child: Icon(Icons.close_rounded, size: 16, color: sub),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHAT TAB
// ─────────────────────────────────────────────────────────────────────────────

class _ChatTab extends StatefulWidget {
  final TripModel trip;
  final List<PlanMember> members;
  final bool isDark;
  final Color surfBg;
  final VoidCallback onUpdate;
  const _ChatTab({
    required this.trip,
    required this.members,
    required this.isDark,
    required this.surfBg,
    required this.onUpdate,
  });

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  static const _me = 'me';

  PlanMember _member(String id) => widget.members.firstWhere(
    (m) => m.id == id,
    orElse: () => const PlanMember(id: '?', name: '?', emoji: '👤'),
  );

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      widget.trip.messages.add(
        TripMessage(
          id: 'tm_${DateTime.now().millisecondsSinceEpoch}',
          senderId: _me,
          text: text,
          at: DateTime.now(),
        ),
      );
    });
    _ctrl.clear();
    widget.onUpdate();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients)
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    const color = Color(0xFF4A9EFF);
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;

    return Column(
      children: [
        Expanded(
          child: widget.trip.messages.isEmpty
              ? Center(
                  child: Text(
                    'No messages yet.\nStart the conversation! 🗺️',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Nunito',
                      color: sub,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: widget.trip.messages.length,
                  itemBuilder: (ctx, i) {
                    final msg = widget.trip.messages[i];
                    final isMe = msg.senderId == _me;
                    final m = _member(msg.senderId);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          if (!isMe) ...[
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                m.emoji,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                if (!isMe)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      m.name,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Nunito',
                                        color: color,
                                      ),
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMe ? color : widget.surfBg,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(14),
                                      topRight: const Radius.circular(14),
                                      bottomLeft: Radius.circular(
                                        isMe ? 14 : 4,
                                      ),
                                      bottomRight: Radius.circular(
                                        isMe ? 4 : 14,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    msg.text,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontFamily: 'Nunito',
                                      color: isMe
                                          ? Colors.white
                                          : isDark
                                          ? AppColors.textDark
                                          : AppColors.textLight,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    _fmtMsgTime(msg.at),
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: sub,
                                      fontFamily: 'Nunito',
                                    ),
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
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            border: Border(top: BorderSide(color: color.withOpacity(0.1))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: TextField(
                    controller: _ctrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Type a message…',
                      hintStyle: TextStyle(
                        color: sub,
                        fontFamily: 'Nunito',
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textDark : AppColors.textLight,
                      fontFamily: 'Nunito',
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _send,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
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

// ─────────────────────────────────────────────────────────────────────────────
// TRIP ADD/EDIT SHEET WITH AI PARSE
// ─────────────────────────────────────────────────────────────────────────────

class _TripSheetHost extends StatelessWidget {
  final bool isDark;
  final Color surfBg;
  final String walletId;
  final List<PlanMember> members;
  final TripModel? existing;
  final void Function(TripModel) onSave;

  const _TripSheetHost({
    required this.isDark,
    required this.surfBg,
    required this.walletId,
    this.members = const [],
    this.existing,
    required this.onSave,
  });

  @override
  Widget build(BuildContext hostCtx) {
    final isEdit = existing != null;
    final mq = MediaQuery.of(hostCtx);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
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
              child: _AddTripSheet(
                isDark: isDark,
                surfBg: surfBg,
                walletId: walletId,
                members: members,
                existing: existing,
                onSave: (trip) {
                  Navigator.pop(hostCtx);
                  onSave(trip);
                  ScaffoldMessenger.of(hostCtx).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEdit
                            ? '${trip.emoji} "${trip.title}" updated!'
                            : '${trip.emoji} "${trip.title}" added!',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      backgroundColor: const Color(0xFF4A9EFF),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      margin: const EdgeInsets.all(16),
                      duration: const Duration(seconds: 3),
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

class _AddTripSheet extends StatefulWidget {
  final bool isDark;
  final Color surfBg;
  final String walletId;
  final List<PlanMember> members;
  final TripModel? existing;
  final void Function(TripModel) onSave;

  const _AddTripSheet({
    required this.isDark,
    required this.surfBg,
    required this.walletId,
    this.members = const [],
    this.existing,
    required this.onSave,
  });

  @override
  State<_AddTripSheet> createState() => _AddTripSheetState();
}

class _AddTripSheetState extends State<_AddTripSheet>
    with SingleTickerProviderStateMixin {
  late TabController _mode;

  // AI mode
  final _aiCtrl = TextEditingController();
  bool _aiParsing = false;
  _ParsedTrip? _aiPreview;
  String? _aiError;

  // Manual fields
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _emoji = '✈️';
  TravelMode _mode2 = TravelMode.flight;
  TripStatus _status = TripStatus.planning;
  DateTime? _start, _end;
  double? _budget;
  final _budgetCtrl = TextEditingController();
  List<TripDestination> _destinations = [
    TripDestination(name: '', orderIndex: 0),
  ];
  final List<TextEditingController> _destCtrls = [TextEditingController()];
  List<String> _memberIds = ['me'];
  bool _titleError = false;
  bool _destError = false;

  final List<String> _emojis = [
    '✈️',
    '🏖️',
    '🌿',
    '🏔️',
    '🗺️',
    '🏙️',
    '🚗',
    '🚢',
    '🌍',
    '🎒',
    '🛤️',
    '🏕️',
  ];

  @override
  void initState() {
    super.initState();
    _mode = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _notesCtrl.text = e.notes ?? '';
      _emoji = e.emoji;
      _mode2 = e.travelMode;
      _status = e.status;
      _start = e.startDate;
      _end = e.endDate;
      _budget = e.budget;
      _budgetCtrl.text = e.budget != null ? e.budget!.toStringAsFixed(0) : '';
      _destinations = List.from(e.destinations);
      if (_destinations.isEmpty)
        _destinations = [TripDestination(name: '', orderIndex: 0)];
      _destCtrls.clear();
      for (final d in _destinations)
        _destCtrls.add(TextEditingController(text: d.name));
      if (_destCtrls.isEmpty) _destCtrls.add(TextEditingController());
      _memberIds = List.from(e.memberIds);
    }
  }

  @override
  void dispose() {
    _mode.dispose();
    _aiCtrl.dispose();
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _budgetCtrl.dispose();
    for (final c in _destCtrls) c.dispose();
    super.dispose();
  }

  Future<void> _parseAi() async {
    final text = _aiCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _aiParsing = true;
      _aiError = null;
      _aiPreview = null;
    });
    try {
      _ParsedTrip? result;
      try {
        result = await _TripClaudeParser.parse(text, widget.walletId);
      } catch (_) {
        result = _TripNlpParser.parse(text, widget.walletId);
      }
      setState(() {
        _aiPreview = result;
        _aiParsing = false;
      });
    } catch (e) {
      setState(() {
        _aiError = e.toString();
        _aiParsing = false;
      });
    }
  }

  void _applyPreview(_ParsedTrip p) {
    setState(() {
      _titleCtrl.text = p.title;
      _emoji = p.emoji;
      _mode2 = p.travelMode;
      _start = p.startDate;
      _end = p.endDate;
      _budget = p.budget;
      _budgetCtrl.text = p.budget != null ? p.budget!.toStringAsFixed(0) : '';
      _destinations = p.destinations.isNotEmpty
          ? p.destinations
          : [TripDestination(name: p.destination, orderIndex: 0)];
      _destCtrls.clear();
      for (final d in _destinations)
        _destCtrls.add(TextEditingController(text: d.name));
      if (_destCtrls.isEmpty) _destCtrls.add(TextEditingController());
      _memberIds = p.memberIds.isNotEmpty ? p.memberIds : ['me'];
      _aiPreview = null;
      _mode.animateTo(1);
    });
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    // Sync controller text → destination names before validation
    for (int i = 0; i < _destinations.length && i < _destCtrls.length; i++) {
      _destinations[i].name = _destCtrls[i].text.trim();
    }
    final validDest = _destinations.any((d) => d.name.trim().isNotEmpty);
    setState(() {
      _titleError = title.isEmpty;
      _destError = !validDest;
    });
    if (title.isEmpty || !validDest) return;

    final e = widget.existing;
    final trip = TripModel(
      id: e?.id ?? 'tr_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      emoji: _emoji,
      destinations: _destinations
          .where((d) => d.name.trim().isNotEmpty)
          .toList(),
      travelMode: _mode2,
      walletId: widget.walletId,
      createdBy: e?.createdBy ?? 'me',
      startDate: _start,
      endDate: _end,
      budget: double.tryParse(_budgetCtrl.text.trim()) ?? _budget,
      memberIds: _memberIds,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      status: _status,
      tasks: e?.tasks ?? [],
      expenses: e?.expenses ?? [],
      messages: e?.messages ?? [],
      votes: e?.votes ?? [],
    );
    widget.onSave(trip);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    const color = Color(0xFF4A9EFF);
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final isEdit = widget.existing != null;

    return Column(
      children: [
        // Tab bar
        TabBar(
          controller: _mode,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
          ),
          indicatorColor: color,
          labelColor: color,
          unselectedLabelColor: sub,
          tabs: const [
            Tab(text: '✨ AI Plan'),
            Tab(text: '✏️ Manual'),
          ],
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: _mode.index == 0
                ? _buildAiTab(isDark, sub, tc, color)
                : _buildManualTab(isDark, sub, tc, color, isEdit),
          ),
        ),
      ],
    );
  }

  // ── AI Tab ─────────────────────────────────────────────────────────────────
  Widget _buildAiTab(bool isDark, Color sub, Color tc, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hint banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('✨', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Describe your trip in plain English',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '"Family trip to Goa and Pune for 6 days in July, budget 80k, by flight"',
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
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Input
        Container(
          decoration: BoxDecoration(
            color: widget.surfBg,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: TextField(
            controller: _aiCtrl,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            minLines: 2,
            style: TextStyle(fontSize: 14, color: tc, fontFamily: 'Nunito'),
            decoration: InputDecoration.collapsed(
              hintText: 'Describe your trip…',
              hintStyle: TextStyle(
                fontSize: 13,
                color: sub,
                fontFamily: 'Nunito',
              ),
            ),
            onSubmitted: (_) => _parseAi(),
          ),
        ),
        const SizedBox(height: 10),
        SaveButton(
          label: _aiParsing ? 'Planning…' : 'Plan with AI ✨',
          color: color,
          onTap: () {
            if (!_aiParsing) _parseAi();
          },
        ),

        if (_aiError != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.expense.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Could not parse. Try rephrasing or use Manual tab.',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Nunito',
                color: AppColors.expense,
              ),
            ),
          ),
        ],

        if (_aiPreview != null) ...[
          const SizedBox(height: 14),
          _TripPreviewCard(
            preview: _aiPreview!,
            isDark: widget.isDark,
            surfBg: widget.surfBg,
            onApply: () => _applyPreview(_aiPreview!),
          ),
        ],

        // Examples
        const SizedBox(height: 16),
        const SheetLabel(text: 'TRY THESE'),
        const SizedBox(height: 8),
        ...[
          '5-day trip to Manali and Shimla in December, budget 25k, by car',
          'Solo trip to Bangkok for a week in March, flight, budget 60k',
          'Weekend getaway to Coorg with family, by car, budget 8k',
        ].map(
          (ex) => GestureDetector(
            onTap: () {
              _aiCtrl.text = ex;
              setState(() {});
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: widget.surfBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  const Text('✈️', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ex,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Nunito',
                        color: sub,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 10, color: sub),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Manual Tab ─────────────────────────────────────────────────────────────
  Widget _buildManualTab(
    bool isDark,
    Color sub,
    Color tc,
    Color color,
    bool isEdit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Emoji picker
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

        // Title
        Container(
          decoration: BoxDecoration(
            color: widget.surfBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _titleError ? AppColors.expense : Colors.transparent,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleCtrl,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 14, color: tc, fontFamily: 'Nunito'),
                decoration: InputDecoration.collapsed(
                  hintText: 'Trip name *',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: _titleError ? AppColors.expense : sub,
                    fontFamily: 'Nunito',
                  ),
                ),
              ),
              if (_titleError) ...[
                const SizedBox(height: 4),
                const Text(
                  'Trip name is required',
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
        const SizedBox(height: 10),

        // ── DESTINATIONS ──────────────────────────────────────────────────────
        Row(
          children: [
            const SheetLabel(text: 'DESTINATIONS'),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() {
                _destinations.add(
                  TripDestination(name: '', orderIndex: _destinations.length),
                );
                _destCtrls.add(TextEditingController());
              }),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 14, color: color),
                  const SizedBox(width: 3),
                  Text(
                    'Add stop',
                    style: TextStyle(
                      fontSize: 11,
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
        const SizedBox(height: 6),
        ..._destinations.asMap().entries.map((entry) {
          // Ensure _destCtrls is large enough
          while (_destCtrls.length <= entry.key)
            _destCtrls.add(TextEditingController());
          final ctrl = _destCtrls[entry.key];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${entry.key + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'DM Mono',
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.surfBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _destError && entry.value.name.isEmpty
                            ? AppColors.expense
                            : Colors.transparent,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: TextField(
                      controller: ctrl,
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(
                        fontSize: 13,
                        color: tc,
                        fontFamily: 'Nunito',
                      ),
                      decoration: InputDecoration.collapsed(
                        hintText: entry.key == 0
                            ? 'From / Main destination *'
                            : 'Next stop…',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: sub,
                          fontFamily: 'Nunito',
                        ),
                      ),
                      onChanged: (v) {
                        if (entry.key < _destinations.length)
                          _destinations[entry.key].name = v;
                      },
                    ),
                  ),
                ),
                if (_destinations.length > 1) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() {
                      _destinations.removeAt(entry.key);
                      if (entry.key < _destCtrls.length) {
                        _destCtrls[entry.key].dispose();
                        _destCtrls.removeAt(entry.key);
                      }
                    }),
                    child: Icon(Icons.close_rounded, size: 16, color: sub),
                  ),
                ],
              ],
            ),
          );
        }),
        if (_destError)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: const Text(
              'Add at least one destination',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.expense,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        const SizedBox(height: 8),

        // Travel mode
        const SheetLabel(text: 'TRAVEL MODE'),
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: TravelMode.values
                .map(
                  (m) => GestureDetector(
                    onTap: () => setState(() => _mode2 = m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _mode2 == m
                            ? color.withOpacity(0.15)
                            : widget.surfBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _mode2 == m ? color : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(m.emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            m.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: _mode2 == m ? color : sub,
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

        // Status
        const SheetLabel(text: 'STATUS'),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: TripStatus.values
                .map(
                  (s) => GestureDetector(
                    onTap: () => setState(() => _status = s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _status == s
                            ? _statusColor(s).withOpacity(0.15)
                            : widget.surfBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _status == s
                              ? _statusColor(s)
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        '${s.emoji} ${s.label}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                          color: _status == s ? _statusColor(s) : sub,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Dates
        const SheetLabel(text: 'DATES'),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate:
                        _start ?? DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 1825)),
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.flight_takeoff_rounded,
                        size: 14,
                        color: Color(0xFF4A9EFF),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _start != null ? fmtDateShort(_start!) : 'Depart',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: const Color(0xFF4A9EFF),
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
                    initialDate:
                        _end ??
                        (_start ?? DateTime.now()).add(const Duration(days: 3)),
                    firstDate: _start ?? DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 1825)),
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.flight_land_rounded,
                        size: 14,
                        color: Color(0xFF4A9EFF),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _end != null ? fmtDateShort(_end!) : 'Return',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: const Color(0xFF4A9EFF),
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

        // Budget
        const SheetLabel(text: 'BUDGET (OPTIONAL)'),
        const SizedBox(height: 6),
        PlanInputField(
          controller: _budgetCtrl,
          hint: 'Total budget (₹)',
          inputType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 12),

        // Members
        const SheetLabel(text: 'WHO\'S GOING'),
        const SizedBox(height: 6),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: (widget.members.isNotEmpty ? widget.members : mockMembers)
                .map((m) {
                  final selected = _memberIds.contains(m.id);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) {
                        if (_memberIds.length > 1) _memberIds.remove(m.id);
                      } else {
                        _memberIds.add(m.id);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF4A9EFF).withOpacity(0.15)
                            : widget.surfBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF4A9EFF)
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(m.emoji, style: const TextStyle(fontSize: 18)),
                          Text(
                            m.name.split(' ').first,
                            style: TextStyle(
                              fontSize: 8,
                              fontFamily: 'Nunito',
                              color: selected ? const Color(0xFF4A9EFF) : sub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                })
                .toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Notes
        const SheetLabel(text: 'NOTES (OPTIONAL)'),
        const SizedBox(height: 6),
        PlanInputField(
          controller: _notesCtrl,
          hint: 'Trip notes, reminders, ideas…',
          maxLines: 3,
        ),
        const SizedBox(height: 16),

        SaveButton(
          label: widget.existing != null ? 'Update Trip →' : 'Add Trip →',
          color: const Color(0xFF4A9EFF),
          onTap: _save,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── AI Preview Card ──────────────────────────────────────────────────────────

class _TripPreviewCard extends StatelessWidget {
  final _ParsedTrip preview;
  final bool isDark;
  final Color surfBg;
  final VoidCallback onApply;
  const _TripPreviewCard({
    required this.preview,
    required this.isDark,
    required this.surfBg,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    const color = Color(0xFF4A9EFF);

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
              const Text('🗺️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  preview.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Nunito',
                    color: tc,
                  ),
                ),
              ),
              Text(preview.emoji, style: const TextStyle(fontSize: 22)),
            ],
          ),
          const SizedBox(height: 8),
          if (preview.destinations.isNotEmpty)
            Text(
              '📍 ${preview.destinations.map((d) => d.name).join(' → ')}',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Nunito',
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${preview.travelMode.emoji} ${preview.travelMode.label}',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Nunito',
                  color: sub,
                ),
              ),
              if (preview.startDate != null) ...[
                const SizedBox(width: 10),
                Text(
                  '📅 ${fmtDateShort(preview.startDate!)}${preview.endDate != null ? ' – ${fmtDateShort(preview.endDate!)}' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Nunito',
                    color: sub,
                  ),
                ),
              ],
              if (preview.budget != null) ...[
                const SizedBox(width: 10),
                Text(
                  '💰 ₹${_fmtK(preview.budget!)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Nunito',
                    color: AppColors.income,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          SaveButton(
            label: 'Use This Plan →',
            color: AppColors.income,
            onTap: onApply,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRIP TASK SHEET (Add / Edit)
// ─────────────────────────────────────────────────────────────────────────────

class _TripTaskSheet extends StatefulWidget {
  final bool isDark;
  final Color surfBg;
  final List<PlanMember> members;
  final TripTask? existing;
  final void Function(TripTask) onSave;
  const _TripTaskSheet({
    required this.isDark,
    required this.surfBg,
    required this.members,
    this.existing,
    required this.onSave,
  });

  @override
  State<_TripTaskSheet> createState() => _TripTaskSheetState();
}

class _TripTaskSheetState extends State<_TripTaskSheet> {
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  String _assignedTo = 'me';
  TaskCategory _cat = TaskCategory.other;
  DateTime? _dueDate;
  bool _titleError = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _notesCtrl.text = e.notes ?? '';
      _costCtrl.text = e.cost != null ? e.cost!.toStringAsFixed(0) : '';
      _assignedTo = e.assignedTo;
      _cat = e.category;
      _dueDate = e.dueDate;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    setState(() => _titleError = title.isEmpty);
    if (title.isEmpty) return;
    final e = widget.existing;
    widget.onSave(
      TripTask(
        id: e?.id ?? 'tt_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        assignedTo: _assignedTo,
        addedBy: e?.addedBy ?? 'me',
        category: _cat,
        cost: double.tryParse(_costCtrl.text.trim()),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        done: e?.done ?? false,
        dueDate: _dueDate,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    const color = Color(0xFF4A9EFF);
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final kb = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: kb),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Text(
                widget.existing != null ? 'Edit Task' : 'Add Task',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                  color: tc,
                ),
              ),
              const SizedBox(height: 12),

              // Title
              Container(
                decoration: BoxDecoration(
                  color: widget.surfBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _titleError ? AppColors.expense : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: TextField(
                  controller: _titleCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    fontSize: 14,
                    color: tc,
                    fontFamily: 'Nunito',
                  ),
                  decoration: InputDecoration.collapsed(
                    hintText: 'Task title *',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: sub,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Category
              const SheetLabel(text: 'CATEGORY'),
              const SizedBox(height: 6),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: TaskCategory.values
                      .map(
                        (cat) => GestureDetector(
                          onTap: () => setState(() => _cat = cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _cat == cat
                                  ? color.withOpacity(0.15)
                                  : widget.surfBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _cat == cat ? color : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  cat.emoji,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  cat.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Nunito',
                                    color: _cat == cat ? color : sub,
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
              const SizedBox(height: 10),

              // Assign to
              const SheetLabel(text: 'ASSIGN TO'),
              const SizedBox(height: 6),
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children:
                      (widget.members.isNotEmpty ? widget.members : mockMembers)
                          .map(
                            (m) => GestureDetector(
                              onTap: () => setState(() => _assignedTo = m.id),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.only(right: 8),
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: _assignedTo == m.id
                                      ? color.withOpacity(0.15)
                                      : widget.surfBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _assignedTo == m.id
                                        ? color
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      m.emoji,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    Text(
                                      m.name.split(' ').first,
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontFamily: 'Nunito',
                                        color: _assignedTo == m.id
                                            ? color
                                            : sub,
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
              const SizedBox(height: 10),

              // Due date + cost
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate:
                              _dueDate ??
                              DateTime.now().add(const Duration(days: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 730),
                          ),
                        );
                        if (d != null) setState(() => _dueDate = d);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: widget.surfBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 14,
                              color: Color(0xFF4A9EFF),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _dueDate != null
                                  ? fmtDateShort(_dueDate!)
                                  : 'Due date',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Nunito',
                                color: Color(0xFF4A9EFF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PlanInputField(
                      controller: _costCtrl,
                      hint: 'Est. cost (₹)',
                      inputType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Notes
              PlanInputField(
                controller: _notesCtrl,
                hint: 'Notes (optional)',
                maxLines: 2,
              ),
              const SizedBox(height: 14),

              SaveButton(
                label: widget.existing != null ? 'Update Task →' : 'Add Task →',
                color: color,
                onTap: _save,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI PARSER + NLP PARSER
// ─────────────────────────────────────────────────────────────────────────────

class _ParsedTrip {
  final String title, emoji, walletId;
  final List<TripDestination> destinations;
  final String destination; // fallback flat string
  final TravelMode travelMode;
  final DateTime? startDate, endDate;
  final double? budget;
  final List<String> memberIds;

  const _ParsedTrip({
    required this.title,
    required this.emoji,
    required this.walletId,
    required this.destinations,
    required this.destination,
    required this.travelMode,
    this.startDate,
    this.endDate,
    this.budget,
    this.memberIds = const ['me'],
  });
}

class _TripClaudeParser {
  static const _apiKey = 'YOUR_ANTHROPIC_API_KEY';

  static Future<_ParsedTrip> parse(String text, String walletId) async {
    if (_apiKey == 'YOUR_ANTHROPIC_API_KEY') throw Exception('No API key');

    final now = DateTime.now();
    final today = now.toIso8601String().substring(0, 10);
    final prompt =
        '''
Extract trip/travel details from this text and return ONLY a JSON object:
{
  "title": "concise trip name",
  "emoji": "single best emoji for the trip",
  "destinations": ["destination 1", "destination 2"],
  "travelMode": "flight|train|car|bus|bike|ship|mixed",
  "startDate": "YYYY-MM-DD or null",
  "endDate": "YYYY-MM-DD or null",
  "budget": number or null,
  "memberIds": ["me"]
}

Today is $today. Return only raw JSON, no markdown.
User text: "$text"''';

    final client = HttpClient();
    try {
      final uri = Uri.parse('https://api.anthropic.com/v1/messages');
      final req = await client.postUrl(uri);
      req.headers
        ..set('x-api-key', _apiKey)
        ..set('anthropic-version', '2023-06-01')
        ..set('content-type', 'application/json');
      req.add(
        utf8.encode(
          jsonEncode({
            'model': 'claude-haiku-4-5-20251001',
            'max_tokens': 400,
            'messages': [
              {'role': 'user', 'content': prompt},
            ],
          }),
        ),
      );
      final res = await req.close().timeout(const Duration(seconds: 8));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) throw Exception('API ${res.statusCode}');

      final decoded = jsonDecode(body);
      final content = (decoded['content'] as List).first['text'] as String;
      final jsonStr = content
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      final destList = (data['destinations'] as List?)?.cast<String>() ?? [];
      final destinations = destList
          .asMap()
          .entries
          .map((e) => TripDestination(name: e.value, orderIndex: e.key))
          .toList();

      DateTime? start, end;
      try {
        if (data['startDate'] != null)
          start = DateTime.parse(data['startDate']);
      } catch (_) {}
      try {
        if (data['endDate'] != null) end = DateTime.parse(data['endDate']);
      } catch (_) {}

      const tm = {
        'flight': TravelMode.flight,
        'train': TravelMode.train,
        'car': TravelMode.car,
        'bus': TravelMode.bus,
        'bike': TravelMode.bike,
        'ship': TravelMode.ship,
        'mixed': TravelMode.mixed,
      };

      return _ParsedTrip(
        title: data['title'] as String,
        emoji: data['emoji'] as String? ?? '✈️',
        walletId: walletId,
        destinations: destinations,
        destination: destList.join(', '),
        travelMode: tm[data['travelMode']] ?? TravelMode.mixed,
        startDate: start,
        endDate: end,
        budget: (data['budget'] as num?)?.toDouble(),
        memberIds: (data['memberIds'] as List?)?.cast<String>() ?? ['me'],
      );
    } finally {
      client.close();
    }
  }
}

class _TripNlpParser {
  static _ParsedTrip parse(String raw, String walletId) {
    final text = raw.trim();
    final lower = text.toLowerCase();
    final now = DateTime.now();

    // ── Destinations ──────────────────────────────────────────────────────
    final placeKeywords = RegExp(
      r'\b(to|in|at|from|via|through)\s+([A-Z][a-zA-Z\s,]+?)(?=\s+(?:for|by|in|budget|\d|and\s+[A-Z])|$)',
    );
    final destMatches = placeKeywords.allMatches(text);
    final destNames = destMatches
        .map((m) => m.group(2)!.trim())
        .toSet()
        .toList();
    final destinations = destNames
        .asMap()
        .entries
        .map((e) => TripDestination(name: e.value, orderIndex: e.key))
        .toList();
    if (destinations.isEmpty) {
      final simple = RegExp(r'\b([A-Z][a-z]+(?: [A-Z][a-z]+)?)\b');
      final m2 = simple.firstMatch(text);
      if (m2 != null)
        destinations.add(TripDestination(name: m2.group(0)!, orderIndex: 0));
    }

    // ── Travel mode ───────────────────────────────────────────────────────
    TravelMode mode = TravelMode.mixed;
    if (lower.contains('flight') ||
        lower.contains('fly') ||
        lower.contains('air')) {
      mode = TravelMode.flight;
    } else if (lower.contains('train') || lower.contains('rail')) {
      mode = TravelMode.train;
    } else if (lower.contains(' car') ||
        lower.contains('drive') ||
        lower.contains('road')) {
      mode = TravelMode.car;
    } else if (lower.contains('bus')) {
      mode = TravelMode.bus;
    } else if (lower.contains('bike') || lower.contains('motor')) {
      mode = TravelMode.bike;
    } else if (lower.contains('ship') ||
        lower.contains('cruise') ||
        lower.contains('ferry')) {
      mode = TravelMode.ship;
    }

    // ── Dates ─────────────────────────────────────────────────────────────
    DateTime? start, end;
    final monthMap = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    for (final entry in monthMap.entries) {
      if (lower.contains(entry.key)) {
        start = DateTime(
          now.year + (now.month > entry.value ? 1 : 0),
          entry.value,
          1,
        );
        break;
      }
    }

    // ── Duration ─────────────────────────────────────────────────────────
    final durMatch = RegExp(r'(\d+)\s*(?:day|night)').firstMatch(lower);
    if (durMatch != null && start != null) {
      end = start.add(Duration(days: int.parse(durMatch.group(1)!)));
    }

    // ── Budget ────────────────────────────────────────────────────────────
    double? budget;
    final budMatch = RegExp(
      r'(?:budget|rs\.?|₹|inr)\s*(\d[\d,k]*)',
      caseSensitive: false,
    ).firstMatch(lower);
    if (budMatch != null) {
      final raw2 = budMatch.group(1)!.replaceAll(',', '').toLowerCase();
      budget = raw2.endsWith('k')
          ? double.tryParse(raw2.replaceAll('k', '')) != null
                ? double.parse(raw2.replaceAll('k', '')) * 1000
                : null
          : double.tryParse(raw2);
    }

    // ── Emoji ────────────────────────────────────────────────────────────
    String emoji = '✈️';
    if (mode == TravelMode.car) emoji = '🚗';
    if (mode == TravelMode.train) emoji = '🚆';
    if (mode == TravelMode.ship) emoji = '🚢';
    if (lower.contains('mountain') || lower.contains('hill')) emoji = '🏔️';
    if (lower.contains('beach') ||
        lower.contains('goa') ||
        lower.contains('coastal'))
      emoji = '🏖️';
    if (lower.contains('temple') || lower.contains('heritage')) emoji = '🛕';
    if (lower.contains('jungle') ||
        lower.contains('forest') ||
        lower.contains('coorg'))
      emoji = '🌿';

    final destStr = destinations.isNotEmpty
        ? destinations.map((d) => d.name).join(' & ')
        : 'Trip';

    return _ParsedTrip(
      title: 'Trip to $destStr',
      emoji: emoji,
      walletId: walletId,
      destinations: destinations,
      destination: destStr,
      travelMode: mode,
      startDate: start,
      endDate: end,
      budget: budget,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title, icon;
  const _SectionHeader({required this.title, required this.icon});
  @override
  Widget build(BuildContext context) {
    final sub = Theme.of(context).brightness == Brightness.dark
        ? AppColors.subDark
        : AppColors.subLight;
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            fontFamily: 'Nunito',
            color: sub,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

Color _statusColor(TripStatus s) {
  switch (s) {
    case TripStatus.planning:
      return const Color(0xFF4A9EFF);
    case TripStatus.confirmed:
      return AppColors.income;
    case TripStatus.ongoing:
      return AppColors.split;
    case TripStatus.completed:
      return AppColors.primary;
    case TripStatus.cancelled:
      return AppColors.expense;
  }
}

String _fmtK(double v) {
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
  return v.toStringAsFixed(0);
}

String _fmtDateRange(DateTime? start, DateTime? end) {
  if (start == null) return '–';
  final s = fmtDateShort(start);
  if (end == null) return s;
  return '$s – ${fmtDateShort(end)}';
}

String _fmtMsgTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inDays < 1) return '${diff.inHours}h';
  return fmtDateShort(dt);
}
