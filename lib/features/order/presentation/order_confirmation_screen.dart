import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/order_model.dart';
import '../../../shared/widgets/neu.dart';
import '../../../shared/widgets/qris_payment_card.dart';
import '../../auth/application/auth_controller.dart';
import '../data/order_repository.dart';

/// Layar konfirmasi setelah pesanan berhasil dibuat.
class OrderConfirmationScreen extends ConsumerWidget {
  const OrderConfirmationScreen({super.key, required this.result});

  final CheckoutResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(isGuestProvider);
    // Polling status pembayaran (tiap 5 dtk) → status, nomor antrian, dan
    // hilangnya tombol bayar terjadi otomatis begitu pembayaran terkonfirmasi.
    final live = ref.watch(orderStatusPollProvider(result.orderId)).valueOrNull;
    final liveQueue = live?.queueNumber ?? '';
    final queueNumber = liveQueue.isNotEmpty ? liveQueue : result.queueNumber;
    // Lunas bila polling melaporkan paid, atau nomor antrian sudah keluar,
    // atau status awal pesanan memang sudah lunas (mis. bayar di kasir).
    final isPaid = (live?.isPaid ?? false) ||
        queueNumber.isNotEmpty ||
        _isPaidStatus(result.paymentStatus);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                child: Column(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 52),
                    )
                        .animate()
                        .scale(duration: 450.ms, curve: Curves.easeOutBack)
                        .fadeIn(),
                    const SizedBox(height: 24),
                    Text('Pesanan dibuat!',
                            style: AppTextStyles.displayMedium,
                            textAlign: TextAlign.center)
                        .animate()
                        .fadeIn(delay: 200.ms),
                    const SizedBox(height: 8),
                    Text(
                      isPaid
                          ? 'Pembayaran diterima — pesanan sedang diproses.'
                          : 'Selesaikan pembayaran untuk mulai diproses.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                    ).animate().fadeIn(delay: 300.ms),
                    const SizedBox(height: 24),
                    // Nomor antrian besar — atau info menunggu pembayaran.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.crema,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: queueNumber.isNotEmpty
                          ? Column(
                              children: [
                                Text('Nomor antrian',
                                    style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Text(queueNumber,
                                    style: AppTextStyles.displayLarge
                                        .copyWith(color: AppColors.espresso)),
                              ],
                            )
                          : Column(
                              children: [
                                Icon(Icons.hourglass_top_rounded,
                                    color: AppColors.amberDark, size: 28),
                                const SizedBox(height: 8),
                                Text('Menunggu pembayaran',
                                    style: AppTextStyles.titleMedium),
                                const SizedBox(height: 4),
                                Text(
                                  'Nomor antrian akan muncul setelah pembayaran dikonfirmasi.',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                    ).animate().fadeIn(delay: 380.ms).scale(
                        begin: const Offset(0.96, 0.96),
                        end: const Offset(1, 1)),
                    const SizedBox(height: 20),
                    NeuCard(
                      padding: const EdgeInsets.all(20),
                      radius: 20,
                      child: Column(
                        children: [
                          _row('Tipe pesanan', result.orderType.label),
                          const Divider(height: 24),
                          _row('Metode', result.paymentMethod.label),
                          const Divider(height: 24),
                          _row('Status pembayaran',
                              isPaid ? 'Lunas' : 'Menunggu pembayaran',
                              valueColor: isPaid
                                  ? AppColors.success
                                  : AppColors.warning),
                          if (result.discountAmount > 0) ...[
                            const Divider(height: 24),
                            _row('Diskon',
                                '- ${Formatters.rupiah(result.discountAmount)}',
                                valueColor: AppColors.success),
                          ],
                          const Divider(height: 24),
                          _row('Total', Formatters.rupiah(result.total),
                              emphasize: true),
                        ],
                      ),
                    ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.08, end: 0),
                    // Tombol pembayaran hanya bila BELUM lunas.
                    if (!isPaid) ...[
                      const SizedBox(height: 20),
                      QrisPaymentCard(
                              orderId: result.orderId, amount: result.total)
                          .animate()
                          .fadeIn(delay: 550.ms),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Column(
                children: [
                  if (isGuest)
                    NeuButton(
                      expand: true,
                      accent: true,
                      onPressed: () => context.goNamed(RouteNames.guestMenu),
                      child: Text('Kembali ke Menu',
                          style: AppTextStyles.button
                              .copyWith(color: Colors.white)),
                    )
                  else ...[
                    NeuButton(
                      expand: true,
                      accent: true,
                      onPressed: () => context.goNamed(RouteNames.orderHistory),
                      child: Text('Lihat Pesanan Saya',
                          style: AppTextStyles.button
                              .copyWith(color: Colors.white)),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => context.goNamed(RouteNames.home),
                      child: const Text('Kembali ke Beranda'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Status awal pesanan (dari pembuatan) yang menandakan sudah lunas.
  bool _isPaidStatus(String status) {
    const paid = {'paid', 'settlement', 'success', 'processing', 'completed'};
    return paid.contains(status.toLowerCase());
  }

  Widget _row(String label, String value,
      {bool emphasize = false, Color? valueColor}) {
    return Row(
      children: [
        Text(label,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary)),
        const Spacer(),
        Text(
          value,
          style: (emphasize ? AppTextStyles.titleLarge : AppTextStyles.label)
              .copyWith(color: valueColor ?? AppColors.textPrimary),
        ),
      ],
    );
  }
}
