import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import 'package:wai_life_assistant/core/theme/app_text.dart';
import 'package:wai_life_assistant/core/theme/app_sizes.dart';
import 'package:wai_life_assistant/shared/app_card.dart';

class WalletSummaryCard extends StatelessWidget {
  const WalletSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      height: AppSizes.walletSummaryCardHeight,
      child: Row(
        children: const [
          Expanded(
            child: _WalletColumn(
              title: AppText.walletSummaryCashTitle,
              outAmount: "₹ 5,000",
              inAmount: "₹ 7,500",
            ),
          ),
          VerticalDivider(thickness: 1, width: 24),
          Expanded(
            child: _WalletColumn(
              title: AppText.walletSummaryOnlineTitle,
              outAmount: "₹ 2,000",
              inAmount: "₹ 3,200",
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletColumn extends StatelessWidget {
  final String title;
  final String outAmount;
  final String inAmount;

  const _WalletColumn({
    required this.title,
    required this.outAmount,
    required this.inAmount,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title, style: textTheme.bodyLarge),

        const SizedBox(height: AppSpacing.gapMM),

        Row(
          children: [
            Text(AppText.outValue, style: textTheme.labelMedium),
            const SizedBox(width: AppSpacing.gapSS),
            Expanded(
              child: Text(
                outAmount,
                style: textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.gapSS),

        Row(
          children: [
            Text(AppText.inValue, style: textTheme.labelMedium),
            const SizedBox(width: AppSpacing.gapSS),
            Expanded(
              child: Text(
                inAmount,
                style: textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
