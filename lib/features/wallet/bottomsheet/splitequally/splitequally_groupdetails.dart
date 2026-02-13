import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/splitequally/splitequally_groupdetails_bottomsheet.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/splitequally/splitequally_groupdetails_options.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/splitequally/settleuppage.dart';
import 'package:wai_life_assistant/data/models/wallet/SplitGroup.dart';
import 'package:wai_life_assistant/data/models/wallet/SplitExpense.dart';
import 'EditExpenseBottomSheet.dart';

class SplitGroupDetailPage extends StatefulWidget {
  final SplitGroup group;

  const SplitGroupDetailPage({super.key, required this.group});

  @override
  State<SplitGroupDetailPage> createState() => _SplitGroupDetailPageState();
}

class _SplitGroupDetailPageState extends State<SplitGroupDetailPage> {
  final List<SplitExpense> _expenses = [];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),

            const Divider(height: 1),

            /// BODY
            Expanded(
              child: _expenses.isEmpty
                  ? Center(
                      child: Text(
                        'No expenses yet',
                        style: textTheme.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _expenses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, index) {
                        final expense = _expenses[index];

                        return GestureDetector(
                          onTap: () => _editExpense(index),
                          child: _ExpenseCard(expense: expense),
                        );
                      },
                    ),
            ),

            _BottomActionBar(group: widget.group, onAddExpense: _addExpense),
          ],
        ),
      ),
    );
  }

  Future<void> _editExpense(int index) async {
    final updatedExpense = await showEditExpenseBottomSheet(
      context,
      _expenses[index],
    );

    if (updatedExpense != null) {
      setState(() {
        _expenses[index] = updatedExpense;
      });
    }
  }

  Widget _buildHeader(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.dblscreenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(widget.group.name, style: textTheme.titleLarge),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.group.members.length} Participants',
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addExpense() async {
    final result = await showAddSpendBottomSheet(
      context: context,
      participants: widget.group.members,
    );

    if (result != null && result is SplitExpense) {
      setState(() {
        _expenses.insert(0, result);
      });
    }
  }
}

class _BottomActionBar extends StatelessWidget {
  final SplitGroup group;
  final VoidCallback onAddExpense;

  const _BottomActionBar({required this.group, required this.onAddExpense});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.dblscreenPadding),
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
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: onAddExpense,
                child: const Text('Spend'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final SplitExpense expense;

  const _ExpenseCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Top row
            Row(
              children: [
                Expanded(
                  child: Text(
                    expense.description,
                    style: textTheme.titleMedium,
                  ),
                ),
                Text(
                  '₹ ${expense.amount.toStringAsFixed(0)}',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            Text('Paid by ${expense.paidBy}', style: textTheme.bodySmall),

            const SizedBox(height: 12),

            /// 🔥 Split Details
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: expense.splitMap.entries.map((entry) {
                final name = entry.key;
                final value = entry.value;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name, style: textTheme.bodyMedium),
                      Text(
                        '₹ ${value.toStringAsFixed(0)}',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// class SplitGroupDetailPage extends StatelessWidget {
//   final SplitGroup group;

//   const SplitGroupDetailPage({super.key, required this.group});

//   @override
//   Widget build(BuildContext context) {
//     final textTheme = Theme.of(context).textTheme;
//     final colors = Theme.of(context).colorScheme;

//     return Scaffold(
//       backgroundColor: colors.surface,
//       body: SafeArea(
//         child: Column(
//           children: [
//             /// HEADER
//             Padding(
//               padding: const EdgeInsets.all(AppSpacing.dblscreenPadding),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   /// Top Row (Back + Group Name)
//                   Row(
//                     children: [
//                       IconButton(
//                         icon: const Icon(Icons.arrow_back),
//                         onPressed: () => Navigator.pop(context),
//                       ),

//                       Expanded(
//                         child: Text(
//                           group.name,
//                           style: textTheme.titleLarge,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ),

//                       IconButton(
//                         icon: const Icon(Icons.more_vert),
//                         onPressed: () {
//                           showGroupOptionsBottomSheet(
//                             context: context,
//                             group: group,
//                           );
//                         },
//                       ),
//                     ],
//                   ),

//                   const SizedBox(height: AppSpacing.gapSS),

//                   /// Participants
//                   Row(
//                     crossAxisAlignment: CrossAxisAlignment.center,
//                     children: [
//                       /// Participants
//                       Text(
//                         '${group.members.length} Participants',
//                         style: textTheme.bodyMedium?.copyWith(
//                           color: colors.onSurfaceVariant,
//                         ),
//                       ),

//                       const Spacer(),

//                       /// Balance summary
//                       Row(
//                         children: [
//                           _BalanceInfo(
//                             label: 'You owe',
//                             amount: group.youOwe,
//                             color: colors.error,
//                           ),
//                           const SizedBox(width: AppSpacing.gapL),
//                           _BalanceInfo(
//                             label: 'You get',
//                             amount: group.youGet,
//                             color: Colors.green,
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),

//             const Divider(height: 1),

//             /// BODY (Transactions placeholder)
//             Expanded(
//               child: Center(
//                 child: Text(
//                   'No expenses yet',
//                   style: textTheme.bodyLarge?.copyWith(
//                     color: colors.onSurfaceVariant,
//                   ),
//                 ),
//               ),
//             ),

//             /// BOTTOM ACTION BAR
//             _BottomActionBar(group: group),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _BalanceInfo extends StatelessWidget {
//   final String label;
//   final double amount;
//   final Color color;

//   const _BalanceInfo({
//     required this.label,
//     required this.amount,
//     required this.color,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final textTheme = Theme.of(context).textTheme;

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(label, style: textTheme.bodySmall),
//         const SizedBox(height: 4),
//         Text(
//           '₹ ${amount.toStringAsFixed(0)}',
//           style: textTheme.titleMedium?.copyWith(
//             color: color,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _BottomActionBar extends StatelessWidget {
//   final SplitGroup group;

//   const _BottomActionBar({super.key, required this.group});

//   @override
//   Widget build(BuildContext context) {
//     return SafeArea(
//       child: Container(
//         padding: const EdgeInsets.all(AppSpacing.dblscreenPadding),
//         decoration: BoxDecoration(
//           color: Theme.of(context).colorScheme.surface,
//           boxShadow: const [
//             BoxShadow(
//               blurRadius: 8,
//               color: Colors.black12,
//               offset: Offset(0, -2),
//             ),
//           ],
//         ),
//         child: Row(
//           children: [
//             Expanded(
//               child: ElevatedButton(
//                 onPressed: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (_) => SettleUpPage(group: group),
//                     ),
//                   );
//                 },
//                 child: const Text('Settle'),
//               ),
//             ),

//             const SizedBox(width: AppSpacing.gapSM),

//             Expanded(
//               child: OutlinedButton(
//                 onPressed: () {
//                   showAddSpendBottomSheet(
//                     context: context,
//                     participants: group.members,
//                   );
//                 },
//                 child: const Text('Spend'),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
