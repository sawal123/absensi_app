import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';

import '../app_database.dart';
import '../models/payroll_deduction_rule.dart';
import '../models/payroll_settings.dart';
import '../models/payroll_slip.dart';
import '../models/salary_allowance.dart';
import '../models/salary_profile.dart';

class PayrollRepository {
  PayrollRepository(this._db);

  final AppDatabase _db;

  static const _settingsKey = 'payroll';

  Future<List<SalaryProfile>> getProfiles() async {
    final db = await _db.database;
    final rows = await db.query('salary_profiles', orderBy: 'employee_id ASC');
    return rows.map(SalaryProfile.fromMap).toList();
  }

  Future<SalaryProfile?> getProfile(int employeeId) async {
    final db = await _db.database;
    final rows = await db.query(
      'salary_profiles',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SalaryProfile.fromMap(rows.first);
  }

  Future<void> saveProfile(SalaryProfile profile) async {
    final db = await _db.database;
    final map = profile.toMap()..remove('id');
    final existing = await db.query(
      'salary_profiles',
      where: 'employee_id = ?',
      whereArgs: [profile.employeeId],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert('salary_profiles', map);
    } else {
      await db.update(
        'salary_profiles',
        map,
        where: 'employee_id = ?',
        whereArgs: [profile.employeeId],
      );
    }
  }

  Future<List<SalaryAllowance>> getAllowances() async {
    final db = await _db.database;
    final rows = await db.query(
      'salary_allowances',
      orderBy: 'employee_id ASC, sort_order ASC, id ASC',
    );
    return rows.map(SalaryAllowance.fromMap).toList();
  }

  Future<List<SalaryAllowance>> getAllowancesFor(int employeeId) async {
    final db = await _db.database;
    final rows = await db.query(
      'salary_allowances',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map(SalaryAllowance.fromMap).toList();
  }

  Future<void> replaceAllowances(
    int employeeId,
    List<SalaryAllowance> items,
  ) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete(
        'salary_allowances',
        where: 'employee_id = ?',
        whereArgs: [employeeId],
      );
      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        await txn.insert('salary_allowances', {
          'employee_id': employeeId,
          'name': item.name,
          'amount': item.amount,
          'basis': item.basis.apiValue,
          'sort_order': index,
        });
      }
    });
  }

  Future<List<PayrollDeductionRule>> getRules() async {
    final db = await _db.database;
    final rows = await db.query(
      'payroll_deduction_rules',
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map(PayrollDeductionRule.fromMap).toList();
  }

  Future<PayrollDeductionRule> saveRule(PayrollDeductionRule rule) async {
    final db = await _db.database;
    final map = rule.toMap()..remove('id');
    if (rule.id == null) {
      final id = await db.insert('payroll_deduction_rules', map);
      return rule.copyWith(id: id);
    }
    await db.update(
      'payroll_deduction_rules',
      map,
      where: 'id = ?',
      whereArgs: [rule.id],
    );
    return rule;
  }

  Future<void> deleteRule(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      'payroll_deduction_rules',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    if ((rows.first['is_system'] as num?)?.toInt() == 1) {
      throw StateError('Komponen bawaan tidak bisa dihapus.');
    }
    await db.delete(
      'payroll_deduction_rules',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<PayrollSettings> getSettings() async {
    final db = await _db.database;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [_settingsKey],
      limit: 1,
    );
    if (rows.isEmpty) return PayrollSettings.defaults();
    final raw = rows.first['value'] as String;
    return PayrollSettings.fromMap(jsonDecode(raw) as Map<String, Object?>);
  }

  Future<void> saveSettings(PayrollSettings settings) async {
    final db = await _db.database;
    await db.insert('settings', {
      'key': _settingsKey,
      'value': jsonEncode(settings.toMap()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<PayrollSlip?> getSlip(int employeeId, int year, int month) async {
    final db = await _db.database;
    final rows = await db.query(
      'payroll_slips',
      where: 'employee_id = ? AND period_year = ? AND period_month = ?',
      whereArgs: [employeeId, year, month],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PayrollSlip.fromMap(rows.first);
  }

  Future<List<PayrollSlip>> getSlips(int year, int month) async {
    final db = await _db.database;
    final rows = await db.query(
      'payroll_slips',
      where: 'period_year = ? AND period_month = ?',
      whereArgs: [year, month],
      orderBy: 'employee_name ASC',
    );
    return rows.map(PayrollSlip.fromMap).toList();
  }

  Future<void> saveSlip(PayrollSlip slip) async {
    final db = await _db.database;
    await db.insert(
      'payroll_slips',
      slip.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSlips(int year, int month) async {
    final db = await _db.database;
    await db.delete(
      'payroll_slips',
      where: 'period_year = ? AND period_month = ?',
      whereArgs: [year, month],
    );
  }
}
