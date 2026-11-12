import 'package:sqflite_common/sqlite_api.dart';

DatabaseFactory get databaseFactoryImpl =>
    throw UnsupportedError('No database factory available on this platform.');

Future<String> resolveDatabasePath() =>
    throw UnsupportedError('No database path available on this platform.');
