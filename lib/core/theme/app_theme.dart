import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_radius.dart';
import 'app_spacing.dart';

class AppTheme {
  AppTheme._();

  static ThemeData lightTheme = ThemeData(
    // primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: AppTextStyles.fontFamily,
    useMaterial3: true,

    // ------------------
    // Text Theme (fallback)
    // ------------------
    textTheme: TextTheme(
      headlineSmall: AppTextStyles.h1,
      titleLarge: AppTextStyles.h2,
      bodyMedium: AppTextStyles.body,
      bodySmall: AppTextStyles.caption,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 24),
      titleTextStyle: AppTextStyles.h2,
    ),

    // ------------------
    // Card
    // ------------------
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),

    // ------------------
    // Divider
    // ------------------
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: AppSpacing.md,
    ),

    // ------------------
    // Buttons
    // ------------------
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: AppColors.primaryLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: AppTextStyles.button,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: AppTextStyles.button.copyWith(color: AppColors.primary),
      ),
    ),

    // ------------------
    // Input Fields
    // ------------------
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      hintStyle: AppTextStyles.hint,
      labelStyle: AppTextStyles.subtitle,
    ),

    // ------------------
    // Bottom Sheet
    // ------------------
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
    ),

    // ------------------
    // Icons
    // ------------------
    iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 24),

    // ------------------
    // Floating Action Button
    // ------------------
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),

    colorScheme: ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      onPrimary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
    ),

    // inputDecorationTheme: InputDecorationTheme(
    //   filled: true,
    //   fillColor: AppColors.surface,
    //   border: OutlineInputBorder(
    //     borderRadius: BorderRadius.circular(AppRadius.md),
    //     borderSide: BorderSide(color: AppColors.border),
    //   ),
    // ),

    // elevatedButtonTheme: ElevatedButtonThemeData(
    //   style: ElevatedButton.styleFrom(
    //     backgroundColor: AppColors.primary,
    //     foregroundColor: Colors.white,
    //     shape: RoundedRectangleBorder(
    //       borderRadius: BorderRadius.circular(AppRadius.md),
    //     ),
    //   ),
    // ),
  );
}
