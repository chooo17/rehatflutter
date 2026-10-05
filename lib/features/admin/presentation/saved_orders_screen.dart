import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/order_model.dart';
import '../../../shared/widgets/neu.dart';
import '../../order/data/order_repository.dart';

/// (Admin) Pesanan BELUM BAYAR: pesanan yang disimpan/bayar-nanti (tunai) dan
/// pesanan QRIS yang menunggu pembayaran. Ketuk untuk membuka & menyelesaikan
/// pembayaran (tandai lunas tunai / tampilkan QRIS).
class SavedOrdersScreen extends ConsumerWidget {
  const SavedOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingOrdersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Pesanan Belum Bayar')),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.amber)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  color: AppColors.textSecondary, size: 36),
              const SizedBox(height: 10),
              Text('Gagal memuat pesanan.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
              TextButton(
                  onPressed: () => ref.invalidate(pendingOrdersProvider),
                  child: const Text('Coba lagi')),
            ],
          ),
        ),
        data: (orders) {
          if (orders.isEmpty) return const _Empty();
          return RefreshIndicator(
            color: AppColors.amber,
            onRefresh: () async => ref.invalidate(pendingOrdersProvider),
            child: ResponsiveListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount: orders.length,
              minItemWidth: 380,
              maxColumns: 3,
              runSpacing: 10,
              itemBuilder: (context, i) => _PendingCard(
                order: orders[i],
                onTap: () async {
                  await context.pushNamed(
                    RouteNames.orderDetail,
                    pathParameters: {'id': orders[i].id},
                  );
                  // Kembali dari detail → segarkan (mungkin sudah dibayar).
                  ref.invalidate(pendingOrdersProvider);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.order, required this.onTap});
  final OrderModel order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isQris = (order.paymentMethod ?? '').toLowerCase() == 'qris';
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
              Expanded(
                child: Text(order.customerName.isEmpty ? 'Pelanggan' : order.customerName,
                    style: AppTextStyles.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              _MethodChip(isQris: isQris),
            ],
          ),
          const SizedBox(height: 4),
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
              Icon(order.orderType.icon, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(order.orderType.label, style: AppTextStyles.bodySmall),
              const Spacer(),
              Text(Formatters.rupiah(order.total),
                  style: AppTextStyles.label.copyWith(color: AppColors.amberDark)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.touch_app_outlined,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('Ketuk → tampilkan QRIS / tandai lunas (tunai)',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({required this.isQris});
  final bool isQris;

  @override
  Widget build(BuildContext context) {
    final color = isQris ? AppColors.amberDark : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isQris ? Icons.qr_code_2_rounded : Icons.payments_outlined,
              size: 13, color: color),
          const SizedBox(width: 4),
          Text(isQris ? 'QRIS' : 'Tunai',
              style: AppTextStyles.caption
                  .copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

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
            child: Icon(Icons.bookmark_border_rounded,
                color: AppColors.amberDark, size: 36),
          ),
          const SizedBox(height: 16),
          Text('Tidak ada pesanan tertunda', style: AppTextStyles.titleLarge),
          const SizedBox(height: 6),
          Text('Pesanan disimpan / menunggu bayar akan muncul di sini.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
