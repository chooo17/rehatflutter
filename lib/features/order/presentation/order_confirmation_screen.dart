import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/order_model.dart';
import '../../../shared/widgets/neu.dart';
import '../../../shared/widgets/qris_payment_card.dart';

/// Layar konfirmasi setelah pesanan berhasil dibuat.
class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({super.key, required this.result});

  final CheckoutResult result;

  @override
  Widget build(BuildContext context) {
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
                      'Selesaikan pembayaran untuk mulai diproses.',
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
                      child: result.queueNumber.isNotEmpty
                          ? Column(
                              children: [
                                Text('Nomor antrian',
                                    style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Text(result.queueNumber,
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
                              _statusLabel(result.paymentStatus),
                              valueColor: AppColors.warning),
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
                    const SizedBox(height: 20),
                    QrisPaymentCard(orderId: result.orderId, amount: result.total)
                        .animate()
                        .fadeIn(delay: 550.ms),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Column(
                children: [
                  NeuButton(
                    expand: true,
                    accent: true,
                    onPressed: () => context.goNamed(RouteNames.orderHistory),
                    child: Text('Lihat Pesanan Saya',
                        style: AppTextStyles.button.copyWith(color: Colors.white)),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => context.goNamed(RouteNames.home),
                    child: const Text('Kembali ke Beranda'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu pembayaran';
      case 'paid':
      case 'settlement':
        return 'Lunas';
      default:
        return status;
    }
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
