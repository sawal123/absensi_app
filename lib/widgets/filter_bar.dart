import 'package:flutter/material.dart';

import '../core/app_palette.dart';

class FilterOption {
  const FilterOption({required this.label, this.count});

  final String label;
  final int? count;
}

class FilterChipBar extends StatelessWidget {
  const FilterChipBar({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<FilterOption> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          final selected = index == selectedIndex;
          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppPalette.primary : AppPalette.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? AppPalette.primary : AppPalette.border,
                ),
              ),
              child: Text(
                option.count == null
                    ? option.label
                    : '${option.count} ${option.label}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : AppPalette.muted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class SegmentOption {
  const SegmentOption({required this.label, this.count});

  final String label;
  final int? count;
}

class SegmentedSwitch extends StatelessWidget {
  const SegmentedSwitch({
    super.key,
    required this.options,
    required this.index,
    required this.onChanged,
  });

  final List<SegmentOption> options;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppPalette.slate,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? AppPalette.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: i == index
                        ? const [
                            BoxShadow(
                              color: Color(0x140F172A),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          options[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: i == index
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: i == index
                                ? AppPalette.primary
                                : AppPalette.muted,
                          ),
                        ),
                      ),
                      if (options[i].count != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: i == index
                                ? AppPalette.blueSoft
                                : AppPalette.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${options[i].count}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: i == index
                                  ? AppPalette.primary
                                  : AppPalette.muted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
