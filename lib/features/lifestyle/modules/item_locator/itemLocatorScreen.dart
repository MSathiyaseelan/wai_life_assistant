import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyle_models.dart';
import '../../widgets/life_widgets.dart';

const _locatorColor = Color(0xFF6C63FF);

// ─────────────────────────────────────────────────────────────────────────────
// ITEM LOCATOR — ROOT SCREEN
// Two views: (A) Container shelf map  (B) Search results
// ─────────────────────────────────────────────────────────────────────────────

class ItemLocatorScreen extends StatefulWidget {
  final String walletId;
  const ItemLocatorScreen({super.key, required this.walletId});
  @override
  State<ItemLocatorScreen> createState() => _ItemLocatorScreenState();
}

class _ItemLocatorScreenState extends State<ItemLocatorScreen> {
  final List<StorageContainer> _containers = List.from(mockContainers);
  final List<StoredItem> _items = List.from(mockStoredItems);
  final _searchCtrl = TextEditingController();
  bool _isSearching = false;
  String _query = '';

  // filter by walletId
  List<StorageContainer> get _myContainers =>
      _containers.where((c) => c.walletId == widget.walletId).toList();

  List<StoredItem> get _myItems =>
      _items.where((i) => i.walletId == widget.walletId).toList();

  // items for a specific container
  List<StoredItem> itemsIn(String cid) =>
      _myItems.where((i) => i.containerId == cid).toList();

  // search across all items
  List<_SearchResult> get _searchResults {
    if (_query.trim().isEmpty) return [];
    final q = _query.toLowerCase();
    final results = <_SearchResult>[];
    for (final item in _myItems) {
      final matches =
          item.name.toLowerCase().contains(q) ||
          (item.description?.toLowerCase().contains(q) ?? false) ||
          (item.category?.toLowerCase().contains(q) ?? false) ||
          (item.notes?.toLowerCase().contains(q) ?? false);
      if (matches) {
        final container = _myContainers.firstWhere(
          (c) => c.id == item.containerId,
          orElse: () => StorageContainer(
            id: '?',
            walletId: widget.walletId,
            type: StorageType.other,
            name: 'Unknown',
          ),
        );
        results.add(_SearchResult(item: item, container: container));
      }
    }
    return results;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

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
            Text('📍', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'Item Locator',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
              ),
            ),
          ],
        ),
        actions: [
          // Add container button
          IconButton(
            icon: const Icon(Icons.create_new_folder_rounded),
            tooltip: 'Add Container',
            onPressed: () => _showAddContainer(context, isDark, surfBg),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddItem(context, isDark, surfBg),
        backgroundColor: _locatorColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Store Item',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
          ),
        ),
      ),

      body: Column(
        children: [
          // ── Search bar ─────────────────────────────────────────────────────
          Container(
            color: cardBg,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() {
                _query = v;
                _isSearching = v.trim().isNotEmpty;
              }),
              onTap: () => setState(() => _isSearching = _query.isNotEmpty),
              style: TextStyle(fontSize: 14, fontFamily: 'Nunito', color: tc),
              decoration: InputDecoration(
                hintText: 'Search items across all containers…',
                hintStyle: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Nunito',
                  color: sub,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _locatorColor,
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => setState(() {
                          _searchCtrl.clear();
                          _query = '';
                          _isSearching = false;
                        }),
                      )
                    : null,
                filled: true,
                fillColor: surfBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // ── Body: search results OR shelf map ──────────────────────────────
          Expanded(
            child: _isSearching
                ? _SearchResultsView(
                    results: _searchResults,
                    query: _query,
                    isDark: isDark,
                    cardBg: cardBg,
                    onItemTap: (r) =>
                        _showItemDetail(context, r.item, r.container, isDark),
                  )
                : _ShelfMapView(
                    containers: _myContainers,
                    itemsIn: itemsIn,
                    isDark: isDark,
                    cardBg: cardBg,
                    surfBg: surfBg,
                    onContainerTap: (c) =>
                        _pushContainerDetail(context, c, isDark, surfBg),
                    onAddContainer: () =>
                        _showAddContainer(context, isDark, surfBg),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Push to container detail ───────────────────────────────────────────────
  void _pushContainerDetail(
    BuildContext ctx,
    StorageContainer c,
    bool isDark,
    Color surfBg,
  ) {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => _ContainerDetailScreen(
          container: c,
          items: itemsIn(c.id),
          isDark: isDark,
          onAddItem: () => _showAddItem(ctx, isDark, surfBg, preselected: c),
          onDeleteItem: (item) => setState(() => _items.remove(item)),
          onEditItem: (item) => _showEditItem(ctx, item, isDark, surfBg),
          onDeleteContainer: () {
            setState(() {
              _items.removeWhere((i) => i.containerId == c.id);
              _containers.remove(c);
            });
            Navigator.pop(ctx);
          },
          onEditContainer: () => _showEditContainer(ctx, c, isDark, surfBg),
        ),
      ),
    );
  }

  // ── Item detail bottom sheet ───────────────────────────────────────────────
  void _showItemDetail(
    BuildContext ctx,
    StoredItem item,
    StorageContainer container,
    bool isDark,
  ) {
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;

    showLifeSheet(
      ctx,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: container.type.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    item.emoji ?? container.type.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito',
                          color: tc,
                        ),
                      ),
                      if (item.category != null)
                        Text(
                          item.category!,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Nunito',
                            color: sub,
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (item.isImportant)
                      _TagChip('⭐ Important', AppColors.lend),
                    if (item.isFragile) ...[
                      const SizedBox(width: 6),
                      _TagChip('🥚 Fragile', AppColors.expense),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Location highlight
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_locatorColor, _locatorColor.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Text('📍', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Stored in',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                            fontFamily: 'Nunito',
                          ),
                        ),
                        Text(
                          '${container.type.emoji}  ${container.name}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Nunito',
                          ),
                        ),
                        if (container.location != null)
                          Text(
                            '📌 ${container.location}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontFamily: 'Nunito',
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Details
            if (item.description != null) ...[
              LifeInfoRow(
                icon: Icons.description_rounded,
                label: item.description!,
              ),
            ],
            if (item.notes != null)
              LifeInfoRow(
                icon: Icons.sticky_note_2_rounded,
                label: item.notes!,
              ),
            LifeInfoRow(
              icon: Icons.calendar_today_rounded,
              label: 'Stored on ${_fmtDate(item.storedOn)}',
            ),
            if (item.storedBy != null)
              Builder(
                builder: (_) {
                  final member = mockLifeMembers.firstWhere(
                    (m) => m.id == item.storedBy,
                    orElse: () =>
                        const LifeMember(id: '?', name: 'Someone', emoji: '👤'),
                  );

                  return LifeInfoRow(
                    icon: Icons.person_rounded,
                    label: 'Stored by ${member.emoji} ${member.name}',
                  );
                },
              ),
            if (container.notes != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _locatorColor.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Container hint: ${container.notes!}',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Nunito',
                          color: sub,
                        ),
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

  // ── Add Container sheet ────────────────────────────────────────────────────
  void _showAddContainer(BuildContext ctx, bool isDark, Color surfBg) {
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final colorCtrl = TextEditingController();
    var selType = StorageType.box;

    showLifeSheet(
      ctx,
      child: StatefulBuilder(
        builder: (ctx2, ss) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Storage Container',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Containers hold your items — you can have multiple of each type',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Nunito',
                  color: isDark ? AppColors.subDark : AppColors.subLight,
                ),
              ),
              const SizedBox(height: 16),

              // Type grid
              const LifeLabel(text: 'CONTAINER TYPE'),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.9,
                children: StorageType.values
                    .map(
                      (t) => GestureDetector(
                        onTap: () => ss(() => selType = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: selType == t
                                ? t.color.withOpacity(0.15)
                                : surfBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selType == t
                                  ? t.color
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                t.emoji,
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t.label,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Nunito',
                                  color: selType == t
                                      ? t.color
                                      : (isDark
                                            ? AppColors.subDark
                                            : AppColors.subLight),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),

              LifeInput(
                controller: nameCtrl,
                hint: 'Container name (e.g. "Box 1", "Bedroom Almirah") *',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LifeInput(
                      controller: locationCtrl,
                      hint: 'Location / Room (e.g. Store Room)',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LifeInput(
                      controller: colorCtrl,
                      hint: 'Color label (optional)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LifeInput(
                controller: notesCtrl,
                hint: 'Notes / Hints about this container',
                maxLines: 2,
              ),

              LifeSaveButton(
                label: 'Add Container',
                color: selType.color,
                onTap: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  setState(
                    () => _containers.add(
                      StorageContainer(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        walletId: widget.walletId,
                        type: selType,
                        name: nameCtrl.text.trim(),
                        location: locationCtrl.text.trim().isEmpty
                            ? null
                            : locationCtrl.text.trim(),
                        color: colorCtrl.text.trim().isEmpty
                            ? null
                            : colorCtrl.text.trim(),
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                      ),
                    ),
                  );
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Edit Container sheet ───────────────────────────────────────────────────
  void _showEditContainer(
    BuildContext ctx,
    StorageContainer c,
    bool isDark,
    Color surfBg,
  ) {
    final nameCtrl = TextEditingController(text: c.name);
    final locationCtrl = TextEditingController(text: c.location ?? '');
    final notesCtrl = TextEditingController(text: c.notes ?? '');
    final colorCtrl = TextEditingController(text: c.color ?? '');
    var selType = c.type;

    showLifeSheet(
      ctx,
      child: StatefulBuilder(
        builder: (ctx2, ss) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Container',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(height: 14),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.9,
                children: StorageType.values
                    .map(
                      (t) => GestureDetector(
                        onTap: () => ss(() => selType = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: selType == t
                                ? t.color.withOpacity(0.15)
                                : surfBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selType == t
                                  ? t.color
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                t.emoji,
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t.label,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Nunito',
                                  color: selType == t
                                      ? t.color
                                      : (isDark
                                            ? AppColors.subDark
                                            : AppColors.subLight),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),

              LifeInput(controller: nameCtrl, hint: 'Container name *'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LifeInput(
                      controller: locationCtrl,
                      hint: 'Location / Room',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LifeInput(
                      controller: colorCtrl,
                      hint: 'Color label',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LifeInput(
                controller: notesCtrl,
                hint: 'Notes / Hints',
                maxLines: 2,
              ),

              LifeSaveButton(
                label: 'Save Changes',
                color: selType.color,
                onTap: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  setState(() {
                    c.type = selType;
                    c.name = nameCtrl.text.trim();
                    c.location = locationCtrl.text.trim().isEmpty
                        ? null
                        : locationCtrl.text.trim();
                    c.color = colorCtrl.text.trim().isEmpty
                        ? null
                        : colorCtrl.text.trim();
                    c.notes = notesCtrl.text.trim().isEmpty
                        ? null
                        : notesCtrl.text.trim();
                  });
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Add Item sheet ─────────────────────────────────────────────────────────
  void _showAddItem(
    BuildContext ctx,
    bool isDark,
    Color surfBg, {
    StorageContainer? preselected,
  }) {
    _showItemForm(ctx, isDark, surfBg, null, preselected: preselected);
  }

  void _showEditItem(
    BuildContext ctx,
    StoredItem item,
    bool isDark,
    Color surfBg,
  ) {
    _showItemForm(ctx, isDark, surfBg, item);
  }

  void _showItemForm(
    BuildContext ctx,
    bool isDark,
    Color surfBg,
    StoredItem? editing, {
    StorageContainer? preselected,
  }) {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final descCtrl = TextEditingController(text: editing?.description ?? '');
    final notesCtrl = TextEditingController(text: editing?.notes ?? '');
    final catCtrl = TextEditingController(text: editing?.category ?? '');
    final emojiCtrl = TextEditingController(text: editing?.emoji ?? '');
    var selCid =
        editing?.containerId ??
        preselected?.id ??
        _myContainers.firstOrNull?.id ??
        '';
    var selMember = editing?.storedBy ?? 'me';
    var isFragile = editing?.isFragile ?? false;
    var isImportant = editing?.isImportant ?? false;

    final cats = [
      'Documents',
      'Clothes',
      'Electronics',
      'Jewellery',
      'Kitchen',
      'Medicine',
      'Festival',
      'Keys',
      'Memories',
      'Grocery',
      'Other',
    ];

    if (_myContainers.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('Add a container first before storing items'),
        ),
      );
      return;
    }

    showLifeSheet(
      ctx,
      child: StatefulBuilder(
        builder: (ctx2, ss) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                editing == null ? 'Store an Item' : 'Edit Item',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(height: 16),

              // Container picker
              const LifeLabel(text: 'STORE IN (CONTAINER)'),
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _myContainers
                      .map(
                        (c) => GestureDetector(
                          onTap: () => ss(() => selCid = c.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: selCid == c.id
                                  ? c.type.color.withOpacity(0.15)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selCid == c.id
                                    ? c.type.color
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  c.type.emoji,
                                  style: const TextStyle(fontSize: 18),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  c.name,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                    color: selCid == c.id
                                        ? c.type.color
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
              const SizedBox(height: 12),

              // Item name + emoji
              Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: LifeInput(controller: emojiCtrl, hint: '📦'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LifeInput(controller: nameCtrl, hint: 'Item name *'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Category chips
              const LifeLabel(text: 'CATEGORY'),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: cats
                      .map(
                        (cat) => GestureDetector(
                          onTap: () => ss(() => catCtrl.text = cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 110),
                            margin: const EdgeInsets.only(right: 7),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: catCtrl.text == cat
                                  ? _locatorColor.withOpacity(0.12)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: catCtrl.text == cat
                                    ? _locatorColor
                                    : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Nunito',
                                color: catCtrl.text == cat
                                    ? _locatorColor
                                    : (isDark
                                          ? AppColors.subDark
                                          : AppColors.subLight),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 10),

              LifeInput(controller: descCtrl, hint: 'Description (optional)'),
              const SizedBox(height: 8),
              LifeInput(
                controller: notesCtrl,
                hint: 'Hint / notes (e.g. "in the small zipper pocket")',
                maxLines: 2,
              ),
              const SizedBox(height: 12),

              // Stored by
              const LifeLabel(text: 'STORED BY'),
              SizedBox(
                height: 46,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: mockLifeMembers
                      .map(
                        (m) => GestureDetector(
                          onTap: () => ss(() => selMember = m.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: selMember == m.id
                                  ? _locatorColor.withOpacity(0.12)
                                  : surfBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selMember == m.id
                                    ? _locatorColor
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  m.emoji,
                                  style: const TextStyle(fontSize: 15),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  m.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                    color: selMember == m.id
                                        ? _locatorColor
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
              const SizedBox(height: 12),

              // Flags
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => ss(() => isImportant = !isImportant),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isImportant
                              ? AppColors.lend.withOpacity(0.12)
                              : surfBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isImportant
                                ? AppColors.lend
                                : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text('⭐', style: TextStyle(fontSize: 20)),
                            const SizedBox(height: 3),
                            Text(
                              'Important',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Nunito',
                                color: isImportant
                                    ? AppColors.lend
                                    : (isDark
                                          ? AppColors.subDark
                                          : AppColors.subLight),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => ss(() => isFragile = !isFragile),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isFragile
                              ? AppColors.expense.withOpacity(0.12)
                              : surfBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isFragile
                                ? AppColors.expense
                                : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text('🥚', style: TextStyle(fontSize: 20)),
                            const SizedBox(height: 3),
                            Text(
                              'Fragile',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Nunito',
                                color: isFragile
                                    ? AppColors.expense
                                    : (isDark
                                          ? AppColors.subDark
                                          : AppColors.subLight),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              LifeSaveButton(
                label: editing == null ? 'Store Item' : 'Save Changes',
                color: _locatorColor,
                onTap: () {
                  if (nameCtrl.text.trim().isEmpty || selCid.isEmpty) return;
                  setState(() {
                    if (editing != null) {
                      editing.name = nameCtrl.text.trim();
                      editing.description = descCtrl.text.trim().isEmpty
                          ? null
                          : descCtrl.text.trim();
                      editing.notes = notesCtrl.text.trim().isEmpty
                          ? null
                          : notesCtrl.text.trim();
                      editing.category = catCtrl.text.isEmpty
                          ? null
                          : catCtrl.text;
                      editing.emoji = emojiCtrl.text.trim().isEmpty
                          ? null
                          : emojiCtrl.text.trim();
                      editing.containerId = selCid;
                      editing.storedBy = selMember;
                      editing.isFragile = isFragile;
                      editing.isImportant = isImportant;
                    } else {
                      _items.add(
                        StoredItem(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          walletId: widget.walletId,
                          containerId: selCid,
                          name: nameCtrl.text.trim(),
                          description: descCtrl.text.trim().isEmpty
                              ? null
                              : descCtrl.text.trim(),
                          notes: notesCtrl.text.trim().isEmpty
                              ? null
                              : notesCtrl.text.trim(),
                          category: catCtrl.text.isEmpty ? null : catCtrl.text,
                          emoji: emojiCtrl.text.trim().isEmpty
                              ? null
                              : emojiCtrl.text.trim(),
                          storedBy: selMember,
                          isFragile: isFragile,
                          isImportant: isImportant,
                        ),
                      );
                    }
                  });
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const m = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${m[d.month]} ${d.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VIEW A — SHELF MAP (default — grouped by container)
// ─────────────────────────────────────────────────────────────────────────────

class _ShelfMapView extends StatelessWidget {
  final List<StorageContainer> containers;
  final List<StoredItem> Function(String) itemsIn;
  final bool isDark;
  final Color cardBg, surfBg;
  final void Function(StorageContainer) onContainerTap;
  final VoidCallback onAddContainer;

  const _ShelfMapView({
    required this.containers,
    required this.itemsIn,
    required this.isDark,
    required this.cardBg,
    required this.surfBg,
    required this.onContainerTap,
    required this.onAddContainer,
  });

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;

    if (containers.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📍', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 14),
          const Text(
            'No storage containers yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add a box, shelf, cupboard or almirah\nto start locating your items',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: sub),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAddContainer,
            icon: const Icon(Icons.create_new_folder_rounded, size: 16),
            label: const Text(
              'Add Container',
              style: TextStyle(fontFamily: 'Nunito'),
            ),
            style: FilledButton.styleFrom(backgroundColor: _locatorColor),
          ),
        ],
      );
    }

    // Group containers by location/room
    final grouped = <String, List<StorageContainer>>{};
    for (final c in containers) {
      final loc = c.location ?? 'Other';
      grouped.putIfAbsent(loc, () => []).add(c);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      children: [
        // Stats bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _locatorColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _locatorColor.withOpacity(0.18)),
          ),
          child: Row(
            children: [
              _StatBubble(
                '📦',
                '${containers.length}',
                'Containers',
                _locatorColor,
              ),
              _vDivider(),
              _StatBubble(
                '🏷️',
                '${containers.fold(0, (s, c) => s + itemsIn(c.id).length)}',
                'Items',
                AppColors.income,
              ),
              _vDivider(),
              _StatBubble(
                '⭐',
                '${containers.fold(0, (s, c) => s + itemsIn(c.id).where((i) => i.isImportant).length)}',
                'Important',
                AppColors.lend,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Containers grouped by room
        ...grouped.entries.map((entry) {
          final loc = entry.key;
          final cList = entry.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Room header
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 14,
                      color: _locatorColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      loc,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: _locatorColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${cList.length} container${cList.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Nunito',
                        color: sub,
                      ),
                    ),
                  ],
                ),
              ),

              // Container cards for this room
              ...cList.map((c) {
                final its = itemsIn(c.id);
                final important = its.where((i) => i.isImportant).toList();
                final fragile = its.where((i) => i.isFragile).toList();

                return GestureDetector(
                  onTap: () => onContainerTap(c),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: c.type.color.withOpacity(0.25)),
                    ),
                    child: Column(
                      children: [
                        // Container header
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: c.type.color.withOpacity(0.09),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(22),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: c.type.color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  c.type.emoji,
                                  style: const TextStyle(fontSize: 24),
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
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'Nunito',
                                        color: tc,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          c.type.label,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'Nunito',
                                            color: sub,
                                          ),
                                        ),
                                        if (c.color != null) ...[
                                          Text(
                                            ' · ',
                                            style: TextStyle(color: sub),
                                          ),
                                          Text(
                                            c.color!,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontFamily: 'Nunito',
                                              color: sub,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Item count badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: c.type.color,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${its.length} item${its.length != 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Nunito',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Items preview (max 3)
                        if (its.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Text(
                              'Empty — tap + to store items here',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Nunito',
                                color: sub,
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                            child: Column(
                              children: [
                                ...its
                                    .take(3)
                                    .map(
                                      (item) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              item.emoji ?? '📦',
                                              style: const TextStyle(
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                item.name,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  fontFamily: 'Nunito',
                                                  color: tc,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (item.isImportant)
                                              const Text(
                                                '⭐',
                                                style: TextStyle(fontSize: 11),
                                              ),
                                            if (item.isFragile)
                                              const Text(
                                                '🥚',
                                                style: TextStyle(fontSize: 11),
                                              ),
                                            if (item.category != null)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                  left: 6,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: c.type.color
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  item.category!,
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontFamily: 'Nunito',
                                                    color: c.type.color,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                                if (its.length > 3)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '+${its.length - 3} more inside →',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'Nunito',
                                        color: c.type.color,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                        // Hint / notes bar
                        if (c.notes != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: c.type.color.withOpacity(0.05),
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(22),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  '💡',
                                  style: TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    c.notes!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'Nunito',
                                      color: sub,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 6),
            ],
          );
        }).toList(),
      ],
    );
  }
}

Widget _vDivider() => Container(
  width: 1,
  height: 30,
  margin: const EdgeInsets.symmetric(horizontal: 8),
  color: _locatorColor.withOpacity(0.15),
);

class _StatBubble extends StatelessWidget {
  final String emoji, value, label;
  final Color color;
  const _StatBubble(this.emoji, this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            fontFamily: 'DM Mono',
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 9, fontFamily: 'Nunito', color: color),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// VIEW B — SEARCH RESULTS
// ─────────────────────────────────────────────────────────────────────────────

class _SearchResultsView extends StatelessWidget {
  final List<_SearchResult> results;
  final String query;
  final bool isDark;
  final Color cardBg;
  final void Function(_SearchResult) onItemTap;

  const _SearchResultsView({
    required this.results,
    required this.query,
    required this.isDark,
    required this.cardBg,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;

    if (results.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔍', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text(
            'No items found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try a different search word',
            style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: sub),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            '${results.length} result${results.length != 1 ? 's' : ''} for "$query"',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Nunito',
              color: sub,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            itemCount: results.length,
            itemBuilder: (_, i) {
              final r = results[i];
              return GestureDetector(
                onTap: () => onItemTap(r),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: r.container.type.color.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Item emoji
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: r.container.type.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          r.item.emoji ?? r.container.type.emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Item info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HighlightText(
                              text: r.item.name,
                              query: query,
                              tc: tc,
                            ),
                            const SizedBox(height: 3),
                            // WHERE IT IS — the hero info
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: r.container.type.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    r.container.type.emoji,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    r.container.name,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'Nunito',
                                      color: r.container.type.color,
                                    ),
                                  ),
                                  if (r.container.location != null) ...[
                                    Text(
                                      ' · ',
                                      style: TextStyle(
                                        color: r.container.type.color,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      r.container.location!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'Nunito',
                                        color: r.container.type.color,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (r.item.notes != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                r.item.notes!,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'Nunito',
                                  color: sub,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),
                      Column(
                        children: [
                          if (r.item.isImportant)
                            const Text('⭐', style: TextStyle(fontSize: 13)),
                          if (r.item.isFragile)
                            const Text('🥚', style: TextStyle(fontSize: 13)),
                        ],
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
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTAINER DETAIL SCREEN — full item list inside one container
// ─────────────────────────────────────────────────────────────────────────────

class _ContainerDetailScreen extends StatefulWidget {
  final StorageContainer container;
  final List<StoredItem> items;
  final bool isDark;
  final VoidCallback onAddItem, onDeleteContainer, onEditContainer;
  final void Function(StoredItem) onDeleteItem, onEditItem;

  const _ContainerDetailScreen({
    required this.container,
    required this.items,
    required this.isDark,
    required this.onAddItem,
    required this.onDeleteItem,
    required this.onEditItem,
    required this.onDeleteContainer,
    required this.onEditContainer,
  });

  @override
  State<_ContainerDetailScreen> createState() => _ContainerDetailState();
}

class _ContainerDetailState extends State<_ContainerDetailScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final c = widget.container;

    // unique categories in this container
    final cats = [
      'All',
      ...widget.items.map((i) => i.category ?? 'Other').toSet().toList()
        ..sort(),
    ];

    final filtered = _filter == 'All'
        ? widget.items
        : widget.items
              .where((i) => (i.category ?? 'Other') == _filter)
              .toList();

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
        title: Row(
          children: [
            Text(c.type.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                c.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 18),
            onPressed: widget.onEditContainer,
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.expense,
              size: 20,
            ),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'detail_fab',
        onPressed: widget.onAddItem,
        backgroundColor: c.type.color,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Item',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
          ),
        ),
      ),
      body: Column(
        children: [
          // Container hero banner
          Container(
            color: cardBg,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [c.type.color, c.type.color.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Text(c.type.emoji, style: const TextStyle(fontSize: 36)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Nunito',
                              ),
                            ),
                            if (c.location != null)
                              Text(
                                '📌 ${c.location}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontFamily: 'Nunito',
                                ),
                              ),
                            if (c.color != null)
                              Text(
                                '🎨 ${c.color}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontFamily: 'Nunito',
                                ),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            '${widget.items.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'DM Mono',
                            ),
                          ),
                          const Text(
                            'items',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                              fontFamily: 'Nunito',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (c.notes != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: c.type.color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Text('💡', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            c.notes!,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Nunito',
                              color: sub,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Category filter chips
          if (cats.length > 1)
            Container(
              color: cardBg,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: cats
                    .map(
                      (cat) => GestureDetector(
                        onTap: () => setState(() => _filter = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _filter == cat ? c.type.color : surfBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Nunito',
                              color: _filter == cat
                                  ? Colors.white
                                  : (isDark
                                        ? AppColors.subDark
                                        : AppColors.subLight),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),

          // Items list
          Expanded(
            child: filtered.isEmpty
                ? LifeEmptyState(
                    emoji: c.type.emoji,
                    title: 'Nothing here yet',
                    subtitle: 'Tap "Add Item" to store something in ${c.name}',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final item = filtered[i];
                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: AppColors.expense.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.expense,
                            size: 24,
                          ),
                        ),
                        onDismissed: (_) {
                          setState(() {});
                          widget.onDeleteItem(item);
                        },
                        child: GestureDetector(
                          onTap: () => widget.onEditItem(item),
                          onLongPress: () => widget.onEditItem(item),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: item.isImportant
                                    ? AppColors.lend.withOpacity(0.3)
                                    : c.type.color.withOpacity(0.15),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Emoji
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: c.type.color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    item.emoji ?? '📦',
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.name,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                fontFamily: 'Nunito',
                                                color: tc,
                                              ),
                                            ),
                                          ),
                                          if (item.isImportant)
                                            const Text(
                                              '⭐',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          if (item.isFragile)
                                            const Padding(
                                              padding: EdgeInsets.only(left: 4),
                                              child: Text(
                                                '🥚',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (item.description != null)
                                        Text(
                                          item.description!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'Nunito',
                                            color: sub,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      if (item.notes != null)
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.tips_and_updates_rounded,
                                              size: 11,
                                              color: c.type.color,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                item.notes!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontFamily: 'Nunito',
                                                  color: c.type.color,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (item.category != null)
                                            _ItemTag(
                                              item.category!,
                                              c.type.color,
                                            ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _fmtDate(item.storedOn),
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontFamily: 'Nunito',
                                              color: sub,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
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

  void _confirmDelete(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text(
          'Remove Container?',
          style: TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Nunito'),
        ),
        content: Text(
          'This will also remove all ${widget.items.length} item(s) stored in '
          '"${widget.container.name}". This cannot be undone.',
          style: const TextStyle(fontFamily: 'Nunito'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDeleteContainer();
            },
            child: const Text(
              'Remove All',
              style: TextStyle(color: AppColors.expense),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const m = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${m[d.month]} ${d.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  final String text;
  final Color color;
  const _TagChip(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        fontFamily: 'Nunito',
        color: color,
      ),
    ),
  );
}

class _ItemTag extends StatelessWidget {
  final String text;
  final Color color;
  const _ItemTag(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 9,
        fontFamily: 'Nunito',
        color: color,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

// Highlight matched query text in search results
class _HighlightText extends StatelessWidget {
  final String text, query;
  final Color tc;
  const _HighlightText({
    required this.text,
    required this.query,
    required this.tc,
  });
  @override
  Widget build(BuildContext context) {
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    final idx = lower.indexOf(q);
    if (idx < 0)
      return Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          fontFamily: 'Nunito',
          color: tc,
        ),
      );
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          fontFamily: 'Nunito',
          color: tc,
        ),
        children: [
          TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + query.length),
            style: const TextStyle(
              backgroundColor: Color(0x336C63FF),
              color: _locatorColor,
            ),
          ),
          TextSpan(text: text.substring(idx + query.length)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

class _SearchResult {
  final StoredItem item;
  final StorageContainer container;
  const _SearchResult({required this.item, required this.container});
}

String _fmtDate(DateTime d) {
  const m = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${d.day} ${m[d.month]} ${d.year}';
}
