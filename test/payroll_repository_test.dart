import 'package:absensi/data/app_database.dart';
import 'package:absensi/data/models/payroll_deduction_rule.dart';
import 'package:absensi/data/models/payroll_slip.dart';
import 'package:absensi/data/models/salary_allowance.dart';
import 'package:absensi/data/repositories/payroll_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database raw;
  late PayrollRepository repository;
  late int employeeId;

  setUp(() async {
    raw = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await raw.execute('PRAGMA foreign_keys = ON');
    await AppDatabase.initializeDatabase(raw);
    repository = PayrollRepository(AppDatabase.withDatabase(raw));

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

  test('seeds payroll profiles, allowances, rules, and settings', () async {
    final profile = await repository.getProfile(employeeId);
    expect(profile, isNotNull);
    expect(profile!.baseSalary, 5000000);
    expect(profile.overtimeRate, 30000);

    final allowances = await repository.getAllowancesFor(employeeId);
    expect(allowances, hasLength(3));
    expect(
      allowances.map((allowance) => allowance.name),
      containsAll(['Tunjangan jabatan', 'Uang makan', 'Transport']),
    );

    final rules = await repository.getRules();
    expect(rules, hasLength(7));
    final pph21 = rules.firstWhere(
      (rule) => rule.basis == DeductionBasis.pph21,
    );
    expect(pph21.isSystem, isTrue);

    final settings = await repository.getSettings();
    expect(settings.overtimeEnabled, isTrue);
    expect(settings.ptkpFor('TK/0'), 54000000);
    expect(settings.pph21Brackets, isNotEmpty);
  });

  test('updates a salary profile and replaces allowances', () async {
    final profile = (await repository.getProfile(employeeId))!;
    await repository.saveProfile(profile.copyWith(baseSalary: 6500000));
    expect((await repository.getProfile(employeeId))!.baseSalary, 6500000);

    await repository.replaceAllowances(employeeId, const [
      SalaryAllowance(
        employeeId: 0,
        name: 'Tunjangan transport',
        amount: 300000,
        basis: AllowanceBasis.perPresentDay,
      ),
    ]);
    final replaced = await repository.getAllowancesFor(employeeId);
    expect(replaced, hasLength(1));
    expect(replaced.first.name, 'Tunjangan transport');
    expect(replaced.first.sortOrder, 0);

    await repository.replaceAllowances(employeeId, const []);
    expect(await repository.getAllowancesFor(employeeId), isEmpty);
  });

  test('creates, updates, and deletes a custom deduction rule', () async {
    final created = await repository.saveRule(
      const PayrollDeductionRule(
        name: 'Potongan kasbon',
        basis: DeductionBasis.fixedMonthly,
        rate: 150000,
        sortOrder: 10,
      ),
    );
    expect(created.id, isNotNull);

    final rules = await repository.getRules();
    expect(rules, hasLength(8));

    await repository.saveRule(created.copyWith(isActive: false));
    final updated = (await repository.getRules()).firstWhere(
      (rule) => rule.id == created.id,
    );
    expect(updated.isActive, isFalse);

    await repository.deleteRule(created.id!);
    expect(await repository.getRules(), hasLength(7));
  });

  test('refuses to delete a system deduction rule', () async {
    final pph21 = (await repository.getRules()).firstWhere(
      (rule) => rule.isSystem,
    );
    await expectLater(
      repository.deleteRule(pph21.id!),
      throwsA(isA<StateError>()),
    );
    expect(await repository.getRules(), hasLength(7));
  });

  test('saves payroll slips as an upsert per employee and period', () async {
    final slip = PayrollSlip(
      employeeId: employeeId,
      employeeName: 'Budi Santoso',
      nip: '0251',
      position: 'Tim Operasional',
      year: 2026,
      month: 11,
      baseSalary: 5000000,
      earnings: const [PayrollLine(label: 'Gaji pokok', amount: 5000000)],
      deductions: const [
        PayrollLine(
          label: 'Keterlambatan',
          amount: 50000,
          detail: '2 kejadian',
        ),
      ],
      grossEarnings: 5000000,
      totalDeductions: 50000,
      netPay: 4950000,
      metrics: const PayrollMetrics(
        workingDays: 21,
        presentDays: 19,
        lateCount: 2,
        lateMinutes: 17,
        absentDays: 1,
        paidLeaveDays: 1,
      ),
      finalizedAt: DateTime(2026, 12, 1),
      finalizedBy: 1,
    );

    await repository.saveSlip(slip);
    final saved = await repository.getSlip(employeeId, 2026, 11);
    expect(saved, isNotNull);
    expect(saved!.netPay, 4950000);
    expect(saved.isFinalized, isTrue);
    expect(saved.earnings, hasLength(1));
    expect(saved.deductions.first.label, 'Keterlambatan');
    expect(saved.metrics.presentDays, 19);

    final updated = PayrollSlip(
      employeeId: employeeId,
      employeeName: 'Budi Santoso',
      nip: '0251',
      position: 'Tim Operasional',
      year: 2026,
      month: 11,
      baseSalary: 5000000,
      earnings: const [PayrollLine(label: 'Gaji pokok', amount: 5000000)],
      deductions: const [PayrollLine(label: 'Keterlambatan', amount: 25000)],
      grossEarnings: 5000000,
      totalDeductions: 25000,
      netPay: 4975000,
      finalizedAt: DateTime(2026, 12, 2),
      finalizedBy: 1,
    );
    await repository.saveSlip(updated);

    final slips = await repository.getSlips(2026, 11);
    expect(slips, hasLength(1));
    expect(slips.first.netPay, 4975000);

    await repository.deleteSlips(2026, 11);
    expect(await repository.getSlips(2026, 11), isEmpty);
  });
}
