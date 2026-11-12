import '../../core/server_time.dart';

class Holiday {
  const Holiday({
    required this.id,
    required this.date,
    required this.name,
    this.isNational = true,
    this.officeLocationId,
  });

  final int id;
  final DateTime date;
  final String name;
  final bool isNational;
  final int? officeLocationId;

  factory Holiday.fromJson(Map<String, Object?> json) {
    return Holiday(
      id: (json['id'] as num?)?.toInt() ?? 0,
      date: parseServerDate(json['date']) ?? DateTime.now(),
      name: (json['name'] as String?) ?? '',
      isNational: json['is_national'] != false,
      officeLocationId: (json['office_location_id'] as num?)?.toInt(),
    );
  }

  Map<String, Object?> toJson() => {
    'date': date.toIso8601String().substring(0, 10),
    'name': name,
    'is_national': isNational,
    'office_location_id': officeLocationId,
  };
}
