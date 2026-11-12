import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_palette.dart';
import '../../data/api/api_config.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(title: const Text('Kebijakan Privasi')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _Heading('Data yang dikumpulkan'),
          const _Paragraph(
            'Aplikasi ini mengumpulkan data identitas dan kepegawaian '
            '(nama, email, NIP, jabatan, tim, cabang), data absensi, jadwal '
            'shift, pengajuan cuti/izin/sakit, perbaikan absensi, lembur, '
            'serta data penggajian yang diperlukan untuk menjalankan fungsi '
            'kepegawaian.',
          ),
          const _Paragraph(
            'Saat absensi, aplikasi mengumpulkan lokasi presisi, foto selfie, '
            'status mock GPS, hasil liveness, dan skor kemiripan wajah. Foto '
            'wajah referensi hanya digunakan untuk verifikasi kehadiran.',
          ),
          const _Heading('Tujuan penggunaan'),
          const _Paragraph(
            'Data digunakan untuk mencatat kehadiran, memverifikasi lokasi '
            'dan wajah, menghitung jam kerja/lembur, memproses cuti, '
            'menyusun payroll, serta memenuhi kewajiban administrasi '
            'kepegawaian.',
          ),
          const _Heading('Penyimpanan dan keamanan'),
          const _Paragraph(
            'Data dikirim ke server perusahaan melalui HTTPS. Token akses '
            'disimpan di perangkat dan terikat pada perangkat. Foto selfie '
            'dan foto wajah referensi disimpan di penyimpanan privat server, '
            'tidak dipublikasikan sebagai URL publik.',
          ),
          const _Heading('Retensi dan hak Anda'),
          const _Paragraph(
            'Data disimpan selama hubungan kerja dan sesuai kewajiban hukum '
            'perusahaan. Anda dapat meminta akses, koreksi, penghapusan data '
            'wajah, atau penghapusan akun melalui menu Profil atau kontak '
            'berikut.',
          ),
          const _Heading('Kontak'),
          Text(
            'Email: ${ApiConfig.supportEmail}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppPalette.ink,
            ),
          ),
          if (ApiConfig.privacyPolicyUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _openUrl(ApiConfig.privacyPolicyUrl),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Buka kebijakan privasi versi web'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: AppPalette.ink,
        ),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          height: 1.55,
          color: AppPalette.muted,
        ),
      ),
    );
  }
}
