import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../core/formatters.dart';
import '../../data/models/attendance.dart';
import '../../data/models/request_status.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/my_requests_provider.dart';
import '../../widgets/page_header.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/surface_card.dart';
import '../../widgets/empty_state.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<AttendanceProvider>();
    final requests = context.watch<MyRequestsProvider>();
    final user = context.watch<AuthProvider>().currentUser;
    final settings = attendance.settings;

    final records = attendance.history.where((record) {
      final date = DateTime.tryParse(record.date);
      return date != null &&
          date.year == _month.year &&
          date.month == _month.month;
    }).toList();

    final present = records
        .where(
          (r) => r.hasCheckedIn &&
              !isLate(
                r.checkInAt!,
                settings.workStart,
                settings.lateToleranceMinutes,
              ),
        )
        .length;
    final late = records
        .where(
          (r) => r.hasCheckedIn &&
              isLate(
                r.checkInAt!,
                settings.workStart,
                settings.lateToleranceMinutes,
              ),
        )
        .length;
    final leaveDays = _leaveDaysInMonth(requests, user?.id);

    final now = DateTime.now();
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;
    final summaryLabel = isCurrentMonth
        ? 'Ringkasan hingga ${now.day} ${monthName(now.month)}'
        : 'Ringkasan ${formatMonthYear(_month)}';

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: attendance.load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const PageHeader(
              title: 'Riwayat Absensi',
              subtitle: 'Setiap kehadiran, tercatat dengan rapi.',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MonthSelector(
                    month: _month,
                    onTap: () => _pickMonth(context),
                  ),
                  const SizedBox(height: 14),
                  _SummaryCard(
                    label: summaryLabel,
                    present: present,
                    late: late,
                    leave: leaveDays,
                  ),
                  const SizedBox(height: 22),
                  SectionHeader(
                    title: 'Catatan harian',
                    actionLabel: '${records.length} hari kerja',
                  ),
                  const SizedBox(height: 8),
                  const _Legend(),
                  const SizedBox(height: 10),
                  if (records.isEmpty)
                    const EmptyState(
                      icon: Icons.event_note_outlined,
                      title: 'Belum ada riwayat absensi',
                      subtitle: 'Riwayat bulan ini akan muncul di sini.',
                    )
                  else
                    for (final record in records)
                      _historyCard(attendance, record),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyCard(AttendanceProvider attendance, Attendance record) {
    final date = DateTime.tryParse(record.date) ?? DateTime.now();
    final shift = attendance.shiftFor(date);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _HistoryCard(
        record: record,
        workStart: shift?.start ?? attendance.settings.workStart,
        officeName: attendance.settings.officeName,
        shiftName: shift?.name ?? 'Libur',
        lateTolerance: attendance.settings.lateToleranceMinutes,
      ),
    );
  }

  int _leaveDaysInMonth(MyRequestsProvider requests, int? employeeId) {
    if (employeeId == null) return 0;
    var total = 0;
    for (final leave in requests.leaveRequests) {
      if (leave.employeeId != employeeId) continue;
      if (leave.status != RequestStatus.approved) continue;
      final inMonth =
          _monthOf(leave.startDate) == _monthOf(_month) ||
          _monthOf(leave.endDate) == _monthOf(_month);
      if (inMonth) total += leave.workingDays;
    }
    return total;
  }

  int _monthOf(DateTime date) => date.year * 12 + date.month;

  Future<void> _pickMonth(BuildContext context) async {
    final now = DateTime.now();
    final months = List.generate(
      12,
      (index) => DateTime(now.year, now.month - index),
    );
    final picked = await showModalBottomSheet<DateTime>(
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
                          month.year == _month.year &&
                          month.month == _month.month;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          formatMonthYear(month),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? AppPalette.primary
                                : AppPalette.ink,
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
    if (picked != null) {
      setState(() => _month = DateTime(picked.year, picked.month));
    }
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({required this.month, required this.onTap});

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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.present,
    required this.late,
    required this.leave,
  });

  final String label;
  final int present;
  final int late;
  final int leave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppPalette.headerGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Stat(value: present, label: 'Hari hadir'),
              ),
              Expanded(
                child: _Stat(value: late, label: 'Terlambat'),
              ),
              Expanded(
                child: _Stat(value: leave, label: 'Hari cuti'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 26,
                height: 1,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              'hari',
              style: TextStyle(
                fontSize: 10.5,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.login_rounded, size: 13, color: AppPalette.primary),
        SizedBox(width: 4),
        Text('Masuk', style: TextStyle(fontSize: 11, color: AppPalette.muted)),
        SizedBox(width: 12),
        Icon(Icons.logout_rounded, size: 13, color: AppPalette.amber),
        SizedBox(width: 4),
        Text(
          'Pulang · WIB',
          style: TextStyle(fontSize: 11, color: AppPalette.muted),
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.record,
    required this.workStart,
    required this.officeName,
    required this.shiftName,
    required this.lateTolerance,
  });

  final Attendance record;
  final String workStart;
  final String officeName;
  final String shiftName;
  final int lateTolerance;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(record.date) ?? DateTime.now();
    final isToday = isSameDay(date, DateTime.now());
    final late = record.hasCheckedIn &&
        isLate(record.checkInAt!, workStart, lateTolerance);
    final pill = _pillFor(record, late);
    final note = _noteFor(record, late);

    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      border: isToday ? AppPalette.primary.withValues(alpha: 0.45) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DateBadge(date: date),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isToday ? '$shiftName · Hari ini' : shiftName,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppPalette.muted,
                        ),
                      ),
                    ),
                    StatusPill(label: pill.$1, tone: pill.$2, dense: true),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(
                      Icons.login_rounded,
                      size: 14,
                      color: AppPalette.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formatClock(record.checkInAt),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.ink,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Icon(
                      Icons.logout_rounded,
                      size: 14,
                      color: AppPalette.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formatClock(record.checkOutAt),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(note.$1, style: TextStyle(fontSize: 10.5, color: note.$2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (String, StatusTone) _pillFor(Attendance record, bool late) {
    if (!record.hasCheckedIn) {
      return ('Belum absen', StatusTone.neutral);
    }
    if (!record.hasCheckedOut) {
      return (
        late ? 'Terlambat' : 'Bekerja',
        late ? StatusTone.warning : StatusTone.info,
      );
    }
    return (
      late ? 'Terlambat' : 'Tepat waktu',
      late ? StatusTone.warning : StatusTone.success,
    );
  }

  (String, Color) _noteFor(Attendance record, bool late) {
    if (!record.hasCheckedIn) {
      return ('Belum ada catatan absensi', AppPalette.faint);
    }
    if (!record.hasCheckedOut) {
      return ('Pulang belum tercatat', AppPalette.amber);
    }
    if (late) {
      final start = parseTimeOfDay(workStart);
      final minutes = record.checkInAt!.difference(start).inMinutes;
      return ('Terlambat $minutes menit', AppPalette.amber);
    }
    return ('Kehadiran lengkap', AppPalette.muted);
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: Column(
        children: [
          Text(
            formatDayShort(date).toUpperCase(),
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: AppPalette.muted,
            ),
          ),
          Text(
            '${date.day}',
            style: const TextStyle(
              fontSize: 20,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: AppPalette.ink,
            ),
          ),
          Text(
            monthShort(date.month).toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: AppPalette.faint,
            ),
          ),
        ],
      ),
    );
  }
}
