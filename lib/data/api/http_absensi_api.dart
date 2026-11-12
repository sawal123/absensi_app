import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/attendance_correction.dart';
import '../models/leave_balance.dart';
import '../models/leave_request.dart';
import '../models/leave_type.dart';
import '../models/request_status.dart';
import 'absensi_api.dart';
import 'api_exception.dart';
import 'api_session.dart';

/// Laravel REST implementation. Activate with:
///
/// ```bash
/// flutter run --dart-define=USE_DUMMY_API=false \
///   --dart-define=API_BASE_URL=https://server-anda/api
/// ```
class HttpAbsensiApi implements AbsensiApi {
  HttpAbsensiApi({
    required String baseUrl,
    String? Function()? tokenProvider,
    http.Client? client,
  }) : baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _tokenProvider = tokenProvider,
       _client = client ?? http.Client();

  final String baseUrl;
  final String? Function()? _tokenProvider;
  final http.Client _client;

  Map<String, String> get _headers {
    final token = _tokenProvider?.call();
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

  @override
  Future<List<LeaveType>> getLeaveTypes() async {
    final decoded = await _send('GET', '/leave-types');
    return _list(decoded)
        .map((item) => LeaveType.fromJson(item))
        .toList();
  }

  @override
  Future<List<LeaveBalance>> getLeaveBalances({
    required int employeeId,
    required int year,
  }) async {
    final decoded = await _send(
      'GET',
      '/leave-balances',
      query: {'year': year.toString()},
    );
    return _list(decoded)
        .map((item) => LeaveBalance.fromJson(item))
        .toList();
  }

  @override
  Future<List<LeaveRequest>> getLeaveRequests({
    required int employeeId,
    int? year,
  }) async {
    final decoded = await _send(
      'GET',
      '/leave-requests',
      query: {
        'scope': 'mine',
        if (year != null) 'year': year.toString(),
      },
    );
    return _list(decoded).map((item) => LeaveRequest.fromJson(item)).toList();
  }

  @override
  Future<LeaveRequest> createLeaveRequest(LeaveRequestDraft draft) async {
    final decoded = await _send(
      'POST',
      '/leave-requests',
      body: draft.toJson(),
    );
    return LeaveRequest.fromJson(_map(decoded));
  }

  @override
  Future<LeaveRequest> cancelLeaveRequest(
    int id, {
    required int employeeId,
  }) async {
    final decoded = await _send(
      'PATCH',
      '/leave-requests/$id/cancel',
      body: const <String, Object?>{},
    );
    return LeaveRequest.fromJson(_map(decoded));
  }

  @override
  Future<List<LeaveRequest>> getTeamLeaveRequests({
    RequestStatus? status,
  }) async {
    final decoded = await _send(
      'GET',
      '/leave-requests',
      query: {
        'scope': 'team',
        if (status != null) 'status': status.apiValue,
      },
    );
    return _list(decoded).map((item) => LeaveRequest.fromJson(item)).toList();
  }

  @override
  Future<LeaveRequest> reviewLeaveRequest(
    int id, {
    required bool approve,
    String note = '',
    int? reviewerId,
    String reviewerName = '',
  }) async {
    final decoded = await _send(
      'PATCH',
      '/leave-requests/$id/review',
      body: {
        'status': approve ? 'approved' : 'rejected',
        'review_note': note.trim(),
      },
    );
    return LeaveRequest.fromJson(_map(decoded));
  }

  @override
  Future<List<AttendanceCorrection>> getCorrections({
    required int employeeId,
  }) async {
    final decoded = await _send(
      'GET',
      '/attendance-corrections',
      query: {'scope': 'mine'},
    );
    return _list(decoded)
        .map((item) => AttendanceCorrection.fromJson(item))
        .toList();
  }

  @override
  Future<AttendanceCorrection> createCorrection(CorrectionDraft draft) async {
    final decoded = await _send(
      'POST',
      '/attendance-corrections',
      body: draft.toJson(),
    );
    return AttendanceCorrection.fromJson(_map(decoded));
  }

  @override
  Future<AttendanceCorrection> cancelCorrection(
    int id, {
    required int employeeId,
  }) async {
    final decoded = await _send(
      'PATCH',
      '/attendance-corrections/$id/cancel',
      body: const <String, Object?>{},
    );
    return AttendanceCorrection.fromJson(_map(decoded));
  }

  @override
  Future<List<AttendanceCorrection>> getTeamCorrections({
    RequestStatus? status,
  }) async {
    final decoded = await _send(
      'GET',
      '/attendance-corrections',
      query: {
        'scope': 'team',
        if (status != null) 'status': status.apiValue,
      },
    );
    return _list(decoded)
        .map((item) => AttendanceCorrection.fromJson(item))
        .toList();
  }

  @override
  Future<AttendanceCorrection> reviewCorrection(
    int id, {
    required bool approve,
    String note = '',
    int? reviewerId,
    String reviewerName = '',
  }) async {
    final decoded = await _send(
      'PATCH',
      '/attendance-corrections/$id/review',
      body: {
        'status': approve ? 'approved' : 'rejected',
        'review_note': note.trim(),
      },
    );
    return AttendanceCorrection.fromJson(_map(decoded));
  }

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
  }) async {
    final uri = _uri(path, query);
    final encoded = body == null ? null : jsonEncode(body);

    late http.Response response;
    switch (method) {
      case 'GET':
        response = await _client.get(uri, headers: _headers);
      case 'POST':
        response = await _client.post(uri, headers: _headers, body: encoded);
      case 'PATCH':
        response = await _client.patch(uri, headers: _headers, body: encoded);
      case 'PUT':
        response = await _client.put(uri, headers: _headers, body: encoded);
      case 'DELETE':
        response = await _client.delete(uri, headers: _headers);
      default:
        throw ApiException('Metode HTTP tidak didukung: $method');
    }

    Object? decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        decoded = null;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map
          ? (decoded['message']?.toString() ??
                'Permintaan gagal (${response.statusCode}).')
          : 'Permintaan gagal (${response.statusCode}).';
      throw ApiException(message, statusCode: response.statusCode);
    }

    return decoded;
  }

  Map<String, Object?> _map(Object? decoded) {
    if (decoded is Map) {
      final data = decoded['data'];
      if (data is Map) return Map<String, Object?>.from(data);
      return Map<String, Object?>.from(decoded);
    }
    throw ApiException('Format respons tidak valid.');
  }

  List<Map<String, Object?>> _list(Object? decoded) {
    final data = decoded is Map ? decoded['data'] : decoded;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, Object?>.from(item))
          .toList();
    }
    return const [];
  }
}
