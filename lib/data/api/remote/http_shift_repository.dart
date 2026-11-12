import '../../app_database.dart';
import '../../models/work_shift.dart';
import '../../repositories/shift_repository.dart';
import '../../../core/formatters.dart';
import '../api_client.dart';
import 'remote_utils.dart';

class HttpShiftRepository extends ShiftRepository {
  HttpShiftRepository(this._client) : super(AppDatabase.instance);

  final ApiClient _client;

  @override
  Future<List<WorkShift>> getShifts() async {
    final decoded = await _client.get('/shifts');
    return asList(decoded).map(WorkShift.fromMap).toList();
  }

  @override
  Future<WorkShift?> getShift(int id) async {
    final shifts = await getShifts();
    for (final shift in shifts) {
      if (shift.id == id) return shift;
    }
    return null;
  }

  @override
  Future<WorkShift> createShift(WorkShift shift) async {
    final decoded = await _client.post('/shifts', body: _body(shift));
    return WorkShift.fromMap(asMap(decoded));
  }

  @override
  Future<void> updateShift(WorkShift shift) async {
    await _client.put('/shifts/${shift.id}', body: _body(shift));
  }

  @override
  Future<void> deleteShift(int id) async {
    await _client.delete('/shifts/$id');
  }

  @override
  Future<void> assignShift({
    required int employeeId,
    required DateTime date,
    int? shiftId,
  }) {
    return assignShiftDates(
      employeeId: employeeId,
      dates: [date],
      shiftId: shiftId,
    );
  }

  @override
  Future<void> assignShiftDates({
    required int employeeId,
    required Iterable<DateTime> dates,
    int? shiftId,
  }) async {
    await _client.post(
      '/shift-assignments',
      body: {
        'employee_id': employeeId,
        'shift_id': shiftId,
        'dates': [for (final date in dates) dateKey(date)],
      },
    );
  }

  @override
  Future<WorkShift?> getShiftForEmployee(int employeeId, DateTime date) async {
    final decoded = await _client.get(
      '/shift-assignments',
      query: {
        'employee_id': '$employeeId',
        'from': dateKey(date),
        'to': dateKey(date),
      },
    );
    final items = asList(decoded);
    if (items.isEmpty) return null;
    final shift = items.first['shift'];
    if (shift is! Map) return null;
    return WorkShift.fromMap(Map<String, Object?>.from(shift));
  }

  @override
  Future<Map<String, WorkShift>> getEmployeeAssignments(
    int employeeId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final decoded = await _client.get(
      '/shift-assignments',
      query: {
        'employee_id': '$employeeId',
        'from': dateKey(from),
        'to': dateKey(to),
      },
    );

    final result = <String, WorkShift>{};
    for (final item in asList(decoded)) {
      final shift = item['shift'];
      final date = item['date'];
      if (shift is Map && date != null) {
        result['$date'] = WorkShift.fromMap(
          Map<String, Object?>.from(shift),
        );
      }
    }
    return result;
  }

  @override
  Future<Map<String, WorkShift>> getAllAssignments({
    required DateTime from,
    required DateTime to,
  }) async {
    final decoded = await _client.get(
      '/shift-assignments',
      query: {'from': dateKey(from), 'to': dateKey(to)},
    );

    final result = <String, WorkShift>{};
    for (final item in asList(decoded)) {
      final shift = item['shift'];
      final employeeId = item['employee_id'];
      final date = item['date'];
      if (shift is Map && employeeId != null && date != null) {
        result['$employeeId|$date'] = WorkShift.fromMap(
          Map<String, Object?>.from(shift),
        );
      }
    }
    return result;
  }

  Map<String, Object?> _body(WorkShift shift) => {
    'name': shift.name,
    'start_time': shift.start,
    'end_time': shift.end,
    'office': shift.office,
    'break_label': shift.breakLabel,
    'cross_day': shift.crossDay,
    'is_active': shift.isActive,
    'color': shift.colorValue,
  };
}
