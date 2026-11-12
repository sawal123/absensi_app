import 'package:sqflite_common/sqlite_api.dart';

import '../../core/formatters.dart';
import '../app_database.dart';
import '../models/work_shift.dart';

class ShiftRepository {
  ShiftRepository(this._db);

  final AppDatabase _db;

  Future<List<WorkShift>> getShifts() async {
    final db = await _db.database;
    final rows = await db.query(
      'work_shifts',
      orderBy: 'start_time ASC, name ASC',
    );
    return rows
        .map((row) => WorkShift.fromMap(Map<String, Object?>.from(row)))
        .toList();
  }

  Future<WorkShift?> getShift(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      'work_shifts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return WorkShift.fromMap(Map<String, Object?>.from(rows.first));
  }

  Future<WorkShift> createShift(WorkShift shift) async {
    final db = await _db.database;
    final resolved = shift.colorValue == 0
        ? await _withNextColor(db, shift)
        : shift;
    final id = await db.insert('work_shifts', {
      ...resolved.toMap()..remove('id'),
      'created_at': DateTime.now().toIso8601String(),
    });
    return resolved.copyWith(id: id);
  }

  Future<WorkShift> _withNextColor(Database db, WorkShift shift) async {
    final rows = await db.query('work_shifts', columns: ['color']);
    final used = {for (final row in rows) (row['color'] as num?)?.toInt() ?? 0};
    for (final color in WorkShift.colorPalette) {
      if (!used.contains(color)) return shift.copyWith(colorValue: color);
    }
    final fallback =
        WorkShift.colorPalette[rows.length % WorkShift.colorPalette.length];
    return shift.copyWith(colorValue: fallback);
  }

  Future<void> updateShift(WorkShift shift) async {
    final db = await _db.database;
    await db.update(
      'work_shifts',
      shift.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [shift.id],
    );
  }

  Future<void> deleteShift(int id) async {
    final db = await _db.database;
    await db.delete('work_shifts', where: 'id = ?', whereArgs: [id]);
  }

  /// [shiftId] null berarti karyawan libur pada tanggal tersebut.
  Future<void> assignShift({
    required int employeeId,
    required DateTime date,
    int? shiftId,
  }) {
    return assignShiftDates(
      employeeId: employeeId,
      dates: [date],
      shiftId: shiftId,
    );
  }

  /// Menetapkan shift yang sama ke banyak tanggal sekaligus.
  /// [shiftId] null menghapus plotting (libur) pada tanggal-tanggal tersebut.
  Future<void> assignShiftDates({
    required int employeeId,
    required Iterable<DateTime> dates,
    int? shiftId,
  }) async {
    final db = await _db.database;
    final uniqueKeys = {for (final date in dates) dateKey(date)};
    if (uniqueKeys.isEmpty) return;

    await db.transaction((txn) async {
      for (final key in uniqueKeys) {
        if (shiftId == null) {
          await txn.delete(
            'shift_assignments',
            where: 'employee_id = ? AND date = ?',
            whereArgs: [employeeId, key],
          );
        } else {
          await txn.insert('shift_assignments', {
            'employee_id': employeeId,
            'date': key,
            'shift_id': shiftId,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  Future<WorkShift?> getShiftForEmployee(int employeeId, DateTime date) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT s.*
      FROM shift_assignments a
      JOIN work_shifts s ON s.id = a.shift_id
      WHERE a.employee_id = ? AND a.date = ?
      LIMIT 1
    ''',
      [employeeId, dateKey(date)],
    );
    if (rows.isEmpty) return null;
    return WorkShift.fromMap(Map<String, Object?>.from(rows.first));
  }

  /// Peta [dateKey] -> shift untuk satu karyawan dalam rentang tanggal.
  Future<Map<String, WorkShift>> getEmployeeAssignments(
    int employeeId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT a.date AS assigned_date, s.*
      FROM shift_assignments a
      JOIN work_shifts s ON s.id = a.shift_id
      WHERE a.employee_id = ? AND a.date BETWEEN ? AND ?
      ORDER BY a.date ASC
    ''',
      [employeeId, dateKey(from), dateKey(to)],
    );

    return {
      for (final row in rows)
        (row['assigned_date'] as String): WorkShift.fromMap(
          Map<String, Object?>.from(row),
        ),
    };
  }

  /// Peta `"employeeId|dateKey"` -> shift untuk seluruh karyawan.
  Future<Map<String, WorkShift>> getAllAssignments({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT a.employee_id AS employee_id, a.date AS assigned_date, s.*
      FROM shift_assignments a
      JOIN work_shifts s ON s.id = a.shift_id
      WHERE a.date BETWEEN ? AND ?
      ORDER BY a.date ASC
    ''',
      [dateKey(from), dateKey(to)],
    );

    return {
      for (final row in rows)
        '${row['employee_id']}|${row['assigned_date']}': WorkShift.fromMap(
          Map<String, Object?>.from(row),
        ),
    };
  }
}
