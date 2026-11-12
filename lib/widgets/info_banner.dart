import 'package:flutter/material.dart';

import '../core/app_palette.dart';
import 'status_pill.dart';

class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.tone = StatusTone.info,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? message;
  final StatusTone tone;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tone.foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: tone.foreground,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    message!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.45,
                      color: AppPalette.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}
