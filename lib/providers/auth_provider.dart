import 'package:flutter/foundation.dart';

import '../data/models/user.dart';
import '../data/repositories/auth_repository.dart';
import '../data/session_store.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required AuthRepository repository,
    required SessionStore session,
  }) : _repository = repository,
       _session = session;

  final AuthRepository _repository;
  final SessionStore _session;

  User? _currentUser;
  bool _initializing = true;
  bool _busy = false;
  String? _error;

  User? get currentUser => _currentUser;
  bool get initializing => _initializing;
  bool get busy => _busy;
  String? get error => _error;

  Future<void> bootstrap() async {
    final storedId = await _session.readUserId();
    if (storedId != null) {
      _currentUser = await _repository.getById(storedId);
      if (_currentUser == null) {
        await _session.clear();
      }
    }
    _initializing = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final user = await _repository.login(email, password);
      if (user == null) {
        _error = 'Email atau password salah.';
        return false;
      }
      _currentUser = user;
      await _session.saveUserId(user.id!);
      return true;
    } catch (e) {
      _error = 'Gagal masuk: $e';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    await _session.clear();
    _currentUser = null;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    final id = _currentUser?.id;
    if (id == null) return;
    final user = await _repository.getById(id);
    if (user != null) {
      _currentUser = user;
      notifyListeners();
    }
  }
}
