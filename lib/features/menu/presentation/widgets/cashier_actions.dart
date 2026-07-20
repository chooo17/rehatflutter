import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/widgets/neu.dart';
import '../../../order/application/checkout_controller.dart';
import '../../../order/data/order_repository.dart';
import '../../../printer/application/printer_controller.dart';
import '../../../wallet/data/wallet_repository.dart';
import '../../application/cart_controller.dart';

/// Aksi kasir (admin) untuk isi keranjang saat ini: pilih tipe pesanan, nama
/// pelanggan, lalu bayar **Tunai**, **QRIS**, atau **Simpan (Bayar Nanti)**.
/// Dipakai di side cart tab Menu maupun layar Keranjang.
class CashierActions extends ConsumerStatefulWidget {
  const CashierActions({super.key});

  @override
  ConsumerState<CashierActions> createState() => _CashierActionsState();
}

enum _Mode { cash, qris, balance, save }

class _CashierActionsState extends ConsumerState<CashierActions> {
  final _nameController = TextEditingController();
  OrderType _orderType = OrderType.dineIn;
  bool _submitting = false;
  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit(_Mode mode) async {
    final items = ref.read(cartControllerProvider);
    if (items.isEmpty || _submitting) return;
    final messenger = ScaffoldMessenger.of(context);
    // Nama pelanggan WAJIB — dipakai di struk, notifikasi, & pengumuman grup.
    if (_nameController.text.trim().length < 2) {
      setState(() => _nameError = 'Nama pelanggan wajib diisi');
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Isi nama pelanggan dulu ya.')));
      return;
    }
    setState(() {
      _nameError = null;
      _submitting = true;
    });
    try {
      final result = await ref.read(orderRepositoryProvider).createCashierOrder(
            items: items,
            orderType: _orderType,
            customerName: _nameController.text,
            payNow: mode == _Mode.cash,
            paymentMethod:
                mode == _Mode.qris ? PaymentMethod.qris : PaymentMethod.cash,
          );
      // Bayar pakai saldo admin: potong saldo & tandai lunas. Bila saldo kurang,
      // ApiException dilempar → pesanan tetap dibuat (pending), tampilkan pesan.
      if (mode == _Mode.balance) {
        await ref
            .read(walletRepositoryProvider)
            .adminPayWithBalance(result.orderId);
      }
      ref.invalidate(adminOrdersProvider);
      ref.invalidate(pendingOrdersProvider);
      ref.read(cartControllerProvider.notifier).clear();
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _nameController.clear();
      });
      if (mode == _Mode.qris) {
        // Tampilkan QR (SNAP) + polling status di layar konfirmasi.
        ref.read(lastCheckoutResultProvider.notifier).state = result;
        context.pushNamed(RouteNames.confirmation, extra: result);
      } else {
        // Tunai / Saldo (lunas) → auto-cetak struk bila printer siap.
        final paid = mode == _Mode.cash || mode == _Mode.balance;
        if (paid) await _autoPrint(result.orderId);
        await _showResult(result, paid: paid);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Gagal membuat pesanan. Coba lagi.')));
    }
  }

  /// Auto-cetak struk (best-effort). Ambil detail pesanan lalu cetak; diam
  /// bila printer belum siap (admin bisa cetak manual dari detail pesanan).
  Future<void> _autoPrint(String orderId) async {
    if (!ref.read(printerControllerProvider).supported) return;
    try {
      final order =
          await ref.read(orderRepositoryProvider).fetchDetailAdmin(orderId);
      await ref.read(printerControllerProvider.notifier).autoPrintOnce(order);
    } catch (_) {}
  }

  Future<void> _showResult(CheckoutResult r, {required bool paid}) async {
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: paid ? AppColors.success : AppColors.amberDark,
                  shape: BoxShape.circle),
              child: Icon(
                  paid ? Icons.check_rounded : Icons.bookmark_added_rounded,
                  color: Colors.white,
                  size: 40),
            ),
            const SizedBox(height: 16),
            Text(paid ? 'Pesanan Lunas' : 'Pesanan Disimpan',
                style: AppTextStyles.titleLarge),
            const SizedBox(height: 6),
            if (paid) ...[
              Text('Nomor antrian', style: AppTextStyles.caption),
              const SizedBox(height: 2),
              Text(r.queueNumber.isNotEmpty ? r.queueNumber : '—',
                  style: AppTextStyles.displayMedium
                      .copyWith(color: AppColors.espresso)),
            ] else
              Text('Menunggu pembayaran.\nTandai "Lunas (Tunai)" saat dibayar.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Text('Total ${Formatters.rupiah(r.total)}',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: NeuButton(
              expand: true,
              accent: true,
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text('Selesai',
                  style: AppTextStyles.button.copyWith(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = ref.watch(cartTotalProvider);
    final empty = ref.watch(cartControllerProvider).isEmpty;
    final disabled = _submitting || empty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tipe pesanan
        Row(
          children: [
            for (final t in OrderType.values) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _orderType = t),
                  child: Container(
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _orderType == t
                          ? AppColors.espresso
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _orderType == t
                              ? AppColors.espresso
                              : AppColors.border),
                    ),
                    child: Text(t.label,
                        style: AppTextStyles.caption.copyWith(
                          color: _orderType == t
                              ? AppColors.crema
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                ),
              ),
              if (t != OrderType.values.last) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
          decoration: InputDecoration(
            hintText: 'Nama pelanggan (wajib)',
            errorText: _nameError,
            isDense: true,
            filled: true,
            fillColor: AppColors.crema,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('Total', style: AppTextStyles.bodyMedium),
            const Spacer(),
            Text(Formatters.rupiah(total),
                style: AppTextStyles.titleLarge
                    .copyWith(color: AppColors.amberDark)),
          ],
        ),
        const SizedBox(height: 12),
        if (_submitting)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.6, color: AppColors.amber)),
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: NeuButton(
                  expand: true,
                  accent: true,
                  onPressed: disabled ? null : () => _submit(_Mode.cash),
                  child: Text('Tunai',
                      style: AppTextStyles.button.copyWith(color: Colors.white)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NeuButton(
                  expand: true,
                  onPressed: disabled ? null : () => _submit(_Mode.qris),
                  child: Text('QRIS',
                      style: AppTextStyles.button
                          .copyWith(color: AppColors.textPrimary)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          NeuButton(
            expand: true,
            onPressed: disabled ? null : () => _submit(_Mode.balance),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.account_balance_wallet_rounded,
                    size: 18, color: AppColors.espresso),
                const SizedBox(width: 8),
                Text('Bayar pakai Saldo',
                    style: AppTextStyles.button
                        .copyWith(color: AppColors.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          NeuButton(
            expand: true,
            onPressed: disabled ? null : () => _submit(_Mode.save),
            child: Text('Simpan (Bayar Nanti)',
                style:
                    AppTextStyles.button.copyWith(color: AppColors.textPrimary)),
          ),
        ],
      ],
    );
  }
}
