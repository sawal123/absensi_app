import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../core/formatters.dart';
import '../../data/models/attendance.dart';
import '../../data/models/leave_request.dart';
import '../../data/models/user.dart';
import '../../data/models/work_shift.dart';
import '../../providers/admin_provider.dart';
import '../../providers/approval_provider.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/page_header.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/surface_card.dart';
import '../../widgets/empty_state.dart';

enum _TeamStatus { present, late, leave, absent }

class _Member {
  const _Member({
    required this.user,
    required this.record,
    required this.leave,
    required this.shift,
  });

  final User user;
  final Attendance? record;
  final LeaveRequest? leave;
  final WorkShift? shift;

  _TeamStatus status(String workStart, [int lateTolerance = 0]) {
    if (record?.hasCheckedIn ?? false) {
      return isLate(
        record!.checkInAt!,
        shift?.start ?? workStart,
        lateTolerance,
      )
          ? _TeamStatus.late
          : _TeamStatus.present;
    }
    if (leave != null) return _TeamStatus.leave;
    return _TeamStatus.absent;
  }
}

class TeamTab extends StatefulWidget {
  const TeamTab({super.key});

  @override
  State<TeamTab> createState() => _TeamTabState();
}

class _TeamTabState extends State<TeamTab> {
  final _search = TextEditingController();
  int _filter = 0;

  static const _filterLabels = ['Semua', 'Hadir', 'Terlambat', 'Cuti', 'Belum'];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final approvals = context.watch<ApprovalProvider>();
    final settings = admin.settings;
    final date = admin.selectedDate;

    final records = {for (final record in admin.records) record.userId: record};
    final leaves = approvals.approvedByEmployeeId(date);

    final members =
        admin.employees
            .map(
              (user) => _Member(
                user: user,
                record: records[user.id],
                leave: leaves[user.id],
                shift: admin.shiftForEmployee(user.id!, date),
              ),
            )
            .toList()
          ..sort((a, b) => a.user.name.compareTo(b.user.name));

    final counts = {
      _TeamStatus.present: members
          .where(
            (m) =>
                m.status(
                  settings.workStart,
                  settings.lateToleranceMinutes,
                ) ==
                _TeamStatus.present,
          )
          .length,
      _TeamStatus.late: members
          .where(
            (m) =>
                m.status(
                  settings.workStart,
                  settings.lateToleranceMinutes,
                ) ==
                _TeamStatus.late,
          )
          .length,
      _TeamStatus.leave: members
          .where(
            (m) =>
                m.status(
                  settings.workStart,
                  settings.lateToleranceMinutes,
                ) ==
                _TeamStatus.leave,
          )
          .length,
      _TeamStatus.absent: members
          .where(
            (m) =>
                m.status(
                  settings.workStart,
                  settings.lateToleranceMinutes,
                ) ==
                _TeamStatus.absent,
          )
          .length,
    };

    final query = _search.text.trim().toLowerCase();
    final filtered = members.where((member) {
      final status = member.status(
        settings.workStart,
        settings.lateToleranceMinutes,
      );
      final matchesFilter = switch (_filter) {
        1 => status == _TeamStatus.present,
        2 => status == _TeamStatus.late,
        3 => status == _TeamStatus.leave,
        4 => status == _TeamStatus.absent,
        _ => true,
      };
      final matchesQuery =
          query.isEmpty ||
          member.user.name.toLowerCase().contains(query) ||
          member.user.nip.toLowerCase().contains(query);
      return matchesFilter && matchesQuery;
    }).toList();

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: admin.load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 20),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            PageHeader(
              title: 'Kehadiran Tim',
              subtitle: 'Tim Operasional · ${admin.employees.length} anggota',
              trailing: const AppBadge(label: 'Atasan'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DateSelector(
                    date: date,
                    onTap: () => _pickDate(context, admin),
                  ),
                  const SizedBox(height: 12),
                  FilterChipBar(
                    options: [
                      FilterOption(label: 'Semua', count: members.length),
                      FilterOption(
                        label: 'Hadir',
                        count: counts[_TeamStatus.present],
                      ),
                      FilterOption(
                        label: 'Terlambat',
                        count: counts[_TeamStatus.late],
                      ),
                      FilterOption(
                        label: 'Cuti',
                        count: counts[_TeamStatus.leave],
                      ),
                      FilterOption(
                        label: 'Belum',
                        count: counts[_TeamStatus.absent],
                      ),
                    ],
                    selectedIndex: _filter,
                    onSelected: (index) => setState(() => _filter = index),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Cari nama atau NIP karyawan',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: AppPalette.faint,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SectionHeader(
                    title: _filter == 0
                        ? 'Semua anggota · ${filtered.length}'
                        : '${_filterLabels[_filter]} · ${filtered.length}',
                    actionLabel:
                        'Diperbarui ${formatClock(DateTime.now())} WIB',
                    actionColor: AppPalette.faint,
                  ),
                  const SizedBox(height: 10),
                  if (admin.loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (filtered.isEmpty)
                    const EmptyState(
                      icon: Icons.group_off_outlined,
                      title: 'Tidak ada anggota yang cocok',
                      subtitle: 'Coba ubah filter atau kata kunci pencarian.',
                    )
                  else
                    SurfaceCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < filtered.length; i++) ...[
                            if (i > 0)
                              const Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                              ),
                            _MemberRow(
                              member: filtered[i],
                              workStart: settings.workStart,
                              lateTolerance: settings.lateToleranceMinutes,
                              officeName: settings.officeName,
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  const Text(
                    'Semua jam dalam WIB. Tanda — berarti belum ada catatan '
                    'absensi; karyawan cuti tidak diwajibkan absen.',
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.5,
                      color: AppPalette.faint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, AdminProvider admin) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: admin.selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      await admin.selectDate(picked);
    }
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
              formatFullDate(date),
              style: const TextStyle(
                fontSize: 13.5,
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

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.workStart,
    required this.lateTolerance,
    required this.officeName,
  });

  final _Member member;
  final String workStart;
  final int lateTolerance;
  final String officeName;

  @override
  Widget build(BuildContext context) {
    final status = member.status(workStart, lateTolerance);
    final record = member.record;

    final pill = switch (status) {
      _TeamStatus.present => const StatusPill(
        label: 'Hadir',
        tone: StatusTone.success,
        dense: true,
      ),
      _TeamStatus.late => const StatusPill(
        label: 'Terlambat',
        tone: StatusTone.warning,
        dense: true,
      ),
      _TeamStatus.leave => const StatusPill(
        label: 'Cuti',
        tone: StatusTone.info,
        dense: true,
      ),
      _TeamStatus.absent => const StatusPill(
        label: 'Belum absen',
        tone: StatusTone.neutral,
        dense: true,
      ),
    };

    final (note, noteColor, noteIcon) = _note(status, record);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialsAvatar(name: member.user.name, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.user.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.ink,
                        ),
                      ),
                    ),
                    pill,
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: member.shift == null
                            ? AppPalette.faint
                            : Color(member.shift!.resolvedColorValue),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'NIP ${member.user.nip} · '
                        '${member.shift?.name ?? 'Libur'} · '
                        '${member.shift?.rangeLabel ?? '-'}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppPalette.faint,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'Masuk ',
                      style: TextStyle(fontSize: 10.5, color: AppPalette.muted),
                    ),
                    Text(
                      record?.checkInAt == null
                          ? '—'
                          : formatClock(record!.checkInAt),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: record?.checkInAt == null
                            ? AppPalette.faint
                            : AppPalette.ink,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Pulang ',
                      style: TextStyle(fontSize: 10.5, color: AppPalette.muted),
                    ),
                    Text(
                      record?.checkOutAt == null
                          ? '—'
                          : formatClock(record!.checkOutAt),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: record?.checkOutAt == null
                            ? AppPalette.faint
                            : AppPalette.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(noteIcon, size: 12, color: noteColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        note,
                        style: TextStyle(fontSize: 10, color: noteColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (String, Color, IconData) _note(_TeamStatus status, Attendance? record) {
    switch (status) {
      case _TeamStatus.present:
        return (
          'Lokasi valid · $officeName',
          AppPalette.green,
          Icons.verified_outlined,
        );
      case _TeamStatus.late:
        final start = dateWithTime(
          record!.checkInAt!,
          member.shift?.start ?? workStart,
        ).add(Duration(minutes: lateTolerance));
        final minutes = record.checkInAt!.difference(start).inMinutes;
        return (
          'Terlambat $minutes menit',
          AppPalette.amber,
          Icons.schedule_rounded,
        );
      case _TeamStatus.leave:
        final leave = member.leave!;
        return (
          '${leave.type} disetujui · ${leave.endDate.day} '
              '${monthShort(leave.endDate.month)}',
          AppPalette.muted,
          Icons.info_outline_rounded,
        );
      case _TeamStatus.absent:
        return (
          'Lokasi belum tersedia · Shift belum mulai',
          AppPalette.faint,
          Icons.info_outline_rounded,
        );
    }
  }
}
