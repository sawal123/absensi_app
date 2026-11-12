import 'package:absensi/core/formatters.dart';
import 'package:absensi/data/api/absensi_api.dart';
import 'package:absensi/data/demo/demo_approvals.dart';
import 'package:absensi/data/models/attendance_correction.dart';
import 'package:absensi/data/models/leave_balance.dart';
import 'package:absensi/data/models/leave_request.dart';
import 'package:absensi/data/models/leave_type.dart';
import 'package:absensi/data/models/request_status.dart';

/// In-memory implementation used by provider unit tests.
class FakeAbsensiApi implements AbsensiApi {
  FakeAbsensiApi({
    required this.leaveTypes,
    required this.balances,
    required this.leaves,
    required this.corrections,
    required this.userIdByEmail,
    required this.employeeById,
  });

  factory FakeAbsensiApi.demo(DateTime now) {
    final userIdByEmail = <String, int>{};
    final employeeById = <int, DemoEmployee>{};
    var nextId = 2;
    for (final employee in DemoApprovals.employees) {
      userIdByEmail[employee.email] = nextId;
      employeeById[nextId] = employee;
      nextId++;
    }

    return FakeAbsensiApi(
      leaveTypes: List.of(DemoApprovals.leaveTypes),
      balances: DemoApprovals.leaveBalances(now, userIdByEmail),
      leaves: DemoApprovals.leaves(now, userIdByEmail),
      corrections: DemoApprovals.corrections(now, userIdByEmail),
      userIdByEmail: userIdByEmail,
      employeeById: employeeById,
    );
  }

  final List<LeaveType> leaveTypes;
  final List<LeaveBalance> balances;
  final List<LeaveRequest> leaves;
  final List<AttendanceCorrection> corrections;
  final Map<String, int> userIdByEmail;
  final Map<int, DemoEmployee> employeeById;

  int _nextLeaveId = 1000;
  int _nextCorrectionId = 2000;

  @override
  Future<List<LeaveType>> getLeaveTypes() async => List.of(leaveTypes);

  @override
  Future<List<LeaveBalance>> getLeaveBalances({
    required int employeeId,
    required int year,
  }) async {
    return balances
        .where((item) => item.employeeId == employeeId && item.year == year)
        .toList();
  }

  @override
  Future<List<LeaveRequest>> getLeaveRequests({
    required int employeeId,
    int? year,
  }) async {
    return leaves
        .where(
          (item) =>
              item.employeeId == employeeId &&
              (year == null || item.startDate.year == year),
        )
        .toList();
  }

  @override
  Future<LeaveRequest> createLeaveRequest(LeaveRequestDraft draft) async {
    final employee = employeeById[draft.employeeId]!;
    final type = leaveTypes.firstWhere((item) => item.id == draft.leaveTypeId);
    final days = workingDaysBetween(draft.startDate, draft.endDate);
    final balance = balances.firstWhere(
      (item) =>
          item.employeeId == draft.employeeId &&
          item.leaveTypeId == draft.leaveTypeId &&
          item.year == draft.startDate.year,
    );
    final id = _nextLeaveId++;

    final request = LeaveRequest(
      id: id,
      employeeId: draft.employeeId,
      code: 'CT-TEST-$id',
      employeeName: employee.name,
      nip: employee.nip,
      team: DemoApprovals.team,
      leaveTypeId: type.id,
      type: type.name,
      startDate: draft.startDate,
      endDate: draft.endDate,
      workingDays: days,
      reason: draft.reason,
      attachmentUrl: draft.attachmentUrl,
      submittedAt: DateTime.now(),
      status: RequestStatus.pending,
      balanceRemaining: balance.remainingDays,
      balanceRequested: days,
      balanceAfter: balance.remainingDays - days,
      teamAvailable: 7,
      teamTotal: 8,
    );
    leaves.add(request);
    return request;
  }

  @override
  Future<LeaveRequest> cancelLeaveRequest(
    int id, {
    required int employeeId,
  }) async {
    final index = leaves.indexWhere((item) => item.id == id);
    final updated = leaves[index].copyWith(status: RequestStatus.cancelled);
    leaves[index] = updated;
    return updated;
  }

  @override
  Future<List<LeaveRequest>> getTeamLeaveRequests({
    RequestStatus? status,
  }) async {
    return status == null
        ? List.of(leaves)
        : leaves.where((item) => item.status == status).toList();
  }

  @override
  Future<LeaveRequest> reviewLeaveRequest(
    int id, {
    required bool approve,
    String note = '',
    int? reviewerId,
    String reviewerName = '',
  }) async {
    final index = leaves.indexWhere((item) => item.id == id);
    final request = leaves[index];
    final updated = request.copyWith(
      status: approve ? RequestStatus.approved : RequestStatus.rejected,
      decisionNote: note,
      reviewerId: reviewerId,
      reviewer: reviewerName,
      reviewedAt: DateTime.now(),
    );
    leaves[index] = updated;

    if (approve) {
      final balanceIndex = balances.indexWhere(
        (item) =>
            item.employeeId == request.employeeId &&
            item.leaveTypeId == request.leaveTypeId &&
            item.year == request.startDate.year,
      );
      if (balanceIndex != -1) {
        balances[balanceIndex] = balances[balanceIndex].copyWith(
          usedDays: balances[balanceIndex].usedDays + request.workingDays,
        );
      }
    }

    return updated;
  }

  @override
  Future<List<AttendanceCorrection>> getCorrections({
    required int employeeId,
  }) async {
    return corrections
        .where((item) => item.employeeId == employeeId)
        .toList();
  }

  @override
  Future<AttendanceCorrection> createCorrection(CorrectionDraft draft) async {
    final employee = employeeById[draft.employeeId]!;
    final id = _nextCorrectionId++;

    final correction = AttendanceCorrection(
      id: id,
      employeeId: draft.employeeId,
      code: 'PA-TEST-$id',
      employeeName: employee.name,
      nip: employee.nip,
      team: DemoApprovals.team,
      attendanceId: draft.attendanceId,
      date: draft.date,
      scheduledStart: '08:00',
      scheduledEnd: '17:00',
      proposedCheckIn: draft.proposedCheckIn,
      proposedCheckOut: draft.proposedCheckOut,
      correctionType: draft.correctionType,
      reason: draft.reason,
      evidenceUrl: draft.evidenceUrl,
      submittedAt: DateTime.now(),
      status: RequestStatus.pending,
    );
    corrections.add(correction);
    return correction;
  }

  @override
  Future<AttendanceCorrection> cancelCorrection(
    int id, {
    required int employeeId,
  }) async {
    final index = corrections.indexWhere((item) => item.id == id);
    final updated = corrections[index].copyWith(
      status: RequestStatus.cancelled,
    );
    corrections[index] = updated;
    return updated;
  }

  @override
  Future<List<AttendanceCorrection>> getTeamCorrections({
    RequestStatus? status,
  }) async {
    return status == null
        ? List.of(corrections)
        : corrections.where((item) => item.status == status).toList();
  }

  @override
  Future<AttendanceCorrection> reviewCorrection(
    int id, {
    required bool approve,
    String note = '',
    int? reviewerId,
    String reviewerName = '',
  }) async {
    final index = corrections.indexWhere((item) => item.id == id);
    final updated = corrections[index].copyWith(
      status: approve ? RequestStatus.approved : RequestStatus.rejected,
      decisionNote: note,
      reviewerId: reviewerId,
      reviewer: reviewerName,
      reviewedAt: DateTime.now(),
    );
    corrections[index] = updated;
    return updated;
  }
}
