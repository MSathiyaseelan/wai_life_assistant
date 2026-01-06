import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import 'package:wai_life_assistant/core/theme/app_text.dart';
import 'package:wai_life_assistant/core/theme/app_sizes.dart';
import 'package:wai_life_assistant/core/theme/app_radius.dart';

class WalletSummaryCard extends StatelessWidget {
  const WalletSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    //final textTheme = Theme.of(context).textTheme;

    return Container(
      height: AppSizes.walletSummaryCardHeight,
      padding: AppSpacing.summaryCardPadding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.walletSummaryRadius,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _WalletColumn(
              title: AppText.walletSummaryOnlineTitle,
              outAmount: "₹ 5,000",
              inAmount: "₹ 7,500",
            ),
          ),
          const VerticalDivider(thickness: 1, width: 24),
          Expanded(
            child: _WalletColumn(
              title: AppText.walletSummaryCashTitle,
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
        Text(title, style: textTheme.headlineMedium),

        const SizedBox(height: AppSpacing.gapMM),

        Row(
          children: [
            Text(AppText.outValue, style: textTheme.bodyLarge),
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
            Text(AppText.inValue, style: textTheme.bodyLarge),
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
