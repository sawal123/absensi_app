import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_palette.dart';
import '../../core/formatters.dart';
import '../../data/models/app_notification.dart';
import '../../providers/hr_provider.dart';
import '../../widgets/empty_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HrProvider>().refreshNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          Consumer<HrProvider>(
            builder: (context, hr, _) {
              if (hr.unreadCount == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: hr.markAllNotificationsRead,
                child: const Text('Tandai semua'),
              );
            },
          ),
        ],
      ),
      body: Consumer<HrProvider>(
        builder: (context, hr, _) {
          return RefreshIndicator(
            onRefresh: hr.refreshNotifications,
            child: hr.notifications.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 80),
                      EmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: 'Belum ada notifikasi',
                        subtitle:
                            'Pemberitahuan pengajuan, persetujuan, dan '
                            'kebijakan HR akan muncul di sini.',
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: hr.notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = hr.notifications[index];
                      return _NotificationTile(
                        notification: item,
                        onTap: () => hr.markNotificationRead(item.id),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: notification.isRead ? Colors.white : AppPalette.blueSoft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon, size: 19, color: _color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.ink,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppPalette.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: AppPalette.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatStamp(notification.createdAt),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppPalette.faint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData get _icon => switch (notification.type) {
    'leave' => Icons.event_available_rounded,
    'correction' => Icons.edit_document,
    'overtime' => Icons.more_time_rounded,
    _ => Icons.info_outline_rounded,
  };

  Color get _color => switch (notification.type) {
    'leave' => AppPalette.green,
    'correction' => AppPalette.amber,
    'overtime' => AppPalette.primary,
    _ => AppPalette.primary,
  };
}
