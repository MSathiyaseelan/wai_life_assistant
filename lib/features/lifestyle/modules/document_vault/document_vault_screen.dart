import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyle_models.dart';
import '../../widgets/life_widgets.dart';

class DocumentVaultScreen extends StatefulWidget {
  final String walletId;
  const DocumentVaultScreen({super.key, required this.walletId});
  @override
  State<DocumentVaultScreen> createState() => _DocumentVaultScreenState();
}

class _DocumentVaultScreenState extends State<DocumentVaultScreen> {
  final List<VaultDocument> _docs = List.from(mockDocuments);
  DocCategory? _filter;
  String _search = '';
  String _selectedMember = 'all';

  List<VaultDocument> get _filtered {
    var list = _docs.where((d) => d.walletId == widget.walletId).toList();
    if (_selectedMember != 'all')
      list = list.where((d) => d.memberId == _selectedMember).toList();
    if (_filter != null)
      list = list.where((d) => d.category == _filter).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where(
            (d) =>
                d.title.toLowerCase().contains(q) ||
                (d.docNo?.toLowerCase().contains(q) ?? false) ||
                (d.issuedBy?.toLowerCase().contains(q) ?? false) ||
                d.tags.any((t) => t.toLowerCase().contains(q)),
          )
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    const color = Color(0xFFFFAA2C);

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
            Text('🗂️', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'Document Vault',
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
        onPressed: () => _showAdd(context, isDark, surfBg),
        backgroundColor: color,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Document',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
          ),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: cardBg,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: surfBg,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: AppColors.subLight,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      style: TextStyle(
                        fontSize: 13,
                        color: tc,
                        fontFamily: 'Nunito',
                      ),
                      decoration: InputDecoration.collapsed(
                        hintText: 'Search documents…',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: sub,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Member filter
          Container(
            color: cardBg,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _MemberChip(
                    label: 'Everyone',
                    emoji: '👨‍👩‍👧‍👦',
                    selected: _selectedMember == 'all',
                    color: color,
                    onTap: () => setState(() => _selectedMember = 'all'),
                  ),
                  ...mockLifeMembers.map(
                    (m) => _MemberChip(
                      label: m.name,
                      emoji: m.emoji,
                      selected: _selectedMember == m.id,
                      color: color,
                      onTap: () => setState(() => _selectedMember = m.id),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Category filter
          Container(
            color: cardBg,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _MemberChip(
                    label: 'All',
                    emoji: '📄',
                    selected: _filter == null,
                    color: color,
                    onTap: () => setState(() => _filter = null),
                  ),
                  ...DocCategory.values.map(
                    (c) => _MemberChip(
                      label: c.label,
                      emoji: c.emoji,
                      selected: _filter == c,
                      color: c.color,
                      onTap: () => setState(() => _filter = c),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? const LifeEmptyState(
                    emoji: '🗂️',
                    title: 'No documents found',
                    subtitle: 'Scan and store your important documents safely',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DocCard(
                        doc: _filtered[i],
                        isDark: isDark,
                        onTap: () => showLifeSheet(
                          context,
                          child: _DocDetail(doc: _filtered[i], isDark: isDark),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showAdd(BuildContext ctx, bool isDark, Color surfBg) {
    const color = Color(0xFFFFAA2C);
    final titleCtrl = TextEditingController();
    final docNoCtrl = TextEditingController();
    final issuedCtrl = TextEditingController();
    final expCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
    var cat = DocCategory.identity;
    var member = 'me';
    showLifeSheet(
      ctx,
      child: StatefulBuilder(
        builder: (ctx2, ss) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Document',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const LifeLabel(text: 'CATEGORY'),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: DocCategory.values
                      .map(
                        (c) => GestureDetector(
                          onTap: () => ss(() => cat = c),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: cat == c
                                  ? c.color.withOpacity(0.15)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: cat == c ? c.color : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  c.emoji,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  c.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                    color: cat == c
                                        ? c.color
                                        : (isDark
                                              ? AppColors.subDark
                                              : AppColors.subLight),
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
              const LifeLabel(text: 'BELONGS TO'),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: mockLifeMembers
                      .map(
                        (m) => GestureDetector(
                          onTap: () => ss(() => member = m.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: member == m.id
                                  ? color.withOpacity(0.15)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: member == m.id
                                    ? color
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  m.emoji,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  m.name,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                    color: member == m.id
                                        ? color
                                        : (isDark
                                              ? AppColors.subDark
                                              : AppColors.subLight),
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
              const SizedBox(height: 8),
              LifeInput(controller: titleCtrl, hint: 'Document title *'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LifeInput(
                      controller: docNoCtrl,
                      hint: 'Doc. Number',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LifeInput(controller: issuedCtrl, hint: 'Issued by'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LifeInput(controller: expCtrl, hint: 'Expiry date (optional)'),
              const SizedBox(height: 8),
              LifeInput(controller: notesCtrl, hint: 'Notes', maxLines: 2),
              const SizedBox(height: 8),
              LifeInput(controller: tagsCtrl, hint: 'Tags (comma-separated)'),
              // Scan placeholder
              const SizedBox(height: 12),
              Container(
                height: 72,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: surfBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.document_scanner_rounded,
                      color: color.withOpacity(0.5),
                      size: 26,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Scan / Attach document',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Nunito',
                        color: color.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              LifeSaveButton(
                label: 'Save Document',
                color: cat.color,
                onTap: () {
                  if (titleCtrl.text.trim().isEmpty) return;
                  final tags = tagsCtrl.text.trim().isEmpty
                      ? <String>[]
                      : tagsCtrl.text
                            .trim()
                            .split(',')
                            .map((t) => t.trim())
                            .toList();
                  setState(
                    () => _docs.add(
                      VaultDocument(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: titleCtrl.text.trim(),
                        walletId: widget.walletId,
                        memberId: member,
                        category: cat,
                        docNo: docNoCtrl.text.trim().isEmpty
                            ? null
                            : docNoCtrl.text.trim(),
                        issuedBy: issuedCtrl.text.trim().isEmpty
                            ? null
                            : issuedCtrl.text.trim(),
                        expiryDate: expCtrl.text.trim().isEmpty
                            ? null
                            : expCtrl.text.trim(),
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                        tags: tags,
                        thumbnailEmoji: cat.emoji,
                      ),
                    ),
                  );
                  Navigator.pop(ctx);
                },
              ),
              //),
              //),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberChip extends StatelessWidget {
  final String label, emoji;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _MemberChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : surfBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                fontFamily: 'Nunito',
                color: selected ? color : sub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  final VaultDocument doc;
  final bool isDark;
  final VoidCallback onTap;
  const _DocCard({
    required this.doc,
    required this.isDark,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final color = doc.category.color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          doc.thumbnailEmoji ?? doc.category.emoji,
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            doc.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                              color: tc,
                            ),
                          ),
                        ),
                        LifeBadge(text: doc.category.label, color: color),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (doc.docNo != null)
                      Text(
                        doc.docNo!,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'DM Mono',
                          color: sub,
                        ),
                      ),
                    if (doc.issuedBy != null)
                      LifeInfoRow(
                        icon: Icons.business_rounded,
                        label: doc.issuedBy!,
                      ),
                    if (doc.tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 5,
                        children: doc.tags
                            .map(
                              (t) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  t,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontFamily: 'Nunito',
                                    color: color,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocDetail extends StatelessWidget {
  final VaultDocument doc;
  final bool isDark;
  const _DocDetail({required this.doc, required this.isDark});
  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final member = mockLifeMembers.firstWhere(
      (m) => m.id == doc.memberId,
      orElse: () => const LifeMember(id: '?', name: '?', emoji: '👤'),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(doc.category.emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                    LifeBadge(
                      text: doc.category.label,
                      color: doc.category.color,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.income.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Text(member.emoji, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text(
                      member.name,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito',
                        color: AppColors.income,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (doc.docNo != null)
            LifeInfoRow(
              icon: Icons.numbers_rounded,
              label: 'Doc No: ${doc.docNo!}',
            ),
          if (doc.issuedBy != null)
            LifeInfoRow(
              icon: Icons.business_rounded,
              label: 'Issued by: ${doc.issuedBy!}',
            ),
          if (doc.issuedDate != null)
            LifeInfoRow(
              icon: Icons.calendar_today_rounded,
              label: 'Issued: ${doc.issuedDate!}',
            ),
          if (doc.expiryDate != null)
            LifeInfoRow(
              icon: Icons.event_busy_rounded,
              label: 'Expiry: ${doc.expiryDate!}',
              color: AppColors.expense,
            ),
          if (doc.notes != null)
            LifeInfoRow(icon: Icons.notes_rounded, label: doc.notes!),
          if (doc.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 5,
              children: doc.tags
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: doc.category.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'Nunito',
                          color: doc.category.color,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            height: 90,
            width: double.infinity,
            decoration: BoxDecoration(
              color: surfBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: doc.category.color.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.document_scanner_rounded,
                  size: 28,
                  color: doc.category.color.withOpacity(0.5),
                ),
                const SizedBox(height: 6),
                Text(
                  doc.filePath != null
                      ? 'Tap to view scan'
                      : 'No scan attached',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Nunito',
                    color: doc.category.color.withOpacity(0.7),
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
