import 'dart:io';
import 'package:flutter/material.dart';

/// Displays either an emoji string or an image (local file or remote URL).
/// Detects automatically: if [value] starts with '/' or 'http' it renders an image,
/// otherwise renders an emoji Text.
class EmojiOrImage extends StatelessWidget {
  final String value;
  /// The font size for emoji text, also used to derive image dimensions.
  final double size;
  /// Border radius for image (default: size / 4).
  final double? borderRadius;

  const EmojiOrImage({
    super.key,
    required this.value,
    required this.size,
    this.borderRadius,
  });

  bool get _isRemote => value.startsWith('http://') || value.startsWith('https://');
  bool get _isLocal  => value.startsWith('/') || value.startsWith('file://');

  @override
  Widget build(BuildContext context) {
    if (_isRemote || _isLocal) {
      final radius = borderRadius ?? size / 4;
      Widget img;
      if (_isRemote) {
        img = Image.network(
          value,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Text('👤', style: TextStyle(fontSize: size * 0.6)),
        );
      } else {
        final path = value.startsWith('file://') ? value.substring(7) : value;
        img = Image.file(
          File(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Text('👤', style: TextStyle(fontSize: size * 0.6)),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: img,
      );
    }
    return Text(value.isEmpty ? '👪' : value, style: TextStyle(fontSize: size));
  }
}
