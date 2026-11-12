import 'dart:math' as math;

import '../data/models/attendance.dart';
import '../data/models/leave_request.dart';
import '../data/models/leave_type.dart';
import '../data/models/office_settings.dart';
import '../data/models/payroll_deduction_rule.dart';
import '../data/models/payroll_settings.dart';
import '../data/models/payroll_slip.dart';
import '../data/models/request_status.dart';
import '../data/models/salary_allowance.dart';
import '../data/models/salary_profile.dart';
import '../data/models/user.dart';
import '../data/models/work_shift.dart';
import 'formatters.dart';

class PayrollCalculator {
  const PayrollCalculator();

  PayrollSlip compute({
    required User employee,
    required SalaryProfile? profile,
    required List<SalaryAllowance> allowances,
    required List<PayrollDeductionRule> rules,
    required PayrollSettings settings,
    required OfficeSettings office,
    required List<Attendance> attendance,
    required Map<String, WorkShift> assignments,
    required List<LeaveRequest> approvedLeaves,
    required Map<int, LeaveType> leaveTypes,
    required int year,
    required int month,
    DateTime? asOf,
  }) {
    final baseSalary = profile?.baseSalary ?? 0;
    final overtimeRate = profile?.overtimeRate ?? 0;
    final ptkpStatus = profile?.ptkpStatus ?? 'TK/0';
    final periodStart = DateTime(year, month, 1);
    final periodEnd = endOfMonth(periodStart);
    final cutoff = dateOnly(asOf ?? DateTime.now());
    final absenceEnd = periodEnd.isAfter(cutoff) ? cutoff : periodEnd;
    final workingDays = workingDaysBetween(periodStart, periodEnd);
    final dailyWage = workingDays == 0 ? 0 : (baseSalary / workingDays).round();

    final presentDates = <String>{};
    var lateCount = 0;
    var lateMinutes = 0;
    var overtimeMinutes = 0;

    for (final record in attendance) {
      final day = DateTime.tryParse(record.date);
      if (day == null || day.year != year || day.month != month) continue;
      if (!record.hasCheckedIn) continue;

      presentDates.add(record.date);
      final shift = assignments[record.date];

      final scheduledStart = dateWithTime(
        record.checkInAt!,
        shift?.start ?? office.workStart,
      );
      if (record.checkInAt!.isAfter(scheduledStart)) {
        lateCount++;
        lateMinutes += record.checkInAt!.difference(scheduledStart).inMinutes;
      }

      if (!record.hasCheckedOut) continue;
      var scheduledEnd = dateWithTime(
        record.checkInAt!,
        shift?.end ?? office.workEnd,
      );
      if (shift?.crossDay ?? false) {
        scheduledEnd = scheduledEnd.add(const Duration(days: 1));
      }
      final extra = record.checkOutAt!.difference(scheduledEnd).inMinutes;
      if (extra >= settings.overtimeMinMinutes) {
        overtimeMinutes += extra;
      }
    }

    final paidLeaveDates = <String>{};
    final unpaidLeaveDates = <String>{};
    for (final leave in approvedLeaves) {
      if (leave.status != RequestStatus.approved) continue;
      final type = leaveTypes[leave.leaveTypeId];
      final isPaid = type?.isPaid ?? true;
      var cursor = dateOnly(leave.startDate);
      final end = dateOnly(leave.endDate);
      while (!cursor.isAfter(end)) {
        final isWorkday =
            cursor.weekday != DateTime.saturday &&
            cursor.weekday != DateTime.sunday;
        if (isWorkday && cursor.year == year && cursor.month == month) {
          final key = dateKey(cursor);
          if (isPaid) {
            paidLeaveDates.add(key);
          } else {
            unpaidLeaveDates.add(key);
          }
        }
        cursor = cursor.add(const Duration(days: 1));
      }
    }

    final unpaidLeaveOnly = unpaidLeaveDates.difference(presentDates);
    final paidLeaveOnly = paidLeaveDates.difference(presentDates);
    final unpaidLeaveDays = unpaidLeaveOnly.length;
    final paidLeaveDays = paidLeaveOnly.length;

    var absentDays = 0;
    for (
      var day = periodStart;
      !day.isAfter(absenceEnd);
      day = day.add(const Duration(days: 1))
    ) {
      if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
        continue;
      }
      final key = dateKey(day);
      if (presentDates.contains(key)) continue;
      if (paidLeaveDates.contains(key)) continue;
      if (unpaidLeaveDates.contains(key)) continue;
      absentDays++;
    }

    final overtimePay = settings.overtimeEnabled && overtimeRate > 0
        ? (overtimeMinutes / 60 * overtimeRate).round()
        : 0;

    final earnings = <PayrollLine>[];
    if (baseSalary > 0) {
      earnings.add(PayrollLine(label: 'Gaji pokok', amount: baseSalary));
    }
    for (final allowance in allowances) {
      if (allowance.amount <= 0) continue;
      final perPresentDay = allowance.basis == AllowanceBasis.perPresentDay;
      final amount = perPresentDay
          ? allowance.amount * presentDates.length
          : allowance.amount;
      if (amount <= 0) continue;
      earnings.add(
        PayrollLine(
          label: allowance.name,
          amount: amount,
          detail: perPresentDay
              ? '${presentDates.length} hari × ${formatRupiah(allowance.amount)}'
              : null,
        ),
      );
    }
    if (overtimePay > 0) {
      earnings.add(
        PayrollLine(
          label: 'Lembur',
          amount: overtimePay,
          detail:
              '${formatDurationShort(Duration(minutes: overtimeMinutes))} × '
              '${formatRupiah(overtimeRate)}/jam',
        ),
      );
    }

    final grossEarnings = earnings.fold<int>(
      0,
      (sum, line) => sum + line.amount,
    );

    final deductions = <PayrollLine>[];
    for (final rule in rules) {
      if (!rule.isActive) continue;
      final result = _deductionFor(
        rule,
        lateCount: lateCount,
        lateMinutes: lateMinutes,
        absentDays: absentDays,
        unpaidLeaveDays: unpaidLeaveDays,
        dailyWage: dailyWage,
        baseSalary: baseSalary,
        grossEarnings: grossEarnings,
        ptkpStatus: ptkpStatus,
        settings: settings,
      );
      if (result.amount <= 0) continue;
      deductions.add(
        PayrollLine(
          label: rule.name,
          amount: result.amount,
          detail: result.detail,
        ),
      );
    }

    final totalDeductions = deductions.fold<int>(
      0,
      (sum, line) => sum + line.amount,
    );
    final netPay = math.max(0, grossEarnings - totalDeductions);

    return PayrollSlip(
      employeeId: employee.id ?? 0,
      employeeName: employee.name,
      nip: employee.nip,
      position: employee.position,
      year: year,
      month: month,
      baseSalary: baseSalary,
      earnings: earnings,
      deductions: deductions,
      grossEarnings: grossEarnings,
      totalDeductions: totalDeductions,
      netPay: netPay,
      metrics: PayrollMetrics(
        workingDays: workingDays,
        presentDays: presentDates.length,
        lateCount: lateCount,
        lateMinutes: lateMinutes,
        absentDays: absentDays,
        paidLeaveDays: paidLeaveDays,
        unpaidLeaveDays: unpaidLeaveDays,
        overtimeMinutes: overtimeMinutes,
      ),
    );
  }

  int monthlyPph21({
    required int grossEarnings,
    required int ptkp,
    required List<TaxBracket> brackets,
    int grossMultiplier = 12,
  }) {
    if (grossEarnings <= 0) return 0;
    final annualGross = grossEarnings * grossMultiplier;
    final biayaJabatan = math.min((annualGross * 0.05).round(), 6000000);
    var pkp = annualGross - ptkp - biayaJabatan;
    if (pkp <= 0) return 0;
    pkp = (pkp ~/ 1000) * 1000;

    var tax = 0.0;
    var lower = 0;
    var remaining = pkp;
    for (final bracket in brackets) {
      if (remaining <= 0) break;
      final upper = bracket.limit;
      final span = upper == null ? remaining : upper - lower;
      if (span <= 0) {
        if (upper != null) lower = upper;
        continue;
      }
      final taxable = math.min(remaining, span);
      tax += taxable * bracket.rate / 100;
      remaining -= taxable;
      if (upper != null) lower = upper;
    }
    return (tax / 12).round();
  }

  _Deduction _deductionFor(
    PayrollDeductionRule rule, {
    required int lateCount,
    required int lateMinutes,
    required int absentDays,
    required int unpaidLeaveDays,
    required int dailyWage,
    required int baseSalary,
    required int grossEarnings,
    required String ptkpStatus,
    required PayrollSettings settings,
  }) {
    switch (rule.basis) {
      case DeductionBasis.latePerOccurrence:
        if (lateCount == 0) return const _Deduction(0, null);
        return _Deduction(
          (rule.rate * lateCount).round(),
          '$lateCount kejadian × ${formatRupiah(rule.rate)}',
        );
      case DeductionBasis.latePerMinute:
        if (lateMinutes == 0) return const _Deduction(0, null);
        return _Deduction(
          (rule.rate * lateMinutes).round(),
          '$lateMinutes menit × ${formatRupiah(rule.rate)}',
        );
      case DeductionBasis.absencePerDay:
        if (absentDays == 0) return const _Deduction(0, null);
        return _Deduction(
          (rule.rate * absentDays).round(),
          '$absentDays hari × ${formatRupiah(rule.rate)}',
        );
      case DeductionBasis.absenceDailyWage:
        if (absentDays == 0 || dailyWage == 0) {
          return const _Deduction(0, null);
        }
        final perDay = (dailyWage * rule.rate / 100).round();
        return _Deduction(
          perDay * absentDays,
          '$absentDays hari × ${formatRupiah(perDay)}',
        );
      case DeductionBasis.unpaidLeavePerDay:
        if (unpaidLeaveDays == 0) return const _Deduction(0, null);
        return _Deduction(
          (rule.rate * unpaidLeaveDays).round(),
          '$unpaidLeaveDays hari × ${formatRupiah(rule.rate)}',
        );
      case DeductionBasis.unpaidLeaveDailyWage:
        if (unpaidLeaveDays == 0 || dailyWage == 0) {
          return const _Deduction(0, null);
        }
        final perDay = (dailyWage * rule.rate / 100).round();
        return _Deduction(
          perDay * unpaidLeaveDays,
          '$unpaidLeaveDays hari × ${formatRupiah(perDay)}',
        );
      case DeductionBasis.percentBase:
        if (baseSalary == 0) return const _Deduction(0, null);
        return _Deduction(
          (baseSalary * rule.rate / 100).round(),
          '${_rateText(rule)} dari gaji pokok',
        );
      case DeductionBasis.percentGross:
        if (grossEarnings == 0) return const _Deduction(0, null);
        return _Deduction(
          (grossEarnings * rule.rate / 100).round(),
          '${_rateText(rule)} dari pendapatan bruto',
        );
      case DeductionBasis.fixedMonthly:
        return _Deduction(rule.rate.round(), 'Potongan tetap bulanan');
      case DeductionBasis.pph21:
        final amount = monthlyPph21(
          grossEarnings: grossEarnings,
          ptkp: settings.ptkpFor(ptkpStatus),
          brackets: settings.pph21Brackets,
        );
        if (amount <= 0) return const _Deduction(0, null);
        return _Deduction(amount, 'PTKP $ptkpStatus');
    }
  }

  String _rateText(PayrollDeductionRule rule) {
    if (rule.basis.isPercent) {
      final text = rule.rate == rule.rate.roundToDouble()
          ? rule.rate.toStringAsFixed(0)
          : rule.rate.toStringAsFixed(1);
      return '$text%';
    }
    return formatRupiah(rule.rate);
  }
}

class _Deduction {
  const _Deduction(this.amount, this.detail);

  final int amount;
  final String? detail;
}
