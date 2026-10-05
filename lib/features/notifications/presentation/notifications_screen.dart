import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/notification_model.dart';
import '../../../shared/widgets/neu.dart';
import '../data/notification_repository.dart';

/// Daftar notifikasi pengguna.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _iconFor(String type) {
    if (type.startsWith('order')) return Icons.receipt_long_rounded;
    switch (type) {
      case 'promo':
        return Icons.local_offer_rounded;
      case 'birthday':
        return Icons.cake_rounded;
      case 'spin_reminder':
        return Icons.casino_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          async.maybeWhen(
            data: (list) => list.any((n) => !n.isRead)
                ? TextButton(
                    onPressed: () async {
                      await ref
                          .read(notificationRepositoryProvider)
                          .markAllRead();
                      ref.invalidate(notificationsProvider);
                    },
                    child: const Text('Tandai semua'),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.amber)),
        error: (e, _) => _ErrorState(
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (list) {
          if (list.isEmpty) return const _EmptyState();
          return RefreshIndicator(
            color: AppColors.amber,
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: ResponsiveListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount: list.length,
              minItemWidth: 360,
              maxColumns: 3,
              runSpacing: 10,
              itemBuilder: (context, i) => _NotificationTile(
                notif: list[i],
                icon: _iconFor(list[i].type),
                onTap: () async {
                  if (!list[i].isRead) {
                    await ref
                        .read(notificationRepositoryProvider)
                        .markRead(list[i].id);
                    ref.invalidate(notificationsProvider);
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notif,
    required this.icon,
    required this.onTap,
  });
  final NotificationModel notif;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      onTap: onTap,
      depth: notif.isRead ? 3 : -3,
      color: notif.isRead ? null : AppColors.crema,
      padding: const EdgeInsets.all(14),
      radius: 16,
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.amberDark, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(notif.title,
                            style: AppTextStyles.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6, top: 4),
                          decoration: const BoxDecoration(
                            color: AppColors.amber,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(notif.body,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary)),
                  if (notif.sentAt != null) ...[
                    const SizedBox(height: 6),
                    Text(Formatters.tanggalJam(notif.sentAt!),
                        style: AppTextStyles.caption),
                  ],
                ],
              ),
            ),
          ],
        ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.crema,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.notifications_none_rounded,
                color: AppColors.amberDark, size: 36),
          ),
          const SizedBox(height: 16),
          Text('Belum ada notifikasi', style: AppTextStyles.titleLarge),
          const SizedBox(height: 6),
          Text('Info pesanan & promo akan muncul di sini.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded,
              color: AppColors.textSecondary, size: 36),
          const SizedBox(height: 10),
          Text('Gagal memuat notifikasi.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}
