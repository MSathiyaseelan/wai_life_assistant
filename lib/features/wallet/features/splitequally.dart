import 'package:flutter/material.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/splitequally/splitequally_bottomsheet.dart';

class SplitEquallyPage extends StatelessWidget {
  final String title;
  const SplitEquallyPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SplitEquallyListView(), // your content
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'split_add_fab',
        icon: const Icon(Icons.add),
        label: const Text('New Split'),
        onPressed: () {
          showNewSplitBottomSheet(context: context);
        },
      ),
    );
  }
}

class SplitEquallyListView extends StatelessWidget {
  const SplitEquallyListView({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Sample data (later replace with DB / API)
    final borrows = [
      BorrowItem(
        person: 'Ravi',
        amount: 5000,
        returnDate: DateTime.now().add(const Duration(days: 15)),
      ),
      BorrowItem(
        person: 'Suresh',
        amount: 12000,
        returnDate: DateTime.now().add(const Duration(days: 30)),
      ),
    ];

    if (borrows.isEmpty) {
      return Center(
        child: Text('No borrow records yet', style: textTheme.bodyLarge),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: borrows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 5),
      itemBuilder: (context, index) {
        final item = borrows[index];

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(item.person, style: textTheme.titleMedium),
            subtitle: Text(
              'Return by ${_formatDate(item.returnDate)}',
              style: textTheme.bodyMedium,
            ),
            trailing: Text(
              '₹ ${item.amount.toStringAsFixed(0)}',
              style: textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            onTap: () {
              // Later: open details page / edit bottom sheet
            },
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class BorrowItem {
  final String person;
  final double amount;
  final DateTime returnDate;

  BorrowItem({
    required this.person,
    required this.amount,
    required this.returnDate,
  });
}
