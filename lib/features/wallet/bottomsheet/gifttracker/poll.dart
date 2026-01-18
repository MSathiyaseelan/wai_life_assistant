import 'package:flutter/material.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/gifttracker/showcreatepollbottomsheet.dart';
import 'polldetailpage.dart';

class PollsPage extends StatelessWidget {
  const PollsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Polls')),

      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _PollCard(
            title: 'Wedding Attendance Poll',
            functionName: 'Ramesh Wedding',
            expiresOn: DateTime.now().add(const Duration(days: 5)),
            totalVotes: 6,
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showCreatePollBottomSheet(context: context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PollCard extends StatelessWidget {
  final String title;
  final String functionName;
  final DateTime expiresOn;
  final int totalVotes;

  const _PollCard({
    required this.title,
    required this.functionName,
    required this.expiresOn,
    required this.totalVotes,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PollDetailPage()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black12)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Function: $functionName'),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.how_to_vote, size: 16, color: colors.primary),
                const SizedBox(width: 4),
                Text('$totalVotes votes'),
                const Spacer(),
                Text('Ends: ${_fmt(expiresOn)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
