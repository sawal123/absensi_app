import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../core/formatters.dart';
import '../../data/models/attendance_correction.dart';
import '../../data/models/leave_balance.dart';
import '../../data/models/leave_request.dart';
import '../../data/models/request_status.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/my_requests_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/page_header.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/surface_card.dart';
import 'correction_request_screen.dart';
import 'leave_request_form_screen.dart';
import 'my_correction_detail_screen.dart';
import 'my_leave_detail_screen.dart';

class RequestsTab extends StatefulWidget {
  const RequestsTab({super.key});

  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
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

  int _tab = 0;
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final requests = context.watch<MyRequestsProvider>();
    final leaves = _visibleLeaves(requests.leaveRequests);
    final corrections = _visibleCorrections(requests.corrections);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: requests.load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const PageHeader(
              title: 'Pengajuan Saya',
              subtitle: 'Cuti, izin, dan perbaikan absensi.',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BalanceCard(balance: requests.annualLeaveBalance),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => _openLeaveForm(context),
                    icon: const Icon(Icons.event_available_rounded, size: 19),
                    label: const Text('Ajukan cuti'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _openCorrectionForm(context),
                    icon: const Icon(Icons.edit_document, size: 19),
                    label: const Text('Ajukan perbaikan absensi'),
                  ),
                  const SizedBox(height: 22),
                  SegmentedSwitch(
                    options: [
                      SegmentOption(
                        label: 'Cuti',
                        count: requests.leaveRequests.length,
                      ),
                      SegmentOption(
                        label: 'Perbaikan',
                        count: requests.corrections.length,
                      ),
                    ],
                    index: _tab,
                    onChanged: (index) => setState(() => _tab = index),
                  ),
                  const SizedBox(height: 12),
                  FilterChipBar(
                    options: _filterLabels,
                    selectedIndex: _filter,
                    onSelected: (index) => setState(() => _filter = index),
                  ),
                  if (requests.error != null) ...[
                    const SizedBox(height: 14),
                    InfoBanner(
                      icon: Icons.error_outline_rounded,
                      title: 'Gagal memuat pengajuan',
                      message: requests.error,
                      tone: StatusTone.danger,
                      trailing: TextButton(
                        onPressed: requests.load,
                        child: const Text('Coba'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (requests.loading &&
                      requests.leaveRequests.isEmpty &&
                      requests.corrections.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_tab == 0) ...[
                    SectionHeader(
                      title: 'Pengajuan cuti',
                      actionLabel: '${leaves.length} pengajuan',
                    ),
                    const SizedBox(height: 10),
                    if (leaves.isEmpty)
                      const EmptyState(
                        icon: Icons.event_available_outlined,
                        title: 'Belum ada pengajuan cuti',
                        subtitle: 'Pengajuan dengan filter ini belum tersedia.',
                      )
                    else
                      for (final leave in leaves)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _LeaveCard(
                            leave: leave,
                            onTap: () => _openLeaveDetail(context, leave),
                          ),
                        ),
                  ] else ...[
                    SectionHeader(
                      title: 'Perbaikan absensi',
                      actionLabel: '${corrections.length} pengajuan',
                    ),
                    const SizedBox(height: 10),
                    if (corrections.isEmpty)
                      const EmptyState(
                        icon: Icons.edit_document,
                        title: 'Belum ada perbaikan absensi',
                        subtitle: 'Pengajuan dengan filter ini belum tersedia.',
                      )
                    else
                      for (final correction in corrections)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CorrectionCard(
                            correction: correction,
                            onTap: () =>
                                _openCorrectionDetail(context, correction),
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

  List<LeaveRequest> _visibleLeaves(List<LeaveRequest> source) {
    final filter = _filters[_filter];
    final items = filter == null
        ? List<LeaveRequest>.of(source)
        : source.where((leave) => leave.status == filter).toList();
    items.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return items;
  }

  List<AttendanceCorrection> _visibleCorrections(
    List<AttendanceCorrection> source,
  ) {
    final filter = _filters[_filter];
    final items = filter == null
        ? List<AttendanceCorrection>.of(source)
        : source.where((item) => item.status == filter).toList();
    items.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return items;
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

  void _openLeaveDetail(BuildContext context, LeaveRequest leave) {
    final requests = context.read<MyRequestsProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<MyRequestsProvider>.value(
          value: requests,
          child: MyLeaveDetailScreen(leaveId: leave.id),
        ),
      ),
    );
  }

  void _openCorrectionDetail(
    BuildContext context,
    AttendanceCorrection correction,
  ) {
    final requests = context.read<MyRequestsProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<MyRequestsProvider>.value(
          value: requests,
          child: MyCorrectionDetailScreen(correctionId: correction.id),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final LeaveBalance? balance;

  @override
  Widget build(BuildContext context) {
    final remaining = balance?.remainingDays;

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
            'Sisa cuti tahunan',
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                remaining == null ? '—' : '$remaining',
                style: const TextStyle(
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'hari',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            balance == null
                ? 'Saldo cuti belum tersedia.'
                : 'Hak ${balance!.entitledDays} hari · '
                      'Terpakai ${balance!.usedDays} hari',
            style: TextStyle(
              fontSize: 10.5,
              color: Colors.white.withValues(alpha: 0.8),
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
    final hasNote = leave.decisionNote.trim().isNotEmpty;

    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  leave.code,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppPalette.faint,
                  ),
                ),
              ),
              requestStatusPill(leave.status),
            ],
          ),
          const SizedBox(height: 10),
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
            '${leave.type} · ${formatWorkingDays(leave.workingDays)}',
            style: const TextStyle(fontSize: 11, color: AppPalette.muted),
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
    final hasNote = correction.decisionNote.trim().isNotEmpty;

    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  correction.code,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppPalette.faint,
                  ),
                ),
              ),
              requestStatusPill(correction.status),
            ],
          ),
          const SizedBox(height: 10),
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
            style: const TextStyle(fontSize: 11, color: AppPalette.muted),
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
