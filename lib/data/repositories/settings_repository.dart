import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';

import '../app_database.dart';
import '../models/office_location.dart';
import '../models/office_settings.dart';

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  static const _officeKey = 'office';

  Future<OfficeSettings> getSettings() async {
    final db = await _db.database;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [_officeKey],
      limit: 1,
    );
    if (rows.isEmpty) return const OfficeSettings();
    final raw = rows.first['value'] as String;
    return OfficeSettings.fromMap(jsonDecode(raw) as Map<String, Object?>);
  }

  Future<void> saveSettings(OfficeSettings settings) async {
    final db = await _db.database;
    await db.insert('settings', {
      'key': _officeKey,
      'value': jsonEncode(settings.toMap()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<OfficeLocation>> getLocations() async {
    final settings = await getSettings();
    return [
      OfficeLocation(
        id: settings.officeLocationId ?? 1,
        name: settings.officeName,
        latitude: settings.latitude,
        longitude: settings.longitude,
        radiusMeters: settings.radiusMeters,
        isDefault: true,
      ),
    ];
  }

  Future<OfficeLocation> saveLocation(OfficeLocation location) async {
    final settings = await getSettings();
    final next = settings.copyWith(
      officeName: location.name,
      latitude: location.latitude,
      longitude: location.longitude,
      radiusMeters: location.radiusMeters,
      officeLocationId: location.id == 0 ? 1 : location.id,
    );
    await saveSettings(next);

    return OfficeLocation(
      id: next.officeLocationId ?? 1,
      name: next.officeName,
      address: location.address,
      latitude: next.latitude,
      longitude: next.longitude,
      radiusMeters: next.radiusMeters,
      isDefault: true,
    );
  }

  Future<void> deleteLocation(int id) async {}
}
