import 'package:flutter/material.dart';

import '../core/app_palette.dart';
import '../core/formatters.dart';
import 'surface_card.dart';

class MonthSelector extends StatelessWidget {
  const MonthSelector({super.key, required this.month, required this.onTap});

  final DateTime month;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: Row(
        children: [
          const Icon(
            Icons.calendar_month_rounded,
            size: 19,
            color: AppPalette.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              formatMonthYear(month),
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppPalette.ink,
              ),
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: AppPalette.primary,
          ),
        ],
      ),
    );
  }
}

Future<DateTime?> showMonthPicker(
  BuildContext context,
  DateTime current, {
  int monthsBack = 12,
}) {
  final now = DateTime.now();
  final months = List.generate(
    monthsBack + 1,
    (index) => DateTime(now.year, now.month - index),
  );
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: AppPalette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Pilih bulan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.ink,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 360,
                child: ListView.builder(
                  itemCount: months.length,
                  itemBuilder: (context, index) {
                    final month = months[index];
                    final selected =
                        month.year == current.year &&
                        month.month == current.month;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        formatMonthYear(month),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected ? AppPalette.primary : AppPalette.ink,
                        ),
                      ),
                      trailing: selected
                          ? const Icon(
                              Icons.check_rounded,
                              color: AppPalette.primary,
                              size: 20,
                            )
                          : null,
                      onTap: () => Navigator.pop(context, month),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
