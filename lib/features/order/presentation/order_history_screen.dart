import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/order_model.dart';
import '../../../shared/widgets/neu.dart';
import '../../auth/application/auth_controller.dart';
import '../data/order_repository.dart';
import 'widgets/reorder_button.dart';

/// Riwayat pesanan pengguna.
class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(authControllerProvider).user?.isAdmin ?? false;
    // Admin: log transaksi selesai/dibatalkan. Pelanggan: pesanan sendiri.
    final provider =
        isAdmin ? adminOrderHistoryProvider : orderHistoryProvider;
    final historyAsync = ref.watch(provider);

    return Scaffold(
      appBar: AppBar(
          title: Text(isAdmin ? 'Riwayat Transaksi' : 'Pesanan Saya')),
      body: historyAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.amber)),
        error: (e, _) => _ErrorState(
          onRetry: () => ref.invalidate(provider),
        ),
        data: (orders) {
          if (orders.isEmpty) return _EmptyState(isAdmin: isAdmin);
          return RefreshIndicator(
            color: AppColors.amber,
            onRefresh: () async => ref.invalidate(provider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _OrderCard(
                order: orders[i],
                admin: isAdmin,
                onTap: () => context.pushNamed(
                  RouteNames.orderDetail,
                  pathParameters: {'id': orders[i].id},
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, this.onTap, this.admin = false});
  final OrderModel order;
  final VoidCallback? onTap;

  /// Mode admin: tampilkan nama pelanggan, sembunyikan tombol "Pesan Lagi".
  final bool admin;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      radius: 18,
      depth: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.crema,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(order.queueLabel,
                    style: AppTextStyles.label.copyWith(color: AppColors.espresso)),
              ),
              const SizedBox(width: 8),
              Icon(order.orderType.icon,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(order.orderType.label, style: AppTextStyles.caption),
              const Spacer(),
              _StatusBadge(status: order.status),
            ],
          ),
          if (admin) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline_rounded,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(order.customerName,
                      style: AppTextStyles.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(Formatters.tanggalJam(order.createdAt),
              style: AppTextStyles.bodySmall),
          if (order.itemsSummary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(order.itemsSummary,
                style: AppTextStyles.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          const Divider(height: 24),
          Row(
            children: [
              Icon(Icons.shopping_bag_outlined,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text('${order.itemCount} item', style: AppTextStyles.bodySmall),
              const Spacer(),
              Text(Formatters.rupiah(order.total),
                  style: AppTextStyles.label
                      .copyWith(color: AppColors.amberDark)),
            ],
          ),
          if (!admin &&
              (order.status == OrderStatus.completed ||
                  order.status == OrderStatus.cancelled)) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ReorderButton(order: order, compact: true),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.caption
            .copyWith(color: status.color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.isAdmin = false});
  final bool isAdmin;

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
            child: Icon(Icons.receipt_long_outlined,
                color: AppColors.amberDark, size: 36),
          ),
          const SizedBox(height: 16),
          Text(isAdmin ? 'Belum ada transaksi' : 'Belum ada pesanan',
              style: AppTextStyles.titleLarge),
          const SizedBox(height: 6),
          Text(
              isAdmin
                  ? 'Transaksi selesai akan tercatat di sini.'
                  : 'Pesananmu akan muncul di sini.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          if (!isAdmin) ...[
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => context.goNamed(RouteNames.menu),
              child: const Text('Pesan Sekarang'),
            ),
          ],
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
          Text('Gagal memuat riwayat.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}
