import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../core/formatters.dart';
import '../../data/api/absensi_api.dart';
import '../../data/models/attendance.dart';
import '../../data/models/correction_type.dart';
import '../../data/models/office_settings.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/my_requests_provider.dart';
import '../../services/image_service.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/page_header.dart';
import '../../widgets/surface_card.dart';

class CorrectionRequestScreen extends StatefulWidget {
  const CorrectionRequestScreen({super.key});

  @override
  State<CorrectionRequestScreen> createState() =>
      _CorrectionRequestScreenState();
}

class _CorrectionRequestScreenState extends State<CorrectionRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();

  DateTime _date = dateOnly(DateTime.now());
  CorrectionType _type = CorrectionType.checkOut;
  TimeOfDay? _proposedIn;
  TimeOfDay? _proposedOut;
  String? _attachmentPath;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final attendance = context.read<AttendanceProvider>();
      final record = _recordFor(attendance, _date);
      setState(() => _applyDefaults(record, attendance.settings, _type));
    });
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<AttendanceProvider>();
    final record = _recordFor(attendance, _date);
    final showIn = _type == CorrectionType.checkIn || _type == CorrectionType.both;
    final showOut =
        _type == CorrectionType.checkOut || _type == CorrectionType.both;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const PageHeader(
              center: true,
              leading: SquareBackButton(),
              title: 'Perbaikan Absensi',
              subtitle: 'Ajukan koreksi jam masuk atau pulang',
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    const _Label('Tanggal kejadian'),
                    const SizedBox(height: 8),
                    SurfaceCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      onTap: () => _pickDate(attendance),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_rounded,
                            size: 19,
                            color: AppPalette.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              formatFullDate(_date),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppPalette.ink,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: AppPalette.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _RecordCard(record: record),
                    const SizedBox(height: 20),
                    const _Label('Jenis perbaikan'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final type in CorrectionType.values)
                          _TypeChip(
                            label: _shortLabel(type),
                            selected: _type == type,
                            onTap: () => setState(() {
                              _type = type;
                              _applyDefaults(record, attendance.settings, type);
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _Label('Waktu yang diusulkan'),
                    const SizedBox(height: 8),
                    if (showIn)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TimeField(
                          label: 'Jam masuk',
                          icon: Icons.login_rounded,
                          time: _proposedIn,
                          onTap: () => _pickTime(true),
                        ),
                      ),
                    if (showOut)
                      _TimeField(
                        label: 'Jam pulang',
                        icon: Icons.logout_rounded,
                        time: _proposedOut,
                        onTap: () => _pickTime(false),
                      ),
                    const SizedBox(height: 20),
                    const _Label('Alasan perbaikan'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _reason,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText:
                            'Jelaskan mengapa catatan absensi perlu '
                            'diperbaiki.',
                        hintMaxLines: 4,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Alasan perbaikan wajib diisi.';
                        }
                        if (value.trim().length < 10) {
                          return 'Tulis alasan minimal 10 karakter.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const _Label('Bukti pendukung'),
                    const SizedBox(height: 8),
                    _AttachmentTile(
                      path: _attachmentPath,
                      onPick: _pickAttachment,
                      onRemove: () => setState(() => _attachmentPath = null),
                    ),
                    const SizedBox(height: 16),
                    const InfoBanner(
                      icon: Icons.verified_user_outlined,
                      title: 'Data berubah setelah disetujui',
                      message:
                          'Perubahan jam absensi hanya diterapkan setelah '
                          'atasan menyetujui pengajuan ini.',
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
                label: Text(_submitting ? 'Mengirim...' : 'Kirim pengajuan'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pastikan waktu dan alasan sudah sesuai bukti.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: AppPalette.faint),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Attendance? _recordFor(AttendanceProvider provider, DateTime date) {
    final key = dateKey(date);
    for (final record in provider.history) {
      if (record.date == key) return record;
    }
    final today = provider.today;
    if (today != null && today.date == key) return today;
    return null;
  }

  Future<void> _pickDate(AttendanceProvider attendance) async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today.subtract(const Duration(days: 30)),
      lastDate: today,
      helpText: 'Pilih tanggal kejadian',
    );
    if (picked == null) return;

    final record = _recordFor(attendance, picked);
    setState(() {
      _date = dateOnly(picked);
      _applyDefaults(record, attendance.settings, _type);
    });
  }

  Future<void> _pickTime(bool isCheckIn) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isCheckIn ? _proposedIn : _proposedOut) ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isCheckIn) {
        _proposedIn = picked;
      } else {
        _proposedOut = picked;
      }
    });
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

  void _applyDefaults(
    Attendance? record,
    OfficeSettings settings,
    CorrectionType type,
  ) {
    final recordIn = record?.checkInAt == null
        ? null
        : TimeOfDay.fromDateTime(record!.checkInAt!);
    final recordOut = record?.checkOutAt == null
        ? null
        : TimeOfDay.fromDateTime(record!.checkOutAt!);
    final workStart = _timeOfDay(settings.workStart);
    final workEnd = _timeOfDay(settings.workEnd);

    switch (type) {
      case CorrectionType.checkIn:
        _proposedIn = recordIn ?? workStart;
        _proposedOut = recordOut;
      case CorrectionType.checkOut:
        _proposedIn = recordIn;
        _proposedOut = recordOut ?? workEnd;
      case CorrectionType.both:
        _proposedIn = recordIn ?? workStart;
        _proposedOut = recordOut ?? workEnd;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final attendance = context.read<AttendanceProvider>();
    final record = _recordFor(attendance, _date);
    final showIn =
        _type == CorrectionType.checkIn || _type == CorrectionType.both;
    final showOut =
        _type == CorrectionType.checkOut || _type == CorrectionType.both;

    final proposedIn = showIn
        ? _combine(_date, _proposedIn)
        : record?.checkInAt;
    final proposedOut = showOut
        ? _combine(_date, _proposedOut)
        : record?.checkOutAt;

    if (proposedIn == null && proposedOut == null) {
      _snack(context, 'Isi minimal satu jam yang ingin diperbaiki.');
      return;
    }

    setState(() => _submitting = true);
    final requests = context.read<MyRequestsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await requests.submitCorrection(
      CorrectionDraft(
        employeeId: requests.employeeId,
        attendanceId: record?.id,
        date: _date,
        correctionType: _type,
        proposedCheckIn: proposedIn,
        proposedCheckOut: proposedOut,
        reason: _reason.text.trim(),
        evidenceUrl: _attachmentPath,
      ),
    );
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Pengajuan perbaikan terkirim.')),
      );
      return;
    }

    setState(() => _submitting = false);
    final message = requests.error ?? 'Pengajuan gagal dikirim.';
    requests.clearError();
    _snack(context, message);
  }

  DateTime? _combine(DateTime date, TimeOfDay? time) {
    if (time == null) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  TimeOfDay _timeOfDay(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 0,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  String _shortLabel(CorrectionType type) => switch (type) {
    CorrectionType.checkIn => 'Jam masuk',
    CorrectionType.checkOut => 'Jam pulang',
    CorrectionType.both => 'Keduanya',
  };

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record});

  final Attendance? record;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Catatan saat ini',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppPalette.ink,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TimeBox(
                  label: 'Masuk',
                  icon: Icons.login_rounded,
                  value: formatClock(record?.checkInAt),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeBox(
                  label: 'Pulang',
                  icon: Icons.logout_rounded,
                  value: formatClock(record?.checkOutAt),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({
    required this.label,
    required this.icon,
    required this.value,
  });

  final String label;
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: AppPalette.muted),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppPalette.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: value == '--:--' ? AppPalette.faint : AppPalette.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.icon,
    required this.time,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final TimeOfDay? time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final value = time == null
        ? 'Pilih jam'
        : '${time!.hour.toString().padLeft(2, '0')}.'
              '${time!.minute.toString().padLeft(2, '0')}';

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppPalette.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppPalette.muted),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: time == null ? AppPalette.faint : AppPalette.ink,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.schedule_rounded,
            size: 18,
            color: AppPalette.primary,
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
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
