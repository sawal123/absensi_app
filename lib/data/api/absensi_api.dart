import '../../core/formatters.dart';
import '../models/attendance_correction.dart';
import '../models/correction_type.dart';
import '../models/leave_balance.dart';
import '../models/leave_request.dart';
import '../models/leave_type.dart';
import '../models/request_status.dart';

abstract class AbsensiApi {
  Future<List<LeaveType>> getLeaveTypes();

  Future<List<LeaveBalance>> getLeaveBalances({
    required int employeeId,
    required int year,
  });

  Future<List<LeaveRequest>> getLeaveRequests({
    required int employeeId,
    int? year,
  });

  Future<LeaveRequest> createLeaveRequest(LeaveRequestDraft draft);

  Future<LeaveRequest> cancelLeaveRequest(int id, {required int employeeId});

  Future<List<LeaveRequest>> getTeamLeaveRequests({RequestStatus? status});

  Future<LeaveRequest> reviewLeaveRequest(
    int id, {
    required bool approve,
    String note = '',
    int? reviewerId,
    String reviewerName = '',
  });

  Future<List<AttendanceCorrection>> getCorrections({required int employeeId});

  Future<AttendanceCorrection> createCorrection(CorrectionDraft draft);

  Future<AttendanceCorrection> cancelCorrection(
    int id, {
    required int employeeId,
  });

  Future<List<AttendanceCorrection>> getTeamCorrections({
    RequestStatus? status,
  });

  Future<AttendanceCorrection> reviewCorrection(
    int id, {
    required bool approve,
    String note = '',
    int? reviewerId,
    String reviewerName = '',
  });
}

class LeaveRequestDraft {
  const LeaveRequestDraft({
    required this.employeeId,
    required this.leaveTypeId,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.attachmentUrl,
  });

  final int employeeId;
  final int leaveTypeId;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String? attachmentUrl;

  Map<String, Object?> toJson() {
    return {
      'leave_type_id': leaveTypeId,
      'start_date': dateKey(startDate),
      'end_date': dateKey(endDate),
      'reason': reason,
      'attachment_url': attachmentUrl,
    };
  }
}

class CorrectionDraft {
  const CorrectionDraft({
    required this.employeeId,
    required this.date,
    required this.correctionType,
    required this.reason,
    this.attendanceId,
    this.proposedCheckIn,
    this.proposedCheckOut,
    this.evidenceUrl,
  });

  final int employeeId;
  final int? attendanceId;
  final DateTime date;
  final CorrectionType correctionType;
  final DateTime? proposedCheckIn;
  final DateTime? proposedCheckOut;
  final String reason;
  final String? evidenceUrl;

  Map<String, Object?> toJson() {
    return {
      'attendance_id': attendanceId,
      'date': dateKey(date),
      'correction_type': correctionType.apiValue,
      'proposed_check_in_at': proposedCheckIn?.toIso8601String(),
      'proposed_check_out_at': proposedCheckOut?.toIso8601String(),
      'reason': reason,
      'evidence_url': evidenceUrl,
    };
  }
}
