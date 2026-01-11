import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  static const double maxDesktopMaxWidth = 1200;
  static const double desktopMaxWidth = 700;
  static const double tabletMaxWidth = 500;
  static const double maxTabletMaxWidth = 600;

  //Wallet
  static const screenPadding = EdgeInsets.all(2);
  static const gapS = 2.0;
  static const gapSS = 4.0;
  static const gapSM = 6.0;
  static const gapSSS = 8.0;
  static const gapMM = 12.0;
  static const gapM = 16.0;
  static const gapL = 24.0;

  //summary card padding
  static const EdgeInsets summaryCardPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  );

  static const chipPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 8);

  static const chipIconPadding = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 10,
  );

  static const walletChipBarPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 8,
  );

  static const walletChipSpacing = 8.0;
}

//Usage
//SizedBox(height: AppSpacing.md);
