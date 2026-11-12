import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../core/formatters.dart';
import '../../data/models/payroll_deduction_rule.dart';
import '../../providers/payroll_provider.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/surface_card.dart';

class PayrollComponentsScreen extends StatelessWidget {
  const PayrollComponentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Komponen Potongan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRuleForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah'),
      ),
      body: Consumer<PayrollProvider>(
        builder: (context, payroll, _) {
          final rules = payroll.rules;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
            children: [
              const InfoBanner(
                icon: Icons.auto_awesome_outlined,
                title: 'Potongan dihitung otomatis',
                message:
                    'Setiap komponen memakai data absensi dan cuti bulan '
                    'terpilih. Ubah tarif atau nonaktifkan komponen kapan saja.',
              ),
              if (payroll.error != null) ...[
                const SizedBox(height: 14),
                InfoBanner(
                  icon: Icons.error_outline_rounded,
                  title: 'Perubahan gagal disimpan',
                  message: payroll.error!,
                  tone: StatusTone.danger,
                  trailing: TextButton(
                    onPressed: payroll.clearError,
                    child: const Text('Tutup'),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SectionHeader(
                title: 'Daftar potongan',
                actionLabel: '${rules.length} komponen',
              ),
              const SizedBox(height: 10),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var index = 0; index < rules.length; index++) ...[
                      if (index > 0)
                        const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: AppPalette.border,
                        ),
                      _RuleRow(
                        rule: rules[index],
                        busy: payroll.busy,
                        onToggle: (value) => payroll.saveRule(
                          rules[index].copyWith(isActive: value),
                        ),
                        onEdit: () =>
                            _openRuleForm(context, rule: rules[index]),
                        onDelete: () =>
                            _confirmDelete(context, payroll, rules[index]),
                      ),
                    ],
                    if (rules.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'Belum ada komponen potongan.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppPalette.faint,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const SectionHeader(title: 'Pengaturan'),
              const SizedBox(height: 10),
              const _OvertimeSettingsCard(),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openRuleForm(
    BuildContext context, {
    PayrollDeductionRule? rule,
  }) async {
    final payroll = context.read<PayrollProvider>();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChangeNotifierProvider<PayrollProvider>.value(
        value: payroll,
        child: _RuleFormSheet(rule: rule),
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              rule == null
                  ? 'Komponen potongan ditambahkan.'
                  : 'Komponen potongan diperbarui.',
            ),
          ),
        );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PayrollProvider payroll,
    PayrollDeductionRule rule,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus komponen?'),
        content: Text(
          'Potongan "${rule.name}" tidak akan dihitung lagi pada slip gaji.',
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
    final ok = await payroll.deleteRule(rule.id!);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Komponen potongan dihapus.'
                : (payroll.error ?? 'Gagal menghapus komponen.'),
          ),
        ),
      );
    if (!ok) payroll.clearError();
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.rule,
    required this.busy,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final PayrollDeductionRule rule;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final subtitle = rule.basis == DeductionBasis.pph21
        ? '${rule.basis.label} · otomatis'
        : '${rule.basis.label} · ${_rateText(rule)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        rule.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.ink,
                        ),
                      ),
                    ),
                    if (rule.isSystem) ...[
                      const SizedBox(width: 6),
                      const StatusPill(
                        label: 'Bawaan',
                        tone: StatusTone.info,
                        dense: true,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppPalette.muted,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: rule.isActive, onChanged: busy ? null : onToggle),
          PopupMenuButton<String>(
            tooltip: 'Opsi',
            enabled: !busy,
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
              } else if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              if (!rule.isSystem)
                const PopupMenuItem(value: 'delete', child: Text('Hapus')),
            ],
          ),
        ],
      ),
    );
  }
}

class _RuleFormSheet extends StatefulWidget {
  const _RuleFormSheet({this.rule});

  final PayrollDeductionRule? rule;

  @override
  State<_RuleFormSheet> createState() => _RuleFormSheetState();
}

class _RuleFormSheetState extends State<_RuleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _rate = TextEditingController();
  late DeductionBasis _basis;
  late bool _active;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _name.text = rule?.name ?? '';
    _rate.text = rule == null ? '' : _formatRateInput(rule.rate);
    _basis = rule?.basis ?? DeductionBasis.latePerOccurrence;
    _active = rule?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final payroll = context.read<PayrollProvider>();
    final rule = widget.rule;
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await payroll.saveRule(
      PayrollDeductionRule(
        id: rule?.id,
        name: _name.text.trim(),
        basis: _basis,
        rate: _basis == DeductionBasis.pph21 ? 0 : _parseRate(_rate.text),
        isSystem: rule?.isSystem ?? false,
        isActive: _active,
        sortOrder: rule?.sortOrder ?? 999,
      ),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _saving = false;
      _error = payroll.error ?? 'Gagal menyimpan komponen potongan.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPph21 = _basis == DeductionBasis.pph21;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.rule == null
                          ? 'Tambah Komponen Potongan'
                          : 'Edit Komponen Potongan',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nama komponen',
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Nama komponen wajib diisi'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<DeductionBasis>(
                initialValue: _basis,
                decoration: const InputDecoration(
                  labelText: 'Dasar perhitungan',
                  prefixIcon: Icon(Icons.calculate_outlined),
                ),
                items: [
                  for (final basis in DeductionBasis.values)
                    DropdownMenuItem(
                      value: basis,
                      child: Text(
                        basis.label,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _basis = value);
                },
              ),
              if (isPph21) ...[
                const SizedBox(height: 12),
                const InfoBanner(
                  icon: Icons.info_outline_rounded,
                  title: 'PPh21 dihitung otomatis',
                  message:
                      'Menggunakan pendapatan bruto tahunan, PTKP karyawan, '
                      'dan tarif progresif. Tarif tidak perlu diisi.',
                ),
              ] else ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _rate,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText: _basis.isPercent
                        ? 'Tarif potongan'
                        : 'Nominal potongan',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    suffixText: _basis.isPercent ? '%' : 'Rp',
                    helperText: _basis.isPercent
                        ? 'Contoh 1,5 berarti 1,5% dari dasar perhitungan.'
                        : 'Nominal rupiah per kejadian/hari sesuai dasar.',
                  ),
                  validator: (value) {
                    if (!_basis.isPercent && !_basis.isNominal) return null;
                    final rate = _parseRate(value ?? '');
                    if (rate <= 0) return 'Tarif harus lebih dari 0';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (value) => setState(() => _active = value),
                title: const Text(
                  'Aktifkan potongan',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Komponen nonaktif tidak dihitung pada slip gaji.',
                  style: TextStyle(fontSize: 11, color: AppPalette.muted),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12.5,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Menyimpan...' : 'Simpan Komponen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OvertimeSettingsCard extends StatefulWidget {
  const _OvertimeSettingsCard();

  @override
  State<_OvertimeSettingsCard> createState() => _OvertimeSettingsCardState();
}

class _OvertimeSettingsCardState extends State<_OvertimeSettingsCard> {
  final _minutes = TextEditingController();
  bool _enabled = true;
  bool _synced = false;
  bool _saving = false;

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final payroll = context.read<PayrollProvider>();
    setState(() => _saving = true);
    final ok = await payroll.savePayrollSettings(
      payroll.settings.copyWith(
        overtimeEnabled: _enabled,
        overtimeMinMinutes: int.tryParse(_minutes.text.trim()) ?? 30,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Pengaturan lembur disimpan.'
                : (payroll.error ?? 'Gagal menyimpan pengaturan.'),
          ),
        ),
      );
    if (!ok) payroll.clearError();
  }

  @override
  Widget build(BuildContext context) {
    final payroll = context.watch<PayrollProvider>();
    if (!_synced) {
      _synced = true;
      _enabled = payroll.settings.overtimeEnabled;
      _minutes.text = payroll.settings.overtimeMinMinutes.toString();
    }

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
            title: const Text(
              'Hitung lembur otomatis',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Lembur dihitung dari jam pulang yang melebihi akhir shift.',
              style: TextStyle(fontSize: 11, color: AppPalette.muted),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _minutes,
            enabled: _enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Minimum lembur (menit)',
              prefixIcon: Icon(Icons.timer_outlined),
              helperText:
                  'Kelebihan jam pulang di bawah batas ini tidak dihitung.',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: const Text('Simpan Pengaturan'),
          ),
          const SizedBox(height: 12),
          const Text(
            'PPh21 memakai PTKP karyawan dan tarif progresif UU HPP. '
            'BPJS yang dipotong adalah iuran karyawan.',
            style: TextStyle(fontSize: 10.5, color: AppPalette.faint),
          ),
        ],
      ),
    );
  }
}

String _rateText(PayrollDeductionRule rule) {
  if (rule.basis.isPercent) {
    return '${_formatRateInput(rule.rate)}%';
  }
  return formatRupiah(rule.rate);
}

String _formatRateInput(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

double _parseRate(String value) {
  final cleaned = value.trim().replaceAll(',', '.');
  return double.tryParse(cleaned) ?? 0;
}
