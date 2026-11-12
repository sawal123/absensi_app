import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/api/absensi_api.dart';
import 'data/api/api_client.dart';
import 'data/api/api_config.dart';
import 'data/api/api_session.dart';
import 'data/api/dummy_absensi_api.dart';
import 'data/api/dummy_hr_api.dart';
import 'data/api/hr_api.dart';
import 'data/api/http_absensi_api.dart';
import 'data/api/http_hr_api.dart';
import 'data/api/remote/http_attendance_repository.dart';
import 'data/api/remote/http_auth_repository.dart';
import 'data/api/remote/http_payroll_repository.dart';
import 'data/api/remote/http_settings_repository.dart';
import 'data/api/remote/http_shift_repository.dart';
import 'data/app_database.dart';
import 'data/repositories/attendance_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/payroll_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/shift_repository.dart';
import 'data/session_store.dart';
import 'providers/auth_provider.dart';
import 'services/image_service.dart';
import 'services/location_service.dart';
import 'services/report_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiSession.restore();

  final db = AppDatabase.instance;
  final apiClient = ApiClient(baseUrl: ApiConfig.baseUrl);

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        Provider<ApiClient>.value(value: apiClient),
        Provider<HrApi>(
          create: (_) =>
              ApiConfig.useDummy ? DummyHrApi(db) : HttpHrApi(apiClient),
        ),
        Provider<AbsensiApi>(
          create: (_) => ApiConfig.useDummy
              ? DummyAbsensiApi(db)
              : HttpAbsensiApi(
                  baseUrl: ApiConfig.baseUrl,
                  tokenProvider: () => ApiSession.token,
                ),
        ),
        Provider<AuthRepository>(
          create: (_) => ApiConfig.useDummy
              ? AuthRepository(db)
              : HttpAuthRepository(apiClient),
        ),
        Provider<AttendanceRepository>(
          create: (_) => ApiConfig.useDummy
              ? AttendanceRepository(db)
              : HttpAttendanceRepository(apiClient),
        ),
        Provider<PayrollRepository>(
          create: (_) => ApiConfig.useDummy
              ? PayrollRepository(db)
              : HttpPayrollRepository(apiClient),
        ),
        Provider<SettingsRepository>(
          create: (_) => ApiConfig.useDummy
              ? SettingsRepository(db)
              : HttpSettingsRepository(apiClient),
        ),
        Provider<ShiftRepository>(
          create: (_) => ApiConfig.useDummy
              ? ShiftRepository(db)
              : HttpShiftRepository(apiClient),
        ),
        Provider<LocationService>(create: (_) => LocationService()),
        Provider<ImageService>(create: (_) => ImageService()),
        Provider<ReportService>(create: (_) => ReportService(apiClient)),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            repository: context.read<AuthRepository>(),
            session: SessionStore(),
          )..bootstrap(),
        ),
      ],
      child: const AbsensiApp(),
    ),
  );
}
