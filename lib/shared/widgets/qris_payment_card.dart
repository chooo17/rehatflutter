import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../features/order/data/order_repository.dart';
import 'neu.dart';

/// Kartu pembayaran untuk pesanan yang belum dibayar.
///
/// - DOKU aktif → tombol **Bayar Sekarang** membuka halaman DOKU Checkout.
/// - DOKU belum aktif → tampilkan **QRIS statis** (`assets/qris/qris.png`) + ACC admin.
class QrisPaymentCard extends ConsumerStatefulWidget {
  const QrisPaymentCard({super.key, required this.orderId, required this.amount});

  final String orderId;
  final int amount;

  @override
  ConsumerState<QrisPaymentCard> createState() => _QrisPaymentCardState();
}

class _QrisPaymentCardState extends ConsumerState<QrisPaymentCard> {
  bool _loading = false;

  Future<void> _pay() async {
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final session =
          await ref.read(orderRepositoryProvider).createPayment(widget.orderId);
      if (!mounted) return;

      if (session.hasUrl) {
        final ok = await launchUrl(
          Uri.parse(session.paymentUrl!),
          mode: LaunchMode.externalApplication,
        );
        if (!ok && mounted) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(
                content: Text('Tidak bisa membuka halaman pembayaran.')));
        } else if (mounted) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(
                content: Text(
                    'Selesaikan pembayaran di halaman DOKU, lalu tarik untuk menyegarkan status.')));
        }
      } else {
        // DOKU belum dikonfigurasi → tampilkan QRIS statis.
        _showStaticQris();
      }
    } on ApiException catch (e) {
      if (mounted) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
              const SnackBar(content: Text('Gagal memulai pembayaran.')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showStaticQris() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundLight,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _StaticQrisSheet(amount: widget.amount),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(20),
      radius: 18,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance_wallet_rounded,
                  color: AppColors.espresso, size: 22),
              const SizedBox(width: 8),
              Text('Pembayaran', style: AppTextStyles.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          Text('Total pembayaran',
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(Formatters.rupiah(widget.amount),
              style: AppTextStyles.displaySmall
                  .copyWith(color: AppColors.amberDark)),
          const SizedBox(height: 16),
          NeuButton(
            expand: true,
            accent: true,
            onPressed: _loading ? null : _pay,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(Colors.white)),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.qr_code_2_rounded,
                          size: 20, color: Colors.white),
                      const SizedBox(width: 8),
                      Text('Bayar Sekarang',
                          style: AppTextStyles.button
                              .copyWith(color: Colors.white)),
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          Text('QRIS / e-wallet / VA / kartu — via DOKU',
              textAlign: TextAlign.center, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

/// Bottom sheet QRIS statis (fallback bila DOKU belum aktif).
class _StaticQrisSheet extends StatelessWidget {
  const _StaticQrisSheet({required this.amount});
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Bayar dengan QRIS', style: AppTextStyles.displaySmall),
          const SizedBox(height: 4),
          Text('Pindai dari GoPay / OVO / DANA / m-banking',
              textAlign: TextAlign.center, style: AppTextStyles.bodySmall),
          const SizedBox(height: 16),
          NeuInset(
            radius: 20,
            padding: const EdgeInsets.all(14),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                'assets/qris/qris.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_2_rounded,
                          color: AppColors.textSecondary, size: 48),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text('QRIS belum diatur.\nTambahkan assets/qris/qris.png',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySmall),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ),
          const SizedBox(height: 16),
          Text(Formatters.rupiah(amount),
              style: AppTextStyles.displaySmall
                  .copyWith(color: AppColors.amberDark)),
          const SizedBox(height: 8),
          Text('Setelah membayar, pesanan dikonfirmasi admin lalu diproses.',
              textAlign: TextAlign.center, style: AppTextStyles.bodySmall),
          const SizedBox(height: 16),
          NeuButton(
            expand: true,
            accent: true,
            onPressed: () => Navigator.pop(context),
            child: Text('Tutup',
                style: AppTextStyles.button.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
