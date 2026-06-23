import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/services/issue_report_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// REPORT ISSUE SHEET
// Tabbed sheet: [New Report] [My Reports]
// ─────────────────────────────────────────────────────────────────────────────

class ReportIssueSheet extends StatefulWidget {
  final bool isDark;
  const ReportIssueSheet({super.key, required this.isDark});

  @override
  State<ReportIssueSheet> createState() => _ReportIssueSheetState();
}

class _ReportIssueSheetState extends State<ReportIssueSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Color get _bg   => widget.isDark ? AppColors.cardDark  : AppColors.cardLight;
  Color get _tc   => widget.isDark ? AppColors.textDark  : AppColors.textLight;
  Color get _sub  => widget.isDark ? AppColors.subDark   : AppColors.subLight;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: _sub.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
            child: Row(
              children: [
                Text('Report Issue',
                    style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito', color: _tc,
                    )),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: _sub, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              controller: _tab,
              labelColor: AppColors.primary,
              unselectedLabelColor: _sub,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 13),
              tabs: const [
                Tab(text: 'New Report'),
                Tab(text: 'My Reports'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _NewReportTab(isDark: widget.isDark, onSubmitted: () => _tab.animateTo(1)),
                _MyReportsTab(isDark: widget.isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NEW REPORT TAB
// ─────────────────────────────────────────────────────────────────────────────

class _NewReportTab extends StatefulWidget {
  final bool isDark;
  final VoidCallback onSubmitted;
  const _NewReportTab({required this.isDark, required this.onSubmitted});

  @override
  State<_NewReportTab> createState() => _NewReportTabState();
}

class _NewReportTabState extends State<_NewReportTab> {
  final _formKey  = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();

  String _category = 'bug';
  String _priority = 'medium';
  final List<String> _localPaths = [];
  bool _submitting = false;

  static const _categories = [
    ('bug',             '🐛', 'Bug'),
    ('crash',          '💥', 'Crash'),
    ('feature_request','💡', 'Feature Request'),
    ('performance',    '⚡', 'Performance'),
    ('ui',             '🎨', 'UI / UX'),
    ('other',          '💬', 'Other'),
  ];

  static const _priorities = [
    ('low',    '🟢', 'Low'),
    ('medium', '🟡', 'Medium'),
    ('high',   '🔴', 'High'),
  ];

  Color get _surf => widget.isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
  Color get _tc   => widget.isDark ? AppColors.textDark : AppColors.textLight;
  Color get _sub  => widget.isDark ? AppColors.subDark  : AppColors.subLight;
  Color get _hint => widget.isDark ? const Color(0xFF666680) : const Color(0xFFAAAAAA);

  Future<void> _pickImage() async {
    if (_localPaths.length >= 4) return;
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImageSourcePicker(isDark: widget.isDark),
    );
    if (src == null) return;
    final img = await ImagePicker().pickImage(source: src, imageQuality: 80);
    if (img == null) return;
    setState(() => _localPaths.add(img.path));
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await IssueReportService.instance.submit(
        category: _category,
        title: _titleCtrl.text,
        description: _descCtrl.text,
        priority: _priority,
        localScreenshotPaths: _localPaths,
      );
      if (!mounted) return;
      // Clear the form
      _titleCtrl.clear();
      _descCtrl.clear();
      setState(() {
        _category = 'bug';
        _priority = 'medium';
        _localPaths.clear();
      });
      _formKey.currentState?.reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted — thank you!'),
            backgroundColor: Color(0xFF2ECC71)),
      );
      widget.onSubmitted();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e'),
            backgroundColor: Colors.red.shade400),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [

          // ── Category ────────────────────────────────────────────────────
          _Label('Category', _sub),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _categories.map((c) {
              final selected = _category == c.$1;
              return GestureDetector(
                onTap: () => setState(() => _category = c.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : _surf,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? AppColors.primary : _sub.withAlpha(40),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(c.$2, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(c.$3,
                          style: TextStyle(
                            fontSize: 12, fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : _tc,
                          )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // ── Priority ────────────────────────────────────────────────────
          _Label('Priority', _sub),
          const SizedBox(height: 8),
          Row(
            children: _priorities.map((p) {
              final selected = _priority == p.$1;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _priority = p.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: EdgeInsets.only(right: p.$1 != 'high' ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary.withAlpha(20) : _surf,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? AppColors.primary : _sub.withAlpha(40),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(p.$2, style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 3),
                        Text(p.$3,
                            style: TextStyle(
                              fontSize: 11, fontFamily: 'Nunito',
                              fontWeight: FontWeight.w700,
                              color: selected ? AppColors.primary : _sub,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // ── Title ───────────────────────────────────────────────────────
          _Label('Title', _sub),
          const SizedBox(height: 8),
          TextFormField(
            controller: _titleCtrl,
            style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: _tc),
            decoration: _inputDeco('Short summary of the issue', _surf, _hint),
            validator: (v) => (v?.trim().isEmpty ?? true) ? 'Title is required' : null,
          ),

          const SizedBox(height: 16),

          // ── Description ─────────────────────────────────────────────────
          _Label('Description', _sub),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descCtrl,
            style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: _tc),
            decoration: _inputDeco(
              'Describe what happened, steps to reproduce, and what you expected…',
              _surf, _hint,
            ),
            maxLines: 5,
            minLines: 4,
            validator: (v) => (v?.trim().isEmpty ?? true) ? 'Description is required' : null,
          ),

          const SizedBox(height: 20),

          // ── Screenshots ─────────────────────────────────────────────────
          Row(
            children: [
              _Label('Screenshots', _sub),
              const Spacer(),
              Text('(up to 4)', style: TextStyle(fontSize: 11, fontFamily: 'Nunito', color: _hint)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 88,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ..._localPaths.asMap().entries.map((e) => _ScreenshotThumb(
                  path: e.value,
                  onRemove: () => setState(() => _localPaths.removeAt(e.key)),
                )),
                if (_localPaths.length < 4)
                  _AddPhotoButton(surf: _surf, sub: _sub, onTap: _pickImage),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Submit ──────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Report',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'Nunito')),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint, Color fill, Color hintColor) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: hintColor),
    filled: true,
    fillColor: fill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade300)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MY REPORTS TAB
// ─────────────────────────────────────────────────────────────────────────────

class _MyReportsTab extends StatefulWidget {
  final bool isDark;
  const _MyReportsTab({required this.isDark});

  @override
  State<_MyReportsTab> createState() => _MyReportsTabState();
}

class _MyReportsTabState extends State<_MyReportsTab> {
  List<IssueReport>? _reports;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await IssueReportService.instance.fetchMyReports();
      if (mounted) setState(() { _reports = r; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Color get _sub => widget.isDark ? AppColors.subDark : AppColors.subLight;
  Color get _tc  => widget.isDark ? AppColors.textDark : AppColors.textLight;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Failed to load', style: TextStyle(color: _sub)),
          const SizedBox(height: 8),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }
    if (_reports == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_reports!.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('📋', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text('No reports yet', style: TextStyle(
            fontSize: 14, fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: _tc)),
          const SizedBox(height: 4),
          Text('Submit your first issue via the New Report tab',
              style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: _sub)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        itemCount: _reports!.length,
        separatorBuilder: (_, i) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _IssueCard(
          report: _reports![i],
          isDark: widget.isDark,
          onDelete: () async {
            await IssueReportService.instance.deleteReport(_reports![i].id);
            _load();
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ISSUE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _IssueCard extends StatefulWidget {
  final IssueReport report;
  final bool isDark;
  final VoidCallback onDelete;
  const _IssueCard({required this.report, required this.isDark, required this.onDelete});

  @override
  State<_IssueCard> createState() => _IssueCardState();
}

class _IssueCardState extends State<_IssueCard> {
  bool _expanded = false;

  Color get _surf => widget.isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
  Color get _tc   => widget.isDark ? AppColors.textDark : AppColors.textLight;
  Color get _sub  => widget.isDark ? AppColors.subDark  : AppColors.subLight;

  Color _statusColor(String s) => switch (s) {
    'in_progress' => const Color(0xFF3B82F6),
    'resolved'    => const Color(0xFF2ECC71),
    'closed'      => const Color(0xFF9CA3AF),
    _             => const Color(0xFFF59E0B),
  };

  Color _priorityColor(String p) => switch (p) {
    'high' => const Color(0xFFEF4444),
    'low'  => const Color(0xFF2ECC71),
    _      => const Color(0xFFF59E0B),
  };

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final statusColor = _statusColor(r.status);
    final fmt = DateFormat('dd MMM yyyy · hh:mm a');

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        decoration: BoxDecoration(
          color: _surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withAlpha(60)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                children: [
                  Text(r.categoryEmoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.title,
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito', color: _tc,
                            ),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(fmt.format(r.createdAt.toLocal()),
                            style: TextStyle(fontSize: 10, fontFamily: 'Nunito', color: _sub)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(24),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(r.statusLabel,
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito', color: statusColor,
                        )),
                  ),
                  const SizedBox(width: 4),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18, color: _sub),
                ],
              ),
            ),

            // ── Expanded detail ───────────────────────────────────────────
            if (_expanded) ...[
              Divider(height: 1, color: _sub.withAlpha(30)),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category + priority row
                    Row(children: [
                      _Chip(label: r.categoryLabel, color: AppColors.primary),
                      const SizedBox(width: 6),
                      _Chip(label: r.priorityLabel,
                          color: _priorityColor(r.priority)),
                    ]),
                    const SizedBox(height: 10),

                    // Description
                    if (r.description.isNotEmpty) ...[
                      Text('Description',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito', color: _sub)),
                      const SizedBox(height: 4),
                      Text(r.description,
                          style: TextStyle(fontSize: 12, fontFamily: 'Nunito', color: _tc)),
                      const SizedBox(height: 12),
                    ],

                    // Screenshots
                    if (r.screenshots.isNotEmpty) ...[
                      Text('Screenshots',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito', color: _sub)),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 72,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: r.screenshots.length,
                          separatorBuilder: (_, i) => const SizedBox(width: 8),
                          itemBuilder: (ctx, i) => GestureDetector(
                            onTap: () => _showImageFull(ctx, r.screenshots[i]),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(r.screenshots[i],
                                  width: 72, height: 72, fit: BoxFit.cover),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Admin note
                    if (r.adminNote?.isNotEmpty == true) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withAlpha(15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF6C63FF).withAlpha(40)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('💬', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Team Response',
                                      style: TextStyle(fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'Nunito',
                                          color: Color(0xFF6C63FF))),
                                  const SizedBox(height: 3),
                                  Text(r.adminNote!,
                                      style: TextStyle(fontSize: 12,
                                          fontFamily: 'Nunito', color: _tc)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Delete (only open reports)
                    if (r.status == 'open')
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: widget.onDelete,
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 16, color: Colors.red),
                          label: const Text('Delete',
                              style: TextStyle(
                                fontSize: 12, fontFamily: 'Nunito',
                                color: Colors.red, fontWeight: FontWeight.w700,
                              )),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showImageFull(BuildContext ctx, String url) {
    showDialog(
      context: ctx,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  final Color color;
  const _Label(this.text, this.color);

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
          letterSpacing: 0.8, fontFamily: 'Nunito', color: color));
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: color.withAlpha(24),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
            fontFamily: 'Nunito', color: color)),
  );
}

class _ScreenshotThumb extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;
  const _ScreenshotThumb({required this.path, required this.onRemove});

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Container(
        width: 80, height: 80,
        margin: const EdgeInsets.only(right: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(File(path), fit: BoxFit.cover),
        ),
      ),
      Positioned(
        top: 2, right: 10,
        child: GestureDetector(
          onTap: onRemove,
          child: Container(
            width: 20, height: 20,
            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
            child: const Icon(Icons.close, size: 12, color: Colors.white),
          ),
        ),
      ),
    ],
  );
}

class _AddPhotoButton extends StatelessWidget {
  final Color surf, sub;
  final VoidCallback onTap;
  const _AddPhotoButton({required this.surf, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 80, height: 80,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sub.withAlpha(60), style: BorderStyle.solid),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined, color: sub, size: 24),
          const SizedBox(height: 4),
          Text('Add', style: TextStyle(fontSize: 10, fontFamily: 'Nunito', color: sub)),
        ],
      ),
    ),
  );
}

class _ImageSourcePicker extends StatelessWidget {
  final bool isDark;
  const _ImageSourcePicker({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg  = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc  = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark  : AppColors.subLight;

    return Container(
      decoration: BoxDecoration(
        color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4,
            decoration: BoxDecoration(color: sub.withAlpha(80), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            leading: Icon(Icons.camera_alt_rounded, color: AppColors.primary),
            title: Text('Camera', style: TextStyle(fontFamily: 'Nunito', color: tc, fontWeight: FontWeight.w700)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: Icon(Icons.photo_library_rounded, color: AppColors.primary),
            title: Text('Gallery', style: TextStyle(fontFamily: 'Nunito', color: tc, fontWeight: FontWeight.w700)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );
  }
}
