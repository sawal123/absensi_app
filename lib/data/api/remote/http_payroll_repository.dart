import 'dart:convert';

import '../../app_database.dart';
import '../../models/payroll_deduction_rule.dart';
import '../../models/payroll_settings.dart';
import '../../models/payroll_slip.dart';
import '../../models/salary_allowance.dart';
import '../../models/salary_profile.dart';
import '../../repositories/payroll_repository.dart';
import '../api_client.dart';
import 'remote_utils.dart';

class HttpPayrollRepository extends PayrollRepository {
  HttpPayrollRepository(this._client) : super(AppDatabase.instance);

  final ApiClient _client;

  @override
  Future<List<SalaryProfile>> getProfiles() async {
    final decoded = await _client.get('/salary-profiles');
    return asList(decoded).map(SalaryProfile.fromMap).toList();
  }

  @override
  Future<SalaryProfile?> getProfile(int employeeId) async {
    final decoded = await _client.get(
      '/salary-profiles',
      query: {'employee_id': '$employeeId'},
    );
    final items = asList(decoded);
    return items.isEmpty ? null : SalaryProfile.fromMap(items.first);
  }

  @override
  Future<void> saveProfile(SalaryProfile profile) async {
    await _client.post(
      '/salary-profiles',
      body: {
        'employee_id': profile.employeeId,
        'base_salary': profile.baseSalary,
        'overtime_rate': profile.overtimeRate,
        'ptkp_status': profile.ptkpStatus,
        'npwp': profile.npwp,
      },
    );
  }

  @override
  Future<List<SalaryAllowance>> getAllowances() async {
    final decoded = await _client.get('/salary-allowances');
    return asList(decoded).map(SalaryAllowance.fromMap).toList();
  }

  @override
  Future<List<SalaryAllowance>> getAllowancesFor(int employeeId) async {
    final decoded = await _client.get(
      '/salary-allowances',
      query: {'employee_id': '$employeeId'},
    );
    return asList(decoded).map(SalaryAllowance.fromMap).toList();
  }

  @override
  Future<void> replaceAllowances(
    int employeeId,
    List<SalaryAllowance> items,
  ) async {
    await _client.put(
      '/salary-allowances',
      body: {
        'employee_id': employeeId,
        'allowances': [
          for (var index = 0; index < items.length; index++)
            {
              'name': items[index].name,
              'amount': items[index].amount,
              'basis': items[index].basis.apiValue,
              'sort_order': index,
            },
        ],
      },
    );
  }

  @override
  Future<List<PayrollDeductionRule>> getRules() async {
    final decoded = await _client.get('/payroll-deduction-rules');
    return asList(decoded).map(PayrollDeductionRule.fromMap).toList();
  }

  @override
  Future<PayrollDeductionRule> saveRule(PayrollDeductionRule rule) async {
    final body = {
      'name': rule.name,
      'basis': rule.basis.apiValue,
      'rate': rule.rate,
      'is_active': rule.isActive,
      'sort_order': rule.sortOrder,
    };

    final decoded = rule.id == null
        ? await _client.post('/payroll-deduction-rules', body: body)
        : await _client.put('/payroll-deduction-rules/${rule.id}', body: body);

    return PayrollDeductionRule.fromMap(asMap(decoded));
  }

  @override
  Future<void> deleteRule(int id) async {
    await _client.delete('/payroll-deduction-rules/$id');
  }

  @override
  Future<PayrollSettings> getSettings() async {
    final decoded = await _client.get('/payroll-settings');
    final json = asMap(decoded);

    final ptkp = <String, int>{...PayrollSettings.defaultPtkp};
    final rawPtkp = json['ptkp'];
    if (rawPtkp is Map) {
      rawPtkp.forEach((key, value) {
        if (value is num) ptkp['$key'] = value.toInt();
      });
    }

    final brackets = <TaxBracket>[];
    final rawBrackets = json['pph21_brackets'];
    if (rawBrackets is List) {
      for (final item in rawBrackets) {
        if (item is Map) {
          brackets.add(TaxBracket.fromMap(Map<String, Object?>.from(item)));
        }
      }
    }

    return PayrollSettings(
      overtimeEnabled: json['overtime_enabled'] != false,
      overtimeMinMinutes:
          (json['overtime_min_minutes'] as num?)?.toInt() ?? 30,
      ptkp: ptkp,
      pph21Brackets: brackets.isEmpty
          ? PayrollSettings.defaultBrackets
          : brackets,
    );
  }

  @override
  Future<void> saveSettings(PayrollSettings settings) async {
    await _client.put(
      '/payroll-settings',
      body: {
        'overtime_enabled': settings.overtimeEnabled,
        'overtime_min_minutes': settings.overtimeMinMinutes,
        'ptkp': settings.ptkp,
        'pph21_brackets': [
          for (final bracket in settings.pph21Brackets) bracket.toMap(),
        ],
      },
    );
  }

  @override
  Future<PayrollSlip?> getSlip(int employeeId, int year, int month) async {
    final decoded = await _client.get(
      '/payroll-slips',
      query: {
        'year': '$year',
        'month': '$month',
        'employee_id': '$employeeId',
      },
    );
    final items = asList(decoded);
    return items.isEmpty ? null : _slip(items.first);
  }

  @override
  Future<List<PayrollSlip>> getSlips(int year, int month) async {
    final decoded = await _client.get(
      '/payroll-slips',
      query: {'year': '$year', 'month': '$month'},
    );
    return asList(decoded).map(_slip).toList();
  }

  @override
  Future<void> saveSlip(PayrollSlip slip) async {
    await _client.post(
      '/payroll-slips/finalize',
      body: {
        'year': slip.year,
        'month': slip.month,
        'employee_id': slip.employeeId,
      },
    );
  }

  @override
  Future<void> deleteSlips(int year, int month) async {
    await _client.delete(
      '/payroll-slips',
      query: {'year': '$year', 'month': '$month'},
    );
  }

  PayrollSlip _slip(Map<String, Object?> json) {
    final map = Map<String, Object?>.from(json);
    map['breakdown'] = jsonEncode(json['breakdown'] ?? const {});
    map['period_year'] = json['period_year'] ?? json['year'];
    map['period_month'] = json['period_month'] ?? json['month'];
    return PayrollSlip.fromMap(map);
  }
}
