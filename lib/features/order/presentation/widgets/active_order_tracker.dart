import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/router/route_names.dart';
import '../../../../shared/models/order_model.dart';
import '../../../auth/application/auth_controller.dart';
import '../../data/order_repository.dart';
import 'complete_order_button.dart';

/// Tahap yang dilihat pelanggan:
/// Dibuat → Dibayar → Diproses → Selesai.
/// ('Siap diambil' tetap ada di sistem dan tampil sebagai label status saat
/// barista menandainya — posisinya di antara Diproses dan Selesai.)
const kTrackSteps = ['Dibuat', 'Dibayar', 'Diproses', 'Selesai'];

/// Indeks tahap terakhir yang SUDAH tercapai untuk sebuah status.
int trackStepIndex(OrderStatus s) {
  switch (s) {
    case OrderStatus.pending:
      return 0; // pesanan dibuat, menunggu bayar
    case OrderStatus.paid:
      return 1; // pembayaran diterima
    case OrderStatus.preparing:
    case OrderStatus.ready:
      return 2; // sedang diproses / siap diambil
    case OrderStatus.completed:
      return 3;
    case OrderStatus.cancelled:
    case OrderStatus.refunded:
      return 0;
  }
}

/// Banner pelacakan pesanan aktif di halaman Menu. Auto-refresh cepat, dan
/// menyegarkan SEKETIKA saat aplikasi kembali ke depan (mis. sepulang dari
/// halaman pembayaran DOKU) sehingga status langsung ter-update.
class ActiveOrderTracker extends ConsumerStatefulWidget {
  const ActiveOrderTracker({super.key});

  @override
  ConsumerState<ActiveOrderTracker> createState() => _ActiveOrderTrackerState();
}

class _ActiveOrderTrackerState extends ConsumerState<ActiveOrderTracker>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kembali ke aplikasi (mis. selesai bayar di browser) → refresh seketika.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(ordersTrackingProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(activeOrderProvider);
    if (order == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: OrderTrackCard(
        order: order,
        onTap: () => context.pushNamed(
          RouteNames.orderDetail,
          pathParameters: {'id': order.id},
        ),
      ),
    );
  }
}

/// Kartu pelacakan satu pesanan: nomor antrian, status, & progres 4 tahap.
/// Dipakai di banner Menu maupun daftar layar "Lacak Pesanan", dan selaras
/// dengan kartu di layar **Pesanan Masuk** (tombol aksi yang sama).
class OrderTrackCard extends ConsumerWidget {
  const OrderTrackCard({super.key, required this.order, this.onTap});

  final OrderModel order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tombol ubah status hanya untuk staf/admin — pelanggan cukup memantau.
    final isAdmin = ref.watch(isAdminProvider);
    final idx = trackStepIndex(order.status);
    final color = order.status.color;
    final done = order.status == OrderStatus.completed;
    final cancelled = order.status == OrderStatus.cancelled;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.crema,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text('Antrian',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary, fontSize: 10)),
                        Text(
                          order.queueNumber.isNotEmpty ? order.queueNumber : '—',
                          style: AppTextStyles.titleMedium
                              .copyWith(color: AppColors.espresso),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.customerName.trim().isNotEmpty
                              ? 'Pesanan ${order.customerName}'
                              : 'Pesanan kamu',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                order.status.label,
                                style: AppTextStyles.titleMedium
                                    .copyWith(color: color),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    Icon(Icons.chevron_right_rounded,
                        color: AppColors.textSecondary),
                ],
              ),
              if (!cancelled) ...[
                const SizedBox(height: 12),
                // Progres 4 tahap: Dibuat → Dibayar → Diproses → Selesai
                Row(
                  children: [
                    for (var i = 0; i < kTrackSteps.length; i++) ...[
                      Expanded(
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOut,
                              height: 4,
                              decoration: BoxDecoration(
                                color: i <= idx ? color : AppColors.border,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              kTrackSteps[i],
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 10,
                                color: i <= idx
                                    ? (done ? color : AppColors.textPrimary)
                                    : AppColors.textSecondary,
                                fontWeight: i == idx
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i != kTrackSteps.length - 1) const SizedBox(width: 6),
                    ],
                  ],
                ),
                // Staf: ubah status langsung dari kartu (tak perlu buka detail).
                if (isAdmin) ...[
                  const SizedBox(height: 12),
                  CompleteOrderButton(order: order),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
