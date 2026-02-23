import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';
import '../../widgets/plan_widgets.dart';

class PlanPartyScreen extends StatefulWidget {
  final String walletId;
  const PlanPartyScreen({super.key, required this.walletId});
  @override
  State<PlanPartyScreen> createState() => _PlanPartyScreenState();
}

class _PlanPartyScreenState extends State<PlanPartyScreen> {
  final List<PartyModel> _parties = List.from(mockParties);
  List<PartyModel> get _filtered =>
      _parties.where((p) => p.walletId == widget.walletId).toList();

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
            Text('🎉', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'Plan the Party',
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
        onPressed: () => _showAddSheet(context, isDark, surfBg),
        backgroundColor: AppColors.expense,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'New Event',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
          ),
        ),
      ),
      body: _filtered.isEmpty
          ? const PlanEmptyState(
              emoji: '🎉',
              title: 'No events yet',
              subtitle: 'Plan your next celebration',
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _filtered.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _PartyCard(
                  party: _filtered[i],
                  isDark: isDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _PartyDetail(
                        party: _filtered[i],
                        isDark: isDark,
                        onUpdate: () => setState(() {}),
                        onDelete: () {
                          setState(() => _parties.remove(_filtered[i]));
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  void _showAddSheet(BuildContext ctx, bool isDark, Color surfBg) {
    showPlanSheet(
      ctx,
      child: _AddPartySheet(
        isDark: isDark,
        surfBg: surfBg,
        walletId: widget.walletId,
        onSave: (p) {
          setState(() => _parties.add(p));
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────

class _PartyCard extends StatelessWidget {
  final PartyModel party;
  final bool isDark;
  final VoidCallback onTap;
  const _PartyCard({
    required this.party,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final done = party.tasks.where((t) => t.done).length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.expense.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.expense,
                    AppColors.expense.withOpacity(0.75),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
              ),
              child: Row(
                children: [
                  Text(party.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          party.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Nunito',
                          ),
                        ),
                        if (party.eventDate != null)
                          Text(
                            '📅 ${fmtDate(party.eventDate!)}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontFamily: 'Nunito',
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (party.eventDate != null)
                    Text(
                      daysUntil(party.eventDate!),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Nunito',
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  if (party.venue != null)
                    Expanded(
                      child: InfoRow(
                        icon: Icons.location_on_rounded,
                        label: party.venue!,
                      ),
                    ),
                  Text(
                    '${party.guestIds.length} guests  •  $done/${party.tasks.length} tasks',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'Nunito',
                      color: sub,
                    ),
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

// ── Detail screen ─────────────────────────────────────────────────────────────

class _PartyDetail extends StatefulWidget {
  final PartyModel party;
  final bool isDark;
  final VoidCallback onUpdate, onDelete;
  const _PartyDetail({
    required this.party,
    required this.isDark,
    required this.onUpdate,
    required this.onDelete,
  });
  @override
  State<_PartyDetail> createState() => _PartyDetailState();
}

class _PartyDetailState extends State<_PartyDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _msgCtrl = TextEditingController();
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final p = widget.party;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        title: Text(
          p.title,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            fontFamily: 'Nunito',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.expense,
            ),
            onPressed: widget.onDelete,
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
            fontSize: 11,
          ),
          indicatorColor: AppColors.expense,
          labelColor: AppColors.expense,
          unselectedLabelColor: sub,
          tabs: const [
            Tab(text: 'Info'),
            Tab(text: 'Tasks'),
            Tab(text: 'Vendors'),
            Tab(text: 'Chat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // INFO
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p.eventDate != null)
                  InfoRow(
                    icon: Icons.calendar_today_rounded,
                    label: fmtDate(p.eventDate!),
                  ),
                if (p.venue != null)
                  InfoRow(icon: Icons.location_on_rounded, label: p.venue!),
                if (p.address != null)
                  InfoRow(icon: Icons.map_rounded, label: p.address!),
                if (p.budget != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Budget',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                          color: tc,
                        ),
                      ),
                      Text(
                        '₹${p.spent.toStringAsFixed(0)} / ₹${p.budget!.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'DM Mono',
                          color: AppColors.expense,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: (p.spent / p.budget!).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: AppColors.expense.withOpacity(0.12),
                      color: AppColors.expense,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  'Guests',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    color: tc,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: p.guestIds.map((id) {
                    final m = mockMembers.firstWhere(
                      (x) => x.id == id,
                      orElse: () =>
                          const PlanMember(id: '?', name: '?', emoji: '👤'),
                    );
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.expense.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(m.emoji, style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 5),
                          Text(
                            m.name,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Nunito',
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // TASKS
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: p.tasks.length,
            itemBuilder: (_, i) {
              final t = p.tasks[i];
              final m = mockMembers.firstWhere(
                (x) => x.id == t.assignedTo,
                orElse: () => const PlanMember(id: '?', name: '?', emoji: '👤'),
              );
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => t.done = !t.done),
                      child: Icon(
                        t.done
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: t.done ? AppColors.income : AppColors.expense,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
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
                          if (t.update != null)
                            Text(
                              '💬 ${t.update}',
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'Nunito',
                                color: sub,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(m.emoji, style: const TextStyle(fontSize: 18)),
                  ],
                ),
              );
            },
          ),

          // VENDORS
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: p.contractors.length,
            itemBuilder: (_, i) {
              final c = p.contractors[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: c.confirmed
                        ? AppColors.income.withOpacity(0.25)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.expense.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        c.confirmed ? '✅' : '🤝',
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: tc,
                            ),
                          ),
                          Text(
                            c.role,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Nunito',
                              color: sub,
                            ),
                          ),
                          if (c.phone != null)
                            Row(
                              children: [
                                const Icon(
                                  Icons.phone_rounded,
                                  size: 11,
                                  color: AppColors.income,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  c.phone!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'Nunito',
                                    color: AppColors.income,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    if (c.quotedAmount != null)
                      Text(
                        '₹${(c.quotedAmount! / 1000).toStringAsFixed(1)}K',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'DM Mono',
                          color: AppColors.expense,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // CHAT
          Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: p.messages.map((m) {
                    final isMe = m.senderId == 'me';
                    final sender = mockMembers.firstWhere(
                      (x) => x.id == m.senderId,
                      orElse: () =>
                          const PlanMember(id: '?', name: '?', emoji: '👤'),
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          if (!isMe) ...[
                            CircleAvatar(
                              child: Text(
                                sender.emoji,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isMe ? AppColors.expense : surfBg,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                                  bottomRight: Radius.circular(isMe ? 4 : 18),
                                ),
                              ),
                              child: Text(
                                m.text,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'Nunito',
                                  color: isMe ? Colors.white : tc,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: surfBg,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: TextField(
                          controller: _msgCtrl,
                          style: TextStyle(
                            fontSize: 13,
                            color: tc,
                            fontFamily: 'Nunito',
                          ),
                          decoration: InputDecoration.collapsed(
                            hintText: 'Message everyone…',
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: sub,
                              fontFamily: 'Nunito',
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        if (_msgCtrl.text.trim().isEmpty) return;
                        setState(() {
                          p.messages.add(
                            PartyMessage(
                              id: DateTime.now().millisecondsSinceEpoch
                                  .toString(),
                              senderId: 'me',
                              text: _msgCtrl.text.trim(),
                              at: DateTime.now(),
                            ),
                          );
                          _msgCtrl.clear();
                        });
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: AppColors.expense,
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
            ],
          ),
        ],
      ),
    );
  }
}

// ── Add party sheet ───────────────────────────────────────────────────────────

class _AddPartySheet extends StatefulWidget {
  final bool isDark;
  final Color surfBg;
  final String walletId;
  final void Function(PartyModel) onSave;
  const _AddPartySheet({
    required this.isDark,
    required this.surfBg,
    required this.walletId,
    required this.onSave,
  });
  @override
  State<_AddPartySheet> createState() => _AddPartySheetState();
}

class _AddPartySheetState extends State<_AddPartySheet> {
  final _titleCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  DateTime? _date;
  List<String> _guests = ['me'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _venueCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final sub = widget.isDark ? AppColors.subDark : AppColors.subLight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'New Event',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFamily: 'Nunito',
              color: tc,
            ),
          ),
          const SizedBox(height: 16),
          PlanInputField(controller: _titleCtrl, hint: 'Event name *'),
          const SizedBox(height: 8),
          PlanInputField(controller: _venueCtrl, hint: 'Venue / Location'),
          const SizedBox(height: 8),
          PlanInputField(
            controller: _budgetCtrl,
            hint: 'Budget (₹)',
            inputType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 14)),
                firstDate: DateTime.now(),
                lastDate: DateTime(2100),
              );
              if (d != null) setState(() => _date = d);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: widget.surfBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: AppColors.expense,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _date != null ? fmtDate(_date!) : 'Event date',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Nunito',
                      color: AppColors.expense,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SheetLabel(text: 'INVITE'),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: mockMembers
                  .map(
                    (m) => GestureDetector(
                      onTap: () => setState(
                        () => _guests.contains(m.id)
                            ? _guests.remove(m.id)
                            : _guests.add(m.id),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _guests.contains(m.id)
                              ? AppColors.expense.withOpacity(0.15)
                              : widget.surfBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _guests.contains(m.id)
                                ? AppColors.expense
                                : Colors.transparent,
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
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
          SaveButton(
            label: 'Create Event',
            color: AppColors.expense,
            onTap: () {
              if (_titleCtrl.text.trim().isEmpty) return;
              widget.onSave(
                PartyModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: _titleCtrl.text.trim(),
                  emoji: '🎉',
                  walletId: widget.walletId,
                  eventDate: _date,
                  venue: _venueCtrl.text.trim().isEmpty
                      ? null
                      : _venueCtrl.text.trim(),
                  budget: double.tryParse(_budgetCtrl.text.trim()),
                  guestIds: _guests,
                  contractors: [],
                  tasks: [],
                  messages: [],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
