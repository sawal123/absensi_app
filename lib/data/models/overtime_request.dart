import '../../core/server_time.dart';
import 'request_status.dart';

class OvertimeRequest {
  const OvertimeRequest({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    this.nip = '',
    this.team = '',
    required this.date,
    required this.startAt,
    required this.endAt,
    required this.minutes,
    required this.reason,
    required this.status,
    this.reviewerName = '',
    this.reviewNote = '',
    this.reviewedAt,
    required this.createdAt,
  });

  final int id;
  final int employeeId;
  final String employeeName;
  final String nip;
  final String team;
  final DateTime date;
  final DateTime startAt;
  final DateTime endAt;
  final int minutes;
  final String reason;
  final RequestStatus status;
  final String reviewerName;
  final String reviewNote;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  factory OvertimeRequest.fromJson(Map<String, Object?> json) {
    return OvertimeRequest(
      id: (json['id'] as num?)?.toInt() ?? 0,
      employeeId: (json['employee_id'] as num?)?.toInt() ?? 0,
      employeeName: (json['employee_name'] as String?) ?? '',
      nip: (json['nip'] as String?) ?? '',
      team: (json['team'] as String?) ?? '',
      date: parseServerDate(json['date']) ?? DateTime.now(),
      startAt: parseServerDate(json['start_at']) ?? DateTime.now(),
      endAt: parseServerDate(json['end_at']) ?? DateTime.now(),
      minutes: (json['minutes'] as num?)?.toInt() ?? 0,
      reason: (json['reason'] as String?) ?? '',
      status: RequestStatus.fromApi(json['status'] as String?),
      reviewerName: (json['reviewer_name'] as String?) ?? '',
      reviewNote: (json['review_note'] as String?) ?? '',
      reviewedAt: parseServerDate(json['reviewed_at']),
      createdAt: parseServerDate(json['created_at']) ?? DateTime.now(),
    );
  }

  OvertimeRequest copyWith({
    RequestStatus? status,
    String? reviewNote,
    String? reviewerName,
    DateTime? reviewedAt,
  }) {
    return OvertimeRequest(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName,
      nip: nip,
      team: team,
      date: date,
      startAt: startAt,
      endAt: endAt,
      minutes: minutes,
      reason: reason,
      status: status ?? this.status,
      reviewerName: reviewerName ?? this.reviewerName,
      reviewNote: reviewNote ?? this.reviewNote,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdAt: createdAt,
    );
  }
}

class OvertimeDraft {
  const OvertimeDraft({
    required this.date,
    required this.startAt,
    required this.endAt,
    required this.reason,
  });

  final DateTime date;
  final DateTime startAt;
  final DateTime endAt;
  final String reason;

  int get minutes => endAt.difference(startAt).inMinutes;

  Map<String, Object?> toJson() => {
    'date': date.toIso8601String().substring(0, 10),
    'start_at': startAt.toIso8601String(),
    'end_at': endAt.toIso8601String(),
    'reason': reason,
  };
}
