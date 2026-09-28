import 'package:flutter/material.dart';

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
/// Use as `MaterialApp(builder: (context, child) => SystemNavInset(child: child!))`.
class SystemNavInset extends StatelessWidget {
  final Widget child;
  const SystemNavInset({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(top: false, left: false, right: false, child: child),
    );
  }
}
