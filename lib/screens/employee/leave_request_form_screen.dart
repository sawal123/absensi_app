import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../core/formatters.dart';
import '../../data/api/absensi_api.dart';
import '../../data/models/leave_balance.dart';
import '../../data/models/leave_type.dart';
import '../../providers/my_requests_provider.dart';
import '../../services/image_service.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/page_header.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/surface_card.dart';

class LeaveRequestFormScreen extends StatefulWidget {
  const LeaveRequestFormScreen({super.key});

  @override
  State<LeaveRequestFormScreen> createState() => _LeaveRequestFormScreenState();
}

class _LeaveRequestFormScreenState extends State<LeaveRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();

  int? _leaveTypeId;
  DateTimeRange? _range;
  String? _attachmentPath;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final requests = context.read<MyRequestsProvider>();
      if (!requests.hasLoadedTypes) requests.load();
    });
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requests = context.watch<MyRequestsProvider>();
    final types = requests.leaveTypes;
    final balance = _leaveTypeId == null
        ? null
        : requests.balanceFor(_leaveTypeId!);
    final days = _range == null
        ? 0
        : workingDaysBetween(
            _range!.start,
            _range!.end,
            holidays: requests.holidayKeys,
          );
    final insufficient =
        balance != null && days > 0 && days > balance.remainingDays;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const PageHeader(
              center: true,
              leading: SquareBackButton(),
              title: 'Ajukan Cuti',
              subtitle: 'Cuti tahunan, izin, atau sakit',
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    const _Label('Jenis pengajuan'),
                    const SizedBox(height: 8),
                    if (types.isEmpty)
                      requests.loading
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : InfoBanner(
                              icon: Icons.error_outline_rounded,
                              title: 'Jenis cuti belum tersedia',
                              message:
                                  requests.error ??
                                  'Periksa koneksi lalu coba lagi.',
                              tone: StatusTone.danger,
                              trailing: TextButton(
                                onPressed: requests.load,
                                child: const Text('Coba'),
                              ),
                            )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final type in types)
                            _TypeChip(
                              type: type,
                              selected: _leaveTypeId == type.id,
                              onTap: () =>
                                  setState(() => _leaveTypeId = type.id),
                            ),
                        ],
                      ),
                    const SizedBox(height: 20),
                    const _Label('Rentang tanggal'),
                    const SizedBox(height: 8),
                    SurfaceCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      onTap: _pickRange,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.date_range_rounded,
                            size: 19,
                            color: AppPalette.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _range == null
                                  ? 'Pilih rentang tanggal'
                                  : formatDateRange(
                                      _range!.start,
                                      _range!.end,
                                    ),
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: _range == null
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                                color: _range == null
                                    ? AppPalette.faint
                                    : AppPalette.ink,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: AppPalette.primary,
                          ),
                        ],
                      ),
                    ),
                    if (_range != null) ...[
                      const SizedBox(height: 12),
                      _SummaryCard(
                        days: days,
                        balance: balance,
                        insufficient: insufficient,
                      ),
                    ],
                    const SizedBox(height: 20),
                    const _Label('Alasan pengajuan'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _reason,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText:
                            'Jelaskan keperluan dan rencana serah terima '
                            'pekerjaanmu.',
                        hintMaxLines: 4,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Alasan pengajuan wajib diisi.';
                        }
                        if (value.trim().length < 10) {
                          return 'Tulis alasan minimal 10 karakter.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const _Label('Lampiran'),
                    const SizedBox(height: 8),
                    _AttachmentTile(
                      path: _attachmentPath,
                      onPick: _pickAttachment,
                      onRemove: () => setState(() => _attachmentPath = null),
                    ),
                    const SizedBox(height: 16),
                    const InfoBanner(
                      icon: Icons.info_outline_rounded,
                      title: 'Pengajuan akan ditinjau atasan',
                      message:
                          'Saldo cuti baru berkurang setelah pengajuan '
                          'disetujui. Kamu dapat membatalkan selama statusnya '
                          'masih menunggu.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppPalette.surface,
          border: Border(top: BorderSide(color: AppPalette.border)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 19),
                label: Text(
                  _submitting ? 'Mengirim...' : 'Kirim pengajuan',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pastikan tanggal dan alasan sudah benar sebelum mengirim.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: AppPalette.faint),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickRange() async {
    final today = dateOnly(DateTime.now());
    final firstDate = today.subtract(const Duration(days: 7));
    final initialRange =
        _range != null && !_range!.start.isBefore(firstDate) ? _range : null;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: today.add(const Duration(days: 365)),
      initialDateRange: initialRange,
      helpText: 'Pilih rentang cuti',
      saveText: 'Pilih',
    );
    if (picked != null) {
      setState(() => _range = picked);
    }
  }

  Future<void> _pickAttachment() async {
    final service = context.read<ImageService>();
    try {
      final path = await service.pickAttachment();
      if (!mounted || path == null) return;
      setState(() => _attachmentPath = path);
    } on ImageException catch (error) {
      if (!mounted) return;
      _snack(context, error.message);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_leaveTypeId == null) {
      _snack(context, 'Pilih jenis pengajuan terlebih dahulu.');
      return;
    }
    if (_range == null) {
      _snack(context, 'Pilih rentang tanggal pengajuan.');
      return;
    }

    final requests = context.read<MyRequestsProvider>();
    final days = workingDaysBetween(
      _range!.start,
      _range!.end,
      holidays: requests.holidayKeys,
    );
    if (days <= 0) {
      _snack(context, 'Rentang tanggal tidak memiliki hari kerja.');
      return;
    }

    final balance = requests.balanceFor(_leaveTypeId!);
    if (balance != null && days > balance.remainingDays) {
      _snack(
        context,
        'Saldo cuti tidak mencukupi. Sisa ${balance.remainingDays} hari.',
      );
      return;
    }

    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await requests.submitLeave(
      LeaveRequestDraft(
        employeeId: requests.employeeId,
        leaveTypeId: _leaveTypeId!,
        startDate: _range!.start,
        endDate: _range!.end,
        reason: _reason.text.trim(),
        attachmentUrl: _attachmentPath,
      ),
    );
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Pengajuan cuti terkirim.')),
      );
      return;
    }

    setState(() => _submitting = false);
    final message = requests.error ?? 'Pengajuan gagal dikirim.';
    requests.clearError();
    _snack(context, message);
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final LeaveType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(type.name),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: AppPalette.blueSoft,
      backgroundColor: AppPalette.surface,
      side: BorderSide(
        color: selected ? AppPalette.primary : AppPalette.border,
      ),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? AppPalette.primary : AppPalette.muted,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.days,
    required this.balance,
    required this.insufficient,
  });

  final int days;
  final LeaveBalance? balance;
  final bool insufficient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: insufficient ? AppPalette.redSoft : AppPalette.blueSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                insufficient
                    ? Icons.error_outline_rounded
                    : Icons.event_available_rounded,
                size: 18,
                color: insufficient ? AppPalette.red : AppPalette.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insufficient
                      ? 'Saldo cuti tidak mencukupi'
                      : 'Ringkasan pengajuan',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: insufficient ? AppPalette.red : AppPalette.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  value: '$days',
                  label: 'Hari kerja',
                  color: AppPalette.ink,
                ),
              ),
              Expanded(
                child: _Stat(
                  value: balance == null ? '—' : '${balance!.remainingDays}',
                  label: 'Saldo saat ini',
                  color: AppPalette.ink,
                ),
              ),
              Expanded(
                child: _Stat(
                  value: balance == null
                      ? '—'
                      : '${balance!.remainingDays - days}',
                  label: 'Sisa setelah',
                  color: insufficient ? AppPalette.red : AppPalette.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                height: 1,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(width: 3),
            const Text(
              'hari',
              style: TextStyle(fontSize: 9.5, color: AppPalette.muted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 9.5, color: AppPalette.muted),
        ),
      ],
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.path,
    required this.onPick,
    required this.onRemove,
  });

  final String? path;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (path == null) {
      return OutlinedButton.icon(
        onPressed: onPick,
        icon: const Icon(Icons.attach_file_rounded, size: 18),
        label: const Text('Lampirkan bukti (opsional)'),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppPalette.slate,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppPalette.blueSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.attach_file_rounded,
              size: 19,
              color: AppPalette.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _fileName(path!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppPalette.ink,
              ),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppPalette.muted,
            ),
          ),
        ],
      ),
    );
  }

  String _fileName(String value) => value.split(RegExp(r'[/\\]')).last;
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppPalette.ink,
      ),
    );
  }
}
