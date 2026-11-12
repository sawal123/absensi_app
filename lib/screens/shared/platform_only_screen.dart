import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../providers/auth_provider.dart';

/// Akun platform (super admin) dikelola lewat API/panel web, bukan mobile.
class PlatformOnlyScreen extends StatelessWidget {
  const PlatformOnlyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppPalette.blueSoft,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 38,
                  color: AppPalette.primary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Akun Platform',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Akun super admin hanya digunakan untuk membuat dan mengelola '
                'tenant melalui API/panel platform. Silakan keluar dan masuk '
                'dengan akun perusahaan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.55,
                  color: AppPalette.muted,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.read<AuthProvider>().logout(),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Keluar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
