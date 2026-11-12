import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/server_time.dart';

/// Menyimpan token, device id, dan offset jam server.
abstract final class ApiSession {
  static const _tokenKey = 'api_token';
  static const _userIdKey = 'api_user_id';
  static const _deviceKey = 'api_device_id';
  static const _offsetKey = 'api_server_offset_ms';

  static String? token;
  static int? userId;
  static String deviceId = '';
  static Duration serverOffset = Duration.zero;

  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_tokenKey);
    userId = prefs.getInt(_userIdKey);
    deviceId = prefs.getString(_deviceKey) ?? '';
    serverOffset = Duration(milliseconds: prefs.getInt(_offsetKey) ?? 0);

    if (deviceId.isEmpty) {
      deviceId = _generateDeviceId();
      await prefs.setString(_deviceKey, deviceId);
    }
  }

  static Future<void> saveAuth({
    required String newToken,
    int? newUserId,
    DateTime? serverTime,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    token = newToken;
    if (newUserId != null) {
      userId = newUserId;
      await prefs.setInt(_userIdKey, newUserId);
    }
    await prefs.setString(_tokenKey, newToken);

    if (serverTime != null) {
      final serverWib = parseServerDate(serverTime);
      if (serverWib != null) {
        serverOffset = serverWib.difference(wibNowApprox());
        await prefs.setInt(_offsetKey, serverOffset.inMilliseconds);
      }
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    token = null;
    userId = null;
    serverOffset = Duration.zero;
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_offsetKey);
  }

  static String _generateDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }
}

abstract final class ApiClock {
  static DateTime now() => wibNowApprox().add(ApiSession.serverOffset);
}
