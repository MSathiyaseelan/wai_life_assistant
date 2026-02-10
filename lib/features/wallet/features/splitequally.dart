import 'package:flutter/material.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/splitequally/splitequally_bottomsheet.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import 'package:wai_life_assistant/core/theme/app_radius.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/splitequally/splitequally_groupdetails.dart';

class SplitEquallyPage extends StatelessWidget {
  final String title;
  const SplitEquallyPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'New Split',
            icon: Icon(
              Icons.add,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withOpacity(0.6), // subtle grey
            ),
            onPressed: () {
              showNewSplitBottomSheet(context: context);
            },
          ),
        ],
      ),
      body: const SplitEquallyListView(),
    );
  }
}

class SplitEquallyListView extends StatelessWidget {
  const SplitEquallyListView({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    /// Sample data (replace later with DB/API)
    final groups = [
      SplitGroup(
        name: 'Goa Trip',
        type: 'Friends',
        members: ['Ravi', 'Suresh', 'Ajay'],
        youOwe: 1200,
        youGet: 0,
      ),
      SplitGroup(
        name: 'Office Lunch',
        type: 'Office',
        members: ['Meena', 'Karthik', 'Priya', 'John'],
        youOwe: 0,
        youGet: 850,
      ),
      SplitGroup(
        name: 'Room Rent',
        type: 'Family',
        members: ['Dad', 'Mom'],
        youOwe: 0,
        youGet: 0,
      ),
    ];

    if (groups.isEmpty) {
      return Center(
        child: Text('No groups created yet', style: textTheme.bodyLarge),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.dblscreenPadding),
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.gapSM),
      itemBuilder: (context, index) {
        final group = groups[index];

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.listTileHorizontalPadding,
              vertical: AppSpacing.listTileVerticalPadding,
            ),

            leading: _GroupAvatar(group: group),

            title: Text(group.name, style: textTheme.titleMedium),

            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${group.type} • ${group.members.length} members',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                _BalanceText(group: group),
              ],
            ),

            trailing: _MembersPreview(
              members: group.members,
              colorScheme: colors,
            ),

            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SplitGroupDetailPage(group: group),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _BalanceText extends StatelessWidget {
  final SplitGroup group;

  const _BalanceText({required this.group});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (group.youOwe > 0) {
      return Text(
        'You owe ₹${group.youOwe.toStringAsFixed(0)}',
        style: textTheme.bodyMedium?.copyWith(
          color: colors.error,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    if (group.youGet > 0) {
      return Text(
        'You get ₹${group.youGet.toStringAsFixed(0)}',
        style: textTheme.bodyMedium?.copyWith(
          color: Colors.green,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Text(
      'Settled up',
      style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
    );
  }
}

class _GroupAvatar extends StatelessWidget {
  final SplitGroup group;

  const _GroupAvatar({required this.group});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return CircleAvatar(
      radius: 24,
      backgroundColor: colors.surfaceContainerHighest,
      child: Icon(Icons.group, color: colors.onSurfaceVariant),
    );
  }
}

class _MembersPreview extends StatelessWidget {
  final List<String> members;
  final ColorScheme colorScheme;

  const _MembersPreview({required this.members, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final visible = members.take(3).toList();
    final remaining = members.length - visible.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...visible.map(
          (name) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: colorScheme.primary.withOpacity(0.12),
              child: Text(
                name[0].toUpperCase(),
                style: TextStyle(fontSize: 12, color: colorScheme.primary),
              ),
            ),
          ),
        ),
        if (remaining > 0)
          CircleAvatar(
            radius: 14,
            backgroundColor: colorScheme.surfaceContainerHighest,
            child: Text(
              '+$remaining',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class SplitGroup {
  final String name;
  final String type;
  final List<String> members;
  final double youOwe;
  final double youGet;
  final String? imagePath;

  SplitGroup({
    required this.name,
    required this.type,
    required this.members,
    required this.youOwe,
    required this.youGet,
    this.imagePath,
  });
}
