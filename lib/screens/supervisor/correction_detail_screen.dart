import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../core/formatters.dart';
import '../../data/models/attendance_correction.dart';
import '../../data/models/correction_type.dart';
import '../../data/models/request_status.dart';
import '../../providers/admin_provider.dart';
import '../../providers/approval_provider.dart';
import '../../widgets/decision_bar.dart';
import '../../widgets/detail_row.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/page_header.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/surface_card.dart';
import '../../widgets/time_change_row.dart';

class CorrectionDetailScreen extends StatefulWidget {
  const CorrectionDetailScreen({super.key, required this.correctionId});

  final int correctionId;

  @override
  State<CorrectionDetailScreen> createState() =>
      _CorrectionDetailScreenState();
}

class _CorrectionDetailScreenState extends State<CorrectionDetailScreen> {
  final _note = TextEditingController();
  bool _noteError = false;
  bool _submitting = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _approve(AttendanceCorrection correction) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final approvals = context.read<ApprovalProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await approvals.approveCorrection(
      correction.id,
      note: _note.text.trim(),
    );
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Perbaikan disetujui. Data absensi diperbarui.'),
        ),
      );
      return;
    }

    setState(() => _submitting = false);
    final message = approvals.error ?? 'Pengajuan gagal disetujui.';
    approvals.clearError();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reject(AttendanceCorrection correction) async {
    if (_note.text.trim().isEmpty) {
      setState(() => _noteError = true);
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    final approvals = context.read<ApprovalProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await approvals.rejectCorrection(
      correction.id,
      note: _note.text.trim(),
    );
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Perbaikan absensi ditolak.')),
      );
      return;
    }

    setState(() => _submitting = false);
    final message = approvals.error ?? 'Pengajuan gagal ditolak.';
    approvals.clearError();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final approvals = context.watch<ApprovalProvider>();
    final settings = context.watch<AdminProvider>().settings;
    final correction = approvals.correctionById(widget.correctionId);

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

    final isPending = correction.status == RequestStatus.pending;
    final highlightIn =
        correction.correctionType == CorrectionType.checkIn ||
        correction.correctionType == CorrectionType.both;
    final highlightOut =
        correction.correctionType == CorrectionType.checkOut ||
        correction.correctionType == CorrectionType.both;
    final hasEvidence =
        correction.evidenceName.isNotEmpty ||
        (correction.evidenceUrl ?? '').isNotEmpty;

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
                          label: 'Lokasi masuk',
                          value: 'Valid · ${settings.officeName}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Perubahan yang diajukan',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppPalette.ink,
                                ),
                              ),
                            ),
                            StatusPill(
                              label: correction.correctionType.label,
                              tone: StatusTone.info,
                              dense: true,
                            ),
                          ],
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
                          recorded: formatClock(correction.recordedCheckIn),
                          proposed: formatClock(correction.proposedCheckIn),
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
                          proposed: formatClock(correction.proposedCheckOut),
                          proposedSub: correction.proposedCheckOut == null
                              ? null
                              : '${correction.proposedCheckOut!.day} '
                                    '${monthShort(correction.proposedCheckOut!.month)} · WIB',
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
                        const SizedBox(height: 14),
                        Text(
                          hasEvidence
                              ? 'Bukti pendukung'
                              : 'Bukti pendukung · tidak ada',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppPalette.ink.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (hasEvidence)
                          _EvidenceTile(
                            correction: correction,
                            onTap: () => _showEvidence(correction),
                          )
                        else
                          const Text(
                            'Karyawan tidak melampirkan berkas.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppPalette.faint,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const InfoBanner(
                    icon: Icons.verified_user_outlined,
                    title: 'Periksa bukti sebelum menyetujui',
                    message:
                        'Data absensi diperbarui hanya setelah '
                        'pengajuan disetujui.',
                  ),
                  const SizedBox(height: 18),
                  if (isPending) ...[
                    Row(
                      children: [
                        const Text(
                          'Catatan peninjau',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.ink,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Wajib jika ditolak',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppPalette.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _note,
                      maxLines: 3,
                      onChanged: (_) {
                        if (_noteError) setState(() => _noteError = false);
                      },
                      decoration: InputDecoration(
                        hintText:
                            'Tulis pertimbangan atau alasan penolakan '
                            'agar karyawan dapat menindaklanjuti.',
                        hintMaxLines: 3,
                        errorText: _noteError
                            ? 'Catatan wajib diisi saat menolak pengajuan.'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Catatan akan terlihat oleh karyawan.',
                      style: TextStyle(fontSize: 10.5, color: AppPalette.faint),
                    ),
                  ] else
                    _DecisionBanner(correction: correction),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isPending
          ? DecisionBar(
              busy: _submitting,
              onReject: () => _reject(correction),
              onApprove: () => _approve(correction),
            )
          : null,
    );
  }

  void _showEvidence(AttendanceCorrection correction) {
    final url = correction.evidenceUrl;
    if (url == null ||
        (!url.startsWith('http://') && !url.startsWith('https://'))) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Pratinjau lampiran tersedia saat backend aktif.'),
          ),
        );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(url, fit: BoxFit.contain),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionBanner extends StatelessWidget {
  const _DecisionBanner({required this.correction});

  final AttendanceCorrection correction;

  @override
  Widget build(BuildContext context) {
    final tone = switch (correction.status) {
      RequestStatus.approved => StatusTone.success,
      RequestStatus.rejected => StatusTone.danger,
      RequestStatus.cancelled => StatusTone.neutral,
      RequestStatus.pending => StatusTone.info,
    };
    final icon = switch (correction.status) {
      RequestStatus.approved => Icons.check_circle_outline_rounded,
      RequestStatus.rejected => Icons.cancel_outlined,
      RequestStatus.cancelled => Icons.remove_circle_outline_rounded,
      RequestStatus.pending => Icons.info_outline_rounded,
    };

    return InfoBanner(
      icon: icon,
      title: 'Pengajuan ${correction.status.label.toLowerCase()}',
      message: correction.decisionNote.isEmpty
          ? null
          : correction.decisionNote,
      tone: tone,
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({required this.correction, required this.onTap});

  final AttendanceCorrection correction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppPalette.slate,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppPalette.blueSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.picture_as_pdf_outlined,
                size: 19,
                color: AppPalette.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    correction.evidenceName.isEmpty
                        ? 'Lampiran'
                        : correction.evidenceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.ink,
                    ),
                  ),
                  if (correction.evidenceMeta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      correction.evidenceMeta,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppPalette.faint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.open_in_new_rounded,
              size: 16,
              color: AppPalette.primary,
            ),
          ],
        ),
      ),
    );
  }
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
          const SizedBox(height: 14),
          Text(
            'Peninjau: ${correction.reviewer.isEmpty ? 'Atasan langsung' : correction.reviewer}',
            style: const TextStyle(fontSize: 10.5, color: AppPalette.muted),
          ),
        ],
      ),
    );
  }
}
