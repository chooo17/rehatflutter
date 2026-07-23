import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../shared/models/cart_item_model.dart';
import '../../../shared/models/order_model.dart';
import '../../auth/application/auth_controller.dart';
import '../../wallet/data/wallet_repository.dart';
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
    this.pendingOrder,
    this.pendingSignature,
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

  /// Pesanan yang SUDAH dibuat di server tetapi pembayarannya gagal (mis.
  /// saldo kurang). Dipakai ulang saat pengguna menekan "Bayar" lagi supaya
  /// tidak lahir pesanan kedua untuk keranjang yang sama.
  final CheckoutResult? pendingOrder;

  /// Sidik jari isi keranjang + pilihan checkout saat [pendingOrder] dibuat.
  /// [pendingOrder] hanya boleh dipakai ulang bila sidik jarinya masih sama —
  /// kalau tidak, pengguna bisa membayar pesanan yang bukan isi keranjangnya.
  final String? pendingSignature;

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
    CheckoutResult? pendingOrder,
    String? pendingSignature,
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
      pendingOrder: pendingOrder ?? this.pendingOrder,
      pendingSignature: pendingSignature ?? this.pendingSignature,
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

  /// Sidik jari isi keranjang + pilihan yang MEMPENGARUHI isi pesanan.
  /// Catatan dikecualikan: mengubahnya tidak mengubah apa yang dibayar.
  String _signatureOf(List<CartItemModel> items) {
    final lines = [for (final e in items) '${e.lineId}x${e.quantity}']..sort();
    return '${lines.join('|')}'
        '#${state.paymentMethod.name}'
        '#${state.orderType.name}'
        '#${state.voucherCode}';
  }

  /// Mengirim pesanan. Untuk tamu, sertakan [guestName]/[guestPhone].
  /// Mengembalikan [CheckoutResult] jika sukses, atau `null`.
  Future<CheckoutResult?> placeOrder({String? guestName, String? guestPhone}) async {
    final items = ref.read(cartControllerProvider);
    if (items.isEmpty) {
      state = state.copyWith(errorMessage: 'Keranjang kosong.');
      return null;
    }

    final isGuest = ref.read(authControllerProvider).isGuest;
    if (isGuest && (guestName == null || guestName.trim().isEmpty)) {
      state = state.copyWith(errorMessage: 'Nama wajib diisi.');
      return null;
    }
    // No. HP tamu WAJIB — WhatsApp satu-satunya kanal notifikasi bagi tamu.
    if (isGuest &&
        (guestPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '').length < 8) {
      state = state.copyWith(
          errorMessage: 'No. HP / WhatsApp wajib diisi (min 8 angka).');
      return null;
    }

    // Sidik jari isi pesanan: dipakai untuk memutuskan apakah pesanan yang
    // gagal dibayar tadi masih mewakili keranjang saat ini.
    final signature = _signatureOf(items);

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final repo = ref.read(orderRepositoryProvider);
      // Pesanan sebelumnya sudah dibuat & isinya belum berubah → JANGAN buat
      // pesanan baru, cukup ulangi pembayarannya.
      final reusable = state.pendingSignature == signature
          ? state.pendingOrder
          : null;
      final result = reusable ??
          (isGuest
              ? await repo.createGuestOrder(
                  items: items,
                  paymentMethod: state.paymentMethod,
                  orderType: state.orderType,
                  notes: state.notes.isEmpty ? null : state.notes,
                  guestName: guestName!,
                  guestPhone: guestPhone,
                )
              : await repo.createOrder(
                  items: items,
                  paymentMethod: state.paymentMethod,
                  orderType: state.orderType,
                  voucherCode:
                      state.voucherCode.isEmpty ? null : state.voucherCode,
                  notes: state.notes.isEmpty ? null : state.notes,
                ));
      // Bayar pakai Saldo Rehat: langsung potong saldo & tandai lunas.
      //
      // Bila potong saldo GAGAL (mis. saldo kurang), pesanan sudah terlanjur
      // ada di server. Simpan sebagai `pendingOrder` supaya penekanan "Bayar"
      // berikutnya MENGULANG PEMBAYARAN pesanan itu, bukan membuat pesanan
      // kedua untuk keranjang yang sama.
      if (!isGuest && state.paymentMethod == PaymentMethod.balance) {
        try {
          await ref
              .read(walletRepositoryProvider)
              .payWithBalance(result.orderId);
        } catch (e) {
          state = state.copyWith(
            isSubmitting: false,
            errorMessage: e is ApiException
                ? e.message
                : 'Gagal membayar dengan saldo. Silakan coba lagi.',
            pendingOrder: result,
            pendingSignature: signature,
          );
          return null;
        }
      }
      // Simpan hasil dulu agar layar konfirmasi bisa membacanya meski router refresh.
      ref.read(lastCheckoutResultProvider.notifier).state = result;
      ref.read(cartControllerProvider.notifier).clear();
      if (!isGuest) {
        ref.invalidate(orderHistoryProvider);
        // Banner & layar pelacakan langsung menampilkan pesanan baru.
        ref.invalidate(ordersTrackingProvider);
        // Poin/stamp bertambah di sisi server setelah bayar — segarkan profil.
        ref.read(authControllerProvider.notifier).refreshUser();
      }
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
