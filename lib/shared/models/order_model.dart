import 'package:flutter/material.dart';

import '../../core/utils/customization_labels.dart';

/// Status pesanan beserta label & warna tampilannya.
enum OrderStatus {
  pending('Menunggu pembayaran', Color(0xFFC9831F)),
  paid('Dibayar', Color(0xFF3E7C5A)),
  preparing('Diproses', Color(0xFFB47832)),
  ready('Siap diambil', Color(0xFF3E7C5A)),
  completed('Selesai', Color(0xFF6E5F54)),
  cancelled('Dibatalkan', Color(0xFFB3261E));

  const OrderStatus(this.label, this.color);

  final String label;
  final Color color;

  /// Nilai yang dikirim ke backend (backend memakai 'processing', bukan 'preparing').
  String get apiValue => this == OrderStatus.preparing ? 'processing' : name;

  /// Urutan lifecycle pesanan.
  static const List<OrderStatus> flow = [
    OrderStatus.pending,
    OrderStatus.paid,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.completed,
  ];

  /// Status berikutnya dalam alur, atau null bila sudah terakhir / di luar alur.
  OrderStatus? get next {
    final i = flow.indexOf(this);
    if (i < 0 || i >= flow.length - 1) return null;
    return flow[i + 1];
  }

  static OrderStatus fromString(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'pending':
      case 'pending_payment':
        return OrderStatus.pending;
      case 'paid':
      case 'payment_success':
        return OrderStatus.paid;
      case 'preparing':
      case 'processing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'completed':
      case 'done':
        return OrderStatus.completed;
      case 'cancelled':
      case 'canceled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }
}

/// Tipe pesanan: makan di tempat atau bawa pulang.
enum OrderType {
  dineIn('dine_in', 'Dine-in', 'Makan di tempat', Icons.storefront_rounded),
  takeaway('takeaway', 'Bawa Pulang', 'Dibungkus', Icons.shopping_bag_rounded);

  const OrderType(this.apiValue, this.label, this.description, this.icon);

  /// Nilai yang dikirim ke / diterima dari backend.
  final String apiValue;
  final String label;
  final String description;
  final IconData icon;

  static OrderType fromString(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'takeaway':
      case 'take_away':
        return OrderType.takeaway;
      case 'dine_in':
      case 'dinein':
      default:
        return OrderType.dineIn;
    }
  }
}

/// Metode pembayaran (sesuai enum backend).
enum PaymentMethod {
  qris('QRIS', Icons.qr_code_2_rounded),
  gopay('GoPay', Icons.account_balance_wallet_outlined),
  ovo('OVO', Icons.account_balance_wallet_outlined),
  dana('DANA', Icons.account_balance_wallet_outlined),
  bca('BCA', Icons.account_balance_outlined),
  bni('BNI', Icons.account_balance_outlined),
  mandiri('Mandiri', Icons.account_balance_outlined),
  cash('Tunai', Icons.payments_outlined),
  balance('Saldo Rehat', Icons.account_balance_wallet_rounded);

  const PaymentMethod(this.label, this.icon);

  final String label;
  final IconData icon;

  /// Nilai yang dikirim ke backend.
  String get apiValue => name;
}

/// Satu baris item dalam pesanan.
class OrderItemModel {
  const OrderItemModel({
    required this.name,
    required this.quantity,
    required this.price,
    this.menuItemId = '',
    this.imageUrl,
    this.size,
    this.sugarLevel,
    this.temperature,
  });

  /// Id menu (untuk menulis ulasan). Backend: `menu_item_id`.
  final String menuItemId;
  final String name;
  final int quantity;

  /// Harga satuan (Rupiah) — backend: `unit_price`.
  final int price;
  final String? imageUrl;
  final String? size;
  final int? sugarLevel;
  final String? temperature;

  int get subtotal => price * quantity;

  String get customizationSummary => CustomizationLabels.summary(
        size: size,
        sugarLevel: sugarLevel,
        temperature: temperature,
      );

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    final cust = json['customization'];
    final c = cust is Map ? Map<String, dynamic>.from(cust) : const {};
    return OrderItemModel(
      menuItemId: (json['menu_item_id'] ?? json['menuItemId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      quantity: _asInt(json['quantity'] ?? json['qty']),
      price: _asInt(json['unit_price'] ?? json['price']),
      imageUrl: (json['image_url'] ?? json['imageUrl']) as String?,
      size: c['size']?.toString(),
      sugarLevel: c['sugar_level'] is num ? (c['sugar_level'] as num).toInt() : null,
      temperature: c['temperature']?.toString(),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

/// Pesanan lengkap (riwayat & detail).
class OrderModel {
  const OrderModel({
    required this.id,
    required this.queueNumber,
    required this.total,
    required this.status,
    required this.createdAt,
    this.items = const [],
    this.itemCount = 0,
    this.itemsSummary = '',
    this.subtotal = 0,
    this.discountAmount = 0,
    this.pointsEarned = 0,
    this.paymentMethod,
    this.orderType = OrderType.dineIn,
    this.notes = '',
    this.customerName = '',
    this.customerPhone = '',
  });

  final String id;

  /// Nomor antrian, mis. "A-3" (backend: `queue_number`). Kosong bila pesanan
  /// belum dibayar — antrian baru diberikan setelah pembayaran dikonfirmasi.
  final String queueNumber;

  /// Sudah punya nomor antrian (yakni sudah dibayar/dikonfirmasi).
  bool get hasQueue => queueNumber.isNotEmpty;

  /// Label antrian untuk tampilan; kosong → "Menunggu bayar".
  String get queueLabel => queueNumber.isNotEmpty ? queueNumber : 'Menunggu bayar';
  final int total;
  final OrderStatus status;
  final DateTime createdAt;

  /// Item detail (terisi pada GET /orders/:id).
  final List<OrderItemModel> items;

  /// Ringkasan untuk daftar riwayat (GET /orders).
  final int itemCount;
  final String itemsSummary;

  final int subtotal;
  final int discountAmount;
  final int pointsEarned;
  final String? paymentMethod;
  final OrderType orderType;

  /// Catatan pelanggan untuk barista (kosong bila tidak ada).
  final String notes;

  /// Nama & nomor pelanggan (terisi pada endpoint admin).
  final String customerName;
  final String customerPhone;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return OrderModel(
      id: (json['id'] ?? '').toString(),
      queueNumber: (json['queue_number'] ?? json['queueNumber'] ?? '').toString(),
      total: _asInt(json['total'] ?? json['total_price']),
      status: OrderStatus.fromString(json['status']?.toString()),
      createdAt: DateTime.tryParse(
              (json['ordered_at'] ?? json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((e) => OrderItemModel.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      itemCount: _asInt(json['item_count']),
      itemsSummary: (json['items_summary'] ?? '').toString(),
      subtotal: _asInt(json['subtotal']),
      discountAmount: _asInt(json['discount_amount']),
      pointsEarned: _asInt(json['points_earned']),
      paymentMethod: json['payment_method']?.toString(),
      orderType: OrderType.fromString(json['order_type']?.toString()),
      notes: (json['notes'] ?? '').toString(),
      customerName: (json['customer_name'] ?? '').toString(),
      customerPhone: (json['customer_phone'] ?? '').toString(),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

/// Hasil pembuatan pesanan (respons POST /orders).
class CheckoutResult {
  const CheckoutResult({
    required this.orderId,
    required this.queueNumber,
    required this.subtotal,
    required this.discountAmount,
    required this.total,
    required this.paymentMethod,
    this.orderType = OrderType.dineIn,
    this.paymentStatus = 'pending',
    this.paymentToken,
    this.qrisUrl,
  });

  final String orderId;
  final String queueNumber;
  final int subtotal;
  final int discountAmount;
  final int total;
  final PaymentMethod paymentMethod;
  final OrderType orderType;
  final String paymentStatus;
  final String? paymentToken;
  final String? qrisUrl;

  factory CheckoutResult.fromJson(
      Map<String, dynamic> json, PaymentMethod method) {
    final payment = json['payment'] is Map
        ? Map<String, dynamic>.from(json['payment'])
        : const {};
    return CheckoutResult(
      orderId: (json['orderId'] ?? json['order_id'] ?? '').toString(),
      queueNumber: (json['queueNumber'] ?? json['queue_number'] ?? '').toString(),
      subtotal: OrderModel._asInt(json['subtotal']),
      discountAmount: OrderModel._asInt(json['discountAmount'] ?? json['discount_amount']),
      total: OrderModel._asInt(json['total']),
      paymentMethod: method,
      orderType: OrderType.fromString(
          (json['orderType'] ?? json['order_type'])?.toString()),
      paymentStatus: (payment['status'] ?? 'pending').toString(),
      paymentToken: payment['token']?.toString(),
      qrisUrl: payment['qrisUrl']?.toString(),
    );
  }
}
