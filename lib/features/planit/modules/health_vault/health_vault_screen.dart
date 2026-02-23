import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/planit/planit_models.dart';
import '../../widgets/plan_widgets.dart';

class HealthVaultScreen extends StatefulWidget {
  final String walletId;
  const HealthVaultScreen({super.key, required this.walletId});
  @override
  State<HealthVaultScreen> createState() => _HealthVaultScreenState();
}

class _HealthVaultScreenState extends State<HealthVaultScreen> {
  final List<HealthMemberProfile> _profiles = List.from(mockHealthProfiles);
  int _selectedProfile = 0;

  HealthMemberProfile get _active => _profiles[_selectedProfile];

  PlanMember _memberFor(String id) => mockMembers.firstWhere(
    (m) => m.id == id,
    orElse: () => const PlanMember(id: '?', name: '?', emoji: '👤'),
  );

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
            Text('🏥', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'Health Vault',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            onPressed: () => _showAddProfileSheet(context, isDark, surfBg),
            tooltip: 'Add member',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddRecordSheet(context, isDark, surfBg),
        backgroundColor: const Color(0xFFFF7043),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Record',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Member selector strip
          Container(
            color: cardBg,
            height: 76,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _profiles.length,
              itemBuilder: (_, i) {
                final m = _memberFor(_profiles[i].memberId);
                final sel = _selectedProfile == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedProfile = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFFFF7043).withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: sel
                            ? const Color(0xFFFF7043)
                            : (isDark
                                  ? AppColors.surfDark
                                  : const Color(0xFFE0E0EC)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(m.emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 6),
                        Text(
                          m.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: sel ? const Color(0xFFFF7043) : tc,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Profile summary card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF7043), Color(0xFFFF5C7A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _memberFor(_active.memberId).emoji,
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _memberFor(_active.memberId).name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          _Pill(label: '🩸 ${_active.bloodGroup}'),
                          if (_active.allergies != null)
                            _Pill(label: '⚠️ ${_active.allergies}'),
                          if (_active.chronicConditions != null)
                            _Pill(label: '💊 ${_active.chronicConditions}'),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_active.records.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'DM Mono',
                      ),
                    ),
                    const Text(
                      'records',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontFamily: 'Nunito',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Records header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Health Records',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Nunito',
                    color: tc,
                  ),
                ),
                Text(
                  '${_active.records.length} total',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Nunito',
                    color: sub,
                  ),
                ),
              ],
            ),
          ),

          // Records list
          Expanded(
            child: _active.records.isEmpty
                ? PlanEmptyState(
                    emoji: '📋',
                    title: 'No records yet',
                    subtitle:
                        'Add prescriptions, reports, vaccinations and more',
                    buttonLabel: 'Add Record',
                    onButton: () =>
                        _showAddRecordSheet(context, isDark, surfBg),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: _active.records.length,
                    itemBuilder: (_, i) {
                      final r = _active.records[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SwipeTile(
                          onDelete: () => setState(
                            () => _active.records.removeWhere(
                              (x) => x.id == r.id,
                            ),
                          ),
                          child: _RecordCard(
                            record: r,
                            isDark: isDark,
                            onTap: () => _showRecordDetail(context, r, isDark),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddProfileSheet(BuildContext context, bool isDark, Color surfBg) {
    showPlanSheet(
      context,
      child: _AddProfileSheet(
        isDark: isDark,
        surfBg: surfBg,
        onSave: (p) {
          setState(() => _profiles.add(p));
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showAddRecordSheet(BuildContext context, bool isDark, Color surfBg) {
    showPlanSheet(
      context,
      child: _AddRecordSheet(
        isDark: isDark,
        surfBg: surfBg,
        onSave: (r) {
          setState(() => _active.records.insert(0, r));
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showRecordDetail(BuildContext context, HealthRecord r, bool isDark) {
    showPlanSheet(
      context,
      child: _RecordDetailSheet(
        record: r,
        isDark: isDark,
        onDelete: () {
          setState(() => _active.records.removeWhere((x) => x.id == r.id));
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  const _Pill({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white24,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        fontFamily: 'Nunito',
      ),
    ),
  );
}

class _RecordCard extends StatelessWidget {
  final HealthRecord record;
  final bool isDark;
  final VoidCallback onTap;
  const _RecordCard({
    required this.record,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final c = record.type.color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: c.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                record.type.emoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: tc,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: c.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          record.type.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                            color: c,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        fmtDateShort(record.date),
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'Nunito',
                          color: sub,
                        ),
                      ),
                    ],
                  ),
                  if (record.doctor != null || record.hospital != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (record.doctor != null) '👨‍⚕️ ${record.doctor}',
                        if (record.hospital != null) '🏥 ${record.hospital}',
                      ].join('  '),
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'Nunito',
                        color: sub,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (record.tags.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: record.tags
                    .take(2)
                    .map(
                      (t) => Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          t,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecordDetailSheet extends StatelessWidget {
  final HealthRecord record;
  final bool isDark;
  final VoidCallback onDelete;
  const _RecordDetailSheet({
    required this.record,
    required this.isDark,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final c = record.type.color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: c.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  record.type.emoji,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: c.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        record.type.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: c,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InfoRow(
            icon: Icons.calendar_today_rounded,
            label: fmtDate(record.date),
          ),
          if (record.doctor != null)
            InfoRow(icon: Icons.person_rounded, label: record.doctor!),
          if (record.hospital != null)
            InfoRow(
              icon: Icons.local_hospital_rounded,
              label: record.hospital!,
            ),
          if (record.notes != null)
            InfoRow(icon: Icons.notes_rounded, label: record.notes!),
          if (record.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: record.tags
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        t,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '✏️ Edit',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.expense.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.expense.withOpacity(0.3),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.expense,
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

class _AddRecordSheet extends StatefulWidget {
  final bool isDark;
  final Color surfBg;
  final void Function(HealthRecord) onSave;
  const _AddRecordSheet({
    required this.isDark,
    required this.surfBg,
    required this.onSave,
  });
  @override
  State<_AddRecordSheet> createState() => _AddRecordSheetState();
}

class _AddRecordSheetState extends State<_AddRecordSheet> {
  final _titleCtrl = TextEditingController();
  final _docCtrl = TextEditingController();
  final _hospCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  HealthRecordType _type = HealthRecordType.prescription;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _docCtrl.dispose();
    _hospCtrl.dispose();
    _notesCtrl.dispose();
    _tagsCtrl.dispose();
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
            'Add Health Record',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFamily: 'Nunito',
              color: tc,
            ),
          ),
          const SizedBox(height: 16),

          const SheetLabel(text: 'RECORD TYPE'),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: HealthRecordType.values
                  .map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _type = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _type == t
                                ? t.color.withOpacity(0.18)
                                : widget.surfBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: _type == t ? t.color : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            '${t.emoji} ${t.label}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Nunito',
                              color: _type == t ? t.color : sub,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),

          PlanInputField(controller: _titleCtrl, hint: 'Record title *'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: PlanInputField(
                  controller: _docCtrl,
                  hint: 'Doctor name',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PlanInputField(
                  controller: _hospCtrl,
                  hint: 'Hospital / clinic',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          PlanInputField(
            controller: _notesCtrl,
            hint: 'Notes / findings',
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          PlanInputField(controller: _tagsCtrl, hint: 'Tags (comma separated)'),
          const SizedBox(height: 14),

          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(1950),
                lastDate: DateTime.now(),
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
                    color: Color(0xFFFF7043),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Date: ${fmtDate(_date)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Nunito',
                      color: Color(0xFFFF7043),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          SaveButton(
            label: 'Save Record',
            color: const Color(0xFFFF7043),
            onTap: () {
              if (_titleCtrl.text.trim().isEmpty) return;
              final tags = _tagsCtrl.text.trim().isEmpty
                  ? <String>[]
                  : _tagsCtrl.text
                        .split(',')
                        .map((t) => t.trim())
                        .where((t) => t.isNotEmpty)
                        .toList();
              widget.onSave(
                HealthRecord(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: _titleCtrl.text.trim(),
                  type: _type,
                  date: _date,
                  doctor: _docCtrl.text.trim().isEmpty
                      ? null
                      : _docCtrl.text.trim(),
                  hospital: _hospCtrl.text.trim().isEmpty
                      ? null
                      : _hospCtrl.text.trim(),
                  notes: _notesCtrl.text.trim().isEmpty
                      ? null
                      : _notesCtrl.text.trim(),
                  tags: tags,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AddProfileSheet extends StatefulWidget {
  final bool isDark;
  final Color surfBg;
  final void Function(HealthMemberProfile) onSave;
  const _AddProfileSheet({
    required this.isDark,
    required this.surfBg,
    required this.onSave,
  });
  @override
  State<_AddProfileSheet> createState() => _AddProfileSheetState();
}

class _AddProfileSheetState extends State<_AddProfileSheet> {
  String _memberId = 'me';
  final _bloodCtrl = TextEditingController();
  final _allergyCtrl = TextEditingController();
  final _condCtrl = TextEditingController();

  @override
  void dispose() {
    _bloodCtrl.dispose();
    _allergyCtrl.dispose();
    _condCtrl.dispose();
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
            'Add Member Profile',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFamily: 'Nunito',
              color: tc,
            ),
          ),
          const SizedBox(height: 16),

          const SheetLabel(text: 'SELECT MEMBER'),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: mockMembers
                  .map(
                    (m) => GestureDetector(
                      onTap: () => setState(() => _memberId = m.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _memberId == m.id
                              ? const Color(0xFFFF7043).withOpacity(0.15)
                              : widget.surfBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _memberId == m.id
                                ? const Color(0xFFFF7043)
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
          const SizedBox(height: 14),

          PlanInputField(
            controller: _bloodCtrl,
            hint: 'Blood group (e.g. O+, AB-)',
          ),
          const SizedBox(height: 8),
          PlanInputField(
            controller: _allergyCtrl,
            hint: 'Known allergies (optional)',
          ),
          const SizedBox(height: 8),
          PlanInputField(
            controller: _condCtrl,
            hint: 'Chronic conditions (optional)',
          ),
          const SizedBox(height: 20),

          SaveButton(
            label: 'Create Profile',
            color: const Color(0xFFFF7043),
            onTap: () {
              widget.onSave(
                HealthMemberProfile(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  memberId: _memberId,
                  bloodGroup: _bloodCtrl.text.trim().isEmpty
                      ? 'Unknown'
                      : _bloodCtrl.text.trim(),
                  allergies: _allergyCtrl.text.trim().isEmpty
                      ? null
                      : _allergyCtrl.text.trim(),
                  chronicConditions: _condCtrl.text.trim().isEmpty
                      ? null
                      : _condCtrl.text.trim(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
