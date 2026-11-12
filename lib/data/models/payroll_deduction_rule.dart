enum DeductionBasis {
  latePerOccurrence('Keterlambatan per kejadian', 'late_per_occurrence'),
  latePerMinute('Keterlambatan per menit', 'late_per_minute'),
  absencePerDay('Absen per hari (nominal)', 'absence_per_day'),
  absenceDailyWage('Absen per hari (gaji harian)', 'absence_daily_wage'),
  unpaidLeavePerDay('Cuti tak dibayar (nominal)', 'unpaid_leave_per_day'),
  unpaidLeaveDailyWage(
    'Cuti tak dibayar (gaji harian)',
    'unpaid_leave_daily_wage',
  ),
  percentBase('Persen gaji pokok', 'percent_base'),
  percentGross('Persen pendapatan bruto', 'percent_gross'),
  fixedMonthly('Nominal tetap per bulan', 'fixed_monthly'),
  pph21('PPh21 progresif', 'pph21');

  const DeductionBasis(this.label, this.apiValue);

  final String label;
  final String apiValue;

  bool get isPercent =>
      this == DeductionBasis.percentBase ||
      this == DeductionBasis.percentGross ||
      this == DeductionBasis.absenceDailyWage ||
      this == DeductionBasis.unpaidLeaveDailyWage;

  bool get isNominal =>
      this == DeductionBasis.latePerOccurrence ||
      this == DeductionBasis.latePerMinute ||
      this == DeductionBasis.absencePerDay ||
      this == DeductionBasis.unpaidLeavePerDay ||
      this == DeductionBasis.fixedMonthly;

  static DeductionBasis fromApi(String? value) {
    for (final basis in DeductionBasis.values) {
      if (basis.apiValue == value) return basis;
    }
    return DeductionBasis.fixedMonthly;
  }
}

class PayrollDeductionRule {
  const PayrollDeductionRule({
    this.id,
    required this.name,
    required this.basis,
    this.rate = 0,
    this.isSystem = false,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final int? id;
  final String name;
  final DeductionBasis basis;

  /// Nominal rupiah atau persen, tergantung [basis].
  final double rate;
  final bool isSystem;
  final bool isActive;
  final int sortOrder;

  PayrollDeductionRule copyWith({
    int? id,
    String? name,
    DeductionBasis? basis,
    double? rate,
    bool? isSystem,
    bool? isActive,
    int? sortOrder,
  }) {
    return PayrollDeductionRule(
      id: id ?? this.id,
      name: name ?? this.name,
      basis: basis ?? this.basis,
      rate: rate ?? this.rate,
      isSystem: isSystem ?? this.isSystem,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'basis': basis.apiValue,
      'rate': rate,
      'is_system': isSystem ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'sort_order': sortOrder,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory PayrollDeductionRule.fromMap(Map<String, Object?> map) {
    return PayrollDeductionRule(
      id: (map['id'] as num?)?.toInt(),
      name: (map['name'] as String?) ?? '',
      basis: DeductionBasis.fromApi(map['basis'] as String?),
      rate: (map['rate'] as num?)?.toDouble() ?? 0,
      isSystem: _asBool(map['is_system']),
      isActive: _asBool(map['is_active'], fallback: true),
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

bool _asBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.toLowerCase();
    return normalized == '1' || normalized == 'true';
  }
  return fallback;
}
