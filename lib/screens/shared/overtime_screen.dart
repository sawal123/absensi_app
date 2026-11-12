import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../core/formatters.dart';
import '../../data/models/overtime_request.dart';
import '../../data/models/request_status.dart';
import '../../providers/hr_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/surface_card.dart';

class OvertimeScreen extends StatelessWidget {
  const OvertimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hr = context.watch<HrProvider>();
    final isManager = hr.user.isManager;

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: Text(isManager ? 'Persetujuan Lembur' : 'Lembur Saya'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: hr.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: isManager
          ? null
          : FloatingActionButton.extended(
              onPressed: hr.busy ? null : () => _openForm(context, hr),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajukan lembur'),
            ),
      body: RefreshIndicator(
        onRefresh: hr.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (hr.error != null) ...[
              InfoBanner(
                icon: Icons.error_outline_rounded,
                title: 'Gagal memproses lembur',
                message: hr.error!,
                tone: StatusTone.danger,
                trailing: TextButton(
                  onPressed: hr.clearError,
                  child: const Text('Tutup'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (hr.loading && hr.overtimeRequests.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (hr.overtimeRequests.isEmpty)
              const EmptyState(
                icon: Icons.more_time_outlined,
                title: 'Belum ada pengajuan lembur',
                subtitle: 'Pengajuan lembur akan muncul di sini.',
              )
            else
              for (final request in hr.overtimeRequests)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OvertimeCard(
                    request: request,
                    canReview: isManager && request.status.isPending,
                    canCancel:
                        !isManager &&
                        request.status.isPending &&
                        request.employeeId == hr.user.id,
                    busy: hr.busy,
                    onApprove: () => hr.reviewOvertime(
                      request.id,
                      approve: true,
                      note: 'Disetujui.',
                    ),
                    onReject: () =>
                        _reject(context, hr, request.id),
                    onCancel: () => hr.cancelOvertime(request.id),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _reject(BuildContext context, HrProvider hr, int id) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak lembur'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Catatan penolakan',
            hintText: 'Jelaskan alasan penolakan.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
    if (note == null) return;
    await hr.reviewOvertime(id, approve: false, note: note);
  }

  Future<void> _openForm(BuildContext context, HrProvider hr) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChangeNotifierProvider<HrProvider>.value(
        value: hr,
        child: const _OvertimeForm(),
      ),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengajuan lembur terkirim.')),
      );
    }
  }
}

class _OvertimeCard extends StatelessWidget {
  const _OvertimeCard({
    required this.request,
    required this.canReview,
    required this.canCancel,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
  });

  final OvertimeRequest request;
  final bool canReview;
  final bool canCancel;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.employeeName.isEmpty
                      ? 'Pengajuan lembur'
                      : request.employeeName,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.ink,
                  ),
                ),
              ),
              requestStatusPill(request.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatFullDate(request.date),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppPalette.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatClock(request.startAt)} – ${formatClock(request.endAt)} '
            '· ${_durationText(request.minutes)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppPalette.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            request.reason,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: AppPalette.muted,
            ),
          ),
          if (request.reviewNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              request.reviewNote,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: request.status == RequestStatus.rejected
                    ? AppPalette.red
                    : AppPalette.green,
              ),
            ),
          ],
          if (canReview) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onReject,
                    child: const Text('Tolak'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : onApprove,
                    child: const Text('Setujui'),
                  ),
                ),
              ],
            ),
          ],
          if (canCancel) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: busy ? null : onCancel,
              child: const Text('Batalkan pengajuan'),
            ),
          ],
        ],
      ),
    );
  }

  String _durationText(int minutes) {
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return '$rest menit';
    return '$hours jam ${rest > 0 ? '$rest menit' : ''}'.trim();
  }
}

class _OvertimeForm extends StatefulWidget {
  const _OvertimeForm();

  @override
  State<_OvertimeForm> createState() => _OvertimeFormState();
}

class _OvertimeFormState extends State<_OvertimeForm> {
  final _reason = TextEditingController();
  DateTime _date = dateOnly(DateTime.now());
  TimeOfDay _start = const TimeOfDay(hour: 17, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 19, minute: 0);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  DateTime get _startAt =>
      DateTime(_date.year, _date.month, _date.day, _start.hour, _start.minute);
  DateTime get _endAt =>
      DateTime(_date.year, _date.month, _date.day, _end.hour, _end.minute);

  int get _minutes => _endAt.difference(_startAt).inMinutes;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (_reason.text.trim().length < 5) {
      setState(() => _error = 'Alasan lembur minimal 5 karakter.');
      return;
    }
    if (_minutes < 15) {
      setState(() => _error = 'Durasi lembur minimal 15 menit.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final ok = await context.read<HrProvider>().submitOvertime(
      OvertimeDraft(
        date: _date,
        startAt: _startAt,
        endAt: _endAt,
        reason: _reason.text.trim(),
      ),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _saving = false;
      _error = context.read<HrProvider>().error ?? 'Gagal mengirim lembur.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ajukan Lembur',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppPalette.ink,
              ),
            ),
            const SizedBox(height: 16),
            SurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              onTap: _pickDate,
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: AppPalette.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(formatFullDate(_date))),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SurfaceCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    onTap: () => _pickTime(start: true),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mulai',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppPalette.muted,
                          ),
                        ),
                        Text(
                          _start.format(context),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SurfaceCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    onTap: () => _pickTime(start: false),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selesai',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppPalette.muted,
                          ),
                        ),
                        Text(
                          _end.format(context),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Alasan lembur',
                hintText: 'Contoh: menyelesaikan rekap stok bulanan.',
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Durasi: ${_minutes > 0 ? _minutes : 0} menit',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppPalette.muted,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(_saving ? 'Mengirim...' : 'Kirim pengajuan'),
            ),
          ],
        ),
      ),
    );
  }
}
