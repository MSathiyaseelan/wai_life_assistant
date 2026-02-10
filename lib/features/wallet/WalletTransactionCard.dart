import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import 'package:wai_life_assistant/core/theme/app_text_styles.dart';
import 'package:wai_life_assistant/data/models/wallet/WalletTransaction.dart';
import 'package:wai_life_assistant/Shared/app_card.dart';

class WalletTransactionCard extends StatelessWidget {
  final WalletTransaction transaction;

  const WalletTransactionCard({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.gapM),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              transaction.purpose,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              transaction.category ?? 'Uncategorized',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('₹${transaction.amount}', style: AppTextStyles.amount),
                // Text(
                //   transaction.category ?? 'Uncategorized',
                //   style: Theme.of(context).textTheme.bodySmall,
                // ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
