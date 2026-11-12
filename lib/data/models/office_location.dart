class OfficeLocation {
  const OfficeLocation({
    required this.id,
    required this.name,
    this.address = '',
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 100,
    this.timezone = 'Asia/Jakarta',
    this.isDefault = false,
    this.isActive = true,
    this.employeesCount = 0,
  });

  final int id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final String timezone;
  final bool isDefault;
  final bool isActive;
  final int employeesCount;

  factory OfficeLocation.fromJson(Map<String, Object?> json) {
    return OfficeLocation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      radiusMeters: (json['radius_meters'] as num?)?.toInt() ?? 100,
      timezone: (json['timezone'] as String?) ?? 'Asia/Jakarta',
      isDefault: json['is_default'] == true,
      isActive: json['is_active'] != false,
      employeesCount: (json['employees_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'radius_meters': radiusMeters,
    'timezone': timezone,
    'is_default': isDefault,
    'is_active': isActive,
  };
}
