import 'package:flutter/foundation.dart';

import '../core/formatters.dart';
import '../core/payroll_calculator.dart';
import '../data/api/absensi_api.dart';
import '../data/models/attendance.dart';
import '../data/models/leave_request.dart';
import '../data/models/leave_type.dart';
import '../data/models/office_settings.dart';
import '../data/models/payroll_deduction_rule.dart';
import '../data/models/payroll_settings.dart';
import '../data/models/payroll_slip.dart';
import '../data/models/request_status.dart';
import '../data/models/salary_allowance.dart';
import '../data/models/salary_profile.dart';
import '../data/models/user.dart';
import '../data/models/work_shift.dart';
import '../data/repositories/attendance_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/payroll_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/shift_repository.dart';

class PayrollProvider extends ChangeNotifier {
  PayrollProvider({
    required AuthRepository authRepository,
    required AttendanceRepository attendanceRepository,
    required PayrollRepository payrollRepository,
    required ShiftRepository shiftRepository,
    required SettingsRepository settingsRepository,
    required AbsensiApi api,
    required int adminId,
    PayrollCalculator calculator = const PayrollCalculator(),
  }) : _authRepository = authRepository,
       _attendanceRepository = attendanceRepository,
       _payrollRepository = payrollRepository,
       _shiftRepository = shiftRepository,
       _settingsRepository = settingsRepository,
       _api = api,
       _adminId = adminId,
       _calculator = calculator;

  final AuthRepository _authRepository;
  final AttendanceRepository _attendanceRepository;
  final PayrollRepository _payrollRepository;
  final ShiftRepository _shiftRepository;
  final SettingsRepository _settingsRepository;
  final AbsensiApi _api;
  final int _adminId;
  final PayrollCalculator _calculator;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<User> _employees = [];
  Map<int, SalaryProfile> _profiles = {};
  Map<int, List<SalaryAllowance>> _allowances = {};
  List<PayrollDeductionRule> _rules = [];
  PayrollSettings _settings = PayrollSettings.defaults();
  OfficeSettings _office = const OfficeSettings();
  Map<int, LeaveType> _leaveTypes = {};
  Map<int, PayrollSlip> _liveSlips = {};
  Map<int, PayrollSlip> _savedSlips = {};
  bool _loading = true;
  bool _busy = false;
  String? _error;

  DateTime get month => _month;
  List<User> get employees => _employees;
  List<PayrollDeductionRule> get rules => _rules;
  PayrollSettings get settings => _settings;
  bool get loading => _loading;
  bool get busy => _busy;
  String? get error => _error;
  bool get isFinalized => _savedSlips.isNotEmpty;
  int get finalizedCount => _savedSlips.length;

  SalaryProfile? profileFor(int employeeId) => _profiles[employeeId];

  List<SalaryAllowance> allowancesFor(int employeeId) =>
      List.unmodifiable(_allowances[employeeId] ?? const []);

  PayrollSlip? liveSlipFor(int employeeId) => _liveSlips[employeeId];

  PayrollSlip? savedSlipFor(int employeeId) => _savedSlips[employeeId];

  PayrollSlip? slipFor(int employeeId) =>
      _savedSlips[employeeId] ?? _liveSlips[employeeId];

  List<PayrollSlip> get slips {
    final result = <PayrollSlip>[];
    for (final employee in _employees) {
      final id = employee.id;
      if (id == null) continue;
      final slip = _savedSlips[id] ?? _liveSlips[id];
      if (slip != null) result.add(slip);
    }
    return result;
  }

  int get totalNetPay => slips.fold<int>(0, (sum, slip) => sum + slip.netPay);

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _employees = await _authRepository.getEmployees();

      final profiles = await _payrollRepository.getProfiles();
      _profiles = {for (final profile in profiles) profile.employeeId: profile};

      final allowances = await _payrollRepository.getAllowances();
      final allowanceMap = <int, List<SalaryAllowance>>{};
      for (final allowance in allowances) {
        allowanceMap.putIfAbsent(allowance.employeeId, () => []).add(allowance);
      }
      _allowances = allowanceMap;

      _rules = await _payrollRepository.getRules();
      _settings = await _payrollRepository.getSettings();
      _office = await _settingsRepository.getSettings();

      final types = await _api.getLeaveTypes();
      _leaveTypes = {for (final type in types) type.id: type};

      final leaves = await _api.getTeamLeaveRequests(
        status: RequestStatus.approved,
      );

      final first = DateTime(_month.year, _month.month, 1);
      final last = endOfMonth(first);
      final records = await _attendanceRepository.getRange(first, last);
      final assignments = await _shiftRepository.getAllAssignments(
        from: first,
        to: last,
      );

      final saved = await _payrollRepository.getSlips(
        _month.year,
        _month.month,
      );
      _savedSlips = {for (final slip in saved) slip.employeeId: slip};

      final recordsByUser = <int, List<Attendance>>{};
      for (final record in records) {
        recordsByUser.putIfAbsent(record.userId, () => []).add(record);
      }

      final leavesByUser = <int, List<LeaveRequest>>{};
      for (final leave in leaves) {
        leavesByUser.putIfAbsent(leave.employeeId, () => []).add(leave);
      }

      final assignmentsByUser = <int, Map<String, WorkShift>>{};
      for (final entry in assignments.entries) {
        final parts = entry.key.split('|');
        if (parts.length != 2) continue;
        final employeeId = int.tryParse(parts.first);
        if (employeeId == null) continue;
        assignmentsByUser.putIfAbsent(employeeId, () => {})[parts.last] =
            entry.value;
      }

      final live = <int, PayrollSlip>{};
      for (final employee in _employees) {
        final id = employee.id;
        if (id == null) continue;
        live[id] = _calculator.compute(
          employee: employee,
          profile: _profiles[id],
          allowances: _allowances[id] ?? const [],
          rules: _rules,
          settings: _settings,
          office: _office,
          attendance: recordsByUser[id] ?? const [],
          assignments: assignmentsByUser[id] ?? const {},
          approvedLeaves: leavesByUser[id] ?? const [],
          leaveTypes: _leaveTypes,
          year: _month.year,
          month: _month.month,
        );
      }
      _liveSlips = live;
    } catch (error) {
      _error = 'Gagal memuat data gaji: $error';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> selectMonth(DateTime month) async {
    final next = DateTime(month.year, month.month);
    if (next.year == _month.year && next.month == _month.month) return;
    _month = next;
    await load();
  }

  Future<bool> saveSalarySetup({
    required User employee,
    required SalaryProfile profile,
    required List<SalaryAllowance> allowances,
  }) async {
    final employeeId = employee.id;
    if (employeeId == null) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _payrollRepository.saveProfile(profile);
      await _payrollRepository.replaceAllowances(employeeId, allowances);
      await load();
      return true;
    } catch (error) {
      _error = 'Gagal menyimpan gaji karyawan: $error';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> saveRule(PayrollDeductionRule rule) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _payrollRepository.saveRule(rule);
      await load();
      return true;
    } catch (error) {
      _error = 'Gagal menyimpan komponen potongan: $error';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> deleteRule(int id) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _payrollRepository.deleteRule(id);
      await load();
      return true;
    } catch (error) {
      _error = error.toString().replaceFirst('Bad state: ', '');
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> savePayrollSettings(PayrollSettings settings) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _payrollRepository.saveSettings(settings);
      _settings = settings;
      return true;
    } catch (error) {
      _error = 'Gagal menyimpan pengaturan gaji: $error';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> finalizeMonth() async {
    if (_liveSlips.isEmpty) {
      _error = 'Belum ada slip yang bisa difinalisasi.';
      notifyListeners();
      return false;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final now = DateTime.now();
      for (final slip in _liveSlips.values) {
        await _payrollRepository.saveSlip(
          slip.copyWith(finalizedAt: now, finalizedBy: _adminId),
        );
      }
      await load();
      return true;
    } catch (error) {
      _error = 'Gagal memfinalisasi gaji: $error';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> reopenMonth() async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _payrollRepository.deleteSlips(_month.year, _month.month);
      await load();
      return true;
    } catch (error) {
      _error = 'Gagal membuka finalisasi: $error';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
