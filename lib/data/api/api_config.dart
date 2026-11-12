abstract final class ApiConfig {
  /// Aktifkan mode demo lokal tanpa backend:
  /// flutter run --dart-define=USE_DUMMY_API=true
  static const bool useDummy = bool.fromEnvironment(
    'USE_DUMMY_API',
    defaultValue: false,
  );

  /// 10.0.2.2 = localhost dari Android emulator.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );
}
