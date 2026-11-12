import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../core/formatters.dart';
import '../../data/models/work_shift.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/surface_card.dart';

class ShiftsScreen extends StatelessWidget {
  const ShiftsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(title: const Text('Kelola Shift')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Tambah shift'),
      ),
      body: Consumer<AdminProvider>(
        builder: (context, admin, _) {
          final shifts = admin.shifts;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              const InfoBanner(
                icon: Icons.schedule_rounded,
                title: 'Template jadwal shift',
                message:
                    'Shift yang dibuat di sini dapat di-plotting ke karyawan '
                    'pada tab Jadwal. Menghapus shift akan mengosongkan '
                    'jadwal karyawan yang memakainya.',
              ),
              const SizedBox(height: 16),
              if (admin.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (shifts.isEmpty)
                const EmptyState(
                  icon: Icons.more_time_outlined,
                  title: 'Belum ada shift',
                  subtitle:
                      'Tambahkan shift pertama untuk mulai mengatur jadwal.',
                )
              else
                for (final shift in shifts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ShiftTile(
                      shift: shift,
                      onEdit: () => _openForm(context, shift: shift),
                      onDelete: () => _confirmDelete(context, shift),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openForm(BuildContext context, {WorkShift? shift}) async {
    final admin = context.read<AdminProvider>();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChangeNotifierProvider<AdminProvider>.value(
        value: admin,
        child: _ShiftForm(
          shift: shift,
          suggestedColor: _suggestColor(admin.shifts),
        ),
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shift == null ? 'Shift berhasil ditambahkan.' : 'Shift diperbarui.',
          ),
        ),
      );
    }
  }

  int _suggestColor(List<WorkShift> shifts) {
    final used = shifts.map((shift) => shift.resolvedColorValue).toSet();
    for (final color in WorkShift.colorPalette) {
      if (!used.contains(color)) return color;
    }
    return WorkShift.colorPalette[shifts.length %
        WorkShift.colorPalette.length];
  }

  Future<void> _confirmDelete(BuildContext context, WorkShift shift) async {
    final admin = context.read<AdminProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus shift?'),
        content: Text(
          'Shift "${shift.name}" akan dihapus. Karyawan yang dijadwalkan '
          'pada shift ini akan menjadi libur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await admin.deleteShift(shift.id!);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Shift dihapus.' : (admin.error ?? 'Gagal menghapus shift.'),
        ),
      ),
    );
    admin.clearError();
  }
}

class _ShiftTile extends StatelessWidget {
  const _ShiftTile({
    required this.shift,
    required this.onEdit,
    required this.onDelete,
  });

  final WorkShift shift;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = Color(shift.resolvedColorValue);
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              shift.crossDay ? Icons.nightlight_round : Icons.wb_sunny_outlined,
              size: 19,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        shift.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.ink,
                        ),
                      ),
                    ),
                    if (!shift.isActive) ...[
                      const SizedBox(width: 6),
                      const _Tag(label: 'Nonaktif', muted: true),
                    ],
                    if (shift.crossDay) ...[
                      const SizedBox(width: 6),
                      const _Tag(label: 'Lintas hari'),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${shift.rangeLabel} · ${shift.hours} jam',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                if ((shift.breakLabel ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    shift.breakLabel!,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppPalette.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              size: 20,
              color: AppPalette.muted,
            ),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Ubah shift')),
              PopupMenuItem(value: 'delete', child: Text('Hapus shift')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: muted ? AppPalette.slate : AppPalette.amberSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: muted ? AppPalette.muted : AppPalette.amber,
        ),
      ),
    );
  }
}

class _ShiftForm extends StatefulWidget {
  const _ShiftForm({this.shift, required this.suggestedColor});

  final WorkShift? shift;
  final int suggestedColor;

  @override
  State<_ShiftForm> createState() => _ShiftFormState();
}

class _ShiftFormState extends State<_ShiftForm> {
  late final TextEditingController _name;
  late final TextEditingController _breakLabel;
  late String _start;
  late String _end;
  late bool _isActive;
  late int _color;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final shift = widget.shift;
    _name = TextEditingController(text: shift?.name ?? '');
    _breakLabel = TextEditingController(text: shift?.breakLabel ?? '');
    _start = shift?.start ?? '08:00';
    _end = shift?.end ?? '17:00';
    _isActive = shift?.isActive ?? true;
    _color = shift?.resolvedColorValue ?? widget.suggestedColor;
  }

  @override
  void dispose() {
    _name.dispose();
    _breakLabel.dispose();
    super.dispose();
  }

  bool get _crossDay => _minutes(_end) <= _minutes(_start);

  static int _minutes(String value) {
    final parts = value.split(':');
    return (int.tryParse(parts.first) ?? 0) * 60 +
        (parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0);
  }

  Future<void> _pickTime({required bool start}) async {
    final current = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(parseTimeOfDay(current)),
    );
    if (picked == null) return;
    final value =
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (start) {
        _start = value;
      } else {
        _end = value;
      }
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Nama shift wajib diisi.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final admin = context.read<AdminProvider>();
    final ok = await admin.saveShift(
      WorkShift(
        id: widget.shift?.id,
        name: _name.text.trim(),
        start: _start,
        end: _end,
        office: admin.settings.officeName,
        breakLabel: _breakLabel.text.trim().isEmpty
            ? null
            : _breakLabel.text.trim(),
        crossDay: _crossDay,
        isActive: _isActive,
        colorValue: _color,
      ),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _saving = false;
      _error = admin.error ?? 'Gagal menyimpan shift.';
    });
    admin.clearError();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 16 + bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.shift == null ? 'Tambah Shift' : 'Ubah Shift',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nama shift',
                  prefixIcon: Icon(Icons.badge_outlined),
                  hintText: 'Contoh: Reguler, Pagi, Shift malam',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TimeField(
                      label: 'Jam mulai',
                      value: _start,
                      onTap: () => _pickTime(start: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeField(
                      label: 'Jam selesai',
                      value: _end,
                      onTap: () => _pickTime(start: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _crossDay
                    ? 'Shift berakhir pada hari berikutnya (lintas hari).'
                    : 'Durasi ${(_minutes(_end) - _minutes(_start)) ~/ 60} jam '
                          '${(_minutes(_end) - _minutes(_start)) % 60} menit.',
                style: const TextStyle(fontSize: 10.5, color: AppPalette.muted),
              ),
              const SizedBox(height: 14),
              const Text(
                'Warna shift',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.ink,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  for (final colorValue in WorkShift.colorPalette)
                    _ColorOption(
                      color: Color(colorValue),
                      selected: _color == colorValue,
                      onTap: () => setState(() => _color = colorValue),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _breakLabel,
                decoration: const InputDecoration(
                  labelText: 'Keterangan istirahat (opsional)',
                  prefixIcon: Icon(Icons.free_breakfast_outlined),
                  hintText: 'Contoh: Istirahat 12.00 – 13.00',
                ),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
                title: const Text(
                  'Shift aktif',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Shift nonaktif tidak muncul saat plotting jadwal.',
                  style: TextStyle(fontSize: 10.5, color: AppPalette.muted),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Simpan Shift'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorOption extends StatelessWidget {
  const _ColorOption({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppPalette.ink : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: selected ? AppPalette.softShadow : null,
        ),
        child: selected
            ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
            : null,
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.schedule),
        ),
        child: Text(
          formatClockValue(value),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppPalette.ink,
          ),
        ),
      ),
    );
  }
}
