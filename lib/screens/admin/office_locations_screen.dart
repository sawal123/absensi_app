import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../data/models/office_location.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/status_pill.dart';

class OfficeLocationsScreen extends StatelessWidget {
  const OfficeLocationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final locations = admin.locations;

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const Text('Cabang & Lokasi'),
        actions: [
          IconButton(
            tooltip: 'Tambah cabang',
            onPressed: () => _openForm(context, admin),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const InfoBanner(
            icon: Icons.apartment_rounded,
            title: 'Setiap karyawan punya cabangnya sendiri',
            message:
                'Absensi memakai radius dan koordinat cabang yang terhubung '
                'dengan akun karyawan.',
          ),
          if (admin.error != null) ...[
            const SizedBox(height: 12),
            InfoBanner(
              icon: Icons.error_outline_rounded,
              title: 'Gagal memuat cabang',
              message: admin.error!,
              tone: StatusTone.danger,
            ),
          ],
          const SizedBox(height: 14),
          if (locations.isEmpty)
            const EmptyState(
              icon: Icons.location_city_outlined,
              title: 'Belum ada cabang',
              subtitle: 'Tambahkan lokasi kantor terlebih dahulu.',
            )
          else
            for (final location in locations)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              location.name,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: AppPalette.ink,
                              ),
                            ),
                          ),
                          if (location.isDefault)
                            const StatusPill(
                              label: 'Default',
                              tone: StatusTone.success,
                              dense: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        location.address.isEmpty
                            ? '${location.latitude}, ${location.longitude}'
                            : '${location.address} · '
                                  '${location.latitude}, ${location.longitude}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppPalette.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Radius ${location.radiusMeters} m · '
                        '${location.employeesCount} karyawan',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppPalette.faint,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () =>
                                _openForm(context, admin, location),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Ubah'),
                          ),
                          TextButton.icon(
                            onPressed: admin.busy
                                ? null
                                : () =>
                                    _confirmDelete(context, admin, location),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                              color: AppPalette.red,
                            ),
                            label: const Text(
                              'Hapus',
                              style: TextStyle(color: AppPalette.red),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    AdminProvider admin, [
    OfficeLocation? location,
  ]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ChangeNotifierProvider<AdminProvider>.value(
        value: admin,
        child: _LocationDialog(location: location),
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cabang disimpan.')),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AdminProvider admin,
    OfficeLocation location,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus cabang?'),
        content: Text(
          '${location.name} akan dihapus. Karyawan pada cabang ini akan '
          'memakai cabang default.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await admin.deleteLocation(location.id);
    }
  }
}

class _LocationDialog extends StatefulWidget {
  const _LocationDialog({this.location});

  final OfficeLocation? location;

  @override
  State<_LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends State<_LocationDialog> {
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late final TextEditingController _radius;
  late bool _isDefault;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final location = widget.location;
    _name = TextEditingController(text: location?.name ?? '');
    _address = TextEditingController(text: location?.address ?? '');
    _latitude = TextEditingController(
      text: (location?.latitude ?? -6.2).toString(),
    );
    _longitude = TextEditingController(
      text: (location?.longitude ?? 106.816666).toString(),
    );
    _radius = TextEditingController(
      text: '${location?.radiusMeters ?? 100}',
    );
    _isDefault = location?.isDefault ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _radius.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final latitude = double.tryParse(_latitude.text);
    final longitude = double.tryParse(_longitude.text);
    final radius = int.tryParse(_radius.text);
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Nama cabang wajib diisi.');
      return;
    }
    if (latitude == null || longitude == null || radius == null) {
      setState(() => _error = 'Koordinat dan radius harus berupa angka.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await context.read<AdminProvider>().saveLocation(
      OfficeLocation(
        id: widget.location?.id ?? 0,
        name: _name.text.trim(),
        address: _address.text.trim(),
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radius,
        isDefault: _isDefault,
        isActive: true,
      ),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _saving = false;
      _error = context.read<AdminProvider>().error ?? 'Gagal menyimpan.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.location == null ? 'Tambah Cabang' : 'Ubah Cabang'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nama cabang'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _address,
                decoration: const InputDecoration(
                  labelText: 'Alamat (opsional)',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _latitude,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _longitude,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _radius,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Radius absensi (meter)',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Jadikan cabang default'),
                value: _isDefault,
                onChanged: (value) => setState(() => _isDefault = value),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
        ),
      ],
    );
  }
}
