import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';

import '../data/api/api_client.dart';

class ReportService {
  ReportService(this._client);

  final ApiClient _client;

  Future<String> downloadAttendance({
    required DateTime from,
    required DateTime to,
  }) async {
    final bytes = await _client.download(
      '/reports/attendance',
      query: {'from': _key(from), 'to': _key(to)},
    );

    return _save('absensi-${_key(from)}-sd-${_key(to)}', bytes);
  }

  Future<String> downloadPayroll({required int year, required int month}) async {
    final bytes = await _client.download(
      '/reports/payroll',
      query: {'year': '$year', 'month': '$month'},
    );

    return _save('gaji-$year-${month.toString().padLeft(2, '0')}', bytes);
  }

  Future<String> _save(String name, Uint8List bytes) {
    return FileSaver.instance.saveFile(
      name: name,
      bytes: bytes,
      fileExtension: 'csv',
      mimeType: MimeType.custom,
      customMimeType: 'text/csv',
    );
  }

  static String _key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
