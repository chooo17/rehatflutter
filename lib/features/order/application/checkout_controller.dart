import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../shared/models/order_model.dart';
import '../../auth/application/auth_controller.dart';
import '../../menu/application/cart_controller.dart';
import '../data/order_repository.dart';

/// Pilihan checkout + status pengiriman pesanan.
class CheckoutState {
  const CheckoutState({
    this.paymentMethod = PaymentMethod.qris,
    this.orderType = OrderType.dineIn,
    this.notes = '',
    this.voucherCode = '',
    this.voucher,
    this.isSubmitting = false,
    this.isValidatingVoucher = false,
    this.errorMessage,
  });

  final PaymentMethod paymentMethod;
  final OrderType orderType;
  final String notes;

  /// Kode voucher yang sedang diterapkan (kosong = tidak ada).
  final String voucherCode;

  /// Hasil validasi voucher (null bila belum/ tidak valid).
  final VoucherValidation? voucher;

  final bool isSubmitting;
  final bool isValidatingVoucher;
  final String? errorMessage;

  int get discountAmount => voucher?.isValid == true ? voucher!.discountAmount : 0;

  CheckoutState copyWith({
    PaymentMethod? paymentMethod,
    OrderType? orderType,
    String? notes,
    String? voucherCode,
    VoucherValidation? voucher,
    bool clearVoucher = false,
    bool? isSubmitting,
    bool? isValidatingVoucher,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CheckoutState(
      paymentMethod: paymentMethod ?? this.paymentMethod,
      orderType: orderType ?? this.orderType,
      notes: notes ?? this.notes,
      voucherCode: voucherCode ?? this.voucherCode,
      voucher: clearVoucher ? null : (voucher ?? this.voucher),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isValidatingVoucher: isValidatingVoucher ?? this.isValidatingVoucher,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class CheckoutController extends Notifier<CheckoutState> {
  @override
  CheckoutState build() => const CheckoutState();

  void setPaymentMethod(PaymentMethod method) =>
      state = state.copyWith(paymentMethod: method, clearError: true);

  void setOrderType(OrderType type) =>
      state = state.copyWith(orderType: type, clearError: true);

  void setNotes(String notes) => state = state.copyWith(notes: notes);

  /// Memvalidasi & menerapkan kode voucher terhadap subtotal saat ini.
  Future<void> applyVoucher(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(voucherCode: '', clearVoucher: true, clearError: true);
      return;
    }
    final subtotal = ref.read(cartTotalProvider);
    state = state.copyWith(isValidatingVoucher: true, clearError: true);
    try {
      final result = await ref
          .read(orderRepositoryProvider)
          .validateVoucher(code: trimmed, subtotal: subtotal);
      if (result.isValid) {
        state = state.copyWith(
          voucherCode: trimmed,
          voucher: result,
          isValidatingVoucher: false,
        );
      } else {
        state = state.copyWith(
          isValidatingVoucher: false,
          clearVoucher: true,
          errorMessage: 'Voucher tidak valid.',
        );
      }
    } on ApiException catch (e) {
      state = state.copyWith(
          isValidatingVoucher: false, clearVoucher: true, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
          isValidatingVoucher: false,
          clearVoucher: true,
          errorMessage: 'Gagal memeriksa voucher.');
    }
  }

  void clearVoucher() =>
      state = state.copyWith(voucherCode: '', clearVoucher: true);

  /// Mengirim pesanan. Mengembalikan [CheckoutResult] jika sukses, atau `null`.
  Future<CheckoutResult?> placeOrder() async {
    final items = ref.read(cartControllerProvider);
    if (items.isEmpty) {
      state = state.copyWith(errorMessage: 'Keranjang kosong.');
      return null;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final result = await ref.read(orderRepositoryProvider).createOrder(
            items: items,
            paymentMethod: state.paymentMethod,
            orderType: state.orderType,
            voucherCode: state.voucherCode.isEmpty ? null : state.voucherCode,
            notes: state.notes.isEmpty ? null : state.notes,
          );
      // Simpan hasil dulu agar layar konfirmasi bisa membacanya meski router refresh.
      ref.read(lastCheckoutResultProvider.notifier).state = result;
      ref.read(cartControllerProvider.notifier).clear();
      ref.invalidate(orderHistoryProvider);
      // Poin/stamp bertambah di sisi server setelah bayar — segarkan profil.
      ref.read(authControllerProvider.notifier).refreshUser();
      state = const CheckoutState(); // reset pilihan untuk order berikutnya
      return result;
    } on ApiException catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.message);
      return null;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Gagal membuat pesanan. Silakan coba lagi.',
      );
      return null;
    }
  }
}

final checkoutControllerProvider =
    NotifierProvider<CheckoutController, CheckoutState>(CheckoutController.new);

/// Menyimpan hasil checkout terakhir agar layar konfirmasi tahan terhadap
/// refresh router (yang menghapus `extra` GoRoute).
final lastCheckoutResultProvider = StateProvider<CheckoutResult?>((ref) => null);
