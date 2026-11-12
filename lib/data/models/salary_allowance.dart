enum AllowanceBasis {
  monthly('Bulanan', 'monthly'),
  perPresentDay('Per hari hadir', 'per_present_day');

  const AllowanceBasis(this.label, this.apiValue);

  final String label;
  final String apiValue;

  static AllowanceBasis fromApi(String? value) {
    for (final basis in AllowanceBasis.values) {
      if (basis.apiValue == value) return basis;
    }
    return AllowanceBasis.monthly;
  }
}

class SalaryAllowance {
  const SalaryAllowance({
    this.id,
    required this.employeeId,
    required this.name,
    this.amount = 0,
    this.basis = AllowanceBasis.monthly,
    this.sortOrder = 0,
  });

  final int? id;
  final int employeeId;
  final String name;
  final int amount;
  final AllowanceBasis basis;
  final int sortOrder;

  SalaryAllowance copyWith({
    int? id,
    int? employeeId,
    String? name,
    int? amount,
    AllowanceBasis? basis,
    int? sortOrder,
  }) {
    return SalaryAllowance(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      basis: basis ?? this.basis,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'name': name,
      'amount': amount,
      'basis': basis.apiValue,
      'sort_order': sortOrder,
    };
  }

  factory SalaryAllowance.fromMap(Map<String, Object?> map) {
    return SalaryAllowance(
      id: (map['id'] as num?)?.toInt(),
      employeeId: (map['employee_id'] as num?)?.toInt() ?? 0,
      name: (map['name'] as String?) ?? '',
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      basis: AllowanceBasis.fromApi(map['basis'] as String?),
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}
