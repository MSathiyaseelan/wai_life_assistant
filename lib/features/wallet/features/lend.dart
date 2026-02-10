import 'package:flutter/material.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/lend/lend_bottomsheet.dart';

class LendPage extends StatelessWidget {
  final String title;
  const LendPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Add Lend',
            icon: Icon(
              Icons.add,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withOpacity(0.6), // subtle grey
            ),
            onPressed: () {
              showAddLendBottomSheet(context: context);
            },
          ),
        ],
      ),
      body: const LendListView(),
    );
  }
}

class LendListView extends StatelessWidget {
  const LendListView({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Sample data (later replace with DB / API)
    final lends = [
      LendItem(
        person: 'Anita',
        amount: 8000,
        returnDate: DateTime.now().add(const Duration(days: 20)),
      ),
      LendItem(
        person: 'Meena',
        amount: 15000,
        returnDate: DateTime.now().add(const Duration(days: 40)),
      ),
    ];

    if (lends.isEmpty) {
      return Center(
        child: Text('No lend records yet', style: textTheme.bodyLarge),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: lends.length,
      separatorBuilder: (_, _) => const SizedBox(height: 5),
      itemBuilder: (context, index) {
        final item = lends[index];

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

class LendItem {
  final String person;
  final double amount;
  final DateTime returnDate;

  LendItem({
    required this.person,
    required this.amount,
    required this.returnDate,
  });
}
