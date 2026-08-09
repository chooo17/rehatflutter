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
import '../../order/presentation/widgets/complete_order_button.dart';

/// (Admin) Halaman "Pesanan": SEMUA pesanan (app pelanggan & kasir) dalam satu
/// layar, dipisah dua seksi — "Perlu tindakan" (aktif, ada tombol Tandai Selesai)
/// dan "Riwayat" (selesai/batal/refund, read-only). Terbaru dulu.
class AdminOrdersScreen extends ConsumerWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(adminOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pesanan')),
      body: ordersAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.amber)),
        error: (e, _) =>
            _ErrorState(onRetry: () => ref.invalidate(adminOrdersProvider)),
        data: (orders) {
          if (orders.isEmpty) return const _EmptyState();
          // Pisah aktif vs riwayat (urutan terbaru-dulu dijaga provider).
          final active = orders
              .where((o) => kActiveOrderStatuses.contains(o.status))
              .toList();
          final history = orders
              .where((o) => !kActiveOrderStatuses.contains(o.status))
              .toList();

          Widget card(OrderModel o) => _AdminOrderCard(
                order: o,
                onTap: () => context.pushNamed(
                  RouteNames.orderDetail,
                  pathParameters: {'id': o.id},
                ),
              );

          return RefreshIndicator(
            color: AppColors.amber,
            onRefresh: () async => ref.invalidate(adminOrdersProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                if (active.isNotEmpty) ...[
                  _SectionHeader('Perlu tindakan', count: active.length),
                  const SizedBox(height: 10),
                  for (final o in active) ...[card(o), const SizedBox(height: 10)],
                ],
                if (history.isNotEmpty) ...[
                  if (active.isNotEmpty) const SizedBox(height: 14),
                  _SectionHeader('Riwayat', count: history.length),
                  const SizedBox(height: 10),
                  for (final o in history) ...[
                    card(o),
                    const SizedBox(height: 10)
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Judul seksi + jumlah, untuk memisah "Perlu tindakan" & "Riwayat".
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {required this.count});
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title.toUpperCase(),
            style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6)),
        const SizedBox(width: 8),
        Text('$count',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textSecondary)),
      ],
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
      depth: 5,
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
                if (order.tableNumber != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Meja ${order.tableNumber}',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.amberDark,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
                const SizedBox(width: 10),
                Text('${order.itemCount} item', style: AppTextStyles.bodySmall),
                const Spacer(),
                Text(Formatters.rupiah(order.total),
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.amberDark)),
              ],
            ),
            // Pesanan aktif → langsung "Tandai Selesai" (status Diproses sudah
            // otomatis saat pembayaran diterima, jadi tak ada tombol antara).
            if (kActiveOrderStatuses.contains(order.status)) ...[
              const SizedBox(height: 12),
              CompleteOrderButton(order: order),
            ] else if (order.status == OrderStatus.completed) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 18, color: AppColors.success),
                    const SizedBox(width: 6),
                    Text('Selesai',
                        style: AppTextStyles.label
                            .copyWith(color: AppColors.success)),
                  ],
                ),
              ),
            ],
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
          child: Text('Belum ada pesanan.',
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
