import 'package:flutter/foundation.dart';

import '../core/formatters.dart';
import '../data/api/hr_api.dart';
import '../data/models/app_notification.dart';
import '../data/models/audit_log_entry.dart';
import '../data/models/holiday.dart';
import '../data/models/overtime_request.dart';
import '../data/models/user.dart';

class HrProvider extends ChangeNotifier {
  HrProvider({required HrApi api, required this.user}) : _api = api;

  final HrApi _api;
  final User user;

  List<Holiday> _holidays = [];
  List<AppNotification> _notifications = [];
  List<OvertimeRequest> _overtime = [];
  List<AuditLogEntry> _auditLogs = [];
  int _unreadCount = 0;
  bool _loading = false;
  bool _busy = false;
  String? _error;

  List<Holiday> get holidays => List.unmodifiable(_holidays);
  List<AppNotification> get notifications =>
      List.unmodifiable(_notifications);
  List<OvertimeRequest> get overtimeRequests => List.unmodifiable(_overtime);
  List<AuditLogEntry> get auditLogs => List.unmodifiable(_auditLogs);
  int get unreadCount => _unreadCount;
  bool get loading => _loading;
  bool get busy => _busy;
  String? get error => _error;

  Set<String> get holidayKeys =>
      {for (final holiday in _holidays) dateKey(holiday.date)};

  List<Holiday> get upcomingHolidays {
    final today = dateOnly(DateTime.now());
    final items = _holidays
        .where((holiday) => !holiday.date.isBefore(today))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return items.take(5).toList();
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final year = DateTime.now().year;
      _holidays = await _api.getHolidays(year: year);
      _notifications = await _api.getNotifications();
      _unreadCount = await _api.getUnreadNotificationCount();
      _overtime = await _api.getOvertimeRequests(
        scope: user.isManager ? 'team' : 'mine',
      );
    } catch (error) {
      _error = _message(error);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshNotifications() async {
    try {
      _notifications = await _api.getNotifications();
      _unreadCount = await _api.getUnreadNotificationCount();
      notifyListeners();
    } catch (error) {
      _error = _message(error);
      notifyListeners();
    }
  }

  Future<void> markNotificationRead(String id) async {
    try {
      await _api.markNotificationRead(id);
      await refreshNotifications();
    } catch (error) {
      _error = _message(error);
      notifyListeners();
    }
  }

  Future<void> markAllNotificationsRead() async {
    try {
      await _api.markAllNotificationsRead();
      await refreshNotifications();
    } catch (error) {
      _error = _message(error);
      notifyListeners();
    }
  }

  Future<bool> submitOvertime(OvertimeDraft draft) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _api.createOvertimeRequest(draft);
      _overtime = await _api.getOvertimeRequests(
        scope: user.isManager ? 'team' : 'mine',
      );
      return true;
    } catch (error) {
      _error = _message(error);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> cancelOvertime(int id) async {
    return _run(() => _api.cancelOvertimeRequest(id));
  }

  Future<bool> reviewOvertime(
    int id, {
    required bool approve,
    String note = '',
  }) async {
    if (!approve && note.trim().isEmpty) {
      _error = 'Catatan wajib diisi saat menolak lembur.';
      notifyListeners();
      return false;
    }
    return _run(
      () => _api.reviewOvertimeRequest(id, approve: approve, note: note),
    );
  }

  Future<bool> enrollFace(String photoPath) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _api.enrollFace(photoPath);
      return true;
    } catch (error) {
      _error = _message(error);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> saveHoliday(Holiday holiday) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _api.saveHoliday(holiday);
      _holidays = await _api.getHolidays(year: holiday.date.year);
      return true;
    } catch (error) {
      _error = _message(error);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> deleteHoliday(int id) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _api.deleteHoliday(id);
      _holidays = await _api.getHolidays(year: DateTime.now().year);
      return true;
    } catch (error) {
      _error = _message(error);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> loadAuditLogs() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _auditLogs = await _api.getAuditLogs();
    } catch (error) {
      _error = _message(error);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> _run(Future<OvertimeRequest> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      _overtime = await _api.getOvertimeRequests(
        scope: user.isManager ? 'team' : 'mine',
      );
      return true;
    } catch (error) {
      _error = _message(error);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  String _message(Object error) =>
      error.toString().replaceFirst('ApiException: ', '');
}
