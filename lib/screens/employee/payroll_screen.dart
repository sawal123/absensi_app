import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../core/formatters.dart';
import '../../data/models/payroll_slip.dart';
import '../../providers/employee_payroll_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/month_selector.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/surface_card.dart';
import '../shared/payroll_detail_screen.dart';

class EmployeePayrollScreen extends StatelessWidget {
  const EmployeePayrollScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Slip Gaji')),
      body: Consumer<EmployeePayrollProvider>(
        builder: (context, payroll, _) {
          final slip = payroll.slip;
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
                if (payroll.error != null)
                  InfoBanner(
                    icon: Icons.error_outline_rounded,
                    title: 'Slip gaji belum bisa dimuat',
                    message: payroll.error!,
                    tone: StatusTone.danger,
                    trailing: TextButton(
                      onPressed: () {
                        payroll.clearError();
                        payroll.load();
                      },
                      child: const Text('Coba'),
                    ),
                  )
                else if (payroll.loading && slip == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (slip == null)
                  const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Belum ada slip gaji',
                    subtitle:
                        'Slip gaji bulan ini akan muncul setelah data absensi '
                        'tercatat.',
                  )
                else ...[
                  if (!payroll.hasSalaryProfile) ...[
                    const InfoBanner(
                      icon: Icons.warning_amber_rounded,
                      title: 'Gaji pokok belum diatur',
                      message:
                          'Hubungi atasan agar gaji pokok dan tunjanganmu '
                          'dilengkapi sebelum slip dihitung.',
                      tone: StatusTone.warning,
                    ),
                    const SizedBox(height: 14),
                  ],
                  _NetCard(slip: slip),
                  const SizedBox(height: 14),
                  SurfaceCard(
                    child: Column(
                      children: [
                        _InfoRow(
                          label: 'Gaji pokok',
                          value: formatRupiah(slip.baseSalary),
                        ),
                        _InfoRow(
                          label: 'Total pendapatan',
                          value: formatRupiah(slip.grossEarnings),
                        ),
                        _InfoRow(
                          label: 'Total potongan',
                          value: '−${formatRupiah(slip.totalDeductions)}',
                          danger: true,
                        ),
                        _InfoRow(
                          label: 'Hadir',
                          value: '${slip.metrics.presentDays} hari',
                        ),
                        _InfoRow(
                          label: 'Terlambat',
                          value: slip.metrics.lateCount == 0
                              ? 'Tidak ada'
                              : '${slip.metrics.lateCount} kali '
                                    '(${slip.metrics.lateMinutes} menit)',
                        ),
                        _InfoRow(
                          label: 'Absen',
                          value: '${slip.metrics.absentDays} hari',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PayrollDetailScreen(slip: slip),
                      ),
                    ),
                    icon: const Icon(Icons.receipt_long_rounded, size: 19),
                    label: const Text('Lihat rincian slip'),
                  ),
                  const SizedBox(height: 14),
                  InfoBanner(
                    icon: slip.isFinalized
                        ? Icons.verified_outlined
                        : Icons.info_outline_rounded,
                    tone: slip.isFinalized
                        ? StatusTone.success
                        : StatusTone.info,
                    title: slip.isFinalized
                        ? 'Slip sudah difinalisasi'
                        : 'Masih berupa estimasi',
                    message: slip.isFinalized
                        ? 'Slip ini tersimpan permanen dan tidak berubah.'
                        : 'Nilai dapat berubah sampai atasan memfinalisasi '
                              'gaji bulan ini.',
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickMonth(
    BuildContext context,
    EmployeePayrollProvider payroll,
  ) async {
    final picked = await showMonthPicker(context, payroll.month);
    if (picked == null) return;
    await payroll.selectMonth(picked);
  }
}

class _NetCard extends StatelessWidget {
  const _NetCard({required this.slip});

  final PayrollSlip slip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppPalette.headerGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Gaji bersih · ${formatMonthYear(DateTime(slip.year, slip.month))}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ),
              StatusPill(
                label: slip.isFinalized ? 'Final' : 'Estimasi',
                tone: slip.isFinalized
                    ? StatusTone.success
                    : StatusTone.warning,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatRupiah(slip.netPay),
            style: const TextStyle(
              fontSize: 30,
              height: 1,
              letterSpacing: -1,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${formatRupiah(slip.grossEarnings)} bruto − '
            '${formatRupiah(slip.totalDeductions)} potongan',
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.danger = false,
  });

  final String label;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppPalette.muted),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: danger ? AppPalette.red : AppPalette.ink,
            ),
          ),
        ],
      ),
    );
  }
}
