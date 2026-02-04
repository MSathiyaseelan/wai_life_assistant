import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/models/lifestyle/lifestyleItem.dart';
import 'package:wai_life_assistant/features/lifestyle/_InfoTile.dart';

class DressDetailScreen extends StatelessWidget {
  final LifestyleItem item;

  const DressDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(item.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoTile('Brand', item.brand),
            InfoTile('Price', item.price?.toString()),
            InfoTile(
              'Purchase Date',
              item.purchaseDate?.toLocal().toString().split(' ')[0],
            ),
            InfoTile('Notes', item.notes),
          ],
        ),
      ),
    );
  }
}
