import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../core/formatters.dart';
import '../../data/models/attendance_correction.dart';
import '../../data/models/correction_type.dart';
import '../../data/models/request_status.dart';
import '../../providers/my_requests_provider.dart';
import '../../widgets/detail_row.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/page_header.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/surface_card.dart';
import '../../widgets/time_change_row.dart';

class MyCorrectionDetailScreen extends StatefulWidget {
  const MyCorrectionDetailScreen({super.key, required this.correctionId});

  final int correctionId;

  @override
  State<MyCorrectionDetailScreen> createState() =>
      _MyCorrectionDetailScreenState();
}

class _MyCorrectionDetailScreenState extends State<MyCorrectionDetailScreen> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final requests = context.watch<MyRequestsProvider>();
    final correction = requests.correctionById(widget.correctionId);

    if (correction == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Perbaikan Absensi')),
        body: const Center(
          child: Text(
            'Pengajuan tidak ditemukan.',
            style: TextStyle(color: AppPalette.muted),
          ),
        ),
      );
    }

    final isPending = correction.status.isPending;
    final highlightIn =
        correction.correctionType == CorrectionType.checkIn ||
        correction.correctionType == CorrectionType.both;
    final highlightOut =
        correction.correctionType == CorrectionType.checkOut ||
        correction.correctionType == CorrectionType.both;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PageHeader(
              center: true,
              leading: const SquareBackButton(),
              title: 'Perbaikan Absensi',
              subtitle: 'Detail pengajuan · ${correction.code}',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  _HeaderCard(correction: correction),
                  const SizedBox(height: 12),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DetailRow(
                          label: 'Tanggal kejadian',
                          value: formatFullDate(correction.date),
                        ),
                        DetailRow(
                          label: 'Jadwal kerja',
                          value:
                              'Reguler · '
                              '${formatClockRange(correction.scheduledStart, correction.scheduledEnd)} WIB',
                        ),
                        DetailRow(
                          label: 'Jenis perbaikan',
                          value: correction.correctionType.label,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Perubahan yang diajukan',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.ink,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Row(
                          children: [
                            SizedBox(width: 66),
                            Expanded(
                              child: Text(
                                'Data tercatat',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: AppPalette.muted,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Diajukan',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppPalette.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(),
                        const SizedBox(height: 6),
                        TimeChangeRow(
                          label: 'Masuk',
                          recorded: correction.recordedCheckIn == null
                              ? '—'
                              : formatClock(correction.recordedCheckIn),
                          proposed: correction.proposedCheckIn == null
                              ? '—'
                              : formatClock(correction.proposedCheckIn),
                          highlight: highlightIn,
                        ),
                        const SizedBox(height: 6),
                        TimeChangeRow(
                          label: 'Pulang',
                          sub: correction.recordedCheckOut == null
                              ? 'Belum tercatat'
                              : null,
                          recorded: correction.recordedCheckOut == null
                              ? '—'
                              : formatClock(correction.recordedCheckOut),
                          proposed: correction.proposedCheckOut == null
                              ? '—'
                              : formatClock(correction.proposedCheckOut),
                          highlight: highlightOut,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Alasan perbaikan',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          correction.reason,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.55,
                            color: AppPalette.muted,
                          ),
                        ),
                        if (correction.evidenceName.isNotEmpty ||
                            (correction.evidenceUrl ?? '').isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Icon(
                                Icons.attach_file_rounded,
                                size: 15,
                                color: AppPalette.primary,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  correction.evidenceName.isNotEmpty
                                      ? correction.evidenceName
                                      : _fileName(correction.evidenceUrl!),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppPalette.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _StatusBanner(correction: correction),
                  if (isPending) ...[
                    const SizedBox(height: 14),
                    const InfoBanner(
                      icon: Icons.info_outline_rounded,
                      title: 'Masih dapat dibatalkan',
                      message:
                          'Batalkan pengajuan bila data yang dimasukkan keliru.',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isPending
          ? _CancelBar(
              busy: _submitting,
              onTap: () => _cancel(correction),
            )
          : null,
    );
  }

  Future<void> _cancel(AttendanceCorrection correction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan pengajuan?'),
        content: const Text(
          'Pengajuan perbaikan absensi ini akan berstatus dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tidak'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    final requests = context.read<MyRequestsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await requests.cancelCorrection(correction.id);
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Pengajuan perbaikan dibatalkan.')),
      );
      return;
    }

    setState(() => _submitting = false);
    final message = requests.error ?? 'Pengajuan gagal dibatalkan.';
    requests.clearError();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  String _fileName(String value) => value.split(RegExp(r'[/\\]')).last;
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.correction});

  final AttendanceCorrection correction;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              requestStatusPill(correction.status),
              const Spacer(),
              Text(
                formatStamp(correction.submittedAt),
                style: const TextStyle(fontSize: 10.5, color: AppPalette.faint),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              InitialsAvatar(name: correction.employeeName, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      correction.employeeName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'NIP ${correction.nip} · ${correction.team}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppPalette.faint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (correction.reviewer.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Peninjau: ${correction.reviewer}',
              style: const TextStyle(fontSize: 10.5, color: AppPalette.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.correction});

  final AttendanceCorrection correction;

  @override
  Widget build(BuildContext context) {
    final message = correction.decisionNote.trim().isEmpty
        ? null
        : correction.decisionNote;

    return switch (correction.status) {
      RequestStatus.pending => const InfoBanner(
        icon: Icons.hourglass_top_rounded,
        title: 'Menunggu persetujuan',
        message: 'Pengajuan sedang ditinjau atasan langsung.',
        tone: StatusTone.warning,
      ),
      RequestStatus.approved => InfoBanner(
        icon: Icons.check_circle_outline_rounded,
        title: 'Perbaikan disetujui',
        message: message,
        tone: StatusTone.success,
      ),
      RequestStatus.rejected => InfoBanner(
        icon: Icons.cancel_outlined,
        title: 'Perbaikan ditolak',
        message: message,
        tone: StatusTone.danger,
      ),
      RequestStatus.cancelled => InfoBanner(
        icon: Icons.remove_circle_outline_rounded,
        title: 'Pengajuan dibatalkan',
        message: message,
        tone: StatusTone.neutral,
      ),
    };
  }
}

class _CancelBar extends StatelessWidget {
  const _CancelBar({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppPalette.surface,
        border: Border(top: BorderSide(color: AppPalette.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: SafeArea(
        top: false,
        child: OutlinedButton.icon(
          onPressed: busy ? null : onTap,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : const Icon(Icons.cancel_outlined, size: 18),
          label: Text(busy ? 'Membatalkan...' : 'Batalkan pengajuan'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppPalette.red,
            backgroundColor: AppPalette.surface,
            side: BorderSide(color: AppPalette.red.withValues(alpha: 0.35)),
          ),
        ),
      ),
    );
  }
}
