import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/app_lifecycle.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/cart_item_model.dart';
import '../../../shared/models/order_model.dart';
import '../../auth/application/auth_controller.dart';

/// Hasil pembuatan sesi pembayaran (DOKU Checkout).
/// `configured=false` → app pakai QRIS statis + ACC admin manual.
class PaymentSession {
  const PaymentSession({required this.configured, this.paymentUrl});

  final bool configured;
  final String? paymentUrl;

  bool get hasUrl => configured && paymentUrl != null && paymentUrl!.isNotEmpty;
}

/// Hasil pembayaran QRIS. Bisa berupa QR di dalam app (SNAP) ATAU URL DOKU
/// Checkout (redirect ke halaman QRIS DOKU).
class QrisResult {
  const QrisResult({
    required this.configured,
    this.qrisContent,
    this.paymentUrl,
    this.amount = 0,
  });

  /// `false` bila DOKU belum dikonfigurasi → app pakai QRIS statis.
  final bool configured;

  /// String QRIS untuk dirender jadi QR di app (jalur SNAP).
  final String? qrisContent;

  /// URL halaman DOKU Checkout (jalur redirect).
  final String? paymentUrl;
  final int amount;

  /// Ada QR untuk dirender di dalam app.
  bool get hasQr => configured && (qrisContent?.isNotEmpty ?? false);

  /// Ada URL Checkout untuk dibuka.
  bool get hasUrl => configured && (paymentUrl?.isNotEmpty ?? false);
}

/// Status ringkas pesanan (untuk polling pembayaran).
class OrderStatusLite {
  const OrderStatusLite({required this.status, required this.queueNumber});
  final String status;
  final String queueNumber;

  bool get hasQueue => queueNumber.isNotEmpty;
  bool get isPaid =>
      hasQueue ||
      const ['paid', 'processing', 'ready', 'completed'].contains(status);
}

/// Hasil validasi voucher di checkout.
class VoucherValidation {
  const VoucherValidation({
    required this.isValid,
    this.discountPct = 0,
    this.discountAmount = 0,
    this.totalAfter = 0,
  });

  final bool isValid;
  final int discountPct;
  final int discountAmount;
  final int totalAfter;
}

/// Akses data pemesanan.
class OrderRepository {
  OrderRepository({required DioClient client}) : _client = client;

  final DioClient _client;

  /// Membuat pesanan baru dari isi keranjang.
  Future<CheckoutResult> createOrder({
    required List<CartItemModel> items,
    required PaymentMethod paymentMethod,
    OrderType orderType = OrderType.dineIn,
    String? voucherCode,
    String? notes,
    String? tableNumber,
  }) async {
    final payload = {
      'items': [
        for (final e in items)
          {
            'menu_item_id': e.item.id,
            'quantity': e.quantity,
            if (e.customizationJson.isNotEmpty)
              'customization': e.customizationJson,
          },
      ],
      'payment_method': paymentMethod.apiValue,
      'order_type': orderType.apiValue,
      if (voucherCode != null && voucherCode.isNotEmpty) 'voucher_code': voucherCode,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      if (tableNumber != null && tableNumber.trim().isNotEmpty)
        'table_number': tableNumber.trim(),
    };

    final res = await _client.post<dynamic>(ApiConstants.orders, data: payload);
    return CheckoutResult.fromJson(_unwrap(res.data), paymentMethod);
  }

  /// Membuat pesanan sebagai TAMU (tanpa login) — tanpa voucher/poin.
  Future<CheckoutResult> createGuestOrder({
    required List<CartItemModel> items,
    required PaymentMethod paymentMethod,
    OrderType orderType = OrderType.dineIn,
    String? notes,
    required String guestName,
    String? guestPhone,
    String? tableNumber,
  }) async {
    final payload = {
      'items': [
        for (final e in items)
          {
            'menu_item_id': e.item.id,
            'quantity': e.quantity,
            if (e.customizationJson.isNotEmpty)
              'customization': e.customizationJson,
          },
      ],
      'payment_method': paymentMethod.apiValue,
      'order_type': orderType.apiValue,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'guest_name': guestName.trim(),
      if (guestPhone != null && guestPhone.trim().isNotEmpty)
        'guest_phone': guestPhone.trim(),
      if (tableNumber != null && tableNumber.trim().isNotEmpty)
        'table_number': tableNumber.trim(),
    };
    final res =
        await _client.post<dynamic>(ApiConstants.ordersGuest, data: payload);
    return CheckoutResult.fromJson(_unwrap(res.data), paymentMethod);
  }

  /// Memvalidasi kode voucher terhadap subtotal.
  Future<VoucherValidation> validateVoucher({
    required String code,
    required int subtotal,
  }) async {
    final res = await _client.post<dynamic>(
      ApiConstants.voucherValidate,
      data: {'code': code, 'subtotal': subtotal},
    );
    final data = _unwrap(res.data);
    return VoucherValidation(
      isValid: (data['is_valid'] ?? false) == true,
      discountPct: _asInt(data['discount_pct']),
      discountAmount: _asInt(data['discount_amount']),
      totalAfter: _asInt(data['total_after']),
    );
  }

  /// Mengambil riwayat pesanan (paginated) — terbaru lebih dulu.
  Future<List<OrderModel>> fetchHistory({int page = 1, int limit = 20}) async {
    final res = await _client.get<dynamic>(
      ApiConstants.orders,
      query: {'page': page, 'limit': limit},
    );
    final data = res.data;
    final list = data is Map ? (data['data'] ?? data['orders']) : data;
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => OrderModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  Future<OrderModel> fetchDetail(String id) async {
    final res = await _client.get<dynamic>(ApiConstants.orderDetail(id));
    return OrderModel.fromJson(_unwrap(res.data));
  }

  /// (Admin) Semua pesanan, opsional difilter status/tanggal (`GET /admin/orders`).
  /// [date] format YYYY-MM-DD → hanya pesanan pada hari itu.
  Future<List<OrderModel>> fetchAllOrders(
      {String? status, String? date, int page = 1, int limit = 30}) async {
    final res = await _client.get<dynamic>(
      ApiConstants.adminOrders,
      query: {
        'page': page,
        'limit': limit,
        if (status != null && status.isNotEmpty) 'status': status,
        if (date != null && date.isNotEmpty) 'date': date,
      },
    );
    final data = res.data;
    final list = data is Map ? (data['data'] ?? data['orders']) : data;
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => OrderModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  /// (Admin) Detail pesanan mana pun (`GET /admin/orders/:id`).
  Future<OrderModel> fetchDetailAdmin(String id) async {
    final res = await _client.get<dynamic>(ApiConstants.adminOrderDetail(id));
    return OrderModel.fromJson(_unwrap(res.data));
  }

  /// Membuat sesi pembayaran DOKU untuk pesanan (`POST /orders/:id/pay`).
  /// Bila DOKU belum dikonfigurasi, backend balas `configured:false`.
  Future<PaymentSession> createPayment(String id) async {
    final res = await _client.post<dynamic>(ApiConstants.orderPay(id));
    final data = _unwrap(res.data);
    return PaymentSession(
      configured: (data['configured'] ?? false) == true,
      paymentUrl: (data['payment_url'] ?? data['paymentUrl'])?.toString(),
    );
  }

  /// Generate QRIS dinamis via DOKU Direct API (`POST /orders/:id/qris`).
  /// Bila DOKU SNAP belum aktif, `configured=false` → app pakai QRIS statis.
  Future<QrisResult> fetchQris(String id) async {
    final res = await _client.post<dynamic>(ApiConstants.orderQris(id));
    final data = _unwrap(res.data);
    return QrisResult(
      configured: (data['configured'] ?? false) == true,
      qrisContent: (data['qris_content'] ?? data['qrisContent'])?.toString(),
      paymentUrl: (data['payment_url'] ?? data['paymentUrl'])?.toString(),
      amount: _asInt(data['amount']),
    );
  }

  /// Status ringkas pesanan (`GET /orders/:id/status`, publik) — untuk polling.
  Future<OrderStatusLite> fetchOrderStatus(String id) async {
    final res = await _client.get<dynamic>(ApiConstants.orderStatus(id));
    final data = _unwrap(res.data);
    return OrderStatusLite(
      status: (data['status'] ?? '').toString(),
      queueNumber:
          (data['queue_number'] ?? data['queueNumber'] ?? '').toString(),
    );
  }

  /// (Admin) Memperbarui status pesanan (`PATCH /orders/:id/status`).
  /// [paymentMethod] opsional — mis. kasir menandai lunas tunai (`cash`).
  Future<void> updateStatus(String id, OrderStatus status,
      {PaymentMethod? paymentMethod}) async {
    await _client.patch<dynamic>(
      ApiConstants.orderStatus(id),
      data: {
        'status': status.apiValue,
        if (paymentMethod != null) 'payment_method': paymentMethod.apiValue,
      },
    );
  }

  /// (Admin) Refund TUNAI penuh sebuah pesanan (`POST /admin/orders/:id/refund`).
  /// [reason] wajib (min 3 karakter). Hanya untuk order berpembayaran tunai yang
  /// sudah dibayar & belum di-refund.
  Future<void> refundOrder(String id, String reason) async {
    await _client.post<dynamic>(
      ApiConstants.adminOrderRefund(id),
      data: {'reason': reason},
    );
  }

  /// (Admin/Kasir) Membuat pesanan TUNAI untuk pelanggan walk-in — langsung
  /// lunas & dapat nomor antrian (`POST /admin/orders`).
  Future<CheckoutResult> createCashierOrder({
    required List<CartItemModel> items,
    OrderType orderType = OrderType.dineIn,
    String? notes,
    String? customerName,
    bool payNow = true,
    PaymentMethod paymentMethod = PaymentMethod.cash,
  }) async {
    final payload = {
      'items': [
        for (final e in items)
          {
            'menu_item_id': e.item.id,
            'quantity': e.quantity,
            if (e.customizationJson.isNotEmpty)
              'customization': e.customizationJson,
          },
      ],
      'order_type': orderType.apiValue,
      'pay_now': payNow,
      'payment_method': paymentMethod == PaymentMethod.qris ? 'qris' : 'cash',
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      if (customerName != null && customerName.trim().isNotEmpty)
        'customer_name': customerName.trim(),
    };
    final res =
        await _client.post<dynamic>(ApiConstants.adminOrders, data: payload);
    return CheckoutResult.fromJson(_unwrap(res.data), paymentMethod);
  }

  /// Memesan ulang pesanan lama (`POST /orders/:id/reorder`).
  Future<CheckoutResult> reorder(String id) async {
    final res = await _client.post<dynamic>(ApiConstants.reorder(id));
    // Backend reorder memakai pembayaran qris secara default.
    return CheckoutResult.fromJson(_unwrap(res.data), PaymentMethod.qris);
  }

  Map<String, dynamic> _unwrap(dynamic body) {
    if (body is Map) {
      final inner = body['data'];
      if (inner is Map) return Map<String, dynamic>.from(inner);
      return Map<String, dynamic>.from(body);
    }
    return const {};
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(client: ref.watch(dioClientProvider));
});

/// Riwayat pesanan (auto-refresh saat di-invalidate).
final orderHistoryProvider = FutureProvider<List<OrderModel>>((ref) {
  return ref.watch(orderRepositoryProvider).fetchHistory();
});

/// Detail satu pesanan.
final orderDetailProvider =
    FutureProvider.family<OrderModel, String>((ref, id) {
  return ref.watch(orderRepositoryProvider).fetchDetail(id);
});

/// Polling status pembayaran tiap 5 dtk sampai nomor antrian keluar (lunas).
/// Publik → jalan untuk user & tamu.
final orderStatusPollProvider =
    StreamProvider.autoDispose.family<OrderStatusLite, String>((ref, id) async* {
  final repo = ref.watch(orderRepositoryProvider);
  while (true) {
    OrderStatusLite? s;
    try {
      s = await repo.fetchOrderStatus(id);
    } catch (_) {}
    if (s != null) {
      yield s;
      if (s.hasQueue) break; // nomor antrian sudah keluar → hentikan polling
    }
    await Future.delayed(const Duration(seconds: 5));
  }
});

/// Status yang dianggap "pesanan masih berjalan".
const kActiveOrderStatuses = {
  OrderStatus.pending,
  OrderStatus.paid,
  OrderStatus.preparing,
  OrderStatus.ready,
};

/// Seluruh pesanan pengguna dengan polling CEPAT — sumber data untuk banner
/// pelacakan di Menu & layar "Lacak Pesanan".
///
/// Responsif: 3 dtk saat ada pesanan berjalan (status berubah nyaris seketika
/// setelah pembayaran), melambat jadi 20 dtk saat tak ada pesanan aktif agar
/// hemat baterai & kuota. Panggil `ref.invalidate(ordersTrackingProvider)`
/// untuk refresh SEKETIKA (mis. sesudah bayar / app kembali ke depan).
final ordersTrackingProvider =
    StreamProvider.autoDispose<List<OrderModel>>((ref) async* {
  final repo = ref.watch(orderRepositoryProvider);
  // ADMIN melacak SEMUA pesanan (selaras dengan layar "Pesanan Masuk"), karena
  // pesanan kasir adalah pesanan tamu (user_id null) sehingga tak muncul di
  // `GET /orders` yang hanya mengembalikan pesanan milik akun sendiri.
  //
  // `select` WAJIB: tanpa itu perubahan APA PUN pada AuthState (mis. pesan
  // error login, token di-refresh, avatar diganti) membangun ulang provider ini
  // → loop polling restart & langsung menembak backend lagi.
  final isAdmin = ref.watch(
    authControllerProvider.select((s) => s.user?.isAdmin ?? false),
  );
  // Hanya sesi TERAUTENTIKASI yang punya pesanan di GET /orders. TAMU / belum
  // login TAK BOLEH menembak endpoint auth: 401-nya memicu interceptor
  // menghapus sesi & menendang ke login (bug: pelacak di Menu men-trigger ini
  // untuk tamu). `.select` agar polling tak restart pada perubahan state lain.
  final isAuthed = ref.watch(
    authControllerProvider
        .select((s) => s.status == AuthStatus.authenticated),
  );
  while (true) {
    List<OrderModel> list = const [];
    // Saat aplikasi di background JANGAN menembak backend — hemat kuota &
    // baterai. Kasir bisa membiarkan app terbuka berjam-jam; tanpa jeda ini
    // `fetchAllOrders` jalan tiap 3 dtk selamanya.
    if (isAuthed && ref.read(appForegroundProvider)) {
      try {
        list = isAdmin
            ? await repo.fetchAllOrders(limit: 50)
            : await repo.fetchHistory(limit: 20);
      } catch (_) {
        // Jaringan gagal → daftar kosong.
      }
      yield list;
    }
    final hasActive = list.any((o) => kActiveOrderStatuses.contains(o.status));
    await Future.delayed(Duration(seconds: hasActive ? 3 : 20));
  }
});

/// Pesanan AKTIF yang paling DULU dibuat (FIFO) — untuk banner di Menu.
///
/// Sengaja bukan yang terbaru: antrean dikerjakan urut masuk, jadi yang tampil
/// adalah pesanan terdepan yang harus diselesaikan lebih dulu.
/// Null bila tak ada pesanan berjalan.
final activeOrderProvider = Provider.autoDispose<OrderModel?>((ref) {
  final list = ref.watch(ordersTrackingProvider).valueOrNull ?? const [];
  OrderModel? oldest;
  for (final o in list) {
    if (!kActiveOrderStatuses.contains(o.status)) continue;
    if (oldest == null || o.createdAt.isBefore(oldest.createdAt)) oldest = o;
  }
  return oldest;
});

/// (Admin) Pesanan Masuk = pesanan yang SUDAH DIBAYAR (paid → selesai),
/// terbaru dulu. Pesanan belum bayar ada di [pendingOrdersProvider].
final adminOrdersProvider = FutureProvider<List<OrderModel>>((ref) async {
  final all =
      await ref.watch(orderRepositoryProvider).fetchAllOrders(limit: 100);
  const shown = {
    OrderStatus.paid,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.completed,
  };
  return all.where((o) => shown.contains(o.status)).toList();
});

/// (Admin) Detail pesanan mana pun.
final adminOrderDetailProvider =
    FutureProvider.family<OrderModel, String>((ref, id) {
  return ref.watch(orderRepositoryProvider).fetchDetailAdmin(id);
});

/// (Admin) Pesanan BELUM BAYAR **hari ini** — disimpan/bayar-nanti (tunai) &
/// QRIS menunggu. Sumber untuk pintasan "Pesanan Belum Bayar" di beranda.
final pendingOrdersProvider = FutureProvider<List<OrderModel>>((ref) {
  // "Hari ini" harus WIB (bukan jam perangkat) — konsisten dgn CLAUDE.md §5d.
  final now = Formatters.toWib(DateTime.now());
  final today = '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
  return ref
      .watch(orderRepositoryProvider)
      .fetchAllOrders(status: 'pending_payment', date: today, limit: 100);
});

/// (Admin) Riwayat transaksi = pesanan yang sudah SELESAI atau DIBATALKAN
/// (log lampau, read-only). Berbeda dari "Pesanan Masuk" (pesanan aktif).
final adminOrderHistoryProvider = FutureProvider<List<OrderModel>>((ref) async {
  final all = await ref.watch(orderRepositoryProvider).fetchAllOrders(limit: 100);
  return all
      .where((o) =>
          o.status == OrderStatus.completed ||
          o.status == OrderStatus.cancelled ||
          o.status == OrderStatus.refunded)
      .toList();
});
