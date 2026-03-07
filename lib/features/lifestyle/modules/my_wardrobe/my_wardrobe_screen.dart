import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyle_models.dart';
import '../../widgets/life_widgets.dart';

const _wardrobeColor = Color(0xFFFF5CA8);

// ── Photo picker (camera or gallery) ─────────────────────────────────────────
Future<String?> _pickPhoto(BuildContext ctx) async {
  ImageSource? source;
  await showModalBottomSheet<void>(
    context: ctx,
    backgroundColor: Colors.transparent,
    builder: (mCtx) {
      final isDark = Theme.of(mCtx).brightness == Brightness.dark;
      return Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 4),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_rounded,
                  color: _wardrobeColor,
                ),
                title: const Text(
                  'Take Photo',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () {
                  source = ImageSource.camera;
                  Navigator.pop(mCtx);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: _wardrobeColor,
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () {
                  source = ImageSource.gallery;
                  Navigator.pop(mCtx);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
  if (source == null) return null;
  final img = await ImagePicker().pickImage(source: source!, imageQuality: 75);
  return img?.path;
}

// ── Date helpers ─────────────────────────────────────────────────────────────
bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

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
  final now = DateTime.now();
  if (_sameDay(d, now)) return 'Today';
  if (_sameDay(d, now.subtract(const Duration(days: 1)))) return 'Yesterday';
  return '${d.day} ${m[d.month]}';
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class MyWardrobeScreen extends StatefulWidget {
  final String walletId;
  const MyWardrobeScreen({super.key, required this.walletId});
  @override
  State<MyWardrobeScreen> createState() => _MyWardrobeScreenState();
}

class _MyWardrobeScreenState extends State<MyWardrobeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final List<ClothingItem> _clothes = List.from(mockClothes);
  final List<OutfitLog> _outfitLogs = [];
  String _selectedMember = 'me';
  ClothingCategory? _filterCat;
  bool _searchActive = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  List<ClothingItem> get _wardrobeItems => _clothes
      .where(
        (c) =>
            c.walletId == widget.walletId &&
            c.memberId == _selectedMember &&
            !c.wishlist,
      )
      .toList();

  List<ClothingItem> get _wishlist => _clothes
      .where(
        (c) =>
            c.walletId == widget.walletId &&
            c.memberId == _selectedMember &&
            c.wishlist,
      )
      .toList();

  List<ClothingItem> get _filtered {
    var items = _wardrobeItems;
    if (_filterCat != null) {
      items = items.where((c) => c.category == _filterCat).toList();
    }
    if (_searchQuery.isNotEmpty) {
      items = items
          .where(
            (c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }
    return items;
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() {
      setState(() {
        // clear search when leaving wardrobe tab
        if (_tab.index != 0) {
          _searchActive = false;
          _searchQuery = '';
          _searchCtrl.clear();
        }
      });
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
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
        title: _searchActive
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search wardrobe…',
                  hintStyle: TextStyle(
                    fontFamily: 'Nunito',
                    color: sub,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                ),
              )
            : const Row(
                children: [
                  Text('👗', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 8),
                  Text(
                    'My Wardrobe',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ],
              ),
        actions: [
          if (_tab.index == 0)
            IconButton(
              icon: Icon(
                _searchActive ? Icons.close_rounded : Icons.search_rounded,
                size: 22,
              ),
              onPressed: () => setState(() {
                _searchActive = !_searchActive;
                if (!_searchActive) {
                  _searchQuery = '';
                  _searchCtrl.clear();
                }
              }),
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
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontFamily: 'Nunito',
            fontSize: 11,
          ),
          indicatorColor: _wardrobeColor,
          labelColor: _wardrobeColor,
          unselectedLabelColor: sub,
          tabs: const [
            Tab(text: 'Wardrobe'),
            Tab(text: 'Outfit Log'),
            Tab(text: 'Wishlist'),
          ],
        ),
      ),
      floatingActionButton: _tab.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showAddItem(context, isDark, surfBg),
              backgroundColor: _wardrobeColor,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Add Item',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Nunito',
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          // Member selector
          Container(
            color: cardBg,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: mockLifeMembers.map((m) {
                  final sel = m.id == _selectedMember;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMember = m.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: sel
                            ? _wardrobeColor.withValues(alpha: 0.12)
                            : surfBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel ? _wardrobeColor : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(m.emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            m.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Nunito',
                              color: sel ? _wardrobeColor : sub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                // WARDROBE TAB
                Column(
                  children: [
                    Container(
                      color: cardBg,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                      child: SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _CatChip(
                              label: 'All',
                              emoji: '👚',
                              selected: _filterCat == null,
                              color: _wardrobeColor,
                              onTap: () => setState(() => _filterCat = null),
                            ),
                            ...ClothingCategory.values.map(
                              (c) => _CatChip(
                                label: c.label,
                                emoji: c.emoji,
                                selected: _filterCat == c,
                                color: _wardrobeColor,
                                onTap: () =>
                                    setState(() => _filterCat = c),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: _searchQuery.isNotEmpty
                          ? _filtered.isEmpty
                              ? LifeEmptyState(
                                  emoji: '🔍',
                                  title: 'No results',
                                  subtitle:
                                      'No items match "$_searchQuery"',
                                )
                              : _SearchResultsList(
                                  items: _filtered,
                                  allItems: _clothes,
                                  outfitLogs: _outfitLogs,
                                  isDark: isDark,
                                  onTap: (item) => showLifeSheet(
                                    context,
                                    child: _ClothingDetail(
                                      item: item,
                                      isDark: isDark,
                                      allItems: _clothes,
                                      onUpdate: () => setState(() {}),
                                    ),
                                  ),
                                )
                          : _filtered.isEmpty
                              ? const LifeEmptyState(
                                  emoji: '👗',
                                  title: 'No items here',
                                  subtitle: 'Add dresses to your wardrobe',
                                )
                              : _ClothingGrid(
                                  items: _filtered,
                                  isDark: isDark,
                                  onTap: (item) => showLifeSheet(
                                    context,
                                    child: _ClothingDetail(
                                      item: item,
                                      isDark: isDark,
                                      allItems: _clothes,
                                      onUpdate: () => setState(() {}),
                                    ),
                                  ),
                                ),
                    ),
                  ],
                ),

                // OUTFIT LOG TAB
                _OutfitLogTab(
                  isDark: isDark,
                  memberId: _selectedMember,
                  allItems: _clothes
                      .where(
                        (c) =>
                            c.walletId == widget.walletId && !c.wishlist,
                      )
                      .toList(),
                  outfitLogs: _outfitLogs,
                  allMembers: mockLifeMembers,
                  onLog: (log) => setState(() {
                    _outfitLogs.removeWhere(
                      (l) =>
                          l.memberId == log.memberId &&
                          _sameDay(l.date, log.date),
                    );
                    _outfitLogs.add(log);
                  }),
                ),

                // WISHLIST TAB
                _wishlist.isEmpty
                    ? const LifeEmptyState(
                        emoji: '💛',
                        title: 'Wishlist is empty',
                        subtitle: 'Snap a dress you love and save it here',
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: _wishlist.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _WishlistCard(
                            item: _wishlist[i],
                            isDark: isDark,
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

  // ── Add clothing item ──────────────────────────────────────────────────────
  void _showAddItem(BuildContext ctx, bool isDark, Color surfBg) {
    final nameCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final sizeCtrl = TextEditingController();
    final colorCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final sourceCtrl = TextEditingController();
    var cat = ClothingCategory.topwear;
    var wishlist = _tab.index == 2;
    String? pickedPath;

    showLifeSheet(
      ctx,
      child: StatefulBuilder(
        builder: (ctx2, ss) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                wishlist ? 'Add to Wishlist' : 'Add Clothing Item',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const LifeLabel(text: 'CATEGORY'),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final c in ClothingCategory.values)
                      GestureDetector(
                        onTap: () => ss(() => cat = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: cat == c
                                ? _wardrobeColor.withValues(alpha: 0.15)
                                : surfBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: cat == c
                                  ? _wardrobeColor
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                c.emoji,
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                c.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Nunito',
                                  color: cat == c
                                      ? _wardrobeColor
                                      : (isDark
                                            ? AppColors.subDark
                                            : AppColors.subLight),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              LifeInput(controller: nameCtrl, hint: 'Item name *'),
              const SizedBox(height: 8),
              LifeInput(controller: brandCtrl, hint: 'Brand (optional)'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LifeInput(
                      controller: sizeCtrl,
                      hint: 'Size (e.g. L, 32)',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LifeInput(controller: colorCtrl, hint: 'Color'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LifeInput(
                controller: notesCtrl,
                hint: 'Notes (optional)',
                maxLines: 2,
              ),
              if (wishlist) ...[
                const SizedBox(height: 8),
                LifeInput(
                  controller: sourceCtrl,
                  hint: 'Source / URL (e.g. Zara, ₹4500)',
                  maxLines: 2,
                ),
              ],
              const SizedBox(height: 12),

              // Photo capture
              GestureDetector(
                onTap: () async {
                  final path = await _pickPhoto(ctx2);
                  if (path != null) ss(() => pickedPath = path);
                },
                child: Container(
                  height: 100,
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: surfBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: pickedPath != null
                          ? _wardrobeColor
                          : _wardrobeColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: pickedPath != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              File(pickedPath!),
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              bottom: 6,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Tap to change',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontFamily: 'Nunito',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_rounded,
                              color: _wardrobeColor.withValues(alpha: 0.5),
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap to add photo',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Nunito',
                                color:
                                    _wardrobeColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              LifeSaveButton(
                label: 'Save Item',
                color: _wardrobeColor,
                onTap: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  setState(() {
                    _clothes.add(
                      ClothingItem(
                        id: DateTime.now().millisecondsSinceEpoch
                            .toString(),
                        memberId: _selectedMember,
                        name: nameCtrl.text.trim(),
                        walletId: widget.walletId,
                        category: cat,
                        gender: ClothingGender.unisex,
                        brand: brandCtrl.text.trim().isEmpty
                            ? null
                            : brandCtrl.text.trim(),
                        size: sizeCtrl.text.trim().isEmpty
                            ? null
                            : sizeCtrl.text.trim(),
                        color: colorCtrl.text.trim().isEmpty
                            ? null
                            : colorCtrl.text.trim(),
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                        photoPath: pickedPath,
                        wishlist: wishlist,
                        wishlistSource: sourceCtrl.text.trim().isEmpty
                            ? null
                            : sourceCtrl.text.trim(),
                      ),
                    );
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
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _CatChip extends StatelessWidget {
  final String label, emoji;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _CatChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : surfBg,
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

// ─────────────────────────────────────────────────────────────────────────────
// CLOTHING GRID
// ─────────────────────────────────────────────────────────────────────────────

class _ClothingGrid extends StatelessWidget {
  final List<ClothingItem> items;
  final bool isDark;
  final void Function(ClothingItem) onTap;
  const _ClothingGrid({
    required this.items,
    required this.isDark,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return GestureDetector(
          onTap: () => onTap(item),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _wardrobeColor.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo / emoji area
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: Container(
                      width: double.infinity,
                      color: _wardrobeColor.withValues(alpha: 0.07),
                      alignment: Alignment.center,
                      child: item.photoPath != null
                          ? Image.file(
                              File(item.photoPath!),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : Text(
                              item.category.emoji,
                              style: const TextStyle(fontSize: 40),
                            ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                          color: tc,
                        ),
                      ),
                      if (item.brand != null)
                        Text(
                          item.brand!,
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'Nunito',
                            color: sub,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          LifeBadge(
                            text: item.category.label,
                            color: _wardrobeColor,
                          ),
                          if (item.matchWith.isNotEmpty) ...[
                            const SizedBox(width: 5),
                            const Icon(
                              Icons.compare_arrows_rounded,
                              size: 13,
                              color: AppColors.income,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CLOTHING DETAIL (StatefulWidget for photo + pairs management)
// ─────────────────────────────────────────────────────────────────────────────

class _ClothingDetail extends StatefulWidget {
  final ClothingItem item;
  final bool isDark;
  final List<ClothingItem> allItems;
  final VoidCallback onUpdate;
  const _ClothingDetail({
    required this.item,
    required this.isDark,
    required this.allItems,
    required this.onUpdate,
  });
  @override
  State<_ClothingDetail> createState() => _ClothingDetailState();
}

class _ClothingDetailState extends State<_ClothingDetail> {
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDark = widget.isDark;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final surfBg =
        isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);

    // Bidirectional pairs: items in matchWith + items that have this item in their matchWith
    final matches = widget.allItems.where((c) {
      if (c.id == item.id) return false;
      return item.matchWith.contains(c.id) || c.matchWith.contains(item.id);
    }).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Text(item.category.emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                    if (item.brand != null)
                      Text(
                        item.brand!,
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Nunito',
                          color: sub,
                        ),
                      ),
                  ],
                ),
              ),
              if (item.size != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _wardrobeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.size!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'DM Mono',
                      color: _wardrobeColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Photo area — tappable to add/change
          GestureDetector(
            onTap: _changePhoto,
            child: Container(
              height: 150,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: _wardrobeColor.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(16),
              ),
              child: item.photoPath != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(item.photoPath!),
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          bottom: 8,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Tap to change',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontFamily: 'Nunito',
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.category.emoji,
                          style: const TextStyle(fontSize: 50),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tap to view / add photo',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Nunito',
                            color: _wardrobeColor,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 14),

          // Pairs well with
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '✨ Pairs well with',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Nunito',
                  color: tc,
                ),
              ),
              GestureDetector(
                onTap: () => _managePairs(context, surfBg, sub),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _wardrobeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_rounded,
                        size: 12,
                        color: _wardrobeColor,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: _wardrobeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (matches.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 82,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: matches.map((m) {
                  return Container(
                    margin: const EdgeInsets.only(right: 10),
                    width: 65,
                    decoration: BoxDecoration(
                      color: surfBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _wardrobeColor.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (m.photoPath != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(m.photoPath!),
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Text(
                            m.category.emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        const SizedBox(height: 3),
                        Text(
                          m.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 8,
                            fontFamily: 'Nunito',
                            color: sub,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              'No pairs set — tap Edit to choose.',
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'Nunito',
                color: sub,
              ),
            ),
          ],

          // Color & notes
          if (item.color != null || item.notes != null) ...[
            const SizedBox(height: 10),
            if (item.color != null)
              LifeInfoRow(icon: Icons.palette_rounded, label: item.color!),
            if (item.notes != null) ...[
              const SizedBox(height: 4),
              LifeInfoRow(icon: Icons.notes_rounded, label: item.notes!),
            ],
          ],
        ],
      ),
    );
  }

  // Change photo (camera or gallery)
  Future<void> _changePhoto() async {
    final path = await _pickPhoto(context);
    if (path != null) {
      setState(() => widget.item.photoPath = path);
      widget.onUpdate();
    }
  }

  // Manage pairs — multi-select picker, grouped by category
  void _managePairs(BuildContext ctx, Color surfBg, Color sub) {
    final item = widget.item;

    // Other non-wishlist items from same member & wallet
    final others = widget.allItems
        .where(
          (c) =>
              c.id != item.id &&
              !c.wishlist &&
              c.memberId == item.memberId &&
              c.walletId == item.walletId,
        )
        .toList();

    // Pre-select: item's explicit matchWith + reverse pairs
    final selected = <String>{
      ...item.matchWith,
      for (final c in others)
        if (c.matchWith.contains(item.id)) c.id,
    };

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
                '✨ Pairs well with',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Choose items that go well with ${item.name}',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Nunito',
                  color: sub,
                ),
              ),
              const SizedBox(height: 12),

              if (others.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'Add more items to create pairs.',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Nunito',
                        color: sub,
                      ),
                    ),
                  ),
                )
              else
                // Grouped by category
                for (final cat in ClothingCategory.values) ...[
                  Builder(builder: (_) {
                    final catItems =
                        others.where((c) => c.category == cat).toList();
                    if (catItems.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LifeLabel(
                          text: '${cat.emoji} ${cat.label.toUpperCase()}',
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 82,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: catItems.map((c) {
                              final isSel = selected.contains(c.id);
                              return GestureDetector(
                                onTap: () => ss(() {
                                  if (isSel) {
                                    selected.remove(c.id);
                                  } else {
                                    selected.add(c.id);
                                  }
                                }),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 120),
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 65,
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? _wardrobeColor.withValues(
                                            alpha: 0.12,
                                          )
                                        : surfBg,
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSel
                                          ? _wardrobeColor
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      if (c.photoPath != null)
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.file(
                                            File(c.photoPath!),
                                            width: 30,
                                            height: 30,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      else
                                        Text(
                                          c.category.emoji,
                                          style: const TextStyle(
                                            fontSize: 22,
                                          ),
                                        ),
                                      const SizedBox(height: 3),
                                      Text(
                                        c.name,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontFamily: 'Nunito',
                                          color: isSel
                                              ? _wardrobeColor
                                              : sub,
                                        ),
                                      ),
                                      if (isSel)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 12,
                                          color: _wardrobeColor,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  }),
                ],

              LifeSaveButton(
                label: 'Save Pairs',
                color: _wardrobeColor,
                onTap: () {
                  setState(() {
                    item.matchWith = selected.toList();
                    // Bidirectional: sync other items' matchWith
                    for (final c in others) {
                      if (selected.contains(c.id)) {
                        if (!c.matchWith.contains(item.id)) {
                          c.matchWith.add(item.id);
                        }
                      } else {
                        c.matchWith.remove(item.id);
                      }
                    }
                  });
                  widget.onUpdate();
                  Navigator.pop(ctx2);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH RESULTS LIST
// ─────────────────────────────────────────────────────────────────────────────

class _SearchResultsList extends StatelessWidget {
  final List<ClothingItem> items;
  final List<ClothingItem> allItems;
  final List<OutfitLog> outfitLogs;
  final bool isDark;
  final void Function(ClothingItem) onTap;
  const _SearchResultsList({
    required this.items,
    required this.allItems,
    required this.outfitLogs,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];

        // Pairs (bidirectional)
        final pairs = allItems.where((c) {
          if (c.id == item.id || c.wishlist) return false;
          return item.matchWith.contains(c.id) ||
              c.matchWith.contains(item.id);
        }).toList();

        // Last worn date
        final wornLogs = outfitLogs
            .where(
              (l) =>
                  l.memberId == item.memberId &&
                  l.itemIds.contains(item.id),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        final lastWorn = wornLogs.isNotEmpty ? wornLogs.first.date : null;

        // Items worn with (from most recent log)
        final wornWith = wornLogs.isNotEmpty
            ? allItems
                .where(
                  (c) =>
                      c.id != item.id &&
                      wornLogs.first.itemIds.contains(c.id),
                )
                .toList()
            : <ClothingItem>[];

        return GestureDetector(
          onTap: () => onTap(item),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _wardrobeColor.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo / emoji
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 56,
                    height: 56,
                    color: _wardrobeColor.withValues(alpha: 0.08),
                    alignment: Alignment.center,
                    child: item.photoPath != null
                        ? Image.file(
                            File(item.photoPath!),
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          )
                        : Text(
                            item.category.emoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                          color: tc,
                        ),
                      ),
                      if (item.brand != null)
                        Text(
                          item.brand!,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Nunito',
                            color: sub,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          LifeBadge(
                            text: item.category.label,
                            color: _wardrobeColor,
                          ),
                          if (lastWorn != null) ...[
                            const SizedBox(width: 6),
                            LifeBadge(
                              text: 'Worn ${_fmtDate(lastWorn)}',
                              color: AppColors.income,
                            ),
                          ],
                        ],
                      ),
                      // Pairs well with
                      if (pairs.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '✨ Pairs with',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                            color: sub,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 44,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: pairs.map((p) {
                              return Container(
                                margin: const EdgeInsets.only(right: 6),
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: surfBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _wardrobeColor.withValues(
                                      alpha: 0.15,
                                    ),
                                  ),
                                ),
                                child: p.photoPath != null
                                    ? ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        child: Image.file(
                                          File(p.photoPath!),
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          p.category.emoji,
                                          style: const TextStyle(
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                      // Last worn with
                      if (wornWith.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '👗 Last worn with',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                            color: sub,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          children: wornWith
                              .map(
                                (w) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.income.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${w.category.emoji} ${w.name}',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontFamily: 'Nunito',
                                      color: AppColors.income,
                                      fontWeight: FontWeight.w700,
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
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OUTFIT LOG TAB
// ─────────────────────────────────────────────────────────────────────────────

class _OutfitLogTab extends StatelessWidget {
  final bool isDark;
  final String memberId;
  final List<ClothingItem> allItems;
  final List<OutfitLog> outfitLogs;
  final List<LifeMember> allMembers;
  final void Function(OutfitLog) onLog;

  const _OutfitLogTab({
    required this.isDark,
    required this.memberId,
    required this.allItems,
    required this.outfitLogs,
    required this.allMembers,
    required this.onLog,
  });

  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);

    final today = DateTime.now();
    final myItems = allItems.where((c) => c.memberId == memberId).toList();

    final todayLog = outfitLogs.cast<OutfitLog?>().firstWhere(
          (l) => l!.memberId == memberId && _sameDay(l.date, today),
          orElse: () => null,
        );

    final pastLogs = outfitLogs
        .where(
          (l) => l.memberId == memberId && !_sameDay(l.date, today),
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // Other family members + their today log
    final others = allMembers.where((m) => m.id != memberId).map((m) {
      final log = outfitLogs.cast<OutfitLog?>().firstWhere(
            (l) => l!.memberId == m.id && _sameDay(l.date, today),
            orElse: () => null,
          );
      return (member: m, log: log);
    }).toList();

    Widget itemThumb(ClothingItem item) => Container(
          margin: const EdgeInsets.only(right: 8),
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: _wardrobeColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: item.photoPath != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(item.photoPath!),
                    fit: BoxFit.cover,
                  ),
                )
              : Center(
                  child: Text(
                    item.category.emoji,
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // ── Today header ────────────────────────────────────────────────
        Row(
          children: [
            Text(
              '📅 Today',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
                color: tc,
              ),
            ),
            const Spacer(),
            Text(
              '${_weekday(today)}, ${today.day} ${_monthName(today.month)}',
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'Nunito',
                color: sub,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Today's outfit card ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _wardrobeColor.withValues(alpha: 0.2),
            ),
          ),
          child: todayLog != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Today's Outfit",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Nunito',
                            color: tc,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () =>
                              _logOutfit(context, myItems, todayLog, sub),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _wardrobeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.edit_rounded,
                                  size: 12,
                                  color: _wardrobeColor,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Change',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito',
                                    color: _wardrobeColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 62,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: todayLog.itemIds
                            .map(
                              (id) => allItems.cast<ClothingItem?>().firstWhere(
                                    (c) => c!.id == id,
                                    orElse: () => null,
                                  ),
                            )
                            .whereType<ClothingItem>()
                            .map<Widget>(itemThumb)
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: todayLog.itemIds
                          .map(
                            (id) => allItems.cast<ClothingItem?>().firstWhere(
                                  (c) => c!.id == id,
                                  orElse: () => null,
                                ),
                          )
                          .whereType<ClothingItem>()
                          .map(
                            (item) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    _wardrobeColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'Nunito',
                                  color: _wardrobeColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                )
              : Column(
                  children: [
                    const Text('👗', style: TextStyle(fontSize: 36)),
                    const SizedBox(height: 8),
                    Text(
                      "What are you wearing today?",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Nunito',
                        color: tc,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Log your outfit and share with family',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Nunito',
                        color: sub,
                      ),
                    ),
                    const SizedBox(height: 14),
                    myItems.isEmpty
                        ? Text(
                            'Add items to your wardrobe first.',
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Nunito',
                              color: sub,
                            ),
                          )
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _logOutfit(
                                context,
                                myItems,
                                null,
                                sub,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _wardrobeColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                              ),
                              label: const Text(
                                "Log Today's Outfit",
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
        ),

        // ── Family Today ────────────────────────────────────────────────
        if (others.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            '👨‍👩‍👧‍👦 Family Today',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              fontFamily: 'Nunito',
              color: tc,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: others.map((entry) {
                final m = entry.member;
                final log = entry.log;
                final mItems = log != null
                    ? allItems
                        .where((c) => log.itemIds.contains(c.id))
                        .toList()
                    : <ClothingItem>[];

                return Container(
                  margin: const EdgeInsets.only(right: 10),
                  width: 90,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: log != null
                          ? _wardrobeColor.withValues(alpha: 0.25)
                          : surfBg,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        m.emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        m.name,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: tc,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (log == null)
                        Text(
                          'Not logged',
                          style: TextStyle(
                            fontSize: 9,
                            fontFamily: 'Nunito',
                            color: sub,
                          ),
                        )
                      else
                        Text(
                          mItems.map((c) => c.category.emoji).join(' '),
                          style: const TextStyle(fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        // ── Past Outfits ────────────────────────────────────────────────
        if (pastLogs.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            '🗓 Past Outfits',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              fontFamily: 'Nunito',
              color: tc,
            ),
          ),
          const SizedBox(height: 10),
          ...pastLogs.take(10).map((log) {
            final logItems = allItems
                .where((c) => log.itemIds.contains(c.id))
                .toList();
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _wardrobeColor.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Text(
                          '${log.date.day}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'DM Mono',
                            color: _wardrobeColor,
                          ),
                        ),
                        Text(
                          _monthName(log.date.month).substring(0, 3),
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'Nunito',
                            color: sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _weekday(log.date),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                            color: sub,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: logItems
                                .map(
                                  (item) => Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: _wardrobeColor.withValues(
                                        alpha: 0.07,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: item.photoPath != null
                                        ? ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Image.file(
                                              File(item.photoPath!),
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : Center(
                                            child: Text(
                                              item.category.emoji,
                                              style: const TextStyle(
                                                fontSize: 18,
                                              ),
                                            ),
                                          ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  String _weekday(DateTime d) =>
      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];

  String _monthName(int m) => [
        '',
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ][m];

  void _logOutfit(
    BuildContext ctx,
    List<ClothingItem> myItems,
    OutfitLog? existing,
    Color sub,
  ) {
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final selected = <String>{...?existing?.itemIds};

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
                "Today's Outfit",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Select what you're wearing today",
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Nunito',
                  color: sub,
                ),
              ),
              const SizedBox(height: 12),

              // Grouped by category
              for (final cat in ClothingCategory.values) ...[
                Builder(builder: (_) {
                  final catItems =
                      myItems.where((c) => c.category == cat).toList();
                  if (catItems.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LifeLabel(
                        text: '${cat.emoji} ${cat.label.toUpperCase()}',
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 82,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: catItems.map((item) {
                            final isSel = selected.contains(item.id);
                            return GestureDetector(
                              onTap: () => ss(() {
                                if (isSel) {
                                  selected.remove(item.id);
                                } else {
                                  selected.add(item.id);
                                }
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                margin: const EdgeInsets.only(right: 8),
                                width: 65,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? _wardrobeColor.withValues(alpha: 0.12)
                                      : surfBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSel
                                        ? _wardrobeColor
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (item.photoPath != null)
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        child: Image.file(
                                          File(item.photoPath!),
                                          width: 30,
                                          height: 30,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    else
                                      Text(
                                        item.category.emoji,
                                        style: const TextStyle(fontSize: 22),
                                      ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item.name,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontFamily: 'Nunito',
                                        color: isSel ? _wardrobeColor : sub,
                                      ),
                                    ),
                                    if (isSel)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 12,
                                        color: _wardrobeColor,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                }),
              ],

              LifeSaveButton(
                label: existing != null ? 'Update Outfit' : 'Log Outfit',
                color: _wardrobeColor,
                onTap: () {
                  if (selected.isEmpty) return;
                  onLog(
                    OutfitLog(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      memberId: memberId,
                      itemIds: selected.toList(),
                      date: DateTime.now(),
                    ),
                  );
                  Navigator.pop(ctx2);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WISHLIST CARD
// ─────────────────────────────────────────────────────────────────────────────

class _WishlistCard extends StatelessWidget {
  final ClothingItem item;
  final bool isDark;
  const _WishlistCard({required this.item, required this.isDark});
  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _wardrobeColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _wardrobeColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              item.category.emoji,
              style: const TextStyle(fontSize: 26),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    color: tc,
                  ),
                ),
                LifeBadge(text: item.category.label, color: _wardrobeColor),
                if (item.wishlistSource != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.wishlistSource!,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Nunito',
                      color: sub,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.favorite_rounded, color: _wardrobeColor, size: 20),
        ],
      ),
    );
  }
}
