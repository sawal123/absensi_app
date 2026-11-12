import '../../core/server_time.dart';

class SalaryProfile {
  const SalaryProfile({
    this.id,
    required this.employeeId,
    this.baseSalary = 0,
    this.overtimeRate = 0,
    this.ptkpStatus = 'TK/0',
    this.npwp = '',
    required this.updatedAt,
  });

  final int? id;
  final int employeeId;

  /// Gaji pokok bulanan dalam rupiah.
  final int baseSalary;

  /// Upah lembur per jam dalam rupiah.
  final int overtimeRate;

  /// Status PTKP untuk perhitungan PPh21, contoh: TK/0, K/1.
  final String ptkpStatus;
  final String npwp;
  final DateTime updatedAt;

  bool get isConfigured => baseSalary > 0;

  SalaryProfile copyWith({
    int? id,
    int? employeeId,
    int? baseSalary,
    int? overtimeRate,
    String? ptkpStatus,
    String? npwp,
    DateTime? updatedAt,
  }) {
    return SalaryProfile(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      baseSalary: baseSalary ?? this.baseSalary,
      overtimeRate: overtimeRate ?? this.overtimeRate,
      ptkpStatus: ptkpStatus ?? this.ptkpStatus,
      npwp: npwp ?? this.npwp,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'base_salary': baseSalary,
      'overtime_rate': overtimeRate,
      'ptkp_status': ptkpStatus,
      'npwp': npwp,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory SalaryProfile.fromMap(Map<String, Object?> map) {
    return SalaryProfile(
      id: (map['id'] as num?)?.toInt(),
      employeeId: (map['employee_id'] as num?)?.toInt() ?? 0,
      baseSalary: (map['base_salary'] as num?)?.toInt() ?? 0,
      overtimeRate: (map['overtime_rate'] as num?)?.toInt() ?? 0,
      ptkpStatus: (map['ptkp_status'] as String?) ?? 'TK/0',
      npwp: (map['npwp'] as String?) ?? '',
      updatedAt: parseServerDate(map['updated_at']) ?? DateTime.now(),
    );
  }
}
