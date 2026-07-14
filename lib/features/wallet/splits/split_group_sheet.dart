import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:wai_life_assistant/core/services/ai_parser.dart';
import 'package:wai_life_assistant/shared/utils/ai_limit_snackbar.dart';
import 'package:wai_life_assistant/data/services/profile_service.dart';
import 'package:wai_life_assistant/shared/widgets/emoji_or_image.dart';
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
      // ScaffoldMessenger + Scaffold so SnackBars shown from within the sheet
      // render inside this modal route instead of bubbling up to the page
      // underneath, where they'd stay hidden behind the sheet.
      builder: (_) => ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SplitGroupSheet(
            existing: existing,
            walletId: walletId,
            onSave: onSave,
            onDelete: onDelete,
          ),
        ),
      ),
    );
  }

  @override
  State<SplitGroupSheet> createState() => _SplitGroupSheetState();
}

class _SplitGroupSheetState extends State<SplitGroupSheet>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _nameCtrl = TextEditingController();
  String _emoji = '👥';
  String? _groupPhotoPath;
  bool _saving = false;
  bool _pinned = false;

  final List<SplitParticipant> _participants = [];
  late TabController _addTab;

  // Top-level AI vs Manual tab (new group only)
  late TabController _mainTab;

  // Contacts
  List<(String, String, String)>? _contacts; // (name, emoji, phone)
  bool _contactsLoading = false;
  bool _openedSettings = false;
  final _contactSearchCtrl = TextEditingController();
  String _contactSearch = '';

  // AI Parse tab state
  final _aiDescCtrl = TextEditingController();
  bool _aiParsing = false;
  String? _aiError;
  String _atSearch = '';
  bool _showAtDropdown = false;
  final List<(String, String, String)> _mentionedContacts = [];

  static const _groupEmojis = [
    '👥', '✈️', '🍱', '🎉', '🏖️', '🏕️', '🎓', '🏠', '🎬', '🛒',
    '💼', '🎮', '⚽', '🎸', '🍕', '☕', '🚗', '🎂', '🏋️', '🎯',
  ];
  static const _avatarEmojis = ['🧑', '👨', '👩', '👧', '👦', '🧔', '👱', '🧓'];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _addTab = TabController(length: 2, vsync: this);
    _addTab.addListener(() {
      setState(() {});
      if (_addTab.index == 0 && _contacts == null && !_contactsLoading) {
        _loadContacts();
      }
    });
    _mainTab = TabController(length: 2, vsync: this);
    _mainTab.addListener(() => setState(() {}));

    if (_isEdit) {
      _nameCtrl.text = widget.existing!.name;
      _emoji = widget.existing!.emoji;
      _pinned = widget.existing!.pinnedToDashboard;
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
      _loadUserProfile();
    }
    _loadContacts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameCtrl.dispose();
    _addTab.dispose();
    _mainTab.dispose();
    _aiDescCtrl.dispose();
    _manualNameCtrl.dispose();
    _manualPhoneCtrl.dispose();
    _contactSearchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _openedSettings) {
      _openedSettings = false;
      _contacts = null;
      _loadContacts();
    }
  }

  // ── Profile ───────────────────────────────────────────────────────────────

  Future<void> _loadUserProfile() async {
    try {
      final profile = await ProfileService.instance.fetchProfile();
      if (profile != null && mounted) {
        setState(() {
          final meIndex = _participants.indexWhere((p) => p.isMe);
          if (meIndex >= 0) {
            _participants[meIndex] = SplitParticipant(
              id: 'me',
              name: profile['name'] as String? ?? 'Me',
              emoji: profile['emoji'] as String? ?? '🧑',
              isMe: true,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('[SplitGroupSheet] Failed to load profile: $e');
    }
  }

  // ── Contacts ──────────────────────────────────────────────────────────────

  Future<void> _loadContacts() async {
    if (_contactsLoading) return;
    setState(() => _contactsLoading = true);
    try {
      final status = await FlutterContacts.permissions.request(PermissionType.read);
      final granted = status == PermissionStatus.granted || status == PermissionStatus.limited;
      if (!granted) {
        if (mounted) setState(() { _contacts = []; _contactsLoading = false; });
        return;
      }
      final raw = await FlutterContacts.getAll(
        properties: {ContactProperty.name, ContactProperty.phone},
      );
      final result = <(String, String, String)>[];
      for (final c in raw) {
        final name = (c.displayName ?? '').trim();
        if (name.isEmpty) continue;
        final p = c.phones.isNotEmpty ? c.phones.first : null;
        final phone = (p?.normalizedNumber?.isNotEmpty == true
            ? p!.normalizedNumber!
            : p?.number) ?? '';
        result.add((name, '🧑', phone));
      }
      result.sort((a, b) => a.$1.toLowerCase().compareTo(b.$1.toLowerCase()));
      if (mounted) setState(() { _contacts = result; _contactsLoading = false; });
    } catch (e) {
      debugPrint('[Contacts] $e');
      if (mounted) setState(() { _contacts = []; _contactsLoading = false; });
    }
  }

  Future<void> _grantContactPermission() async {
    final status = await ph.Permission.contacts.status;
    if (status.isPermanentlyDenied || status.isDenied) {
      _openedSettings = true;
      await ph.openAppSettings();
    } else {
      _contacts = null;
      await _loadContacts();
    }
  }

  // ── Participants ──────────────────────────────────────────────────────────

  bool _alreadyAdded(String? phone, String name) {
    if (phone != null && phone.isNotEmpty) {
      return _participants.any((p) => p.phone == phone);
    }
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
    if (name.isEmpty || _alreadyAdded(phone.isEmpty ? null : phone, name)) {
      return;
    }
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
        finalEmoji = _emoji;
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
      pinnedToDashboard: _pinned,
    );
    group.isSettled = widget.existing?.isSettled ?? false;

    if (mounted) {
      widget.onSave(group);
      Navigator.pop(context);
    }
  }

  // ── AI Parse ──────────────────────────────────────────────────────────────

  void _onAiTextChanged(String value) {
    final words = value.split(RegExp(r'\s'));
    final lastWord = words.isNotEmpty ? words.last : '';
    if (lastWord.startsWith('@')) {
      setState(() {
        _atSearch = lastWord.substring(1).toLowerCase();
        _showAtDropdown = true;
      });
    } else {
      if (_showAtDropdown) setState(() => _showAtDropdown = false);
    }
  }

  void _selectMentionContact((String, String, String) contact) {
    final text = _aiDescCtrl.text;
    final words = text.split(RegExp(r'\s'));
    if (words.isNotEmpty && words.last.startsWith('@')) {
      words[words.length - 1] = '@${contact.$1}';
    }
    final newText = words.join(' ');
    _aiDescCtrl.text = newText;
    _aiDescCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: newText.length),
    );
    if (!_mentionedContacts.any((c) => c.$1 == contact.$1)) {
      _mentionedContacts.add(contact);
    }
    setState(() => _showAtDropdown = false);
  }

  Future<void> _parseWithAI() async {
    final text = _aiDescCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() { _aiParsing = true; _aiError = null; });
    try {
      final result = await AIParser.parseText(
        feature: 'wallet',
        subFeature: 'split_group',
        text: text,
      );
      if (!result.success || result.data == null) {
        if (mounted) {
          maybeShowAiLimitSnackbar(context, result.error);
          setState(() => _aiError = result.error ?? 'Could not parse. Try again.');
        }
        return;
      }
      final d = result.data!;
      final groupName = (d['group_name'] as String? ?? '').trim();
      final emoji = (d['emoji'] as String? ?? '').trim();
      final rawParticipants = d['participants'] as List<dynamic>? ?? [];

      if (groupName.isNotEmpty) _nameCtrl.text = groupName;
      if (emoji.isNotEmpty && emoji != '👥') _emoji = emoji;
      _groupPhotoPath = null;

      // Keep "You", rebuild remaining from AI result
      final meParticipant = _participants.firstWhere((p) => p.isMe);
      _participants.clear();
      _participants.add(meParticipant);

      for (int i = 0; i < rawParticipants.length; i++) {
        final m = rawParticipants[i] as Map<String, dynamic>? ?? {};
        final name = (m['name'] as String? ?? '').trim();
        if (name.isEmpty) continue;
        // Match against @mentioned contacts to get phone number
        final mentioned = _mentionedContacts.where((c) =>
          c.$1.toLowerCase().contains(name.toLowerCase()) ||
          name.toLowerCase().contains(c.$1.split(' ').first.toLowerCase()),
        ).firstOrNull;
        if (mentioned != null) {
          if (!_alreadyAdded(mentioned.$3, mentioned.$1)) {
            _participants.add(SplitParticipant(
              id: 'c_${mentioned.$3.isNotEmpty ? mentioned.$3 : mentioned.$1}',
              name: mentioned.$1,
              emoji: mentioned.$2,
              phone: mentioned.$3.isNotEmpty ? mentioned.$3 : null,
            ));
          }
        } else {
          final phone = (m['phone'] as String? ?? '').trim();
          if (!_alreadyAdded(phone.isEmpty ? null : phone, name)) {
            _participants.add(SplitParticipant(
              id: 'u_${DateTime.now().millisecondsSinceEpoch}_$i',
              name: name,
              emoji: '🧑',
              phone: phone.isEmpty ? null : phone,
            ));
          }
        }
      }

      // Switch to manual tab for review
      if (mounted) _mainTab.animateTo(1);
    } catch (e) {
      if (mounted) setState(() => _aiError = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _aiParsing = false);
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
            // Top-level tab switcher (new group only)
            if (!_isEdit) _buildMainTabBar(surfBg, sub),
            Expanded(
              child: !_isEdit && _mainTab.index == 0
                  ? _buildAiTab(isDark, surfBg, tc, sub)
                  : _buildManualTab(isDark, surfBg, tc, sub),
            ),
          ],
        ),
      ),
    );
  }

  // ── Main tab switcher (AI vs Manual) ──────────────────────────────────────

  Widget _buildMainTabBar(Color surfBg, Color sub) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: surfBg,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(4),
        child: TabBar(
          controller: _mainTab,
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
            fontSize: 13,
            fontFamily: 'Nunito',
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            fontFamily: 'Nunito',
          ),
          padding: EdgeInsets.zero,
          tabs: const [
            Tab(
              height: 38,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Text('✦ '), Text('AI Parse')],
              ),
            ),
            Tab(
              height: 38,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Text('✏️ '), Text('Manual')],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── AI Parse tab ──────────────────────────────────────────────────────────

  Widget _buildAiTab(bool isDark, Color surfBg, Color tc, Color sub) {
    final filteredContacts = _showAtDropdown && _contacts != null
        ? _contacts!.where((c) =>
            _atSearch.isEmpty ||
            c.$1.toLowerCase().contains(_atSearch) ||
            c.$3.contains(_atSearch),
          ).take(6).toList()
        : <(String, String, String)>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group icon row
          Row(
            children: [
              GestureDetector(
                onTap: () => _pickGroupIcon(isDark, surfBg),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.split.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.split.withValues(alpha: 0.35),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: EmojiOrImage(
                      value: _groupPhotoPath ?? _emoji,
                      size: 30,
                      borderRadius: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Group Icon',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Nunito',
                      color: tc,
                    ),
                  ),
                  Text(
                    'Tap to change emoji or photo',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Nunito',
                      color: sub,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          _lbl('DESCRIBE YOUR GROUP', sub),
          const SizedBox(height: 8),
          TextField(
            controller: _aiDescCtrl,
            onChanged: _onAiTextChanged,
            maxLines: 4,
            style: TextStyle(fontSize: 14, fontFamily: 'Nunito', color: tc),
            decoration: InputDecoration(
              hintText: 'e.g. Goa Trip with @Rahul, Priya and Suresh for new year',
              hintStyle: TextStyle(
                fontSize: 13, fontFamily: 'Nunito', color: sub,
              ),
              filled: true,
              fillColor: surfBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14,
              ),
            ),
          ),
          // @ contact dropdown
          if (_showAtDropdown && filteredContacts.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: surfBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.split.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: filteredContacts.map((c) {
                  return GestureDetector(
                    onTap: () => _selectMentionContact(c),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Text(c.$2, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
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
                          const Icon(
                            Icons.add_circle_rounded,
                            color: AppColors.split,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          if (_showAtDropdown && _contactsLoading) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: surfBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.split,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Type @ to mention contacts from your phone',
            style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: sub),
          ),
          if (_aiError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.expense.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.expense, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _aiError!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'Nunito',
                        color: AppColors.expense,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_aiParsing || _aiDescCtrl.text.trim().isEmpty)
                  ? null
                  : _parseWithAI,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.split,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _aiParsing
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('✦  ', style: TextStyle(fontSize: 15, color: Colors.white)),
                        Text(
                          'Parse with AI',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Nunito',
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Manual tab ────────────────────────────────────────────────────────────

  Widget _buildManualTab(bool isDark, Color surfBg, Color tc, Color sub) {
    final canSave = _nameCtrl.text.trim().isNotEmpty && _participants.length >= 2;
    return SingleChildScrollView(
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
                      fontSize: 14, fontFamily: 'Nunito', color: sub,
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
                  fontSize: 11, fontFamily: 'Nunito', color: AppColors.expense,
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Add participant panel
          _buildAddPanel(isDark, surfBg, tc, sub),
          const SizedBox(height: 24),

          // Pin to Dashboard (edit mode only)
          if (_isEdit) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Text('📌', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pin to Dashboard',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: tc,
                          ),
                        ),
                        Text(
                          'Quick access to add expenses from home',
                          style: TextStyle(
                            fontSize: 11, fontFamily: 'Nunito', color: sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _pinned,
                    onChanged: (v) => setState(() => _pinned = v),
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

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
                onPressed: _grantContactPermission,
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

  // ── Manual add-person tab ──────────────────────────────────────────────────

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
              style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800),
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
    final nav = Navigator.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);  // close dialog using its own context
              nav.pop();           // close sheet using pre-captured navigator
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
              style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800),
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
