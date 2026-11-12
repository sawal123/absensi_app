import 'package:flutter/material.dart';

import '../core/app_palette.dart';
import '../data/models/request_status.dart';

enum StatusTone { success, warning, info, neutral, danger }

extension StatusToneColors on StatusTone {
  Color get foreground => switch (this) {
    StatusTone.success => AppPalette.green,
    StatusTone.warning => AppPalette.amber,
    StatusTone.info => AppPalette.primary,
    StatusTone.neutral => AppPalette.muted,
    StatusTone.danger => AppPalette.red,
  };

  Color get background => switch (this) {
    StatusTone.success => AppPalette.greenSoft,
    StatusTone.warning => AppPalette.amberSoft,
    StatusTone.info => AppPalette.blueSoft,
    StatusTone.neutral => AppPalette.slate,
    StatusTone.danger => AppPalette.redSoft,
  };
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.icon,
    this.dense = false,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 12, color: tone.foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: tone.foreground,
              fontSize: dense ? 10.5 : 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

StatusPill requestStatusPill(RequestStatus status) {
  return switch (status) {
    RequestStatus.pending => StatusPill(
      label: status.label,
      tone: StatusTone.warning,
      dense: true,
    ),
    RequestStatus.approved => StatusPill(
      label: status.label,
      tone: StatusTone.success,
      dense: true,
    ),
    RequestStatus.rejected => StatusPill(
      label: status.label,
      tone: StatusTone.danger,
      dense: true,
    ),
    RequestStatus.cancelled => StatusPill(
      label: status.label,
      tone: StatusTone.neutral,
      dense: true,
    ),
  };
}
