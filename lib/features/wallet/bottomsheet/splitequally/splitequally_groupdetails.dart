import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/splitequally/splitequally_groupdetails_bottomsheet.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/splitequally/splitequally_groupdetails_options.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/splitequally/settleuppage.dart';
import 'package:wai_life_assistant/data/models/wallet/SplitGroup.dart';

class SplitGroupDetailPage extends StatelessWidget {
  final SplitGroup group;

  const SplitGroupDetailPage({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            /// HEADER
            Padding(
              padding: const EdgeInsets.all(AppSpacing.dblscreenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// Top Row (Back + Group Name)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),

                      Expanded(
                        child: Text(
                          group.name,
                          style: textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () {
                          showGroupOptionsBottomSheet(
                            context: context,
                            group: group,
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.gapSS),

                  /// Participants
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      /// Participants
                      Text(
                        '${group.members.length} Participants',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),

                      const Spacer(),

                      /// Balance summary
                      Row(
                        children: [
                          _BalanceInfo(
                            label: 'You owe',
                            amount: group.youOwe,
                            color: colors.error,
                          ),
                          const SizedBox(width: AppSpacing.gapL),
                          _BalanceInfo(
                            label: 'You get',
                            amount: group.youGet,
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            /// BODY (Transactions placeholder)
            Expanded(
              child: Center(
                child: Text(
                  'No expenses yet',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),

            /// BOTTOM ACTION BAR
            _BottomActionBar(group: group),
          ],
        ),
      ),
    );
  }
}

class _BalanceInfo extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _BalanceInfo({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          '₹ ${amount.toStringAsFixed(0)}',
          style: textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final SplitGroup group;

  const _BottomActionBar({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.dblscreenPadding),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: const [
            BoxShadow(
              blurRadius: 8,
              color: Colors.black12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SettleUpPage(group: group),
                    ),
                  );
                },
                child: const Text('Settle'),
              ),
            ),

            const SizedBox(width: AppSpacing.gapSM),

            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  showAddSpendBottomSheet(
                    context: context,
                    participants: group.members,
                  );
                },
                child: const Text('Spend'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
