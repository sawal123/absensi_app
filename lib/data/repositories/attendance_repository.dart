import 'package:sqflite_common/sqlite_api.dart';

import '../app_database.dart';
import '../models/attendance.dart';

class AttendanceRepository {
  AttendanceRepository(this._db);

  final AppDatabase _db;

  Future<Attendance?> getForDate(int userId, String date) async {
    final db = await _db.database;
    final rows = await db.query(
      'attendance',
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, date],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Attendance.fromMap(rows.first);
  }

  Future<List<Attendance>> getHistory(int userId, {int limit = 90}) async {
    final db = await _db.database;
    final rows = await db.query(
      'attendance',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date DESC',
      limit: limit,
    );
    return rows.map(Attendance.fromMap).toList();
  }

  Future<List<Attendance>> getForDateAllUsers(String date) async {
    final db = await _db.database;
    final rows = await db.query(
      'attendance',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'check_in_at ASC',
    );
    return rows.map(Attendance.fromMap).toList();
  }

  Future<List<Attendance>> getRange(DateTime from, DateTime to) async {
    final db = await _db.database;
    final rows = await db.query(
      'attendance',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [_key(from), _key(to)],
      orderBy: 'date DESC',
    );
    return rows.map(Attendance.fromMap).toList();
  }

  Future<List<Attendance>> getForUserRange(
    int userId,
    DateTime from,
    DateTime to,
  ) async {
    final db = await _db.database;
    final rows = await db.query(
      'attendance',
      where: 'user_id = ? AND date BETWEEN ? AND ?',
      whereArgs: [userId, _key(from), _key(to)],
      orderBy: 'date ASC',
    );
    return rows.map(Attendance.fromMap).toList();
  }

  Future<Attendance> saveCheckIn(Attendance record) async {
    final db = await _db.database;
    final id = await db.insert(
      'attendance',
      record.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return record.copyWith(id: id);
  }

  Future<Attendance> saveCheckOut(Attendance record) async {
    final db = await _db.database;
    await db.update(
      'attendance',
      record.toMap()..remove('id'),
      where: 'user_id = ? AND date = ?',
      whereArgs: [record.userId, record.date],
    );
    return record;
  }

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
