import 'package:flutter/material.dart';

import '../core/app_palette.dart';

/// Rounded white surface used by almost every block in the designs.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = AppPalette.surface,
    this.border,
    this.radius = 22,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color? border;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(onTap: onTap, child: content);
    }

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: border == null
            ? null
            : BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: border!),
              ),
        child: content,
      ),
    );
  }
}
