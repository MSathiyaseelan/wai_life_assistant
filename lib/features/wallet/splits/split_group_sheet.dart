import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wai_life_assistant/data/models/wallet/split_group_models.dart';
import '../../../../core/theme/app_theme.dart';

class SplitGroupSheet extends StatefulWidget {
  final SplitGroup? existing;
  final String walletId;
  final void Function(SplitGroup) onSave;
  final VoidCallback? onDelete;

  const SplitGroupSheet({
    super.key,
    this.existing,
    required this.walletId,
    required this.onSave,
    this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    SplitGroup? existing,
    required String walletId,
    required void Function(SplitGroup) onSave,
    VoidCallback? onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SplitGroupSheet(
        existing: existing,
        walletId: walletId,
        onSave: onSave,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<SplitGroupSheet> createState() => _SplitGroupSheetState();
}

class _SplitGroupSheetState extends State<SplitGroupSheet>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  String _emoji = '👥';
  final List<SplitParticipant> _participants = [];
  late TabController _addTab;

  static const _mockContacts = [
    ('Priya', '👧', '9876543212'),
    ('Rahul', '👨', '9876500001'),
    ('Sneha', '👩', '9876500002'),
    ('Dad', '👨', '9876543210'),
    ('Mom', '👩', '9876543211'),
    ('Karthik', '🧑', '9876600001'),
    ('Ananya', '👧', '9876600002'),
  ];

  static const _groupEmojis = [
    '👥',
    '✈️',
    '🍱',
    '🎉',
    '🏖️',
    '🏕️',
    '🎓',
    '🏠',
    '🎬',
    '🛒',
    '💼',
    '🎮',
    '⚽',
    '🎸',
    '🍕',
    '☕',
    '🚗',
    '🎂',
    '🏋️',
    '🎯',
  ];
  static const _avatarEmojis = ['🧑', '👨', '👩', '👧', '👦', '🧔', '👱', '🧓'];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _addTab = TabController(length: 2, vsync: this);
    _addTab.addListener(() => setState(() {}));
    if (_isEdit) {
      _nameCtrl.text = widget.existing!.name;
      _emoji = widget.existing!.emoji;
      _participants.addAll(
        widget.existing!.participants.map(
          (p) => SplitParticipant(
            id: p.id,
            name: p.name,
            emoji: p.emoji,
            phone: p.phone,
            isMe: p.isMe,
          ),
        ),
      );
    } else {
      _participants.add(
        SplitParticipant(id: 'me', name: 'Me (Arjun)', emoji: '🧑', isMe: true),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addTab.dispose();
    super.dispose();
  }

  bool _alreadyAdded(String? phone, String name) {
    if (phone != null && phone.isNotEmpty)
      return _participants.any((p) => p.phone == phone);
    return _participants.any((p) => p.name.toLowerCase() == name.toLowerCase());
  }

  void _addFromContact((String, String, String) c) {
    if (_alreadyAdded(c.$3, c.$1)) return;
    setState(
      () => _participants.add(
        SplitParticipant(id: 'c_${c.$3}', name: c.$1, emoji: c.$2, phone: c.$3),
      ),
    );
  }

  void _addManual(String name, String emoji, String phone) {
    if (name.isEmpty || _alreadyAdded(phone.isEmpty ? null : phone, name))
      return;
    setState(
      () => _participants.add(
        SplitParticipant(
          id: 'u_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          emoji: emoji,
          phone: phone.isEmpty ? null : phone,
        ),
      ),
    );
  }

  void _remove(SplitParticipant p) {
    if (p.isMe) return;
    setState(() => _participants.remove(p));
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _participants.length < 2) return;
    HapticFeedback.mediumImpact();
    final group = SplitGroup(
      id: _isEdit
          ? widget.existing!.id
          : 'sg_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      emoji: _emoji,
      walletId: widget.walletId,
      participants: List.from(_participants),
      transactions: widget.existing?.transactions,
      messages: widget.existing?.messages,
      createdAt: widget.existing?.createdAt,
    );
    widget.onSave(group);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
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
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  Text(
                    _isEdit ? '✏️  Edit Group' : '➕  New Split Group',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                      color: tc,
                    ),
                  ),
                  const Spacer(),
                  if (_isEdit && widget.onDelete != null)
                    GestureDetector(
                      onTap: _confirmDelete,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.expense.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.expense.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: AppColors.expense,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Emoji + name row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => _pickEmoji(isDark, surfBg),
                          child: Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: AppColors.split.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.split.withOpacity(0.35),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _emoji,
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _nameCtrl,
                            onChanged: (_) => setState(() {}),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Nunito',
                              color: tc,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Group name e.g. Goa Trip',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Nunito',
                                color: sub,
                              ),
                              filled: true,
                              fillColor: surfBg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Participants
                    _lbl('PARTICIPANTS (${_participants.length})', sub),
                    const SizedBox(height: 8),
                    ..._participants.map(
                      (p) => _buildParticipantTile(p, surfBg, tc, sub),
                    ),
                    if (_participants.length < 2)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 2),
                        child: Text(
                          'Add at least 1 more person to create the group',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Nunito',
                            color: AppColors.expense,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Add participant panel
                    _buildAddPanel(isDark, surfBg, tc, sub),
                    const SizedBox(height: 24),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed:
                            _nameCtrl.text.trim().isNotEmpty &&
                                _participants.length >= 2
                            ? _save
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.split,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _isEdit ? 'Save Changes' : 'Create Group',
                          style: const TextStyle(
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

  Widget _buildParticipantTile(
    SplitParticipant p,
    Color surfBg,
    Color tc,
    Color sub,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(12),
        border: p.isMe
            ? Border.all(color: AppColors.split.withOpacity(0.4))
            : null,
      ),
      child: Row(
        children: [
          Text(p.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      p.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                    if (p.isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.split.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'You',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: AppColors.split,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (p.phone != null)
                  Text(
                    p.phone!,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Nunito',
                      color: sub,
                    ),
                  ),
              ],
            ),
          ),
          if (!p.isMe)
            GestureDetector(
              onTap: () => _remove(p),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.expense.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.remove_rounded,
                  color: AppColors.expense,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddPanel(bool isDark, Color surfBg, Color tc, Color sub) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.split.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab switcher inside panel
          Container(
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: surfBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _addTab,
              isScrollable: false,
              indicator: BoxDecoration(
                color: AppColors.split,
                borderRadius: BorderRadius.circular(10),
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
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                fontFamily: 'Nunito',
              ),
              padding: EdgeInsets.zero,
              tabs: const [
                Tab(
                  height: 36,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [Text('📱 '), Text('Contacts')],
                  ),
                ),
                Tab(
                  height: 36,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [Text('✏️ '), Text('Manual')],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: _addTab.index == 0
                ? _buildContacts(surfBg, tc, sub)
                : _buildManual(surfBg, tc, sub),
          ),
        ],
      ),
    );
  }

  Widget _buildContacts(Color surfBg, Color tc, Color sub) {
    return Column(
      children: _mockContacts.map((c) {
        final added = _alreadyAdded(c.$3, c.$1);
        return GestureDetector(
          onTap: added
              ? null
              : () {
                  _addFromContact(c);
                  setState(() {});
                },
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: added ? surfBg.withOpacity(0.5) : surfBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(c.$2, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.$1,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: tc,
                        ),
                      ),
                      Text(
                        c.$3,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Nunito',
                          color: sub,
                        ),
                      ),
                    ],
                  ),
                ),
                added
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.income.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Added',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: AppColors.income,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.add_circle_rounded,
                        color: AppColors.split,
                        size: 22,
                      ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // Manual entry state
  String _manualEmoji = '🧑';
  final _manualNameCtrl = TextEditingController();
  final _manualPhoneCtrl = TextEditingController();

  Widget _buildManual(Color surfBg, Color tc, Color sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _lbl('AVATAR', sub),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _avatarEmojis
                .map(
                  (e) => GestureDetector(
                    onTap: () => setState(() => _manualEmoji = e),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 46,
                      height: 46,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: _manualEmoji == e
                            ? AppColors.split.withOpacity(0.15)
                            : surfBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _manualEmoji == e
                              ? AppColors.split
                              : Colors.transparent,
                          width: 2,
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
        _field(_manualNameCtrl, 'Name', surfBg, tc),
        const SizedBox(height: 8),
        _field(
          _manualPhoneCtrl,
          'Phone number (optional)',
          surfBg,
          tc,
          inputType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              final n = _manualNameCtrl.text.trim();
              if (n.isEmpty) return;
              _addManual(n, _manualEmoji, _manualPhoneCtrl.text.trim());
              _manualNameCtrl.clear();
              _manualPhoneCtrl.clear();
              setState(() {});
            },
            icon: const Icon(Icons.person_add_rounded, size: 16),
            label: const Text(
              'Add Person',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.split,
              side: BorderSide(color: AppColors.split.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _pickEmoji(bool isDark, Color surfBg) {
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Group Icon',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _groupEmojis
                  .map(
                    (e) => GestureDetector(
                      onTap: () {
                        setState(() => _emoji = e);
                        Navigator.pop(context);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _emoji == e
                              ? AppColors.split.withOpacity(0.15)
                              : surfBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _emoji == e
                                ? AppColors.split
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(e, style: const TextStyle(fontSize: 26)),
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

  void _confirmDelete() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Group?',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        content: const Text(
          'This will permanently remove the group, all transactions and messages.',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              widget.onDelete?.call();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.expense,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Delete',
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

  Widget _lbl(String t, Color c) => Text(
    t,
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.8,
      fontFamily: 'Nunito',
      color: c,
    ),
  );

  Widget _field(
    TextEditingController c,
    String hint,
    Color surfBg,
    Color tc, {
    TextInputType? inputType,
  }) => TextField(
    controller: c,
    keyboardType: inputType,
    onChanged: (_) => setState(() {}),
    style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: tc),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: 12,
        color: AppColors.subLight,
      ),
      filled: true,
      fillColor: surfBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    ),
  );
}
