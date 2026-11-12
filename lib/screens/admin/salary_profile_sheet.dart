import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../data/models/payroll_settings.dart';
import '../../data/models/salary_allowance.dart';
import '../../data/models/salary_profile.dart';
import '../../data/models/user.dart';
import '../../providers/payroll_provider.dart';

class SalaryProfileSheet extends StatefulWidget {
  const SalaryProfileSheet({super.key, required this.employee});

  final User employee;

  @override
  State<SalaryProfileSheet> createState() => _SalaryProfileSheetState();
}

class _SalaryProfileSheetState extends State<SalaryProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  final _baseSalary = TextEditingController();
  final _overtimeRate = TextEditingController();
  final _npwp = TextEditingController();
  final _allowanceDrafts = <_AllowanceDraft>[];

  String _ptkpStatus = 'TK/0';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final payroll = context.read<PayrollProvider>();
    final employeeId = widget.employee.id ?? 0;
    final profile = payroll.profileFor(employeeId);
    _baseSalary.text = (profile?.baseSalary ?? 0).toString();
    _overtimeRate.text = (profile?.overtimeRate ?? 0).toString();
    _npwp.text = profile?.npwp ?? '';
    _ptkpStatus = profile?.ptkpStatus ?? 'TK/0';
    for (final allowance in payroll.allowancesFor(employeeId)) {
      _allowanceDrafts.add(_AllowanceDraft.from(allowance));
    }
  }

  @override
  void dispose() {
    _baseSalary.dispose();
    _overtimeRate.dispose();
    _npwp.dispose();
    for (final draft in _allowanceDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final employeeId = widget.employee.id;
    if (employeeId == null) return;

    final allowances = <SalaryAllowance>[];
    var order = 0;
    for (final draft in _allowanceDrafts) {
      final name = draft.name.text.trim();
      final amount = int.tryParse(draft.amount.text.trim()) ?? 0;
      if (name.isEmpty && amount <= 0) continue;
      allowances.add(
        SalaryAllowance(
          employeeId: employeeId,
          name: name,
          amount: amount,
          basis: draft.basis,
          sortOrder: order++,
        ),
      );
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final payroll = context.read<PayrollProvider>();
    final ok = await payroll.saveSalarySetup(
      employee: widget.employee,
      profile: SalaryProfile(
        employeeId: employeeId,
        baseSalary: int.parse(_baseSalary.text.trim()),
        overtimeRate: int.tryParse(_overtimeRate.text.trim()) ?? 0,
        ptkpStatus: _ptkpStatus,
        npwp: _npwp.text.trim(),
        updatedAt: DateTime.now(),
      ),
      allowances: allowances,
    );

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _saving = false;
      _error = payroll.error ?? 'Gagal menyimpan gaji karyawan.';
    });
  }

  @override
  Widget build(BuildContext context) {
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Atur Gaji Karyawan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.employee.name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppPalette.muted,
                          ),
                        ),
                      ],
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
                controller: _baseSalary,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Gaji pokok bulanan',
                  prefixText: 'Rp ',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                validator: (value) {
                  final amount = int.tryParse(value?.trim() ?? '');
                  if (amount == null || amount <= 0) {
                    return 'Masukkan gaji pokok lebih dari 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _overtimeRate,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Upah lembur per jam',
                  prefixText: 'Rp ',
                  prefixIcon: Icon(Icons.more_time_outlined),
                  helperText:
                      'Lembur dihitung dari jam pulang melebihi jadwal.',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _ptkpStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status PTKP',
                        prefixIcon: Icon(Icons.family_restroom_outlined),
                      ),
                      items: [
                        for (final status in PayrollSettings.ptkpStatuses)
                          DropdownMenuItem(value: status, child: Text(status)),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _ptkpStatus = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _npwp,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'NPWP (opsional)',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Tunjangan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.ink,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _saving
                        ? null
                        : () => setState(
                            () => _allowanceDrafts.add(_AllowanceDraft()),
                          ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Tambah'),
                  ),
                ],
              ),
              if (_allowanceDrafts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Belum ada tunjangan. Tambahkan bila karyawan menerima '
                    'tunjangan tetap atau harian.',
                    style: TextStyle(fontSize: 11, color: AppPalette.faint),
                  ),
                )
              else
                for (var index = 0; index < _allowanceDrafts.length; index++)
                  _AllowanceRow(
                    key: ValueKey(_allowanceDrafts[index]),
                    draft: _allowanceDrafts[index],
                    onChanged: () => setState(() {}),
                    onRemove: _saving
                        ? null
                        : () => setState(() {
                            _allowanceDrafts.removeAt(index).dispose();
                          }),
                  ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12.5,
                  ),
                ),
              ],
              const SizedBox(height: 18),
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
                label: Text(_saving ? 'Menyimpan...' : 'Simpan Gaji'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllowanceRow extends StatelessWidget {
  const _AllowanceRow({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onRemove,
  });

  final _AllowanceDraft draft;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppPalette.slate,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: draft.name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nama tunjangan',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                tooltip: 'Hapus tunjangan',
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: AppPalette.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: draft.amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Nominal',
                    prefixText: 'Rp ',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<AllowanceBasis>(
                  initialValue: draft.basis,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Dasar',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: [
                    for (final basis in AllowanceBasis.values)
                      DropdownMenuItem(
                        value: basis,
                        child: Text(
                          basis.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    draft.basis = value;
                    onChanged();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AllowanceDraft {
  _AllowanceDraft({
    String name = '',
    String amount = '',
    this.basis = AllowanceBasis.monthly,
  }) : name = TextEditingController(text: name),
       amount = TextEditingController(text: amount);

  factory _AllowanceDraft.from(SalaryAllowance allowance) {
    return _AllowanceDraft(
      name: allowance.name,
      amount: allowance.amount.toString(),
      basis: allowance.basis,
    );
  }

  final TextEditingController name;
  final TextEditingController amount;
  AllowanceBasis basis;

  void dispose() {
    name.dispose();
    amount.dispose();
  }
}
