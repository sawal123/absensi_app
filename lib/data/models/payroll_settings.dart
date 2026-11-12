class TaxBracket {
  const TaxBracket({this.limit, required this.rate});

  /// Batas atas PKP tahunan dalam rupiah. `null` berarti tanpa batas.
  final int? limit;

  /// Tarif dalam persen, contoh 5 berarti 5%.
  final double rate;

  Map<String, Object?> toMap() => {'limit': limit, 'rate': rate};

  factory TaxBracket.fromMap(Map<String, Object?> map) {
    return TaxBracket(
      limit: (map['limit'] as num?)?.toInt(),
      rate: (map['rate'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PayrollSettings {
  const PayrollSettings({
    this.overtimeEnabled = true,
    this.overtimeMinMinutes = 30,
    this.ptkp = defaultPtkp,
    this.pph21Brackets = defaultBrackets,
  });

  final bool overtimeEnabled;
  final int overtimeMinMinutes;

  /// PTKP tahunan per status, dalam rupiah.
  final Map<String, int> ptkp;
  final List<TaxBracket> pph21Brackets;

  static const Map<String, int> defaultPtkp = {
    'TK/0': 54000000,
    'TK/1': 58500000,
    'TK/2': 63000000,
    'TK/3': 67500000,
    'K/0': 58500000,
    'K/1': 63000000,
    'K/2': 67500000,
    'K/3': 72000000,
  };

  static const List<String> ptkpStatuses = [
    'TK/0',
    'TK/1',
    'TK/2',
    'TK/3',
    'K/0',
    'K/1',
    'K/2',
    'K/3',
  ];

  static const List<TaxBracket> defaultBrackets = [
    TaxBracket(limit: 60000000, rate: 5),
    TaxBracket(limit: 250000000, rate: 15),
    TaxBracket(limit: 500000000, rate: 25),
    TaxBracket(limit: 5000000000, rate: 30),
    TaxBracket(limit: null, rate: 35),
  ];

  factory PayrollSettings.defaults() => const PayrollSettings();

  int ptkpFor(String status) => ptkp[status] ?? ptkp['TK/0'] ?? 54000000;

  PayrollSettings copyWith({
    bool? overtimeEnabled,
    int? overtimeMinMinutes,
    Map<String, int>? ptkp,
    List<TaxBracket>? pph21Brackets,
  }) {
    return PayrollSettings(
      overtimeEnabled: overtimeEnabled ?? this.overtimeEnabled,
      overtimeMinMinutes: overtimeMinMinutes ?? this.overtimeMinMinutes,
      ptkp: ptkp ?? this.ptkp,
      pph21Brackets: pph21Brackets ?? this.pph21Brackets,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'overtimeEnabled': overtimeEnabled,
      'overtimeMinMinutes': overtimeMinMinutes,
      'ptkp': ptkp,
      'pph21Brackets': [for (final bracket in pph21Brackets) bracket.toMap()],
    };
  }

  factory PayrollSettings.fromMap(Map<String, Object?> map) {
    final rawPtkp = map['ptkp'];
    final ptkp = <String, int>{...defaultPtkp};
    if (rawPtkp is Map) {
      rawPtkp.forEach((key, value) {
        if (value is num) ptkp['$key'] = value.toInt();
      });
    }

    final rawBrackets = map['pph21Brackets'];
    final brackets = <TaxBracket>[];
    if (rawBrackets is List) {
      for (final item in rawBrackets) {
        if (item is Map) {
          brackets.add(TaxBracket.fromMap(Map<String, Object?>.from(item)));
        }
      }
    }

    return PayrollSettings(
      overtimeEnabled: _asBool(map['overtimeEnabled'], fallback: true),
      overtimeMinMinutes: (map['overtimeMinMinutes'] as num?)?.toInt() ?? 30,
      ptkp: ptkp,
      pph21Brackets: brackets.isEmpty ? defaultBrackets : brackets,
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
