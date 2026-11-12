import 'package:flutter/foundation.dart';

import '../data/api/absensi_api.dart';
import '../data/api/hr_api.dart';
import '../data/models/attendance_correction.dart';
import '../data/models/holiday.dart';
import '../data/models/leave_balance.dart';
import '../data/models/leave_request.dart';
import '../data/models/leave_type.dart';

class MyRequestsProvider extends ChangeNotifier {
  MyRequestsProvider({
    required AbsensiApi api,
    required int employeeId,
    required int year,
    HrApi? hrApi,
  }) : _api = api,
       _employeeId = employeeId,
       _year = year,
       _hrApi = hrApi;

  final AbsensiApi _api;
  final HrApi? _hrApi;
  final int _employeeId;
  final int _year;

  List<LeaveType> _leaveTypes = [];
  List<LeaveBalance> _leaveBalances = [];
  List<LeaveRequest> _leaveRequests = [];
  List<AttendanceCorrection> _corrections = [];
  List<Holiday> _holidays = [];
  bool _loading = false;
  bool _busy = false;
  String? _error;

  int get employeeId => _employeeId;
  int get year => _year;
  bool get loading => _loading;
  bool get busy => _busy;
  String? get error => _error;

  List<LeaveType> get leaveTypes => List.unmodifiable(_leaveTypes);
  List<LeaveBalance> get leaveBalances => List.unmodifiable(_leaveBalances);
  List<LeaveRequest> get leaveRequests => List.unmodifiable(_leaveRequests);
  List<AttendanceCorrection> get corrections =>
      List.unmodifiable(_corrections);
  List<Holiday> get holidays => List.unmodifiable(_holidays);
  Set<String> get holidayKeys =>
      {for (final holiday in _holidays) dateKeyValue(holiday.date)};

  static String dateKeyValue(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  bool get hasLoadedTypes => _leaveTypes.isNotEmpty;

  LeaveType? leaveTypeById(int id) {
    for (final type in _leaveTypes) {
      if (type.id == id) return type;
    }
    return null;
  }

  LeaveBalance? balanceFor(int leaveTypeId) {
    for (final balance in _leaveBalances) {
      if (balance.leaveTypeId == leaveTypeId) return balance;
    }
    return null;
  }

  /// Saldo cuti tahunan dipakai kartu ringkasan.
  LeaveBalance? get annualLeaveBalance => balanceFor(1);

  LeaveRequest? leaveById(int id) {
    for (final leave in _leaveRequests) {
      if (leave.id == id) return leave;
    }
    return null;
  }

  AttendanceCorrection? correctionById(int id) {
    for (final correction in _corrections) {
      if (correction.id == id) return correction;
    }
    return null;
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _leaveTypes = await _api.getLeaveTypes();
      if (_hrApi != null) {
        try {
          _holidays = await _hrApi.getHolidays(year: _year);
        } catch (_) {
          _holidays = [];
        }
      }
      await _refresh();
    } catch (error) {
      _error = _message(error);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> submitLeave(LeaveRequestDraft draft) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _api.createLeaveRequest(draft);
      await _refresh();
      return true;
    } catch (error) {
      _error = _message(error);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> submitCorrection(CorrectionDraft draft) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _api.createCorrection(draft);
      await _refresh();
      return true;
    } catch (error) {
      _error = _message(error);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> cancelLeave(int id) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _api.cancelLeaveRequest(id, employeeId: _employeeId);
      await _refresh();
      return true;
    } catch (error) {
      _error = _message(error);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> cancelCorrection(int id) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _api.cancelCorrection(id, employeeId: _employeeId);
      await _refresh();
      return true;
    } catch (error) {
      _error = _message(error);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _refresh() async {
    _leaveBalances = await _api.getLeaveBalances(
      employeeId: _employeeId,
      year: _year,
    );
    _leaveRequests = await _api.getLeaveRequests(
      employeeId: _employeeId,
      year: _year,
    );
    _corrections = await _api.getCorrections(employeeId: _employeeId);
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  String _message(Object error) =>
      error.toString().replaceFirst('ApiException: ', '');
}
