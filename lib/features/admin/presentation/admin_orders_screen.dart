import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/order_model.dart';
import '../../../shared/widgets/neu.dart';
import '../../order/data/order_repository.dart';

/// (Admin) Pesanan Masuk: lihat semua pesanan, filter status, konfirmasi bayar.
class AdminOrdersScreen extends ConsumerWidget {
  const AdminOrdersScreen({super.key});

  // (label, nilai status backend). '' = semua.
  static const _filters = [
    ('Menunggu bayar', 'pending_payment'),
    ('Dibayar', 'paid'),
    ('Diproses', 'processing'),
    ('Siap', 'ready'),
    ('Semua', ''),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(adminOrdersFilterProvider);
    final ordersAsync = ref.watch(adminOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pesanan Masuk')),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final (label, value) = _filters[i];
                final active = value == selected;
                return GestureDetector(
                  onTap: () =>
                      ref.read(adminOrdersFilterProvider.notifier).state = value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? AppColors.espresso : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: active ? AppColors.espresso : AppColors.border),
                    ),
                    child: Text(label,
                        style: AppTextStyles.caption.copyWith(
                          color: active ? AppColors.crema : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.amber)),
              error: (e, _) => _ErrorState(
                  onRetry: () => ref.invalidate(adminOrdersProvider)),
              data: (orders) {
                if (orders.isEmpty) return const _EmptyState();
                return RefreshIndicator(
                  color: AppColors.amber,
                  onRefresh: () async => ref.invalidate(adminOrdersProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _AdminOrderCard(
                      order: orders[i],
                      onTap: () => context.pushNamed(
                        RouteNames.orderDetail,
                        pathParameters: {'id': orders[i].id},
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminOrderCard extends StatelessWidget {
  const _AdminOrderCard({required this.order, required this.onTap});
  final OrderModel order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      radius: 18,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(order.queueLabel, style: AppTextStyles.titleMedium),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(order.customerName,
                      style: AppTextStyles.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                _StatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(Formatters.tanggalJam(order.createdAt),
                style: AppTextStyles.bodySmall),
            if (order.itemsSummary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(order.itemsSummary,
                  style: AppTextStyles.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
            const Divider(height: 24),
            Row(
              children: [
                _OrderTypeChip(type: order.orderType),
                const SizedBox(width: 10),
                Text('${order.itemCount} item', style: AppTextStyles.bodySmall),
                const Spacer(),
                Text(Formatters.rupiah(order.total),
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.amberDark)),
              ],
            ),
          ],
        ),
    );
  }
}

/// Chip tipe pesanan — bawa pulang disorot agar barista mudah membedakan.
class _OrderTypeChip extends StatelessWidget {
  const _OrderTypeChip({required this.type});
  final OrderType type;

  @override
  Widget build(BuildContext context) {
    final takeaway = type == OrderType.takeaway;
    final color = takeaway ? AppColors.amberDark : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(type.label,
              style: AppTextStyles.caption
                  .copyWith(color: color, fontWeight: FontWeight.w600)),
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
      child: Text(status.label,
          style: AppTextStyles.caption
              .copyWith(color: status.color, fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Icon(Icons.receipt_long_outlined,
            color: AppColors.textSecondary, size: 40),
        const SizedBox(height: 12),
        Center(
          child: Text('Tidak ada pesanan untuk filter ini.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
        ),
      ],
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
          Text('Gagal memuat pesanan.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}
