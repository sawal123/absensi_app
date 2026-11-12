# Kontrak API Laravel — Cuti & Perbaikan Absensi

Dokumen ini menjadi acuan implementasi backend Laravel. Aplikasi Flutter sudah
memiliki `HttpAbsensiApi` yang memetakan method ke endpoint di bawah ini.

## Konfigurasi

```bash
flutter run \
  --dart-define=USE_DUMMY_API=false \
  --dart-define=API_BASE_URL=https://server-anda/api
```

Default dummy: `http://10.0.2.2:8000/api` (Android emulator).

## Header

```http
Accept: application/json
Content-Type: application/json
Authorization: Bearer {token}
```

Backend Laravel sudah menyediakan autentikasi token Sanctum. Login melalui
`POST /auth/login`, lalu kirim header `Authorization: Bearer {token}`.
`HttpAbsensiApi` menerima `tokenProvider` opsional agar token dari
`SessionStore`/`AuthProvider` bisa langsung dioper.

## Format Respons

Sukses:

```json
{ "data": { } }
```

Daftar:

```json
{ "data": [ ] }
```

Error:

```json
{
  "message": "Saldo cuti tidak mencukupi.",
  "errors": {
    "end_date": ["Tanggal selesai harus setelah tanggal mulai."]
  }
}
```

Aplikasi membaca `message` sebagai pesan utama dan melempar `ApiException`.

## Enum

- Status pengajuan: `pending`, `approved`, `rejected`, `cancelled`
- Jenis perbaikan: `check_in`, `check_out`, `both`

## Endpoint

### Referensi

#### `GET /leave-types`

```json
{
  "data": [
    { "id": 1, "name": "Cuti tahunan", "is_paid": true, "max_days_per_year": 12 },
    { "id": 2, "name": "Izin", "is_paid": true, "max_days_per_year": 3 },
    { "id": 3, "name": "Sakit", "is_paid": true, "max_days_per_year": 12 }
  ]
}
```

#### `GET /leave-balances?year=2026`

Karyawan login. Bila atasan perlu melihat saldo anggota, tambahkan
`?employee_id={id}`.

```json
{
  "data": [
    {
      "id": 1,
      "employee_id": 3,
      "leave_type_id": 1,
      "year": 2026,
      "entitled_days": 12,
      "used_days": 4,
      "adjustment_days": 0,
      "remaining_days": 8
    }
  ]
}
```

### Cuti

#### `GET /leave-requests?year=2026`

Pengajuan milik karyawan login.

#### `GET /leave-requests?scope=team&status=pending`

Pengajuan seluruh tim untuk atasan. `status` opsional.

Resource cuti:

```json
{
  "data": {
    "id": 12,
    "code": "CT-261104-0256",
    "employee_id": 3,
    "employee_name": "Citra Lestari",
    "nip": "0256",
    "team": "Tim Operasional",
    "leave_type_id": 1,
    "leave_type_name": "Cuti tahunan",
    "start_date": "2026-11-13",
    "end_date": "2026-11-14",
    "requested_days": 2,
    "reason": "Acara keluarga di luar kota.",
    "attachment_url": null,
    "status": "pending",
    "reviewed_by": null,
    "reviewed_at": null,
    "review_note": "",
    "created_at": "2026-11-04T09:10:00+07:00",
    "balance_before": 8,
    "balance_after": 6,
    "team_available": 7,
    "team_total": 8
  }
}
```

`balance_before`/`balance_after` dan `team_available`/`team_total` boleh
dihitung server saat resource dibuat.

#### `POST /leave-requests`

```json
{
  "leave_type_id": 1,
  "start_date": "2026-11-13",
  "end_date": "2026-11-14",
  "reason": "Acara keluarga di luar kota.",
  "attachment_url": null
}
```

Respons `201` berisi resource seperti di atas. Validasi minimal:

- `end_date >= start_date`
- hari kerja > 0
- saldo tersedia >= jumlah hari yang diajukan
- alasan wajib diisi

#### `PATCH /leave-requests/{id}/cancel`

Hanya pemilik dan status `pending`.

#### `PATCH /leave-requests/{id}/review`

```json
{
  "status": "approved",
  "review_note": "Disetujui, selamat berlibur."
}
```

Aturan:

- Hanya `pending` yang bisa ditinjau.
- `rejected` wajib `review_note`.
- `approved` menambah `leave_balances.used_days`.
- Isi `reviewed_by`, `reviewed_at`, `review_note`.

### Perbaikan Absensi

#### `GET /attendance-corrections`

Pengajuan milik karyawan login.

#### `GET /attendance-corrections?scope=team&status=pending`

Seluruh tim untuk atasan.

Resource:

```json
{
  "data": {
    "id": 4,
    "code": "PA-261105-0248",
    "employee_id": 1,
    "employee_name": "Aditya Pratama",
    "nip": "0248",
    "team": "Tim Operasional",
    "attendance_id": 21,
    "date": "2026-11-05",
    "scheduled_start": "08:00",
    "scheduled_end": "17:00",
    "recorded_check_in_at": "2026-11-05T07:58:00+07:00",
    "recorded_check_out_at": null,
    "proposed_check_in_at": "2026-11-05T07:58:00+07:00",
    "proposed_check_out_at": "2026-11-05T17:05:00+07:00",
    "correction_type": "check_out",
    "reason": "Lupa absen pulang setelah menyelesaikan rekap stok.",
    "evidence_url": null,
    "status": "pending",
    "reviewed_by": null,
    "reviewed_at": null,
    "review_note": "",
    "created_at": "2026-11-05T09:10:00+07:00"
  }
}
```

#### `POST /attendance-corrections`

```json
{
  "attendance_id": 21,
  "date": "2026-11-05",
  "correction_type": "check_out",
  "proposed_check_in_at": null,
  "proposed_check_out_at": "2026-11-05T17:05:00+07:00",
  "reason": "Lupa absen pulang.",
  "evidence_url": null
}
```

Validasi minimal:

- Minimal satu dari `proposed_check_in_at`/`proposed_check_out_at` terisi.
- Tanggal tidak boleh di masa depan.
- Alasan wajib diisi.

#### `PATCH /attendance-corrections/{id}/cancel`

Hanya pemilik dan status `pending`.

#### `PATCH /attendance-corrections/{id}/review`

```json
{
  "status": "approved",
  "review_note": "Data absensi diperbarui."
}
```

Saat `approved`, server wajib:

1. Mengisi `check_in_at`/`check_out_at` pada `attendances` sesuai waktu usulan.
2. Membuat baris attendance bila belum ada.
3. Menyimpan `reviewed_by`, `reviewed_at`, `review_note`.
4. Menolak bila `review_note` kosong dan status `rejected`.

## Pemetaan Model

| Field JSON | Field Dart |
|---|---|
| `requested_days` | `LeaveRequest.workingDays` |
| `leave_type_name` | `LeaveRequest.type` |
| `employee_name` | `LeaveRequest.employeeName` |
| `review_note` | `LeaveRequest.decisionNote` |
| `reviewed_at` | `LeaveRequest.reviewedAt` |
| `correction_type` | `AttendanceCorrection.correctionType` |
| `proposed_check_in_at` | `AttendanceCorrection.proposedCheckIn` |
| `recorded_check_out_at` | `AttendanceCorrection.recordedCheckOut` |

`fromJson` menerima field flat di atas maupun bentuk nested
(`employee: {...}`, `leave_type: {...}`) agar kompatibel dengan Laravel
API Resource.

## Catatan Development

- Android emulator: `10.0.2.2`; iOS simulator/web: `localhost`.
- HTTP lokal membutuhkan `android:usesCleartextTraffic="true"`.
- Unggah lampiran memakai `POST /uploads` (multipart `file` + `folder`), lalu
  kirim URL hasilnya pada `attachment_url`/`evidence_url`.

## Payroll

Modul gaji di aplikasi masih memakai SQLite lokal lewat `PayrollRepository`.
Backend Laravel sudah menyediakan endpoint padanannya:

- `GET/POST/PUT /salary-profiles`, `GET/PUT/POST /salary-allowances`
- `GET/POST/PUT/DELETE /payroll-deduction-rules`
- `GET/PUT /payroll-settings`
- `GET /payroll-slips?year=&month=`
- `POST /payroll-slips/finalize` dengan body `{ "year": 2026, "month": 10 }`
- `DELETE /payroll-slips?year=&month=` (buka finalisasi)

Perhitungan PPh21 memakai pendapatan bruto tahunan, PTKP, biaya jabatan 5%
(maks. Rp6 juta/tahun), dan tarif progresif UU HPP; hasil bulanan = pajak
tahunan / 12.

## Implementasi Backend

Kode backend ada di [`../../absensi_backend`](../../absensi_backend). Daftar
endpoint lengkap, akun demo, dan cara menjalankan server ada di
[`absensi_backend/README.md`](../../absensi_backend/README.md).

