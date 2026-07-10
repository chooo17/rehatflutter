import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/order_model.dart';

/// Timeline visual progres pesanan (untuk pelanggan).
/// Menunggu bayar → Dibayar → Diproses → Siap diambil → Selesai.
class OrderTrackingTimeline extends StatelessWidget {
  const OrderTrackingTimeline({super.key, required this.status});

  final OrderStatus status;

  // (status, label, ikon) sesuai urutan lifecycle.
  static const List<(OrderStatus, String, IconData)> _steps = [
    (OrderStatus.pending, 'Menunggu pembayaran', Icons.schedule_rounded),
    (OrderStatus.paid, 'Pembayaran diterima', Icons.payments_rounded),
    (OrderStatus.preparing, 'Sedang diproses', Icons.local_cafe_rounded),
    (OrderStatus.ready, 'Siap diambil', Icons.shopping_bag_rounded),
    (OrderStatus.completed, 'Selesai', Icons.done_all_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    if (status == OrderStatus.cancelled) return const _CancelledCard();

    final currentIndex = OrderStatus.flow.indexOf(status);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _steps.length; i++)
            _StepRow(
              label: _steps[i].$2,
              icon: _steps[i].$3,
              done: i < currentIndex,
              active: i == currentIndex,
              isLast: i == _steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.icon,
    required this.done,
    required this.active,
    required this.isLast,
  });

  final String label;
  final IconData icon;
  final bool done;
  final bool active;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final reached = done || active;
    final circleColor = active
        ? AppColors.amber
        : (done ? AppColors.espresso : AppColors.crema);
    final iconColor = reached ? AppColors.crema : AppColors.amberLight;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: reached ? Colors.transparent : AppColors.border,
                  ),
                ),
                child: Icon(done ? Icons.check_rounded : icon,
                    color: iconColor, size: 18),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2.5,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: done ? AppColors.espresso : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: (active
                              ? AppTextStyles.titleMedium
                              : AppTextStyles.bodyLarge)
                          .copyWith(
                        color: reached
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w400,
                      )),
                  if (active) ...[
                    const SizedBox(height: 2),
                    Text('Status saat ini',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.amberDark)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelledCard extends StatelessWidget {
  const _CancelledCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cancel_rounded, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Pesanan dibatalkan',
                style: AppTextStyles.titleMedium
                    .copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
