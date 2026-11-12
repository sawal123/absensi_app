import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';

import '../../core/formatters.dart';
import '../app_database.dart';
import '../models/attendance.dart';
import '../models/attendance_correction.dart';
import '../models/leave_balance.dart';
import '../models/leave_request.dart';
import '../models/leave_type.dart';
import '../models/office_settings.dart';
import '../models/request_status.dart';
import 'absensi_api.dart';
import 'api_exception.dart';

/// Dummy backend backed by the local SQLite database.
///
/// Every method mirrors the shape of the future Laravel API so the provider
/// layer does not need to change when `USE_DUMMY_API=false`.
class DummyAbsensiApi implements AbsensiApi {
  DummyAbsensiApi(
    this._database, {
    this.latency = const Duration(milliseconds: 250),
  });

  final AppDatabase _database;
  final Duration latency;

  Future<Database> get _db => _database.database;

  Future<void> _wait() async {
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }
  }

  @override
  Future<List<LeaveType>> getLeaveTypes() async {
    await _wait();
    final db = await _db;
    final rows = await db.query('leave_types', orderBy: 'id ASC');
    return rows
        .map((row) => LeaveType.fromMap(Map<String, Object?>.from(row)))
        .toList();
  }

  @override
  Future<List<LeaveBalance>> getLeaveBalances({
    required int employeeId,
    required int year,
  }) async {
    await _wait();
    final db = await _db;
    final rows = await db.query(
      'leave_balances',
      where: 'employee_id = ? AND year = ?',
      whereArgs: [employeeId, year],
      orderBy: 'leave_type_id ASC',
    );
    return rows
        .map((row) => LeaveBalance.fromMap(Map<String, Object?>.from(row)))
        .toList();
  }

  @override
  Future<List<LeaveRequest>> getLeaveRequests({
    required int employeeId,
    int? year,
  }) async {
    await _wait();
    final db = await _db;
    final rows = await db.query(
      'leave_requests',
      where: year == null
          ? 'employee_id = ?'
          : 'employee_id = ? AND substr(start_date, 1, 4) = ?',
      whereArgs: year == null
          ? [employeeId]
          : [employeeId, year.toString()],
      orderBy: 'created_at DESC',
    );
    return rows.map(_leaveFromRow).toList();
  }

  @override
  Future<LeaveRequest> createLeaveRequest(LeaveRequestDraft draft) async {
    await _wait();
    final start = dateOnly(draft.startDate);
    final end = dateOnly(draft.endDate);

    if (end.isBefore(start)) {
      throw ApiException('Tanggal selesai harus setelah tanggal mulai.');
    }

    final days = workingDaysBetween(start, end);
    if (days <= 0) {
      throw ApiException('Rentang tanggal tidak memiliki hari kerja.');
    }
    if (draft.reason.trim().isEmpty) {
      throw ApiException('Alasan pengajuan wajib diisi.');
    }

    final db = await _db;
    final typeRows = await db.query(
      'leave_types',
      where: 'id = ?',
      whereArgs: [draft.leaveTypeId],
      limit: 1,
    );
    if (typeRows.isEmpty) {
      throw ApiException('Jenis cuti tidak ditemukan.');
    }
    final type = LeaveType.fromMap(
      Map<String, Object?>.from(typeRows.first),
    );

    final balance = await _balance(
      db,
      employeeId: draft.employeeId,
      leaveTypeId: draft.leaveTypeId,
      year: start.year,
    );
    if (balance == null) {
      throw ApiException('Saldo cuti belum tersedia untuk tahun ini.');
    }
    if (balance.remainingDays < days) {
      throw ApiException(
        'Saldo cuti tidak mencukupi. Sisa ${balance.remainingDays} hari.',
      );
    }

    final user = await _user(db, draft.employeeId);
    if (user == null) {
      throw ApiException('Karyawan tidak ditemukan.');
    }

    final stats = await _teamStats(db, start);
    final code = await _uniqueCode('CT', start, user.nip, db);

    final request = LeaveRequest(
      id: 0,
      employeeId: draft.employeeId,
      code: code,
      employeeName: user.name,
      nip: user.nip,
      team: user.position,
      leaveTypeId: type.id,
      type: type.name,
      startDate: start,
      endDate: end,
      workingDays: days,
      reason: draft.reason.trim(),
      attachmentUrl: draft.attachmentUrl,
      submittedAt: DateTime.now(),
      status: RequestStatus.pending,
      balanceRemaining: balance.remainingDays,
      balanceRequested: days,
      balanceAfter: balance.remainingDays - days,
      teamAvailable: stats.$1,
      teamTotal: stats.$2,
    );

    final id = await db.insert('leave_requests', request.toInsertMap());
    return _leaveById(id);
  }

  @override
  Future<LeaveRequest> cancelLeaveRequest(
    int id, {
    required int employeeId,
  }) async {
    await _wait();
    final db = await _db;
    final request = await _leaveOrNull(db, id);
    if (request == null) {
      throw ApiException('Pengajuan cuti tidak ditemukan.');
    }
    if (request.employeeId != employeeId) {
      throw ApiException('Pengajuan ini bukan milik Anda.');
    }
    if (!request.status.isPending) {
      throw ApiException('Hanya pengajuan menunggu yang dapat dibatalkan.');
    }

    await db.update(
      'leave_requests',
      {'status': RequestStatus.cancelled.apiValue},
      where: 'id = ?',
      whereArgs: [id],
    );
    return _leaveById(id);
  }

  @override
  Future<List<LeaveRequest>> getTeamLeaveRequests({
    RequestStatus? status,
  }) async {
    await _wait();
    final db = await _db;
    final rows = await db.query(
      'leave_requests',
      where: status == null ? null : 'status = ?',
      whereArgs: status == null ? null : [status.apiValue],
      orderBy: 'created_at DESC',
    );
    return rows.map(_leaveFromRow).toList();
  }

  @override
  Future<LeaveRequest> reviewLeaveRequest(
    int id, {
    required bool approve,
    String note = '',
    int? reviewerId,
    String reviewerName = '',
  }) async {
    await _wait();
    final db = await _db;
    final request = await _leaveOrNull(db, id);
    if (request == null) {
      throw ApiException('Pengajuan cuti tidak ditemukan.');
    }
    if (!request.status.isPending) {
      throw ApiException('Pengajuan ini sudah ditinjau.');
    }
    if (!approve && note.trim().isEmpty) {
      throw ApiException('Catatan wajib diisi saat menolak pengajuan.');
    }

    final reviewedAt = DateTime.now();
    final reviewer = reviewerName.isEmpty ? 'Atasan' : reviewerName;

    if (approve) {
      final balance = await _balance(
        db,
        employeeId: request.employeeId,
        leaveTypeId: request.leaveTypeId,
        year: request.startDate.year,
      );
      if (balance == null) {
        throw ApiException('Saldo cuti tidak ditemukan.');
      }
      if (balance.remainingDays < request.workingDays) {
        throw ApiException(
          'Saldo cuti tidak mencukupi. Sisa ${balance.remainingDays} hari.',
        );
      }

      await db.update(
        'leave_balances',
        {'used_days': balance.usedDays + request.workingDays},
        where: 'id = ?',
        whereArgs: [balance.id],
      );

      await db.update(
        'leave_requests',
        {
          'status': RequestStatus.approved.apiValue,
          'reviewer_id': reviewerId,
          'reviewer_name': reviewer,
          'reviewed_at': reviewedAt.toIso8601String(),
          'review_note': note.trim(),
          'balance_before': balance.remainingDays,
          'balance_after': balance.remainingDays - request.workingDays,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      await db.update(
        'leave_requests',
        {
          'status': RequestStatus.rejected.apiValue,
          'reviewer_id': reviewerId,
          'reviewer_name': reviewer,
          'reviewed_at': reviewedAt.toIso8601String(),
          'review_note': note.trim(),
          'balance_before': request.balanceRemaining,
          'balance_after': request.balanceRemaining,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    return _leaveById(id);
  }

  @override
  Future<List<AttendanceCorrection>> getCorrections({
    required int employeeId,
  }) async {
    await _wait();
    final db = await _db;
    final rows = await db.query(
      'attendance_corrections',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'created_at DESC',
    );
    return rows.map(_correctionFromRow).toList();
  }

  @override
  Future<AttendanceCorrection> createCorrection(CorrectionDraft draft) async {
    await _wait();
    if (draft.proposedCheckIn == null && draft.proposedCheckOut == null) {
      throw ApiException('Isi minimal satu jam yang ingin diperbaiki.');
    }
    if (draft.reason.trim().isEmpty) {
      throw ApiException('Alasan perbaikan wajib diisi.');
    }

    final eventDate = dateOnly(draft.date);
    if (eventDate.isAfter(dateOnly(DateTime.now()))) {
      throw ApiException('Perbaikan hanya untuk tanggal yang sudah berjalan.');
    }

    final db = await _db;
    final user = await _user(db, draft.employeeId);
    if (user == null) {
      throw ApiException('Karyawan tidak ditemukan.');
    }

    final attendance = await _attendanceForDate(
      db,
      employeeId: draft.employeeId,
      date: eventDate,
    );
    final settings = await _officeSettings(db);
    final code = await _uniqueCode('PA', eventDate, user.nip, db);
    final evidenceUrl = draft.evidenceUrl;

    final correction = AttendanceCorrection(
      id: 0,
      employeeId: draft.employeeId,
      code: code,
      employeeName: user.name,
      nip: user.nip,
      team: user.position,
      attendanceId: attendance?.id,
      date: eventDate,
      scheduledStart: settings.workStart,
      scheduledEnd: settings.workEnd,
      recordedCheckIn: attendance?.checkInAt,
      recordedCheckOut: attendance?.checkOutAt,
      proposedCheckIn: draft.proposedCheckIn,
      proposedCheckOut: draft.proposedCheckOut,
      correctionType: draft.correctionType,
      reason: draft.reason.trim(),
      evidenceUrl: evidenceUrl,
      evidenceName: _fileName(evidenceUrl),
      evidenceMeta: evidenceUrl == null ? '' : 'Lampiran lokal',
      submittedAt: DateTime.now(),
      status: RequestStatus.pending,
    );

    final id = await db.insert(
      'attendance_corrections',
      correction.toInsertMap(),
    );
    return _correctionById(id);
  }

  @override
  Future<AttendanceCorrection> cancelCorrection(
    int id, {
    required int employeeId,
  }) async {
    await _wait();
    final db = await _db;
    final correction = await _correctionOrNull(db, id);
    if (correction == null) {
      throw ApiException('Pengajuan perbaikan tidak ditemukan.');
    }
    if (correction.employeeId != employeeId) {
      throw ApiException('Pengajuan ini bukan milik Anda.');
    }
    if (!correction.status.isPending) {
      throw ApiException('Hanya pengajuan menunggu yang dapat dibatalkan.');
    }

    await db.update(
      'attendance_corrections',
      {'status': RequestStatus.cancelled.apiValue},
      where: 'id = ?',
      whereArgs: [id],
    );
    return _correctionById(id);
  }

  @override
  Future<List<AttendanceCorrection>> getTeamCorrections({
    RequestStatus? status,
  }) async {
    await _wait();
    final db = await _db;
    final rows = await db.query(
      'attendance_corrections',
      where: status == null ? null : 'status = ?',
      whereArgs: status == null ? null : [status.apiValue],
      orderBy: 'created_at DESC',
    );
    return rows.map(_correctionFromRow).toList();
  }

  @override
  Future<AttendanceCorrection> reviewCorrection(
    int id, {
    required bool approve,
    String note = '',
    int? reviewerId,
    String reviewerName = '',
  }) async {
    await _wait();
    final db = await _db;
    final correction = await _correctionOrNull(db, id);
    if (correction == null) {
      throw ApiException('Pengajuan perbaikan tidak ditemukan.');
    }
    if (!correction.status.isPending) {
      throw ApiException('Pengajuan ini sudah ditinjau.');
    }
    if (!approve && note.trim().isEmpty) {
      throw ApiException('Catatan wajib diisi saat menolak pengajuan.');
    }

    final reviewedAt = DateTime.now();
    final reviewer = reviewerName.isEmpty ? 'Atasan' : reviewerName;
    int? attendanceId = correction.attendanceId;

    if (approve) {
      attendanceId = await _applyCorrection(db, correction);
    }

    await db.update(
      'attendance_corrections',
      {
        'status': approve
            ? RequestStatus.approved.apiValue
            : RequestStatus.rejected.apiValue,
        'reviewer_id': reviewerId,
        'reviewer_name': reviewer,
        'reviewed_at': reviewedAt.toIso8601String(),
        'review_note': note.trim(),
        'attendance_id': attendanceId,
        if (approve) 'recorded_check_in':
            correction.proposedCheckIn?.toIso8601String(),
        if (approve) 'recorded_check_out':
            correction.proposedCheckOut?.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    return _correctionById(id);
  }

  Future<int> _applyCorrection(
    Database db,
    AttendanceCorrection correction,
  ) async {
    final date = dateKey(correction.date);
    final existing = await _attendanceForDate(
      db,
      employeeId: correction.employeeId,
      date: correction.date,
    );
    final note = _appendNote(existing?.note ?? '', correction.code);

    if (existing != null) {
      await db.update(
        'attendance',
        {
          if (correction.proposedCheckIn != null)
            'check_in_at': correction.proposedCheckIn!.toIso8601String(),
          if (correction.proposedCheckOut != null)
            'check_out_at': correction.proposedCheckOut!.toIso8601String(),
          'note': note,
        },
        where: 'id = ?',
        whereArgs: [existing.id],
      );
      return existing.id!;
    }

    final record = Attendance(
      userId: correction.employeeId,
      date: date,
      checkInAt: correction.proposedCheckIn,
      checkOutAt: correction.proposedCheckOut,
      note: note,
    );
    return db.insert('attendance', record.toMap()..remove('id'));
  }

  String _appendNote(String current, String code) {
    final suffix = 'Diperbaiki dari pengajuan $code';
    if (current.trim().isEmpty) return suffix;
    return '$current · $suffix';
  }

  Future<Attendance?> _attendanceForDate(
    Database db, {
    required int employeeId,
    required DateTime date,
  }) async {
    final rows = await db.query(
      'attendance',
      where: 'user_id = ? AND date = ?',
      whereArgs: [employeeId, dateKey(date)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Attendance.fromMap(Map<String, Object?>.from(rows.first));
  }

  Future<LeaveBalance?> _balance(
    Database db, {
    required int employeeId,
    required int leaveTypeId,
    required int year,
  }) async {
    final rows = await db.query(
      'leave_balances',
      where: 'employee_id = ? AND leave_type_id = ? AND year = ?',
      whereArgs: [employeeId, leaveTypeId, year],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LeaveBalance.fromMap(Map<String, Object?>.from(rows.first));
  }

  Future<_UserRow?> _user(Database db, int id) async {
    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return _UserRow(
      name: (row['name'] as String?) ?? '',
      nip: (row['nip'] as String?) ?? '',
      position: (row['position'] as String?) ?? '',
    );
  }

  Future<OfficeSettings> _officeSettings(Database db) async {
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['office'],
      limit: 1,
    );
    if (rows.isEmpty) return const OfficeSettings();
    final decoded = jsonDecode(rows.first['value'] as String);
    return OfficeSettings.fromMap(Map<String, Object?>.from(decoded as Map));
  }

  Future<(int, int)> _teamStats(Database db, DateTime date) async {
    final countRows = await db.rawQuery(
      "SELECT COUNT(*) AS total FROM users WHERE role = 'employee'",
    );
    final total = (countRows.first['total'] as num?)?.toInt() ?? 0;

    final approved = await db.query(
      'leave_requests',
      where: 'status = ?',
      whereArgs: [RequestStatus.approved.apiValue],
    );
    var onLeave = 0;
    for (final row in approved) {
      final leave = _leaveFromRow(row);
      if (leave.employeeId != 0 && leave.covers(date)) onLeave++;
    }
    final available = (total - onLeave).clamp(0, total);
    return (available, total);
  }

  Future<String> _uniqueCode(
    String prefix,
    DateTime date,
    String nip,
    Database db,
  ) async {
    final table = prefix == 'CT' ? 'leave_requests' : 'attendance_corrections';
    final compact = dateKey(date).replaceAll('-', '').substring(2);
    final base = '$prefix-$compact-$nip';

    var code = base;
    var suffix = 1;
    while (true) {
      final rows = await db.query(
        table,
        columns: ['id'],
        where: 'code = ?',
        whereArgs: [code],
        limit: 1,
      );
      if (rows.isEmpty) return code;
      suffix++;
      code = '$base-$suffix';
    }
  }

  String _fileName(String? url) {
    if (url == null || url.isEmpty) return '';
    final parts = url.split('/');
    return parts.isEmpty ? url : parts.last;
  }

  Future<LeaveRequest?> _leaveOrNull(Database db, int id) async {
    final rows = await db.query(
      'leave_requests',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _leaveFromRow(rows.first);
  }

  Future<LeaveRequest> _leaveById(int id) async {
    final db = await _db;
    final leave = await _leaveOrNull(db, id);
    if (leave == null) {
      throw ApiException('Pengajuan cuti tidak ditemukan.');
    }
    return leave;
  }

  Future<AttendanceCorrection?> _correctionOrNull(
    Database db,
    int id,
  ) async {
    final rows = await db.query(
      'attendance_corrections',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _correctionFromRow(rows.first);
  }

  Future<AttendanceCorrection> _correctionById(int id) async {
    final db = await _db;
    final correction = await _correctionOrNull(db, id);
    if (correction == null) {
      throw ApiException('Pengajuan perbaikan tidak ditemukan.');
    }
    return correction;
  }

  LeaveRequest _leaveFromRow(Map<String, Object?> row) =>
      LeaveRequest.fromMap(Map<String, Object?>.from(row));

  AttendanceCorrection _correctionFromRow(Map<String, Object?> row) =>
      AttendanceCorrection.fromMap(Map<String, Object?>.from(row));
}

class _UserRow {
  const _UserRow({
    required this.name,
    required this.nip,
    required this.position,
  });

  final String name;
  final String nip;
  final String position;
}
