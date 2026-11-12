import 'package:flutter/material.dart';

import '../core/app_palette.dart';

class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.greeting,
    required this.name,
    required this.initials,
    this.meta,
    this.onBellTap,
  });

  final String greeting;
  final String name;
  final String initials;
  final String? meta;
  final VoidCallback? onBellTap;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppPalette.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, topInset + 16, 20, 26),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.4,
              ),
            ),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                if (meta != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    meta!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onBellTap != null)
            Material(
              color: Colors.white.withValues(alpha: 0.16),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onBellTap,
                child: const SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
