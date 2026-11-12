import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

DatabaseFactory get databaseFactoryImpl => databaseFactory;

Future<String> resolveDatabasePath() async =>
    p.join(await getDatabasesPath(), 'absensi.db');
