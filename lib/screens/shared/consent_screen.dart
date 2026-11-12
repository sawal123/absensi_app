import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../data/api/api_config.dart';
import '../../data/consent_store.dart';
import '../../providers/auth_provider.dart';
import 'privacy_policy_screen.dart';

/// Persetujuan sensitif harus diberikan sebelum izin lokasi/kamera diminta.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({
    super.key,
    required this.userId,
    required this.onAccepted,
  });

  final int userId;
  final VoidCallback onAccepted;

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _agreed = false;

  Future<void> _accept() async {
    await ConsentStore.accept(widget.userId);
    widget.onAccepted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppPalette.blueSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.shield_outlined,
                size: 34,
                color: AppPalette.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Persetujuan Privasi & Data',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppPalette.ink,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sebelum menggunakan absensi, mohon baca bagaimana data Anda '
              'digunakan. Persetujuan ini diperlukan untuk izin lokasi, '
              'kamera, dan verifikasi wajah.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.55,
                color: AppPalette.muted,
              ),
            ),
            const SizedBox(height: 20),
            const _ConsentPoint(
              icon: Icons.badge_outlined,
              title: 'Identitas & kepegawaian',
              body: 'Nama, email, NIP, jabatan, tim, dan cabang.',
            ),
            const _ConsentPoint(
              icon: Icons.location_on_outlined,
              title: 'Lokasi presisi saat absen',
              body: 'Untuk memastikan absensi dilakukan di area kantor.',
            ),
            const _ConsentPoint(
              icon: Icons.face_retouching_natural,
              title: 'Foto selfie & wajah',
              body: 'Untuk bukti kehadiran, liveness, dan pencocokan wajah.',
            ),
            const _ConsentPoint(
              icon: Icons.event_note_outlined,
              title: 'Absensi, cuti, lembur, payroll',
              body: 'Untuk administrasi kehadiran dan penggajian.',
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppPalette.slate,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Data dikirim ke server perusahaan melalui HTTPS. Foto '
                'selfie dan wajah disimpan di penyimpanan privat. Anda dapat '
                'menghapus data wajah atau akun melalui menu Profil.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.55,
                  color: AppPalette.muted,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PrivacyPolicyScreen(),
                ),
              ),
              icon: const Icon(Icons.policy_outlined, size: 18),
              label: const Text('Baca kebijakan privasi lengkap'),
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _agreed,
              onChanged: (value) => setState(() => _agreed = value ?? false),
              title: const Text(
                'Saya telah membaca dan menyetujui penggunaan data di atas.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _agreed ? _accept : null,
              child: const Text('Setuju & Lanjutkan'),
            ),
            TextButton(
              onPressed: () => context.read<AuthProvider>().logout(),
              child: const Text('Tolak & keluar'),
            ),
            const SizedBox(height: 6),
            Text(
              'Kontak privasi: ${ApiConfig.supportEmail}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10.5, color: AppPalette.faint),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsentPoint extends StatelessWidget {
  const _ConsentPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppPalette.blueSoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: AppPalette.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: AppPalette.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
