import 'package:absensi/core/formatters.dart';
import 'package:absensi/core/payroll_calculator.dart';
import 'package:absensi/data/models/attendance.dart';
import 'package:absensi/data/models/leave_request.dart';
import 'package:absensi/data/models/leave_type.dart';
import 'package:absensi/data/models/office_settings.dart';
import 'package:absensi/data/models/payroll_deduction_rule.dart';
import 'package:absensi/data/models/payroll_settings.dart';
import 'package:absensi/data/models/payroll_slip.dart';
import 'package:absensi/data/models/request_status.dart';
import 'package:absensi/data/models/salary_allowance.dart';
import 'package:absensi/data/models/salary_profile.dart';
import 'package:absensi/data/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = PayrollCalculator();

  User employee() => User(
    id: 1,
    name: 'Budi Santoso',
    email: 'budi@absensi.com',
    passwordHash: 'hash',
    role: 'employee',
    position: 'Tim Operasional',
    nip: '0251',
    createdAt: DateTime(2026, 1, 1),
  );

  SalaryProfile profile({
    int baseSalary = 5000000,
    int overtimeRate = 30000,
    String ptkpStatus = 'TK/0',
  }) {
    return SalaryProfile(
      employeeId: 1,
      baseSalary: baseSalary,
      overtimeRate: overtimeRate,
      ptkpStatus: ptkpStatus,
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  List<SalaryAllowance> allowances() => const [
    SalaryAllowance(
      employeeId: 1,
      name: 'Tunjangan jabatan',
      amount: 500000,
      basis: AllowanceBasis.monthly,
      sortOrder: 0,
    ),
    SalaryAllowance(
      employeeId: 1,
      name: 'Uang makan',
      amount: 25000,
      basis: AllowanceBasis.perPresentDay,
      sortOrder: 1,
    ),
  ];

  List<PayrollDeductionRule> rules() => const [
    PayrollDeductionRule(
      name: 'Keterlambatan',
      basis: DeductionBasis.latePerOccurrence,
      rate: 25000,
      sortOrder: 0,
    ),
    PayrollDeductionRule(
      name: 'Absen tanpa keterangan',
      basis: DeductionBasis.absenceDailyWage,
      rate: 100,
      sortOrder: 1,
    ),
    PayrollDeductionRule(
      name: 'Cuti tidak dibayar',
      basis: DeductionBasis.unpaidLeaveDailyWage,
      rate: 100,
      sortOrder: 2,
    ),
    PayrollDeductionRule(
      name: 'BPJS Kesehatan',
      basis: DeductionBasis.percentGross,
      rate: 1,
      sortOrder: 3,
    ),
    PayrollDeductionRule(
      name: 'BPJS JHT',
      basis: DeductionBasis.percentGross,
      rate: 2,
      sortOrder: 4,
    ),
    PayrollDeductionRule(
      name: 'BPJS JP',
      basis: DeductionBasis.percentGross,
      rate: 1,
      sortOrder: 5,
    ),
    PayrollDeductionRule(
      name: 'PPh21',
      basis: DeductionBasis.pph21,
      isSystem: true,
      sortOrder: 6,
    ),
  ];

  Map<int, LeaveType> leaveTypes() => const {
    1: LeaveType(id: 1, name: 'Cuti tahunan', isPaid: true, maxDaysPerYear: 12),
    2: LeaveType(id: 2, name: 'Izin', isPaid: false, maxDaysPerYear: 3),
  };

  LeaveRequest approvedLeave({
    required int typeId,
    required DateTime start,
    required DateTime end,
    required int workingDays,
  }) {
    return LeaveRequest(
      id: 1,
      employeeId: 1,
      code: 'CT-261117-0251',
      employeeName: 'Budi Santoso',
      nip: '0251',
      team: 'Tim Operasional',
      leaveTypeId: typeId,
      type: typeId == 1 ? 'Cuti tahunan' : 'Izin',
      startDate: start,
      endDate: end,
      workingDays: workingDays,
      reason: 'Keperluan keluarga.',
      submittedAt: DateTime(2026, 11, 10),
      status: RequestStatus.approved,
    );
  }

  List<Attendance> attendanceNovember() {
    final records = <Attendance>[];
    const lateMinutes = {'2026-11-03': 12, '2026-11-04': 5};

    for (
      var day = DateTime(2026, 11, 1);
      !day.isAfter(DateTime(2026, 11, 30));
      day = day.add(const Duration(days: 1))
    ) {
      if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
        continue;
      }
      final key = dateKey(day);
      if (key == '2026-11-16' || key == '2026-11-17') continue;

      final offset = lateMinutes[key] ?? 0;
      final overtime = key == '2026-11-02';
      records.add(
        Attendance(
          userId: 1,
          date: key,
          checkInAt: DateTime(day.year, day.month, day.day, 8, offset),
          checkOutAt: overtime
              ? DateTime(day.year, day.month, day.day, 18)
              : DateTime(day.year, day.month, day.day, 17, 15),
        ),
      );
    }
    return records;
  }

  int amountOf(List<PayrollLine> lines, String label) {
    return lines.firstWhere((line) => line.label == label).amount;
  }

  test('menghitung gaji bersih lengkap dari absensi dan cuti', () {
    final slip = calculator.compute(
      employee: employee(),
      profile: profile(),
      allowances: allowances(),
      rules: rules(),
      settings: PayrollSettings.defaults(),
      office: const OfficeSettings(),
      attendance: attendanceNovember(),
      assignments: const {},
      approvedLeaves: [
        approvedLeave(
          typeId: 1,
          start: DateTime(2026, 11, 17),
          end: DateTime(2026, 11, 17),
          workingDays: 1,
        ),
      ],
      leaveTypes: leaveTypes(),
      year: 2026,
      month: 11,
      asOf: DateTime(2026, 12, 1),
    );

    expect(slip.metrics.workingDays, 21);
    expect(slip.metrics.presentDays, 19);
    expect(slip.metrics.lateCount, 2);
    expect(slip.metrics.lateMinutes, 17);
    expect(slip.metrics.absentDays, 1);
    expect(slip.metrics.paidLeaveDays, 1);
    expect(slip.metrics.unpaidLeaveDays, 0);
    expect(slip.metrics.overtimeMinutes, 60);

    expect(slip.baseSalary, 5000000);
    expect(slip.grossEarnings, 6005000);
    expect(amountOf(slip.earnings, 'Gaji pokok'), 5000000);
    expect(amountOf(slip.earnings, 'Tunjangan jabatan'), 500000);
    expect(amountOf(slip.earnings, 'Uang makan'), 475000);
    expect(amountOf(slip.earnings, 'Lembur'), 30000);

    expect(amountOf(slip.deductions, 'Keterlambatan'), 50000);
    expect(amountOf(slip.deductions, 'Absen tanpa keterangan'), 238095);
    expect(amountOf(slip.deductions, 'BPJS Kesehatan'), 60050);
    expect(amountOf(slip.deductions, 'BPJS JHT'), 120100);
    expect(amountOf(slip.deductions, 'BPJS JP'), 60050);
    expect(amountOf(slip.deductions, 'PPh21'), 60238);
    expect(slip.totalDeductions, 588533);
    expect(slip.netPay, 5416467);
  });

  test('cuti tidak dibayar memotong gaji harian sesuai jumlah hari', () {
    final slip = calculator.compute(
      employee: employee(),
      profile: profile(baseSalary: 4200000, overtimeRate: 0),
      allowances: const [],
      rules: const [
        PayrollDeductionRule(
          name: 'Cuti tidak dibayar',
          basis: DeductionBasis.unpaidLeaveDailyWage,
          rate: 100,
        ),
      ],
      settings: PayrollSettings.defaults(),
      office: const OfficeSettings(),
      attendance: const [],
      assignments: const {},
      approvedLeaves: [
        approvedLeave(
          typeId: 2,
          start: DateTime(2026, 11, 17),
          end: DateTime(2026, 11, 18),
          workingDays: 2,
        ),
      ],
      leaveTypes: leaveTypes(),
      year: 2026,
      month: 11,
      asOf: DateTime(2026, 12, 1),
    );

    expect(slip.metrics.unpaidLeaveDays, 2);
    expect(slip.metrics.paidLeaveDays, 0);
    expect(slip.metrics.absentDays, 19);
    expect(amountOf(slip.deductions, 'Cuti tidak dibayar'), 400000);
    expect(slip.grossEarnings, 4200000);
    expect(slip.netPay, 3800000);
  });

  test('tidak menghitung hari kerja yang belum lewat sebagai absen', () {
    final slip = calculator.compute(
      employee: employee(),
      profile: profile(),
      allowances: const [],
      rules: const [],
      settings: PayrollSettings.defaults(),
      office: const OfficeSettings(),
      attendance: const [],
      assignments: const {},
      approvedLeaves: const [],
      leaveTypes: leaveTypes(),
      year: 2026,
      month: 11,
      asOf: DateTime(2026, 11, 10),
    );

    expect(slip.metrics.workingDays, 21);
    expect(slip.metrics.absentDays, 7);
  });

  test('PPh21 lebih rendah saat PTKP lebih besar', () {
    final tk0 = calculator.monthlyPph21(
      grossEarnings: 6005000,
      ptkp: PayrollSettings.defaultPtkp['TK/0']!,
      brackets: PayrollSettings.defaultBrackets,
    );
    final k3 = calculator.monthlyPph21(
      grossEarnings: 6005000,
      ptkp: PayrollSettings.defaultPtkp['K/3']!,
      brackets: PayrollSettings.defaultBrackets,
    );

    expect(tk0, 60238);
    expect(k3, 0);
    expect(k3, lessThan(tk0));
  });

  test('profil gaji kosong tetap menghasilkan slip tanpa nilai', () {
    final slip = calculator.compute(
      employee: employee(),
      profile: null,
      allowances: const [],
      rules: rules(),
      settings: PayrollSettings.defaults(),
      office: const OfficeSettings(),
      attendance: const [],
      assignments: const {},
      approvedLeaves: const [],
      leaveTypes: leaveTypes(),
      year: 2026,
      month: 11,
      asOf: DateTime(2026, 12, 1),
    );

    expect(slip.baseSalary, 0);
    expect(slip.grossEarnings, 0);
    expect(slip.totalDeductions, 0);
    expect(slip.netPay, 0);
    expect(slip.metrics.workingDays, 21);
    expect(slip.metrics.absentDays, 21);
  });
}
