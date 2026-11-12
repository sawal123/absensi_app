import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../core/formatters.dart';
import '../../data/models/holiday.dart';
import '../../providers/hr_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/status_pill.dart';

class HolidaysScreen extends StatelessWidget {
  const HolidaysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hr = context.watch<HrProvider>();
    final holidays = [...hr.holidays]
      ..sort((a, b) => a.date.compareTo(b.date));

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const Text('Hari Libur'),
        actions: [
          IconButton(
            tooltip: 'Tambah hari libur',
            onPressed: () => _openForm(context, hr),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: hr.load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const InfoBanner(
              icon: Icons.info_outline_rounded,
              title: 'Hari libur memengaruhi cuti & payroll',
              message:
                  'Hari libur tidak dihitung sebagai hari kerja pada '
                  'pengajuan cuti dan perhitungan gaji.',
            ),
            if (hr.error != null) ...[
              const SizedBox(height: 12),
              InfoBanner(
                icon: Icons.error_outline_rounded,
                title: 'Gagal memuat hari libur',
                message: hr.error!,
                tone: StatusTone.danger,
              ),
            ],
            const SizedBox(height: 14),
            if (holidays.isEmpty)
              const EmptyState(
                icon: Icons.event_busy_outlined,
                title: 'Belum ada hari libur',
                subtitle: 'Tambahkan hari libur nasional atau cuti bersama.',
              )
            else
              for (final holiday in holidays)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppPalette.redSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${holiday.date.day}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppPalette.red,
                                ),
                              ),
                              Text(
                                monthShort(holiday.date.month),
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: AppPalette.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                holiday.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppPalette.ink,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                [
                                  formatFullDate(holiday.date),
                                  if (holiday.isNational) 'Nasional',
                                ].join(' · '),
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppPalette.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Hapus',
                          onPressed: hr.busy
                              ? null
                              : () => _confirmDelete(context, hr, holiday),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppPalette.red,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, HrProvider hr) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => ChangeNotifierProvider<HrProvider>.value(
        value: hr,
        child: const _HolidayDialog(),
      ),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hari libur disimpan.')),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    HrProvider hr,
    Holiday holiday,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus hari libur?'),
        content: Text('${holiday.name} pada ${formatFullDate(holiday.date)}?'),
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
      await hr.deleteHoliday(holiday.id);
    }
  }
}

class _HolidayDialog extends StatefulWidget {
  const _HolidayDialog();

  @override
  State<_HolidayDialog> createState() => _HolidayDialogState();
}

class _HolidayDialogState extends State<_HolidayDialog> {
  final _name = TextEditingController();
  DateTime _date = dateOnly(DateTime.now());
  bool _isNational = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Nama hari libur wajib diisi.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await context.read<HrProvider>().saveHoliday(
      Holiday(
        id: 0,
        date: _date,
        name: _name.text.trim(),
        isNational: _isNational,
      ),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _saving = false;
      _error = context.read<HrProvider>().error ?? 'Gagal menyimpan.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Hari Libur'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Nama hari libur',
                hintText: 'Contoh: Cuti bersama Idul Fitri',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month_rounded, size: 18),
              label: Text(formatFullDate(_date)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hari libur nasional'),
              value: _isNational,
              onChanged: (value) => setState(() => _isNational = value),
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
