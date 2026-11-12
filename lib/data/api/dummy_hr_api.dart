import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';

import '../app_database.dart';
import '../models/app_notification.dart';
import '../models/audit_log_entry.dart';
import '../models/holiday.dart';
import '../models/overtime_request.dart';
import '../models/request_status.dart';
import 'hr_api.dart';

/// Implementasi lokal untuk mode demo tanpa backend.
class DummyHrApi implements HrApi {
  DummyHrApi(this._db);

  final AppDatabase _db;
  static const _holidayKey = 'hr_holidays';
  static const _overtimeKey = 'hr_overtime';

  @override
  Future<List<Holiday>> getHolidays({int? year}) async {
    final items = await _read(_holidayKey);
    final holidays = items.map((item) => Holiday.fromJson(item)).toList();
    if (year == null) return holidays;
    return holidays.where((item) => item.date.year == year).toList();
  }

  @override
  Future<Holiday> saveHoliday(Holiday holiday) async {
    final items = await _read(_holidayKey);
    var nextId = 1;
    for (final item in items) {
      final id = (item['id'] as num?)?.toInt() ?? 0;
      if (id >= nextId) nextId = id + 1;
    }
    final saved = Holiday(
      id: holiday.id == 0 ? nextId : holiday.id,
      date: holiday.date,
      name: holiday.name,
      isNational: holiday.isNational,
      officeLocationId: holiday.officeLocationId,
    );
    items.removeWhere((item) => item['id'] == saved.id);
    items.add(saved.toJson()..['id'] = saved.id);
    await _write(_holidayKey, items);
    return saved;
  }

  @override
  Future<void> deleteHoliday(int id) async {
    final items = await _read(_holidayKey);
    items.removeWhere((item) => item['id'] == id);
    await _write(_holidayKey, items);
  }

  @override
  Future<List<AppNotification>> getNotifications({bool unreadOnly = false}) async =>
      const [];

  @override
  Future<int> getUnreadNotificationCount() async => 0;

  @override
  Future<void> markNotificationRead(String id) async {}

  @override
  Future<void> markAllNotificationsRead() async {}

  @override
  Future<List<OvertimeRequest>> getOvertimeRequests({
    String scope = 'mine',
    RequestStatus? status,
  }) async {
    final items = await _read(_overtimeKey);
    final result = items.map(_overtime).toList();
    if (status == null) return result;
    return result.where((item) => item.status == status).toList();
  }

  @override
  Future<OvertimeRequest> createOvertimeRequest(OvertimeDraft draft) async {
    final items = await _read(_overtimeKey);
    final nextId = items.length + 1;
    final request = OvertimeRequest(
      id: nextId,
      employeeId: 0,
      employeeName: 'Saya',
      date: draft.date,
      startAt: draft.startAt,
      endAt: draft.endAt,
      minutes: draft.minutes,
      reason: draft.reason,
      status: RequestStatus.pending,
      createdAt: DateTime.now(),
    );
    items.add(_toMap(request));
    await _write(_overtimeKey, items);
    return request;
  }

  @override
  Future<OvertimeRequest> cancelOvertimeRequest(int id) async {
    return _update(id, RequestStatus.cancelled, 'Dibatalkan.');
  }

  @override
  Future<OvertimeRequest> reviewOvertimeRequest(
    int id, {
    required bool approve,
    String note = '',
  }) async {
    return _update(
      id,
      approve ? RequestStatus.approved : RequestStatus.rejected,
      note,
    );
  }

  Future<OvertimeRequest> _update(
    int id,
    RequestStatus status,
    String note,
  ) async {
    final items = await _read(_overtimeKey);
    final index = items.indexWhere((item) => item['id'] == id);
    if (index < 0) {
      throw StateError('Pengajuan lembur tidak ditemukan.');
    }
    items[index]['status'] = status.apiValue;
    items[index]['review_note'] = note;
    items[index]['reviewed_at'] = DateTime.now().toIso8601String();
    await _write(_overtimeKey, items);
    return _overtime(items[index]);
  }

  @override
  Future<void> enrollFace(String photoPath) async {
    throw StateError('Pendaftaran wajah memerlukan backend Laravel aktif.');
  }

  @override
  Future<void> deleteFace() async {
    throw StateError('Penghapusan data wajah memerlukan backend Laravel aktif.');
  }

  @override
  Future<List<AuditLogEntry>> getAuditLogs({int limit = 100}) async => const [];

  OvertimeRequest _overtime(Map<String, Object?> item) {
    return OvertimeRequest(
      id: (item['id'] as num?)?.toInt() ?? 0,
      employeeId: (item['employee_id'] as num?)?.toInt() ?? 0,
      employeeName: (item['employee_name'] as String?) ?? 'Saya',
      date: DateTime.tryParse('${item['date']}') ?? DateTime.now(),
      startAt: DateTime.tryParse('${item['start_at']}') ?? DateTime.now(),
      endAt: DateTime.tryParse('${item['end_at']}') ?? DateTime.now(),
      minutes: (item['minutes'] as num?)?.toInt() ?? 0,
      reason: (item['reason'] as String?) ?? '',
      status: RequestStatus.fromApi(item['status'] as String?),
      reviewNote: (item['review_note'] as String?) ?? '',
      reviewedAt: DateTime.tryParse('${item['reviewed_at']}'),
      createdAt: DateTime.tryParse('${item['created_at']}') ?? DateTime.now(),
    );
  }

  Map<String, Object?> _toMap(OvertimeRequest request) => {
    'id': request.id,
    'employee_id': request.employeeId,
    'employee_name': request.employeeName,
    'date': request.date.toIso8601String().substring(0, 10),
    'start_at': request.startAt.toIso8601String(),
    'end_at': request.endAt.toIso8601String(),
    'minutes': request.minutes,
    'reason': request.reason,
    'status': request.status.apiValue,
    'review_note': request.reviewNote,
    'reviewed_at': request.reviewedAt?.toIso8601String(),
    'created_at': request.createdAt.toIso8601String(),
  };

  Future<List<Map<String, Object?>>> _read(String key) async {
    final db = await _db.database;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return [];
    final raw = rows.first['value'] as String;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList();
  }

  Future<void> _write(String key, List<Map<String, Object?>> items) async {
    final db = await _db.database;
    await db.insert('settings', {
      'key': key,
      'value': jsonEncode(items),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
