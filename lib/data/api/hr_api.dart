import '../models/app_notification.dart';
import '../models/audit_log_entry.dart';
import '../models/holiday.dart';
import '../models/overtime_request.dart';
import '../models/request_status.dart';

/// Endpoint HR yang tidak termasuk kontrak cuti/perbaikan.
abstract class HrApi {
  Future<List<Holiday>> getHolidays({int? year});

  Future<Holiday> saveHoliday(Holiday holiday);

  Future<void> deleteHoliday(int id);

  Future<List<AppNotification>> getNotifications({bool unreadOnly = false});

  Future<int> getUnreadNotificationCount();

  Future<void> markNotificationRead(String id);

  Future<void> markAllNotificationsRead();

  Future<List<OvertimeRequest>> getOvertimeRequests({
    String scope = 'mine',
    RequestStatus? status,
  });

  Future<OvertimeRequest> createOvertimeRequest(OvertimeDraft draft);

  Future<OvertimeRequest> cancelOvertimeRequest(int id);

  Future<OvertimeRequest> reviewOvertimeRequest(
    int id, {
    required bool approve,
    String note = '',
  });

  Future<void> enrollFace(String photoPath);

  Future<List<AuditLogEntry>> getAuditLogs({int limit = 100});
}
