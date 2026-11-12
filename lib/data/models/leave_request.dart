import '../../core/formatters.dart';
import '../../core/server_time.dart';
import 'request_status.dart';

class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.employeeId,
    required this.code,
    required this.employeeName,
    required this.nip,
    required this.team,
    required this.leaveTypeId,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.workingDays,
    required this.reason,
    required this.submittedAt,
    required this.status,
    this.attachmentUrl,
    this.reviewerId,
    this.reviewer = '',
    this.reviewedAt,
    this.decisionNote = '',
    this.balanceRemaining = 0,
    this.balanceRequested = 0,
    this.balanceAfter = 0,
    this.teamAvailable = 0,
    this.teamTotal = 0,
  });

  final int id;
  final int employeeId;
  final String code;
  final String employeeName;
  final String nip;
  final String team;
  final int leaveTypeId;

  /// Nama tipe cuti yang ditampilkan di UI.
  final String type;
  final DateTime startDate;
  final DateTime endDate;
  final int workingDays;
  final String reason;
  final String? attachmentUrl;
  final DateTime submittedAt;
  final RequestStatus status;
  final int? reviewerId;
  final String reviewer;
  final DateTime? reviewedAt;
  final String decisionNote;
  final int balanceRemaining;
  final int balanceRequested;
  final int balanceAfter;
  final int teamAvailable;
  final int teamTotal;

  bool covers(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  LeaveRequest copyWith({
    RequestStatus? status,
    String? decisionNote,
    int? reviewerId,
    String? reviewer,
    DateTime? reviewedAt,
    String? attachmentUrl,
    int? balanceRemaining,
    int? balanceRequested,
    int? balanceAfter,
    int? teamAvailable,
    int? teamTotal,
  }) {
    return LeaveRequest(
      id: id,
      employeeId: employeeId,
      code: code,
      employeeName: employeeName,
      nip: nip,
      team: team,
      leaveTypeId: leaveTypeId,
      type: type,
      startDate: startDate,
      endDate: endDate,
      workingDays: workingDays,
      reason: reason,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      submittedAt: submittedAt,
      status: status ?? this.status,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewer: reviewer ?? this.reviewer,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      decisionNote: decisionNote ?? this.decisionNote,
      balanceRemaining: balanceRemaining ?? this.balanceRemaining,
      balanceRequested: balanceRequested ?? this.balanceRequested,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      teamAvailable: teamAvailable ?? this.teamAvailable,
      teamTotal: teamTotal ?? this.teamTotal,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'code': code,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'nip': nip,
      'team': team,
      'leave_type_id': leaveTypeId,
      'leave_type_name': type,
      'start_date': dateKey(startDate),
      'end_date': dateKey(endDate),
      'working_days': workingDays,
      'reason': reason,
      'attachment_url': attachmentUrl,
      'status': status.apiValue,
      'reviewer_id': reviewerId,
      'reviewer_name': reviewer,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'review_note': decisionNote,
      'created_at': submittedAt.toIso8601String(),
      'balance_before': balanceRemaining,
      'balance_after': balanceAfter,
      'team_available': teamAvailable,
      'team_total': teamTotal,
    };
  }

  Map<String, Object?> toInsertMap() {
    final map = toMap();
    map.remove('id');
    return map;
  }

  factory LeaveRequest.fromMap(Map<String, Object?> map) {
    return LeaveRequest(
      id: (map['id'] as num?)?.toInt() ?? 0,
      employeeId: (map['employee_id'] as num?)?.toInt() ?? 0,
      code: (map['code'] as String?) ?? '',
      employeeName: (map['employee_name'] as String?) ?? '',
      nip: (map['nip'] as String?) ?? '',
      team: (map['team'] as String?) ?? '',
      leaveTypeId: (map['leave_type_id'] as num?)?.toInt() ?? 0,
      type:
          (map['leave_type_name'] as String?) ??
          (map['leave_type'] as String?) ??
          '',
      startDate: _parseDate(map['start_date']) ?? DateTime.now(),
      endDate: _parseDate(map['end_date']) ?? DateTime.now(),
      workingDays:
          (map['working_days'] as num?)?.toInt() ??
          (map['requested_days'] as num?)?.toInt() ??
          0,
      reason: (map['reason'] as String?) ?? '',
      attachmentUrl: map['attachment_url'] as String?,
      submittedAt:
          _parseDate(map['created_at'] ?? map['submitted_at']) ??
          DateTime.now(),
      status: RequestStatus.fromApi(map['status'] as String?),
      reviewerId:
          (map['reviewer_id'] as num?)?.toInt() ??
          (map['reviewed_by'] as num?)?.toInt(),
      reviewer: (map['reviewer_name'] as String?) ?? '',
      reviewedAt: _parseDate(map['reviewed_at']),
      decisionNote:
          (map['review_note'] as String?) ??
          (map['decision_note'] as String?) ??
          '',
      balanceRemaining:
          (map['balance_before'] as num?)?.toInt() ??
          (map['balance_remaining'] as num?)?.toInt() ??
          0,
      balanceRequested:
          (map['balance_requested'] as num?)?.toInt() ??
          (map['working_days'] as num?)?.toInt() ??
          0,
      balanceAfter: (map['balance_after'] as num?)?.toInt() ?? 0,
      teamAvailable: (map['team_available'] as num?)?.toInt() ?? 0,
      teamTotal: (map['team_total'] as num?)?.toInt() ?? 0,
    );
  }

  factory LeaveRequest.fromJson(Map<String, Object?> json) {
    final employee = _asMap(json['employee']);
    final leaveType = _asMap(json['leave_type']);

    return LeaveRequest.fromMap({
      'id': json['id'],
      'employee_id': json['employee_id'] ?? employee['id'],
      'employee_name':
          json['employee_name'] ??
          employee['name'] ??
          employee['full_name'] ??
          json['employee'],
      'nip': json['nip'] ?? employee['nip'] ?? employee['employee_number'],
      'team':
          json['team'] ??
          employee['team'] ??
          employee['department'] ??
          employee['department_name'],
      'leave_type_id': json['leave_type_id'] ?? leaveType['id'],
      'leave_type_name': json['leave_type_name'] ?? leaveType['name'],
      'start_date': json['start_date'],
      'end_date': json['end_date'],
      'working_days': json['working_days'] ?? json['requested_days'],
      'reason': json['reason'],
      'attachment_url': json['attachment_url'],
      'status': json['status'],
      'reviewer_id': json['reviewer_id'] ?? json['reviewed_by'],
      'reviewer_name': json['reviewer_name'] ?? json['reviewer'],
      'reviewed_at': json['reviewed_at'],
      'review_note': json['review_note'] ?? json['decision_note'],
      'created_at': json['created_at'] ?? json['submitted_at'],
      'balance_before': json['balance_before'] ?? json['balance_remaining'],
      'balance_requested': json['balance_requested'],
      'balance_after': json['balance_after'],
      'team_available': json['team_available'],
      'team_total': json['team_total'],
    });
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'code': code,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'nip': nip,
      'team': team,
      'leave_type_id': leaveTypeId,
      'leave_type_name': type,
      'start_date': dateKey(startDate),
      'end_date': dateKey(endDate),
      'requested_days': workingDays,
      'reason': reason,
      'attachment_url': attachmentUrl,
      'status': status.apiValue,
      'reviewed_by': reviewerId,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'review_note': decisionNote,
      'created_at': submittedAt.toIso8601String(),
      'balance_before': balanceRemaining,
      'balance_after': balanceAfter,
    };
  }
}

Map<String, Object?> _asMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return Map<String, Object?>.from(value);
  return const <String, Object?>{};
}

DateTime? _parseDate(Object? value) => parseServerDate(value);
