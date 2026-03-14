import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:wai_life_assistant/core/supabase/profile_service.dart';
import 'package:wai_life_assistant/core/widgets/emoji_or_image.dart';
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
  String? _groupPhotoPath; // local path when user picks from gallery/camera
  bool _saving = false;

  final List<SplitParticipant> _participants = [];
  late TabController _addTab;

  // Contacts
  List<(String, String, String)>? _contacts; // (name, emoji, phone)
  bool _contactsLoading = false;
  final _contactSearchCtrl = TextEditingController();
  String _contactSearch = '';

  static const _groupEmojis = [
    '👥', '✈️', '🍱', '🎉', '🏖️', '🏕️', '🎓', '🏠', '🎬', '🛒',
    '💼', '🎮', '⚽', '🎸', '🍕', '☕', '🚗', '🎂', '🏋️', '🎯',
  ];
  static const _avatarEmojis = ['🧑', '👨', '👩', '👧', '👦', '🧔', '👱', '🧓'];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _addTab = TabController(length: 2, vsync: this);
    _addTab.addListener(() {
      setState(() {});
      // Load contacts the first time the Contacts tab is shown
      if (_addTab.index == 0 && _contacts == null && !_contactsLoading) {
        _loadContacts();
      }
    });
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
        SplitParticipant(id: 'me', name: 'Me', emoji: '🧑', isMe: true),
      );
    }
    // Pre-load contacts immediately so they're ready when tab opens
    _loadContacts();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addTab.dispose();
    _manualNameCtrl.dispose();
    _manualPhoneCtrl.dispose();
    _contactSearchCtrl.dispose();
    super.dispose();
  }

  // ── Contacts ──────────────────────────────────────────────────────────────

  Future<void> _loadContacts() async {
    if (_contactsLoading) return;
    setState(() => _contactsLoading = true);
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        if (mounted) setState(() { _contacts = []; _contactsLoading = false; });
        return;
      }
      final raw = await FlutterContacts.getContacts(withProperties: true);
      final result = <(String, String, String)>[];
      for (final c in raw) {
        if (c.displayName.isEmpty) continue;
        final phone = c.phones.isNotEmpty
            ? c.phones.first.normalizedNumber.isNotEmpty
                ? c.phones.first.normalizedNumber
                : c.phones.first.number
            : '';
        result.add((c.displayName, '🧑', phone));
      }
      result.sort((a, b) => a.$1.toLowerCase().compareTo(b.$1.toLowerCase()));
      if (mounted) setState(() { _contacts = result; _contactsLoading = false; });
    } catch (e) {
      debugPrint('[Contacts] $e');
      if (mounted) setState(() { _contacts = []; _contactsLoading = false; });
    }
  }

  // ── Participants ──────────────────────────────────────────────────────────

  bool _alreadyAdded(String? phone, String name) {
    if (phone != null && phone.isNotEmpty)
      return _participants.any((p) => p.phone == phone);
    return _participants.any((p) => p.name.toLowerCase() == name.toLowerCase());
  }

  void _addFromContact((String, String, String) c) {
    if (_alreadyAdded(c.$3, c.$1)) return;
    setState(() => _participants.add(
      SplitParticipant(
        id: 'c_${c.$3.isNotEmpty ? c.$3 : c.$1}',
        name: c.$1,
        emoji: c.$2,
        phone: c.$3.isNotEmpty ? c.$3 : null,
      ),
    ));
  }

  void _addManual(String name, String emoji, String phone) {
    if (name.isEmpty || _alreadyAdded(phone.isEmpty ? null : phone, name))
      return;
    setState(() => _participants.add(
      SplitParticipant(
        id: 'u_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        emoji: emoji,
        phone: phone.isEmpty ? null : phone,
      ),
    ));
  }

  void _remove(SplitParticipant p) {
    if (p.isMe) return;
    setState(() => _participants.remove(p));
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _participants.length < 2) return;
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);

    String finalEmoji = _emoji;

    // Upload group photo if one was picked
    if (_groupPhotoPath != null) {
      try {
        finalEmoji = await ProfileService.instance.uploadPhoto(
          localPath: _groupPhotoPath!,
          folder: 'splits',
          name: 'sg_${DateTime.now().millisecondsSinceEpoch}',
        );
      } catch (e) {
        debugPrint('[Photo upload] $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Photo upload failed: $e'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ));
        }
        finalEmoji = _emoji; // fallback to current emoji
      }
    }

    final group = SplitGroup(
      id: _isEdit
          ? widget.existing!.id
          : 'sg_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      emoji: finalEmoji,
      walletId: widget.walletId,
      participants: List.from(_participants),
      transactions: widget.existing?.transactions,
      messages: widget.existing?.messages,
      createdAt: widget.existing?.createdAt,
    );

    if (mounted) {
      widget.onSave(group);
      Navigator.pop(context);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    final canSave = _nameCtrl.text.trim().isNotEmpty && _participants.length >= 2;

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
                  color: Colors.grey.withValues(alpha: 0.3),
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
                          horizontal: 10, vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.expense.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.expense.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
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
                    // Icon + name row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => _pickGroupIcon(isDark, surfBg),
                          child: Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: AppColors.split.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.split.withValues(alpha: 0.35),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: EmojiOrImage(
                                value: _groupPhotoPath ?? _emoji,
                                size: 34,
                                borderRadius: 14,
                              ),
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
                                horizontal: 14, vertical: 16,
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
                        onPressed: (canSave && !_saving) ? _save : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.split,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white,
                                ),
                              )
                            : Text(
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

  // ── Participant tile ───────────────────────────────────────────────────────

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
            ? Border.all(color: AppColors.split.withValues(alpha: 0.4))
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
                          horizontal: 6, vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.split.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
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
                      fontSize: 11, fontFamily: 'Nunito', color: sub,
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
                  color: AppColors.expense.withValues(alpha: 0.08),
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

  // ── Add participant panel ──────────────────────────────────────────────────

  Widget _buildAddPanel(bool isDark, Color surfBg, Color tc, Color sub) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.split.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

  // ── Contacts tab ───────────────────────────────────────────────────────────

  Widget _buildContacts(Color surfBg, Color tc, Color sub) {
    if (_contactsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.split),
        ),
      );
    }

    final all = _contacts ?? [];

    if (all.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            const Text('📵', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              _contacts == null
                  ? 'Loading contacts…'
                  : 'No contacts found or permission denied',
              style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub),
              textAlign: TextAlign.center,
            ),
            if (_contacts != null && _contacts!.isEmpty) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: _loadContacts,
                child: const Text(
                  'Grant Permission',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    color: AppColors.split,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final query = _contactSearch.toLowerCase();
    final list = query.isEmpty
        ? all
        : all
            .where((c) =>
                c.$1.toLowerCase().contains(query) ||
                c.$3.contains(query))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search field
        const SizedBox(height: 6),
        TextField(
          controller: _contactSearchCtrl,
          onChanged: (v) => setState(() => _contactSearch = v),
          style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: tc),
          decoration: InputDecoration(
            hintText: 'Search contacts…',
            hintStyle: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: sub),
            prefixIcon: Icon(Icons.search_rounded, size: 18, color: sub),
            suffixIcon: _contactSearch.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _contactSearchCtrl.clear();
                      setState(() => _contactSearch = '');
                    },
                    child: Icon(Icons.close_rounded, size: 16, color: sub),
                  )
                : null,
            filled: true,
            fillColor: surfBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
        const SizedBox(height: 6),
        // Fixed-height scrollable list
        SizedBox(
          height: 240,
          child: list.isEmpty
              ? Center(
                  child: Text(
                    'No results for "$_contactSearch"',
                    style: TextStyle(
                      fontSize: 12, fontFamily: 'Nunito', color: sub,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final c = list[i];
                    final added = _alreadyAdded(c.$3, c.$1);
                    return GestureDetector(
                      onTap: added ? null : () => _addFromContact(c),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: added ? surfBg.withValues(alpha: 0.5) : surfBg,
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
                                  if (c.$3.isNotEmpty)
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
                                      horizontal: 8, vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.income.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Added',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        fontFamily: 'Nunito',
                                        color: AppColors.income,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.add_circle_rounded,
                                    color: AppColors.split,
                                    size: 22,
                                  ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Manual tab ─────────────────────────────────────────────────────────────

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
                            ? AppColors.split.withValues(alpha: 0.15)
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
              side: BorderSide(color: AppColors.split.withValues(alpha: 0.5)),
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

  // ── Group icon picker ──────────────────────────────────────────────────────

  Future<void> _pickGroupIcon(bool isDark, Color surfBg) async {
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => Container(
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
                    color: Colors.grey.withValues(alpha: 0.3),
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
              // Gallery / Camera buttons
              Row(
                children: [
                  _iconPickerBtn(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    surfBg: surfBg,
                    onTap: () async {
                      final img = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 80,
                      );
                      if (img != null) {
                        setState(() => _groupPhotoPath = img.path);
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    },
                  ),
                  const SizedBox(width: 10),
                  _iconPickerBtn(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    surfBg: surfBg,
                    onTap: () async {
                      final img = await ImagePicker().pickImage(
                        source: ImageSource.camera,
                        imageQuality: 80,
                      );
                      if (img != null) {
                        setState(() => _groupPhotoPath = img.path);
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    },
                  ),
                  if (_groupPhotoPath != null) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        setState(() => _groupPhotoPath = null);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.expense.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '✕ Remove',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.expense,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _groupEmojis.map(
                  (e) => GestureDetector(
                    onTap: () {
                      setState(() { _emoji = e; _groupPhotoPath = null; });
                      Navigator.pop(ctx);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _emoji == e && _groupPhotoPath == null
                            ? AppColors.split.withValues(alpha: 0.15)
                            : surfBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _emoji == e && _groupPhotoPath == null
                              ? AppColors.split
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(e, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                ).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconPickerBtn({
    required IconData icon,
    required String label,
    required Color surfBg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: surfBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.split),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'Nunito',
                color: AppColors.split,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete confirm ─────────────────────────────────────────────────────────

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
            fontFamily: 'Nunito', fontWeight: FontWeight.w900, fontSize: 17,
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
              style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700),
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
                fontFamily: 'Nunito', fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

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
  }) =>
      TextField(
        controller: c,
        keyboardType: inputType,
        onChanged: (_) => setState(() {}),
        style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: tc),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontFamily: 'Nunito', fontSize: 12, color: AppColors.subLight,
          ),
          filled: true,
          fillColor: surfBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        ),
      );
}
