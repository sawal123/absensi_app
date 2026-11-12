import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../core/formatters.dart';
import '../../data/models/user.dart';
import '../../data/models/work_shift.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/page_header.dart';
import '../../widgets/section_header.dart';
import '../../widgets/surface_card.dart';
import 'bulk_schedule_screen.dart';
import 'shifts_screen.dart';

class ScheduleManagementTab extends StatelessWidget {
  const ScheduleManagementTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, admin, _) {
        final date = admin.selectedDate;
        final employees = admin.employees;
        final activeShifts = admin.shifts.where((s) => s.isActive).toList();

        final counts = <int, int>{};
        for (final employee in employees) {
          final shiftId = admin.shiftForEmployee(employee.id!)?.id;
          if (shiftId != null) {
            counts[shiftId] = (counts[shiftId] ?? 0) + 1;
          }
        }

        return SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: admin.load,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const PageHeader(
                  title: 'Jadwal Shift',
                  subtitle: 'Plotting karyawan ke shift per tanggal.',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DateSelector(
                        date: date,
                        onTap: () => _pickDate(context, admin),
                      ),
                      const SizedBox(height: 18),
                      SectionHeader(
                        title: 'Template shift',
                        actionLabel: 'Kelola',
                        onAction: () => _openShifts(context),
                      ),
                      const SizedBox(height: 10),
                      if (activeShifts.isEmpty)
                        const EmptyState(
                          icon: Icons.more_time_outlined,
                          title: 'Belum ada shift aktif',
                          subtitle:
                              'Tambahkan shift terlebih dahulu melalui '
                              'Kelola Shift.',
                        )
                      else
                        SurfaceCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: Column(
                            children: [
                              for (var i = 0; i < activeShifts.length; i++) ...[
                                if (i > 0) const Divider(height: 1),
                                _ShiftSummaryRow(
                                  shift: activeShifts[i],
                                  assignedCount:
                                      counts[activeShifts[i].id] ?? 0,
                                ),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 22),
                      SectionHeader(
                        title: 'Plotting karyawan · ${employees.length}',
                        actionLabel: formatShortDate(date),
                        actionColor: AppPalette.primary,
                      ),
                      const SizedBox(height: 10),
                      if (admin.loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (employees.isEmpty)
                        const EmptyState(
                          icon: Icons.group_off_outlined,
                          title: 'Belum ada karyawan',
                          subtitle:
                              'Tambahkan karyawan sebelum mengatur jadwal.',
                        )
                      else
                        SurfaceCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (var i = 0; i < employees.length; i++) ...[
                                if (i > 0)
                                  const Divider(
                                    height: 1,
                                    indent: 16,
                                    endIndent: 16,
                                  ),
                                _EmployeeScheduleRow(
                                  employee: employees[i],
                                  shift: admin.shiftForEmployee(
                                    employees[i].id!,
                                  ),
                                  onTap: () =>
                                      _pickShift(context, admin, employees[i]),
                                  onBulkTap: () =>
                                      _openBulk(context, admin, employees[i]),
                                ),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 14),
                      const Text(
                        'Ketuk karyawan untuk memilih shift atau menandai '
                        'libur pada satu tanggal. Gunakan ikon kalender untuk '
                        'mengatur banyak tanggal sekaligus. Jadwal ini dipakai '
                        'saat absen masuk: karyawan hanya bisa absen dalam '
                        'batas waktu sebelum shift.',
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.5,
                          color: AppPalette.faint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDate(BuildContext context, AdminProvider admin) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: admin.selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      await admin.selectDate(picked);
    }
  }

  void _openShifts(BuildContext context) {
    final admin = context.read<AdminProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<AdminProvider>.value(
          value: admin,
          child: const ShiftsScreen(),
        ),
      ),
    );
  }

  Future<void> _openBulk(
    BuildContext context,
    AdminProvider admin,
    User employee,
  ) async {
    final count = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<AdminProvider>.value(
          value: admin,
          child: BulkScheduleScreen(employee: employee),
        ),
      ),
    );
    if (count == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$count tanggal diperbarui untuk ${firstNameOf(employee.name)}.',
        ),
      ),
    );
  }

  Future<void> _pickShift(
    BuildContext context,
    AdminProvider admin,
    User employee,
  ) async {
    final current = admin.shiftForEmployee(employee.id!);
    final shifts = admin.shifts.where((s) => s.isActive).toList();
    final selection = await showModalBottomSheet<_ShiftSelection>(
      context: context,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    employee.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'NIP ${employee.nip} · ${formatFullDate(admin.selectedDate)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppPalette.muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final shift in shifts)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(shift.resolvedColorValue)
                              .withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: Color(shift.resolvedColorValue),
                        ),
                      ),
                      title: Text(
                        shift.name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${shift.rangeLabel} · ${shift.hours} jam',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: current?.id == shift.id
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: Color(shift.resolvedColorValue),
                            )
                          : null,
                      onTap: () =>
                          Navigator.pop(context, _ShiftSelection(shift.id)),
                    ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.event_busy_outlined,
                      color: AppPalette.muted,
                    ),
                    title: const Text(
                      'Libur',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Hapus plotting shift pada tanggal ini.',
                      style: TextStyle(fontSize: 11),
                    ),
                    trailing: current == null
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: AppPalette.primary,
                          )
                        : null,
                    onTap: () =>
                        Navigator.pop(context, const _ShiftSelection(null)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selection == null) return;
    final ok = await admin.assignShift(
      employeeId: employee.id!,
      shiftId: selection.shiftId,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Jadwal ${firstNameOf(employee.name)} diperbarui.'
              : (admin.error ?? 'Gagal menyimpan plotting shift.'),
        ),
      ),
    );
    if (!ok) admin.clearError();
  }
}

class _ShiftSelection {
  const _ShiftSelection(this.shiftId);

  final int? shiftId;
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
              formatFullDate(date),
              style: const TextStyle(
                fontSize: 13.5,
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

class _ShiftSummaryRow extends StatelessWidget {
  const _ShiftSummaryRow({required this.shift, required this.assignedCount});

  final WorkShift shift;
  final int assignedCount;

  @override
  Widget build(BuildContext context) {
    final color = Color(shift.resolvedColorValue);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              shift.crossDay ? Icons.nightlight_round : Icons.wb_sunny_outlined,
              size: 17,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shift.name,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${shift.rangeLabel} · ${shift.hours} jam',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppPalette.muted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$assignedCount orang',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeScheduleRow extends StatelessWidget {
  const _EmployeeScheduleRow({
    required this.employee,
    required this.shift,
    required this.onTap,
    required this.onBulkTap,
  });

  final User employee;
  final WorkShift? shift;
  final VoidCallback onTap;
  final VoidCallback onBulkTap;

  @override
  Widget build(BuildContext context) {
    final color = shift == null ? null : Color(shift!.resolvedColorValue);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            InitialsAvatar(name: employee.name, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.name,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'NIP ${employee.nip}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppPalette.faint,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  shift?.name ?? 'Libur',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: color ?? AppPalette.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  shift?.rangeLabel ?? 'Tidak ada shift',
                  style: const TextStyle(fontSize: 10, color: AppPalette.faint),
                ),
              ],
            ),
            IconButton(
              tooltip: 'Atur banyak tanggal',
              onPressed: onBulkTap,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              icon: const Icon(
                Icons.date_range_rounded,
                size: 19,
                color: AppPalette.primary,
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppPalette.faint,
            ),
          ],
        ),
      ),
    );
  }
}
