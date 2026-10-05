import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keeps every route clear of the Android system navigation bar.
///
/// Android 15 forces edge-to-edge for apps targeting SDK 35, so pages draw
/// underneath the 3-button / gesture bar and bottom-anchored controls (chat
/// inputs, save buttons, FABs) end up hidden behind it. Wrapping the app in
/// a bottom-only SafeArea fixes this for all routes, sheets and dialogs at
/// once. SafeArea consumes the padding, so widgets that already add
/// `MediaQuery.padding.bottom` see 0 and don't double up. The strip under
/// the nav bar is painted with the scaffold background colour.
///
/// On Android 15+ it also states the system bar icon colours explicitly.
/// Nothing in the app ever set the navigation bar's, so the system picked
/// one from whatever was behind the bar — and on a Galaxy A16 (One UI,
/// 3-button nav) it kept flipping, making the status bar icons and the
/// nav buttons blink on and off. Older Android versions aren't edge-to-edge
/// and keep their default bars, so they're left untouched.
///
/// Call [init] once before runApp. Use as
/// `MaterialApp(builder: (context, child) => SystemNavInset(child: child!))`.
class SystemNavInset extends StatelessWidget {
  final Widget child;
  const SystemNavInset({super.key, required this.child});

  static bool _edgeToEdge = false;

  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      _edgeToEdge = info.version.sdkInt >= 35;
    } catch (_) {
      // Unknown SDK — leave the system bars alone, as before.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inset = ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(top: false, left: false, right: false, child: child),
    );
    if (!_edgeToEdge) return inset;

    final icons =
        theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark;
    // App bars still set the status bar for the screens that have one; this
    // covers the navigation bar everywhere and the status bar elsewhere.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarIconBrightness: icons,
        systemNavigationBarColor: theme.scaffoldBackgroundColor,
        systemNavigationBarIconBrightness: icons,
        systemNavigationBarContrastEnforced: false,
      ),
      child: inset,
    );
  }
}
