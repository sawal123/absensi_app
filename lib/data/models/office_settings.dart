class OfficeSettings {
  const OfficeSettings({
    this.officeName = 'Kantor Pusat',
    this.latitude = -6.200000,
    this.longitude = 106.816666,
    this.radiusMeters = 100,
    this.workStart = '08:00',
    this.workEnd = '17:00',
    this.earlyCheckInMinutes = 60,
    this.lateToleranceMinutes = 0,
    this.faceMatchRequired = false,
    this.faceMatchThreshold = 12,
    this.overtimeRequiresApproval = false,
    this.deviceBindingEnabled = false,
    this.selfieRequired = true,
    this.mockLocationBlocked = true,
    this.officeLocationId,
  });

  final String officeName;
  final double latitude;
  final double longitude;
  final int radiusMeters;

  /// HH:mm
  final String workStart;

  /// HH:mm
  final String workEnd;

  /// Absen masuk hanya dibuka selama [earlyCheckInMinutes] sebelum shift
  /// dimulai. Contoh: 60 berarti shift 08:00 tidak bisa absen pukul 06:00.
  final int earlyCheckInMinutes;
  final int lateToleranceMinutes;
  final bool faceMatchRequired;
  final int faceMatchThreshold;
  final bool overtimeRequiresApproval;
  final bool deviceBindingEnabled;
  final bool selfieRequired;
  final bool mockLocationBlocked;
  final int? officeLocationId;

  bool get isConfigured => latitude != 0 || longitude != 0;

  OfficeSettings copyWith({
    String? officeName,
    double? latitude,
    double? longitude,
    int? radiusMeters,
    String? workStart,
    String? workEnd,
    int? earlyCheckInMinutes,
    int? lateToleranceMinutes,
    bool? faceMatchRequired,
    int? faceMatchThreshold,
    bool? overtimeRequiresApproval,
    bool? deviceBindingEnabled,
    bool? selfieRequired,
    bool? mockLocationBlocked,
    int? officeLocationId,
  }) {
    return OfficeSettings(
      officeName: officeName ?? this.officeName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      workStart: workStart ?? this.workStart,
      workEnd: workEnd ?? this.workEnd,
      earlyCheckInMinutes: earlyCheckInMinutes ?? this.earlyCheckInMinutes,
      lateToleranceMinutes: lateToleranceMinutes ?? this.lateToleranceMinutes,
      faceMatchRequired: faceMatchRequired ?? this.faceMatchRequired,
      faceMatchThreshold: faceMatchThreshold ?? this.faceMatchThreshold,
      overtimeRequiresApproval:
          overtimeRequiresApproval ?? this.overtimeRequiresApproval,
      deviceBindingEnabled: deviceBindingEnabled ?? this.deviceBindingEnabled,
      selfieRequired: selfieRequired ?? this.selfieRequired,
      mockLocationBlocked: mockLocationBlocked ?? this.mockLocationBlocked,
      officeLocationId: officeLocationId ?? this.officeLocationId,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'officeName': officeName,
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'workStart': workStart,
      'workEnd': workEnd,
      'earlyCheckInMinutes': earlyCheckInMinutes,
      'lateToleranceMinutes': lateToleranceMinutes,
      'faceMatchRequired': faceMatchRequired,
      'faceMatchThreshold': faceMatchThreshold,
      'overtimeRequiresApproval': overtimeRequiresApproval,
      'deviceBindingEnabled': deviceBindingEnabled,
      'selfieRequired': selfieRequired,
      'mockLocationBlocked': mockLocationBlocked,
      'officeLocationId': officeLocationId,
    };
  }

  factory OfficeSettings.fromMap(Map<String, Object?> map) {
    return OfficeSettings(
      officeName: (map['officeName'] as String?) ?? 'Kantor Pusat',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      radiusMeters: (map['radiusMeters'] as num?)?.toInt() ?? 100,
      workStart: (map['workStart'] as String?) ?? '08:00',
      workEnd: (map['workEnd'] as String?) ?? '17:00',
      earlyCheckInMinutes: (map['earlyCheckInMinutes'] as num?)?.toInt() ?? 60,
      lateToleranceMinutes:
          (map['lateToleranceMinutes'] as num?)?.toInt() ?? 0,
      faceMatchRequired: map['faceMatchRequired'] == true,
      faceMatchThreshold: (map['faceMatchThreshold'] as num?)?.toInt() ?? 12,
      overtimeRequiresApproval: map['overtimeRequiresApproval'] == true,
      deviceBindingEnabled: map['deviceBindingEnabled'] == true,
      selfieRequired: map['selfieRequired'] != false,
      mockLocationBlocked: map['mockLocationBlocked'] != false,
      officeLocationId: (map['officeLocationId'] as num?)?.toInt(),
    );
  }
}
