import '../../core/formatters.dart';
import '../models/office_settings.dart';
import '../models/work_shift.dart';

/// Shift pattern used by the schedule screens until the roster API exists.
/// Sunday is off, Friday uses the night shift, everything else is regular.
abstract final class DemoSchedule {
  static List<ShiftDay> week(DateTime anchor, OfficeSettings settings) {
    final start = startOfWeek(anchor);
    return List.generate(7, (index) {
      final date = start.add(Duration(days: index));
      return ShiftDay(date: date, shift: shiftFor(date, settings));
    });
  }

  static WorkShift? shiftFor(DateTime date, OfficeSettings settings) {
    if (date.weekday == DateTime.sunday) return null;
    if (date.weekday == DateTime.friday) return nightShift(settings);
    return regularShift(settings);
  }

  static WorkShift regularShift(OfficeSettings settings) {
    return WorkShift(
      name: 'Reguler',
      start: settings.workStart,
      end: settings.workEnd,
      office: settings.officeName,
      breakLabel: 'Istirahat 12.00 – 13.00',
    );
  }

  static WorkShift nightShift(OfficeSettings settings) {
    return WorkShift(
      name: 'Shift malam',
      start: '22:00',
      end: '06:00',
      office: settings.officeName,
      crossDay: true,
    );
  }

  /// The first shift after [from] within the next two weeks.
  static ({DateTime date, WorkShift shift})? nextShift(
    DateTime from,
    OfficeSettings settings,
  ) {
    for (var i = 1; i <= 14; i++) {
      final date = dateOnly(from).add(Duration(days: i));
      final shift = shiftFor(date, settings);
      if (shift != null) return (date: date, shift: shift);
    }
    return null;
  }
}
