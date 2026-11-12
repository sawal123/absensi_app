/// Backend Laravel berjalan pada zona Asia/Jakarta (WIB, UTC+7) dan
/// mengirim timestamp ISO-8601 dengan offset. Dart mengubah string ber-offset
/// menjadi UTC, sehingga semua timestamp server harus dipetakan kembali ke WIB
/// agar jam yang ditampilkan sesuai dengan label "WIB" di aplikasi.
const wibOffset = Duration(hours: 7);

DateTime? parseServerDate(Object? value) {
  if (value == null) return null;
  final parsed = value is DateTime
      ? value
      : DateTime.tryParse(value.toString().trim());
  if (parsed == null) return null;

  return parsed.isUtc ? parsed.add(wibOffset) : parsed;
}

DateTime toWib(DateTime value) =>
    value.isUtc ? value.add(wibOffset) : value;

/// Perkiraan waktu WIB dari jam perangkat (sebelum koreksi jam server).
DateTime wibNowApprox() => DateTime.now().toUtc().add(wibOffset);
