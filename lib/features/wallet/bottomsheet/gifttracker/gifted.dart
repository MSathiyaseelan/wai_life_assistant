import 'package:flutter/material.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/gifttracker/showaddgiftedBottomsheet.dart';

class GiftedPage extends StatelessWidget {
  const GiftedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Gifted')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 5, // mock
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.card_giftcard),
            title: Text('₹ 1,000 to Ramesh', style: textTheme.bodyLarge),
            subtitle: Text('Wedding · Self'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Open details later
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showAddGiftedBottomSheet(context: context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
