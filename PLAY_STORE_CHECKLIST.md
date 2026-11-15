# Checklist Publikasi Google Play — Absensi Karyawan

Dokumen ini merangkum hal yang **wajib** diselesaikan agar build tidak ditolak
Google Play. Bagian teknis sudah disiapkan di repo; bagian operasional harus
dilengkapi pemilik aplikasi.

## Status teknis saat ini

| Item | Status |
|---|---|
| targetSdkVersion | 36 (memenuhi syarat Play 2026) |
| minSdkVersion | 24 |
| AAB release | Build terverifikasi; **build ulang dengan upload key Anda** sebelum upload |
| 16 KB page size | Lolos verifikasi `zipalign -c -P 16 -v 4` |
| 64-bit | Ya (arm64-v8a, armeabi-v7a, x86_64) |
| Cleartext release | Diblokir (`usesCleartextTraffic=false`) |
| Backup data | Dimatikan (`allowBackup=false`, `fullBackupContent=false`) |
| Izin release | INTERNET, CAMERA, ACCESS_FINE/COARSE_LOCATION, ACCESS_NETWORK_STATE |
| Izin berlebih | RECORD_AUDIO & READ/WRITE_EXTERNAL_STORAGE sudah dihapus |
| Consent sensitif | Ada sebelum izin lokasi/kamera |
| Hapus data wajah | Ada di Profil |
| Hapus akun & data | Ada di Profil + halaman web |
| Kebijakan privasi | Tersedia in-app dan halaman statis backend |

## 1. Wajib sebelum upload (blocker)

### a. Release signing
Build saat ini memakai **debug key** jika `android/key.properties` belum ada.
Play **menolak** AAB debug-signed.

```bash
cd android
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Buat `android/key.properties` (sudah masuk `.gitignore`):

```properties
storePassword=ISI_PASSWORD
keyPassword=ISI_PASSWORD
keyAlias=upload
storeFile=../upload-keystore.jks
```

Jangan commit keystore atau `key.properties`.

Build `assembleRelease`/`bundleRelease` **sengaja gagal** jika `key.properties`
belum ada, sehingga tidak ada AAB debug-signed yang terunggah tanpa sengaja.

Aktifkan **Play App Signing** saat membuat aplikasi di Play Console. Simpan
keystore upload di tempat aman; kehilangan kunci dapat menghambat update.

### b. Backend publik HTTPS
Aplikasi default memakai `https://absen.temuanspace.com/api`. Backend wajib
dapat diakses reviewer:

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://absen.temuanspace.com/api \
  --dart-define=PRIVACY_POLICY_URL=https://absen.temuanspace.com/privacy.html \
  --dart-define=SUPPORT_EMAIL=hr@perusahaan-anda.com
```

Backend juga harus berjalan, sudah di-seed, dan memiliki akun demo yang aktif.

### c. Kebijakan privasi publik
Upload `absensi_backend/public/privacy.html` bersama backend sehingga dapat
diakses tanpa login, misalnya:

- `https://absen.temuanspace.com/privacy.html`
- `https://absen.temuanspace.com/data-deletion.html`

Ganti `hr@example.com` dan alamat perusahaan di kedua halaman.

### d. Application ID unik
`android/app/build.gradle.kts` masih memakai `com.absensi.absensi`. Ganti
dengan ID unik milik perusahaan **sebelum upload pertama**, misalnya
`com.namaperusahaan.absensi`. ID tidak dapat diubah setelah dipublikasikan.

### e. Upload AAB, bukan APK
Play Console menerima **Android App Bundle** untuk aplikasi baru. Gunakan
`app-release.aab` hasil build release yang sudah ditandatangani upload key.

## 2. Isian Play Console

### App access
Buat akun khusus review melalui menu Pengguna (peran admin atau karyawan),
lalu isi kredensialnya di Play Console. Jangan memakai akun admin produksi.

- Catatan: absensi memerlukan lokasi kantor dan kamera. Fitur lain (dashboard,
  cuti, persetujuan, lembur, payroll, notifikasi) dapat diakses tanpa absen.

Jika reviewer tidak berada di radius kantor, pastikan minimal alur login dan
menu utama dapat ditinjau. Pertimbangkan menyediakan cabang demo dengan radius
besar hanya untuk periode review, lalu nonaktifkan kembali.

### Data safety
Isi sesuai perilaku aplikasi (jangan menyembunyikan data):

| Kategori | Data | Dikumpulkan | Tujuan | Dibagikan | Dienkripsi |
|---|---|---|---|---|---|
| Personal info | Nama, email, NIP, jabatan | Ya | Fungsi aplikasi | Tidak* | Ya |
| Location | Lokasi presisi saat absen | Ya | Fungsi aplikasi/verifikasi | Tidak* | Ya |
| Photos & videos | Selfie, foto wajah | Ya | Fungsi aplikasi/verifikasi | Tidak* | Ya |
| Biometric/face | Hash wajah & skor kemiripan | Ya | Verifikasi kehadiran | Tidak* | Ya |
| Financial info | Gaji, tunjangan, potongan | Ya | Fungsi payroll | Tidak* | Ya |
| Health info | Jenis cuti sakit (jika dipakai) | Ya | Administrasi cuti | Tidak* | Ya |
| App activity | Absensi, cuti, lembur, approval | Ya | Fungsi aplikasi | Tidak* | Ya |
| Device/other IDs | Device id acak untuk binding | Ya | Keamanan/fungsi | Tidak* | Ya |

\* Data dikirim ke server perusahaan (pemroses untuk perusahaan). Jika hosting
memakai penyedia pihak ketiga, tinjau definisi "sharing" di Play Console.

Jawab:
- Data terenkripsi saat transit: **Ya** (HTTPS).
- Pengguna dapat meminta penghapusan data: **Ya**.
- Tidak ada iklan dan tidak ada `AD_ID`.

### Account deletion
Play mensyaratkan alur hapus akun + URL publik untuk aplikasi yang memiliki
akun. Keduanya sudah disiapkan:

- In-app: **Profil → Hapus akun & data** (konfirmasi password).
- Web: `https://absen.temuanspace.com/data-deletion.html`
- Server menghapus baris pengguna, absensi, cuti, lembur, payroll, file selfie,
  foto wajah, lampiran, serta menganonimkan payload audit log.

### Permissions / sensitif
- Lokasi hanya **foreground** (saat aplikasi digunakan), bukan background.
- Kamera untuk selfie absensi.
- Tidak ada izin mikrofon/audio, tidak ada akses storage luas.
- Consent screen tampil **sebelum** izin lokasi/kamera diminta.
- Data wajah dijelaskan pada consent + privacy policy (data sensitif).

### Content rating & kategori
- Kategori: Business / Productivity.
- Tidak ada konten kekerasan, seksual, perjudian, atau UGC publik.
- Bukan produk finansial (payroll internal), jadi tidak memerlukan billing Play.

### Employee monitoring
Aplikasi memantau kehadiran karyawan. Pastikan:
- Perusahaan memiliki dasar hukum/kebijakan internal.
- Karyawan menyetujui consent screen.
- Privacy policy menjelaskan pemantauan lokasi/wajah dan retensinya.

## 3. Store listing

- Nama aplikasi: gunakan nama resmi perusahaan (hindari merek pihak lain).
- Ikon Play 512×512 PNG (ikon launcher saat ini masih default Flutter).
- Feature graphic 1024×500.
- Minimal 2 screenshot ponsel.
- Deskripsi singkat & lengkap, sebutkan fitur absensi, cuti, lembur, payroll.
- Kategori Business, email dukungan aktif.

## 4. Pengujian sebelum produksi

1. Build AAB release bertanda tangan upload key.
2. Upload ke **Internal testing**, bukan langsung production.
3. Uji di Android 13/14/15/16:
   - consent muncul sebelum izin,
   - izin lokasi & kamera,
   - absen dengan mock GPS ditolak,
   - liveness & face match,
   - cuti/lembur/approval/notifikasi,
   - export CSV,
   - hapus data wajah dan hapus akun.
4. Periksa **Pre-launch report** Play Console (crash, ANR, aksesibilitas,
   permission).
5. Naikkan `versionCode` (`pubspec.yaml` bagian `+1`) setiap upload.

## 5. Perintah build final

```bash
flutter clean
flutter pub get
flutter analyze
flutter test

flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://absen.temuanspace.com/api \
  --dart-define=PRIVACY_POLICY_URL=https://absen.temuanspace.com/privacy.html \
  --dart-define=SUPPORT_EMAIL=hr@perusahaan-anda.com
```

Hasil: `build/app/outputs/bundle/release/app-release.aab`.
