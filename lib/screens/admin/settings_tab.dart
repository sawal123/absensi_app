import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../data/models/office_settings.dart';
import '../../providers/admin_provider.dart';
import '../../services/location_service.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _radius = TextEditingController();
  final _workStart = TextEditingController();
  final _workEnd = TextEditingController();
  final _earlyCheckIn = TextEditingController();
  final _lateTolerance = TextEditingController();
  final _faceThreshold = TextEditingController();

  bool _synced = false;
  bool _locating = false;
  bool _faceMatchRequired = false;
  bool _overtimeRequiresApproval = true;
  bool _deviceBindingEnabled = true;
  bool _selfieRequired = true;
  bool _mockLocationBlocked = true;

  @override
  void dispose() {
    _name.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _radius.dispose();
    _workStart.dispose();
    _workEnd.dispose();
    _earlyCheckIn.dispose();
    _lateTolerance.dispose();
    _faceThreshold.dispose();
    super.dispose();
  }

  void _syncFrom(OfficeSettings settings) {
    _name.text = settings.officeName;
    _latitude.text = settings.latitude.toString();
    _longitude.text = settings.longitude.toString();
    _radius.text = settings.radiusMeters.toString();
    _workStart.text = settings.workStart;
    _workEnd.text = settings.workEnd;
    _earlyCheckIn.text = settings.earlyCheckInMinutes.toString();
    _lateTolerance.text = settings.lateToleranceMinutes.toString();
    _faceThreshold.text = settings.faceMatchThreshold.toString();
    _faceMatchRequired = settings.faceMatchRequired;
    _overtimeRequiresApproval = settings.overtimeRequiresApproval;
    _deviceBindingEnabled = settings.deviceBindingEnabled;
    _selfieRequired = settings.selfieRequired;
    _mockLocationBlocked = settings.mockLocationBlocked;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, admin, _) {
        if (!_synced && !admin.loading) {
          _synced = true;
          _syncFrom(admin.settings);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionCard(
                  title: 'Lokasi Kantor',
                  subtitle: 'Absensi hanya bisa dilakukan di dalam radius ini.',
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Nama kantor',
                        prefixIcon: Icon(Icons.apartment),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Nama kantor wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latitude,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Latitude',
                            ),
                            validator: (v) => double.tryParse(v ?? '') == null
                                ? 'Angka tidak valid'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _longitude,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Longitude',
                            ),
                            validator: (v) => double.tryParse(v ?? '') == null
                                ? 'Angka tidak valid'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _locating
                          ? null
                          : () => _useCurrentLocation(context),
                      icon: _locating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location, size: 18),
                      label: const Text('Gunakan lokasi saya sekarang'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _radius,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Radius absensi (meter)',
                        prefixIcon: Icon(Icons.radar),
                      ),
                      validator: (v) {
                        final value = int.tryParse(v ?? '');
                        if (value == null || value <= 0) {
                          return 'Masukkan angka lebih dari 0';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Jam Kerja',
                  subtitle:
                      'Jam default dan batas absen sebelum shift dimulai.',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _workStart,
                            readOnly: true,
                            onTap: () => _pickTime(_workStart),
                            decoration: const InputDecoration(
                              labelText: 'Jam masuk',
                              prefixIcon: Icon(Icons.schedule),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _workEnd,
                            readOnly: true,
                            onTap: () => _pickTime(_workEnd),
                            decoration: const InputDecoration(
                              labelText: 'Jam keluar',
                              prefixIcon: Icon(Icons.schedule_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _earlyCheckIn,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Batas absen sebelum shift (menit)',
                        prefixIcon: Icon(Icons.timer_outlined),
                        helperText:
                            'Contoh 60: shift pukul 08.00 hanya bisa absen '
                            'mulai pukul 07.00, tidak bisa pukul 06.00.',
                        helperMaxLines: 3,
                      ),
                      validator: (v) {
                        final value = int.tryParse(v ?? '');
                        if (value == null || value <= 0) {
                          return 'Masukkan angka lebih dari 0';
                        }
                        if (value > 720) {
                          return 'Maksimal 720 menit (12 jam)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _lateTolerance,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Toleransi keterlambatan (menit)',
                        prefixIcon: Icon(Icons.hourglass_bottom_rounded),
                        helperText:
                            'Karyawan tidak dianggap terlambat sampai '
                            'melewati batas ini.',
                      ),
                      validator: (v) {
                        final value = int.tryParse(v ?? '');
                        if (value == null || value < 0) {
                          return 'Masukkan angka 0 atau lebih';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Kebijakan & Anti-Fraud',
                  subtitle:
                      'Kontrol verifikasi wajah, lembur, dan pengamanan '
                      'perangkat.',
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Wajib face match'),
                      subtitle: const Text(
                        'Selfie absensi harus cocok dengan wajah terdaftar.',
                      ),
                      value: _faceMatchRequired,
                      onChanged: (value) =>
                          setState(() => _faceMatchRequired = value),
                    ),
                    if (_faceMatchRequired)
                      TextFormField(
                        controller: _faceThreshold,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Ambang kemiripan wajah (0-64)',
                          helperText:
                              'Semakin kecil semakin ketat. Rekomendasi 10-15.',
                        ),
                        validator: (v) {
                          final value = int.tryParse(v ?? '');
                          if (value == null || value < 0 || value > 64) {
                            return 'Masukkan angka 0-64';
                          }
                          return null;
                        },
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Lembur perlu persetujuan'),
                      subtitle: const Text(
                        'Payroll memakai lembur yang sudah disetujui.',
                      ),
                      value: _overtimeRequiresApproval,
                      onChanged: (value) =>
                          setState(() => _overtimeRequiresApproval = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Binding perangkat'),
                      subtitle: const Text(
                        'Satu akun hanya aktif pada satu perangkat.',
                      ),
                      value: _deviceBindingEnabled,
                      onChanged: (value) =>
                          setState(() => _deviceBindingEnabled = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Selfie wajib'),
                      subtitle: const Text(
                        'Absen masuk/pulang harus menyertakan foto selfie.',
                      ),
                      value: _selfieRequired,
                      onChanged: (value) =>
                          setState(() => _selfieRequired = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Blokir mock GPS'),
                      subtitle: const Text(
                        'Tolak absensi dari lokasi palsu.',
                      ),
                      value: _mockLocationBlocked,
                      onChanged: (value) =>
                          setState(() => _mockLocationBlocked = value),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: admin.busy ? null : () => _save(context, admin),
                  icon: admin.busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Simpan Pengaturan'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final initial = parseTimeOfDay(controller.text);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (picked != null) {
      controller.text =
          '${picked.hour.toString().padLeft(2, '0')}:'
          '${picked.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _useCurrentLocation(BuildContext context) async {
    setState(() => _locating = true);
    try {
      final position = await context
          .read<LocationService>()
          .getCurrentPosition();
      _latitude.text = position.latitude.toStringAsFixed(6);
      _longitude.text = position.longitude.toStringAsFixed(6);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lokasi saat ini berhasil diambil.')),
      );
    } on LocationException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal mengambil lokasi: $e')));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save(BuildContext context, AdminProvider admin) async {
    if (!_formKey.currentState!.validate()) return;
    final settings = OfficeSettings(
      officeName: _name.text.trim(),
      latitude: double.parse(_latitude.text),
      longitude: double.parse(_longitude.text),
      radiusMeters: int.parse(_radius.text),
      workStart: _workStart.text,
      workEnd: _workEnd.text,
      earlyCheckInMinutes: int.parse(_earlyCheckIn.text),
      lateToleranceMinutes: int.parse(_lateTolerance.text),
      faceMatchRequired: _faceMatchRequired,
      faceMatchThreshold: int.parse(_faceThreshold.text),
      overtimeRequiresApproval: _overtimeRequiresApproval,
      deviceBindingEnabled: _deviceBindingEnabled,
      selfieRequired: _selfieRequired,
      mockLocationBlocked: _mockLocationBlocked,
      officeLocationId: admin.settings.officeLocationId,
    );
    final ok = await admin.saveSettings(settings);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Pengaturan berhasil disimpan.'
              : (admin.error ?? 'Gagal menyimpan pengaturan.'),
        ),
      ),
    );
    admin.clearError();
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
