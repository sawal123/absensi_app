import 'dart:convert';

import '../../core/server_time.dart';

class PayrollLine {
  const PayrollLine({required this.label, required this.amount, this.detail});

  final String label;
  final int amount;
  final String? detail;

  Map<String, Object?> toMap() => {
    'label': label,
    'amount': amount,
    'detail': detail,
  };

  factory PayrollLine.fromMap(Map<String, Object?> map) {
    return PayrollLine(
      label: (map['label'] as String?) ?? '',
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      detail: map['detail'] as String?,
    );
  }
}

class PayrollMetrics {
  const PayrollMetrics({
    this.workingDays = 0,
    this.presentDays = 0,
    this.lateCount = 0,
    this.lateMinutes = 0,
    this.absentDays = 0,
    this.paidLeaveDays = 0,
    this.unpaidLeaveDays = 0,
    this.overtimeMinutes = 0,
  });

  final int workingDays;
  final int presentDays;
  final int lateCount;
  final int lateMinutes;
  final int absentDays;
  final int paidLeaveDays;
  final int unpaidLeaveDays;
  final int overtimeMinutes;

  Map<String, Object?> toMap() => {
    'workingDays': workingDays,
    'presentDays': presentDays,
    'lateCount': lateCount,
    'lateMinutes': lateMinutes,
    'absentDays': absentDays,
    'paidLeaveDays': paidLeaveDays,
    'unpaidLeaveDays': unpaidLeaveDays,
    'overtimeMinutes': overtimeMinutes,
  };

  factory PayrollMetrics.fromMap(Map<String, Object?> map) {
    return PayrollMetrics(
      workingDays: (map['workingDays'] as num?)?.toInt() ?? 0,
      presentDays: (map['presentDays'] as num?)?.toInt() ?? 0,
      lateCount: (map['lateCount'] as num?)?.toInt() ?? 0,
      lateMinutes: (map['lateMinutes'] as num?)?.toInt() ?? 0,
      absentDays: (map['absentDays'] as num?)?.toInt() ?? 0,
      paidLeaveDays: (map['paidLeaveDays'] as num?)?.toInt() ?? 0,
      unpaidLeaveDays: (map['unpaidLeaveDays'] as num?)?.toInt() ?? 0,
      overtimeMinutes: (map['overtimeMinutes'] as num?)?.toInt() ?? 0,
    );
  }
}

class PayrollSlip {
  const PayrollSlip({
    this.id,
    required this.employeeId,
    required this.employeeName,
    this.nip = '',
    this.position = '',
    required this.year,
    required this.month,
    this.baseSalary = 0,
    this.earnings = const [],
    this.deductions = const [],
    this.grossEarnings = 0,
    this.totalDeductions = 0,
    this.netPay = 0,
    this.metrics = const PayrollMetrics(),
    this.finalizedAt,
    this.finalizedBy,
  });

  final int? id;
  final int employeeId;
  final String employeeName;
  final String nip;
  final String position;
  final int year;
  final int month;
  final int baseSalary;
  final List<PayrollLine> earnings;
  final List<PayrollLine> deductions;
  final int grossEarnings;
  final int totalDeductions;
  final int netPay;
  final PayrollMetrics metrics;
  final DateTime? finalizedAt;
  final int? finalizedBy;

  bool get isFinalized => finalizedAt != null;

  PayrollSlip copyWith({int? id, DateTime? finalizedAt, int? finalizedBy}) {
    return PayrollSlip(
      id: id ?? this.id,
      employeeId: employeeId,
      employeeName: employeeName,
      nip: nip,
      position: position,
      year: year,
      month: month,
      baseSalary: baseSalary,
      earnings: earnings,
      deductions: deductions,
      grossEarnings: grossEarnings,
      totalDeductions: totalDeductions,
      netPay: netPay,
      metrics: metrics,
      finalizedAt: finalizedAt ?? this.finalizedAt,
      finalizedBy: finalizedBy ?? this.finalizedBy,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'period_year': year,
      'period_month': month,
      'employee_name': employeeName,
      'nip': nip,
      'position': position,
      'base_salary': baseSalary,
      'gross_earnings': grossEarnings,
      'total_deductions': totalDeductions,
      'net_pay': netPay,
      'breakdown': jsonEncode({
        'earnings': [for (final line in earnings) line.toMap()],
        'deductions': [for (final line in deductions) line.toMap()],
        'metrics': metrics.toMap(),
      }),
      'status': isFinalized ? 'final' : 'draft',
      'finalized_by': finalizedBy,
      'finalized_at': (finalizedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  factory PayrollSlip.fromMap(Map<String, Object?> map) {
    final breakdown = _asMap(jsonDecode((map['breakdown'] as String?) ?? '{}'));
    return PayrollSlip(
      id: (map['id'] as num?)?.toInt(),
      employeeId: (map['employee_id'] as num?)?.toInt() ?? 0,
      employeeName: (map['employee_name'] as String?) ?? '',
      nip: (map['nip'] as String?) ?? '',
      position: (map['position'] as String?) ?? '',
      year: (map['period_year'] as num?)?.toInt() ?? 0,
      month: (map['period_month'] as num?)?.toInt() ?? 0,
      baseSalary: (map['base_salary'] as num?)?.toInt() ?? 0,
      earnings: _lines(breakdown['earnings']),
      deductions: _lines(breakdown['deductions']),
      grossEarnings: (map['gross_earnings'] as num?)?.toInt() ?? 0,
      totalDeductions: (map['total_deductions'] as num?)?.toInt() ?? 0,
      netPay: (map['net_pay'] as num?)?.toInt() ?? 0,
      metrics: PayrollMetrics.fromMap(_asMap(breakdown['metrics'])),
      finalizedAt: parseServerDate(map['finalized_at']),
      finalizedBy: (map['finalized_by'] as num?)?.toInt(),
    );
  }

  static List<PayrollLine> _lines(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) PayrollLine.fromMap(Map<String, Object?>.from(item)),
    ];
  }
}

Map<String, Object?> _asMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return Map<String, Object?>.from(value);
  return const <String, Object?>{};
}
