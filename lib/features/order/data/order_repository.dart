import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/cart_item_model.dart';
import '../../../shared/models/order_model.dart';

/// Hasil pembuatan sesi pembayaran (DOKU Checkout).
/// `configured=false` → app pakai QRIS statis + ACC admin manual.
class PaymentSession {
  const PaymentSession({required this.configured, this.paymentUrl});

  final bool configured;
  final String? paymentUrl;

  bool get hasUrl => configured && paymentUrl != null && paymentUrl!.isNotEmpty;
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
    };

    final res = await _client.post<dynamic>(ApiConstants.orders, data: payload);
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

  /// (Admin) Semua pesanan, opsional difilter status (`GET /admin/orders`).
  Future<List<OrderModel>> fetchAllOrders({String? status, int page = 1, int limit = 30}) async {
    final res = await _client.get<dynamic>(
      ApiConstants.adminOrders,
      query: {
        'page': page,
        'limit': limit,
        if (status != null && status.isNotEmpty) 'status': status,
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

  /// (Admin) Memperbarui status pesanan (`PATCH /orders/:id/status`).
  Future<void> updateStatus(String id, OrderStatus status) async {
    await _client.patch<dynamic>(
      ApiConstants.orderStatus(id),
      data: {'status': status.apiValue},
    );
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

/// (Admin) Filter status aktif di panel pesanan masuk ('' = semua).
final adminOrdersFilterProvider = StateProvider<String>((ref) => '');

/// (Admin) Semua pesanan sesuai filter status.
final adminOrdersProvider = FutureProvider<List<OrderModel>>((ref) {
  final status = ref.watch(adminOrdersFilterProvider);
  return ref.watch(orderRepositoryProvider).fetchAllOrders(status: status);
});

/// (Admin) Detail pesanan mana pun.
final adminOrderDetailProvider =
    FutureProvider.family<OrderModel, String>((ref, id) {
  return ref.watch(orderRepositoryProvider).fetchDetailAdmin(id);
});
