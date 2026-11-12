import '../../core/formatters.dart';

class WorkShift {
  const WorkShift({
    this.id,
    required this.name,
    required this.start,
    required this.end,
    this.office = '',
    this.breakLabel,
    this.crossDay = false,
    this.isActive = true,
    this.colorValue = 0,
  });

  /// Palet warna yang dipakai untuk membedakan shift.
  static const colorPalette = <int>[
    0xFF2563EB,
    0xFF15803D,
    0xFFB45309,
    0xFF7C3AED,
    0xFFDB2777,
    0xFF0891B2,
    0xFFDC2626,
    0xFF4F46E5,
  ];

  final int? id;
  final String name;

  /// HH:mm
  final String start;

  /// HH:mm
  final String end;
  final String office;
  final String? breakLabel;
  final bool crossDay;
  final bool isActive;

  /// ARGB. 0 berarti belum diatur dan memakai warna pertama palet.
  final int colorValue;

  int get resolvedColorValue =>
      colorValue == 0 ? colorPalette.first : colorValue;

  String get rangeLabel => formatClockRange(start, end);

  /// Durasi shift dalam jam, dibulatkan.
  int get hours {
    final total = _durationMinutes;
    return (total / 60).round();
  }

  Duration get duration => Duration(minutes: _durationMinutes);

  int get _durationMinutes {
    var total = _minutesOf(end) - _minutesOf(start);
    if (crossDay || total <= 0) total += 24 * 60;
    return total;
  }

  WorkShift copyWith({
    int? id,
    String? name,
    String? start,
    String? end,
    String? office,
    String? breakLabel,
    bool? crossDay,
    bool? isActive,
    int? colorValue,
  }) {
    return WorkShift(
      id: id ?? this.id,
      name: name ?? this.name,
      start: start ?? this.start,
      end: end ?? this.end,
      office: office ?? this.office,
      breakLabel: breakLabel ?? this.breakLabel,
      crossDay: crossDay ?? this.crossDay,
      isActive: isActive ?? this.isActive,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'start_time': start,
      'end_time': end,
      'office': office,
      'break_label': breakLabel,
      'cross_day': crossDay ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'color': colorValue,
    };
  }

  factory WorkShift.fromMap(Map<String, Object?> map) {
    final start = (map['start_time'] ?? map['start'] ?? '08:00') as String;
    final end = (map['end_time'] ?? map['end'] ?? '17:00') as String;
    return WorkShift(
      id: (map['id'] as num?)?.toInt(),
      name: (map['name'] as String?) ?? '',
      start: start,
      end: end,
      office: (map['office'] as String?) ?? '',
      breakLabel: map['break_label'] as String?,
      crossDay:
          _asBool(map['cross_day']) || _minutesOf(end) <= _minutesOf(start),
      isActive: map['is_active'] == null ? true : _asBool(map['is_active']),
      colorValue: (map['color'] as num?)?.toInt() ?? 0,
    );
  }

  static int _minutesOf(String value) {
    final parts = value.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return hour * 60 + minute;
  }

  static bool _asBool(Object? value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value.toString() == '1' || value.toString().toLowerCase() == 'true';
  }
}

class ShiftDay {
  const ShiftDay({required this.date, this.shift});

  final DateTime date;
  final WorkShift? shift;

  bool get isOff => shift == null;
}
