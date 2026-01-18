import 'package:flutter/material.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/gifttracker/myfunctions.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/gifttracker/gifted.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/gifttracker/upcomingfunctions.dart';

class GiftTrackerPage extends StatelessWidget {
  final String title;
  const GiftTrackerPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showGiftOptionsBottomSheet(context),
          ),
        ],
      ),
      body: Center(
        child: Text('Track gifts across functions', style: textTheme.bodyLarge),
      ),
    );
  }
}

void _showGiftOptionsBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _GiftOptionsSheet(),
  );
}

class _GiftOptionsSheet extends StatelessWidget {
  const _GiftOptionsSheet();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHeader(title: 'Gift Tracker'),

          _OptionTile(
            icon: Icons.event,
            title: 'My Functions',
            onTap: () => _open(context, const MyFunctionsPage()),
          ),
          _OptionTile(
            icon: Icons.card_giftcard,
            title: 'Gifted',
            onTap: () => _open(context, const GiftedPage()),
          ),
          _OptionTile(
            icon: Icons.upcoming,
            title: 'Upcoming Functions',
            onTap: () => _open(
              context,
              const UpcomingFunctionsPage(),
            ), //UpcomingFunctionsPage()),
          ),
          _OptionTile(
            icon: Icons.poll,
            title: 'Polls',
            onTap: () =>
                _open(context, const MyFunctionsPage()), //GiftPollsPage()),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: textTheme.bodyLarge),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;

  const _SheetHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: textTheme.titleMedium)),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
