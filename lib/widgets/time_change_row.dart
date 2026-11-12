import 'package:flutter/material.dart';

import '../core/app_palette.dart';

/// Baris perbandingan "data tercatat → diusulkan" pada perbaikan absensi.
class TimeChangeRow extends StatelessWidget {
  const TimeChangeRow({
    super.key,
    required this.label,
    required this.recorded,
    required this.proposed,
    required this.highlight,
    this.sub,
    this.proposedSub,
  });

  final String label;
  final String? sub;
  final String recorded;
  final String proposed;
  final String? proposedSub;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        SizedBox(
          width: 66,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.ink,
                ),
              ),
              if (sub != null)
                Text(
                  sub!,
                  style: const TextStyle(fontSize: 9, color: AppPalette.faint),
                ),
            ],
          ),
        ),
        Expanded(
          child: Text(
            recorded,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppPalette.ink,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                proposed,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: highlight ? AppPalette.primary : AppPalette.ink,
                ),
              ),
              if (proposedSub != null)
                Text(
                  proposedSub!,
                  style: const TextStyle(fontSize: 9, color: AppPalette.muted),
                ),
            ],
          ),
        ),
      ],
    );

    if (!highlight) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: row,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: AppPalette.blueSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: row,
    );
  }
}
