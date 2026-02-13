import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/splitequally/splitequally_bottomsheet.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import 'package:wai_life_assistant/core/theme/app_radius.dart';
import 'package:wai_life_assistant/data/models/wallet/SplitGroup.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/splitequally/splitequally_groupdetails.dart';
import 'package:wai_life_assistant/features/wallet/AI/showSplitSparkBottomSheet.dart';

class SplitEquallyPage extends StatefulWidget {
  final String title;
  const SplitEquallyPage({super.key, required this.title});

  @override
  State<SplitEquallyPage> createState() => _SplitEquallyPageState();
}

class _SplitEquallyPageState extends State<SplitEquallyPage> {
  final List<SplitGroup> _groups = [
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
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          SplitEquallyListView(groups: _groups),

          /// Floating Rail
          SplitFloatingRail(
            onSparkTap: () async {
              final intent = await showSplitSparkBottomSheet(context);

              if (intent != null) {
                final newGroup = SplitGroup(
                  name: intent.groupName,
                  type: "AI Created",
                  members: intent.participants,
                  youOwe: 0,
                  youGet: 0,
                );

                setState(() {
                  _groups.insert(0, newGroup);
                });
              }
            },

            // onSparkTap: () {
            //   debugPrint("Split Spark tapped");
            //   final intent = showSparkBottomSheet(context);

            //   if (intent == null) return;
            // },
            onNewGroupTap: () async {
              final newGroup = await showNewSplitBottomSheet(context);

              if (newGroup != null) {
                setState(() {
                  _groups.insert(0, newGroup);
                });
              }
            },
          ),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// LIST VIEW
////////////////////////////////////////////////////////////

class SplitEquallyListView extends StatelessWidget {
  final List<SplitGroup> groups;

  const SplitEquallyListView({super.key, required this.groups});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

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

////////////////////////////////////////////////////////////
/// FLOATING RAIL
////////////////////////////////////////////////////////////

class SplitFloatingRail extends StatelessWidget {
  final VoidCallback onSparkTap;
  final VoidCallback onNewGroupTap;

  const SplitFloatingRail({
    super.key,
    required this.onSparkTap,
    required this.onNewGroupTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 12,
      bottom: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          /// Spark AI
          _RailAction(
            icon: Icons.auto_awesome_rounded,
            label: 'Spark',
            color: Colors.deepPurple,
            onTap: () {
              HapticFeedback.lightImpact();
              onSparkTap();
            },
          ),

          const SizedBox(height: 28),

          /// New Group
          _RailAction(
            icon: Icons.add,
            label: 'Group',
            color: Colors.grey,
            onTap: () {
              HapticFeedback.lightImpact();
              onNewGroupTap();
            },
          ),
        ],
      ),
    );
  }
}

class _RailAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _RailAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 30, color: color),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// SMALL COMPONENTS
////////////////////////////////////////////////////////////

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

// import 'package:flutter/material.dart';
// import 'package:wai_life_assistant/features/wallet/bottomsheet/splitequally/splitequally_bottomsheet.dart';
// import 'package:wai_life_assistant/core/theme/app_spacing.dart';
// import 'package:wai_life_assistant/core/theme/app_radius.dart';
// import 'package:wai_life_assistant/data/models/wallet/SplitGroup.dart';
// import 'package:wai_life_assistant/features/wallet/bottomsheet/splitequally/splitequally_groupdetails.dart';

// class SplitEquallyPage extends StatefulWidget {
//   final String title;
//   const SplitEquallyPage({super.key, required this.title});

//   @override
//   State<SplitEquallyPage> createState() => _SplitEquallyPageState();
// }

// class _SplitEquallyPageState extends State<SplitEquallyPage> {
//   final List<SplitGroup> _groups = [
//     SplitGroup(
//       name: 'Goa Trip',
//       type: 'Friends',
//       members: ['Ravi', 'Suresh', 'Ajay'],
//       youOwe: 1200,
//       youGet: 0,
//     ),
//     SplitGroup(
//       name: 'Office Lunch',
//       type: 'Office',
//       members: ['Meena', 'Karthik', 'Priya', 'John'],
//       youOwe: 0,
//       youGet: 850,
//     ),
//   ];

//   Future<void> _createNewGroup() async {
//     final newGroup = await showNewSplitBottomSheet(context);

//     if (newGroup != null) {
//       setState(() {
//         _groups.insert(0, newGroup);
//       });
//     }
//   }

//   void _openAiIntegration() {
//     debugPrint("Spark AI tapped");
//     // TODO: Navigate to AI parsing page
//   }

//   @override
//   Widget build(BuildContext context) {
//     final colors = Theme.of(context).colorScheme;

//     return Scaffold(
//       appBar: AppBar(title: Text(widget.title)),
//       body: Stack(
//         children: [
//           SplitEquallyListView(groups: _groups),

//           /// ✅ Floating Rail
//           Positioned(
//             right: AppSpacing.md,
//             bottom: AppSpacing.lg,
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 /// ✨ Spark Button
//                 _FloatingRailButton(
//                   icon: Icons.auto_awesome,
//                   label: 'Spark',
//                   onTap: _openAiIntegration,
//                 ),

//                 const SizedBox(height: AppSpacing.gapSM),

//                 /// ➕ New Group Button
//                 _FloatingRailButton(
//                   icon: Icons.add,
//                   label: 'Group',
//                   onTap: _createNewGroup,
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // class _SplitEquallyPageState extends State<SplitEquallyPage> {
// //   final List<SplitGroup> _groups = [
// //     SplitGroup(
// //       name: 'Goa Trip',
// //       type: 'Friends',
// //       members: ['Ravi', 'Suresh', 'Ajay'],
// //       youOwe: 1200,
// //       youGet: 0,
// //     ),
// //     SplitGroup(
// //       name: 'Office Lunch',
// //       type: 'Office',
// //       members: ['Meena', 'Karthik', 'Priya', 'John'],
// //       youOwe: 0,
// //       youGet: 850,
// //     ),
// //     SplitGroup(
// //       name: 'Goa Trip',
// //       type: 'Friends',
// //       members: ['Ravi', 'Suresh', 'Ajay'],
// //       youOwe: 1200,
// //       youGet: 0,
// //     ),
// //     SplitGroup(
// //       name: 'Office Lunch',
// //       type: 'Office',
// //       members: ['Meena', 'Karthik', 'Priya', 'John'],
// //       youOwe: 0,
// //       youGet: 850,
// //     ),
// //     SplitGroup(
// //       name: 'Goa Trip',
// //       type: 'Friends',
// //       members: ['Ravi', 'Suresh', 'Ajay'],
// //       youOwe: 1200,
// //       youGet: 0,
// //     ),
// //     SplitGroup(
// //       name: 'Office Lunch',
// //       type: 'Office',
// //       members: ['Meena', 'Karthik', 'Priya', 'John'],
// //       youOwe: 0,
// //       youGet: 850,
// //     ),
// //   ];

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(
// //         title: Text(widget.title),
// //         actions: [
// //           IconButton(
// //             tooltip: 'New Split',
// //             icon: Icon(
// //               Icons.add,
// //               color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
// //             ),
// //             onPressed: () async {
// //               final newGroup = await showNewSplitBottomSheet(context);

// //               if (newGroup != null) {
// //                 setState(() {
// //                   _groups.insert(0, newGroup);
// //                 });
// //               }
// //             },
// //           ),
// //         ],
// //       ),
// //       body: SplitEquallyListView(groups: _groups),
// //     );
// //   }
// // }

// class SplitEquallyListView extends StatelessWidget {
//   final List<SplitGroup> groups;

//   const SplitEquallyListView({super.key, required this.groups});

//   @override
//   Widget build(BuildContext context) {
//     final textTheme = Theme.of(context).textTheme;
//     final colors = Theme.of(context).colorScheme;

//     if (groups.isEmpty) {
//       return Center(
//         child: Text('No groups created yet', style: textTheme.bodyLarge),
//       );
//     }

//     return ListView.separated(
//       padding: const EdgeInsets.all(AppSpacing.dblscreenPadding),
//       itemCount: groups.length,
//       separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.gapSM),
//       itemBuilder: (context, index) {
//         final group = groups[index];

//         return Card(
//           elevation: 1,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(AppRadius.card),
//           ),
//           child: ListTile(
//             contentPadding: const EdgeInsets.symmetric(
//               horizontal: AppSpacing.listTileHorizontalPadding,
//               vertical: AppSpacing.listTileVerticalPadding,
//             ),
//             leading: _GroupAvatar(group: group),
//             title: Text(group.name, style: textTheme.titleMedium),
//             subtitle: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   '${group.type} • ${group.members.length} members',
//                   style: textTheme.bodySmall,
//                 ),
//                 const SizedBox(height: AppSpacing.xs),
//                 _BalanceText(group: group),
//               ],
//             ),
//             trailing: _MembersPreview(
//               members: group.members,
//               colorScheme: colors,
//             ),
//             onTap: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (_) => SplitGroupDetailPage(group: group),
//                 ),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }
// }

// class _BalanceText extends StatelessWidget {
//   final SplitGroup group;

//   const _BalanceText({required this.group});

//   @override
//   Widget build(BuildContext context) {
//     final colors = Theme.of(context).colorScheme;
//     final textTheme = Theme.of(context).textTheme;

//     if (group.youOwe > 0) {
//       return Text(
//         'You owe ₹${group.youOwe.toStringAsFixed(0)}',
//         style: textTheme.bodyMedium?.copyWith(
//           color: colors.error,
//           fontWeight: FontWeight.w600,
//         ),
//       );
//     }

//     if (group.youGet > 0) {
//       return Text(
//         'You get ₹${group.youGet.toStringAsFixed(0)}',
//         style: textTheme.bodyMedium?.copyWith(
//           color: Colors.green,
//           fontWeight: FontWeight.w600,
//         ),
//       );
//     }

//     return Text(
//       'Settled up',
//       style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
//     );
//   }
// }

// class _GroupAvatar extends StatelessWidget {
//   final SplitGroup group;

//   const _GroupAvatar({required this.group});

//   @override
//   Widget build(BuildContext context) {
//     final colors = Theme.of(context).colorScheme;

//     return CircleAvatar(
//       radius: 24,
//       backgroundColor: colors.surfaceContainerHighest,
//       child: Icon(Icons.group, color: colors.onSurfaceVariant),
//     );
//   }
// }

// class _MembersPreview extends StatelessWidget {
//   final List<String> members;
//   final ColorScheme colorScheme;

//   const _MembersPreview({required this.members, required this.colorScheme});

//   @override
//   Widget build(BuildContext context) {
//     final visible = members.take(3).toList();
//     final remaining = members.length - visible.length;

//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         ...visible.map(
//           (name) => Padding(
//             padding: const EdgeInsets.only(right: 4),
//             child: CircleAvatar(
//               radius: 14,
//               backgroundColor: colorScheme.primary.withOpacity(0.12),
//               child: Text(
//                 name[0].toUpperCase(),
//                 style: TextStyle(fontSize: 12, color: colorScheme.primary),
//               ),
//             ),
//           ),
//         ),
//         if (remaining > 0)
//           CircleAvatar(
//             radius: 14,
//             backgroundColor: colorScheme.surfaceContainerHighest,
//             child: Text(
//               '+$remaining',
//               style: TextStyle(
//                 fontSize: 11,
//                 color: colorScheme.onSurfaceVariant,
//               ),
//             ),
//           ),
//       ],
//     );
//   }
// }

// class _FloatingRailButton extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final VoidCallback onTap;

//   const _FloatingRailButton({
//     required this.icon,
//     required this.label,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final colors = Theme.of(context).colorScheme;
//     final textTheme = Theme.of(context).textTheme;

//     return Material(
//       color: colors.surface,
//       elevation: 3,
//       borderRadius: BorderRadius.circular(30),
//       child: InkWell(
//         borderRadius: BorderRadius.circular(30),
//         onTap: onTap,
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Icon(icon, size: 20, color: colors.primary),
//               const SizedBox(width: 8),
//               Text(
//                 label,
//                 style: textTheme.labelLarge?.copyWith(
//                   color: colors.primary,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
