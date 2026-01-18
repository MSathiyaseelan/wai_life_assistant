import 'package:flutter/material.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/gifttracker/functiondetailscreen.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/gifttracker/addfunctionbottomsheet.dart';

class MyFunctionsPage extends StatelessWidget {
  const MyFunctionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Functions"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              showAddFunctionBottomSheet(context);
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (context, index) {
          return _FunctionCard(
            title: "My Marriage",
            date: "12 Jan 2024",
            cash: "₹3,45,000",
            gifts: "42",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FunctionDetailScreen()),
              );
            },
          );
        },
      ),
    );
  }
}

class _FunctionCard extends StatelessWidget {
  final String title;
  final String date;
  final String cash;
  final String gifts;
  final VoidCallback onTap;

  const _FunctionCard({
    required this.title,
    required this.date,
    required this.cash,
    required this.gifts,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(date, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.currency_rupee, size: 18),
                  const SizedBox(width: 4),
                  Text(cash),
                  const Spacer(),
                  const Icon(Icons.card_giftcard, size: 18),
                  const SizedBox(width: 4),
                  Text("$gifts items"),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showAddFunctionBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const AddFunctionBottomSheet(),
  );
}
