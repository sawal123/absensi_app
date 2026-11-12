import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';

import '../core/formatters.dart';
import '../core/security.dart';
import 'db/database_factory_stub.dart'
    if (dart.library.io) 'db/database_factory_io.dart'
    if (dart.library.js_interop) 'db/database_factory_web.dart';
import 'demo/demo_approvals.dart';
import 'demo/demo_schedule.dart';
import 'models/office_settings.dart';
import 'models/work_shift.dart';

class AppDatabase {
  AppDatabase._();

  /// Dipakai unit test untuk membungkus database in-memory yang sudah
  /// diinisialisasi lewat [initializeDatabase].
  AppDatabase.withDatabase(Database db) : _db = db;

  static final AppDatabase instance = AppDatabase._();

  static const int _version = 6;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = await resolveDatabasePath();
    return databaseFactoryImpl.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await initializeDatabase(db);
  }

  static Future<void> initializeDatabase(Database db) async {
    await _createBaseTables(db);
    await _createApprovalTables(db);
    await _createShiftTables(db);
    await _createPayrollTables(db);
    await _seed(db);
    await _seedApprovals(db);
    await _seedShifts(db);
    await _seedPayroll(db);
    await _seedPayrollDemoAttendance(db);
  }

  static Future<void> _createBaseTables(Database db) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL,
        position TEXT NOT NULL DEFAULT '',
        nip TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        check_in_at TEXT,
        check_in_lat REAL,
        check_in_lng REAL,
        check_in_photo TEXT,
        check_out_at TEXT,
        check_out_lat REAL,
        check_out_lng REAL,
        check_out_photo TEXT,
        note TEXT NOT NULL DEFAULT '',
        UNIQUE(user_id, date),
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_attendance_date ON attendance (date)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE users ADD COLUMN nip TEXT NOT NULL DEFAULT ''",
      );
      await _seed(db);
    }
    if (oldVersion < 3) {
      await _createApprovalTables(db);
      await _seedApprovals(db);
    }
    if (oldVersion < 4) {
      await _createShiftTables(db);
      await _seedShifts(db);
    }
    if (oldVersion < 5) {
      if (!await _hasColumn(db, 'work_shifts', 'color')) {
        await db.execute(
          'ALTER TABLE work_shifts ADD COLUMN color INTEGER NOT NULL DEFAULT 0',
        );
      }
      await _backfillShiftColors(db);
    }
    if (oldVersion < 6) {
      await _createPayrollTables(db);
      await _seedPayroll(db);
      await _seedPayrollDemoAttendance(db);
    }
  }

  static Future<bool> _hasColumn(
    Database db,
    String table,
    String column,
  ) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.any((row) => row['name'] == column);
  }

  static Future<void> _backfillShiftColors(Database db) async {
    final rows = await db.query('work_shifts', orderBy: 'id ASC');
    for (var index = 0; index < rows.length; index++) {
      final id = rows[index]['id'];
      await db.update(
        'work_shifts',
        {
          'color':
              WorkShift.colorPalette[index % WorkShift.colorPalette.length],
        },
        where: 'id = ? AND (color IS NULL OR color = 0)',
        whereArgs: [id],
      );
    }
  }

  static Future<void> _createShiftTables(Database db) async {
    await db.execute('''
      CREATE TABLE work_shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        office TEXT NOT NULL DEFAULT '',
        break_label TEXT,
        cross_day INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        color INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE shift_assignments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        shift_id INTEGER NOT NULL,
        UNIQUE(employee_id, date),
        FOREIGN KEY (employee_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (shift_id) REFERENCES work_shifts (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_shift_assignments_date
      ON shift_assignments (date)
    ''');
    await db.execute('''
      CREATE INDEX idx_shift_assignments_employee
      ON shift_assignments (employee_id)
    ''');
  }

  static Future<void> _createPayrollTables(Database db) async {
    await db.execute('''
      CREATE TABLE salary_profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL UNIQUE,
        base_salary INTEGER NOT NULL DEFAULT 0,
        overtime_rate INTEGER NOT NULL DEFAULT 0,
        ptkp_status TEXT NOT NULL DEFAULT 'TK/0',
        npwp TEXT NOT NULL DEFAULT '',
        updated_at TEXT NOT NULL,
        FOREIGN KEY (employee_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE salary_allowances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        amount INTEGER NOT NULL DEFAULT 0,
        basis TEXT NOT NULL DEFAULT 'monthly',
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (employee_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_salary_allowances_employee
      ON salary_allowances (employee_id)
    ''');

    await db.execute('''
      CREATE TABLE payroll_deduction_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        basis TEXT NOT NULL,
        rate REAL NOT NULL DEFAULT 0,
        is_system INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE payroll_slips (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        period_year INTEGER NOT NULL,
        period_month INTEGER NOT NULL,
        employee_name TEXT NOT NULL,
        nip TEXT NOT NULL DEFAULT '',
        position TEXT NOT NULL DEFAULT '',
        base_salary INTEGER NOT NULL DEFAULT 0,
        gross_earnings INTEGER NOT NULL DEFAULT 0,
        total_deductions INTEGER NOT NULL DEFAULT 0,
        net_pay INTEGER NOT NULL DEFAULT 0,
        breakdown TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'final',
        finalized_by INTEGER,
        finalized_at TEXT NOT NULL,
        UNIQUE(employee_id, period_year, period_month),
        FOREIGN KEY (employee_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_payroll_slips_period
      ON payroll_slips (period_year, period_month)
    ''');
  }

  static Future<void> _createApprovalTables(Database db) async {
    await db.execute('''
      CREATE TABLE leave_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        is_paid INTEGER NOT NULL DEFAULT 1,
        max_days_per_year INTEGER NOT NULL DEFAULT 12
      )
    ''');

    await db.execute('''
      CREATE TABLE leave_balances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        leave_type_id INTEGER NOT NULL,
        year INTEGER NOT NULL,
        entitled_days INTEGER NOT NULL DEFAULT 0,
        used_days INTEGER NOT NULL DEFAULT 0,
        adjustment_days INTEGER NOT NULL DEFAULT 0,
        UNIQUE(employee_id, leave_type_id, year),
        FOREIGN KEY (employee_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (leave_type_id) REFERENCES leave_types (id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE leave_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        employee_id INTEGER NOT NULL,
        employee_name TEXT NOT NULL,
        nip TEXT NOT NULL DEFAULT '',
        team TEXT NOT NULL DEFAULT '',
        leave_type_id INTEGER NOT NULL,
        leave_type_name TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        working_days INTEGER NOT NULL,
        reason TEXT NOT NULL,
        attachment_url TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        reviewer_id INTEGER,
        reviewer_name TEXT NOT NULL DEFAULT '',
        reviewed_at TEXT,
        review_note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        balance_before INTEGER,
        balance_after INTEGER,
        team_available INTEGER NOT NULL DEFAULT 0,
        team_total INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (employee_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_leave_requests_employee
      ON leave_requests (employee_id)
    ''');
    await db.execute('''
      CREATE INDEX idx_leave_requests_status ON leave_requests (status)
    ''');

    await db.execute('''
      CREATE TABLE attendance_corrections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        employee_id INTEGER NOT NULL,
        employee_name TEXT NOT NULL,
        nip TEXT NOT NULL DEFAULT '',
        team TEXT NOT NULL DEFAULT '',
        attendance_id INTEGER,
        date TEXT NOT NULL,
        scheduled_start TEXT NOT NULL DEFAULT '',
        scheduled_end TEXT NOT NULL DEFAULT '',
        recorded_check_in TEXT,
        recorded_check_out TEXT,
        proposed_check_in TEXT,
        proposed_check_out TEXT,
        correction_type TEXT NOT NULL,
        reason TEXT NOT NULL,
        evidence_url TEXT,
        evidence_name TEXT NOT NULL DEFAULT '',
        evidence_meta TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'pending',
        reviewer_id INTEGER,
        reviewer_name TEXT NOT NULL DEFAULT '',
        reviewed_at TEXT,
        review_note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY (employee_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_corrections_employee
      ON attendance_corrections (employee_id)
    ''');
    await db.execute('''
      CREATE INDEX idx_corrections_status ON attendance_corrections (status)
    ''');
  }

  static Future<void> _seed(Database db) async {
    final now = DateTime.now().toIso8601String();

    for (final user in _demoUsers) {
      await db.insert('users', {
        'name': user.name,
        'email': user.email,
        'password_hash': hashPassword(user.password),
        'role': user.role,
        'position': user.position,
        'nip': user.nip,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.update(
        'users',
        {'nip': user.nip},
        where: "email = ? AND (nip IS NULL OR nip = '')",
        whereArgs: [user.email],
      );
    }

    await db.insert('settings', {
      'key': 'office',
      'value': jsonEncode({
        'officeName': 'Kantor Pusat',
        'latitude': -6.200000,
        'longitude': 106.816666,
        'radiusMeters': 100,
        'workStart': '08:00',
        'workEnd': '17:00',
        'earlyCheckInMinutes': 60,
      }),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<void> _seedApprovals(Database db) async {
    final now = DateTime.now();

    for (final type in DemoApprovals.leaveTypes) {
      await db.insert(
        'leave_types',
        type.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    final users = await db.query('users');
    final userIdByEmail = <String, int>{};
    for (final row in users) {
      final email = row['email'] as String?;
      final id = (row['id'] as num?)?.toInt();
      if (email != null && id != null) {
        userIdByEmail[email] = id;
      }
    }

    for (final balance in DemoApprovals.leaveBalances(now, userIdByEmail)) {
      final map = balance.toMap()..remove('id');
      await db.insert(
        'leave_balances',
        map,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    for (final leave in DemoApprovals.leaves(now, userIdByEmail)) {
      await db.insert(
        'leave_requests',
        leave.toInsertMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    for (final correction in DemoApprovals.corrections(now, userIdByEmail)) {
      await db.insert(
        'attendance_corrections',
        correction.toInsertMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  static Future<void> _seedShifts(Database db) async {
    final shiftRows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM work_shifts',
    );
    final shiftCount = (shiftRows.first['total'] as num?)?.toInt() ?? 0;
    if (shiftCount == 0) {
      final now = DateTime.now().toIso8601String();
      for (final shift in _demoShifts) {
        await db.insert('work_shifts', {...shift, 'created_at': now});
      }
    }

    final assignmentRows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM shift_assignments',
    );
    final assignmentCount =
        (assignmentRows.first['total'] as num?)?.toInt() ?? 0;
    if (assignmentCount > 0) return;

    final shifts = await db.query('work_shifts');
    final shiftIdByName = <String, int>{
      for (final row in shifts)
        (row['name'] as String): (row['id'] as num).toInt(),
    };

    final employees = await db.query(
      'users',
      where: 'role = ?',
      whereArgs: ['employee'],
    );
    if (employees.isEmpty) return;

    final now = dateOnly(DateTime.now());
    final start = startOfWeek(now).subtract(const Duration(days: 14));
    final end = startOfWeek(now).add(const Duration(days: 70));
    const settings = OfficeSettings();

    for (final employee in employees) {
      final employeeId = (employee['id'] as num).toInt();
      var cursor = start;
      while (!cursor.isAfter(end)) {
        final shift = DemoSchedule.shiftFor(cursor, settings);
        final shiftId = shift == null ? null : shiftIdByName[shift.name];
        if (shiftId != null) {
          await db.insert('shift_assignments', {
            'employee_id': employeeId,
            'date': dateKey(cursor),
            'shift_id': shiftId,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        cursor = cursor.add(const Duration(days: 1));
      }
    }
  }

  static Future<void> _seedPayroll(Database db) async {
    final now = DateTime.now().toIso8601String();

    final ruleRows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM payroll_deduction_rules',
    );
    final ruleCount = (ruleRows.first['total'] as num?)?.toInt() ?? 0;
    if (ruleCount == 0) {
      var order = 0;
      for (final rule in _demoDeductionRules) {
        await db.insert('payroll_deduction_rules', {
          ...rule,
          'sort_order': order++,
          'updated_at': now,
        });
      }
    }

    final settingsRows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['payroll'],
      limit: 1,
    );
    if (settingsRows.isEmpty) {
      await db.insert('settings', {
        'key': 'payroll',
        'value': jsonEncode({
          'overtimeEnabled': true,
          'overtimeMinMinutes': 30,
          'ptkp': {
            'TK/0': 54000000,
            'TK/1': 58500000,
            'TK/2': 63000000,
            'TK/3': 67500000,
            'K/0': 58500000,
            'K/1': 63000000,
            'K/2': 67500000,
            'K/3': 72000000,
          },
          'pph21Brackets': [
            {'limit': 60000000, 'rate': 5},
            {'limit': 250000000, 'rate': 15},
            {'limit': 500000000, 'rate': 25},
            {'limit': 5000000000, 'rate': 30},
            {'limit': null, 'rate': 35},
          ],
        }),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    final employees = await db.query(
      'users',
      where: 'role = ?',
      whereArgs: ['employee'],
    );
    for (final employee in employees) {
      final employeeId = (employee['id'] as num).toInt();

      final profileRows = await db.query(
        'salary_profiles',
        where: 'employee_id = ?',
        whereArgs: [employeeId],
        limit: 1,
      );
      if (profileRows.isEmpty) {
        await db.insert('salary_profiles', {
          'employee_id': employeeId,
          'base_salary': 5000000,
          'overtime_rate': 30000,
          'ptkp_status': 'TK/0',
          'npwp': '',
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      final allowanceRows = await db.query(
        'salary_allowances',
        where: 'employee_id = ?',
        whereArgs: [employeeId],
        limit: 1,
      );
      if (allowanceRows.isEmpty) {
        await db.insert('salary_allowances', {
          'employee_id': employeeId,
          'name': 'Tunjangan jabatan',
          'amount': 500000,
          'basis': 'monthly',
          'sort_order': 0,
        });
        await db.insert('salary_allowances', {
          'employee_id': employeeId,
          'name': 'Uang makan',
          'amount': 25000,
          'basis': 'per_present_day',
          'sort_order': 1,
        });
        await db.insert('salary_allowances', {
          'employee_id': employeeId,
          'name': 'Transport',
          'amount': 20000,
          'basis': 'per_present_day',
          'sort_order': 2,
        });
      }
    }
  }

  /// Data demo untuk bulan lalu agar slip gaji tidak menampilkan semua absen.
  /// Hanya mengisi karyawan yang belum punya absensi pada bulan tersebut.
  static Future<void> _seedPayrollDemoAttendance(Database db) async {
    final today = dateOnly(DateTime.now());
    final periodStart = DateTime(today.year, today.month - 1, 1);
    final periodEnd = endOfMonth(periodStart);

    final employees = await db.query(
      'users',
      where: 'role = ?',
      whereArgs: ['employee'],
    );
    if (employees.isEmpty) return;

    final settingsRows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['office'],
      limit: 1,
    );
    if (settingsRows.isEmpty) return;
    final settings = OfficeSettings.fromMap(
      jsonDecode(settingsRows.first['value'] as String) as Map<String, Object?>,
    );

    final leaveRows = await db.query(
      'leave_requests',
      where: 'status = ? AND start_date <= ? AND end_date >= ?',
      whereArgs: ['approved', dateKey(periodEnd), dateKey(periodStart)],
    );
    final leavesByEmployee = <int, List<(DateTime, DateTime)>>{};
    for (final row in leaveRows) {
      final employeeId = (row['employee_id'] as num?)?.toInt();
      final start = DateTime.tryParse('${row['start_date']}');
      final end = DateTime.tryParse('${row['end_date']}');
      if (employeeId == null || start == null || end == null) continue;
      leavesByEmployee.putIfAbsent(employeeId, () => []).add((
        dateOnly(start),
        dateOnly(end),
      ));
    }

    bool onLeave(int employeeId, DateTime day) {
      final ranges = leavesByEmployee[employeeId];
      if (ranges == null) return false;
      for (final range in ranges) {
        if (!day.isBefore(range.$1) && !day.isAfter(range.$2)) return true;
      }
      return false;
    }

    const lateOffsets = [0, 5, 12, 20, 3, 0, 15];

    for (final employee in employees) {
      final employeeId = (employee['id'] as num).toInt();
      final existing = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM attendance '
        'WHERE user_id = ? AND date BETWEEN ? AND ?',
        [employeeId, dateKey(periodStart), dateKey(periodEnd)],
      );
      if (((existing.first['total'] as num?)?.toInt() ?? 0) > 0) continue;

      var skipUsed = false;
      for (
        var day = periodStart;
        !day.isAfter(periodEnd);
        day = day.add(const Duration(days: 1))
      ) {
        if (day.weekday == DateTime.saturday ||
            day.weekday == DateTime.sunday) {
          continue;
        }
        if (onLeave(employeeId, day)) continue;
        if (!skipUsed && day.weekday == DateTime.tuesday && day.day >= 8) {
          skipUsed = true;
          continue;
        }

        final shift = DemoSchedule.shiftFor(day, settings);
        if (shift == null) continue;

        final scheduledStart = dateWithTime(day, shift.start);
        var scheduledEnd = dateWithTime(day, shift.end);
        if (!scheduledEnd.isAfter(scheduledStart)) {
          scheduledEnd = scheduledEnd.add(const Duration(days: 1));
        }
        final lateMinutes = lateOffsets[(day.day - 1) % lateOffsets.length];
        final checkIn = scheduledStart.add(Duration(minutes: lateMinutes));
        final checkOut = scheduledEnd.add(
          Duration(minutes: 10 + (day.day % 5) * 9),
        );

        await db.insert('attendance', {
          'user_id': employeeId,
          'date': dateKey(day),
          'check_in_at': checkIn.toIso8601String(),
          'check_out_at': checkOut.toIso8601String(),
          'note': 'Data demo penggajian',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
  }

  static const _demoDeductionRules = <Map<String, Object?>>[
    {
      'name': 'Keterlambatan',
      'basis': 'late_per_occurrence',
      'rate': 25000,
      'is_system': 0,
      'is_active': 1,
    },
    {
      'name': 'Absen tanpa keterangan',
      'basis': 'absence_daily_wage',
      'rate': 100,
      'is_system': 0,
      'is_active': 1,
    },
    {
      'name': 'Cuti tidak dibayar',
      'basis': 'unpaid_leave_daily_wage',
      'rate': 100,
      'is_system': 0,
      'is_active': 1,
    },
    {
      'name': 'BPJS Kesehatan',
      'basis': 'percent_gross',
      'rate': 1,
      'is_system': 0,
      'is_active': 1,
    },
    {
      'name': 'BPJS JHT',
      'basis': 'percent_gross',
      'rate': 2,
      'is_system': 0,
      'is_active': 1,
    },
    {
      'name': 'BPJS JP',
      'basis': 'percent_gross',
      'rate': 1,
      'is_system': 0,
      'is_active': 1,
    },
    {
      'name': 'PPh21',
      'basis': 'pph21',
      'rate': 0,
      'is_system': 1,
      'is_active': 1,
    },
  ];

  static const _demoShifts = <Map<String, Object?>>[
    {
      'name': 'Reguler',
      'start_time': '08:00',
      'end_time': '17:00',
      'office': 'Kantor Pusat',
      'break_label': 'Istirahat 12.00 – 13.00',
      'cross_day': 0,
      'is_active': 1,
      'color': 0xFF2563EB,
    },
    {
      'name': 'Pagi',
      'start_time': '06:00',
      'end_time': '14:00',
      'office': 'Kantor Pusat',
      'break_label': 'Istirahat 10.00 – 10.30',
      'cross_day': 0,
      'is_active': 1,
      'color': 0xFFB45309,
    },
    {
      'name': 'Shift malam',
      'start_time': '22:00',
      'end_time': '06:00',
      'office': 'Kantor Pusat',
      'break_label': null,
      'cross_day': 1,
      'is_active': 1,
      'color': 0xFF4F46E5,
    },
  ];

  static const _demoUsers = [
    (
      name: 'Administrator',
      email: 'admin@absensi.com',
      role: 'admin',
      position: 'Atasan',
      nip: '0210',
      password: 'admin123',
    ),
    (
      name: 'Aditya Pratama',
      email: 'aditya@absensi.com',
      role: 'employee',
      position: 'Tim Operasional',
      nip: '0248',
      password: '123456',
    ),
    (
      name: 'Budi Santoso',
      email: 'budi@absensi.com',
      role: 'employee',
      position: 'Tim Operasional',
      nip: '0251',
      password: '123456',
    ),
    (
      name: 'Citra Lestari',
      email: 'citra@absensi.com',
      role: 'employee',
      position: 'Tim Operasional',
      nip: '0256',
      password: '123456',
    ),
    (
      name: 'Dimas Prakoso',
      email: 'dimas@absensi.com',
      role: 'employee',
      position: 'Tim Operasional',
      nip: '0260',
      password: '123456',
    ),
    (
      name: 'Eko Saputra',
      email: 'eko@absensi.com',
      role: 'employee',
      position: 'Tim Operasional',
      nip: '0262',
      password: '123456',
    ),
    (
      name: 'Fajar Ramadhan',
      email: 'fajar@absensi.com',
      role: 'employee',
      position: 'Tim Operasional',
      nip: '0265',
      password: '123456',
    ),
    (
      name: 'Rina Wulandari',
      email: 'rina@absensi.com',
      role: 'employee',
      position: 'Tim Operasional',
      nip: '0268',
      password: '123456',
    ),
    (
      name: 'Nanda Putri',
      email: 'nanda@absensi.com',
      role: 'employee',
      position: 'Tim Operasional',
      nip: '0271',
      password: '123456',
    ),
  ];
}
