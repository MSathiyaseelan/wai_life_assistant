import 'package:flutter/material.dart';

class LendPage extends StatelessWidget {
  final String title;
  const LendPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(title, style: textTheme.titleLarge)),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _dummyTransactions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final tx = _dummyTransactions[index];

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 6,
                    color: Colors.black.withOpacity(0.08),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: tx.isCredit
                        ? Colors.green.withOpacity(0.15)
                        : Colors.red.withOpacity(0.15),
                    child: Icon(
                      tx.isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                      color: tx.isCredit ? Colors.green : Colors.red,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx.title, style: textTheme.bodyLarge),
                        const SizedBox(height: 4),
                        Text(tx.date, style: textTheme.bodySmall),
                      ],
                    ),
                  ),

                  Text(
                    tx.amount,
                    style: textTheme.bodyLarge?.copyWith(
                      color: tx.isCredit ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class TransactionItem {
  final String title;
  final String date;
  final String amount;
  final bool isCredit;

  TransactionItem({
    required this.title,
    required this.date,
    required this.amount,
    required this.isCredit,
  });
}

final _dummyTransactions = [
  TransactionItem(
    title: 'UPI Received',
    date: '10 Jan 2026',
    amount: '+ ₹7,500',
    isCredit: true,
  ),
  TransactionItem(
    title: 'Cash Paid',
    date: '09 Jan 2026',
    amount: '- ₹2,000',
    isCredit: false,
  ),
  TransactionItem(
    title: 'UPI Sent',
    date: '08 Jan 2026',
    amount: '- ₹1,200',
    isCredit: false,
  ),
];
