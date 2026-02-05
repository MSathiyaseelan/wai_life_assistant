import 'package:flutter/material.dart';

class AppRadius {
  AppRadius._();

  static const none = 0.0;

  // Small elements
  static const xs = 4.0; // chips, tags
  static const sm = 8.0; // buttons, text fields

  // Default
  static const md = 12.0; // cards, list items, bottom sheets

  // Large surfaces
  static const lg = 16.0; // dialogs, modals

  // Extra large
  static const xl = 24.0; // full-width sheets, feature sections

  static const small = BorderRadius.all(Radius.circular(8));
  static const medium = BorderRadius.all(Radius.circular(12));
  static const large = BorderRadius.all(Radius.circular(16));

  static const walletSummaryRadius = BorderRadius.all(Radius.circular(12));

  static const double card = 12;
  static const double avatarSM = 14;
  static const double avatarMD = 24;
}

// | Component            | Radius            |
// | -------------------- | ----------------- |
// | Buttons              | `sm (8)`          |
// | TextFields           | `sm (8)`          |
// | Chips                | `xs (4)`          |
// | Cards / List items   | `md (12)`         |
// | BottomSheet          | `md / lg (12–16)` |
// | Dialog               | `lg (16)`         |
// | Full-screen sections | `xl (24)`         |
