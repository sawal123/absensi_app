import '../../app_database.dart';
import '../../models/attendance.dart';
import '../../repositories/attendance_repository.dart';
import '../api_client.dart';
import '../api_session.dart';
import 'remote_utils.dart';

class HttpAttendanceRepository extends AttendanceRepository {
  HttpAttendanceRepository(this._client) : super(AppDatabase.instance);

  final ApiClient _client;

  @override
  Future<Attendance?> getForDate(int userId, String date) async {
    final decoded = await _client.get(
      '/attendances',
      query: {'employee_id': '$userId', 'date': date, 'limit': '1'},
    );
    final items = asList(decoded);
    return items.isEmpty ? null : Attendance.fromMap(items.first);
  }

  @override
  Future<List<Attendance>> getHistory(int userId, {int limit = 90}) async {
    final now = DateTime.now();
    final decoded = await _client.get(
      '/attendances',
      query: {
        'employee_id': '$userId',
        'from': _key(now.subtract(Duration(days: limit))),
        'to': _key(now),
        'limit': '$limit',
      },
    );
    return asList(decoded).map(Attendance.fromMap).toList();
  }

  @override
  Future<List<Attendance>> getForDateAllUsers(String date) async {
    final decoded = await _client.get(
      '/attendances',
      query: {'date': date, 'limit': '500'},
    );
    return asList(decoded).map(Attendance.fromMap).toList();
  }

  @override
  Future<List<Attendance>> getRange(DateTime from, DateTime to) async {
    final decoded = await _client.get(
      '/attendances',
      query: {'from': _key(from), 'to': _key(to), 'limit': '500'},
    );
    return asList(decoded).map(Attendance.fromMap).toList();
  }

  @override
  Future<List<Attendance>> getForUserRange(
    int userId,
    DateTime from,
    DateTime to,
  ) async {
    final decoded = await _client.get(
      '/attendances',
      query: {
        'employee_id': '$userId',
        'from': _key(from),
        'to': _key(to),
        'limit': '500',
      },
    );
    return asList(decoded).map(Attendance.fromMap).toList();
  }

  @override
  Future<Attendance> saveCheckIn(Attendance record) async {
    final decoded = await _client.multipart(
      '/attendance/check-in',
      fields: {
        'latitude': '${record.checkInLat ?? 0}',
        'longitude': '${record.checkInLng ?? 0}',
        'is_mocked': record.isMocked ? '1' : '0',
        'liveness_passed': record.livenessPassed ? '1' : '0',
        'device_id': ApiSession.deviceId,
        'note': record.note,
        if (record.checkInPhoto != null) 'photo': record.checkInPhoto!,
      },
      fileField: 'photo_file',
      filePath: record.checkInPhoto,
    );

    return Attendance.fromMap(asMap(decoded));
  }

  @override
  Future<Attendance> saveCheckOut(Attendance record) async {
    final decoded = await _client.multipart(
      '/attendance/check-out',
      fields: {
        'latitude': '${record.checkOutLat ?? 0}',
        'longitude': '${record.checkOutLng ?? 0}',
        'is_mocked': record.isMocked ? '1' : '0',
        'liveness_passed': record.livenessPassed ? '1' : '0',
        'device_id': ApiSession.deviceId,
        'note': record.note,
        if (record.checkOutPhoto != null) 'photo': record.checkOutPhoto!,
      },
      fileField: 'photo_file',
      filePath: record.checkOutPhoto,
    );

    return Attendance.fromMap(asMap(decoded));
  }

  static String _key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
