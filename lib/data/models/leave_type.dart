class LeaveType {
  const LeaveType({
    required this.id,
    required this.name,
    required this.isPaid,
    required this.maxDaysPerYear,
  });

  final int id;
  final String name;
  final bool isPaid;
  final int maxDaysPerYear;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'is_paid': isPaid ? 1 : 0,
      'max_days_per_year': maxDaysPerYear,
    };
  }

  factory LeaveType.fromMap(Map<String, Object?> map) {
    return LeaveType(
      id: (map['id'] as num?)?.toInt() ?? 0,
      name: (map['name'] as String?) ?? '',
      isPaid: _asBool(map['is_paid']),
      maxDaysPerYear:
          (map['max_days_per_year'] as num?)?.toInt() ??
          (map['max_days'] as num?)?.toInt() ??
          0,
    );
  }

  factory LeaveType.fromJson(Map<String, Object?> json) =>
      LeaveType.fromMap(json);

  Map<String, Object?> toJson() => toMap();
}

bool _asBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.toLowerCase();
    return normalized == '1' || normalized == 'true';
  }
  return false;
}
