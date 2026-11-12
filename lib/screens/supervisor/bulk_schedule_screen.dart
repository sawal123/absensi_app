import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../core/formatters.dart';
import '../../data/models/user.dart';
import '../../data/models/work_shift.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/surface_card.dart';

class BulkScheduleScreen extends StatefulWidget {
  const BulkScheduleScreen({super.key, required this.employee});

  final User employee;

  @override
  State<BulkScheduleScreen> createState() => _BulkScheduleScreenState();
}

class _BulkScheduleScreenState extends State<BulkScheduleScreen> {
  late DateTime _month;
  final Set<String> _selected = {};
  final Map<String, int> _appliedColors = {};
  int? _shiftId;
  bool _initialized = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final admin = context.read<AdminProvider>();
    final anchor = admin.selectedDate;
    _month = DateTime(anchor.year, anchor.month);
    final active = admin.shifts.where((shift) => shift.isActive).toList();
    _shiftId =
        admin.shiftForEmployee(widget.employee.id!)?.id ??
        (active.isEmpty ? null : active.first.id);
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  void _toggleDate(DateTime date) {
    final key = dateKey(date);
    setState(() {
      if (!_selected.remove(key)) _selected.add(key);
    });
  }

  void _toggleMonth({required bool Function(DateTime date) where}) {
    final last = DateTime(_month.year, _month.month + 1, 0).day;
    setState(() {
      for (var day = 1; day <= last; day++) {
        final date = DateTime(_month.year, _month.month, day);
        if (where(date)) _selected.add(dateKey(date));
      }
    });
  }

  Future<void> _apply(AdminProvider admin) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final dates = _selected.map(DateTime.parse).toList()..sort();
    final ok = await admin.assignShiftDates(
      employeeId: widget.employee.id!,
      dates: dates,
      shiftId: _shiftId,
    );
    if (!mounted) return;
    if (ok) {
      final count = dates.length;
      final isLibur = _shiftId == null;
      final colorValue = _selectedColor(admin);
      final keys = dates.map(dateKey).toSet();
      final messenger = ScaffoldMessenger.of(context);
      setState(() {
        _saving = false;
        if (isLibur || colorValue == null) {
          for (final key in keys) {
            _appliedColors.remove(key);
          }
        } else {
          for (final key in keys) {
            _appliedColors[key] = colorValue;
          }
        }
        _selected.clear();
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isLibur
                ? '$count tanggal ditandai libur.'
                : '$count tanggal berhasil dijadwalkan.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _saving = false;
      _error = admin.error ?? 'Gagal menyimpan jadwal.';
    });
    admin.clearError();
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final shifts = admin.shifts.where((shift) => shift.isActive).toList();
    final selectedShift = _shiftFor(shifts);
    final count = _selected.length;

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(title: const Text('Atur Jadwal Massal')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          _EmployeeCard(employee: widget.employee),
          const SizedBox(height: 14),
          SurfaceCard(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _ArrowButton(
                      icon: Icons.chevron_left,
                      onTap: () => _changeMonth(-1),
                    ),
                    Expanded(
                      child: Text(
                        formatMonthYear(_month),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.ink,
                        ),
                      ),
                    ),
                    _ArrowButton(
                      icon: Icons.chevron_right,
                      onTap: () => _changeMonth(1),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final label in const [
                      'Sen',
                      'Sel',
                      'Rab',
                      'Kam',
                      'Jum',
                      'Sab',
                      'Min',
                    ])
                      Expanded(
                        child: Center(
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppPalette.faint,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                _MonthGrid(
                  month: _month,
                  selected: _selected,
                  savedColors: _appliedColors,
                  shiftFor: (date) =>
                      admin.shiftForEmployee(widget.employee.id!, date),
                  onToggle: _toggleDate,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ActionChip(
                      label: const Text('Hari kerja'),
                      onPressed: () => _toggleMonth(
                        where: (date) =>
                            date.weekday >= DateTime.monday &&
                            date.weekday <= DateTime.friday,
                      ),
                    ),
                    ActionChip(
                      label: const Text('Semua tanggal'),
                      onPressed: () => _toggleMonth(where: (_) => true),
                    ),
                    ActionChip(
                      label: const Text('Kosongkan'),
                      onPressed: () => setState(_selected.clear),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Warna shift',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.muted,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    for (final shift in shifts)
                      _LegendMark(
                        background: Color(shift.resolvedColorValue)
                            .withValues(alpha: 0.16),
                        foreground: Color(shift.resolvedColorValue),
                        label: shift.name,
                      ),
                    const _LegendMark(
                      background: AppPalette.primary,
                      foreground: Colors.white,
                      label: 'Sedang dipilih',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Pilih shift'),
          const SizedBox(height: 10),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final shift in shifts)
                      ChoiceChip(
                        avatar: CircleAvatar(
                          radius: 6,
                          backgroundColor: Color(shift.resolvedColorValue),
                        ),
                        showCheckmark: false,
                        selectedColor: Color(shift.resolvedColorValue)
                            .withValues(alpha: 0.16),
                        label: Text('${shift.name} · ${shift.rangeLabel}'),
                        selected: _shiftId == shift.id,
                        onSelected: (_) => setState(() => _shiftId = shift.id),
                      ),
                    ChoiceChip(
                      avatar: const CircleAvatar(
                        radius: 6,
                        backgroundColor: AppPalette.faint,
                      ),
                      showCheckmark: false,
                      label: const Text('Libur'),
                      selected: _shiftId == null,
                      onSelected: (_) => setState(() => _shiftId = null),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  selectedShift == null
                      ? 'Tanggal terpilih akan ditandai libur.'
                      : 'Shift ${selectedShift.name} '
                            '(${selectedShift.rangeLabel}) akan diterapkan '
                            'ke tanggal terpilih.',
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    color: AppPalette.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          InfoBanner(
            icon: count == 0
                ? Icons.event_note_outlined
                : Icons.event_available_rounded,
            title: count == 0
                ? 'Belum ada tanggal dipilih'
                : '$count tanggal dipilih',
            tone: count == 0 ? StatusTone.neutral : StatusTone.info,
            message: count == 0
                ? 'Centang tanggal pada kalender untuk menerapkan jadwal '
                      'sekaligus.'
                : 'Jadwal akan diterapkan ke $count tanggal terpilih.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppPalette.surface,
          border: Border(top: BorderSide(color: AppPalette.border)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: count == 0 || _saving ? null : () => _apply(admin),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.done_all_rounded, size: 19),
                label: Text(
                  _saving
                      ? 'Menyimpan...'
                      : selectedShift == null
                      ? 'Terapkan Libur ke $count tanggal'
                      : 'Terapkan ke $count tanggal',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Centang beberapa tanggal, pilih shift, lalu terapkan. '
                'Tanggal yang sudah disimpan ditandai centang hijau.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: AppPalette.faint),
              ),
            ],
          ),
        ),
      ),
    );
  }

  WorkShift? _shiftFor(List<WorkShift> shifts) {
    for (final shift in shifts) {
      if (shift.id == _shiftId) return shift;
    }
    return null;
  }

  int? _selectedColor(AdminProvider admin) {
    for (final shift in admin.shifts) {
      if (shift.id == _shiftId) return shift.resolvedColorValue;
    }
    return null;
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.employee});

  final User employee;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
        children: [
          InitialsAvatar(name: employee.name, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'NIP ${employee.nip} · ${employee.position}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppPalette.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.savedColors,
    required this.shiftFor,
    required this.onToggle,
  });

  final DateTime month;
  final Set<String> selected;
  final Map<String, int> savedColors;
  final WorkShift? Function(DateTime date) shiftFor;
  final ValueChanged<DateTime> onToggle;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - DateTime.monday;
    final cells = ((leading + days) / 7).ceil() * 7;
    final today = dateOnly(DateTime.now());

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final day = index - leading + 1;
        if (day < 1 || day > days) return const SizedBox.shrink();
        final date = DateTime(month.year, month.month, day);
        final key = dateKey(date);
        final assignedColor =
            shiftFor(date)?.resolvedColorValue ?? savedColors[key];
        return _DayCell(
          date: date,
          selected: selected.contains(key),
          assignedColor: assignedColor,
          isToday: isSameDay(date, today),
          onTap: () => onToggle(date),
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.assignedColor,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final int? assignedColor;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = assignedColor == null ? null : Color(assignedColor!);
    final background = selected
        ? AppPalette.primary
        : color == null
        ? AppPalette.slate
        : color.withValues(alpha: 0.14);
    final foreground = selected ? Colors.white : color ?? AppPalette.ink;
    final assigned = color != null;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: isToday && !selected
              ? Border.all(color: AppPalette.primary, width: 1.2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected || assigned
                    ? FontWeight.w800
                    : FontWeight.w600,
                color: foreground,
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 12,
              child: selected || assigned
                  ? Icon(
                      Icons.check_rounded,
                      size: 11,
                      color: selected ? Colors.white : color,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendMark extends StatelessWidget {
  const _LegendMark({
    required this.background,
    required this.foreground,
    required this.label,
  });

  final Color background;
  final Color foreground;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(Icons.check_rounded, size: 10, color: foreground),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 9.5, color: AppPalette.muted),
        ),
      ],
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
        width: 32,
        height: 32,
        child: Icon(icon, size: 22, color: AppPalette.primary),
      ),
    );
  }
}
