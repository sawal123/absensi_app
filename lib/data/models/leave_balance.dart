class LeaveBalance {
  const LeaveBalance({
    required this.id,
    required this.employeeId,
    required this.leaveTypeId,
    required this.year,
    required this.entitledDays,
    required this.usedDays,
    required this.adjustmentDays,
  });

  final int id;
  final int employeeId;
  final int leaveTypeId;
  final int year;
  final int entitledDays;
  final int usedDays;
  final int adjustmentDays;

  int get remainingDays => entitledDays - usedDays + adjustmentDays;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'leave_type_id': leaveTypeId,
      'year': year,
      'entitled_days': entitledDays,
      'used_days': usedDays,
      'adjustment_days': adjustmentDays,
    };
  }

  factory LeaveBalance.fromMap(Map<String, Object?> map) {
    return LeaveBalance(
      id: (map['id'] as num?)?.toInt() ?? 0,
      employeeId: (map['employee_id'] as num?)?.toInt() ?? 0,
      leaveTypeId: (map['leave_type_id'] as num?)?.toInt() ?? 0,
      year: (map['year'] as num?)?.toInt() ?? DateTime.now().year,
      entitledDays: (map['entitled_days'] as num?)?.toInt() ?? 0,
      usedDays: (map['used_days'] as num?)?.toInt() ?? 0,
      adjustmentDays: (map['adjustment_days'] as num?)?.toInt() ?? 0,
    );
  }

  factory LeaveBalance.fromJson(Map<String, Object?> json) =>
      LeaveBalance.fromMap(json);

  Map<String, Object?> toJson() {
    return {
      ...toMap(),
      'remaining_days': remainingDays,
    };
  }

  LeaveBalance copyWith({
    int? entitledDays,
    int? usedDays,
    int? adjustmentDays,
  }) {
    return LeaveBalance(
      id: id,
      employeeId: employeeId,
      leaveTypeId: leaveTypeId,
      year: year,
      entitledDays: entitledDays ?? this.entitledDays,
      usedDays: usedDays ?? this.usedDays,
      adjustmentDays: adjustmentDays ?? this.adjustmentDays,
    );
  }
}
