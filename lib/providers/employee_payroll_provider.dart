import 'package:flutter/foundation.dart';

import '../core/formatters.dart';
import '../core/payroll_calculator.dart';
import '../data/api/absensi_api.dart';
import '../data/models/leave_type.dart';
import '../data/models/payroll_slip.dart';
import '../data/models/salary_allowance.dart';
import '../data/models/salary_profile.dart';
import '../data/models/user.dart';
import '../data/repositories/attendance_repository.dart';
import '../data/repositories/payroll_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/shift_repository.dart';

class EmployeePayrollProvider extends ChangeNotifier {
  EmployeePayrollProvider({
    required User employee,
    required AttendanceRepository attendanceRepository,
    required PayrollRepository payrollRepository,
    required ShiftRepository shiftRepository,
    required SettingsRepository settingsRepository,
    required AbsensiApi api,
    PayrollCalculator calculator = const PayrollCalculator(),
  }) : employee = employee,
       _attendanceRepository = attendanceRepository,
       _payrollRepository = payrollRepository,
       _shiftRepository = shiftRepository,
       _settingsRepository = settingsRepository,
       _api = api,
       _calculator = calculator;

  final User employee;
  final AttendanceRepository _attendanceRepository;
  final PayrollRepository _payrollRepository;
  final ShiftRepository _shiftRepository;
  final SettingsRepository _settingsRepository;
  final AbsensiApi _api;
  final PayrollCalculator _calculator;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  SalaryProfile? _profile;
  PayrollSlip? _liveSlip;
  PayrollSlip? _savedSlip;
  bool _loading = true;
  String? _error;

  int get employeeId => employee.id ?? 0;
  DateTime get month => _month;
  SalaryProfile? get profile => _profile;
  PayrollSlip? get liveSlip => _liveSlip;
  PayrollSlip? get savedSlip => _savedSlip;
  PayrollSlip? get slip => _savedSlip ?? _liveSlip;
  bool get isFinalized => _savedSlip != null;
  bool get hasSalaryProfile => _profile?.isConfigured ?? false;
  bool get loading => _loading;
  String? get error => _error;

  List<SalaryAllowance> _allowances = [];
  List<SalaryAllowance> get allowances => List.unmodifiable(_allowances);

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _profile = await _payrollRepository.getProfile(employeeId);
      _allowances = await _payrollRepository.getAllowancesFor(employeeId);

      final rules = await _payrollRepository.getRules();
      final settings = await _payrollRepository.getSettings();
      final office = await _settingsRepository.getSettings();

      final first = DateTime(_month.year, _month.month, 1);
      final last = endOfMonth(first);
      final records = await _attendanceRepository.getForUserRange(
        employeeId,
        first,
        last,
      );
      final assignments = await _shiftRepository.getEmployeeAssignments(
        employeeId,
        from: first,
        to: last,
      );

      final types = await _api.getLeaveTypes();
      final leaveTypes = <int, LeaveType>{
        for (final type in types) type.id: type,
      };
      final leaves = await _api.getLeaveRequests(
        employeeId: employeeId,
        year: _month.year,
      );

      _liveSlip = _calculator.compute(
        employee: employee,
        profile: _profile,
        allowances: _allowances,
        rules: rules,
        settings: settings,
        office: office,
        attendance: records,
        assignments: assignments,
        approvedLeaves: leaves,
        leaveTypes: leaveTypes,
        year: _month.year,
        month: _month.month,
      );
      _savedSlip = await _payrollRepository.getSlip(
        employeeId,
        _month.year,
        _month.month,
      );
    } catch (error) {
      _error = 'Gagal memuat slip gaji: $error';
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

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
