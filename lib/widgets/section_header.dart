import 'package:flutter/material.dart';

import '../core/app_palette.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.actionColor = AppPalette.primary,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color actionColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppPalette.ink,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (actionLabel != null)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: actionColor,
                      ),
                    ),
                    if (onAction != null) ...[
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_forward, size: 13, color: actionColor),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
