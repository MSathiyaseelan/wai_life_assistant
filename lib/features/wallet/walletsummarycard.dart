import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import 'package:wai_life_assistant/core/theme/app_text.dart';
import 'package:wai_life_assistant/shared/app_card.dart';
import 'package:wai_life_assistant/shared/calendar/customcalendar.dart';
import 'package:wai_life_assistant/core/theme/app_colors.dart';
import 'package:wai_life_assistant/core/theme/app_icon_sizes.dart';
import 'package:wai_life_assistant/core/theme/app_radius.dart';

class WalletSummaryCard extends StatelessWidget {
  const WalletSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero, // we already control inner padding manually
      child: Column(
        children: [
          // 1. Date Navigator Section
          const DayNavigator(),

          Divider(height: AppSpacing.dividerSpace, color: AppColors.divider),

          // 2. Summary Section
          Padding(
            padding: AppSpacing.wallatPadding,
            child: IntrinsicHeight(
              child: Row(
                children: [
                  const Expanded(
                    child: _WalletSection(
                      title: AppText.walletSummaryCashTitle,
                      icon: Icons.payments_rounded,
                      iconColor: AppColors.primary,
                      inAmount: "7,500",
                      outAmount: "5,000",
                    ),
                  ),
                  VerticalDivider(
                    thickness: AppSpacing.dividerSpace,
                    width: AppSpacing.xxxl,
                    color: AppColors.divider,
                  ),
                  const Expanded(
                    child: _WalletSection(
                      title: AppText.walletSummaryOnlineTitle,
                      icon: Icons.account_balance_wallet_rounded,
                      iconColor: AppColors.secondary,
                      inAmount: "3,200",
                      outAmount: "2,000",
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final String inAmount;
  final String outAmount;

  const _WalletSection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.inAmount,
    required this.outAmount,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: Icon + Title
        Row(
          children: [
            Icon(icon, size: AppIconSizes.medium, color: iconColor),
            const SizedBox(width: AppSpacing.sm),
            Text(
              title,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // In Amount Row
        _AmountRow(
          label: AppText.inValue,
          amount: "₹$inAmount",
          color: AppColors.amountRowIn,
          isPositive: true,
        ),
        const SizedBox(height: 12),

        // Out Amount Row
        _AmountRow(
          label: AppText.outValue,
          amount: "₹$outAmount",
          color: AppColors.amountRowOut,
          isPositive: false,
        ),
      ],
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;
  final bool isPositive;

  const _AmountRow({
    required this.label,
    required this.amount,
    required this.color,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Label Badge
        Container(
          padding: AppSpacing.walletAmountRow,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // Amount
        Text(
          amount,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            //color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
