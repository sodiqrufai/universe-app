import 'package:flutter/material.dart';

/// The UniVerse "UV" monogram. Single source of truth for every in-app logo.
/// Asset: assets/images/logo_mark.png (transparent PNG, blue→purple).
class UniVerseLogo extends StatelessWidget {
  final double size;

  /// Draws a white circular badge behind the mark — use on purple/dark
  /// backgrounds (splash) where the transparent mark would lose contrast.
  final bool badge;

  const UniVerseLogo({super.key, this.size = 48, this.badge = false});

  @override
  Widget build(BuildContext context) {
    final mark = Image.asset(
      'assets/images/logo_mark.png',
      width: badge ? size * 0.82 : size,
      height: badge ? size * 0.82 : size,
      fit: BoxFit.contain,
      semanticLabel: 'UniVerse logo',
      filterQuality: FilterQuality.high,
    );
    if (!badge) return mark;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: mark,
    );
  }
}
