import '../models/app_notification.dart';
import '../models/audit_log_entry.dart';
import '../models/holiday.dart';
import '../models/overtime_request.dart';
import '../models/request_status.dart';
import 'api_client.dart';
import 'hr_api.dart';
import 'remote/remote_utils.dart';

class HttpHrApi implements HrApi {
  HttpHrApi(this._client);

  final ApiClient _client;

  @override
  Future<List<Holiday>> getHolidays({int? year}) async {
    final decoded = await _client.get(
      '/holidays',
      query: year == null ? null : {'year': '$year'},
    );
    return asList(decoded).map(Holiday.fromJson).toList();
  }

  @override
  Future<Holiday> saveHoliday(Holiday holiday) async {
    final decoded = holiday.id == 0
        ? await _client.post('/holidays', body: holiday.toJson())
        : await _client.put('/holidays/${holiday.id}', body: holiday.toJson());
    return Holiday.fromJson(asMap(decoded));
  }

  @override
  Future<void> deleteHoliday(int id) async {
    await _client.delete('/holidays/$id');
  }

  @override
  Future<List<AppNotification>> getNotifications({
    bool unreadOnly = false,
  }) async {
    final decoded = await _client.get(
      '/notifications',
      query: unreadOnly ? {'unread_only': '1'} : null,
    );
    return asList(decoded).map(AppNotification.fromJson).toList();
  }

  @override
  Future<int> getUnreadNotificationCount() async {
    final decoded = await _client.get(
      '/notifications',
      query: {'limit': '1'},
    );
    if (decoded is Map && decoded['meta'] is Map) {
      final meta = decoded['meta'] as Map;
      return (meta['unread_count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  @override
  Future<void> markNotificationRead(String id) async {
    await _client.patch('/notifications/$id/read');
  }

  @override
  Future<void> markAllNotificationsRead() async {
    await _client.patch('/notifications/read-all');
  }

  @override
  Future<List<OvertimeRequest>> getOvertimeRequests({
    String scope = 'mine',
    RequestStatus? status,
  }) async {
    final decoded = await _client.get(
      '/overtime-requests',
      query: {
        'scope': scope,
        if (status != null) 'status': status.apiValue,
      },
    );
    return asList(decoded).map(OvertimeRequest.fromJson).toList();
  }

  @override
  Future<OvertimeRequest> createOvertimeRequest(OvertimeDraft draft) async {
    final decoded = await _client.post(
      '/overtime-requests',
      body: draft.toJson(),
    );
    return OvertimeRequest.fromJson(asMap(decoded));
  }

  @override
  Future<OvertimeRequest> cancelOvertimeRequest(int id) async {
    final decoded = await _client.patch('/overtime-requests/$id/cancel');
    return OvertimeRequest.fromJson(asMap(decoded));
  }

  @override
  Future<OvertimeRequest> reviewOvertimeRequest(
    int id, {
    required bool approve,
    String note = '',
  }) async {
    final decoded = await _client.patch(
      '/overtime-requests/$id/review',
      body: {
        'status': approve ? 'approved' : 'rejected',
        'review_note': note.trim(),
      },
    );
    return OvertimeRequest.fromJson(asMap(decoded));
  }

  @override
  Future<void> enrollFace(String photoPath) async {
    await _client.multipart(
      '/auth/face',
      fileField: 'photo',
      filePath: photoPath,
    );
  }

  @override
  Future<void> deleteFace() async {
    await _client.delete('/auth/face');
  }

  @override
  Future<List<AuditLogEntry>> getAuditLogs({int limit = 100}) async {
    final decoded = await _client.get(
      '/audit-logs',
      query: {'limit': '$limit'},
    );
    return asList(decoded).map(AuditLogEntry.fromJson).toList();
  }
}
