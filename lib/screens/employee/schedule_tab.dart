import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../core/formatters.dart';
import '../../data/models/work_shift.dart';
import '../../providers/attendance_provider.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/page_header.dart';
import '../../widgets/section_header.dart';
import '../../widgets/surface_card.dart';

class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  late DateTime _week;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _week = startOfWeek(now);
    _selected = dateOnly(now);
  }

  void _moveWeek(int days) {
    setState(() {
      _week = _week.add(Duration(days: days));
      _selected = _selected.add(Duration(days: days));
    });
  }

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<AttendanceProvider>();
    final days = attendance.weekOf(_week);
    final selectedShift = attendance.shiftFor(_selected);
    final next = attendance.nextShift(DateTime.now());

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: attendance.load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const PageHeader(
              title: 'Jadwal Shift',
              subtitle: 'Atur harimu, kenali waktu kerjamu.',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WeekCard(
                    week: _week,
                    days: days,
                    selected: _selected,
                    onSelect: (date) => setState(() => _selected = date),
                    onPrevious: () => _moveWeek(-7),
                    onNext: () => _moveWeek(7),
                  ),
                  const SizedBox(height: 22),
                  const SectionHeader(
                    title: 'Jadwal terdekat',
                    actionLabel: 'Semua waktu WIB',
                  ),
                  const SizedBox(height: 10),
                  _ShiftCard(
                    date: _selected,
                    shift: selectedShift,
                    highlighted: isSameDay(_selected, DateTime.now()),
                  ),
                  if (next != null) ...[
                    const SizedBox(height: 12),
                    _NextShiftCard(date: next.date, shift: next.shift),
                    const SizedBox(height: 14),
                    InfoBanner(
                      icon: Icons.info_outline_rounded,
                      title: next.shift.crossDay
                          ? 'Absen pulang shift malam dilakukan '
                                '${formatDayName(next.date.add(const Duration(days: 1)))}, '
                                '${next.date.add(const Duration(days: 1)).day} '
                                '${monthName(next.date.add(const Duration(days: 1)).month)} '
                                'setelah pukul ${formatClockValue(next.shift.end)} WIB.'
                          : 'Shift berikutnya dimulai pukul '
                                '${formatClockValue(next.shift.start)} WIB.',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.week,
    required this.days,
    required this.selected,
    required this.onSelect,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime week;
  final List<ShiftDay> days;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatMonthYear(week),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.ink,
                  ),
                ),
              ),
              _ArrowButton(icon: Icons.chevron_left, onTap: onPrevious),
              const SizedBox(width: 4),
              _ArrowButton(icon: Icons.chevron_right, onTap: onNext),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final day in days)
                Expanded(
                  child: _DayColumn(
                    day: day,
                    selected: isSameDay(day.date, selected),
                    onTap: () => onSelect(day.date),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pekan ${formatDateRange(days.first.date, days.last.date)}',
                  style: const TextStyle(fontSize: 11, color: AppPalette.muted),
                ),
              ),
              Text(
                'Hari ini: ${formatDayShort(now)}, ${now.day} '
                '${monthShort(now.month)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Icon(icon, size: 20, color: AppPalette.primary),
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final ShiftDay day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shiftColor = day.shift == null
        ? AppPalette.primary
        : Color(day.shift!.resolvedColorValue);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        children: [
          Text(
            formatDayShort(day.date),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: selected ? AppPalette.primary : AppPalette.muted,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 34,
            height: 46,
            decoration: BoxDecoration(
              color: selected ? AppPalette.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.date.day}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppPalette.ink,
                  ),
                ),
                const SizedBox(height: 4),
                if (day.shift != null)
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : shiftColor,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({
    required this.date,
    required this.shift,
    required this.highlighted,
  });

  final DateTime date;
  final WorkShift? shift;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    if (shift == null) {
      return const SurfaceCard(
        child: Row(
          children: [
            _IconBox(icon: Icons.event_busy_outlined),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hari libur',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tidak ada shift terjadwal untuk hari ini.',
                    style: TextStyle(fontSize: 11.5, color: AppPalette.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final label = highlighted
        ? 'Hari ini · ${formatDayName(date)}, ${date.day} ${monthShort(date.month)}'
        : '${formatDayName(date)}, ${date.day} ${monthName(date.month)}';

    if (highlighted) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: AppPalette.headerGradient,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                _GlassChip(label: shift!.name),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.wb_sunny_outlined,
                  size: 26,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  shift!.rangeLabel,
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              [
                shift!.office,
                if (shift!.breakLabel != null) shift!.breakLabel!,
              ].join(' · '),
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),
          ],
        ),
      );
    }

    final color = Color(shift!.resolvedColorValue);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.muted,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  shift!.name,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.wb_sunny_outlined, size: 24, color: color),
              const SizedBox(width: 8),
              Text(
                shift!.rangeLabel,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                  color: AppPalette.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            [
              shift!.office,
              if (shift!.breakLabel != null) shift!.breakLabel!,
            ].join(' · '),
            style: const TextStyle(fontSize: 11.5, color: AppPalette.muted),
          ),
        ],
      ),
    );
  }
}

class _NextShiftCard extends StatelessWidget {
  const _NextShiftCard({required this.date, required this.shift});

  final DateTime date;
  final WorkShift shift;

  @override
  Widget build(BuildContext context) {
    final endDate = date.add(Duration(days: shift.crossDay ? 1 : 0));
    final color = Color(shift.resolvedColorValue);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _IconBox(
                icon: shift.crossDay
                    ? Icons.nightlight_round
                    : Icons.wb_sunny_outlined,
                color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  shift.name,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.ink,
                  ),
                ),
              ),
              if (shift.crossDay)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.blueSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Lintas hari',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mulai · ${formatDayName(date)}, ${date.day} '
                      '${monthShort(date.month)}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppPalette.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatClockValue(shift.start),
                      style: const TextStyle(
                        fontSize: 26,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: AppPalette.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: AppPalette.faint,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Selesai · ${formatDayName(endDate)}, ${endDate.day} '
                      '${monthShort(endDate.month)}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppPalette.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatClockValue(shift.end),
                      style: TextStyle(
                        fontSize: 26,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: AppPalette.muted,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${shift.office} · ${shift.hours} jam'
                  '${shift.crossDay ? ' · Berakhir esok hari' : ''}',
                  style: const TextStyle(fontSize: 11, color: AppPalette.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? AppPalette.primary;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 19, color: resolved),
    );
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
