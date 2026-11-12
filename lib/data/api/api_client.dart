import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'api_session.dart';

/// Pembungkus HTTP tunggal untuk seluruh repository remote.
class ApiClient {
  ApiClient({required String baseUrl, http.Client? client})
    : baseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl,
      _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Map<String, String> get _headers {
    final token = ApiSession.token;
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (ApiSession.deviceId.isNotEmpty) 'X-Device-Id': ApiSession.deviceId,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    return query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: query);
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body, Map<String, String>? query}) =>
      _send('POST', path, body: body, query: query);

  Future<dynamic> put(String path, {Object? body, Map<String, String>? query}) =>
      _send('PUT', path, body: body, query: query);

  Future<dynamic> patch(String path, {Object? body, Map<String, String>? query}) =>
      _send('PATCH', path, body: body, query: query);

  Future<dynamic> delete(
    String path, {
    Map<String, String>? query,
    Object? body,
  }) => _send('DELETE', path, query: query, body: body);

  Future<dynamic> multipart(
    String path, {
    Map<String, String> fields = const {},
    String fileField = 'photo',
    String? filePath,
    String? secondFileField,
    String? secondFilePath,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path));
    request.headers.addAll({
      'Accept': 'application/json',
      if (ApiSession.deviceId.isNotEmpty) 'X-Device-Id': ApiSession.deviceId,
      if (ApiSession.token != null && ApiSession.token!.isNotEmpty)
        'Authorization': 'Bearer ${ApiSession.token}',
    });
    request.fields.addAll(fields);

    if (filePath != null) {
      try {
        request.files.add(await http.MultipartFile.fromPath(fileField, filePath));
      } catch (_) {
        request.fields[fileField] = filePath;
      }
    }
    if (secondFileField != null && secondFilePath != null) {
      try {
        request.files.add(
          await http.MultipartFile.fromPath(secondFileField, secondFilePath),
        );
      } catch (_) {
        request.fields[secondFileField] = secondFilePath;
      }
    }

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Future<Uint8List> download(String path, {Map<String, String>? query}) async {
    final response = await _client.get(_uri(path, query), headers: _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decode(response);
    }

    return response.bodyBytes;
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final uri = _uri(path, query);
    final encoded = body == null ? null : jsonEncode(body);

    late http.Response response;
    switch (method) {
      case 'GET':
        response = await _client.get(uri, headers: _headers);
      case 'POST':
        response = await _client.post(uri, headers: _headers, body: encoded);
      case 'PUT':
        response = await _client.put(uri, headers: _headers, body: encoded);
      case 'PATCH':
        response = await _client.patch(uri, headers: _headers, body: encoded);
      case 'DELETE':
        response = await _client.delete(uri, headers: _headers, body: encoded);
      default:
        throw ApiException('Metode HTTP tidak didukung: $method');
    }

    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    Object? decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        decoded = null;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Permintaan gagal (${response.statusCode}).';
      if (decoded is Map) {
        final raw = decoded['message'];
        if (raw is String && raw.isNotEmpty) {
          message = raw;
        }
        final errors = decoded['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) {
            message = first.first.toString();
          }
        }
      }
      throw ApiException(message, statusCode: response.statusCode);
    }

    return decoded;
  }
}
