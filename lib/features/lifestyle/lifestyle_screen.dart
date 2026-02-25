import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/features/wallet/widgets/family_switcher_sheet.dart';
import '../lifestyle/modules/my_garage/my_garage_screen.dart';
import '../lifestyle/modules/my_wardrobe/my_wardrobe_screen.dart';
import '../lifestyle/modules/my_devices/my_devices_screen.dart';
import '../lifestyle/modules/around_the_house/around_house_screen.dart';
import '../lifestyle/modules/document_vault/document_vault_screen.dart';
import '../lifestyle/modules/my_functions/my_functions_screen.dart';
import '../lifestyle/modules/item_locator/itemLocatorScreen.dart';

class LifeStyleScreen extends StatefulWidget {
  final String activeWalletId;
  final void Function(String) onWalletChange;
  const LifeStyleScreen({
    super.key,
    required this.activeWalletId,
    required this.onWalletChange,
  });
  @override
  State<LifeStyleScreen> createState() => _LifeStyleScreenState();
}

class _LifeStyleScreenState extends State<LifeStyleScreen> {
  List<WalletModel> get _allWallets => [personalWallet, ...familyWallets];
  WalletModel get _currentWallet => _allWallets.firstWhere(
    (w) => w.id == widget.activeWalletId,
    orElse: () => personalWallet,
  );

  void _switchWallet(String id) => widget.onWalletChange(id);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor = isDark ? AppColors.subDark : AppColors.subLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(isDark, textColor),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildTagline(isDark, subColor)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Row 1: 2 wide tiles ─────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _WideModuleTile(
                        emoji: '🚗',
                        title: 'My Garage',
                        subtitle: 'Vehicles, Insurance & Service',
                        color: const Color(0xFF4A9EFF),
                        gradientEnd: const Color(0xFF2261CC),
                        onTap: () => _push(
                          MyGarageScreen(walletId: widget.activeWalletId),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _WideModuleTile(
                        emoji: '👗',
                        title: 'My Wardrobe',
                        subtitle: 'Dresses, Outfits & Wishlist',
                        color: const Color(0xFFFF5CA8),
                        gradientEnd: const Color(0xFFCC1A6A),
                        onTap: () => _push(
                          MyWardrobeScreen(walletId: widget.activeWalletId),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Row 2: 3 square tiles ────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _SquareModuleTile(
                        emoji: '📱',
                        title: 'My Devices',
                        subtitle: 'Gadgets & warranty',
                        color: const Color(0xFF9C27B0),
                        onTap: () => _push(
                          MyDevicesScreen(walletId: widget.activeWalletId),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SquareModuleTile(
                        emoji: '🏠',
                        title: 'Around the House',
                        subtitle: 'Appliances & rooms',
                        color: const Color(0xFF00C897),
                        onTap: () => _push(
                          AroundTheHouseScreen(walletId: widget.activeWalletId),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SquareModuleTile(
                        emoji: '🗂️',
                        title: 'Doc Vault',
                        subtitle: 'Safe & organised',
                        color: const Color(0xFFFFAA2C),
                        onTap: () => _push(
                          DocumentVaultScreen(walletId: widget.activeWalletId),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Row 3: Item Locator wide tile ───────────────────────
                _WideModuleTile(
                  emoji: '📍',
                  title: 'Item Locator',
                  subtitle: 'Find anything, anywhere at home',
                  color: const Color(0xFF6C63FF),
                  gradientEnd: const Color(0xFF4B44CC),
                  onTap: () =>
                      _push(ItemLocatorScreen(walletId: widget.activeWalletId)),
                ),
                const SizedBox(height: 12),

                // ── Row 4: Full-width functions banner ───────────────────────
                _FunctionsBannerTile(
                  onTap: () =>
                      _push(MyFunctionsScreen(walletId: widget.activeWalletId)),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _push(Widget screen) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => screen,
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                ),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  AppBar _buildAppBar(bool isDark, Color textColor) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    return AppBar(
      backgroundColor: cardBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Row(
        children: [
          const Text('✨', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LifeStyle',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                  color: textColor,
                ),
              ),
              Text(
                'Your life, organised',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Nunito',
                  color: isDark ? AppColors.subDark : AppColors.subLight,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        GestureDetector(
          onTap: () => FamilySwitcherSheet.show(
            context,
            currentWalletId: widget.activeWalletId,
            onSelect: widget.onWalletChange,
          ),
          child: Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _currentWallet.gradient),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentWallet.emoji,
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(width: 5),
                Text(
                  _currentWallet.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    fontFamily: 'Nunito',
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTagline(bool isDark, Color subColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Text(
        'Track everything that matters — in one place',
        style: TextStyle(
          fontSize: 13,
          fontFamily: 'Nunito',
          color: subColor,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

// ── Wide module tile (2-column) ───────────────────────────────────────────────
class _WideModuleTile extends StatelessWidget {
  final String emoji, title, subtitle;
  final Color color, gradientEnd;
  final VoidCallback onTap;
  const _WideModuleTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.gradientEnd,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 135,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned(
              right: -16,
              top: -16,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: -20,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 32)),
                  const Spacer(),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Square module tile (3-column) ─────────────────────────────────────────────
class _SquareModuleTile extends StatelessWidget {
  final String emoji, title, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _SquareModuleTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final tc = isDark ? AppColors.textDark : AppColors.textLight;
    final sub = isDark ? AppColors.subDark : AppColors.subLight;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 125,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isDark ? 0.08 : 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 18, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                      color: tc,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontFamily: 'Nunito',
                      color: sub,
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Functions banner tile ─────────────────────────────────────────────────────
class _FunctionsBannerTile extends StatelessWidget {
  final VoidCallback onTap;
  const _FunctionsBannerTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFFFF5CA8), Color(0xFFFFAA2C)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withOpacity(0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              top: -10,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '🎊 My Functions',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito',
                        ),
                      ),
                      const Text(
                        'Events · Gifts Received · Gifted · Planning',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'lifestyleController.dart';
// import 'lifestyleItemCard.dart';
// import 'package:wai_life_assistant/data/enum/lifestyleCategory.dart';
// import 'addLifestyleItemSheet.dart';

// class LifeStyleScreen extends StatelessWidget {
//   const LifeStyleScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final controller = context.watch<LifestyleController>();

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('LifeStyle'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.add),
//             onPressed: () {
//               showModalBottomSheet(
//                 context: context,
//                 isScrollControlled: true,
//                 shape: const RoundedRectangleBorder(
//                   borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//                 ),
//                 builder: (_) => AddLifestyleItemSheet(
//                   category: controller.selectedCategory,
//                 ),
//               );
//             },
//           ),
//         ],
//       ),

//       body: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // 🔝 Category Selector
//           SizedBox(
//             height: 56,
//             child: ListView(
//               scrollDirection: Axis.horizontal,
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               children: LifestyleCategory.values.map((category) {
//                 final selected = controller.selectedCategory == category;

//                 return Padding(
//                   padding: const EdgeInsets.only(right: 8),
//                   child: ChoiceChip(
//                     label: Text(_categoryLabel(category)),
//                     selected: selected,
//                     onSelected: (_) => controller.changeCategory(category),
//                   ),
//                 );
//               }).toList(),
//             ),
//           ),

//           const SizedBox(height: 8),

//           // 📦 Content
//           Expanded(
//             child: controller.filteredItems.isEmpty
//                 ? _EmptyLifestyle(category: controller.selectedCategory)
//                 : ListView.separated(
//                     padding: const EdgeInsets.all(16),
//                     itemCount: controller.filteredItems.length,
//                     separatorBuilder: (_, __) => const SizedBox(height: 12),
//                     itemBuilder: (_, index) {
//                       return LifestyleItemCard(
//                         item: controller.filteredItems[index],
//                       );
//                     },
//                   ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _EmptyLifestyle extends StatelessWidget {
//   final LifestyleCategory category;
//   const _EmptyLifestyle({required this.category});

//   @override
//   Widget build(BuildContext context) {
//     final label = _categoryLabel(category);

//     return Center(
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           const Icon(Icons.category_outlined, size: 48, color: Colors.grey),
//           const SizedBox(height: 8),
//           Text(
//             'No $label added yet.',
//             style: Theme.of(context).textTheme.bodyMedium,
//           ),
//         ],
//       ),
//     );
//   }
// }

// String _categoryLabel(LifestyleCategory c) {
//   switch (c) {
//     case LifestyleCategory.vehicle:
//       return 'Vehicle';
//     case LifestyleCategory.dresses:
//       return 'Dresses';
//     case LifestyleCategory.gadgets:
//       return 'Gadgets';
//     case LifestyleCategory.appliances:
//       return 'Appliances';
//     case LifestyleCategory.collections:
//       return 'Collections';
//   }
// }
