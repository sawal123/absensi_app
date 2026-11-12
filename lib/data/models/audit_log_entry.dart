import '../../core/server_time.dart';

class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    this.userName = '',
    required this.method,
    required this.path,
    required this.statusCode,
    this.ipAddress = '',
    this.payload = const {},
    required this.createdAt,
  });

  final int id;
  final String userName;
  final String method;
  final String path;
  final int statusCode;
  final String ipAddress;
  final Map<String, Object?> payload;
  final DateTime createdAt;

  factory AuditLogEntry.fromJson(Map<String, Object?> json) {
    final rawPayload = json['payload'];
    return AuditLogEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userName: (json['user_name'] as String?) ?? '',
      method: (json['method'] as String?) ?? '',
      path: (json['path'] as String?) ?? '',
      statusCode: (json['status_code'] as num?)?.toInt() ?? 0,
      ipAddress: (json['ip_address'] as String?) ?? '',
      payload: rawPayload is Map
          ? Map<String, Object?>.from(rawPayload)
          : const {},
      createdAt: parseServerDate(json['created_at']) ?? DateTime.now(),
    );
  }
}
