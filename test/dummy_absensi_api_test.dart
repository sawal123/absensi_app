import 'package:absensi/core/formatters.dart';
import 'package:absensi/data/api/absensi_api.dart';
import 'package:absensi/data/api/api_exception.dart';
import 'package:absensi/data/api/dummy_absensi_api.dart';
import 'package:absensi/data/app_database.dart';
import 'package:absensi/data/models/correction_type.dart';
import 'package:absensi/data/models/request_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database raw;
  late DummyAbsensiApi api;
  late int citraId;
  final year = DateTime.now().year;

  setUp(() async {
    raw = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await raw.execute('PRAGMA foreign_keys = ON');
    await AppDatabase.initializeDatabase(raw);
    api = DummyAbsensiApi(
      AppDatabase.withDatabase(raw),
      latency: Duration.zero,
    );

    final rows = await raw.query(
      'users',
      where: 'email = ?',
      whereArgs: ['citra@absensi.com'],
    );
    citraId = (rows.first['id'] as num).toInt();
  });

  tearDown(() async {
    await raw.close();
  });

  test('seeds types, balances, leaves, and corrections', () async {
    expect(await api.getLeaveTypes(), hasLength(3));

    final balances = await api.getLeaveBalances(
      employeeId: citraId,
      year: year,
    );
    expect(balances, hasLength(3));

    final teamLeaves = await api.getTeamLeaveRequests();
    expect(teamLeaves, hasLength(8));
    expect(
      teamLeaves.where((leave) => leave.status == RequestStatus.pending),
      hasLength(4),
    );

    final teamCorrections = await api.getTeamCorrections();
    expect(teamCorrections, hasLength(5));

    final mine = await api.getLeaveRequests(employeeId: citraId);
    expect(mine, hasLength(1));
  });

  test('creates a leave, approves it, and updates the balance', () async {
    final before = await api.getLeaveBalances(
      employeeId: citraId,
      year: year,
    );
    final annualBefore = before
        .firstWhere((balance) => balance.leaveTypeId == 1)
        .remainingDays;

    final date = _nextWeekday(DateTime.now().add(const Duration(days: 21)));
    final created = await api.createLeaveRequest(
      LeaveRequestDraft(
        employeeId: citraId,
        leaveTypeId: 1,
        startDate: date,
        endDate: date,
        reason: 'Acara keluarga besar di luar kota.',
      ),
    );

    expect(created.id, greaterThan(0));
    expect(created.status, RequestStatus.pending);
    expect(created.workingDays, 1);

    final approved = await api.reviewLeaveRequest(
      created.id,
      approve: true,
      note: 'Disetujui',
      reviewerId: 1,
      reviewerName: 'Administrator',
    );
    expect(approved.status, RequestStatus.approved);

    final after = await api.getLeaveBalances(employeeId: citraId, year: year);
    final annualAfter = after
        .firstWhere((balance) => balance.leaveTypeId == 1)
        .remainingDays;
    expect(annualAfter, annualBefore - created.workingDays);
  });

  test('cancels a pending leave and blocks a second cancel', () async {
    final mine = await api.getLeaveRequests(employeeId: citraId);
    final pending = mine.firstWhere(
      (leave) => leave.status == RequestStatus.pending,
    );

    final cancelled = await api.cancelLeaveRequest(
      pending.id,
      employeeId: citraId,
    );
    expect(cancelled.status, RequestStatus.cancelled);

    await expectLater(
      api.cancelLeaveRequest(pending.id, employeeId: citraId),
      throwsA(isA<ApiException>()),
    );
  });

  test('approving a correction updates the attendance row', () async {
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day).subtract(
      const Duration(days: 1),
    );

    final correction = await api.createCorrection(
      CorrectionDraft(
        employeeId: citraId,
        date: date,
        correctionType: CorrectionType.checkOut,
        proposedCheckOut: DateTime(date.year, date.month, date.day, 17, 15),
        reason: 'Lupa absen pulang setelah menyelesaikan pekerjaan.',
      ),
    );
    expect(correction.status, RequestStatus.pending);

    final approved = await api.reviewCorrection(
      correction.id,
      approve: true,
      note: 'Disetujui',
      reviewerId: 1,
      reviewerName: 'Administrator',
    );
    expect(approved.status, RequestStatus.approved);

    final rows = await raw.query(
      'attendance',
      where: 'user_id = ? AND date = ?',
      whereArgs: [citraId, dateKey(date)],
    );
    expect(rows, isNotEmpty);
    expect(rows.first['check_out_at'], isNotNull);
  });
}

DateTime _nextWeekday(DateTime value) {
  var date = DateTime(value.year, value.month, value.day);
  while (date.weekday == DateTime.saturday ||
      date.weekday == DateTime.sunday) {
    date = date.add(const Duration(days: 1));
  }
  return date;
}
