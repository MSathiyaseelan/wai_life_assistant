import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const String fontFamily = 'Inter';

  // ------------------
  // Headings
  // ------------------

  static const TextStyle h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // ------------------
  // Titles & labels
  // ------------------

  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  // ------------------
  // Body text
  // ------------------

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // ------------------
  // Small / helper text
  // ------------------

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textHint,
  );

  static const TextStyle hint = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textHint,
  );

  // ------------------
  // Buttons
  // ------------------

  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  // ------------------
  // Special cases
  // ------------------

  // Wallet amounts, totals
  static const TextStyle amount = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle amountLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  // Error / success messages
  static const TextStyle error = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.error,
  );

  static const TextStyle success = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.success,
  );

  static const TextStyle bold = TextStyle(fontWeight: FontWeight.w600);
}

// | Style       | Size | Usage           |
// | ----------- | ---- | --------------- |
// | h1          | 24   | Page titles     |
// | h2          | 20   | Section headers |
// | h3          | 18   | Card headers    |
// | title       | 16   | List titles     |
// | body        | 14   | Main content    |
// | caption     | 12   | Hints, meta     |
// | button      | 14   | All buttons     |
// | amountLarge | 24   | Wallet totals   |


//Usage Example
// Text(
//   'Wallet',
//   style: AppTextStyles.h1,
// );

// Text(
//   'Add Transaction',
//   style: AppTextStyles.button,
// );

// Text(
//   '₹ 2,450',
//   style: AppTextStyles.amountLarge,
// );


