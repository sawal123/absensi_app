import '../api_exception.dart';

Map<String, Object?> asMap(dynamic decoded) {
  if (decoded is Map) {
    final data = decoded['data'];
    if (data is Map) return Map<String, Object?>.from(data);
    return Map<String, Object?>.from(decoded);
  }
  throw ApiException('Format respons tidak valid.');
}

List<Map<String, Object?>> asList(dynamic decoded) {
  final data = decoded is Map ? decoded['data'] : decoded;
  if (data is List) {
    return data
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList();
  }
  return const [];
}
