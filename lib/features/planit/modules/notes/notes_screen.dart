import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/core/supabase/note_service.dart';
import 'package:wai_life_assistant/core/services/network_service.dart';
import 'package:wai_life_assistant/core/widgets/emoji_or_image.dart';
import 'package:wai_life_assistant/services/ai_parser.dart';

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

// ── Note type ─────────────────────────────────────────────────────────────────

enum NoteType { text, list, link, secret }

extension NoteTypeExt on NoteType {
  String get label => switch (this) {
    NoteType.text   => 'Text',
    NoteType.list   => 'List',
    NoteType.link   => 'Link',
    NoteType.secret => 'Secret',
  };

  IconData get icon => switch (this) {
    NoteType.text   => Icons.text_fields_rounded,
    NoteType.list   => Icons.checklist_rounded,
    NoteType.link   => Icons.link_rounded,
    NoteType.secret => Icons.lock_outline_rounded,
  };

  String get contentHint => switch (this) {
    NoteType.text   => 'Write your note here...',
    NoteType.list   => 'One item per line...',
    NoteType.link   => 'Paste a URL here...',
    NoteType.secret => 'Your secret content...',
  };
}

NoteType _noteTypeFromString(String? s) {
  return NoteType.values.firstWhere(
    (t) => t.name == s,
    orElse: () => NoteType.text,
  );
}

// ── Model ─────────────────────────────────────────────────────────────────────

class NoteModel {
  String id;
  final String walletId;
  String title;
  String content;
  NoteColor color;
  NoteType type;
  bool isPinned;
  final DateTime createdAt;
  DateTime updatedAt;

  NoteModel({
    required this.id,
    required this.walletId,
    this.title = '',
    this.content = '',
    this.color = NoteColor.yellow,
    this.type = NoteType.text,
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
    type: _noteTypeFromString(row['note_type'] as String?),
    isPinned: row['is_pinned'] as bool? ?? false,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );

  Map<String, dynamic> toRow() => {
    'wallet_id': walletId,
    'title': title,
    'content': content,
    'color': color.name,
    'note_type': type.name,
    'is_pinned': isPinned,
  };

  NoteModel copyWith({
    String? title,
    String? content,
    NoteColor? color,
    NoteType? type,
    bool? isPinned,
  }) => NoteModel(
    id: id,
    walletId: walletId,
    title: title ?? this.title,
    content: content ?? this.content,
    color: color ?? this.color,
    type: type ?? this.type,
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
  final List<NoteModel>? notes;

  final bool openAdd;
  const NotesScreen({
    super.key,
    required this.walletId,
    this.walletName = 'Personal',
    this.walletEmoji = '🗒️',
    this.openAdd = false,
    this.notes,
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
    if (widget.openAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openNoteSheet();
      });
    }
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
      final loaded = rows.map(NoteModel.fromRow).toList();
      widget.notes?..clear()..addAll(loaded);
      setState(() {
        _notes = loaded;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[Notes] load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveNote(NoteModel note, {bool isNew = false}) async {
    try {
      if (isNew || note.id.isEmpty) {
        // note.id.isEmpty guards against a broken local note (e.g. from a
        // prior failed save) being re-submitted as an update.
        final row = await NoteService.instance.addNote(note.toRow());
        final saved = NoteModel.fromRow(row);
        if (mounted) {
          setState(() {
            // Replace any stale zero-id entry or prepend the new one.
            final stale = _notes.indexWhere((n) => n.id.isEmpty);
            if (stale >= 0) {
              _notes[stale] = saved;
            } else {
              _notes.insert(0, saved);
            }
          });
        }
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
    if (widget.walletId.isEmpty) return;
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
            // Header row: type icon + pin + date
            Row(
              children: [
                Icon(note.type.icon, size: 11, color: accent),
                const SizedBox(width: 3),
                if (note.isPinned) ...[
                  Icon(Icons.push_pin_rounded, size: 11, color: accent),
                  const SizedBox(width: 3),
                ],
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
                Container(
                  width: 9,
                  height: 9,
                  decoration:
                      BoxDecoration(color: accent, shape: BoxShape.circle),
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

            // Content preview (secret → obscured, list → bulleted, others → plain)
            if (note.content.isNotEmpty)
              Expanded(
                child: note.type == NoteType.secret
                    ? Row(
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              size: 12,
                              color: accent.withValues(alpha: 0.6)),
                          const SizedBox(width: 4),
                          Text(
                            '•' * 12,
                            style: TextStyle(
                              fontSize: 11,
                              color: accent.withValues(alpha: 0.6),
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      )
                    : note.type == NoteType.list
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: note.content
                                .split('\n')
                                .where((l) => l.trim().isNotEmpty)
                                .take(5)
                                .map((l) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 2),
                                      child: Row(
                                        children: [
                                          Icon(Icons.circle,
                                              size: 5,
                                              color: accent
                                                  .withValues(alpha: 0.6)),
                                          const SizedBox(width: 5),
                                          Expanded(
                                            child: Text(
                                              l.trim(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontFamily: 'Nunito',
                                                fontWeight: FontWeight.w500,
                                                color: (isDark
                                                        ? Colors.white
                                                        : Colors.black)
                                                    .withValues(alpha: 0.65),
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          )
                        : Text(
                            note.content,
                            maxLines: 8,
                            overflow: TextOverflow.fade,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w500,
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.65),
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

class _NoteSheetState extends State<_NoteSheet>
    with SingleTickerProviderStateMixin {
  late TabController _mode;

  // AI state
  final _aiCtrl = TextEditingController();
  bool _aiParsing = false;
  _ParsedNote? _aiPreview;
  String? _aiError;
  bool _usingClaudeAI = false;

  // Manual form state
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late NoteColor _color;
  late NoteType _type;
  late bool _isPinned;
  bool _saving = false;
  bool _secretVisible = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _mode = TabController(
      length: 2,
      vsync: this,
      initialIndex: e != null ? 1 : 0,
    );
    _mode.addListener(() => setState(() {}));
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _contentCtrl = TextEditingController(text: e?.content ?? '');
    _color = e?.color ?? NoteColor.yellow;
    _type = e?.type ?? NoteType.text;
    _isPinned = e?.isPinned ?? false;
  }

  @override
  void dispose() {
    _mode.dispose();
    _aiCtrl.dispose();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _parseAI(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _aiParsing = true;
      _aiError = null;
      _aiPreview = null;
      _usingClaudeAI = false;
    });

    _ParsedNote? result;
    try {
      final aiResult = await AIParser.parseText(
        feature: 'planit',
        subFeature: 'note',
        text: text.trim(),
      );
      if (aiResult.success && aiResult.data != null) {
        result = _parsedNoteFromAI(aiResult.data!, widget.walletId);
        _usingClaudeAI = true;
      } else {
        throw Exception(aiResult.error ?? 'AI parse failed');
      }
    } catch (_) {
      try {
        result = _NoteNlpParser.parse(text.trim(), widget.walletId);
        _usingClaudeAI = false;
      } catch (e) {
        if (mounted) {
          setState(() {
            _aiParsing = false;
            _aiError = 'Could not understand — try again or fill manually.';
          });
        }
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _aiPreview = result;
      _aiParsing = false;
      _titleCtrl.text = result!.title;
      _contentCtrl.text = result.content;
      _color = result.color;
      _type = result.type;
      _isPinned = result.isPinned;
    });
  }

  Future<void> _save() async {
    if (widget.walletId.isEmpty) {
      Navigator.pop(context);
      return;
    }
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
            type: _type,
            isPinned: _isPinned,
          )
        : NoteModel(
            id: '',
            walletId: widget.walletId,
            title: title,
            content: content,
            color: _color,
            type: _type,
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
    final hintColor =
        (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.35);
    final subColor =
        (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.5);
    final isNew = widget.existing == null;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // ── Drag handle ──────────────────────────────────────────────────
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
            const SizedBox(height: 12),

            // ── Header ───────────────────────────────────────────────────────
            Row(
              children: [
                const Text('🗒️', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  isNew ? 'New Note' : 'Edit Note',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Nunito',
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Mode switcher ────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(3),
              child: TabBar(
                controller: _mode,
                indicator: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(11),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: accent,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  fontFamily: 'Nunito',
                ),
                padding: EdgeInsets.zero,
                tabs: const [
                  Tab(
                    height: 36,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('✨', style: TextStyle(fontSize: 14)),
                        SizedBox(width: 6),
                        Text('AI Parse'),
                      ],
                    ),
                  ),
                  Tab(
                    height: 36,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_outlined, size: 14),
                        SizedBox(width: 6),
                        Text('Manual'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── AI TAB ───────────────────────────────────────────────────────
            if (_mode.index == 0) ...[
              _NoteAiHint(isDark: widget.isDark, accent: accent),
              const SizedBox(height: 12),
              _NoteAiInputBox(
                ctrl: _aiCtrl,
                isDark: widget.isDark,
                accent: accent,
                isParsing: _aiParsing,
                onParse: () => _parseAI(_aiCtrl.text),
              ),
              if (_aiError != null) ...[
                const SizedBox(height: 10),
                _NoteErrorBanner(message: _aiError!),
              ],
              if (_aiPreview != null) ...[
                const SizedBox(height: 12),
                _NoteAiPreviewCard(
                  preview: _aiPreview!,
                  isDark: widget.isDark,
                  accent: accent,
                  usedClaudeAI: _usingClaudeAI,
                  onEdit: () => _mode.animateTo(1),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _saving ? null : _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isNew ? '✓  Create Note' : '✓  Save Changes',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
              if (_aiPreview == null && !_aiParsing) ...[
                const SizedBox(height: 12),
                _NoteExamples(
                  isDark: widget.isDark,
                  accent: accent,
                  onTap: (s) => setState(() => _aiCtrl.text = s),
                ),
              ],
            ],

            // ── MANUAL TAB ───────────────────────────────────────────────────
            if (_mode.index == 1) ...[
            // ── Type selector + Pin ──────────────────────────────────────────
            Row(
              children: [
                // Type tabs
                Expanded(
                  child: Row(
                    children: NoteType.values.map((t) {
                      final sel = t == _type;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _type = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: sel
                                  ? accent
                                  : accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: sel
                                  ? null
                                  : Border.all(
                                      color: accent.withValues(alpha: 0.25)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  t.icon,
                                  size: 16,
                                  color: sel ? Colors.white : accent,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  t.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                    color: sel ? Colors.white : accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 8),
                // Pin button
                GestureDetector(
                  onTap: () => setState(() => _isPinned = !_isPinned),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isPinned
                          ? accent
                          : accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: _isPinned
                          ? null
                          : Border.all(
                              color: accent.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isPinned
                              ? Icons.push_pin_rounded
                              : Icons.push_pin_outlined,
                          size: 14,
                          color: _isPinned ? Colors.white : accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Pin',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                            color: _isPinned ? Colors.white : accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Title field ──────────────────────────────────────────────────
            TextField(
              controller: _titleCtrl,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'Nunito',
                color: textColor,
              ),
              decoration: InputDecoration(
                hintText: 'Note title (optional)',
                hintStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Nunito',
                  color: hintColor,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: accent.withValues(alpha: 0.25)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: accent.withValues(alpha: 0.25)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: accent, width: 1.5),
                ),
                filled: true,
                fillColor: accent.withValues(alpha: 0.06),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 1,
            ),

            const SizedBox(height: 10),

            // ── Content field ────────────────────────────────────────────────
            Stack(
              children: [
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minHeight: 100, maxHeight: 260),
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
                      hintText: _type.contentHint,
                      hintStyle: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Nunito',
                          color: hintColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: accent.withValues(alpha: 0.25)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: accent.withValues(alpha: 0.25)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: accent, width: 1.5),
                      ),
                      filled: true,
                      fillColor: accent.withValues(alpha: 0.06),
                      contentPadding: const EdgeInsets.fromLTRB(14, 12, 44, 12),
                      alignLabelWithHint: true,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 6,
                    // obscureText requires maxLines == 1
                    maxLines: (_type == NoteType.secret && !_secretVisible)
                        ? 1
                        : null,
                    keyboardType: _type == NoteType.link
                        ? TextInputType.url
                        : TextInputType.multiline,
                    obscureText:
                        _type == NoteType.secret && !_secretVisible,
                  ),
                ),
                // Show/hide toggle for secret type
                if (_type == NoteType.secret)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _secretVisible = !_secretVisible),
                      child: Icon(
                        _secretVisible
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 20,
                        color: accent.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Note colour ──────────────────────────────────────────────────
            Text(
              'NOTE COLOR',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                fontFamily: 'Nunito',
                color: subColor,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: NoteColor.values.map((c) {
                final selected = c == _color;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: selected ? 34 : 28,
                      height: selected ? 34 : 28,
                      decoration: BoxDecoration(
                        color: c.bg(widget.isDark),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? c.accent(widget.isDark)
                              : c.accent(widget.isDark).withValues(alpha: 0.35),
                          width: selected ? 2.5 : 1.5,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: c
                                      .accent(widget.isDark)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                      child: selected
                          ? Icon(Icons.check_rounded,
                              size: 14,
                              color: c.accent(widget.isDark))
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // ── Action buttons ───────────────────────────────────────────────
            Row(
              children: [
                // Cancel
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: accent.withValues(alpha: 0.35),
                            width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: accent,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Save / Create
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _saving ? null : _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isNew ? '✓  Create Note' : '✓  Save Changes',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            ], // end manual tab
          ],
        ),
        ),
      ),
    );
  }
}

// ── AI helpers ────────────────────────────────────────────────────────────────

class _ParsedNote {
  final String title, content, walletId;
  final NoteColor color;
  final NoteType type;
  final bool isPinned;

  const _ParsedNote({
    required this.title,
    required this.content,
    required this.walletId,
    required this.color,
    required this.type,
    required this.isPinned,
  });
}

_ParsedNote _parsedNoteFromAI(Map<String, dynamic> data, String walletId) =>
    _ParsedNote(
      title: data['title'] as String? ?? '',
      content: data['content'] as String? ?? '',
      walletId: walletId,
      color: _noteColorFromString(data['color'] as String?),
      type: _noteTypeFromString(data['note_type'] as String?),
      isPinned: data['is_pinned'] as bool? ?? false,
    );

class _NoteNlpParser {
  static _ParsedNote parse(String raw, String walletId) {
    final text = raw.trim();
    final lower = text.toLowerCase();

    NoteType type = NoteType.text;
    if (lower.contains('http://') ||
        lower.contains('https://') ||
        lower.contains('www.')) {
      type = NoteType.link;
    } else if (lower.contains('password') ||
        lower.contains('secret') ||
        lower.contains(' pin ') ||
        lower.contains('credential')) {
      type = NoteType.secret;
    } else if (text.contains('\n') &&
        (lower.contains('- ') ||
            lower.contains('* ') ||
            RegExp(r'^\d+\.', multiLine: true).hasMatch(text))) {
      type = NoteType.list;
    }

    String title = '';
    String content = text;
    final lines = text.split('\n');
    if (lines.length > 1 && lines[0].trim().length < 60) {
      title = lines[0].trim();
      content = lines.sublist(1).join('\n').trim();
    }

    NoteColor color = NoteColor.yellow;
    if (type == NoteType.link) {
      color = NoteColor.blue;
    } else if (type == NoteType.secret) {
      color = NoteColor.purple;
    } else if (type == NoteType.list) {
      color = NoteColor.green;
    }

    final isPinned = lower.contains('important') ||
        lower.contains('pin this') ||
        lower.contains("don't forget");

    return _ParsedNote(
      title: title,
      content: content,
      walletId: walletId,
      color: color,
      type: type,
      isPinned: isPinned,
    );
  }
}

class _NoteAiHint extends StatelessWidget {
  final bool isDark;
  final Color accent;
  const _NoteAiHint({required this.isDark, required this.accent});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: accent.withValues(alpha: 0.2)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('✨', style: TextStyle(fontSize: 15)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Describe your note in plain English — Claude AI will extract the title, content, type, and color.',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Nunito',
              color: isDark ? AppColors.textDark : AppColors.textLight,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );
}

class _NoteAiInputBox extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isDark, isParsing;
  final Color accent;
  final VoidCallback onParse;

  const _NoteAiInputBox({
    required this.ctrl,
    required this.isDark,
    required this.accent,
    required this.isParsing,
    required this.onParse,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    return Container(
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: TextField(
              controller: ctrl,
              maxLines: 3,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(fontSize: 14, color: tc, fontFamily: 'Nunito'),
              decoration: InputDecoration.collapsed(
                hintText:
                    '"Team meeting notes: action items for Ravi, Priya and me"',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: sub,
                  fontFamily: 'Nunito',
                  height: 1.4,
                ),
              ),
            ),
          ),
          Divider(
            height: 1,
            indent: 14,
            endIndent: 14,
            color: accent.withValues(alpha: 0.15),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 10, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Type anything — AI will figure out the rest',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Nunito',
                      color: sub,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: isParsing ? null : onParse,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isParsing
                          ? accent.withValues(alpha: 0.4)
                          : accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: isParsing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '✨ Parse',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteErrorBanner extends StatelessWidget {
  final String message;
  const _NoteErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.red.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded,
            color: Colors.red, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Nunito',
              color: Colors.red,
            ),
          ),
        ),
      ],
    ),
  );
}

class _NoteAiPreviewCard extends StatelessWidget {
  final _ParsedNote preview;
  final bool isDark, usedClaudeAI;
  final Color accent;
  final VoidCallback onEdit;

  const _NoteAiPreviewCard({
    required this.preview,
    required this.isDark,
    required this.accent,
    required this.usedClaudeAI,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final noteAccent = preview.color.accent(isDark);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI badge + edit button
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: usedClaudeAI
                      ? const Color(0xFF7C3AED).withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  usedClaudeAI ? '✨ Claude AI' : '🔍 Local NLP',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Nunito',
                    color: usedClaudeAI
                        ? const Color(0xFF7C3AED)
                        : Colors.orange,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onEdit,
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 12, color: sub),
                    const SizedBox(width: 4),
                    Text(
                      'Edit',
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
            ],
          ),
          const SizedBox(height: 10),

          // Color + type + pin chips
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: noteAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                preview.color.label,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                  color: sub,
                ),
              ),
              const SizedBox(width: 12),
              Icon(preview.type.icon, size: 12, color: sub),
              const SizedBox(width: 4),
              Text(
                preview.type.label,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                  color: sub,
                ),
              ),
              if (preview.isPinned) ...[
                const SizedBox(width: 12),
                Icon(Icons.push_pin_rounded, size: 12, color: sub),
                const SizedBox(width: 4),
                Text(
                  'Pinned',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w600,
                    color: sub,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Title
          if (preview.title.isNotEmpty) ...[
            Text(
              preview.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                fontFamily: 'Nunito',
                color: tc,
              ),
            ),
            const SizedBox(height: 6),
          ],

          // Content preview
          if (preview.content.isNotEmpty)
            Text(
              preview.type == NoteType.secret
                  ? '🔒 ••••••••••••'
                  : preview.content.length > 120
                      ? '${preview.content.substring(0, 120)}…'
                      : preview.content,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Nunito',
                color: sub,
                height: 1.45,
              ),
            ),
        ],
      ),
    );
  }
}

class _NoteExamples extends StatelessWidget {
  final bool isDark;
  final Color accent;
  final void Function(String) onTap;

  const _NoteExamples({
    required this.isDark,
    required this.accent,
    required this.onTap,
  });

  static const _examples = [
    'Team meeting today — action items: update landing page, call vendor, send report',
    'Groceries: milk, eggs, bread, tomatoes, onions, coriander',
    'https://github.com/flutter/flutter — good reference for animations',
    'Password for bank account login PIN important',
  ];

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TRY AN EXAMPLE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
            color: sub,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        ..._examples.map(
          (ex) => GestureDetector(
            onTap: () => onTap(ex),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withValues(alpha: 0.15)),
              ),
              child: Text(
                '"$ex"',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Nunito',
                  fontStyle: FontStyle.italic,
                  color: sub,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
      ],
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
