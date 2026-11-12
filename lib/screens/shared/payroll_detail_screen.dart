import 'package:flutter/material.dart';

import '../../core/app_palette.dart';
import '../../core/formatters.dart';
import '../../data/models/payroll_slip.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/page_header.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/surface_card.dart';

class PayrollDetailScreen extends StatelessWidget {
  const PayrollDetailScreen({super.key, required this.slip});

  final PayrollSlip slip;

  @override
  Widget build(BuildContext context) {
    final period = DateTime(slip.year, slip.month);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PageHeader(
              center: true,
              leading: const SquareBackButton(),
              title: 'Slip Gaji',
              subtitle: formatMonthYear(period),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                children: [
                  _IdentityCard(slip: slip),
                  const SizedBox(height: 14),
                  _NetCard(slip: slip),
                  const SizedBox(height: 14),
                  _LinesCard(
                    title: 'Pendapatan',
                    lines: slip.earnings,
                    total: slip.grossEarnings,
                    totalLabel: 'Total pendapatan',
                    tone: AppPalette.green,
                    emptyText: 'Belum ada komponen pendapatan.',
                  ),
                  const SizedBox(height: 14),
                  _LinesCard(
                    title: 'Potongan',
                    lines: slip.deductions,
                    total: slip.totalDeductions,
                    totalLabel: 'Total potongan',
                    tone: AppPalette.red,
                    emptyText: 'Tidak ada potongan bulan ini.',
                    negative: true,
                  ),
                  const SizedBox(height: 14),
                  _MetricsCard(metrics: slip.metrics),
                  const SizedBox(height: 16),
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
                        ? 'Nilai pada slip ini tersimpan permanen dan tidak '
                              'berubah meski data absensi diperbarui.'
                        : 'Slip dihitung dari data absensi dan cuti terkini. '
                              'Nilai dapat berubah sampai atasan memfinalisasi.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.slip});

  final PayrollSlip slip;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (slip.nip.isNotEmpty) 'NIP ${slip.nip}',
      if (slip.position.isNotEmpty) slip.position,
    ].join(' · ');

    return SurfaceCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppPalette.blueSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppPalette.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slip.employeeName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.ink,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppPalette.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          StatusPill(
            label: slip.isFinalized ? 'Final' : 'Estimasi',
            tone: slip.isFinalized ? StatusTone.success : StatusTone.warning,
            dense: true,
          ),
        ],
      ),
    );
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
          Text(
            'Gaji bersih',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.82),
            ),
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
          const SizedBox(height: 12),
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

class _LinesCard extends StatelessWidget {
  const _LinesCard({
    required this.title,
    required this.lines,
    required this.total,
    required this.totalLabel,
    required this.tone,
    required this.emptyText,
    this.negative = false,
  });

  final String title;
  final List<PayrollLine> lines;
  final int total;
  final String totalLabel;
  final Color tone;
  final String emptyText;
  final bool negative;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppPalette.ink,
            ),
          ),
          const SizedBox(height: 10),
          if (lines.isEmpty)
            Text(
              emptyText,
              style: const TextStyle(fontSize: 11.5, color: AppPalette.faint),
            )
          else
            for (final line in lines) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.label,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppPalette.ink,
                            ),
                          ),
                          if ((line.detail ?? '').isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              line.detail!,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppPalette.faint,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      negative
                          ? '−${formatRupiah(line.amount)}'
                          : formatRupiah(line.amount),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: negative ? tone : AppPalette.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: AppPalette.border),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  totalLabel,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.muted,
                  ),
                ),
              ),
              Text(
                negative ? '−${formatRupiah(total)}' : formatRupiah(total),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: tone,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  const _MetricsCard({required this.metrics});

  final PayrollMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final overtime = metrics.overtimeMinutes == 0
        ? 'Tidak ada'
        : formatDurationShort(Duration(minutes: metrics.overtimeMinutes));
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Rincian kehadiran',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppPalette.ink,
            ),
          ),
          const SizedBox(height: 10),
          _MetricRow(label: 'Hari kerja', value: '${metrics.workingDays} hari'),
          _MetricRow(label: 'Hadir', value: '${metrics.presentDays} hari'),
          _MetricRow(
            label: 'Terlambat',
            value: metrics.lateCount == 0
                ? 'Tidak ada'
                : '${metrics.lateCount} kali · ${metrics.lateMinutes} menit',
          ),
          _MetricRow(label: 'Absen', value: '${metrics.absentDays} hari'),
          _MetricRow(
            label: 'Cuti dibayar',
            value: '${metrics.paidLeaveDays} hari',
          ),
          _MetricRow(
            label: 'Cuti tak dibayar',
            value: '${metrics.unpaidLeaveDays} hari',
          ),
          _MetricRow(label: 'Lembur', value: overtime),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
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
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppPalette.ink,
            ),
          ),
        ],
      ),
    );
  }
}
