import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../core/formatters.dart';
import '../../data/models/attendance.dart';
import '../../data/models/attendance_correction.dart';
import '../../data/models/correction_type.dart';
import '../../data/models/leave_request.dart';
import '../../data/models/user.dart';
import '../../data/models/work_shift.dart';
import '../../providers/admin_provider.dart';
import '../../providers/approval_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/hr_provider.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/live_clock.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/surface_card.dart';
import '../shared/notifications_screen.dart';
import 'correction_detail_screen.dart';
import 'leave_detail_screen.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key, required this.onOpenTab});

  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    return Consumer3<AdminProvider, ApprovalProvider, AuthProvider>(
      builder: (context, admin, approvals, auth, _) {
        final user = auth.currentUser;
        final settings = admin.settings;
        final date = admin.selectedDate;
        final employees = admin.employees;
        final records = {
          for (final record in admin.records) record.userId: record,
        };
        final leaves = approvals.approvedByEmployeeId(date);

        var present = 0;
        var late = 0;
        for (final employee in employees) {
          final record = records[employee.id];
          if (record == null || !record.hasCheckedIn) continue;
          final shiftStart =
              admin.shiftForEmployee(employee.id!, date)?.start ??
              settings.workStart;
          if (isLate(
            record.checkInAt!,
            shiftStart,
            settings.lateToleranceMinutes,
          )) {
            late++;
          } else {
            present++;
          }
        }
        final onLeave = employees
            .where((employee) => leaves.containsKey(employee.id))
            .length;
        final absent = (employees.length - present - late - onLeave).clamp(
          0,
          999,
        );

        return RefreshIndicator(
          onRefresh: admin.load,
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              GradientHeader(
                greeting: greetingFor(DateTime.now()),
                name: user?.name ?? 'Atasan',
                initials: initials(user?.name ?? '?'),
                meta: [
                  if ((user?.tenantName ?? '').isNotEmpty) user!.tenantName,
                  'Atasan',
                ].join(' • '),
                onBellTap: () => _openNotifications(context),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SummaryCard(
                      date: date,
                      total: employees.length,
                      present: present,
                      late: late,
                      onLeave: onLeave,
                      absent: absent,
                    ),
                    const SizedBox(height: 22),
                    SectionHeader(
                      title: 'Perlu persetujuan',
                      actionLabel: 'Lihat semua',
                      onAction: () => onOpenTab(2),
                    ),
                    const SizedBox(height: 10),
                    _PendingCard(
                      approvals: approvals,
                      onOpenApprovals: () => onOpenTab(2),
                    ),
                    const SizedBox(height: 22),
                    SectionHeader(
                      title: 'Jadwal tim hari ini',
                      actionLabel: 'Lihat tim',
                      onAction: () => onOpenTab(1),
                    ),
                    const SizedBox(height: 10),
                    _TeamScheduleCard(
                      employees: employees
                          .map(
                            (employee) =>
                                admin.shiftForEmployee(employee.id!, date),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                    _FooterBanner(
                      employees: employees,
                      records: records,
                      leaves: leaves,
                      shiftFor: (employee) =>
                          admin.shiftForEmployee(employee.id!, date),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openNotifications(BuildContext context) {
    final hr = context.read<HrProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<HrProvider>.value(
          value: hr,
          child: const NotificationsScreen(),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.date,
    required this.total,
    required this.present,
    required this.late,
    required this.onLeave,
    required this.absent,
  });

  final DateTime date;
  final int total;
  final int present;
  final int late;
  final int onLeave;
  final int absent;

  @override
  Widget build(BuildContext context) {
    final segments = <(int, Color)>[
      if (present > 0) (present, AppPalette.green),
      if (late > 0) (late, AppPalette.amber),
      if (onLeave > 0) (onLeave, AppPalette.primaryLight),
      if (absent > 0) (absent, const Color(0xFFCBD5E1)),
    ];

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatFullDate(date),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppPalette.muted,
                  ),
                ),
              ),
              LiveClock(
                builder: (time) => Text(
                  '${formatClock(time)} WIB',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$total',
                          style: const TextStyle(
                            fontSize: 34,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                            color: AppPalette.ink,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'anggota tim',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppPalette.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${present + late} sudah masuk · termasuk $late terlambat',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppPalette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppPalette.blueSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.groups_2_rounded,
                  size: 22,
                  color: AppPalette.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 8,
              child: segments.isEmpty
                  ? const ColoredBox(color: AppPalette.slate)
                  : Row(
                      children: [
                        for (final segment in segments)
                          Expanded(
                            flex: segment.$1,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 1.5,
                              ),
                              child: ColoredBox(color: segment.$2),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  value: present,
                  label: 'Hadir tepat waktu',
                  foreground: AppPalette.green,
                  background: AppPalette.greenSoft,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  value: late,
                  label: 'Terlambat',
                  foreground: AppPalette.amber,
                  background: AppPalette.amberSoft,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  value: onLeave,
                  label: 'Cuti',
                  foreground: AppPalette.primary,
                  background: AppPalette.blueSoft,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  value: absent,
                  label: 'Belum absen',
                  foreground: AppPalette.muted,
                  background: AppPalette.slate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final int value;
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.fromLTRB(10, 9, 8, 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              height: 1,
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9.5,
              height: 1.25,
              fontWeight: FontWeight.w500,
              color: AppPalette.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.approvals, required this.onOpenApprovals});

  final ApprovalProvider approvals;
  final VoidCallback onOpenApprovals;

  @override
  Widget build(BuildContext context) {
    if (approvals.pendingCount == 0) {
      return const InfoBanner(
        icon: Icons.task_alt_rounded,
        title: 'Tidak ada pengajuan menunggu',
        message: 'Semua pengajuan tim sudah ditinjau.',
        tone: StatusTone.success,
      );
    }

    final leaves = approvals.pendingLeaves;
    final corrections = approvals.pendingCorrections;
    final rows = <Widget>[];

    if (leaves.isNotEmpty) {
      final leave = leaves.first;
      rows.add(
        _PendingRow(
          name: leave.employeeName,
          subtitle:
              '${leave.type} · '
              '${formatDateRange(leave.startDate, leave.endDate)}',
          trailing: formatWorkingDays(leave.workingDays),
          onTap: () => _openLeave(context, leave),
        ),
      );
    }
    if (corrections.isNotEmpty) {
      final correction = corrections.first;
      rows.add(
        _PendingRow(
          name: correction.employeeName,
          subtitle:
              'Perbaikan absensi · ${correction.date.day} '
              '${monthShort(correction.date.month)}',
          trailing: _correctionShortLabel(correction.correctionType),
          onTap: () => _openCorrection(context, correction),
        ),
      );
    }

    final remaining = approvals.pendingCount - rows.length;

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${approvals.pendingCount} pengajuan menunggu',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.ink,
                  ),
                ),
              ),
              StatusPill(
                label:
                    '${approvals.pendingLeaveCount} cuti · '
                    '${approvals.pendingCorrectionCount} perbaikan',
                tone: StatusTone.warning,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            rows[i],
          ],
          if (remaining > 0) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '+$remaining pengajuan lainnya',
                style: const TextStyle(fontSize: 11, color: AppPalette.muted),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onOpenApprovals,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Tinjau pengajuan'),
            ),
          ),
        ],
      ),
    );
  }

  void _openLeave(BuildContext context, LeaveRequest leave) {
    final admin = context.read<AdminProvider>();
    final approvals = context.read<ApprovalProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider<AdminProvider>.value(value: admin),
            ChangeNotifierProvider<ApprovalProvider>.value(value: approvals),
          ],
          child: LeaveDetailScreen(leaveId: leave.id),
        ),
      ),
    );
  }

  void _openCorrection(BuildContext context, AttendanceCorrection correction) {
    final admin = context.read<AdminProvider>();
    final approvals = context.read<ApprovalProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider<AdminProvider>.value(value: admin),
            ChangeNotifierProvider<ApprovalProvider>.value(value: approvals),
          ],
          child: CorrectionDetailScreen(correctionId: correction.id),
        ),
      ),
    );
  }

  String _correctionShortLabel(CorrectionType type) => switch (type) {
    CorrectionType.checkIn => 'Jam masuk',
    CorrectionType.checkOut => 'Jam pulang',
    CorrectionType.both => 'Masuk & pulang',
  };
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({
    required this.name,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final String trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            InitialsAvatar(name: name, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppPalette.muted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              trailing,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppPalette.primary,
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppPalette.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamScheduleCard extends StatelessWidget {
  const _TeamScheduleCard({required this.employees});

  final List<WorkShift?> employees;

  @override
  Widget build(BuildContext context) {
    final groups = <String, (WorkShift, int)>{};
    for (final shift in employees) {
      if (shift == null) continue;
      final current = groups[shift.name];
      groups[shift.name] = (shift, (current?.$2 ?? 0) + 1);
    }

    if (groups.isEmpty) {
      return const SurfaceCard(
        child: Text(
          'Tidak ada shift terjadwal hari ini.',
          style: TextStyle(fontSize: 12, color: AppPalette.muted),
        ),
      );
    }

    final entries = groups.values.toList();

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Color(entries[i].$1.resolvedColorValue)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.event_note_rounded,
                      size: 17,
                      color: Color(entries[i].$1.resolvedColorValue),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entries[i].$1.name,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(entries[i].$1.resolvedColorValue),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${entries[i].$1.rangeLabel} · '
                          '${entries[i].$1.office}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppPalette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${entries[i].$2} orang',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(entries[i].$1.resolvedColorValue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FooterBanner extends StatelessWidget {
  const _FooterBanner({
    required this.employees,
    required this.records,
    required this.leaves,
    required this.shiftFor,
  });

  final List<User> employees;
  final Map<int, Attendance> records;
  final Map<int, LeaveRequest> leaves;
  final WorkShift? Function(User employee) shiftFor;

  @override
  Widget build(BuildContext context) {
    User? missing;
    for (final employee in employees) {
      final record = records[employee.id];
      if (record != null && record.hasCheckedIn) continue;
      if (leaves.containsKey(employee.id)) continue;
      missing = employee;
      break;
    }

    if (missing == null) {
      return const InfoBanner(
        icon: Icons.verified_rounded,
        title: 'Semua anggota tim sudah tercatat',
        message: 'Kehadiran tim hari ini lengkap.',
        tone: StatusTone.success,
      );
    }

    final name = firstNameOf(missing.name);
    final shift = shiftFor(missing);
    final message = shift == null
        ? '$name belum absen dan tidak ada shift terjadwal hari ini.'
        : '$name belum absen. ${shift.name} dimulai pukul '
              '${formatClockValue(shift.start)}, belum terlambat.';

    return InfoBanner(
      icon: Icons.info_outline_rounded,
      title: '$name belum absen',
      message: message,
    );
  }
}
