import '../../core/server_time.dart';

class Attendance {
  const Attendance({
    this.id,
    required this.userId,
    required this.date,
    this.checkInAt,
    this.checkInLat,
    this.checkInLng,
    this.checkInPhoto,
    this.checkOutAt,
    this.checkOutLat,
    this.checkOutLng,
    this.checkOutPhoto,
    this.note = '',
    this.isMocked = false,
    this.livenessPassed = true,
    this.faceMatchScore,
  });

  final int? id;
  final int userId;

  /// yyyy-MM-dd
  final String date;
  final DateTime? checkInAt;
  final double? checkInLat;
  final double? checkInLng;
  final String? checkInPhoto;
  final DateTime? checkOutAt;
  final double? checkOutLat;
  final double? checkOutLng;
  final String? checkOutPhoto;
  final String note;
  final bool isMocked;
  final bool livenessPassed;
  final int? faceMatchScore;

  bool get hasCheckedIn => checkInAt != null;
  bool get hasCheckedOut => checkOutAt != null;

  Duration? get workDuration {
    if (checkInAt == null || checkOutAt == null) return null;
    return checkOutAt!.difference(checkInAt!);
  }

  Attendance copyWith({
    int? id,
    int? userId,
    String? date,
    DateTime? checkInAt,
    double? checkInLat,
    double? checkInLng,
    String? checkInPhoto,
    DateTime? checkOutAt,
    double? checkOutLat,
    double? checkOutLng,
    String? checkOutPhoto,
    String? note,
    bool? isMocked,
    bool? livenessPassed,
    int? faceMatchScore,
  }) {
    return Attendance(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      checkInAt: checkInAt ?? this.checkInAt,
      checkInLat: checkInLat ?? this.checkInLat,
      checkInLng: checkInLng ?? this.checkInLng,
      checkInPhoto: checkInPhoto ?? this.checkInPhoto,
      checkOutAt: checkOutAt ?? this.checkOutAt,
      checkOutLat: checkOutLat ?? this.checkOutLat,
      checkOutLng: checkOutLng ?? this.checkOutLng,
      checkOutPhoto: checkOutPhoto ?? this.checkOutPhoto,
      note: note ?? this.note,
      isMocked: isMocked ?? this.isMocked,
      livenessPassed: livenessPassed ?? this.livenessPassed,
      faceMatchScore: faceMatchScore ?? this.faceMatchScore,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'date': date,
      'check_in_at': checkInAt?.toIso8601String(),
      'check_in_lat': checkInLat,
      'check_in_lng': checkInLng,
      'check_in_photo': checkInPhoto,
      'check_out_at': checkOutAt?.toIso8601String(),
      'check_out_lat': checkOutLat,
      'check_out_lng': checkOutLng,
      'check_out_photo': checkOutPhoto,
      'note': note,
    };
  }

  factory Attendance.fromMap(Map<String, Object?> map) {
    return Attendance(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      date: map['date'] as String,
      checkInAt: _parseDate(map['check_in_at']),
      checkInLat: (map['check_in_lat'] as num?)?.toDouble(),
      checkInLng: (map['check_in_lng'] as num?)?.toDouble(),
      checkInPhoto: map['check_in_photo'] as String?,
      checkOutAt: _parseDate(map['check_out_at']),
      checkOutLat: (map['check_out_lat'] as num?)?.toDouble(),
      checkOutLng: (map['check_out_lng'] as num?)?.toDouble(),
      checkOutPhoto: map['check_out_photo'] as String?,
      note: (map['note'] as String?) ?? '',
      isMocked: map['is_mocked'] == true,
      livenessPassed: map['liveness_passed'] != false,
      faceMatchScore: (map['face_match_score'] as num?)?.toInt(),
    );
  }

  static DateTime? _parseDate(Object? value) => parseServerDate(value);
}
