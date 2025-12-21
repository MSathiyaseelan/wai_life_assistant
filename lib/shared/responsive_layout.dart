import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget child;

  const ResponsiveLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
              maxWidth: _maxWidth(constraints.maxWidth),
            ),
            child: child,
          ),
        );
      },
    );
  }

  double _maxWidth(double width) {
    if (width >= 1200) return 1100; // web
    if (width >= 800) return 720; // tablet
    return width; // mobile
  }
}
