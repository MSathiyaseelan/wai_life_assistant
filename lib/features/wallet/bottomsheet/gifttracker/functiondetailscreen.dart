import 'package:flutter/material.dart';

class FunctionDetailScreen extends StatelessWidget {
  const FunctionDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Marriage")),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showAddGiftBottomSheet(context);
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _FunctionSummary(),
          const Divider(),
          Expanded(child: _GiftList()),
        ],
      ),
    );
  }
}

class _FunctionSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: const [
          _SummaryTile(title: "Cash", value: "₹3,45,000"),
          _SummaryTile(title: "Gifts", value: "42"),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String title;
  final String value;

  const _SummaryTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(title, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _GiftList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.currency_rupee),
            title: const Text("Ramesh Kumar"),
            subtitle: const Text("Cash Gift"),
            trailing: const Text("₹5,000"),
          ),
        );
      },
    );
  }
}

void showAddGiftBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const AddGiftBottomSheet(),
  );
}

class AddGiftBottomSheet extends StatefulWidget {
  const AddGiftBottomSheet({super.key});

  @override
  State<AddGiftBottomSheet> createState() => _AddGiftBottomSheetState();
}

class _AddGiftBottomSheetState extends State<AddGiftBottomSheet> {
  String giftType = "cash";

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Add Gift", style: TextStyle(fontSize: 18)),
          const SizedBox(height: 16),

          ToggleButtons(
            isSelected: [giftType == "cash", giftType == "item"],
            onPressed: (index) {
              setState(() {
                giftType = index == 0 ? "cash" : "item";
              });
            },
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text("Cash"),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text("Item"),
              ),
            ],
          ),

          const SizedBox(height: 16),

          TextField(decoration: const InputDecoration(labelText: "Giver Name")),

          if (giftType == "cash") ...[
            TextField(
              decoration: const InputDecoration(labelText: "Amount"),
              keyboardType: TextInputType.number,
            ),
            TextField(
              decoration: const InputDecoration(labelText: "Payment Mode"),
            ),
          ] else ...[
            TextField(
              decoration: const InputDecoration(labelText: "Item Name"),
            ),
            TextField(
              decoration: const InputDecoration(labelText: "Quantity / Weight"),
            ),
          ],

          const SizedBox(height: 16),

          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Save Gift"),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
