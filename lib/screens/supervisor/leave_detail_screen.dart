import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../core/formatters.dart';
import '../../data/models/leave_request.dart';
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

class LeaveDetailScreen extends StatefulWidget {
  const LeaveDetailScreen({super.key, required this.leaveId});

  final int leaveId;

  @override
  State<LeaveDetailScreen> createState() => _LeaveDetailScreenState();
}

class _LeaveDetailScreenState extends State<LeaveDetailScreen> {
  final _note = TextEditingController();
  bool _noteError = false;
  bool _submitting = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _approve(LeaveRequest leave) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final approvals = context.read<ApprovalProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await approvals.approveLeave(leave.id, note: _note.text.trim());
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Pengajuan cuti disetujui.')),
      );
      return;
    }

    setState(() => _submitting = false);
    final message = approvals.error ?? 'Pengajuan gagal disetujui.';
    approvals.clearError();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reject(LeaveRequest leave) async {
    if (_note.text.trim().isEmpty) {
      setState(() => _noteError = true);
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    final approvals = context.read<ApprovalProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await approvals.rejectLeave(leave.id, note: _note.text.trim());
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Pengajuan cuti ditolak.')),
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
    final admin = context.watch<AdminProvider>();
    final leave = approvals.leaveById(widget.leaveId);

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

    final isPending = leave.status == RequestStatus.pending;
    final span = isSameDay(leave.startDate, leave.endDate)
        ? formatDayName(leave.startDate)
        : '${formatDayName(leave.startDate)}–'
              '${formatDayName(leave.endDate)}';
    final shift = admin.shiftForEmployee(leave.employeeId, leave.startDate);
    final scheduleLabel = shift == null
        ? 'Hari libur'
        : '${shift.name} · ${formatClockRange(shift.start, shift.end)} WIB';

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
                          value:
                              '${formatWorkingDays(leave.workingDays)} · '
                              '$span',
                        ),
                        DetailRow(
                          label: 'Jadwal terdampak',
                          value: scheduleLabel,
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
                  if (leave.teamTotal > 0)
                    InfoBanner(
                      icon: Icons.groups_2_outlined,
                      title:
                          '${leave.teamAvailable} dari ${leave.teamTotal} '
                          'anggota tetap tersedia',
                      tone: StatusTone.success,
                      message:
                          '${formatDateRange(leave.startDate, leave.endDate)} '
                          'tidak ada cuti lain yang disetujui. Serah terima '
                          ' pekerjaan perlu dikonfirmasi.',
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
                    _DecisionBanner(leave: leave),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isPending
          ? DecisionBar(
              busy: _submitting,
              onReject: () => _reject(leave),
              onApprove: () => _approve(leave),
            )
          : null,
    );
  }

  String _fileName(String value) => value.split(RegExp(r'[/\\]')).last;
}

class _DecisionBanner extends StatelessWidget {
  const _DecisionBanner({required this.leave});

  final LeaveRequest leave;

  @override
  Widget build(BuildContext context) {
    final tone = switch (leave.status) {
      RequestStatus.approved => StatusTone.success,
      RequestStatus.rejected => StatusTone.danger,
      RequestStatus.cancelled => StatusTone.neutral,
      RequestStatus.pending => StatusTone.info,
    };
    final icon = switch (leave.status) {
      RequestStatus.approved => Icons.check_circle_outline_rounded,
      RequestStatus.rejected => Icons.cancel_outlined,
      RequestStatus.cancelled => Icons.remove_circle_outline_rounded,
      RequestStatus.pending => Icons.info_outline_rounded,
    };

    return InfoBanner(
      icon: icon,
      title: 'Pengajuan ${leave.status.label.toLowerCase()}',
      message: leave.decisionNote.isEmpty ? null : leave.decisionNote,
      tone: tone,
    );
  }
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
          const SizedBox(height: 14),
          Text(
            'Peninjau: ${leave.reviewer.isEmpty ? 'Atasan langsung' : leave.reviewer}',
            style: const TextStyle(fontSize: 10.5, color: AppPalette.muted),
          ),
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
    final sufficiency = leave.balanceAfter >= 0
        ? 'Saldo mencukupi.'
        : 'Saldo tidak mencukupi.';

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
                child: _BalanceStat(
                  value: '${leave.balanceRemaining}',
                  label: 'Saldo saat ini',
                  color: AppPalette.ink,
                ),
              ),
              Expanded(
                child: _BalanceStat(
                  value: '−${leave.balanceRequested}',
                  label: 'Diajukan',
                  color: AppPalette.ink,
                ),
              ),
              Expanded(
                child: _BalanceStat(
                  value: '${leave.balanceAfter}',
                  label: 'Jika disetujui',
                  color: AppPalette.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            sufficiency,
            style: const TextStyle(fontSize: 10.5, color: AppPalette.muted),
          ),
        ],
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  const _BalanceStat({
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
