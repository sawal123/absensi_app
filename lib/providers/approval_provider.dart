import 'package:flutter/foundation.dart';

import '../data/api/absensi_api.dart';
import '../data/models/attendance_correction.dart';
import '../data/models/leave_request.dart';
import '../data/models/request_status.dart';

enum ApprovalTab { leave, correction }

class ApprovalProvider extends ChangeNotifier {
  ApprovalProvider({
    required AbsensiApi api,
    required int reviewerId,
    required String reviewerName,
  }) : _api = api,
       _reviewerId = reviewerId,
       _reviewerName = reviewerName;

  final AbsensiApi _api;
  final int _reviewerId;
  final String _reviewerName;

  List<LeaveRequest> _leaves = [];
  List<AttendanceCorrection> _corrections = [];
  ApprovalTab _tab = ApprovalTab.leave;
  RequestStatus? _statusFilter;
  bool _loading = false;
  bool _busy = false;
  String? _error;

  ApprovalTab get tab => _tab;
  RequestStatus? get statusFilter => _statusFilter;
  bool get loading => _loading;
  bool get busy => _busy;
  String? get error => _error;

  List<LeaveRequest> get leaves => List.unmodifiable(_leaves);
  List<AttendanceCorrection> get corrections => List.unmodifiable(_corrections);

  int get leaveCount => _leaves.length;
  int get correctionCount => _corrections.length;
  int get pendingLeaveCount => _leaves.where((l) => l.status.isPending).length;
  int get pendingCorrectionCount =>
      _corrections.where((c) => c.status.isPending).length;
  int get pendingCount => pendingLeaveCount + pendingCorrectionCount;

  List<LeaveRequest> get pendingLeaves =>
      _leaves.where((l) => l.status.isPending).toList()
        ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

  List<AttendanceCorrection> get pendingCorrections =>
      _corrections.where((c) => c.status.isPending).toList()
        ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

  List<LeaveRequest> get visibleLeaves {
    final filter = _statusFilter;
    final items = filter == null
        ? List<LeaveRequest>.of(_leaves)
        : _leaves.where((l) => l.status == filter).toList();
    items.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return items;
  }

  List<AttendanceCorrection> get visibleCorrections {
    final filter = _statusFilter;
    final items = filter == null
        ? List<AttendanceCorrection>.of(_corrections)
        : _corrections.where((c) => c.status == filter).toList();
    items.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return items;
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final leaves = await _api.getTeamLeaveRequests();
      final corrections = await _api.getTeamCorrections();
      _leaves = leaves;
      _corrections = corrections;
    } catch (error) {
      _error = _message(error);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  LeaveRequest? leaveById(int id) {
    for (final leave in _leaves) {
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

  List<LeaveRequest> leavesOn(DateTime date) => _leaves
      .where((l) => l.status == RequestStatus.approved && l.covers(date))
      .toList();

  LeaveRequest? leaveForId(int employeeId, DateTime date) {
    for (final leave in leavesOn(date)) {
      if (leave.employeeId == employeeId) return leave;
    }
    return null;
  }

  /// Leave days already approved for [date] keyed by employee id.
  Map<int, LeaveRequest> approvedByEmployeeId(DateTime date) {
    final map = <int, LeaveRequest>{};
    for (final leave in leavesOn(date)) {
      map[leave.employeeId] = leave;
    }
    return map;
  }

  void selectTab(ApprovalTab tab) {
    if (_tab == tab) return;
    _tab = tab;
    notifyListeners();
  }

  void selectStatus(RequestStatus? status) {
    if (_statusFilter == status) return;
    _statusFilter = status;
    notifyListeners();
  }

  Future<bool> approveLeave(int id, {String note = ''}) =>
      _reviewLeave(id, approve: true, note: note);

  Future<bool> rejectLeave(int id, {required String note}) async {
    if (note.trim().isEmpty) {
      _error = 'Catatan wajib diisi saat menolak pengajuan.';
      notifyListeners();
      return false;
    }
    return _reviewLeave(id, approve: false, note: note);
  }

  Future<bool> approveCorrection(int id, {String note = ''}) =>
      _reviewCorrection(id, approve: true, note: note);

  Future<bool> rejectCorrection(int id, {required String note}) async {
    if (note.trim().isEmpty) {
      _error = 'Catatan wajib diisi saat menolak pengajuan.';
      notifyListeners();
      return false;
    }
    return _reviewCorrection(id, approve: false, note: note);
  }

  Future<bool> _reviewLeave(
    int id, {
    required bool approve,
    required String note,
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final updated = await _api.reviewLeaveRequest(
        id,
        approve: approve,
        note: note,
        reviewerId: _reviewerId,
        reviewerName: _reviewerName,
      );
      _replaceLeave(updated);
      return true;
    } catch (error) {
      _error = _message(error);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> _reviewCorrection(
    int id, {
    required bool approve,
    required String note,
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final updated = await _api.reviewCorrection(
        id,
        approve: approve,
        note: note,
        reviewerId: _reviewerId,
        reviewerName: _reviewerName,
      );
      _replaceCorrection(updated);
      return true;
    } catch (error) {
      _error = _message(error);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void _replaceLeave(LeaveRequest updated) {
    final index = _leaves.indexWhere((leave) => leave.id == updated.id);
    if (index == -1) {
      _leaves = [..._leaves, updated];
    } else {
      _leaves = [..._leaves]..[index] = updated;
    }
  }

  void _replaceCorrection(AttendanceCorrection updated) {
    final index = _corrections.indexWhere(
      (correction) => correction.id == updated.id,
    );
    if (index == -1) {
      _corrections = [..._corrections, updated];
    } else {
      _corrections = [..._corrections]..[index] = updated;
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
