import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyle_models.dart';
import '../../widgets/life_widgets.dart';

const _wardrobeColor = Color(0xFFFF5CA8);

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
  String _selectedMember = 'me';
  ClothingCategory? _filterCat;

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
    if (_filterCat == null) return _wardrobeItems;
    return _wardrobeItems.where((c) => c.category == _filterCat).toList();
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
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
        title: const Row(
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
        bottom: TabBar(
          controller: _tab,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
            fontSize: 11,
          ),
          indicatorColor: _wardrobeColor,
          labelColor: _wardrobeColor,
          unselectedLabelColor: sub,
          tabs: const [
            Tab(text: 'Wardrobe'),
            Tab(text: 'Outfit Log'),
            Tab(text: '💛 Wishlist'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddItem(context, isDark, surfBg),
        backgroundColor: _wardrobeColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          _tab.index == 2 ? 'Add Wishlist' : 'Add Item',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
          ),
        ),
      ),
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
                        color: sel ? _wardrobeColor.withOpacity(0.12) : surfBg,
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
                // WARDROBE
                Column(
                  children: [
                    // Category filter
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
                                onTap: () => setState(() => _filterCat = c),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Grid
                    Expanded(
                      child: _filtered.isEmpty
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
                                ),
                              ),
                            ),
                    ),
                  ],
                ),

                // OUTFIT LOG - photo diary concept
                _OutfitLogTab(isDark: isDark, memberId: _selectedMember),

                // WISHLIST
                _filtered.isEmpty && _wishlist.isEmpty
                    ? const LifeEmptyState(
                        emoji: '💛',
                        title: 'Wishlist is empty',
                        subtitle: 'Snap a dress you love and save it here',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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

  void _showAddItem(BuildContext ctx, bool isDark, Color surfBg) {
    final nameCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final sourceCtrl = TextEditingController();
    var cat = ClothingCategory.topwear;
    var wishlist = _tab.index == 2;

    showLifeSheet(
      ctx,
      child: StatefulBuilder(
        builder: (ctx2, ss) {
          return Padding(
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
                                  ? _wardrobeColor.withOpacity(0.15)
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

                if (wishlist) ...[
                  const SizedBox(height: 8),
                  LifeInput(
                    controller: sourceCtrl,
                    hint: 'Source / URL (e.g. Zara, ₹4500)',
                    maxLines: 2,
                  ),
                ],

                const SizedBox(height: 12),

                Container(
                  height: 80,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: surfBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _wardrobeColor.withOpacity(0.2)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_rounded,
                        color: _wardrobeColor.withOpacity(0.5),
                        size: 28,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to add photo',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Nunito',
                          color: _wardrobeColor.withOpacity(0.7),
                        ),
                      ),
                    ],
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
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          memberId: _selectedMember,
                          name: nameCtrl.text.trim(),
                          walletId: widget.walletId,
                          category: cat,
                          gender: ClothingGender.unisex,
                          brand: brandCtrl.text.trim().isEmpty
                              ? null
                              : brandCtrl.text.trim(),
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
          );
        },
      ),
    );
  }
}

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
              border: Border.all(color: _wardrobeColor.withOpacity(0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo placeholder
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _wardrobeColor.withOpacity(0.07),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: item.photoPath != null
                        ? const Icon(
                            Icons.image_rounded,
                            size: 40,
                            color: _wardrobeColor,
                          )
                        : Text(
                            item.category.emoji,
                            style: const TextStyle(fontSize: 40),
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

class _ClothingDetail extends StatelessWidget {
  final ClothingItem item;
  final bool isDark;
  final List<ClothingItem> allItems;
  const _ClothingDetail({
    required this.item,
    required this.isDark,
    required this.allItems,
  });
  @override
  Widget build(BuildContext context) {
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    final matches = allItems
        .where((c) => item.matchWith.contains(c.id))
        .toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
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
            ],
          ),
          const SizedBox(height: 12),
          // Photo placeholder
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: _wardrobeColor.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item.category.emoji, style: const TextStyle(fontSize: 50)),
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
          if (matches.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              '✨ Pairs well with',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFamily: 'Nunito',
                color: tc,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: matches
                    .map(
                      (m) => Container(
                        margin: const EdgeInsets.only(right: 10),
                        width: 60,
                        decoration: BoxDecoration(
                          color: surfBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              m.category.emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
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
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          if (item.notes != null) ...[
            const SizedBox(height: 10),
            LifeInfoRow(icon: Icons.notes_rounded, label: item.notes!),
          ],
        ],
      ),
    );
  }
}

class _OutfitLogTab extends StatelessWidget {
  final bool isDark;
  final String memberId;
  const _OutfitLogTab({required this.isDark, required this.memberId});
  @override
  Widget build(BuildContext context) {
    final surfBg = isDark ? AppColors.surfDark : const Color(0xFFEDEEF5);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👗', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text(
              'Outfit Log',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFamily: 'Nunito',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Take a daily selfie to log your outfit.\nSwipe through your style diary.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Nunito',
                color: AppColors.subDark,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: _wardrobeColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text(
                "Today's Outfit",
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
        border: Border.all(color: _wardrobeColor.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _wardrobeColor.withOpacity(0.08),
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
