import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../features/order/data/order_repository.dart';
import '../../features/printer/application/printer_controller.dart';
import 'neu.dart';

/// Kartu pembayaran untuk pesanan yang belum dibayar.
///
/// - DOKU Direct API aktif → **Generate QRIS** via API, QR dirender di app.
/// - DOKU belum aktif → tampilkan **QRIS statis** (`assets/qris/qris.png`) + ACC admin.
class QrisPaymentCard extends ConsumerStatefulWidget {
  const QrisPaymentCard({super.key, required this.orderId, required this.amount});

  final String orderId;
  final int amount;

  @override
  ConsumerState<QrisPaymentCard> createState() => _QrisPaymentCardState();
}

class _QrisPaymentCardState extends ConsumerState<QrisPaymentCard> {
  bool _loading = true;
  QrisResult? _result;

  @override
  void initState() {
    super.initState();
    _prefetch();
  }

  /// Siapkan sesi pembayaran lebih dulu, agar saat tombol ditekan URL sudah siap
  /// dan bisa dibuka SINKRON — menghindari popup diblok Safari iOS akibat jeda
  /// async antara tap dan `launchUrl`.
  Future<void> _prefetch() async {
    if (mounted) setState(() => _loading = true);
    try {
      final r =
          await ref.read(orderRepositoryProvider).fetchQris(widget.orderId);
      if (mounted) {
        setState(() {
          _result = r;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _result = null;
          _loading = false;
        });
      }
    }
  }

  void _pay() {
    final r = _result;
    if (r == null) {
      _prefetch(); // belum siap / gagal → coba siapkan lagi
      return;
    }
    if (r.hasUrl) {
      // Buka SINKRON (tanpa await) agar tetap dalam konteks gesture pengguna →
      // tidak diblok popup Safari iOS.
      launchUrl(Uri.parse(r.paymentUrl!), mode: LaunchMode.externalApplication);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text(
                'Membuka halaman pembayaran DOKU. Setelah bayar, tarik untuk menyegarkan status.')));
    } else if (r.hasQr) {
      _showDynamicQris(r.qrisContent!);
    } else {
      _showStaticQris();
    }
  }

  void _showDynamicQris(String qrData) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundLight,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _DynamicQrisSheet(
          orderId: widget.orderId, qrData: qrData, amount: widget.amount),
    );
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

/// Bottom sheet QRIS dinamis dari DOKU (QR dirender dari `qrContent`).
/// Memantau status pembayaran (polling); begitu lunas, otomatis menampilkan
/// layar sukses + nomor antrian tanpa perlu menutup/refresh manual.
class _DynamicQrisSheet extends ConsumerWidget {
  const _DynamicQrisSheet(
      {required this.orderId, required this.qrData, required this.amount});
  final String orderId;
  final String qrData;
  final int amount;

  /// Auto-cetak struk saat lunas — hanya di perangkat kasir yang printer-nya
  /// tersambung (dedupe di controller). Diam bila bukan admin / tanpa printer.
  Future<void> _autoPrint(WidgetRef ref) async {
    if (!ref.read(printerControllerProvider).connected) return;
    try {
      final order =
          await ref.read(orderRepositoryProvider).fetchDetailAdmin(orderId);
      await ref.read(printerControllerProvider.notifier).autoPrintOnce(order);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Begitu status berubah jadi lunas → cetak struk otomatis.
    ref.listen(orderStatusPollProvider(orderId), (prev, next) {
      if (next.valueOrNull?.isPaid ?? false) _autoPrint(ref);
    });
    final status = ref.watch(orderStatusPollProvider(orderId)).valueOrNull;
    final paid = status?.isPaid ?? false;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, 24 + MediaQuery.of(context).padding.bottom),
      child: paid
          ? _PaidView(queueNumber: status?.queueNumber ?? '', amount: amount)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Scan untuk Bayar', style: AppTextStyles.displaySmall),
                const SizedBox(height: 4),
                Text('Pindai QRIS dari GoPay / OVO / DANA / m-banking',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall),
                const SizedBox(height: 16),
                NeuInset(
                  radius: 20,
                  padding: const EdgeInsets.all(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 240,
                      backgroundColor: Colors.white,
                      errorStateBuilder: (_, __) => const SizedBox(
                        height: 240,
                        child: Center(child: Text('QRIS tidak dapat dirender.')),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(Formatters.rupiah(amount),
                    style: AppTextStyles.displaySmall
                        .copyWith(color: AppColors.amberDark)),
                const SizedBox(height: 10),
                // Indikator menunggu pembayaran (polling aktif).
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.amber)),
                    const SizedBox(width: 8),
                    Text('Menunggu pembayaran…',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 16),
                NeuButton(
                  expand: true,
                  onPressed: () => Navigator.pop(context),
                  child: Text('Tutup',
                      style: AppTextStyles.button
                          .copyWith(color: AppColors.textPrimary)),
                ),
              ],
            ),
    );
  }
}

/// Tampilan sukses saat pembayaran QRIS terdeteksi lunas.
class _PaidView extends StatelessWidget {
  const _PaidView({required this.queueNumber, required this.amount});
  final String queueNumber;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(
              color: AppColors.success, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
        ),
        const SizedBox(height: 16),
        Text('Pembayaran Berhasil', style: AppTextStyles.displaySmall),
        const SizedBox(height: 6),
        Text('Total ${Formatters.rupiah(amount)} telah dibayar.',
            textAlign: TextAlign.center, style: AppTextStyles.bodySmall),
        if (queueNumber.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Nomor antrian',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(queueNumber,
              style: AppTextStyles.displayMedium
                  .copyWith(color: AppColors.espresso)),
        ],
        const SizedBox(height: 20),
        NeuButton(
          expand: true,
          accent: true,
          onPressed: () => Navigator.pop(context),
          child: Text('Selesai',
              style: AppTextStyles.button.copyWith(color: Colors.white)),
        ),
      ],
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
