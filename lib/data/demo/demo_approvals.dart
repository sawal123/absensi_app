import '../../core/formatters.dart';
import '../models/attendance_correction.dart';
import '../models/correction_type.dart';
import '../models/leave_balance.dart';
import '../models/leave_request.dart';
import '../models/leave_type.dart';
import '../models/request_status.dart';

/// Seed data for leave & correction requests.
///
/// Dates are relative to [now] so a fresh install always looks current.
abstract final class DemoApprovals {
  static const team = 'Tim Operasional';

  static const leaveTypes = <LeaveType>[
    LeaveType(id: 1, name: 'Cuti tahunan', isPaid: true, maxDaysPerYear: 12),
    LeaveType(id: 2, name: 'Izin', isPaid: true, maxDaysPerYear: 3),
    LeaveType(id: 3, name: 'Sakit', isPaid: true, maxDaysPerYear: 12),
  ];

  static const employees = <DemoEmployee>[
    DemoEmployee(
      email: 'aditya@absensi.com',
      name: 'Aditya Pratama',
      nip: '0248',
      annualLeaveUsed: 3,
      permissionUsed: 1,
    ),
    DemoEmployee(
      email: 'budi@absensi.com',
      name: 'Budi Santoso',
      nip: '0251',
      annualLeaveUsed: 12,
      sickUsed: 1,
    ),
    DemoEmployee(
      email: 'citra@absensi.com',
      name: 'Citra Lestari',
      nip: '0256',
      annualLeaveUsed: 2,
    ),
    DemoEmployee(
      email: 'dimas@absensi.com',
      name: 'Dimas Prakoso',
      nip: '0260',
      annualLeaveUsed: 4,
      permissionUsed: 1,
    ),
    DemoEmployee(email: 'eko@absensi.com', name: 'Eko Saputra', nip: '0262'),
    DemoEmployee(
      email: 'fajar@absensi.com',
      name: 'Fajar Ramadhan',
      nip: '0265',
      annualLeaveUsed: 1,
    ),
    DemoEmployee(
      email: 'rina@absensi.com',
      name: 'Rina Wulandari',
      nip: '0268',
      annualLeaveUsed: 4,
    ),
    DemoEmployee(
      email: 'nanda@absensi.com',
      name: 'Nanda Putri',
      nip: '0271',
      annualLeaveUsed: 2,
      sickUsed: 1,
    ),
  ];

  static List<LeaveBalance> leaveBalances(
    DateTime now,
    Map<String, int> userIdByEmail,
  ) {
    final year = now.year;
    final balances = <LeaveBalance>[];

    for (final employee in employees) {
      final employeeId = userIdByEmail[employee.email];
      if (employeeId == null) continue;

      balances.addAll([
        LeaveBalance(
          id: 0,
          employeeId: employeeId,
          leaveTypeId: 1,
          year: year,
          entitledDays: 12,
          usedDays: employee.annualLeaveUsed,
          adjustmentDays: 0,
        ),
        LeaveBalance(
          id: 0,
          employeeId: employeeId,
          leaveTypeId: 2,
          year: year,
          entitledDays: 3,
          usedDays: employee.permissionUsed,
          adjustmentDays: 0,
        ),
        LeaveBalance(
          id: 0,
          employeeId: employeeId,
          leaveTypeId: 3,
          year: year,
          entitledDays: 12,
          usedDays: employee.sickUsed,
          adjustmentDays: 0,
        ),
      ]);
    }

    return balances;
  }

  static List<LeaveRequest> leaves(
    DateTime now,
    Map<String, int> userIdByEmail,
  ) {
    final today = dateOnly(now);

    LeaveRequest build({
      required String email,
      required int leaveTypeId,
      required String type,
      required DateTime start,
      required DateTime end,
      required int days,
      required String reason,
      required DateTime submittedAt,
      required RequestStatus status,
      required int teamAvailable,
      required int teamTotal,
      int? reviewerId,
      String reviewer = 'Dewi Puspita',
      DateTime? reviewedAt,
      String decisionNote = '',
      String? attachmentUrl,
    }) {
      final employee = employeeByEmail(email);
      final employeeId = userIdByEmail[email] ?? 0;
      final balance = _balanceFor(email, leaveTypeId);
      final requested = days;
      final before = balance;
      final after = before - requested;

      return LeaveRequest(
        id: _codeSeed(email, start),
        employeeId: employeeId,
        code: _code('CT', start, employee.nip),
        employeeName: employee.name,
        nip: employee.nip,
        team: team,
        leaveTypeId: leaveTypeId,
        type: type,
        startDate: start,
        endDate: end,
        workingDays: requested,
        reason: reason,
        attachmentUrl: attachmentUrl,
        submittedAt: submittedAt,
        status: status,
        reviewerId: reviewerId,
        reviewer: reviewer,
        reviewedAt: reviewedAt,
        decisionNote: decisionNote,
        balanceRemaining: before,
        balanceRequested: requested,
        balanceAfter: after,
        teamAvailable: teamAvailable,
        teamTotal: teamTotal,
      );
    }

    return [
      build(
        email: 'citra@absensi.com',
        leaveTypeId: 1,
        type: 'Cuti tahunan',
        start: today.add(const Duration(days: 4)),
        end: today.add(const Duration(days: 5)),
        days: 2,
        reason:
            'Menghadiri acara keluarga di Bandung. Pekerjaan harian '
            'akan saya serahkan kepada Eko sebelum cuti.',
        submittedAt: _at(today.subtract(const Duration(days: 1)), 16, 20),
        status: RequestStatus.pending,
        teamAvailable: 7,
        teamTotal: 8,
      ),
      build(
        email: 'eko@absensi.com',
        leaveTypeId: 1,
        type: 'Cuti tahunan',
        start: today.add(const Duration(days: 7)),
        end: today.add(const Duration(days: 7)),
        days: 1,
        reason: 'Keperluan administrasi kependudukan di kantor kelurahan.',
        submittedAt: _at(today.subtract(const Duration(days: 2)), 8, 45),
        status: RequestStatus.pending,
        teamAvailable: 7,
        teamTotal: 8,
      ),
      build(
        email: 'dimas@absensi.com',
        leaveTypeId: 2,
        type: 'Izin',
        start: today.add(const Duration(days: 2)),
        end: today.add(const Duration(days: 2)),
        days: 1,
        reason: 'Izin keperluan pribadi yang tidak bisa ditinggalkan.',
        submittedAt: _at(today.subtract(const Duration(days: 1)), 14, 5),
        status: RequestStatus.pending,
        teamAvailable: 7,
        teamTotal: 8,
      ),
      build(
        email: 'fajar@absensi.com',
        leaveTypeId: 3,
        type: 'Sakit',
        start: today.subtract(const Duration(days: 1)),
        end: today.subtract(const Duration(days: 1)),
        days: 1,
        reason: 'Demam dan dokter menyarankan istirahat satu hari.',
        attachmentUrl: 'Surat_dokter_8Nov.pdf',
        submittedAt: _at(today.subtract(const Duration(days: 1)), 6, 40),
        status: RequestStatus.pending,
        teamAvailable: 7,
        teamTotal: 8,
      ),
      build(
        email: 'rina@absensi.com',
        leaveTypeId: 1,
        type: 'Cuti tahunan',
        start: today,
        end: today,
        days: 1,
        reason: 'Pemeriksaan kesehatan rutin di rumah sakit.',
        submittedAt: _at(today.subtract(const Duration(days: 3)), 13, 10),
        status: RequestStatus.approved,
        reviewedAt: _at(today.subtract(const Duration(days: 2)), 9, 5),
        decisionNote: 'Disetujui · Dewi Puspita',
        teamAvailable: 7,
        teamTotal: 8,
      ),
      build(
        email: 'budi@absensi.com',
        leaveTypeId: 1,
        type: 'Cuti tahunan',
        start: today.subtract(const Duration(days: 5)),
        end: today.subtract(const Duration(days: 5)),
        days: 1,
        reason: 'Acara keluarga di luar kota.',
        submittedAt: _at(today.subtract(const Duration(days: 6)), 10, 5),
        status: RequestStatus.rejected,
        reviewedAt: _at(today.subtract(const Duration(days: 5)), 8, 30),
        decisionNote: 'Ditolak · Saldo cuti tidak mencukupi',
        teamAvailable: 7,
        teamTotal: 8,
      ),
      build(
        email: 'nanda@absensi.com',
        leaveTypeId: 3,
        type: 'Sakit',
        start: today.subtract(const Duration(days: 8)),
        end: today.subtract(const Duration(days: 7)),
        days: 2,
        reason: 'Rawat jalan dan istirahat sesuai anjuran dokter.',
        submittedAt: _at(today.subtract(const Duration(days: 9)), 7, 20),
        status: RequestStatus.approved,
        reviewedAt: _at(today.subtract(const Duration(days: 8)), 9, 15),
        decisionNote: 'Disetujui · Dewi Puspita',
        teamAvailable: 7,
        teamTotal: 8,
      ),
      build(
        email: 'aditya@absensi.com',
        leaveTypeId: 1,
        type: 'Cuti tahunan',
        start: today.subtract(const Duration(days: 12)),
        end: today.subtract(const Duration(days: 12)),
        days: 1,
        reason: 'Keperluan keluarga yang sudah selesai.',
        submittedAt: _at(today.subtract(const Duration(days: 14)), 11, 0),
        status: RequestStatus.cancelled,
        reviewedAt: _at(today.subtract(const Duration(days: 13)), 8, 0),
        decisionNote: 'Dibatalkan oleh karyawan',
        teamAvailable: 7,
        teamTotal: 8,
      ),
    ];
  }

  static List<AttendanceCorrection> corrections(
    DateTime now,
    Map<String, int> userIdByEmail,
  ) {
    final today = dateOnly(now);

    AttendanceCorrection build({
      required String email,
      required DateTime eventDate,
      required CorrectionType type,
      required DateTime? recordedCheckIn,
      required DateTime? recordedCheckOut,
      required DateTime? proposedCheckIn,
      required DateTime? proposedCheckOut,
      required String reason,
      required DateTime submittedAt,
      required RequestStatus status,
      String evidenceName = '',
      String evidenceMeta = '',
      DateTime? reviewedAt,
      String decisionNote = '',
    }) {
      final employee = employeeByEmail(email);

      return AttendanceCorrection(
        id: _codeSeed(email, eventDate),
        employeeId: userIdByEmail[email] ?? 0,
        code: _code('PA', eventDate, employee.nip),
        employeeName: employee.name,
        nip: employee.nip,
        team: team,
        date: eventDate,
        scheduledStart: '08:00',
        scheduledEnd: '17:00',
        recordedCheckIn: recordedCheckIn,
        recordedCheckOut: recordedCheckOut,
        proposedCheckIn: proposedCheckIn,
        proposedCheckOut: proposedCheckOut,
        correctionType: type,
        reason: reason,
        evidenceUrl: null,
        evidenceName: evidenceName,
        evidenceMeta: evidenceMeta,
        submittedAt: submittedAt,
        reviewer: 'Dewi Puspita',
        reviewedAt: reviewedAt,
        status: status,
        decisionNote: decisionNote,
      );
    }

    final adityaDate = today.subtract(const Duration(days: 1));
    final citraDate = today.subtract(const Duration(days: 2));
    final rinaDate = today.subtract(const Duration(days: 5));
    final ekoDate = today.subtract(const Duration(days: 7));
    final nandaDate = today.subtract(const Duration(days: 3));

    return [
      build(
        email: 'aditya@absensi.com',
        eventDate: adityaDate,
        type: CorrectionType.checkOut,
        recordedCheckIn: _at(adityaDate, 7, 58),
        recordedCheckOut: null,
        proposedCheckIn: _at(adityaDate, 7, 58),
        proposedCheckOut: _at(adityaDate, 17, 5),
        reason:
            'Lupa absen pulang setelah menyelesaikan rekap stok. '
            'Saya meninggalkan kantor pukul 17.05. Terlampir laporan '
            'pekerjaan sebagai bukti.',
        evidenceName: 'Laporan_stok_4Nov.pdf',
        evidenceMeta: 'PDF · 248 KB · 5 Nov 09.10',
        submittedAt: _at(today, 9, 10),
        status: RequestStatus.pending,
      ),
      build(
        email: 'citra@absensi.com',
        eventDate: citraDate,
        type: CorrectionType.checkIn,
        recordedCheckIn: null,
        recordedCheckOut: _at(citraDate, 17, 2),
        proposedCheckIn: _at(citraDate, 8, 2),
        proposedCheckOut: _at(citraDate, 17, 2),
        reason:
            'Lupa absen masuk karena langsung mengikuti rapat pagi. '
            'Rekan satu tim dapat mengonfirmasi kehadiran saya.',
        evidenceName: 'Foto_rapat_pagi.jpg',
        evidenceMeta: 'JPG · 1.2 MB · 3 Nov 08.15',
        submittedAt: _at(today.subtract(const Duration(days: 1)), 9, 30),
        status: RequestStatus.pending,
      ),
      build(
        email: 'rina@absensi.com',
        eventDate: rinaDate,
        type: CorrectionType.checkOut,
        recordedCheckIn: _at(rinaDate, 7, 55),
        recordedCheckOut: null,
        proposedCheckIn: _at(rinaDate, 7, 55),
        proposedCheckOut: _at(rinaDate, 17, 3),
        reason: 'Mesin absensi pulang tidak merespons saat hendak pulang.',
        evidenceName: 'Bukti_mesin_absen.jpg',
        evidenceMeta: 'JPG · 840 KB · 30 Okt 17.10',
        submittedAt: _at(today.subtract(const Duration(days: 4)), 8, 20),
        status: RequestStatus.approved,
        reviewedAt: _at(today.subtract(const Duration(days: 3)), 10, 0),
        decisionNote: 'Disetujui · Dewi Puspita',
      ),
      build(
        email: 'eko@absensi.com',
        eventDate: ekoDate,
        type: CorrectionType.checkIn,
        recordedCheckIn: _at(ekoDate, 8, 45),
        recordedCheckOut: _at(ekoDate, 17, 0),
        proposedCheckIn: _at(ekoDate, 8, 0),
        proposedCheckOut: _at(ekoDate, 17, 0),
        reason: 'Sistem mencatat jam masuk terlambat padahal sudah di kantor.',
        submittedAt: _at(today.subtract(const Duration(days: 6)), 9, 0),
        status: RequestStatus.rejected,
        reviewedAt: _at(today.subtract(const Duration(days: 5)), 11, 30),
        decisionNote: 'Ditolak · Bukti tidak sesuai',
      ),
      build(
        email: 'nanda@absensi.com',
        eventDate: nandaDate,
        type: CorrectionType.both,
        recordedCheckIn: _at(nandaDate, 8, 10),
        recordedCheckOut: null,
        proposedCheckIn: _at(nandaDate, 8, 0),
        proposedCheckOut: _at(nandaDate, 17, 0),
        reason:
            'Mesin absensi bermasalah saat jam pulang dan jam masuk '
            'tercatat tidak sesuai jadwal.',
        evidenceName: 'Foto_mesin_absen.jpg',
        evidenceMeta: 'JPG · 960 KB · 6 Nov 17.05',
        submittedAt: _at(today.subtract(const Duration(days: 2)), 8, 45),
        status: RequestStatus.pending,
      ),
    ];
  }

  static DemoEmployee employeeByEmail(String email) =>
      employees.firstWhere((employee) => employee.email == email);

  static int _balanceFor(String email, int leaveTypeId) {
    final employee = employeeByEmail(email);
    return switch (leaveTypeId) {
      1 => 12 - employee.annualLeaveUsed,
      2 => 3 - employee.permissionUsed,
      3 => 12 - employee.sickUsed,
      _ => 0,
    };
  }

  static int _codeSeed(String email, DateTime date) {
    final employee = employeeByEmail(email);
    return int.parse(
      '${date.year}${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}${employee.nip}',
    );
  }

  static String _code(String prefix, DateTime date, String nip) {
    final compact = dateKey(date).replaceAll('-', '').substring(2);
    return '$prefix-$compact-$nip';
  }

  static DateTime _at(DateTime date, int hour, int minute) =>
      DateTime(date.year, date.month, date.day, hour, minute);
}

class DemoEmployee {
  const DemoEmployee({
    required this.email,
    required this.name,
    required this.nip,
    this.annualLeaveUsed = 0,
    this.permissionUsed = 0,
    this.sickUsed = 0,
  });

  final String email;
  final String name;
  final String nip;
  final int annualLeaveUsed;
  final int permissionUsed;
  final int sickUsed;
}
