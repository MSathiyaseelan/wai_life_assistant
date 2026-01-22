import 'package:flutter/material.dart';
import '../../../data/models/pandry/groceryitem.dart';
import 'grocerybuynowdetailsheet.dart';

class GroceryBuyNow extends StatelessWidget {
  final List<GroceryItem> items;

  const GroceryBuyNow({required this.items});

  @override
  Widget build(BuildContext context) {
    final buyNowItems = items.where((e) => e.isOut || e.isLow).toList();
    if (buyNowItems.isEmpty) return const SizedBox();

    return Card(
      margin: const EdgeInsets.all(12),
      child: ListTile(
        leading: const Icon(Icons.shopping_cart_outlined),
        title: const Text('Buy Today'),
        subtitle: Text('${buyNowItems.length} items to buy'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          final appBarHeight = kToolbarHeight;
          final topPadding = MediaQuery.of(context).padding.top;

          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.of(context).size.height -
                  appBarHeight -
                  topPadding,
            ),
            builder: (_) => BuyNowDetailsSheet(items: buyNowItems),
          );
        },
      ),
    );
  }
}
