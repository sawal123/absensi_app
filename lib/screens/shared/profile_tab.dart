import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../data/api/api_config.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/hr_provider.dart';
import '../../providers/payroll_provider.dart';
import '../../services/report_service.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/page_header.dart';
import '../../widgets/surface_card.dart';
import '../admin/audit_logs_screen.dart';
import '../admin/employees_screen.dart';
import '../admin/holidays_screen.dart';
import '../admin/office_locations_screen.dart';
import '../admin/payroll_screen.dart';
import '../admin/settings_screen.dart';
import '../shared/camera_capture_screen.dart';
import '../shared/notifications_screen.dart';
import '../shared/overtime_screen.dart';
import '../supervisor/shifts_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const PageHeader(
            title: 'Profil',
            subtitle: 'Kelola akun dan preferensimu.',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SurfaceCard(
                  child: Row(
                    children: [
                      InitialsAvatar(name: user?.name ?? '?', size: 60),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? 'Karyawan',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppPalette.ink,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              user?.email ?? '-',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppPalette.muted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                AppBadge(
                                  label: (user?.isManager ?? false)
                                      ? 'Atasan'
                                      : 'Karyawan',
                                ),
                                if (user?.faceEnrolled ?? false) ...[
                                  const SizedBox(width: 6),
                                  const AppBadge(label: 'Wajah aktif'),
                                ],
                                if ((user?.nip ?? '').isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    'NIP ${user!.nip}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppPalette.muted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (user?.isManager ?? false) ...[
                  const SizedBox(height: 16),
                  SurfaceCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _MenuItem(
                          icon: Icons.fact_check_outlined,
                          label: 'Persetujuan lembur',
                          onTap: () =>
                              _openHrPage(context, const OvertimeScreen()),
                        ),
                        const Divider(height: 1, indent: 58),
                        _MenuItem(
                          icon: Icons.more_time_outlined,
                          label: 'Kelola shift',
                          onTap: () =>
                              _openAdminPage(context, const ShiftsScreen()),
                        ),
                        const Divider(height: 1, indent: 58),
                        _MenuItem(
                          icon: Icons.payments_outlined,
                          label: 'Gaji karyawan',
                          onTap: () => _openPayrollPage(context),
                        ),
                        const Divider(height: 1, indent: 58),
                        _MenuItem(
                          icon: Icons.download_outlined,
                          label: 'Export laporan',
                          onTap: () => _exportReport(context),
                        ),
                        if (user?.isAdmin ?? false) ...[
                          const Divider(height: 1, indent: 58),
                          _MenuItem(
                            icon: Icons.groups_2_outlined,
                            label: 'Kelola karyawan',
                            onTap: () => _openAdminPage(
                              context,
                              const EmployeesScreen(),
                            ),
                          ),
                          const Divider(height: 1, indent: 58),
                          _MenuItem(
                            icon: Icons.tune_rounded,
                            label: 'Pengaturan kantor',
                            onTap: () => _openAdminPage(
                              context,
                              const SettingsScreen(),
                            ),
                          ),
                          const Divider(height: 1, indent: 58),
                          _MenuItem(
                            icon: Icons.apartment_outlined,
                            label: 'Cabang & lokasi',
                            onTap: () => _openAdminPage(
                              context,
                              const OfficeLocationsScreen(),
                            ),
                          ),
                          const Divider(height: 1, indent: 58),
                          _MenuItem(
                            icon: Icons.event_busy_outlined,
                            label: 'Hari libur',
                            onTap: () =>
                                _openHrPage(context, const HolidaysScreen()),
                          ),
                          const Divider(height: 1, indent: 58),
                          _MenuItem(
                            icon: Icons.history_rounded,
                            label: 'Audit log',
                            onTap: () =>
                                _openHrPage(context, const AuditLogsScreen()),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _MenuItem(
                        icon: Icons.notifications_none_rounded,
                        label: 'Notifikasi',
                        onTap: () =>
                            _openHrPage(context, const NotificationsScreen()),
                      ),
                      const Divider(height: 1, indent: 58),
                      _MenuItem(
                        icon: Icons.face_retouching_natural,
                        label: (user?.faceEnrolled ?? false)
                            ? 'Wajah terdaftar · daftar ulang'
                            : 'Daftarkan wajah',
                        onTap: () => _enrollFace(context),
                      ),
                      const Divider(height: 1, indent: 58),
                      _MenuItem(
                        icon: Icons.info_outline_rounded,
                        label: 'Tentang aplikasi',
                        onTap: () => _showAbout(context),
                      ),
                      const Divider(height: 1, indent: 58),
                      _MenuItem(
                        icon: Icons.logout_rounded,
                        label: 'Keluar',
                        danger: true,
                        onTap: () => _confirmLogout(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Center(
                  child: Text(
                    'Absensi v1.0.0',
                    style: TextStyle(fontSize: 10.5, color: AppPalette.faint),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openAdminPage(BuildContext context, Widget page) {
    final admin = context.read<AdminProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<AdminProvider>.value(
          value: admin,
          child: page,
        ),
      ),
    );
  }

  void _openPayrollPage(BuildContext context) {
    final payroll = context.read<PayrollProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<PayrollProvider>.value(
          value: payroll,
          child: const PayrollScreen(),
        ),
      ),
    );
  }

  void _openHrPage(BuildContext context, Widget page) {
    final hr = context.read<HrProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<HrProvider>.value(
          value: hr,
          child: page,
        ),
      ),
    );
  }

  Future<void> _enrollFace(BuildContext context) async {
    final capture = await Navigator.of(context).push<CaptureResult>(
      MaterialPageRoute(
        builder: (_) => const CameraCaptureScreen(
          mode: AttendanceCaptureMode.faceEnrollment,
        ),
      ),
    );
    if (capture == null || !context.mounted) return;

    if (!capture.livenessPassed) {
      _snack(
        context,
        'Verifikasi liveness gagal. Ulangi pendaftaran wajah.',
      );
      return;
    }

    final hr = context.read<HrProvider>();
    final ok = await hr.enrollFace(capture.path);
    if (!context.mounted) return;

    if (ok) {
      await context.read<AuthProvider>().refreshUser();
      if (!context.mounted) return;
      _snack(context, 'Wajah berhasil didaftarkan.');
    } else {
      _snack(context, hr.error ?? 'Gagal mendaftarkan wajah.');
      hr.clearError();
    }
  }

  Future<void> _exportReport(BuildContext context) async {
    if (ApiConfig.useDummy) {
      _snack(context, 'Export laporan memerlukan backend Laravel aktif.');
      return;
    }

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Export laporan CSV',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.ink,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('Rekap absensi bulan ini'),
                subtitle: const Text('Tanggal 1 sampai hari ini'),
                onTap: () => Navigator.pop(context, 'attendance'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Slip gaji bulan lalu'),
                subtitle: const Text('Data finalisasi payroll'),
                onTap: () => Navigator.pop(context, 'payroll'),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice == null || !context.mounted) return;

    final service = context.read<ReportService>();
    final now = DateTime.now();
    final previous = DateTime(now.year, now.month - 1);

    try {
      _snack(context, 'Menyiapkan laporan...');
      final path = choice == 'attendance'
          ? await service.downloadAttendance(
              from: DateTime(now.year, now.month, 1),
              to: now,
            )
          : await service.downloadPayroll(
              year: previous.year,
              month: previous.month,
            );
      if (!context.mounted) return;
      _snack(context, 'Laporan disimpan: $path');
    } catch (error) {
      if (!context.mounted) return;
      _snack(context, 'Gagal export laporan: $error');
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Absensi',
      applicationVersion: '1.0.0',
      applicationLegalese:
          'Aplikasi absensi karyawan dengan verifikasi lokasi.',
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar akun?'),
        content: const Text('Anda perlu masuk kembali untuk melanjutkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().logout();
    }
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppPalette.red : AppPalette.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: danger ? AppPalette.redSoft : AppPalette.blueSoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                icon,
                size: 16,
                color: danger ? AppPalette.red : AppPalette.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
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
