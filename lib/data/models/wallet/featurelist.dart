import 'package:flutter/material.dart';

class FeatureItem {
  final String title;
  final IconData icon;
  final WidgetBuilder pageBuilder;

  const FeatureItem({
    required this.title,
    required this.icon,
    required this.pageBuilder,
  });
}
