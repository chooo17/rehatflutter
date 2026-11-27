import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/models/cart_item_model.dart';
import '../../../shared/models/delivery_models.dart';
import '../../../shared/models/order_model.dart';
import '../../auth/application/auth_controller.dart';
import '../../delivery/data/delivery_repository.dart';
import '../../wallet/data/wallet_repository.dart';
import '../../menu/application/cart_controller.dart';
import '../data/order_repository.dart';
import 'table_provider.dart';

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
    this.addressId,
    this.deliveryQuote,
    this.isQuoting = false,
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

  /// Alamat pengiriman terpilih (delivery).
  final String? addressId;

  /// Hasil cek alamat + ongkir dari server (delivery).
  final DeliveryQuote? deliveryQuote;
  final bool isQuoting;

  /// Ongkir yang akan ditagih (0 bila bukan delivery).
  int get deliveryFee =>
      orderType == OrderType.delivery ? (deliveryQuote?.deliveryFee ?? 0) : 0;

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
    String? addressId,
    DeliveryQuote? deliveryQuote,
    bool clearQuote = false,
    bool? isQuoting,
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
      addressId: addressId ?? this.addressId,
      deliveryQuote: clearQuote ? null : (deliveryQuote ?? this.deliveryQuote),
      isQuoting: isQuoting ?? this.isQuoting,
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

  /// Pilih Delivery: pakai alamat terpilih, atau alamat default/pertama.
  Future<void> useDelivery() async {
    setOrderType(OrderType.delivery);
    if (state.addressId != null) return refreshQuote();
    try {
      final list = await ref.read(deliveryRepositoryProvider).fetchAddresses();
      if (list.isEmpty) return;
      final def = list.firstWhere((a) => a.isDefault, orElse: () => list.first);
      await selectAddress(def.id);
    } on ApiException catch (e) {
      state = state.copyWith(errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(errorMessage: 'Gagal memuat alamat.');
    }
  }

  /// Pilih alamat pengiriman lalu minta ongkir ke server.
  Future<void> selectAddress(String addressId) async {
    state = state.copyWith(addressId: addressId, isQuoting: true, clearQuote: true, clearError: true);
    final itemsNet = ref.read(cartTotalProvider) - state.discountAmount;
    try {
      final q = await ref
          .read(deliveryRepositoryProvider)
          .quote(addressId: addressId, itemsNet: itemsNet);
      if (state.addressId != addressId) return; // pilihan sudah berganti
      state = state.copyWith(deliveryQuote: q, isQuoting: false);
    } on ApiException catch (e) {
      state = state.copyWith(isQuoting: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(isQuoting: false, errorMessage: 'Gagal menghitung ongkir.');
    }
  }

  /// Ongkir bergantung pada total menu setelah diskon → hitung ulang bila berubah.
  Future<void> refreshQuote() async {
    final id = state.addressId;
    if (state.orderType == OrderType.delivery && id != null) await selectAddress(id);
  }

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
        await refreshQuote();
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

  void clearVoucher() {
    state = state.copyWith(voucherCode: '', clearVoucher: true);
    refreshQuote();
  }

  /// Sidik jari isi keranjang + pilihan yang MEMPENGARUHI isi pesanan.
  /// Catatan dikecualikan: mengubahnya tidak mengubah apa yang dibayar.
  String _signatureOf(List<CartItemModel> items) {
    final lines = [for (final e in items) '${e.lineId}x${e.quantity}']..sort();
    return '${lines.join('|')}'
        '#${state.paymentMethod.name}'
        '#${state.orderType.name}'
        '#${state.addressId ?? ''}'
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

    final table = ref.read(tableNumberProvider);
    final effectiveType = table != null ? OrderType.dineIn : state.orderType;
    if (effectiveType == OrderType.delivery) {
      if (isGuest) {
        state = state.copyWith(errorMessage: 'Masuk dulu untuk memesan delivery.');
        return null;
      }
      if (state.addressId == null) {
        state = state.copyWith(errorMessage: 'Pilih alamat pengiriman.');
        return null;
      }
      if (state.deliveryQuote?.available != true) {
        state = state.copyWith(
            errorMessage: state.deliveryQuote?.message ?? 'Alamat ini belum bisa dikirimi.');
        return null;
      }
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
      // QR meja: bila pelanggan datang lewat scan QR (?table=N), pesanan
      // otomatis dine-in & nomor meja ikut terkirim.
      final result = reusable ??
          (isGuest
              ? await repo.createGuestOrder(
                  items: items,
                  paymentMethod: state.paymentMethod,
                  orderType: effectiveType,
                  notes: state.notes.isEmpty ? null : state.notes,
                  guestName: guestName!,
                  guestPhone: guestPhone,
                  tableNumber: table,
                )
              : await repo.createOrder(
                  items: items,
                  paymentMethod: state.paymentMethod,
                  orderType: effectiveType,
                  voucherCode:
                      state.voucherCode.isEmpty ? null : state.voucherCode,
                  notes: state.notes.isEmpty ? null : state.notes,
                  tableNumber: table,
                  addressId: effectiveType == OrderType.delivery ? state.addressId : null,
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
      Analytics.orderCreated(
          value: result.total,
          paymentMethod: state.paymentMethod.name,
          source: 'app');
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
