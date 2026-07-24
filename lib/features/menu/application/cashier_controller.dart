import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/models/cart_item_model.dart';
import '../../../shared/models/order_model.dart';
import '../../order/data/order_repository.dart';
import '../../wallet/data/wallet_repository.dart';
import 'cart_controller.dart';

/// Cara bayar di kasir (walk-in). Dipakai bersama antara controller & widget.
enum CashierPayMode { cash, qris, balance, save }

/// Status pengiriman pesanan kasir.
class CashierState {
  const CashierState({
    this.isSubmitting = false,
    this.errorMessage,
    this.pendingOrder,
    this.pendingSignature,
  });

  final bool isSubmitting;
  final String? errorMessage;

  /// Pesanan yang SUDAH dibuat di server tetapi potong saldo admin-nya gagal
  /// (mis. saldo kurang). Dipakai ulang saat kasir menekan "Bayar pakai Saldo"
  /// lagi supaya tidak lahir pesanan kedua untuk keranjang yang sama.
  final CheckoutResult? pendingOrder;

  /// Sidik jari isi keranjang + pilihan saat [pendingOrder] dibuat. Pesanan
  /// tertunda hanya boleh dipakai ulang bila sidik jarinya masih sama.
  final String? pendingSignature;

  CashierState copyWith({
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    CheckoutResult? pendingOrder,
    String? pendingSignature,
  }) {
    return CashierState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      pendingOrder: pendingOrder ?? this.pendingOrder,
      pendingSignature: pendingSignature ?? this.pendingSignature,
    );
  }
}

/// Logika pembuatan + pembayaran pesanan kasir. Dipisah dari widget agar bisa
/// diuji unit — sekaligus tempat penjaga anti-pesanan-ganda jalur Saldo hidup
/// (kembaran [CheckoutController] untuk sisi pelanggan).
class CashierController extends Notifier<CashierState> {
  @override
  CashierState build() => const CashierState();

  /// Sidik jari isi pesanan + pilihan yang memengaruhi apa yang dibayar.
  String _signatureOf(
      List<CartItemModel> items, CashierPayMode mode, OrderType orderType) {
    final lines = [for (final e in items) '${e.lineId}x${e.quantity}']..sort();
    return '${lines.join('|')}#${mode.name}#${orderType.name}';
  }

  /// Membuat pesanan kasir & (untuk Saldo) langsung memotong saldo admin.
  /// Mengembalikan [CheckoutResult] bila sukses, atau `null` bila gagal —
  /// widget membaca [CashierState.errorMessage] untuk menampilkan pesan.
  Future<CheckoutResult?> submit({
    required CashierPayMode mode,
    required String customerName,
    required OrderType orderType,
  }) async {
    final items = ref.read(cartControllerProvider);
    if (items.isEmpty) {
      state = state.copyWith(errorMessage: 'Keranjang kosong.');
      return null;
    }

    final signature = _signatureOf(items, mode, orderType);
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final repo = ref.read(orderRepositoryProvider);
      // Pesanan sebelumnya sudah dibuat & isinya belum berubah → JANGAN buat
      // pesanan baru, cukup ulangi pembayarannya.
      final reusable =
          state.pendingSignature == signature ? state.pendingOrder : null;
      final result = reusable ??
          await repo.createCashierOrder(
            items: items,
            orderType: orderType,
            customerName: customerName,
            payNow: mode == CashierPayMode.cash,
            paymentMethod: mode == CashierPayMode.qris
                ? PaymentMethod.qris
                : PaymentMethod.cash,
          );

      // Bayar pakai saldo admin: potong saldo & tandai lunas. Bila GAGAL,
      // pesanan sudah terlanjur ada di server — simpan sebagai pesanan tertunda
      // supaya penekanan berikutnya mengulang pembayaran, bukan membuat pesanan
      // kedua untuk keranjang yang sama.
      if (mode == CashierPayMode.balance) {
        try {
          await ref
              .read(walletRepositoryProvider)
              .adminPayWithBalance(result.orderId);
        } catch (e) {
          state = state.copyWith(
            isSubmitting: false,
            errorMessage: e is ApiException
                ? e.message
                : 'Gagal membayar dengan saldo. Coba lagi.',
            pendingOrder: result,
            pendingSignature: signature,
          );
          return null;
        }
      }

      Analytics.orderCreated(
          value: result.total, paymentMethod: mode.name, source: 'cashier');
      ref.invalidate(adminOrdersProvider);
      ref.invalidate(pendingOrdersProvider);
      ref.read(cartControllerProvider.notifier).clear();
      state = const CashierState(); // reset untuk pesanan berikutnya
      return result;
    } on ApiException catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.message);
      return null;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Gagal membuat pesanan. Coba lagi.',
      );
      return null;
    }
  }
}

final cashierControllerProvider =
    NotifierProvider<CashierController, CashierState>(CashierController.new);
