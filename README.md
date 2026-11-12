# Absensi Karyawan

Aplikasi absensi karyawan Flutter yang terhubung ke backend Laravel
(`../absensi_backend`). Mendukung absensi GPS + selfie, liveness, face match,
shift, cuti, lembur, payroll, multi-cabang, notifikasi, export laporan, dan
audit log.

## Fitur

- Login token Sanctum dengan binding perangkat (`X-Device-Id`).
- Peran: `admin`, `supervisor` (atasan), `employee`.
- Karyawan:
  - Absen masuk/pulang dengan selfie, verifikasi radius kantor, deteksi mock
    GPS, dan liveness (tantangan kedip mata).
  - Face enrollment dan face match terhadap foto referensi.
  - Jadwal shift, cuti/izin/sakit, perbaikan absensi, pengajuan lembur.
  - Riwayat absensi, saldo cuti, slip gaji, notifikasi.
- Atasan:
  - Rekap kehadiran tim, persetujuan cuti, perbaikan absensi, dan lembur.
  - Kelola shift dan payroll.
  - Export laporan CSV absensi/payroll.
- Admin:
  - Kelola karyawan, cabang/lokasi, hari libur, pengaturan kebijakan kantor.
  - Audit log aktivitas API.

## Menjalankan

Backend harus aktif terlebih dahulu (lihat `../absensi_backend/README.md`).

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

- Android emulator: `10.0.2.2`
- iOS simulator / web: `127.0.0.1`
- Perangkat fisik: IP LAN komputer, mis. `http://192.168.1.10:8000/api`

Build debug/profil Android sudah mengizinkan HTTP lokal. Build **release**
wajib memakai HTTPS.

Mode demo lokal tanpa backend:

```bash
flutter run --dart-define=USE_DUMMY_API=true
```

Mode dummy memakai SQLite lokal; liveness/face match dan export laporan
memerlukan backend aktif.

## Akun demo backend

| Peran | Email | Password |
|---|---|---|
| Admin | admin@absensi.com | admin123 |
| Atasan | dewi@absensi.com | 123456 |
| Karyawan | citra@absensi.com | 123456 |

## Anti-fraud

- Mock GPS: `Position.isMocked` dari geolocator ditolak jika kebijakan kantor
  memblokir lokasi palsu.
- Liveness: ML Kit mendeteksi wajah dan transisi mata terbuka → tertutup →
  terbuka sebelum tombol foto aktif.
- Face match: backend membandingkan hash gambar selfie dengan foto wajah
  terdaftar (ambang dapat diatur di Pengaturan).
- Perangkat terikat pada token; login di perangkat lain mencabut token lama.

Catatan: face match memakai kemiripan gambar (dHash), bukan biometrik
sertifikasi. Untuk kebutuhan kepatuhan tinggi, integrasikan SDK face
recognition/liveness berlisensi di backend.

## Izin platform

- Android: INTERNET, CAMERA, lokasi presisi; cleartext hanya di debug/profile.
- iOS: kamera, galeri, lokasi saat digunakan; ML Kit membutuhkan iOS 15+.

### Setup iOS untuk ML Kit (wajib sekali)

Plugin `google_mlkit_face_detection` memakai Swift Package Manager:

1. Tambahkan `-all_load` pada **Build Settings → Other Linker Flags**.
2. Unduh `GoogleMVFaceDetectorResources.bundle` dari rilis
   `d-date/google-mlkit-swiftpm` versi yang dipakai plugin, lalu tambahkan ke
   **Runner → Build Phases → Copy Bundle Resources**.

Tanpa langkah ini, deteksi wajah/liveness di iOS tidak akan berjalan.

## Verifikasi

```bash
flutter analyze
flutter test
```

## Struktur

```
lib/
  core/          # tema, format, jarak, waktu server (WIB)
  data/
    api/         # AbsensiApi, HrApi, ApiClient, sesi token, repository HTTP
    models/      # model data termasuk OfficeLocation, Holiday, Overtime
    repositories/# implementasi lokal (mode dummy)
  providers/     # auth, absensi, pengajuan, payroll, HR
  screens/       # login, karyawan, atasan, admin
  services/      # lokasi, kamera, laporan
  widgets/       # komponen UI bersama
```
