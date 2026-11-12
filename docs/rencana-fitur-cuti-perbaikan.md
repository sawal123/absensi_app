# Rencana Fitur Cuti, Izin/Sakit, dan Perbaikan Absensi

Dokumen ini menjelaskan rencana dan hasil implementasi lanjutan fitur absensi
dengan data dummy persisten (SQLite) yang disiapkan agar mudah dipindahkan ke
backend Laravel.

## Ringkasan Fitur

- Karyawan dapat mengajukan **cuti tahunan**, **izin**, dan **sakit**.
- Karyawan dapat mengajukan **perbaikan absensi** (jam masuk, jam pulang, atau
  keduanya) untuk tanggal yang sudah berjalan.
- Karyawan dapat melihat **riwayat pengajuan** dan **membatalkan** pengajuan
  yang masih berstatus `pending`.
- Atasan dapat melihat seluruh pengajuan tim, menyetujui, atau menolak dengan
  catatan.
- Persetujuan perbaikan absensi **benar-benar memperbarui** data `attendance`
  sehingga riwayat karyawan ikut berubah.
- Persetujuan cuti memperbarui `leave_balances.used_days`.
- Semua data bertahan setelah aplikasi ditutup karena disimpan di SQLite.

## Arsitektur

```
Screens (employee / supervisor)
        │
        ▼
Providers
  ├─ MyRequestsProvider      (karyawan: cuti + perbaikan saya)
  └─ ApprovalProvider        (atasan: seluruh pengajuan tim)
        │
        ▼
AbsensiApi  (kontrak abstrak)
  ├─ DummyAbsensiApi   → SQLite lokal (aktif sekarang)
  └─ HttpAbsensiApi    → REST API Laravel (siap dipakai)
```

Titik pergantian backend hanya ada di `lib/data/api/api_config.dart`:

```dart
static const bool useDummy = bool.fromEnvironment(
  'USE_DUMMY_API',
  defaultValue: true,
);
static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000/api',
);
```

Menjalankan dengan backend Laravel:

```bash
flutter run \
  --dart-define=USE_DUMMY_API=false \
  --dart-define=API_BASE_URL=https://server-anda/api
```

## Skema Data (SQLite v3)

Tabel baru mengikuti ERD di `UI dan flow/ERD sistem absensi karyawan.png`.

### `leave_types`
| Kolom | Tipe | Keterangan |
|---|---|---|
| id | INTEGER PK | |
| name | TEXT | Cuti tahunan, Izin, Sakit |
| is_paid | INTEGER | 1 = dibayar |
| max_days_per_year | INTEGER | Hak maksimal per tahun |

### `leave_balances`
| Kolom | Tipe | Keterangan |
|---|---|---|
| id | INTEGER PK | |
| employee_id | INTEGER FK users.id | |
| leave_type_id | INTEGER FK leave_types.id | |
| year | INTEGER | |
| entitled_days | INTEGER | Hak |
| used_days | INTEGER | Terpakai (bertambah saat disetujui) |
| adjustment_days | INTEGER | Penyesuaian manual |

Unik per `(employee_id, leave_type_id, year)`.

### `leave_requests`
Kolom utama: `id`, `code` (unik), `employee_id`, `employee_name`, `nip`,
`team`, `leave_type_id`, `leave_type_name`, `start_date`, `end_date`,
`working_days`, `reason`, `attachment_url`, `status`, `reviewer_id`,
`reviewer_name`, `reviewed_at`, `review_note`, `created_at`,
`balance_before`, `balance_after`, `team_available`, `team_total`.

Status: `pending`, `approved`, `rejected`, `cancelled`.

### `attendance_corrections`
Kolom utama: `id`, `code` (unik), `employee_id`, `employee_name`, `nip`,
`team`, `attendance_id`, `date`, `scheduled_start`, `scheduled_end`,
`recorded_check_in`, `recorded_check_out`, `proposed_check_in`,
`proposed_check_out`, `correction_type`, `reason`, `evidence_url`,
`evidence_name`, `evidence_meta`, `status`, `reviewer_id`, `reviewer_name`,
`reviewed_at`, `review_note`, `created_at`.

`correction_type`: `check_in`, `check_out`, `both`.

## Data Dummy

### Akun demo (tidak berubah)

| Peran | Email | Password |
|---|---|---|
| Admin | admin@absensi.com | admin123 |
| Karyawan | citra@absensi.com | 123456 |
| Karyawan | aditya@absensi.com | 123456 |

### Tipe cuti
| id | Nama | Dibayar | Hak/tahun |
|---|---|---|---|
| 1 | Cuti tahunan | Ya | 12 |
| 2 | Izin | Ya | 3 |
| 3 | Sakit | Ya | 12 |

### Contoh pengajuan cuti
| Karyawan | Tipe | Tanggal | Status |
|---|---|---|---|
| Citra Lestari | Cuti tahunan | hari ini +4 s.d. +5 | pending |
| Eko Saputra | Cuti tahunan | hari ini +7 | pending |
| Dimas Prakoso | Izin | hari ini +2 | pending |
| Fajar Ramadhan | Sakit | hari ini −1 | pending |
| Rina Wulandari | Cuti tahunan | hari ini | approved |
| Budi Santoso | Cuti tahunan | hari ini −5 | rejected |
| Nanda Putri | Sakit | hari ini −8 s.d. −7 | approved |
| Aditya Pratama | Cuti tahunan | hari ini −12 | cancelled |

### Contoh perbaikan absensi
| Karyawan | Jenis | Tanggal | Status |
|---|---|---|---|
| Aditya Pratama | Jam pulang | hari ini −1 | pending |
| Citra Lestari | Jam masuk | hari ini −2 | pending |
| Rina Wulandari | Jam pulang | hari ini −5 | approved |
| Eko Saputra | Jam masuk | hari ini −7 | rejected |
| Nanda Putri | Masuk & pulang | hari ini −3 | pending |

Tanggal seed dihitung saat database pertama kali dibuat. Untuk mengulang data
demo, hapus data aplikasi (atau uninstall lalu install ulang).

## Alur Pengguna

### Karyawan
1. Buka tab **Pengajuan**.
2. Pilih **Ajukan cuti** atau **Ajukan perbaikan absensi**.
3. Isi formulir; saldo cuti dan jumlah hari kerja dihitung otomatis.
4. Kirim; pengajuan muncul dengan status **Menunggu**.
5. Buka detail untuk melihat catatan atasan atau membatalkan pengajuan yang
   masih pending.
6. RIwayat absensi ikut berubah setelah perbaikan disetujui.

### Atasan
1. Login sebagai admin.
2. Buka tab **Persetujuan** (badge menunjukkan jumlah pending).
3. Pilih segmen **Cuti** atau **Perbaikan Absensi**, lalu filter status.
4. Buka detail, isi catatan bila menolak, lalu setujui/tolak.
5. Persetujuan perbaikan langsung memperbarui baris `attendance`.

## Struktur Kode Baru

```
lib/data/api/
  api_config.dart
  api_exception.dart
  absensi_api.dart
  dummy_absensi_api.dart
  http_absensi_api.dart

lib/data/models/
  leave_type.dart
  leave_balance.dart
  correction_type.dart

lib/providers/
  my_requests_provider.dart

lib/screens/employee/
  requests_tab.dart
  leave_request_form_screen.dart
  correction_request_screen.dart
  my_leave_detail_screen.dart
  my_correction_detail_screen.dart

lib/widgets/
  time_change_row.dart
```

## Verifikasi

```bash
flutter pub get
flutter analyze
flutter test
```

Skenario manual:

1. Login `citra@absensi.com` / `123456`.
2. Buka **Pengajuan** → cek saldo dan daftar seed.
3. Ajukan cuti → muncul sebagai pending.
4. Batalkan pengajuan → status menjadi **Dibatalkan**.
5. Ajukan perbaikan absensi.
6. Login `admin@absensi.com` / `admin123`.
7. Setujui perbaikan → login kembali sebagai karyawan dan cek riwayat.
8. Restart aplikasi → data tetap ada.

## Catatan Migrasi ke Laravel

- Kontrak endpoint dan contoh JSON ada di
  [`api-kontrak-laravel.md`](./api-kontrak-laravel.md).
- Auth masih lokal. Saat login dimigrasi, simpan token di `SessionStore` dan
  oper ke `HttpAbsensiApi(tokenProvider: ...)`.
- Untuk development Android, `http://10.0.2.2` memerlukan
  `android:usesCleartextTraffic="true"`.
- Lampiran pada mode dummy hanya menyimpan path lokal. Saat backend aktif,
  unggah file dan simpan URL dari server.
