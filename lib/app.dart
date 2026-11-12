import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'data/api/absensi_api.dart';
import 'data/api/hr_api.dart';
import 'data/repositories/attendance_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/payroll_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/shift_repository.dart';
import 'providers/admin_provider.dart';
import 'providers/approval_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/employee_payroll_provider.dart';
import 'providers/hr_provider.dart';
import 'providers/my_requests_provider.dart';
import 'providers/payroll_provider.dart';
import 'screens/employee/employee_shell.dart';
import 'screens/login_screen.dart';
import 'screens/shared/consent_gate.dart';
import 'screens/shared/platform_only_screen.dart';
import 'screens/supervisor/supervisor_shell.dart';
import 'services/image_service.dart';
import 'services/location_service.dart';

class AbsensiApp extends StatelessWidget {
  const AbsensiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Absensi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('id'),
      supportedLocales: const [Locale('id')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.initializing) {
          return const _SplashScreen();
        }

        final user = auth.currentUser;
        if (user == null) {
          return const LoginScreen();
        }

        if (user.isSuperAdmin) {
          return const PlatformOnlyScreen();
        }

        if (user.isManager) {
          return ConsentGate(
            key: ValueKey('consent-${user.id}'),
            userId: user.id!,
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider<HrProvider>(
                  key: ValueKey('hr-manager-${user.id}'),
                  create: (context) =>
                      HrProvider(api: context.read<HrApi>(), user: user)
                        ..load(),
                ),
                ChangeNotifierProvider<AdminProvider>(
                  key: ValueKey('admin-${user.id}'),
                  create: (context) => AdminProvider(
                    authRepository: context.read<AuthRepository>(),
                    attendanceRepository: context.read<AttendanceRepository>(),
                    settingsRepository: context.read<SettingsRepository>(),
                    shiftRepository: context.read<ShiftRepository>(),
                  )..load(),
                ),
                ChangeNotifierProvider<ApprovalProvider>(
                  key: ValueKey('approvals-${user.id}'),
                  create: (context) => ApprovalProvider(
                    api: context.read<AbsensiApi>(),
                    reviewerId: user.id!,
                    reviewerName: user.name,
                  )..load(),
                ),
                ChangeNotifierProvider<PayrollProvider>(
                  key: ValueKey('payroll-admin-${user.id}'),
                  create: (context) => PayrollProvider(
                    authRepository: context.read<AuthRepository>(),
                    attendanceRepository: context.read<AttendanceRepository>(),
                    payrollRepository: context.read<PayrollRepository>(),
                    shiftRepository: context.read<ShiftRepository>(),
                    settingsRepository: context.read<SettingsRepository>(),
                    api: context.read<AbsensiApi>(),
                    adminId: user.id!,
                  )..load(),
                ),
              ],
              child: const SupervisorShell(),
            ),
          );
        }

        return ConsentGate(
          key: ValueKey('consent-${user.id}'),
          userId: user.id!,
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider<HrProvider>(
                key: ValueKey('hr-employee-${user.id}'),
                create: (context) =>
                    HrProvider(api: context.read<HrApi>(), user: user)..load(),
              ),
              ChangeNotifierProvider<AttendanceProvider>(
                key: ValueKey('employee-${user.id}'),
                create: (context) => AttendanceProvider(
                  userId: user.id!,
                  repository: context.read<AttendanceRepository>(),
                  settingsRepository: context.read<SettingsRepository>(),
                  shiftRepository: context.read<ShiftRepository>(),
                  locationService: context.read<LocationService>(),
                  imageService: context.read<ImageService>(),
                )..load(),
              ),
              ChangeNotifierProvider<MyRequestsProvider>(
                key: ValueKey('requests-${user.id}'),
                create: (context) => MyRequestsProvider(
                  api: context.read<AbsensiApi>(),
                  hrApi: context.read<HrApi>(),
                  employeeId: user.id!,
                  year: DateTime.now().year,
                )..load(),
              ),
              ChangeNotifierProvider<EmployeePayrollProvider>(
                key: ValueKey('payroll-${user.id}'),
                create: (context) => EmployeePayrollProvider(
                  employee: user,
                  attendanceRepository: context.read<AttendanceRepository>(),
                  payrollRepository: context.read<PayrollRepository>(),
                  shiftRepository: context.read<ShiftRepository>(),
                  settingsRepository: context.read<SettingsRepository>(),
                  api: context.read<AbsensiApi>(),
                )..load(),
              ),
            ],
            child: const EmployeeShell(),
          ),
        );
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                Icons.fingerprint,
                size: 56,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Absensi',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    );
  }
}
