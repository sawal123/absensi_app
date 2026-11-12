import '../../app_database.dart';
import '../../models/user.dart';
import '../../repositories/auth_repository.dart';
import '../api_client.dart';
import '../api_session.dart';
import 'remote_utils.dart';

class HttpAuthRepository extends AuthRepository {
  HttpAuthRepository(this._client) : super(AppDatabase.instance);

  final ApiClient _client;

  @override
  Future<User?> login(String email, String password) async {
    final decoded = await _client.post(
      '/auth/login',
      body: {
        'email': email.trim().toLowerCase(),
        'password': password,
        'device_id': ApiSession.deviceId,
        'device_name': 'mobile',
      },
    );

    final data = asMap(decoded);
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) return null;

    final user = User.fromMap(
      Map<String, Object?>.from(data['user'] as Map? ?? const {}),
    );

    await ApiSession.saveAuth(
      newToken: token,
      newUserId: user.id,
      serverTime: DateTime.tryParse('${data['server_time']}'),
    );

    return user;
  }

  @override
  Future<User?> getById(int id) async {
    try {
      final decoded = await _client.get('/auth/me');
      return User.fromMap(asMap(decoded));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<User>> getAll() async {
    final decoded = await _client.get('/users');
    return asList(decoded).map(User.fromMap).toList();
  }

  @override
  Future<List<User>> getEmployees() async {
    final decoded = await _client.get(
      '/users',
      query: {'role': 'employee'},
    );
    return asList(decoded).map(User.fromMap).toList();
  }

  @override
  Future<User> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
    String position = '',
    String nip = '',
    int? officeLocationId,
  }) async {
    final body = <String, Object?>{
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
      'role': role,
      'position': position.trim(),
      'nip': nip.trim(),
    };
    if (officeLocationId != null) {
      body['office_location_id'] = officeLocationId;
    }

    final decoded = await _client.post('/users', body: body);

    return User.fromMap(asMap(decoded));
  }

  @override
  Future<void> updateUser(User user) async {
    await _client.put(
      '/users/${user.id}',
      body: {
        'name': user.name,
        'email': user.email,
        'role': user.role,
        'nip': user.nip,
        'position': user.position,
        if (user.officeLocationId != null)
          'office_location_id': user.officeLocationId,
      },
    );
  }

  @override
  Future<void> deleteUser(int id) async {
    await _client.delete('/users/$id');
  }

  @override
  Future<void> logout() async {
    try {
      await _client.post('/auth/logout');
    } catch (_) {
      // Token mungkin sudah kedaluwarsa; sesi lokal tetap dibersihkan.
    } finally {
      await ApiSession.clear();
    }
  }
}
