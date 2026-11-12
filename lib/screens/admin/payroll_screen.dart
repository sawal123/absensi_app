import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../core/formatters.dart';
import '../../data/models/payroll_slip.dart';
import '../../data/models/user.dart';
import '../../providers/payroll_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/month_selector.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/surface_card.dart';
import '../shared/payroll_detail_screen.dart';
import 'payroll_components_screen.dart';
import 'salary_profile_sheet.dart';

class PayrollScreen extends StatelessWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gaji Karyawan'),
        actions: [
          IconButton(
            tooltip: 'Komponen potongan',
            onPressed: () => _openComponents(context),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: Consumer<PayrollProvider>(
        builder: (context, payroll, _) {
          return RefreshIndicator(
            onRefresh: payroll.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                MonthSelector(
                  month: payroll.month,
                  onTap: () => _pickMonth(context, payroll),
                ),
                const SizedBox(height: 14),
                _SummaryCard(
                  payroll: payroll,
                  onFinalize: () => _finalize(context, payroll),
                  onReopen: () => _reopen(context, payroll),
                ),
                if (payroll.error != null) ...[
                  const SizedBox(height: 14),
                  InfoBanner(
                    icon: Icons.error_outline_rounded,
                    title: 'Data gaji belum lengkap',
                    message: payroll.error!,
                    tone: StatusTone.danger,
                    trailing: TextButton(
                      onPressed: () {
                        payroll.clearError();
                        payroll.load();
                      },
                      child: const Text('Coba'),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                SectionHeader(
                  title: 'Slip karyawan',
                  actionLabel: '${payroll.slips.length} karyawan',
                ),
                const SizedBox(height: 10),
                if (payroll.loading && payroll.employees.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (payroll.employees.isEmpty)
                  const EmptyState(
                    icon: Icons.group_off_outlined,
                    title: 'Belum ada karyawan',
                    subtitle:
                        'Tambahkan karyawan terlebih dahulu untuk menghitung '
                        'gaji.',
                  )
                else
                  for (final employee in payroll.employees)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _EmployeeCard(
                        employee: employee,
                        slip: payroll.slipFor(employee.id ?? 0),
                        finalized:
                            payroll.savedSlipFor(employee.id ?? 0) != null,
                        onTap: () {
                          final slip = payroll.slipFor(employee.id ?? 0);
                          if (slip == null) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PayrollDetailScreen(slip: slip),
                            ),
                          );
                        },
                        onEdit: () =>
                            _openSalarySetup(context, payroll, employee),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickMonth(BuildContext context, PayrollProvider payroll) async {
    final picked = await showMonthPicker(context, payroll.month);
    if (picked == null) return;
    await payroll.selectMonth(picked);
  }

  Future<void> _openSalarySetup(
    BuildContext context,
    PayrollProvider payroll,
    User employee,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChangeNotifierProvider<PayrollProvider>.value(
        value: payroll,
        child: SalaryProfileSheet(employee: employee),
      ),
    );
    if (saved == true && context.mounted) {
      _snack(context, 'Gaji ${employee.name} berhasil disimpan.');
    }
  }

  void _openComponents(BuildContext context) {
    final payroll = context.read<PayrollProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<PayrollProvider>.value(
          value: payroll,
          child: const PayrollComponentsScreen(),
        ),
      ),
    );
  }

  Future<void> _finalize(BuildContext context, PayrollProvider payroll) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Finalisasi gaji ${formatMonthYear(payroll.month)}?'),
        content: const Text(
          'Slip gaji seluruh karyawan akan disimpan permanen. Nilainya tidak '
          'akan berubah sampai finalisasi dibuka kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finalisasi'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await payroll.finalizeMonth();
    if (!context.mounted) return;
    _snack(
      context,
      ok
          ? 'Gaji berhasil difinalisasi.'
          : (payroll.error ?? 'Finalisasi gagal.'),
    );
    if (!ok) payroll.clearError();
  }

  Future<void> _reopen(BuildContext context, PayrollProvider payroll) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buka finalisasi?'),
        content: const Text(
          'Slip yang tersimpan akan dihapus dan dihitung ulang dari data '
          'absensi serta cuti terkini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Buka finalisasi'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await payroll.reopenMonth();
    if (!context.mounted) return;
    _snack(
      context,
      ok
          ? 'Finalisasi dibuka. Slip kembali berupa estimasi.'
          : (payroll.error ?? 'Gagal membuka finalisasi.'),
    );
    if (!ok) payroll.clearError();
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.payroll,
    required this.onFinalize,
    required this.onReopen,
  });

  final PayrollProvider payroll;
  final VoidCallback onFinalize;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppPalette.headerGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total gaji bersih',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ),
              StatusPill(
                label: payroll.isFinalized ? 'Final' : 'Estimasi',
                tone: payroll.isFinalized
                    ? StatusTone.success
                    : StatusTone.warning,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatRupiah(payroll.totalNetPay),
            style: const TextStyle(
              fontSize: 30,
              height: 1,
              letterSpacing: -1,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            payroll.isFinalized
                ? '${payroll.finalizedCount} slip final · '
                      '${formatMonthYear(payroll.month)}'
                : '${payroll.slips.length} karyawan · belum difinalisasi',
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: payroll.busy
                ? null
                : (payroll.isFinalized ? onReopen : onFinalize),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppPalette.primary,
              minimumSize: const Size.fromHeight(44),
            ),
            icon: payroll.busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    payroll.isFinalized
                        ? Icons.lock_open_rounded
                        : Icons.lock_outline_rounded,
                    size: 18,
                  ),
            label: Text(
              payroll.isFinalized ? 'Buka finalisasi' : 'Finalisasi gaji',
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.employee,
    required this.slip,
    required this.finalized,
    required this.onTap,
    required this.onEdit,
  });

  final User employee;
  final PayrollSlip? slip;
  final bool finalized;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final current = slip;
    final meta = [
      if (employee.position.isNotEmpty) employee.position,
      if (employee.nip.isNotEmpty) 'NIP ${employee.nip}',
    ].join(' · ');
    final configured = (current?.baseSalary ?? 0) > 0;

    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialsAvatar(name: employee.name, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.name,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.ink,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppPalette.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  !configured
                      ? 'Gaji pokok belum diatur'
                      : 'Hadir ${current!.metrics.presentDays} · '
                            'Telat ${current.metrics.lateCount} · '
                            'Absen ${current.metrics.absentDays}',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: configured ? AppPalette.faint : AppPalette.amber,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                current == null ? '-' : formatRupiah(current.netPay),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.ink,
                ),
              ),
              const SizedBox(height: 4),
              StatusPill(
                label: finalized ? 'Final' : 'Estimasi',
                tone: finalized ? StatusTone.success : StatusTone.warning,
                dense: true,
              ),
              IconButton(
                onPressed: onEdit,
                tooltip: 'Atur gaji',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 17,
                  color: AppPalette.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
