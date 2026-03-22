import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/core/supabase/note_service.dart';
import 'package:wai_life_assistant/core/services/network_service.dart';
import 'package:wai_life_assistant/core/widgets/emoji_or_image.dart';

// ── Note color palette ────────────────────────────────────────────────────────

enum NoteColor {
  yellow,
  pink,
  blue,
  green,
  purple,
  orange,
  mint,
  white;

  String get label => name[0].toUpperCase() + name.substring(1);

  Color bg(bool isDark) => switch (this) {
    NoteColor.yellow => isDark ? const Color(0xFF3D3000) : const Color(0xFFFFF9C4),
    NoteColor.pink   => isDark ? const Color(0xFF3D0019) : const Color(0xFFFFE4EC),
    NoteColor.blue   => isDark ? const Color(0xFF002040) : const Color(0xFFDCEEFF),
    NoteColor.green  => isDark ? const Color(0xFF002210) : const Color(0xFFD6F5E3),
    NoteColor.purple => isDark ? const Color(0xFF200035) : const Color(0xFFEBDCFF),
    NoteColor.orange => isDark ? const Color(0xFF3D1500) : const Color(0xFFFFE6CC),
    NoteColor.mint   => isDark ? const Color(0xFF00302A) : const Color(0xFFCCF5EE),
    NoteColor.white  => isDark ? const Color(0xFF232323) : const Color(0xFFFFFFFF),
  };

  Color accent(bool isDark) => switch (this) {
    NoteColor.yellow => const Color(0xFFF9A825),
    NoteColor.pink   => const Color(0xFFE91E8C),
    NoteColor.blue   => const Color(0xFF1565C0),
    NoteColor.green  => const Color(0xFF2E7D32),
    NoteColor.purple => const Color(0xFF6A1B9A),
    NoteColor.orange => const Color(0xFFE65100),
    NoteColor.mint   => const Color(0xFF00796B),
    NoteColor.white  => isDark ? Colors.white70 : const Color(0xFF607D8B),
  };
}

NoteColor _noteColorFromString(String? s) {
  return NoteColor.values.firstWhere(
    (c) => c.name == s,
    orElse: () => NoteColor.yellow,
  );
}

// ── Model ─────────────────────────────────────────────────────────────────────

class NoteModel {
  String id;
  final String walletId;
  String title;
  String content;
  NoteColor color;
  bool isPinned;
  final DateTime createdAt;
  DateTime updatedAt;

  NoteModel({
    required this.id,
    required this.walletId,
    this.title = '',
    this.content = '',
    this.color = NoteColor.yellow,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NoteModel.fromRow(Map<String, dynamic> row) => NoteModel(
    id: row['id'] as String,
    walletId: row['wallet_id'] as String,
    title: row['title'] as String? ?? '',
    content: row['content'] as String? ?? '',
    color: _noteColorFromString(row['color'] as String?),
    isPinned: row['is_pinned'] as bool? ?? false,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );

  Map<String, dynamic> toRow() => {
    'wallet_id': walletId,
    'title': title,
    'content': content,
    'color': color.name,
    'is_pinned': isPinned,
  };

  NoteModel copyWith({
    String? title,
    String? content,
    NoteColor? color,
    bool? isPinned,
  }) => NoteModel(
    id: id,
    walletId: walletId,
    title: title ?? this.title,
    content: content ?? this.content,
    color: color ?? this.color,
    isPinned: isPinned ?? this.isPinned,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}

// ── Screen ────────────────────────────────────────────────────────────────────

class NotesScreen extends StatefulWidget {
  final String walletId;
  final String walletName;
  final String walletEmoji;

  const NotesScreen({
    super.key,
    required this.walletId,
    this.walletName = 'Personal',
    this.walletEmoji = '🗒️',
  });

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<NoteModel> _notes = [];
  bool _loading = false;
  bool _wasOnline = true;
  String _search = '';
  final _searchCtrl = TextEditingController();

  List<NoteModel> get _filtered {
    final q = _search.trim().toLowerCase();
    var list = List<NoteModel>.from(_notes);
    if (q.isNotEmpty) {
      list = list.where((n) =>
        n.title.toLowerCase().contains(q) ||
        n.content.toLowerCase().contains(q),
      ).toList();
    }
    return list;
  }

  List<NoteModel> get _pinned => _filtered.where((n) => n.isPinned).toList();
  List<NoteModel> get _unpinned => _filtered.where((n) => !n.isPinned).toList();

  void _onNetworkChange() {
    final online = NetworkService.instance.isOnline.value;
    if (online && !_wasOnline) _loadNotes();
    _wasOnline = online;
  }

  @override
  void initState() {
    super.initState();
    _wasOnline = NetworkService.instance.isOnline.value;
    NetworkService.instance.isOnline.addListener(_onNetworkChange);
    _loadNotes();
  }

  @override
  void dispose() {
    NetworkService.instance.isOnline.removeListener(_onNetworkChange);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    if (widget.walletId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final rows = await NoteService.instance.fetchNotes(widget.walletId);
      if (!mounted) return;
      setState(() {
        _notes = rows.map(NoteModel.fromRow).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('[Notes] load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveNote(NoteModel note, {bool isNew = false}) async {
    try {
      if (isNew) {
        final row = await NoteService.instance.addNote(note.toRow());
        final saved = NoteModel.fromRow(row);
        if (mounted) setState(() => _notes.insert(0, saved));
      } else {
        if (mounted) {
          setState(() {
            final i = _notes.indexWhere((n) => n.id == note.id);
            if (i >= 0) _notes[i] = note;
          });
        }
        await NoteService.instance.updateNote(note.id, note.toRow());
      }
    } catch (e) {
      debugPrint('[Notes] save error: $e');
      if (isNew && mounted) setState(() => _notes.insert(0, note));
    }
  }

  Future<void> _deleteNote(NoteModel note) async {
    setState(() => _notes.remove(note));
    try {
      await NoteService.instance.deleteNote(note.id);
    } catch (_) {}
  }

  Future<void> _togglePin(NoteModel note) async {
    final updated = note.copyWith(isPinned: !note.isPinned);
    setState(() {
      final i = _notes.indexWhere((n) => n.id == note.id);
      if (i >= 0) _notes[i] = updated;
    });
    try {
      await NoteService.instance.updateNote(
        note.id,
        {'is_pinned': updated.isPinned},
      );
    } catch (_) {}
  }

  void _openNoteSheet({NoteModel? existing}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NoteSheet(
        isDark: isDark,
        existing: existing,
        walletId: widget.walletId,
        onSave: (note) => _saveNote(note, isNew: existing == null),
      ),
    );
  }

  void _showContextMenu(NoteModel note) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContextMenu(
        isDark: isDark,
        note: note,
        onEdit: () {
          Navigator.pop(context);
          _openNoteSheet(existing: note);
        },
        onPin: () {
          Navigator.pop(context);
          _togglePin(note);
        },
        onDelete: () {
          Navigator.pop(context);
          _deleteNote(note);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor = isDark ? AppColors.subDark : AppColors.subLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(isDark, cardBg, textColor, subColor),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNoteSheet(),
        backgroundColor: const Color(0xFFF9A825),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'New Note',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(isDark, subColor),
    );
  }

  AppBar _buildAppBar(
    bool isDark,
    Color cardBg,
    Color textColor,
    Color subColor,
  ) {
    return AppBar(
      backgroundColor: cardBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          EmojiOrImage(value: widget.walletEmoji, size: 20, borderRadius: 4),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                  color: textColor,
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  widget.walletName,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Nunito',
                    color: subColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: subColor, size: 22),
          onPressed: _loadNotes,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildBody(bool isDark, Color subColor) {
    final pinned = _pinned;
    final unpinned = _unpinned;
    final total = pinned.length + unpinned.length;

    if (_notes.isEmpty) {
      return _buildEmpty(isDark, subColor);
    }

    return CustomScrollView(
      slivers: [
        // Search bar
        SliverToBoxAdapter(child: _buildSearchBar(isDark, subColor)),

        if (total == 0)
          SliverFillRemaining(
            child: Center(
              child: Text(
                'No notes match "$_search"',
                style: TextStyle(
                  color: subColor,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        else ...[
          // Pinned section
          if (pinned.isNotEmpty) ...[
            _sectionHeader('📌  Pinned', isDark, subColor),
            _buildGrid(pinned, isDark),
          ],

          // Other notes
          if (unpinned.isNotEmpty) ...[
            if (pinned.isNotEmpty)
              _sectionHeader('🗒️  Notes', isDark, subColor),
            _buildGrid(unpinned, isDark),
          ],

          // Bottom padding for FAB
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ],
    );
  }

  Widget _buildEmpty(bool isDark, Color subColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🗒️', style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'No notes yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              fontFamily: 'Nunito',
              color: isDark ? AppColors.textDark : AppColors.textLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + New Note to create your first sticky note',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Nunito',
              color: subColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, Color subColor) {
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: surfBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _search = v),
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: isDark ? AppColors.textDark : AppColors.textLight,
          ),
          decoration: InputDecoration(
            hintText: 'Search notes…',
            hintStyle: TextStyle(
              fontFamily: 'Nunito',
              color: subColor,
              fontSize: 14,
            ),
            prefixIcon: Icon(Icons.search_rounded, color: subColor, size: 20),
            suffixIcon: _search.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded, color: subColor, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _search = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _sectionHeader(
    String label,
    bool isDark,
    Color subColor,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
            color: subColor,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }

  SliverPadding _buildGrid(List<NoteModel> notes, bool isDark) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        delegate: SliverChildBuilderDelegate(
          (ctx, i) => _NoteCard(
            note: notes[i],
            isDark: isDark,
            onTap: () => _openNoteSheet(existing: notes[i]),
            onLongPress: () => _showContextMenu(notes[i]),
          ),
          childCount: notes.length,
        ),
      ),
    );
  }
}

// ── Note card ─────────────────────────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  final NoteModel note;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _NoteCard({
    required this.note,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
  });

  String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final bg = note.color.bg(isDark);
    final accent = note.color.accent(isDark);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: pin icon + date
            Row(
              children: [
                if (note.isPinned)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.push_pin_rounded,
                      size: 13,
                      color: accent,
                    ),
                  ),
                Expanded(
                  child: Text(
                    _relativeDate(note.updatedAt),
                    style: TextStyle(
                      fontSize: 9,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w600,
                      color: accent.withValues(alpha: 0.75),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Color dot
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Title
            if (note.title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  note.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.2,
                  ),
                ),
              ),

            // Content preview
            if (note.content.isNotEmpty)
              Expanded(
                child: Text(
                  note.content,
                  maxLines: 8,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w500,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.65),
                    height: 1.4,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Note edit/add bottom sheet ────────────────────────────────────────────────

class _NoteSheet extends StatefulWidget {
  final bool isDark;
  final NoteModel? existing;
  final String walletId;
  final Future<void> Function(NoteModel) onSave;

  const _NoteSheet({
    required this.isDark,
    required this.existing,
    required this.walletId,
    required this.onSave,
  });

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late NoteColor _color;
  late bool _isPinned;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _contentCtrl = TextEditingController(text: e?.content ?? '');
    _color = e?.color ?? NoteColor.yellow;
    _isPinned = e?.isPinned ?? false;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty && content.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final note = widget.existing != null
        ? widget.existing!.copyWith(
            title: title,
            content: content,
            color: _color,
            isPinned: _isPinned,
          )
        : NoteModel(
            id: '',
            walletId: widget.walletId,
            title: title,
            content: content,
            color: _color,
            isPinned: _isPinned,
            createdAt: now,
            updatedAt: now,
          );
    await widget.onSave(note);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bg = _color.bg(widget.isDark);
    final accent = _color.accent(widget.isDark);
    final textColor = widget.isDark ? Colors.white : Colors.black87;
    final hintColor = (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.35);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Color picker row
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: NoteColor.values.map((c) {
                  final selected = c == _color;
                  return GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      margin: const EdgeInsets.only(right: 8),
                      width: selected ? 36 : 28,
                      height: selected ? 36 : 28,
                      decoration: BoxDecoration(
                        color: c.accent(widget.isDark),
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: textColor, width: 2.5)
                            : null,
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: c.accent(widget.isDark).withValues(alpha: 0.4),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                      child: selected
                          ? Icon(Icons.check_rounded, size: 16, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // Title field
            TextField(
              controller: _titleCtrl,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFamily: 'Nunito',
                color: textColor,
              ),
              decoration: InputDecoration(
                hintText: 'Title',
                hintStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Nunito',
                  color: hintColor,
                ),
                border: InputBorder.none,
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 1,
            ),

            // Content field
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 80, maxHeight: 240),
              child: TextField(
                controller: _contentCtrl,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w500,
                  color: textColor.withValues(alpha: 0.85),
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Write something…',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Nunito',
                    color: hintColor,
                  ),
                  border: InputBorder.none,
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
                keyboardType: TextInputType.multiline,
              ),
            ),

            const SizedBox(height: 16),

            // Bottom actions: pin toggle + save
            Row(
              children: [
                // Pin toggle
                GestureDetector(
                  onTap: () => setState(() => _isPinned = !_isPinned),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _isPinned
                          ? accent.withValues(alpha: 0.15)
                          : accent.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: accent.withValues(alpha: _isPinned ? 0.5 : 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isPinned
                              ? Icons.push_pin_rounded
                              : Icons.push_pin_outlined,
                          size: 16,
                          color: accent,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _isPinned ? 'Pinned' : 'Pin',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Save button
                GestureDetector(
                  onTap: _saving ? null : _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Context menu (long-press) ─────────────────────────────────────────────────

class _ContextMenu extends StatelessWidget {
  final bool isDark;
  final NoteModel note;
  final VoidCallback onEdit;
  final VoidCallback onPin;
  final VoidCallback onDelete;

  const _ContextMenu({
    required this.isDark,
    required this.note,
    required this.onEdit,
    required this.onPin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor = isDark ? AppColors.subDark : AppColors.subLight;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Note preview header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: note.color.accent(isDark),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    note.title.isNotEmpty
                        ? note.title
                        : note.content.isNotEmpty
                            ? note.content
                            : 'Untitled note',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: subColor.withValues(alpha: 0.15)),

          _MenuItem(
            icon: Icons.edit_rounded,
            label: 'Edit',
            color: AppColors.primary,
            onTap: onEdit,
          ),
          _MenuItem(
            icon: note.isPinned
                ? Icons.push_pin_outlined
                : Icons.push_pin_rounded,
            label: note.isPinned ? 'Unpin' : 'Pin',
            color: const Color(0xFFF9A825),
            onTap: onPin,
          ),
          Divider(height: 1, color: subColor.withValues(alpha: 0.15)),
          _MenuItem(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: AppColors.expense,
            onTap: onDelete,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFamily: 'Nunito',
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
