import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../core/formatters.dart';
import '../../data/models/attendance.dart';
import '../../data/models/user.dart';
import '../../data/models/work_shift.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employee_payroll_provider.dart';
import '../../providers/hr_provider.dart';
import '../../providers/my_requests_provider.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/live_clock.dart';
import '../../widgets/quick_actions.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/surface_card.dart';
import '../shared/camera_capture_screen.dart';
import '../shared/notifications_screen.dart';
import '../shared/overtime_screen.dart';
import 'confirm_attendance_screen.dart';
import 'correction_request_screen.dart';
import 'leave_request_form_screen.dart';
import 'payroll_screen.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.onOpenTab});

  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    return Consumer2<AttendanceProvider, AuthProvider>(
      builder: (context, attendance, auth, _) {
        final user = auth.currentUser;
        final now = DateTime.now();
        final today = attendance.today;
        final settings = attendance.settings;
        final shift = attendance.todayShift;
        final state = _HomeState.of(today, shift?.start ?? settings.workStart);

        return RefreshIndicator(
          onRefresh: attendance.load,
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              GradientHeader(
                greeting: greetingFor(now),
                name: user?.name ?? 'Karyawan',
                initials: initials(user?.name ?? '?'),
                meta: _metaFor(user),
                onBellTap: () => _openNotifications(context),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TodayCard(
                      attendance: attendance,
                      state: state,
                      onAction: () => _handleAction(context, attendance),
                    ),
                    const SizedBox(height: 14),
                    _TodayShiftCard(shift: shift, date: now),
                    const SizedBox(height: 22),
                    const SectionHeader(title: 'Keperluanmu'),
                    const SizedBox(height: 12),
                    QuickActions(
                      items: [
                        QuickActionItem(
                          icon: Icons.history_rounded,
                          label: 'Riwayat',
                          onTap: () => onOpenTab(1),
                        ),
                        QuickActionItem(
                          icon: Icons.calendar_month_rounded,
                          label: 'Jadwal',
                          onTap: () => onOpenTab(2),
                        ),
                        QuickActionItem(
                          icon: Icons.event_available_rounded,
                          label: 'Cuti',
                          onTap: () => _openLeaveForm(context),
                        ),
                        QuickActionItem(
                          icon: Icons.edit_document,
                          label: 'Perbaikan',
                          onTap: () => _openCorrectionForm(context),
                        ),
                        QuickActionItem(
                          icon: Icons.more_time_rounded,
                          label: 'Lembur',
                          onTap: () => _openOvertime(context),
                        ),
                        QuickActionItem(
                          icon: Icons.receipt_long_rounded,
                          label: 'Slip gaji',
                          onTap: () => _openPayroll(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _StateBanner(
                      state: state,
                      today: today,
                      workStart: shift?.start ?? settings.workStart,
                      workEnd: shift?.end ?? settings.workEnd,
                      lateTolerance: settings.lateToleranceMinutes,
                      name: user?.name ?? '',
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

  String _metaFor(User? user) {
    if (user == null) return '';
    final nip = user.nip.isEmpty ? '' : 'NIP ${user.nip}';
    return [user.position, nip].where((part) => part.isNotEmpty).join(' • ');
  }

  Future<void> _handleAction(
    BuildContext context,
    AttendanceProvider attendance,
  ) async {
    if (attendance.busy) return;

    final hasCheckedIn = attendance.today?.hasCheckedIn ?? false;
    final hasCheckedOut = attendance.today?.hasCheckedOut ?? false;
    if (hasCheckedOut) return;

    if (!hasCheckedIn) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider<AttendanceProvider>.value(
            value: attendance,
            child: const ConfirmAttendanceScreen(),
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Absen pulang?'),
        content: const Text(
          'Kamera akan terbuka untuk foto selfie, lalu lokasi diperiksa '
          'sebelum absen pulang dicatat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Absen Pulang'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final photo = await Navigator.of(context).push<CaptureResult>(
      MaterialPageRoute(
        builder: (_) =>
            const CameraCaptureScreen(mode: AttendanceCaptureMode.checkOut),
      ),
    );
    if (photo == null || !context.mounted) return;

    final ok = await attendance.clockOut(
      photoPath: photo.path,
      livenessPassed: photo.livenessPassed,
    );
    if (!context.mounted) return;
    _snack(
      context,
      ok
          ? 'Absen pulang berhasil dicatat.'
          : (attendance.error ?? 'Absen pulang gagal.'),
    );
    if (!ok) attendance.clearError();
  }

  void _openLeaveForm(BuildContext context) {
    final requests = context.read<MyRequestsProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<MyRequestsProvider>.value(
          value: requests,
          child: const LeaveRequestFormScreen(),
        ),
      ),
    );
  }

  void _openCorrectionForm(BuildContext context) {
    final requests = context.read<MyRequestsProvider>();
    final attendance = context.read<AttendanceProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider<MyRequestsProvider>.value(value: requests),
            ChangeNotifierProvider<AttendanceProvider>.value(value: attendance),
          ],
          child: const CorrectionRequestScreen(),
        ),
      ),
    );
  }

  void _openPayroll(BuildContext context) {
    final payroll = context.read<EmployeePayrollProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<EmployeePayrollProvider>.value(
          value: payroll,
          child: const EmployeePayrollScreen(),
        ),
      ),
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

  void _openOvertime(BuildContext context) {
    final hr = context.read<HrProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<HrProvider>.value(
          value: hr,
          child: const OvertimeScreen(),
        ),
      ),
    );
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _HomeState {
  notCheckedIn,
  working,
  done;

  static _HomeState of(Attendance? record, String workStart) {
    if (record == null || !record.hasCheckedIn) return notCheckedIn;
    if (record.hasCheckedOut) return done;
    return working;
  }

  StatusPill get pill => switch (this) {
    notCheckedIn => const StatusPill(
      label: 'Belum masuk',
      tone: StatusTone.info,
    ),
    working => const StatusPill(
      label: 'Sedang bekerja',
      tone: StatusTone.success,
    ),
    done => const StatusPill(label: 'Selesai', tone: StatusTone.neutral),
  };
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.attendance,
    required this.state,
    required this.onAction,
  });

  final AttendanceProvider attendance;
  final _HomeState state;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final today = attendance.today;
    final settings = attendance.settings;
    final now = DateTime.now();

    final buttonLabel = switch (state) {
      _HomeState.notCheckedIn => 'Absen Masuk',
      _HomeState.working => 'Absen Pulang',
      _HomeState.done => 'Absensi selesai',
    };
    final buttonIcon = switch (state) {
      _HomeState.notCheckedIn => Icons.login_rounded,
      _HomeState.working => Icons.logout_rounded,
      _HomeState.done => Icons.check_circle_outline_rounded,
    };
    final shiftEnd = attendance.todayShift?.end ?? settings.workEnd;
    final caption = switch (state) {
      _HomeState.notCheckedIn => 'Mulai harimu dengan mencatat kehadiran.',
      _HomeState.working =>
        'Jadwal pulangmu hari ini pukul ${formatClockValue(shiftEnd)} WIB.',
      _HomeState.done => 'Absensi hari ini sudah lengkap.',
    };

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatFullDate(now),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppPalette.muted,
                  ),
                ),
              ),
              state.pill,
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              LiveClock(
                builder: (time) => Text(
                  formatClock(time),
                  style: const TextStyle(
                    fontSize: 46,
                    height: 1,
                    letterSpacing: -1.5,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.ink,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 6),
                child: Text(
                  'WIB',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _TimeBox(
                  label: 'Masuk',
                  icon: Icons.login_rounded,
                  time: formatClock(today?.checkInAt),
                  filled: today?.hasCheckedIn ?? false,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeBox(
                  label: 'Pulang',
                  icon: Icons.logout_rounded,
                  time: formatClock(today?.checkOutAt),
                  filled: today?.hasCheckedOut ?? false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                size: 15,
                color: AppPalette.green,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  settings.officeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppPalette.muted),
                ),
              ),
              Text(
                'Radius · ${settings.radiusMeters} m',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: attendance.busy || state == _HomeState.done
                ? null
                : onAction,
            icon: attendance.busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Icon(buttonIcon, size: 19),
            label: Text(attendance.busy ? 'Memproses...' : buttonLabel),
          ),
          const SizedBox(height: 10),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5, color: AppPalette.faint),
          ),
        ],
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({
    required this.label,
    required this.icon,
    required this.time,
    required this.filled,
  });

  final String label;
  final IconData icon;
  final String time;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppPalette.muted),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(fontSize: 11.5, color: AppPalette.muted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            time,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: filled ? AppPalette.ink : AppPalette.faint,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayShiftCard extends StatelessWidget {
  const _TodayShiftCard({required this.shift, required this.date});

  final WorkShift? shift;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final color = shift == null
        ? AppPalette.primary
        : Color(shift!.resolvedColorValue);
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  formatDayShort(date).toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: color,
                  ),
                ),
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shift == null
                      ? 'Jadwal hari ini · Libur'
                      : 'Jadwal hari ini · ${shift!.name}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppPalette.muted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  shift?.rangeLabel ?? 'Tidak ada jadwal',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.ink,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          if (shift != null)
            Text(
              'WIB',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}

class _StateBanner extends StatelessWidget {
  const _StateBanner({
    required this.state,
    required this.today,
    required this.workStart,
    required this.workEnd,
    required this.lateTolerance,
    required this.name,
  });

  final _HomeState state;
  final Attendance? today;
  final String workStart;
  final String workEnd;
  final int lateTolerance;
  final String name;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _HomeState.notCheckedIn:
        return InfoBanner(
          icon: Icons.verified_user_outlined,
          title: 'Siap memulai hari?',
          message:
              'Pastikan lokasi dan waktumu sesuai. Absen masuk sebelum '
              'pukul ${formatClockValue(workStart)} WIB.',
        );
      case _HomeState.working:
        final late = isLate(today!.checkInAt!, workStart, lateTolerance);
        return InfoBanner(
          icon: Icons.check_circle_outline_rounded,
          title: 'Absen masuk berhasil!',
          tone: StatusTone.success,
          message:
              'Tercatat pukul ${formatClock(today!.checkInAt)} WIB · '
              '${late ? 'Terlambat' : 'Tepat waktu'}. Selamat bekerja, '
              '${firstNameOf(name)}.',
        );
      case _HomeState.done:
        return InfoBanner(
          icon: Icons.workspace_premium_outlined,
          title: 'Absensi hari ini lengkap',
          tone: StatusTone.success,
          message:
              'Masuk ${formatClock(today!.checkInAt)} · '
              'Pulang ${formatClock(today!.checkOutAt)} WIB. '
              'Selamat beristirahat.',
        );
    }
  }
}
