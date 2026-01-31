import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void showCategoryGrid(BuildContext context) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: const [
            _CategoryTile('Appointments', Icons.calendar_today),
            _CategoryTile('Event Planner', Icons.event),
            _CategoryTile('Trip Planner', Icons.next_plan_rounded),
            _CategoryTile('Family', Icons.family_restroom),
            _CategoryTile('Finance', Icons.account_balance),
            _CategoryTile('Education', Icons.school),
            _CategoryTile('Health', Icons.favorite),
            _CategoryTile('Location', Icons.location_on),
            _CategoryTile('Personal', Icons.person),
            _CategoryTile('Smart', Icons.auto_awesome),
          ],
        ),
      );
    },
  );
}

class _CategoryTile extends StatelessWidget {
  final String title;
  final IconData icon;

  const _CategoryTile(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.pop(context);
        // TODO: open corresponding reminder sheet
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surfaceVariant,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Icon(icon), const SizedBox(width: 8), Text(title)],
        ),
      ),
    );
  }
}
