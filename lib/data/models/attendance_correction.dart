import '../../core/formatters.dart';
import '../../core/server_time.dart';
import 'correction_type.dart';
import 'request_status.dart';

class AttendanceCorrection {
  const AttendanceCorrection({
    required this.id,
    required this.employeeId,
    required this.code,
    required this.employeeName,
    required this.nip,
    required this.team,
    required this.date,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.correctionType,
    required this.reason,
    required this.submittedAt,
    required this.status,
    this.attendanceId,
    this.recordedCheckIn,
    this.recordedCheckOut,
    this.proposedCheckIn,
    this.proposedCheckOut,
    this.evidenceUrl,
    this.evidenceName = '',
    this.evidenceMeta = '',
    this.reviewerId,
    this.reviewer = '',
    this.reviewedAt,
    this.decisionNote = '',
  });

  final int id;
  final int employeeId;
  final String code;
  final String employeeName;
  final String nip;
  final String team;
  final int? attendanceId;
  final DateTime date;
  final String scheduledStart;
  final String scheduledEnd;
  final DateTime? recordedCheckIn;
  final DateTime? recordedCheckOut;
  final DateTime? proposedCheckIn;
  final DateTime? proposedCheckOut;
  final CorrectionType correctionType;
  final String reason;
  final String? evidenceUrl;
  final String evidenceName;
  final String evidenceMeta;
  final DateTime submittedAt;
  final RequestStatus status;
  final int? reviewerId;
  final String reviewer;
  final DateTime? reviewedAt;
  final String decisionNote;

  AttendanceCorrection copyWith({
    RequestStatus? status,
    String? decisionNote,
    int? reviewerId,
    String? reviewer,
    DateTime? reviewedAt,
    DateTime? recordedCheckIn,
    DateTime? recordedCheckOut,
    int? attendanceId,
  }) {
    return AttendanceCorrection(
      id: id,
      employeeId: employeeId,
      code: code,
      employeeName: employeeName,
      nip: nip,
      team: team,
      attendanceId: attendanceId ?? this.attendanceId,
      date: date,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      recordedCheckIn: recordedCheckIn ?? this.recordedCheckIn,
      recordedCheckOut: recordedCheckOut ?? this.recordedCheckOut,
      proposedCheckIn: proposedCheckIn,
      proposedCheckOut: proposedCheckOut,
      correctionType: correctionType,
      reason: reason,
      evidenceUrl: evidenceUrl,
      evidenceName: evidenceName,
      evidenceMeta: evidenceMeta,
      submittedAt: submittedAt,
      status: status ?? this.status,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewer: reviewer ?? this.reviewer,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      decisionNote: decisionNote ?? this.decisionNote,
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
      'attendance_id': attendanceId,
      'date': dateKey(date),
      'scheduled_start': scheduledStart,
      'scheduled_end': scheduledEnd,
      'recorded_check_in': recordedCheckIn?.toIso8601String(),
      'recorded_check_out': recordedCheckOut?.toIso8601String(),
      'proposed_check_in': proposedCheckIn?.toIso8601String(),
      'proposed_check_out': proposedCheckOut?.toIso8601String(),
      'correction_type': correctionType.apiValue,
      'reason': reason,
      'evidence_url': evidenceUrl,
      'evidence_name': evidenceName,
      'evidence_meta': evidenceMeta,
      'status': status.apiValue,
      'reviewer_id': reviewerId,
      'reviewer_name': reviewer,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'review_note': decisionNote,
      'created_at': submittedAt.toIso8601String(),
    };
  }

  Map<String, Object?> toInsertMap() {
    final map = toMap();
    map.remove('id');
    return map;
  }

  factory AttendanceCorrection.fromMap(Map<String, Object?> map) {
    return AttendanceCorrection(
      id: (map['id'] as num?)?.toInt() ?? 0,
      employeeId: (map['employee_id'] as num?)?.toInt() ?? 0,
      code: (map['code'] as String?) ?? '',
      employeeName: (map['employee_name'] as String?) ?? '',
      nip: (map['nip'] as String?) ?? '',
      team: (map['team'] as String?) ?? '',
      attendanceId: (map['attendance_id'] as num?)?.toInt(),
      date:
          _parseDate(map['date'] ?? map['event_date']) ??
          _parseDate(map['created_at']) ??
          DateTime.now(),
      scheduledStart: (map['scheduled_start'] as String?) ?? '',
      scheduledEnd: (map['scheduled_end'] as String?) ?? '',
      recordedCheckIn: _parseDate(map['recorded_check_in']),
      recordedCheckOut: _parseDate(map['recorded_check_out']),
      proposedCheckIn: _parseDate(map['proposed_check_in']),
      proposedCheckOut: _parseDate(map['proposed_check_out']),
      correctionType: CorrectionType.fromApi(map['correction_type'] as String?),
      reason: (map['reason'] as String?) ?? '',
      evidenceUrl: map['evidence_url'] as String?,
      evidenceName: (map['evidence_name'] as String?) ?? '',
      evidenceMeta: (map['evidence_meta'] as String?) ?? '',
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
    );
  }

  factory AttendanceCorrection.fromJson(Map<String, Object?> json) {
    final employee = _asMap(json['employee']);
    final attendance = _asMap(json['attendance']);

    final recordedIn = json['recorded_check_in_at'] ?? json['recorded_check_in'];
    final recordedOut =
        json['recorded_check_out_at'] ?? json['recorded_check_out'];
    final proposedIn = json['proposed_check_in_at'] ?? json['proposed_check_in'];
    final proposedOut =
        json['proposed_check_out_at'] ?? json['proposed_check_out'];

    return AttendanceCorrection.fromMap({
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
      'attendance_id': json['attendance_id'] ?? attendance['id'],
      'date': json['date'] ?? json['event_date'] ?? attendance['date'],
      'scheduled_start': json['scheduled_start'],
      'scheduled_end': json['scheduled_end'],
      'recorded_check_in': recordedIn,
      'recorded_check_out': recordedOut,
      'proposed_check_in': proposedIn,
      'proposed_check_out': proposedOut,
      'correction_type':
          json['correction_type'] ??
          _inferCorrectionType(proposedIn, proposedOut),
      'reason': json['reason'],
      'evidence_url': json['evidence_url'],
      'evidence_name': json['evidence_name'] ?? _fileName(json['evidence_url']),
      'evidence_meta': json['evidence_meta'],
      'status': json['status'],
      'reviewer_id': json['reviewer_id'] ?? json['reviewed_by'],
      'reviewer_name': json['reviewer_name'] ?? json['reviewer'],
      'reviewed_at': json['reviewed_at'],
      'review_note': json['review_note'] ?? json['decision_note'],
      'created_at': json['created_at'] ?? json['submitted_at'],
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
      'attendance_id': attendanceId,
      'date': dateKey(date),
      'scheduled_start': scheduledStart,
      'scheduled_end': scheduledEnd,
      'recorded_check_in_at': recordedCheckIn?.toIso8601String(),
      'recorded_check_out_at': recordedCheckOut?.toIso8601String(),
      'proposed_check_in_at': proposedCheckIn?.toIso8601String(),
      'proposed_check_out_at': proposedCheckOut?.toIso8601String(),
      'correction_type': correctionType.apiValue,
      'reason': reason,
      'evidence_url': evidenceUrl,
      'status': status.apiValue,
      'reviewed_by': reviewerId,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'review_note': decisionNote,
      'created_at': submittedAt.toIso8601String(),
    };
  }
}

String _inferCorrectionType(Object? proposedIn, Object? proposedOut) {
  if (proposedIn != null && proposedOut != null) return 'both';
  if (proposedOut != null) return 'check_out';
  return 'check_in';
}

String _fileName(Object? url) {
  if (url == null) return '';
  final value = url.toString();
  final parts = value.split('/');
  return parts.isEmpty ? value : parts.last;
}

Map<String, Object?> _asMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return Map<String, Object?>.from(value);
  return const <String, Object?>{};
}

DateTime? _parseDate(Object? value) => parseServerDate(value);
