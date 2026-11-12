import '../../app_database.dart';
import '../../models/office_location.dart';
import '../../models/office_settings.dart';
import '../../repositories/settings_repository.dart';
import '../api_client.dart';
import 'remote_utils.dart';

class HttpSettingsRepository extends SettingsRepository {
  HttpSettingsRepository(this._client) : super(AppDatabase.instance);

  final ApiClient _client;

  @override
  Future<OfficeSettings> getSettings() async {
    final decoded = await _client.get('/office-settings');
    return _settings(asMap(decoded));
  }

  @override
  Future<void> saveSettings(OfficeSettings settings) async {
    await _client.put(
      '/office-settings',
      body: {
        if (settings.officeLocationId != null)
          'office_location_id': settings.officeLocationId,
        'office_name': settings.officeName,
        'latitude': settings.latitude,
        'longitude': settings.longitude,
        'radius_meters': settings.radiusMeters,
        'work_start': settings.workStart,
        'work_end': settings.workEnd,
        'early_check_in_minutes': settings.earlyCheckInMinutes,
        'late_tolerance_minutes': settings.lateToleranceMinutes,
        'face_match_required': settings.faceMatchRequired,
        'face_match_threshold': settings.faceMatchThreshold,
        'overtime_requires_approval': settings.overtimeRequiresApproval,
        'device_binding_enabled': settings.deviceBindingEnabled,
        'selfie_required': settings.selfieRequired,
        'mock_location_blocked': settings.mockLocationBlocked,
      },
    );
  }

  @override
  Future<List<OfficeLocation>> getLocations() async {
    final decoded = await _client.get('/office-locations');
    return asList(decoded).map(OfficeLocation.fromJson).toList();
  }

  @override
  Future<OfficeLocation> saveLocation(OfficeLocation location) async {
    final decoded = location.id == 0
        ? await _client.post('/office-locations', body: location.toJson())
        : await _client.put(
            '/office-locations/${location.id}',
            body: location.toJson(),
          );
    return OfficeLocation.fromJson(asMap(decoded));
  }

  @override
  Future<void> deleteLocation(int id) async {
    await _client.delete('/office-locations/$id');
  }

  OfficeSettings _settings(Map<String, Object?> json) {
    return OfficeSettings(
      officeName: (json['office_name'] as String?) ?? 'Kantor Pusat',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      radiusMeters: (json['radius_meters'] as num?)?.toInt() ?? 100,
      workStart: (json['work_start'] as String?) ?? '08:00',
      workEnd: (json['work_end'] as String?) ?? '17:00',
      earlyCheckInMinutes:
          (json['early_check_in_minutes'] as num?)?.toInt() ?? 60,
      lateToleranceMinutes:
          (json['late_tolerance_minutes'] as num?)?.toInt() ?? 0,
      faceMatchRequired: json['face_match_required'] == true,
      faceMatchThreshold:
          (json['face_match_threshold'] as num?)?.toInt() ?? 12,
      overtimeRequiresApproval: json['overtime_requires_approval'] == true,
      deviceBindingEnabled: json['device_binding_enabled'] == true,
      selfieRequired: json['selfie_required'] != false,
      mockLocationBlocked: json['mock_location_blocked'] != false,
      officeLocationId: (json['office_location_id'] as num?)?.toInt(),
    );
  }
}
