import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../core/formatters.dart';
import '../../data/models/leave_request.dart';
import '../../data/models/request_status.dart';
import '../../providers/my_requests_provider.dart';
import '../../widgets/detail_row.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/page_header.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/surface_card.dart';

class MyLeaveDetailScreen extends StatefulWidget {
  const MyLeaveDetailScreen({super.key, required this.leaveId});

  final int leaveId;

  @override
  State<MyLeaveDetailScreen> createState() => _MyLeaveDetailScreenState();
}

class _MyLeaveDetailScreenState extends State<MyLeaveDetailScreen> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final requests = context.watch<MyRequestsProvider>();
    final leave = requests.leaveById(widget.leaveId);

    if (leave == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pengajuan Cuti')),
        body: const Center(
          child: Text(
            'Pengajuan tidak ditemukan.',
            style: TextStyle(color: AppPalette.muted),
          ),
        ),
      );
    }

    final isPending = leave.status.isPending;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PageHeader(
              center: true,
              leading: const SquareBackButton(),
              title: 'Pengajuan Cuti',
              subtitle: 'Detail pengajuan · ${leave.code}',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  _HeaderCard(leave: leave),
                  const SizedBox(height: 12),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Rincian pengajuan',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DetailRow(label: 'Jenis cuti', value: leave.type),
                        DetailRow(
                          label: 'Rentang tanggal',
                          value: formatDateRange(
                            leave.startDate,
                            leave.endDate,
                          ),
                        ),
                        DetailRow(
                          label: 'Durasi',
                          value: formatWorkingDays(leave.workingDays),
                        ),
                        DetailRow(
                          label: 'Diajukan',
                          value: formatStamp(leave.submittedAt),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _BalanceCard(leave: leave),
                  const SizedBox(height: 12),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Alasan pengajuan',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          leave.reason,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.55,
                            color: AppPalette.muted,
                          ),
                        ),
                        if ((leave.attachmentUrl ?? '').isNotEmpty) ...[
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
                                  _fileName(leave.attachmentUrl!),
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
                  _StatusBanner(leave: leave),
                  if (isPending) ...[
                    const SizedBox(height: 14),
                    const InfoBanner(
                      icon: Icons.info_outline_rounded,
                      title: 'Masih dapat dibatalkan',
                      message:
                          'Batalkan pengajuan bila rencana berubah. Saldo '
                          'cuti tidak terpakai selama belum disetujui.',
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
              onTap: () => _cancel(leave),
            )
          : null,
    );
  }

  Future<void> _cancel(LeaveRequest leave) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan pengajuan?'),
        content: const Text(
          'Pengajuan cuti ini akan berstatus dibatalkan dan tidak dapat '
          'dikirim ulang.',
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
    final ok = await requests.cancelLeave(leave.id);
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Pengajuan cuti dibatalkan.')),
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
  const _HeaderCard({required this.leave});

  final LeaveRequest leave;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              requestStatusPill(leave.status),
              const Spacer(),
              Text(
                formatStamp(leave.submittedAt),
                style: const TextStyle(fontSize: 10.5, color: AppPalette.faint),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              InitialsAvatar(name: leave.employeeName, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leave.employeeName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'NIP ${leave.nip} · ${leave.team}',
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
          if (leave.reviewer.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Peninjau: ${leave.reviewer}',
              style: const TextStyle(fontSize: 10.5, color: AppPalette.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.leave});

  final LeaveRequest leave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.blueSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Saldo cuti tahunan ${leave.startDate.year}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.ink,
                  ),
                ),
              ),
              const Icon(
                Icons.calendar_month_rounded,
                size: 18,
                color: AppPalette.primary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  value: '${leave.balanceRemaining}',
                  label: 'Saldo saat ini',
                  color: AppPalette.ink,
                ),
              ),
              Expanded(
                child: _Stat(
                  value: '−${leave.balanceRequested}',
                  label: 'Diajukan',
                  color: AppPalette.ink,
                ),
              ),
              Expanded(
                child: _Stat(
                  value: '${leave.balanceAfter}',
                  label: 'Jika disetujui',
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

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

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
              value,
              style: TextStyle(
                fontSize: 22,
                height: 1,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(width: 3),
            const Text(
              'hari',
              style: TextStyle(fontSize: 9.5, color: AppPalette.muted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 9.5, color: AppPalette.muted),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.leave});

  final LeaveRequest leave;

  @override
  Widget build(BuildContext context) {
    final message = leave.decisionNote.trim().isEmpty
        ? null
        : leave.decisionNote;

    return switch (leave.status) {
      RequestStatus.pending => const InfoBanner(
        icon: Icons.hourglass_top_rounded,
        title: 'Menunggu persetujuan',
        message: 'Pengajuan sedang ditinjau atasan langsung.',
        tone: StatusTone.warning,
      ),
      RequestStatus.approved => InfoBanner(
        icon: Icons.check_circle_outline_rounded,
        title: 'Pengajuan disetujui',
        message: message,
        tone: StatusTone.success,
      ),
      RequestStatus.rejected => InfoBanner(
        icon: Icons.cancel_outlined,
        title: 'Pengajuan ditolak',
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
