import '../../core/server_time.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type = 'info',
    this.data = const {},
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final Map<String, Object?> data;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, Object?> json) {
    final rawData = json['data'];
    return AppNotification(
      id: '${json['id']}',
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'info',
      data: rawData is Map ? Map<String, Object?>.from(rawData) : const {},
      readAt: parseServerDate(json['read_at']),
      createdAt: parseServerDate(json['created_at']) ?? DateTime.now(),
    );
  }
}
