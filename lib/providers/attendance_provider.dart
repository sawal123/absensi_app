import 'package:flutter/foundation.dart';

import '../core/formatters.dart';
import '../core/geo.dart';
import '../data/api/api_session.dart';
import '../data/models/attendance.dart';
import '../data/models/office_settings.dart';
import '../data/models/work_shift.dart';
import '../data/repositories/attendance_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/shift_repository.dart';
import '../services/image_service.dart';
import '../services/location_service.dart';

class AttendanceProvider extends ChangeNotifier {
  AttendanceProvider({
    required this.userId,
    required AttendanceRepository repository,
    required SettingsRepository settingsRepository,
    required ShiftRepository shiftRepository,
    required LocationService locationService,
    required ImageService imageService,
  }) : _repository = repository,
       _settingsRepository = settingsRepository,
       _shiftRepository = shiftRepository,
       _locationService = locationService,
       _imageService = imageService;

  final int userId;
  final AttendanceRepository _repository;
  final SettingsRepository _settingsRepository;
  final ShiftRepository _shiftRepository;
  final LocationService _locationService;
  final ImageService _imageService;

  OfficeSettings _settings = const OfficeSettings();
  Attendance? _today;
  List<Attendance> _history = [];
  List<WorkShift> _shifts = [];
  Map<String, WorkShift> _assignments = {};
  WorkShift? _todayShift;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  OfficeSettings get settings => _settings;
  Attendance? get today => _today;
  List<Attendance> get history => _history;
  List<WorkShift> get shifts => _shifts;
  WorkShift? get todayShift => _todayShift;
  bool get loading => _loading;
  bool get busy => _busy;
  String? get error => _error;

  WorkShift? shiftFor(DateTime date) => _assignments[dateKey(date)];

  List<ShiftDay> weekOf(DateTime anchor) {
    final start = startOfWeek(anchor);
    return List.generate(7, (index) {
      final date = start.add(Duration(days: index));
      return ShiftDay(date: date, shift: shiftFor(date));
    });
  }

  /// Shift pertama setelah [from] dalam dua minggu ke depan.
  ({DateTime date, WorkShift shift})? nextShift(DateTime from) {
    for (var i = 1; i <= 14; i++) {
      final date = dateOnly(from).add(Duration(days: i));
      final shift = shiftFor(date);
      if (shift != null) return (date: date, shift: shift);
    }
    return null;
  }

  /// Pesan penolakan bila [now] masih terlalu awal untuk absen masuk.
  String? checkInWindowErrorFor(DateTime now) {
    final shift = _todayShift;
    if (shift == null) {
      return 'Tidak ada shift terjadwal hari ini. Hubungi atasan untuk '
          'mengatur jadwal shift Anda.';
    }

    final earliest = dateWithTime(
      now,
      shift.start,
    ).subtract(Duration(minutes: _settings.earlyCheckInMinutes));
    if (now.isBefore(earliest)) {
      return 'Absen masuk baru dibuka pukul ${formatClock(earliest)} WIB. '
          'Maksimal ${_settings.earlyCheckInMinutes} menit sebelum shift '
          'dimulai pukul ${formatClockValue(shift.start)} WIB.';
    }
    return null;
  }

  String? get checkInWindowError => checkInWindowErrorFor(ApiClock.now());

  bool get canCheckIn => !_busy && (_today?.hasCheckedIn != true);
  bool get canCheckOut =>
      !_busy && (_today?.hasCheckedIn == true && _today?.hasCheckedOut != true);

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final now = dateOnly(ApiClock.now());
      _settings = await _settingsRepository.getSettings();
      _shifts = await _shiftRepository.getShifts();
      _assignments = await _shiftRepository.getEmployeeAssignments(
        userId,
        from: now.subtract(const Duration(days: 180)),
        to: now.add(const Duration(days: 180)),
      );
      _todayShift = _assignments[dateKey(now)];
      _today = await _repository.getForDate(userId, dateKey(now));
      _history = await _repository.getHistory(userId);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> clockIn({
    String? photoPath,
    bool livenessPassed = true,
  }) async {
    if (_busy || _today?.hasCheckedIn == true) return false;

    final windowError = checkInWindowErrorFor(ApiClock.now());
    if (windowError != null) {
      _error = windowError;
      notifyListeners();
      return false;
    }

    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final photo = photoPath ?? await _imageService.takeSelfie();
      final position = await _locationService.getCurrentPosition();

      if (_settings.mockLocationBlocked && position.isMocked) {
        _error =
            'Lokasi palsu (mock GPS) terdeteksi. Matikan aplikasi lokasi palsu.';
        return false;
      }

      if (_settings.isConfigured) {
        final distance = distanceInMeters(
          position.latitude,
          position.longitude,
          _settings.latitude,
          _settings.longitude,
        );
        if (distance > _settings.radiusMeters) {
          _error =
              'Anda berada ${formatDistance(distance)} dari '
              '${_settings.officeName}. Maksimal ${_settings.radiusMeters} m.';
          return false;
        }
      }

      final now = ApiClock.now();
      final record = Attendance(
        userId: userId,
        date: dateKey(now),
        checkInAt: now,
        checkInLat: position.latitude,
        checkInLng: position.longitude,
        checkInPhoto: photo,
        isMocked: position.isMocked,
        livenessPassed: livenessPassed,
      );
      _today = await _repository.saveCheckIn(record);
      _history = await _repository.getHistory(userId);
      return true;
    } on ImageException catch (e) {
      _error = e.message;
      return false;
    } on LocationException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Absen masuk gagal: $e';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> clockOut({
    String? photoPath,
    bool livenessPassed = true,
  }) async {
    final current = _today;
    if (_busy ||
        current == null ||
        !current.hasCheckedIn ||
        current.hasCheckedOut) {
      return false;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final photo = photoPath ?? await _imageService.takeSelfie();
      final position = await _locationService.getCurrentPosition();

      if (_settings.mockLocationBlocked && position.isMocked) {
        _error =
            'Lokasi palsu (mock GPS) terdeteksi. Matikan aplikasi lokasi palsu.';
        return false;
      }

      if (_settings.isConfigured) {
        final distance = distanceInMeters(
          position.latitude,
          position.longitude,
          _settings.latitude,
          _settings.longitude,
        );
        if (distance > _settings.radiusMeters) {
          _error =
              'Anda berada ${formatDistance(distance)} dari '
              '${_settings.officeName}. Maksimal ${_settings.radiusMeters} m.';
          return false;
        }
      }

      final now = ApiClock.now();
      final updated = current.copyWith(
        checkOutAt: now,
        checkOutLat: position.latitude,
        checkOutLng: position.longitude,
        checkOutPhoto: photo,
        isMocked: current.isMocked || position.isMocked,
        livenessPassed: current.livenessPassed && livenessPassed,
      );
      _today = await _repository.saveCheckOut(updated);
      _history = await _repository.getHistory(userId);
      return true;
    } on ImageException catch (e) {
      _error = e.message;
      return false;
    } on LocationException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Absen keluar gagal: $e';
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
