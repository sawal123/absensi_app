import 'package:flutter/foundation.dart';

import '../core/formatters.dart';
import '../data/models/attendance.dart';
import '../data/models/office_location.dart';
import '../data/models/office_settings.dart';
import '../data/models/user.dart';
import '../data/models/work_shift.dart';
import '../data/repositories/attendance_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/shift_repository.dart';

class AdminProvider extends ChangeNotifier {
  AdminProvider({
    required AuthRepository authRepository,
    required AttendanceRepository attendanceRepository,
    required SettingsRepository settingsRepository,
    required ShiftRepository shiftRepository,
  }) : _authRepository = authRepository,
       _attendanceRepository = attendanceRepository,
       _settingsRepository = settingsRepository,
       _shiftRepository = shiftRepository;

  final AuthRepository _authRepository;
  final AttendanceRepository _attendanceRepository;
  final SettingsRepository _settingsRepository;
  final ShiftRepository _shiftRepository;

  List<User> _users = [];
  List<Attendance> _records = [];
  List<WorkShift> _shifts = [];
  List<OfficeLocation> _locations = [];
  Map<String, WorkShift> _assignments = {};
  DateTime _selectedDate = DateTime.now();
  OfficeSettings _settings = const OfficeSettings();
  bool _loading = true;
  bool _busy = false;
  String? _error;

  List<User> get users => _users;
  List<User> get employees =>
      _users.where((u) => u.role == 'employee').toList();
  List<Attendance> get records => _records;
  List<WorkShift> get shifts => _shifts;
  List<OfficeLocation> get locations => List.unmodifiable(_locations);
  DateTime get selectedDate => _selectedDate;
  OfficeSettings get settings => _settings;
  bool get loading => _loading;
  bool get busy => _busy;
  String? get error => _error;

  WorkShift? shiftForEmployee(int employeeId, [DateTime? date]) {
    final day = date ?? _selectedDate;
    return _assignments['$employeeId|${dateKey(day)}'];
  }

  User? userById(int id) {
    for (final user in _users) {
      if (user.id == id) return user;
    }
    return null;
  }

  int get presentCount => _records.where((r) => r.hasCheckedIn).length;

  int get lateCount => _records
      .where(
        (r) =>
            r.hasCheckedIn &&
            isLate(
              r.checkInAt!,
              shiftForEmployee(r.userId)?.start ?? _settings.workStart,
              _settings.lateToleranceMinutes,
            ),
      )
      .length;

  int get completedCount => _records.where((r) => r.hasCheckedOut).length;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      _settings = await _settingsRepository.getSettings();
      _users = await _authRepository.getAll();
      _records = await _attendanceRepository.getForDateAllUsers(
        dateKey(_selectedDate),
      );
      _shifts = await _shiftRepository.getShifts();
      _locations = await _settingsRepository.getLocations();
      await _loadAssignments();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> selectDate(DateTime date) async {
    _selectedDate = date;
    _loading = true;
    notifyListeners();
    try {
      _records = await _attendanceRepository.getForDateAllUsers(dateKey(date));
      await _loadAssignments();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadAssignments() async {
    _assignments = await _shiftRepository.getAllAssignments(
      from: _selectedDate.subtract(const Duration(days: 120)),
      to: _selectedDate.add(const Duration(days: 120)),
    );
  }

  Future<bool> saveShift(WorkShift shift) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      if (shift.id == null) {
        await _shiftRepository.createShift(shift);
      } else {
        await _shiftRepository.updateShift(shift);
      }
      _shifts = await _shiftRepository.getShifts();
      await _loadAssignments();
      return true;
    } catch (e) {
      _error = 'Gagal menyimpan shift: $e';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> deleteShift(int id) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _shiftRepository.deleteShift(id);
      _shifts = await _shiftRepository.getShifts();
      await _loadAssignments();
      return true;
    } catch (e) {
      _error = 'Gagal menghapus shift: $e';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> assignShift({required int employeeId, int? shiftId}) {
    return assignShiftDates(
      employeeId: employeeId,
      dates: [_selectedDate],
      shiftId: shiftId,
    );
  }

  /// Menetapkan shift yang sama ke banyak tanggal sekaligus.
  Future<bool> assignShiftDates({
    required int employeeId,
    required Iterable<DateTime> dates,
    int? shiftId,
  }) async {
    if (dates.isEmpty) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _shiftRepository.assignShiftDates(
        employeeId: employeeId,
        dates: dates,
        shiftId: shiftId,
      );
      await _loadAssignments();
      return true;
    } catch (e) {
      _error = 'Gagal menyimpan plotting shift: $e';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> addEmployee({
    required String name,
    required String email,
    required String password,
    required String position,
    String nip = '',
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _authRepository.createUser(
        name: name,
        email: email,
        password: password,
        role: 'employee',
        position: position,
        nip: nip,
      );
      _users = await _authRepository.getAll();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('AuthException: ', '');
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> deleteEmployee(int id) async {
    _busy = true;
    notifyListeners();
    try {
      await _authRepository.deleteUser(id);
      _users = await _authRepository.getAll();
      _records = await _attendanceRepository.getForDateAllUsers(
        dateKey(_selectedDate),
      );
      return true;
    } catch (e) {
      _error = 'Gagal menghapus karyawan: $e';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> saveSettings(OfficeSettings settings) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _settingsRepository.saveSettings(settings);
      _settings = settings;
      _locations = await _settingsRepository.getLocations();
      return true;
    } catch (e) {
      _error = 'Gagal menyimpan pengaturan: $e';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> saveLocation(OfficeLocation location) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _settingsRepository.saveLocation(location);
      _locations = await _settingsRepository.getLocations();
      return true;
    } catch (e) {
      _error = 'Gagal menyimpan cabang: $e';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> deleteLocation(int id) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _settingsRepository.deleteLocation(id);
      _locations = await _settingsRepository.getLocations();
      return true;
    } catch (e) {
      _error = 'Gagal menghapus cabang: $e';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
