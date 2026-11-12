import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../core/formatters.dart';
import '../../data/models/audit_log_entry.dart';
import '../../providers/hr_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/status_pill.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HrProvider>().loadAuditLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hr = context.watch<HrProvider>();

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const Text('Audit Log'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: hr.loadAuditLogs,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: hr.loadAuditLogs,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const InfoBanner(
              icon: Icons.verified_user_outlined,
              title: 'Jejak aktivitas API',
              message:
                  'Setiap perubahan data (POST/PUT/PATCH/DELETE) dicatat '
                  'beserta pengguna, waktu, dan status respons.',
            ),
            if (hr.error != null) ...[
              const SizedBox(height: 12),
              InfoBanner(
                icon: Icons.error_outline_rounded,
                title: 'Gagal memuat audit log',
                message: hr.error!,
                tone: StatusTone.danger,
              ),
            ],
            const SizedBox(height: 14),
            if (hr.loading && hr.auditLogs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (hr.auditLogs.isEmpty)
              const EmptyState(
                icon: Icons.history_toggle_off_rounded,
                title: 'Belum ada audit log',
                subtitle: 'Aktivitas perubahan data akan tampil di sini.',
              )
            else
              for (final entry in hr.auditLogs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _AuditTile(entry: entry),
                ),
          ],
        ),
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.entry});

  final AuditLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = entry.statusCode >= 400 ? AppPalette.red : AppPalette.green;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  entry.method,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.ink,
                  ),
                ),
              ),
              Text(
                '${entry.statusCode}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${entry.userName.isEmpty ? 'Sistem' : entry.userName} · '
            '${formatStamp(entry.createdAt)}'
            '${entry.ipAddress.isEmpty ? '' : ' · ${entry.ipAddress}'}',
            style: const TextStyle(fontSize: 10, color: AppPalette.muted),
          ),
          if (entry.payload.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              entry.payload.entries
                  .take(3)
                  .map((item) => '${item.key}: ${item.value}')
                  .join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9.5, color: AppPalette.faint),
            ),
          ],
        ],
      ),
    );
  }
}
