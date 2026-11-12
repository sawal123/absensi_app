import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../core/formatters.dart';
import '../../core/geo.dart';
import '../../data/models/work_shift.dart';
import '../../providers/attendance_provider.dart';
import '../../services/location_service.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/live_clock.dart';
import '../../widgets/map_preview.dart';
import '../../widgets/page_header.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/surface_card.dart';
import '../shared/camera_capture_screen.dart';

class ConfirmAttendanceScreen extends StatefulWidget {
  const ConfirmAttendanceScreen({super.key});

  @override
  State<ConfirmAttendanceScreen> createState() =>
      _ConfirmAttendanceScreenState();
}

class _ConfirmAttendanceScreenState extends State<ConfirmAttendanceScreen> {
  bool _locating = true;
  double? _latitude;
  double? _longitude;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveLocation());
  }

  Future<void> _resolveLocation() async {
    try {
      final position = await context
          .read<LocationService>()
          .getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locating = false;
      });
    } on LocationException catch (error) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _locationError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _locationError = 'Lokasi belum bisa diverifikasi saat ini.';
      });
    }
  }

  Future<void> _confirm() async {
    final attendance = context.read<AttendanceProvider>();
    final photo = await Navigator.of(context).push<CaptureResult>(
      MaterialPageRoute(
        builder: (_) =>
            const CameraCaptureScreen(mode: AttendanceCaptureMode.checkIn),
      ),
    );
    if (!mounted || photo == null) return;

    final ok = await attendance.clockIn(
      photoPath: photo.path,
      livenessPassed: photo.livenessPassed,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    final message = attendance.error ?? 'Absen masuk gagal.';
    attendance.clearError();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<AttendanceProvider>();
    final settings = attendance.settings;
    final shift = attendance.todayShift;
    final windowError = attendance.checkInWindowError;

    final hasPosition = _latitude != null && _longitude != null;
    final distance = hasPosition
        ? distanceInMeters(
            _latitude!,
            _longitude!,
            settings.latitude,
            settings.longitude,
          )
        : null;
    final inRange = distance == null ? null : distance <= settings.radiusMeters;

    return Scaffold(
      backgroundColor: AppPalette.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PageHeader(
              center: true,
              leading: const SquareBackButton(),
              title: 'Absen Masuk',
              subtitle: 'Pastikan lokasi dan waktumu sesuai',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  MapPreview(
                    officeName: settings.officeName,
                    radiusMeters: settings.radiusMeters,
                  ),
                  const SizedBox(height: 16),
                  _LocationSummary(
                    officeName: settings.officeName,
                    latitude: _latitude,
                    longitude: _longitude,
                    inRange: inRange,
                    locating: _locating,
                    failed: _locationError != null,
                  ),
                  const SizedBox(height: 12),
                  if (_locating)
                    const InfoBanner(
                      icon: Icons.my_location_rounded,
                      title: 'Memeriksa lokasi...',
                      message:
                          'Izinkan akses lokasi agar jarak ke kantor '
                          'bisa diverifikasi.',
                    )
                  else if (_locationError != null)
                    InfoBanner(
                      icon: Icons.location_off_outlined,
                      title: 'Lokasi belum tersedia',
                      message: _locationError,
                      tone: StatusTone.warning,
                    )
                  else
                    InfoBanner(
                      icon: inRange == true
                          ? Icons.check_circle_outline_rounded
                          : Icons.error_outline_rounded,
                      title:
                          'Kamu berjarak '
                          '${formatDistance(distance ?? 0)} dari kantor · '
                          'Maks. ${settings.radiusMeters} m',
                      message: inRange == true
                          ? 'Lokasi kamu berada di dalam area absensi.'
                          : 'Mendekatlah ke kantor untuk bisa absen masuk.',
                      tone: inRange == true
                          ? StatusTone.success
                          : StatusTone.danger,
                    ),
                  if (windowError != null) ...[
                    const SizedBox(height: 12),
                    InfoBanner(
                      icon: Icons.lock_clock_outlined,
                      title: 'Belum waktunya absen masuk',
                      message: windowError,
                      tone: StatusTone.warning,
                    ),
                  ],
                  const SizedBox(height: 14),
                  _TimeCard(
                    shift: shift,
                    workStart: settings.workStart,
                    workEnd: settings.workEnd,
                    lateTolerance: settings.lateToleranceMinutes,
                  ),
                ],
              ),
            ),
          ],
        ),
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
                onPressed:
                    attendance.busy || inRange == false || windowError != null
                    ? null
                    : _confirm,
                icon: attendance.busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 20),
                label: Text(
                  attendance.busy ? 'Memproses...' : 'Konfirmasi Absen Masuk',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Foto selfie, waktu, dan lokasi saat konfirmasi akan '
                'disimpan sebagai bukti kehadiran.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: AppPalette.faint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationSummary extends StatelessWidget {
  const _LocationSummary({
    required this.officeName,
    required this.latitude,
    required this.longitude,
    required this.inRange,
    required this.locating,
    required this.failed,
  });

  final String officeName;
  final double? latitude;
  final double? longitude;
  final bool? inRange;
  final bool locating;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final StatusPill pill;
    if (locating) {
      pill = const StatusPill(
        label: 'Memeriksa lokasi',
        tone: StatusTone.neutral,
      );
    } else if (failed) {
      pill = const StatusPill(
        label: 'Lokasi tidak tersedia',
        tone: StatusTone.warning,
      );
    } else {
      pill = switch (inRange) {
        true => const StatusPill(
          label: 'Lokasi sesuai',
          tone: StatusTone.success,
        ),
        false => const StatusPill(
          label: 'Di luar radius',
          tone: StatusTone.danger,
        ),
        null => const StatusPill(
          label: 'Memeriksa lokasi',
          tone: StatusTone.neutral,
        ),
      };
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                officeName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.ink,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            pill,
          ],
        ),
        const SizedBox(height: 5),
        Text(
          latitude == null || longitude == null
              ? 'Titik absensi kantor'
              : 'Titik absensi · ${latitude!.toStringAsFixed(5)}, '
                    '${longitude!.toStringAsFixed(5)}',
          style: const TextStyle(fontSize: 11.5, color: AppPalette.muted),
        ),
      ],
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.shift,
    required this.workStart,
    required this.workEnd,
    required this.lateTolerance,
  });

  final WorkShift? shift;
  final String workStart;
  final String workEnd;
  final int lateTolerance;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final late = isLate(now, shift?.start ?? workStart, lateTolerance);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatFullDate(now),
                  style: const TextStyle(fontSize: 12, color: AppPalette.muted),
                ),
              ),
              StatusPill(
                label: late ? 'Terlambat' : 'Tepat waktu',
                tone: late ? StatusTone.warning : StatusTone.success,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              LiveClock(
                builder: (time) => Text(
                  formatClock(time),
                  style: const TextStyle(
                    fontSize: 44,
                    height: 1,
                    letterSpacing: -1.4,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.ink,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 5),
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
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Jadwal kerja hari ini',
                style: TextStyle(fontSize: 12, color: AppPalette.muted),
              ),
              const Spacer(),
              Text(
                shift == null
                    ? 'Libur'
                    : '${formatClockValue(shift!.start)} – '
                          '${formatClockValue(shift!.end)} WIB',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.ink,
                ),
              ),
            ],
          ),
          if (shift != null && shift!.name.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              shift!.crossDay
                  ? '${shift!.name} · berakhir esok hari'
                  : shift!.name,
              style: const TextStyle(fontSize: 11, color: AppPalette.muted),
            ),
          ],
        ],
      ),
    );
  }
}
