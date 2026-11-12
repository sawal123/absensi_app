import '../app_database.dart';
import '../../core/security.dart';
import '../models/user.dart';

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository(this._db);

  final AppDatabase _db;

  Future<User?> login(String email, String password) async {
    final db = await _db.database;
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final user = User.fromMap(rows.first);
    if (user.passwordHash != hashPassword(password)) return null;
    return user;
  }

  Future<User?> getById(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  Future<List<User>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('users', orderBy: 'role ASC, name ASC');
    return rows.map(User.fromMap).toList();
  }

  Future<List<User>> getEmployees() async {
    final db = await _db.database;
    final rows = await db.query(
      'users',
      where: 'role = ?',
      whereArgs: ['employee'],
      orderBy: 'name ASC',
    );
    return rows.map(User.fromMap).toList();
  }

  Future<User> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
    String position = '',
    String nip = '',
    int? officeLocationId,
  }) async {
    final db = await _db.database;
    final normalizedEmail = email.trim().toLowerCase();
    final exists = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [normalizedEmail],
      limit: 1,
    );
    if (exists.isNotEmpty) {
      throw AuthException('Email sudah terdaftar.');
    }
    final user = User(
      name: name.trim(),
      email: normalizedEmail,
      passwordHash: hashPassword(password),
      role: role,
      position: position.trim(),
      nip: nip.trim(),
      createdAt: DateTime.now(),
    );
    final id = await db.insert('users', user.toMap()..remove('id'));
    return user.copyWith(id: id);
  }

  Future<void> updateUser(User user) async {
    final db = await _db.database;
    await db.update(
      'users',
      user.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<void> deleteUser(int id) async {
    final db = await _db.database;
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  /// Local mode tidak memiliki sesi server.
  Future<void> logout() async {}

  Future<void> deleteAccount({required String password}) async {
    throw UnsupportedError(
      'Penghapusan akun memerlukan backend Laravel aktif.',
    );
  }
}
