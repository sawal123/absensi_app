import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../core/formatters.dart';
import '../../data/models/attendance_correction.dart';
import '../../data/models/leave_request.dart';
import '../../data/models/request_status.dart';
import '../../providers/admin_provider.dart';
import '../../providers/approval_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/page_header.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/surface_card.dart';
import 'correction_detail_screen.dart';
import 'leave_detail_screen.dart';

class ApprovalsTab extends StatelessWidget {
  const ApprovalsTab({super.key});

  static const _filters = <RequestStatus?>[
    null,
    RequestStatus.pending,
    RequestStatus.approved,
    RequestStatus.rejected,
    RequestStatus.cancelled,
  ];

  static const _filterLabels = <FilterOption>[
    FilterOption(label: 'Semua'),
    FilterOption(label: 'Menunggu'),
    FilterOption(label: 'Disetujui'),
    FilterOption(label: 'Ditolak'),
    FilterOption(label: 'Dibatalkan'),
  ];

  @override
  Widget build(BuildContext context) {
    final approvals = context.watch<ApprovalProvider>();
    final filterIndex = _filters.indexOf(approvals.statusFilter);
    final leaves = approvals.visibleLeaves;
    final corrections = approvals.visibleCorrections;
    final showCorrectionTeaser =
        approvals.tab == ApprovalTab.leave &&
        approvals.statusFilter == null &&
        approvals.pendingCorrections.isNotEmpty;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: approvals.load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const PageHeader(
              title: 'Persetujuan',
              subtitle: 'Tinjau pengajuan Tim Operasional',
              trailing: AppBadge(label: 'Atasan'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PendingBanner(approvals: approvals),
                  const SizedBox(height: 14),
                  SegmentedSwitch(
                    options: [
                      SegmentOption(label: 'Cuti', count: approvals.leaveCount),
                      SegmentOption(
                        label: 'Perbaikan Absensi',
                        count: approvals.correctionCount,
                      ),
                    ],
                    index: approvals.tab.index,
                    onChanged: (index) =>
                        approvals.selectTab(ApprovalTab.values[index]),
                  ),
                  const SizedBox(height: 12),
                  FilterChipBar(
                    options: _filterLabels,
                    selectedIndex: filterIndex < 0 ? 0 : filterIndex,
                    onSelected: (index) =>
                        approvals.selectStatus(_filters[index]),
                  ),
                  if (approvals.error != null) ...[
                    const SizedBox(height: 14),
                    InfoBanner(
                      icon: Icons.error_outline_rounded,
                      title: 'Gagal memuat pengajuan',
                      message: approvals.error,
                      tone: StatusTone.danger,
                      trailing: TextButton(
                        onPressed: approvals.load,
                        child: const Text('Coba'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (approvals.loading &&
                      approvals.leaveCount == 0 &&
                      approvals.correctionCount == 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (approvals.tab == ApprovalTab.leave) ...[
                    SectionHeader(
                      title: 'Pengajuan cuti',
                      actionLabel: '${leaves.length} pengajuan',
                    ),
                    const SizedBox(height: 10),
                    if (leaves.isEmpty)
                      const EmptyState(
                        icon: Icons.event_available_outlined,
                        title: 'Tidak ada pengajuan cuti',
                        subtitle: 'Pengajuan dengan filter ini belum tersedia.',
                      )
                    else
                      for (final leave in leaves)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _LeaveCard(
                            leave: leave,
                            onTap: () => _openLeave(context, leave),
                          ),
                        ),
                    if (showCorrectionTeaser) ...[
                      const SizedBox(height: 12),
                      const SectionHeader(title: 'Perbaikan perlu ditinjau'),
                      const SizedBox(height: 10),
                      for (final correction in approvals.pendingCorrections)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CorrectionCard(
                            correction: correction,
                            onTap: () => _openCorrection(context, correction),
                          ),
                        ),
                    ],
                  ] else ...[
                    SectionHeader(
                      title: 'Perbaikan absensi',
                      actionLabel: '${corrections.length} pengajuan',
                    ),
                    const SizedBox(height: 10),
                    if (corrections.isEmpty)
                      const EmptyState(
                        icon: Icons.edit_document,
                        title: 'Tidak ada perbaikan absensi',
                        subtitle: 'Pengajuan dengan filter ini belum tersedia.',
                      )
                    else
                      for (final correction in corrections)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CorrectionCard(
                            correction: correction,
                            onTap: () => _openCorrection(context, correction),
                          ),
                        ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.approvals});

  final ApprovalProvider approvals;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppPalette.headerGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 22,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${approvals.pendingCount} pengajuan menunggu',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${approvals.pendingLeaveCount} cuti dan '
                  '${approvals.pendingCorrectionCount} perbaikan absensi',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.leave, required this.onTap});

  final LeaveRequest leave;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rejected = leave.status == RequestStatus.rejected;
    final hasNote =
        leave.status.isDecided && leave.decisionNote.trim().isNotEmpty;

    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InitialsAvatar(name: leave.employeeName, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leave.employeeName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
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
              requestStatusPill(leave.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDateRange(leave.startDate, leave.endDate),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${leave.type} · '
                      '${formatWorkingDays(leave.workingDays)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppPalette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppPalette.primary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasNote
                ? leave.decisionNote
                : leave.status.isDecided
                ? '${leave.status.label} oleh '
                      '${leave.reviewer.isEmpty ? 'atasan' : leave.reviewer}'
                : 'Diajukan ${formatStamp(leave.submittedAt)}',
            style: TextStyle(
              fontSize: 10.5,
              color: rejected ? AppPalette.red : AppPalette.faint,
            ),
          ),
        ],
      ),
    );
  }
}

class _CorrectionCard extends StatelessWidget {
  const _CorrectionCard({required this.correction, required this.onTap});

  final AttendanceCorrection correction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rejected = correction.status == RequestStatus.rejected;
    final hasNote =
        correction.status.isDecided && correction.decisionNote.trim().isNotEmpty;

    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InitialsAvatar(name: correction.employeeName, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      correction.employeeName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
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
              requestStatusPill(correction.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatFullDate(correction.date),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      correction.correctionType.label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppPalette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppPalette.primary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasNote
                ? correction.decisionNote
                : correction.status.isDecided
                ? '${correction.status.label} oleh '
                      '${correction.reviewer.isEmpty ? 'atasan' : correction.reviewer}'
                : 'Diajukan ${formatStamp(correction.submittedAt)}',
            style: TextStyle(
              fontSize: 10.5,
              color: rejected ? AppPalette.red : AppPalette.faint,
            ),
          ),
        ],
      ),
    );
  }
}
