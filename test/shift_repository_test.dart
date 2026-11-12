import 'package:absensi/core/formatters.dart';
import 'package:absensi/data/app_database.dart';
import 'package:absensi/data/models/office_settings.dart';
import 'package:absensi/data/models/work_shift.dart';
import 'package:absensi/data/repositories/shift_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database raw;
  late ShiftRepository repository;
  late int employeeId;

  setUp(() async {
    raw = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await raw.execute('PRAGMA foreign_keys = ON');
    await AppDatabase.initializeDatabase(raw);
    repository = ShiftRepository(AppDatabase.withDatabase(raw));

    final rows = await raw.query(
      'users',
      where: 'email = ?',
      whereArgs: ['budi@absensi.com'],
    );
    employeeId = (rows.first['id'] as num).toInt();
  });

  tearDown(() async {
    await raw.close();
  });

  test('seeds shift templates including a cross-day night shift', () async {
    final shifts = await repository.getShifts();
    expect(
      shifts.map((shift) => shift.name),
      containsAll(['Reguler', 'Pagi', 'Shift malam']),
    );

    final night = shifts.firstWhere((shift) => shift.name == 'Shift malam');
    expect(night.crossDay, isTrue);
    expect(night.hours, 8);

    final colors = shifts.map((shift) => shift.resolvedColorValue).toSet();
    expect(colors, hasLength(shifts.length));
    expect(colors.every(WorkShift.colorPalette.contains), isTrue);
  });

  test('seeds a roster for the current period', () async {
    final date = startOfWeek(DateTime.now()).add(const Duration(days: 7));
    final shift = await repository.getShiftForEmployee(employeeId, date);
    expect(shift, isNotNull);
  });

  test('creates, updates, assigns, and deletes a shift', () async {
    final created = await repository.createShift(
      const WorkShift(
        name: 'Sore',
        start: '14:00',
        end: '22:00',
        office: 'Kantor Pusat',
      ),
    );
    expect(created.id, isNotNull);
    expect(WorkShift.colorPalette.contains(created.resolvedColorValue), isTrue);

    await repository.updateShift(created.copyWith(name: 'Sore kedua'));
    expect((await repository.getShift(created.id!))!.name, 'Sore kedua');

    final date = dateOnly(DateTime.now());
    await repository.assignShift(
      employeeId: employeeId,
      date: date,
      shiftId: created.id,
    );
    expect(
      (await repository.getShiftForEmployee(employeeId, date))!.name,
      'Sore kedua',
    );

    final mine = await repository.getEmployeeAssignments(
      employeeId,
      from: date,
      to: date,
    );
    expect(mine[dateKey(date)]!.name, 'Sore kedua');

    final all = await repository.getAllAssignments(from: date, to: date);
    expect(all['$employeeId|${dateKey(date)}']!.name, 'Sore kedua');

    await repository.assignShift(
      employeeId: employeeId,
      date: date,
      shiftId: null,
    );
    expect(await repository.getShiftForEmployee(employeeId, date), isNull);

    await repository.deleteShift(created.id!);
    expect(await repository.getShift(created.id!), isNull);
  });

  test('assigns one shift to many dates at once and clears them', () async {
    final start = dateOnly(DateTime.now()).add(const Duration(days: 3));
    final dates = [for (var i = 0; i < 10; i++) start.add(Duration(days: i))];
    final morning = (await repository.getShifts()).firstWhere(
      (shift) => shift.name == 'Pagi',
    );

    await repository.assignShiftDates(
      employeeId: employeeId,
      dates: dates,
      shiftId: morning.id,
    );

    final assigned = await repository.getEmployeeAssignments(
      employeeId,
      from: dates.first,
      to: dates.last,
    );
    expect(assigned, hasLength(10));
    expect(assigned.values.every((shift) => shift.name == 'Pagi'), isTrue);

    await repository.assignShiftDates(
      employeeId: employeeId,
      dates: dates,
      shiftId: null,
    );
    final cleared = await repository.getEmployeeAssignments(
      employeeId,
      from: dates.first,
      to: dates.last,
    );
    expect(cleared, isEmpty);
  });

  test('keeps an explicitly chosen shift color', () async {
    const chosen = 0xFFDB2777;
    final created = await repository.createShift(
      const WorkShift(
        name: 'Sore',
        start: '14:00',
        end: '22:00',
        colorValue: chosen,
      ),
    );
    expect(created.resolvedColorValue, chosen);
    expect((await repository.getShift(created.id!))!.colorValue, chosen);
  });

  test('office settings default the early check-in window to 60 minutes', () {
    expect(const OfficeSettings().earlyCheckInMinutes, 60);
    expect(
      OfficeSettings.fromMap(const <String, Object?>{}).earlyCheckInMinutes,
      60,
    );
    expect(
      OfficeSettings.fromMap(const <String, Object?>{'earlyCheckInMinutes': 90})
          .earlyCheckInMinutes,
      90,
    );
  });
}
