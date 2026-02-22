import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const primary = Color(0xFF6C63FF);
  static const primaryLight = Color(0xFFEEEDFF);
  static const primaryDark = Color(0xFF4B44CC);

  // Transaction types
  static const income = Color(0xFF00C897);
  static const expense = Color(0xFFFF5C7A);
  static const split = Color(0xFF4A9EFF);
  static const lend = Color(0xFFFFAA2C);
  static const borrow = Color(0xFF00D0D0);
  static const request = Color(0xFFFF7043);

  // Income/expense bg tints
  static const incomeBg = Color(0xFFE6FAF5);
  static const expenseBg = Color(0xFFFFECEF);
  static const splitBg = Color(0xFFE8F3FF);
  static const lendBg = Color(0xFFFFF4E0);
  static const borrowBg = Color(0xFFE0FAFA);
  static const requestBg = Color(0xFFFFF0EB);

  // Cash vs Online
  static const cash = Color(0xFF43A047);
  static const online = Color(0xFF1E88E5);

  // Neutrals
  static const bgLight = Color(0xFFF5F6FA);
  static const bgDark = Color(0xFF0E0E1A);
  static const cardLight = Color(0xFFFFFFFF);
  static const cardDark = Color(0xFF1A1A2E);
  static const surfDark = Color(0xFF16213E);
  static const textLight = Color(0xFF1A1A2E);
  static const textDark = Color(0xFFF0F0FF);
  static const subLight = Color(0xFF8E8EA0);
  static const subDark = Color(0xFF6E6E90);

  // Personal wallet gradient
  static const personalGrad = [Color(0xFF6C63FF), Color(0xFF3D35CC)];
  // Family wallet gradient options
  static const familyGrad1 = [Color(0xFF00C897), Color(0xFF009E76)];
  static const familyGrad2 = [Color(0xFFFF5C7A), Color(0xFFCC2E50)];
  static const familyGrad3 = [Color(0xFFFFAA2C), Color(0xFFCC8000)];
  static const familyGrad4 = [Color(0xFF4A9EFF), Color(0xFF1A6ECC)];

  static List<List<Color>> familyGradients = [
    familyGrad1,
    familyGrad2,
    familyGrad3,
    familyGrad4,
  ];
}

class AppTheme {
  static ThemeData light() => ThemeData(
    useMaterial3: true,
    fontFamily: 'Nunito',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: AppColors.bgLight,
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.cardLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgLight,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: AppColors.textLight),
      titleTextStyle: TextStyle(
        fontFamily: 'Nunito',
        fontWeight: FontWeight.w800,
        fontSize: 20,
        color: AppColors.textLight,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.cardLight,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.subLight,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
  );

  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    fontFamily: 'Nunito',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: AppColors.bgDark,
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: AppColors.textDark),
      titleTextStyle: TextStyle(
        fontFamily: 'Nunito',
        fontWeight: FontWeight.w800,
        fontSize: 20,
        color: AppColors.textDark,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.cardDark,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.subDark,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
  );
}

// import 'package:flutter/material.dart';
// import 'app_colors.dart';
// import 'app_text_styles.dart';
// import 'app_radius.dart';
// import 'app_spacing.dart';

// class AppTheme {
//   AppTheme._();

//   static ThemeData lightTheme = ThemeData(
//     // primaryColor: AppColors.primary,
//     scaffoldBackgroundColor: AppColors.background,
//     fontFamily: AppTextStyles.fontFamily,
//     useMaterial3: true,

//     // ------------------
//     // Text Theme (fallback)
//     // ------------------
//     textTheme: TextTheme(
//       headlineSmall: AppTextStyles.h1,
//       titleLarge: AppTextStyles.h2,
//       bodyMedium: AppTextStyles.body,
//       bodySmall: AppTextStyles.caption,
//     ),

//     appBarTheme: AppBarTheme(
//       backgroundColor: AppColors.surface,
//       elevation: 0,
//       centerTitle: false,
//       iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 24),
//       titleTextStyle: AppTextStyles.h2,
//     ),

//     // ------------------
//     // Card
//     // ------------------
//     cardTheme: CardThemeData(
//       color: AppColors.surface,
//       elevation: 1,
//       margin: const EdgeInsets.only(bottom: AppSpacing.sm),
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(AppRadius.md),
//       ),
//     ),

//     // ------------------
//     // Divider
//     // ------------------
//     dividerTheme: const DividerThemeData(
//       color: AppColors.divider,
//       thickness: 1,
//       space: AppSpacing.md,
//     ),

//     // ------------------
//     // Buttons
//     // ------------------
//     elevatedButtonTheme: ElevatedButtonThemeData(
//       style: ElevatedButton.styleFrom(
//         minimumSize: const Size.fromHeight(48),
//         backgroundColor: AppColors.primaryLight,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(AppRadius.sm),
//         ),
//         textStyle: AppTextStyles.button,
//       ),
//     ),

//     textButtonTheme: TextButtonThemeData(
//       style: TextButton.styleFrom(
//         textStyle: AppTextStyles.button.copyWith(color: AppColors.primary),
//       ),
//     ),

//     // ------------------
//     // Input Fields
//     // ------------------
//     inputDecorationTheme: InputDecorationTheme(
//       filled: true,
//       fillColor: AppColors.surface,
//       contentPadding: const EdgeInsets.symmetric(
//         horizontal: AppSpacing.lg,
//         vertical: AppSpacing.md,
//       ),
//       border: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(AppRadius.sm),
//         borderSide: const BorderSide(color: AppColors.divider),
//       ),
//       enabledBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(AppRadius.sm),
//         borderSide: const BorderSide(color: AppColors.divider),
//       ),
//       focusedBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(AppRadius.sm),
//         borderSide: const BorderSide(color: AppColors.primary),
//       ),
//       errorBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(AppRadius.sm),
//         borderSide: const BorderSide(color: AppColors.error),
//       ),
//       hintStyle: AppTextStyles.hint,
//       labelStyle: AppTextStyles.subtitle,
//     ),

//     // ------------------
//     // Bottom Sheet
//     // ------------------
//     bottomSheetTheme: BottomSheetThemeData(
//       backgroundColor: AppColors.surface,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
//       ),
//     ),

//     // ------------------
//     // Icons
//     // ------------------
//     iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 24),

//     // ------------------
//     // Floating Action Button
//     // ------------------
//     floatingActionButtonTheme: FloatingActionButtonThemeData(
//       backgroundColor: AppColors.primary,
//       foregroundColor: Colors.white,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(AppRadius.lg),
//       ),
//     ),

//     colorScheme: ColorScheme.light(
//       primary: AppColors.primary,
//       secondary: AppColors.secondary,
//       onPrimary: Colors.white,
//       surface: AppColors.surface,
//       onSurface: AppColors.textPrimary,
//       error: AppColors.error,
//     ),

//     // inputDecorationTheme: InputDecorationTheme(
//     //   filled: true,
//     //   fillColor: AppColors.surface,
//     //   border: OutlineInputBorder(
//     //     borderRadius: BorderRadius.circular(AppRadius.md),
//     //     borderSide: BorderSide(color: AppColors.border),
//     //   ),
//     // ),

//     // elevatedButtonTheme: ElevatedButtonThemeData(
//     //   style: ElevatedButton.styleFrom(
//     //     backgroundColor: AppColors.primary,
//     //     foregroundColor: Colors.white,
//     //     shape: RoundedRectangleBorder(
//     //       borderRadius: BorderRadius.circular(AppRadius.md),
//     //     ),
//     //   ),
//     // ),
//   );
// }
