# Delivery Fase 1 — App Flutter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. It will decide whether each batch should run in parallel or serial subagent mode and will pass only task-local context to each subagent. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** App `rehatflutter` mendukung delivery dengan kurir Rehat sendiri: alamat + pin peta, pilihan Delivery di checkout (ongkir dari server), info antaran di detail pesanan, layar **Antaran** untuk kurir, serta layar admin **Delivery & Kurir** dan aksi pilihkan kurir / refund.

**Architecture:** Model baru di `lib/shared/models/delivery_models.dart`; semua panggilan API delivery di `lib/features/delivery/data/delivery_repository.dart` (+ provider). Checkout memakai state yang ada (`CheckoutState`) ditambah alamat & quote. Layar baru di `lib/features/delivery/presentation/`. Peta memakai `flutter_map` (OpenStreetMap, tanpa API key) + `geolocator`.

**Tech Stack:** Flutter 3.44.4 (sama dengan CI), Riverpod 2, go_router 14, Dio, flutter_map, latlong2, geolocator, url_launcher.

**Spec:** `docs/superpowers/specs/2026-11-27-delivery-fase-1-design.md`. **Backend sudah live** (lihat `docs/superpowers/plans/2026-11-27-delivery-fase-1-backend.md`); kontrak API yang dipakai:

| Endpoint | Respons `data` |
|---|---|
| `GET /delivery/config` | `{enabled, available, reason, message, last_order_at, radius_m, delivery_fee, free_delivery_min}` |
| `POST /delivery/quote` `{address_id, items_net}` | `{available, reason, message, distance_m, delivery_fee, free_delivery_min, remaining_for_free}` |
| `GET/POST /me/addresses`, `PATCH/DELETE /me/addresses/:id` | alamat `{id, label, address_text, notes, recipient_name, recipient_phone, lat, lng, is_default}` |
| `POST /orders` + `order_type:'delivery'`, `address_id` | `{orderId, queueNumber, subtotal, discountAmount, deliveryFee, total, orderType, payment}` |
| `GET /orders/:id`, `GET /admin/orders/:id` | + `delivery_fee, delivery_status, delivery_address, delivery_distance_m, picked_up_at, delivered_at, courier_name, courier_phone` |
| `GET /admin/orders` | baris + `delivery_status, delivery_distance_m, delivery_fee, courier_name` |
| `GET /courier/deliveries` | `{on_duty, waiting:[order], mine:[order], delivered_today}`; order = `{id, queue_number, delivery_status, delivery_address, delivery_distance_m, total, order_items:[{quantity, customization, menu_items:{name}}]}` |
| `PATCH /courier/duty` `{on_duty}`; `POST /courier/deliveries/:id/{claim,on-the-way,delivered,failed}` (`failed` butuh `{reason}`) | — |
| `GET /admin/store-settings` → `{settings, hours}`; `PATCH /admin/store-settings`; `PUT /admin/store-hours` (7 baris `{day_of_week, open_time 'HH:MM'|null, close_time, is_closed}`) | — |
| `GET/POST /admin/couriers` `{phone}`; `DELETE /admin/couriers/:id`; `POST /admin/orders/:id/assign-courier` `{courier_id}`; `POST /admin/orders/:id/delivery-refund` `{reason, mode:'wallet'}` | — |

Error backend: `{success:false, error:{code, message}}` → sudah dipetakan ke `ApiException.message` oleh `DioClient`.

**Repo & perintah:**
- Repo: `C:\Users\USER\projects\rehatflutter`, branch kerja `feat/delivery-app` (dibuat di Task 0). **Jangan push ke `main`** sampai Task 13 (push `main` = deploy web produksi lewat CI).
- Flutter lokal bawaan (3.32.1) **terlalu lama** untuk kode ini. Task 0 memasang Flutter 3.44.4 di `C:\src\flutter-3.44.4`; semua perintah memakai `C:\src\flutter-3.44.4\bin\flutter` (disingkat `FLUTTER` di plan).
- Test satu file: `FLUTTER test test/<file>.dart`; semua: `FLUTTER test`; analisis: `FLUTTER analyze`.

---

## File Structure

| File | Status | Tanggung jawab |
|---|---|---|
| `lib/shared/models/delivery_models.dart` | baru | `DeliveryStatus`, `AddressModel`, `DeliveryConfig`, `DeliveryQuote`, `CourierDeliveries`, `CourierInfo`, `StoreSettings`, `StoreHour` |
| `lib/shared/models/order_model.dart` | ubah | `OrderType.delivery`, field delivery di `OrderModel`, `deliveryFee` di `CheckoutResult`, item dari `order_items` |
| `lib/shared/models/user_model.dart` | ubah | `isCourier` |
| `lib/core/constants/api_constants.dart` | ubah | Path endpoint delivery |
| `lib/features/delivery/data/delivery_repository.dart` | baru | Semua panggilan API delivery + provider |
| `lib/features/order/data/order_repository.dart` | ubah | `createOrder(addressId:)` |
| `lib/features/order/application/checkout_controller.dart` | ubah | Alamat, quote, ongkir, validasi delivery |
| `lib/features/delivery/presentation/widgets/location_picker.dart` | baru | Peta + pin tengah + "Lokasi saya" |
| `lib/features/delivery/presentation/address_list_screen.dart` | baru | Daftar alamat |
| `lib/features/delivery/presentation/address_form_screen.dart` | baru | Tambah/ubah alamat |
| `lib/features/delivery/presentation/widgets/delivery_address_section.dart` | baru | Bagian alamat + status ongkir di checkout |
| `lib/features/order/presentation/checkout_screen.dart` | ubah | Kartu Delivery, bagian alamat, baris ongkir |
| `lib/features/menu/presentation/widgets/cashier_actions.dart` | ubah | Kasir hanya dine-in/bawa pulang |
| `lib/features/delivery/presentation/widgets/delivery_info_card.dart` | baru | Status antaran + kurir di detail pesanan |
| `lib/features/delivery/presentation/widgets/admin_delivery_actions.dart` | baru | Admin: pilihkan kurir, refund |
| `lib/features/order/presentation/order_detail_screen.dart` | ubah | Baris ongkir, kartu antaran, aksi admin |
| `lib/features/admin/presentation/admin_orders_screen.dart` | ubah | Chip delivery + status antaran + kurir |
| `lib/features/delivery/presentation/courier_screen.dart` | baru | Layar Antaran kurir |
| `lib/features/delivery/presentation/store_settings_screen.dart` | baru | Admin: pengaturan delivery, jam, kurir |
| `lib/core/router/route_names.dart`, `app_router.dart` | ubah | Rute baru |
| `lib/features/profile/presentation/profile_screen.dart` | ubah | Menu Alamat, Antaran, Delivery & Kurir |
| `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist` | ubah | Izin lokasi |
| `test/delivery_models_test.dart`, `test/checkout_delivery_test.dart` | baru | Test model & checkout delivery |
| `test/checkout_controller_test.dart` | ubah | Fake `createOrder` mengikuti parameter baru |

---

### Task 0: Flutter 3.44.4 lokal + branch kerja

- [ ] **Step 1: Pasang SDK** (sekali; ±1–2 GB)

```bash
git clone --depth 1 --branch 3.44.4 https://github.com/flutter/flutter.git C:/src/flutter-3.44.4
C:/src/flutter-3.44.4/bin/flutter --version
```
Expected: `Flutter 3.44.4 • channel stable` (atau `[user-branch]`), Dart 3.x.

- [ ] **Step 2: Baseline**

```bash
cd C:/Users/USER/projects/rehatflutter
git checkout -b feat/delivery-app
C:/src/flutter-3.44.4/bin/flutter pub get
C:/src/flutter-3.44.4/bin/flutter test
```
Expected: semua test lama PASS. Bila ada yang gagal **sebelum** perubahan apa pun, catat dan laporkan — jangan perbaiki di plan ini.

---

### Task 1: Model delivery + perluasan model pesanan

**Files:**
- Create: `lib/shared/models/delivery_models.dart`
- Modify: `lib/shared/models/order_model.dart`, `lib/shared/models/user_model.dart`
- Test: `test/delivery_models_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/delivery_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/shared/models/delivery_models.dart';
import 'package:rehat_app/shared/models/order_model.dart';
import 'package:rehat_app/shared/models/user_model.dart';

void main() {
  test('DeliveryStatus.fromString', () {
    expect(DeliveryStatus.fromString('on_the_way'), DeliveryStatus.onTheWay);
    expect(DeliveryStatus.fromString(null), isNull);
    expect(DeliveryStatus.fromString('xyz'), isNull);
  });

  test('AddressModel json', () {
    final a = AddressModel.fromJson({
      'id': 'a1', 'label': 'Rumah', 'address_text': 'Jl. Melati 5', 'notes': null,
      'recipient_name': 'Nadia', 'recipient_phone': '0812', 'lat': -7.18, 'lng': 113.25, 'is_default': true,
    });
    expect(a.isDefault, isTrue);
    expect(a.lat, -7.18);
    expect(a.toJson(), {
      'label': 'Rumah', 'address_text': 'Jl. Melati 5', 'notes': null,
      'recipient_name': 'Nadia', 'recipient_phone': '0812', 'lat': -7.18, 'lng': 113.25, 'is_default': true,
    });
  });

  test('DeliveryQuote json', () {
    final q = DeliveryQuote.fromJson({
      'available': false, 'reason': 'OUT_OF_RADIUS', 'message': 'Di luar jangkauan',
      'distance_m': 5600, 'delivery_fee': 5000, 'free_delivery_min': 50000, 'remaining_for_free': 20000,
    });
    expect(q.available, isFalse);
    expect(q.distanceKmLabel, '5.6 km');
    expect(q.remainingForFree, 20000);
  });

  test('OrderType delivery', () {
    expect(OrderType.fromString('delivery'), OrderType.delivery);
    expect(OrderType.delivery.apiValue, 'delivery');
    expect(OrderType.counterTypes, [OrderType.dineIn, OrderType.takeaway]);
  });

  test('OrderModel membaca field delivery (detail & daftar kurir)', () {
    final o = OrderModel.fromJson({
      'id': 'o1', 'queue_number': 'A-7', 'total': 25000, 'status': 'processing',
      'order_type': 'delivery', 'delivery_fee': 5000, 'delivery_status': 'assigned',
      'delivery_distance_m': 1234,
      'delivery_address': {'label': 'Rumah', 'address_text': 'Jl. Melati 5', 'recipient_name': 'Nadia', 'recipient_phone': '0812', 'lat': -7.18, 'lng': 113.25},
      'courier_name': 'Budi', 'courier_phone': '0811',
      'order_items': [{'quantity': 2, 'menu_items': {'name': 'Kopi Susu'}}],
    });
    expect(o.orderType, OrderType.delivery);
    expect(o.deliveryFee, 5000);
    expect(o.deliveryStatus, DeliveryStatus.assigned);
    expect(o.deliveryAddress!.recipientName, 'Nadia');
    expect(o.courierName, 'Budi');
    expect(o.items.single.name, 'Kopi Susu');
    expect(o.items.single.quantity, 2);
  });

  test('OrderModel: courier dari embed {courier:{name}}', () {
    final o = OrderModel.fromJson({'id': 'o1', 'courier': {'name': 'Andi', 'phone': '0899'}});
    expect(o.courierName, 'Andi');
    expect(o.courierPhone, '0899');
  });

  test('CheckoutResult.deliveryFee', () {
    final r = CheckoutResult.fromJson({'orderId': 'o1', 'total': 25000, 'deliveryFee': 5000}, PaymentMethod.qris);
    expect(r.deliveryFee, 5000);
  });

  test('UserModel.isCourier', () {
    expect(UserModel.fromJson({'id': 'u', 'role': 'courier'}).isCourier, isTrue);
    expect(UserModel.fromJson({'id': 'u', 'role': 'customer'}).isCourier, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `FLUTTER test test/delivery_models_test.dart`
Expected: FAIL — compile error, `delivery_models.dart` tidak ada

- [ ] **Step 3: Write `delivery_models.dart`**

```dart
// lib/shared/models/delivery_models.dart
import 'package:flutter/material.dart';

import 'order_model.dart';

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double _double(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

String? _strOrNull(dynamic v) {
  final s = v?.toString();
  return (s == null || s.isEmpty) ? null : s;
}

/// Status antaran (kolom `orders.delivery_status`).
enum DeliveryStatus {
  waitingCourier('waiting_courier', 'Mencari kurir', Icons.hourglass_top_rounded),
  assigned('assigned', 'Kurir ditetapkan', Icons.person_pin_circle_rounded),
  onTheWay('on_the_way', 'Sedang diantar', Icons.delivery_dining_rounded),
  delivered('delivered', 'Terkirim', Icons.check_circle_rounded),
  failed('failed', 'Gagal diantar', Icons.error_outline_rounded),
  cancelled('cancelled', 'Dibatalkan', Icons.cancel_outlined);

  const DeliveryStatus(this.apiValue, this.label, this.icon);
  final String apiValue;
  final String label;
  final IconData icon;

  static DeliveryStatus? fromString(String? v) {
    for (final s in values) {
      if (s.apiValue == v) return s;
    }
    return null;
  }
}

/// Alamat tersimpan pelanggan (juga dipakai untuk snapshot alamat di pesanan).
class AddressModel {
  const AddressModel({
    this.id = '',
    required this.label,
    required this.addressText,
    this.notes,
    required this.recipientName,
    required this.recipientPhone,
    required this.lat,
    required this.lng,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String addressText;
  final String? notes;
  final String recipientName;
  final String recipientPhone;
  final double lat;
  final double lng;
  final bool isDefault;

  factory AddressModel.fromJson(Map<String, dynamic> j) => AddressModel(
        id: (j['id'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        addressText: (j['address_text'] ?? '').toString(),
        notes: _strOrNull(j['notes']),
        recipientName: (j['recipient_name'] ?? '').toString(),
        recipientPhone: (j['recipient_phone'] ?? '').toString(),
        lat: _double(j['lat']),
        lng: _double(j['lng']),
        isDefault: j['is_default'] == true,
      );

  /// Payload POST/PATCH (tanpa id).
  Map<String, dynamic> toJson() => {
        'label': label,
        'address_text': addressText,
        'notes': notes,
        'recipient_name': recipientName,
        'recipient_phone': recipientPhone,
        'lat': lat,
        'lng': lng,
        'is_default': isDefault,
      };

  String get mapsUrl => 'https://maps.google.com/?q=$lat,$lng';
}

class DeliveryConfig {
  const DeliveryConfig({
    required this.enabled,
    required this.available,
    this.reason,
    this.message,
    this.lastOrderAt,
    this.radiusM = 0,
    this.deliveryFee = 0,
    this.freeDeliveryMin = 0,
  });

  final bool enabled;
  final bool available;
  final String? reason;
  final String? message;
  final String? lastOrderAt;
  final int radiusM;
  final int deliveryFee;
  final int freeDeliveryMin;

  factory DeliveryConfig.fromJson(Map<String, dynamic> j) => DeliveryConfig(
        enabled: j['enabled'] == true,
        available: j['available'] == true,
        reason: _strOrNull(j['reason']),
        message: _strOrNull(j['message']),
        lastOrderAt: _strOrNull(j['last_order_at']),
        radiusM: _int(j['radius_m']),
        deliveryFee: _int(j['delivery_fee']),
        freeDeliveryMin: _int(j['free_delivery_min']),
      );
}

class DeliveryQuote {
  const DeliveryQuote({
    required this.available,
    this.reason,
    this.message,
    this.distanceM,
    this.deliveryFee = 0,
    this.freeDeliveryMin = 0,
    this.remainingForFree = 0,
  });

  final bool available;
  final String? reason;
  final String? message;
  final int? distanceM;
  final int deliveryFee;
  final int freeDeliveryMin;
  final int remainingForFree;

  String get distanceKmLabel =>
      distanceM == null ? '-' : '${(distanceM! / 1000).toStringAsFixed(1)} km';

  factory DeliveryQuote.fromJson(Map<String, dynamic> j) => DeliveryQuote(
        available: j['available'] == true,
        reason: _strOrNull(j['reason']),
        message: _strOrNull(j['message']),
        distanceM: j['distance_m'] == null ? null : _int(j['distance_m']),
        deliveryFee: _int(j['delivery_fee']),
        freeDeliveryMin: _int(j['free_delivery_min']),
        remainingForFree: _int(j['remaining_for_free']),
      );
}

class CourierDeliveries {
  const CourierDeliveries({
    required this.onDuty,
    this.waiting = const [],
    this.mine = const [],
    this.deliveredToday = 0,
  });

  final bool onDuty;
  final List<OrderModel> waiting;
  final List<OrderModel> mine;
  final int deliveredToday;

  static List<OrderModel> _orders(dynamic v) => v is List
      ? v.whereType<Map>().map((e) => OrderModel.fromJson(Map<String, dynamic>.from(e))).toList()
      : const [];

  factory CourierDeliveries.fromJson(Map<String, dynamic> j) => CourierDeliveries(
        onDuty: j['on_duty'] == true,
        waiting: _orders(j['waiting']),
        mine: _orders(j['mine']),
        deliveredToday: _int(j['delivered_today']),
      );
}

class CourierInfo {
  const CourierInfo({required this.id, required this.name, required this.phone, this.onDuty = false});
  final String id;
  final String name;
  final String phone;
  final bool onDuty;

  factory CourierInfo.fromJson(Map<String, dynamic> j) => CourierInfo(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        phone: (j['phone'] ?? '').toString(),
        onDuty: j['courier_on_duty'] == true,
      );
}

class StoreSettings {
  const StoreSettings({
    this.storeLat,
    this.storeLng,
    this.storeAddress = '',
    this.deliveryEnabled = false,
    this.radiusM = 3000,
    this.deliveryFee = 5000,
    this.freeDeliveryMin = 50000,
    this.cutoffMinutes = 60,
  });

  final double? storeLat;
  final double? storeLng;
  final String storeAddress;
  final bool deliveryEnabled;
  final int radiusM;
  final int deliveryFee;
  final int freeDeliveryMin;
  final int cutoffMinutes;

  factory StoreSettings.fromJson(Map<String, dynamic> j) => StoreSettings(
        storeLat: j['store_lat'] == null ? null : _double(j['store_lat']),
        storeLng: j['store_lng'] == null ? null : _double(j['store_lng']),
        storeAddress: (j['store_address'] ?? '').toString(),
        deliveryEnabled: j['delivery_enabled'] == true,
        radiusM: _int(j['delivery_radius_m']),
        deliveryFee: _int(j['delivery_fee']),
        freeDeliveryMin: _int(j['free_delivery_min']),
        cutoffMinutes: _int(j['delivery_cutoff_minutes']),
      );

  Map<String, dynamic> toJson() => {
        if (storeLat != null) 'store_lat': storeLat,
        if (storeLng != null) 'store_lng': storeLng,
        'store_address': storeAddress,
        'delivery_enabled': deliveryEnabled,
        'delivery_radius_m': radiusM,
        'delivery_fee': deliveryFee,
        'free_delivery_min': freeDeliveryMin,
        'delivery_cutoff_minutes': cutoffMinutes,
      };
}

class StoreHour {
  const StoreHour({required this.dayOfWeek, this.openTime, this.closeTime, this.isClosed = false});
  final int dayOfWeek; // 0 = Minggu … 6 = Sabtu
  final String? openTime; // 'HH:MM'
  final String? closeTime;
  final bool isClosed;

  static const dayNames = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];

  static String? _hhmm(dynamic v) {
    final s = v?.toString();
    if (s == null || s.length < 5) return null;
    return s.substring(0, 5); // '10:00:00' -> '10:00'
  }

  factory StoreHour.fromJson(Map<String, dynamic> j) => StoreHour(
        dayOfWeek: _int(j['day_of_week']),
        openTime: _hhmm(j['open_time']),
        closeTime: _hhmm(j['close_time']),
        isClosed: j['is_closed'] == true,
      );

  Map<String, dynamic> toJson() => {
        'day_of_week': dayOfWeek,
        'open_time': openTime,
        'close_time': closeTime,
        'is_closed': isClosed,
      };

  StoreHour copyWith({String? openTime, String? closeTime, bool? isClosed}) => StoreHour(
        dayOfWeek: dayOfWeek,
        openTime: openTime ?? this.openTime,
        closeTime: closeTime ?? this.closeTime,
        isClosed: isClosed ?? this.isClosed,
      );
}
```

Catatan: `delivery_models.dart` meng-import `order_model.dart` dan `order_model.dart` meng-import `delivery_models.dart` — import melingkar antar-library diperbolehkan di Dart.

- [ ] **Step 4: Ubah `order_model.dart`**

Tambah import di atas: `import 'delivery_models.dart';`

`OrderType` — tambah nilai & daftar kasir:

```dart
enum OrderType {
  dineIn('dine_in', 'Dine-in', 'Makan di tempat', Icons.storefront_rounded),
  takeaway('takeaway', 'Bawa Pulang', 'Dibungkus', Icons.shopping_bag_rounded),
  delivery('delivery', 'Delivery', 'Diantar ke alamatmu', Icons.delivery_dining_rounded);

  const OrderType(this.apiValue, this.label, this.description, this.icon);

  /// Nilai yang dikirim ke / diterima dari backend.
  final String apiValue;
  final String label;
  final String description;
  final IconData icon;

  /// Tipe yang bisa dipilih kasir di toko (delivery hanya dari app pelanggan).
  static const List<OrderType> counterTypes = [OrderType.dineIn, OrderType.takeaway];

  static OrderType fromString(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'takeaway':
      case 'take_away':
        return OrderType.takeaway;
      case 'delivery':
        return OrderType.delivery;
      case 'dine_in':
      case 'dinein':
      default:
        return OrderType.dineIn;
    }
  }
}
```

`OrderItemModel.fromJson` — nama juga dari embed `menu_items` (baris kurir):

```dart
      name: (json['name'] ?? (json['menu_items'] is Map ? json['menu_items']['name'] : null) ?? '').toString(),
```

`OrderModel` — tambah parameter konstruktor (setelah `this.tableNumber,`):

```dart
    this.deliveryFee = 0,
    this.deliveryStatus,
    this.deliveryAddress,
    this.deliveryDistanceM,
    this.courierName,
    this.courierPhone,
```

field (setelah `final String? tableNumber;`):

```dart
  /// Ongkir yang dibayar pelanggan (0 untuk non-delivery / gratis ongkir).
  final int deliveryFee;

  /// Status antaran (null untuk non-delivery / belum dibayar).
  final DeliveryStatus? deliveryStatus;

  /// Snapshot alamat saat pesan (delivery).
  final AddressModel? deliveryAddress;
  final int? deliveryDistanceM;
  final String? courierName;
  final String? courierPhone;

  bool get isDelivery => orderType == OrderType.delivery;
```

Di `OrderModel.fromJson`, ganti baris `final rawItems = json['items'];` dengan:

```dart
    final rawItems = json['items'] ?? json['order_items'];
    final courier = json['courier'] is Map ? Map<String, dynamic>.from(json['courier']) : const <String, dynamic>{};
    final addr = json['delivery_address'];
```

dan tambahkan di akhir argumen `OrderModel(` (setelah `tableNumber: ...,`):

```dart
      deliveryFee: _asInt(json['delivery_fee']),
      deliveryStatus: DeliveryStatus.fromString(json['delivery_status']?.toString()),
      deliveryAddress: addr is Map ? AddressModel.fromJson(Map<String, dynamic>.from(addr)) : null,
      deliveryDistanceM: json['delivery_distance_m'] == null ? null : _asInt(json['delivery_distance_m']),
      courierName: (json['courier_name'] ?? courier['name'])?.toString(),
      courierPhone: (json['courier_phone'] ?? courier['phone'])?.toString(),
```

`CheckoutResult` — tambah `this.deliveryFee = 0,` di konstruktor, field `final int deliveryFee;`, dan di `fromJson`:

```dart
      deliveryFee: OrderModel._asInt(json['deliveryFee'] ?? json['delivery_fee']),
```

- [ ] **Step 5: `user_model.dart`** — setelah getter `isAdmin` tambahkan:

```dart
  /// Kurir Rehat (layar Antaran). Tidak bergantung pada build admin: kurir
  /// memakai app web pelanggan.
  bool get isCourier => role == 'courier';
```

- [ ] **Step 6: Run tests**

Run: `FLUTTER test test/delivery_models_test.dart test/models_test.dart`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/shared/models test/delivery_models_test.dart
git commit -m "feat(delivery): model delivery, OrderType.delivery & field antaran di pesanan"
```

---

### Task 2: Endpoint & `DeliveryRepository`

**Files:**
- Modify: `lib/core/constants/api_constants.dart`
- Create: `lib/features/delivery/data/delivery_repository.dart`
- Modify: `lib/features/order/data/order_repository.dart` (`createOrder`)
- Modify: `test/checkout_controller_test.dart` (signature fake)

- [ ] **Step 1: Konstanta** — tambahkan di dalam class `ApiConstants` (sebelum `}` penutup):

```dart
  // Delivery ------------------------------------------------------------
  static const String deliveryConfig = '/delivery/config';
  static const String deliveryQuote = '/delivery/quote';
  static const String myAddresses = '/me/addresses';
  static String myAddress(String id) => '/me/addresses/$id';
  static const String courierDeliveries = '/courier/deliveries';
  static const String courierDuty = '/courier/duty';
  static String courierAction(String id, String action) => '/courier/deliveries/$id/$action';
  static const String adminStoreSettings = '/admin/store-settings';
  static const String adminStoreHours = '/admin/store-hours';
  static const String adminCouriers = '/admin/couriers';
  static String adminCourier(String id) => '/admin/couriers/$id';
  static String adminAssignCourier(String orderId) => '/admin/orders/$orderId/assign-courier';
  static String adminDeliveryRefund(String orderId) => '/admin/orders/$orderId/delivery-refund';
```

- [ ] **Step 2: Repository**

```dart
// lib/features/delivery/data/delivery_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/delivery_models.dart';

class DeliveryRepository {
  DeliveryRepository({required DioClient client}) : _client = client;
  final DioClient _client;

  Map<String, dynamic> _map(dynamic body) {
    final inner = body is Map ? body['data'] : null;
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return body is Map ? Map<String, dynamic>.from(body) : const {};
  }

  List<Map<String, dynamic>> _list(dynamic body) {
    final inner = body is Map ? body['data'] : body;
    return inner is List
        ? inner.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : const [];
  }

  // Pelanggan ----------------------------------------------------------
  Future<DeliveryConfig> fetchConfig() async =>
      DeliveryConfig.fromJson(_map((await _client.get<dynamic>(ApiConstants.deliveryConfig)).data));

  Future<DeliveryQuote> quote({required String addressId, required int itemsNet}) async {
    final res = await _client.post<dynamic>(ApiConstants.deliveryQuote,
        data: {'address_id': addressId, 'items_net': itemsNet < 0 ? 0 : itemsNet});
    return DeliveryQuote.fromJson(_map(res.data));
  }

  Future<List<AddressModel>> fetchAddresses() async =>
      _list((await _client.get<dynamic>(ApiConstants.myAddresses)).data).map(AddressModel.fromJson).toList();

  Future<AddressModel> createAddress(AddressModel a) async =>
      AddressModel.fromJson(_map((await _client.post<dynamic>(ApiConstants.myAddresses, data: a.toJson())).data));

  Future<AddressModel> updateAddress(String id, AddressModel a) async =>
      AddressModel.fromJson(_map((await _client.patch<dynamic>(ApiConstants.myAddress(id), data: a.toJson())).data));

  Future<void> deleteAddress(String id) => _client.delete<dynamic>(ApiConstants.myAddress(id));

  // Kurir --------------------------------------------------------------
  Future<CourierDeliveries> fetchCourierDeliveries() async =>
      CourierDeliveries.fromJson(_map((await _client.get<dynamic>(ApiConstants.courierDeliveries)).data));

  Future<void> setDuty(bool onDuty) => _client.patch<dynamic>(ApiConstants.courierDuty, data: {'on_duty': onDuty});

  Future<void> claim(String orderId) => _client.post<dynamic>(ApiConstants.courierAction(orderId, 'claim'));
  Future<void> markOnTheWay(String orderId) => _client.post<dynamic>(ApiConstants.courierAction(orderId, 'on-the-way'));
  Future<void> markDelivered(String orderId) => _client.post<dynamic>(ApiConstants.courierAction(orderId, 'delivered'));
  Future<void> markFailed(String orderId, String reason) =>
      _client.post<dynamic>(ApiConstants.courierAction(orderId, 'failed'), data: {'reason': reason});

  // Admin --------------------------------------------------------------
  Future<(StoreSettings, List<StoreHour>)> fetchStoreSettings() async {
    final data = _map((await _client.get<dynamic>(ApiConstants.adminStoreSettings)).data);
    final s = data['settings'] is Map ? Map<String, dynamic>.from(data['settings']) : <String, dynamic>{};
    final hours = (data['hours'] is List ? data['hours'] as List : const [])
        .whereType<Map>()
        .map((e) => StoreHour.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
    return (StoreSettings.fromJson(s), hours);
  }

  Future<void> updateStoreSettings(StoreSettings s) =>
      _client.patch<dynamic>(ApiConstants.adminStoreSettings, data: s.toJson());

  Future<void> saveStoreHours(List<StoreHour> hours) =>
      _client.put<dynamic>(ApiConstants.adminStoreHours, data: [for (final h in hours) h.toJson()]);

  Future<List<CourierInfo>> fetchCouriers() async =>
      _list((await _client.get<dynamic>(ApiConstants.adminCouriers)).data).map(CourierInfo.fromJson).toList();

  Future<void> addCourier(String phone) => _client.post<dynamic>(ApiConstants.adminCouriers, data: {'phone': phone});
  Future<void> removeCourier(String id) => _client.delete<dynamic>(ApiConstants.adminCourier(id));

  Future<void> assignCourier(String orderId, String courierId) =>
      _client.post<dynamic>(ApiConstants.adminAssignCourier(orderId), data: {'courier_id': courierId});

  Future<void> refundDelivery(String orderId, String reason) =>
      _client.post<dynamic>(ApiConstants.adminDeliveryRefund(orderId), data: {'reason': reason, 'mode': 'wallet'});
}

final deliveryRepositoryProvider =
    Provider<DeliveryRepository>((ref) => DeliveryRepository(client: ref.watch(dioClientProvider)));

final deliveryConfigProvider = FutureProvider.autoDispose<DeliveryConfig>(
    (ref) => ref.watch(deliveryRepositoryProvider).fetchConfig());

final addressesProvider = FutureProvider.autoDispose<List<AddressModel>>(
    (ref) => ref.watch(deliveryRepositoryProvider).fetchAddresses());

final courierDeliveriesProvider = FutureProvider.autoDispose<CourierDeliveries>(
    (ref) => ref.watch(deliveryRepositoryProvider).fetchCourierDeliveries());

final storeSettingsProvider = FutureProvider.autoDispose<(StoreSettings, List<StoreHour>)>(
    (ref) => ref.watch(deliveryRepositoryProvider).fetchStoreSettings());

final couriersProvider = FutureProvider.autoDispose<List<CourierInfo>>(
    (ref) => ref.watch(deliveryRepositoryProvider).fetchCouriers());
```

- [ ] **Step 3: `OrderRepository.createOrder`** — tambah parameter `String? addressId,` (setelah `String? tableNumber,`) dan di `payload` (setelah blok `table_number`):

```dart
      if (addressId != null && addressId.isNotEmpty) 'address_id': addressId,
```

- [ ] **Step 4: Sesuaikan fake di `test/checkout_controller_test.dart`** — override `createOrder` di `_FakeOrderRepository` harus menerima parameter baru. Tambah `String? addressId,` ke parameter override (setelah `String? tableNumber,`).

- [ ] **Step 5: Analyze & test**

Run: `FLUTTER analyze && FLUTTER test`
Expected: `No issues found!` (atau hanya info lama yang sudah ada sebelumnya) dan semua test PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/constants/api_constants.dart lib/features/delivery/data lib/features/order/data/order_repository.dart test/checkout_controller_test.dart
git commit -m "feat(delivery): DeliveryRepository & endpoint delivery, createOrder kirim address_id"
```

---

### Task 3: Checkout controller — alamat, ongkir, validasi

**Files:**
- Modify: `lib/features/order/application/checkout_controller.dart`
- Test: `test/checkout_delivery_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/checkout_delivery_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/core/network/dio_client.dart';
import 'package:rehat_app/core/storage/secure_storage.dart';
import 'package:rehat_app/features/auth/application/auth_controller.dart';
import 'package:rehat_app/features/delivery/data/delivery_repository.dart';
import 'package:rehat_app/features/menu/application/cart_controller.dart';
import 'package:rehat_app/features/order/application/checkout_controller.dart';
import 'package:rehat_app/features/order/data/order_repository.dart';
import 'package:rehat_app/shared/models/cart_item_model.dart';
import 'package:rehat_app/shared/models/delivery_models.dart';
import 'package:rehat_app/shared/models/menu_item_model.dart';
import 'package:rehat_app/shared/models/order_model.dart';

class _FakeOrders extends OrderRepository {
  _FakeOrders() : super(client: DioClient(storage: SecureStorage()));
  int creates = 0;
  OrderType? lastType;
  String? lastAddressId;

  @override
  Future<CheckoutResult> createOrder({
    required List<CartItemModel> items,
    required PaymentMethod paymentMethod,
    OrderType orderType = OrderType.dineIn,
    String? voucherCode,
    String? notes,
    String? tableNumber,
    String? addressId,
  }) async {
    creates++;
    lastType = orderType;
    lastAddressId = addressId;
    return const CheckoutResult(
        orderId: 'o1', queueNumber: '', subtotal: 30000, discountAmount: 0,
        total: 35000, deliveryFee: 5000, paymentMethod: PaymentMethod.qris, orderType: OrderType.delivery);
  }

  @override
  Future<List<OrderModel>> fetchHistory({int page = 1, int limit = 20}) async => const [];
  @override
  Future<List<OrderModel>> fetchAllOrders({String? status, String? date, int page = 1, int limit = 30}) async => const [];
}

class _FakeDelivery extends DeliveryRepository {
  _FakeDelivery() : super(client: DioClient(storage: SecureStorage()));
  List<AddressModel> addresses = const [
    AddressModel(id: 'a1', label: 'Kantor', addressText: 'Jl. A', recipientName: 'N', recipientPhone: '0812', lat: 0, lng: 0),
    AddressModel(id: 'a2', label: 'Rumah', addressText: 'Jl. B', recipientName: 'N', recipientPhone: '0812', lat: 0, lng: 0, isDefault: true),
  ];
  DeliveryQuote nextQuote = const DeliveryQuote(available: true, distanceM: 1200, deliveryFee: 5000, freeDeliveryMin: 50000, remainingForFree: 20000);
  final List<(String, int)> quoteCalls = [];

  @override
  Future<List<AddressModel>> fetchAddresses() async => addresses;
  @override
  Future<DeliveryQuote> quote({required String addressId, required int itemsNet}) async {
    quoteCalls.add((addressId, itemsNet));
    return nextQuote;
  }
}

class _FakeAuth extends AuthController {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);
  @override
  Future<void> refreshUser() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeOrders orders;
  late _FakeDelivery delivery;
  late ProviderContainer c;

  setUp(() {
    orders = _FakeOrders();
    delivery = _FakeDelivery();
    c = ProviderContainer(overrides: [
      orderRepositoryProvider.overrideWithValue(orders),
      deliveryRepositoryProvider.overrideWithValue(delivery),
      authControllerProvider.overrideWith(_FakeAuth.new),
    ]);
    c.read(cartControllerProvider.notifier)
        .add(const MenuItemModel(id: 'm1', name: 'Kopi', price: 30000), quantity: 1);
  });
  tearDown(() => c.dispose());

  CheckoutController ctl() => c.read(checkoutControllerProvider.notifier);
  CheckoutState st() => c.read(checkoutControllerProvider);

  test('useDelivery memilih alamat default & mengambil quote dari total menu', () async {
    await ctl().useDelivery();
    expect(st().orderType, OrderType.delivery);
    expect(st().addressId, 'a2');
    expect(delivery.quoteCalls.single, ('a2', 30000));
    expect(st().deliveryFee, 5000);
  });

  test('deliveryFee 0 bila bukan delivery', () async {
    await ctl().useDelivery();
    ctl().setOrderType(OrderType.takeaway);
    expect(st().deliveryFee, 0);
  });

  test('pesan delivery tanpa alamat ditolak tanpa memanggil backend', () async {
    delivery.addresses = const [];
    await ctl().useDelivery();
    final r = await ctl().placeOrder();
    expect(r, isNull);
    expect(st().errorMessage, 'Pilih alamat pengiriman.');
    expect(orders.creates, 0);
  });

  test('alamat di luar jangkauan ditolak dengan pesan dari server', () async {
    delivery.nextQuote = const DeliveryQuote(available: false, reason: 'OUT_OF_RADIUS', message: 'Di luar jangkauan');
    await ctl().useDelivery();
    final r = await ctl().placeOrder();
    expect(r, isNull);
    expect(st().errorMessage, 'Di luar jangkauan');
    expect(orders.creates, 0);
  });

  test('pesan delivery sukses mengirim tipe delivery & address_id', () async {
    await ctl().useDelivery();
    final r = await ctl().placeOrder();
    expect(r, isNotNull);
    expect(orders.lastType, OrderType.delivery);
    expect(orders.lastAddressId, 'a2');
  });

  test('ganti alamat mengambil quote baru', () async {
    await ctl().useDelivery();
    await ctl().selectAddress('a1');
    expect(st().addressId, 'a1');
    expect(delivery.quoteCalls.last.$1, 'a1');
  });

  test('takeaway tidak mengirim address_id', () async {
    await ctl().useDelivery();
    ctl().setOrderType(OrderType.takeaway);
    await ctl().placeOrder();
    expect(orders.lastType, OrderType.takeaway);
    expect(orders.lastAddressId, isNull);
  });
}
```

Bila `AuthState` tidak punya konstruktor `const`, hapus kata `const` di `_FakeAuth.build` (cek `auth_controller.dart`). Bila `CartController.add` memakai tanda tangan lain, ikuti pemakaian di `test/checkout_controller_test.dart` (`fillCart`).

- [ ] **Step 2: Run test to verify it fails**

Run: `FLUTTER test test/checkout_delivery_test.dart`
Expected: FAIL — compile error (`useDelivery`, `addressId`, `deliveryFee` belum ada)

- [ ] **Step 3: Implementasi di `checkout_controller.dart`**

Import tambahan:

```dart
import '../../../shared/models/delivery_models.dart';
import '../../delivery/data/delivery_repository.dart';
```

`CheckoutState`: tambah parameter konstruktor `this.addressId, this.deliveryQuote, this.isQuoting = false,`, field:

```dart
  /// Alamat pengiriman terpilih (delivery).
  final String? addressId;

  /// Hasil cek alamat + ongkir dari server (delivery).
  final DeliveryQuote? deliveryQuote;
  final bool isQuoting;

  /// Ongkir yang akan ditagih (0 bila bukan delivery).
  int get deliveryFee =>
      orderType == OrderType.delivery ? (deliveryQuote?.deliveryFee ?? 0) : 0;
```

`copyWith`: tambah parameter `String? addressId, DeliveryQuote? deliveryQuote, bool clearQuote = false, bool? isQuoting,` dan di `return CheckoutState(` tambahkan:

```dart
      addressId: addressId ?? this.addressId,
      deliveryQuote: clearQuote ? null : (deliveryQuote ?? this.deliveryQuote),
      isQuoting: isQuoting ?? this.isQuoting,
```

Di `CheckoutController` tambahkan (setelah `setNotes`):

```dart
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
```

Panggil ulang quote saat voucher berubah:
- di akhir cabang sukses `applyVoucher` (setelah `state = state.copyWith(voucherCode: trimmed, ...)`), tambahkan `await refreshQuote();`
- ubah `clearVoucher` menjadi:

```dart
  void clearVoucher() {
    state = state.copyWith(voucherCode: '', clearVoucher: true);
    refreshQuote();
  }
```

`_signatureOf`: tambahkan alamat ke sidik jari (sebelum `'#${state.voucherCode}'`):

```dart
        '#${state.addressId ?? ''}'
```

`placeOrder`: pindahkan perhitungan `table`/`effectiveType` ke **sebelum** `final signature = _signatureOf(items);` (hapus deklarasi lama di dalam `try`) dan tambahkan validasi delivery:

```dart
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
```

Di pemanggilan `repo.createOrder(...)` tambahkan argumen:

```dart
                  addressId: effectiveType == OrderType.delivery ? state.addressId : null,
```

- [ ] **Step 4: Run tests**

Run: `FLUTTER test test/checkout_delivery_test.dart test/checkout_controller_test.dart`
Expected: PASS (test lama tetap hijau)

- [ ] **Step 5: Commit**

```bash
git add lib/features/order/application/checkout_controller.dart test/checkout_delivery_test.dart
git commit -m "feat(delivery): checkout — pilih alamat, ongkir dari server, validasi delivery"
```

---

### Task 4: Paket peta & izin lokasi + `LocationPicker`

**Files:**
- Modify: `pubspec.yaml` (via `flutter pub add`)
- Modify: `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`
- Create: `lib/features/delivery/presentation/widgets/location_picker.dart`

- [ ] **Step 1: Tambah paket** (versi terbaru yang kompatibel dipilih otomatis)

```bash
FLUTTER pub add flutter_map latlong2 geolocator
```
Expected: `pubspec.yaml` mendapat tiga dependensi; `pub get` sukses.

- [ ] **Step 2: Izin lokasi**

`android/app/src/main/AndroidManifest.xml`, di dalam `<manifest>` sebelum `<application`:

```xml
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```
(lewati baris yang sudah ada)

`ios/Runner/Info.plist`, di dalam `<dict>` utama:

```xml
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>Lokasi dipakai untuk menandai alamat pengiriman pesananmu.</string>
```

- [ ] **Step 3: `LocationPicker`**

Cari `applicationId` di `android/app/build.gradle` atau `build.gradle.kts` dan pakai nilainya untuk `userAgentPackageName` (kebijakan tile OpenStreetMap mewajibkan user-agent yang jelas).

```dart
// lib/features/delivery/presentation/widgets/location_picker.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

/// Titik Rehat Coffeehouse (default peta bila belum ada titik).
const rehatStoreLatLng = LatLng(-7.1940555, 113.2508814);

/// Peta dengan pin tetap di tengah: geser peta untuk menandai lokasi.
class LocationPicker extends StatefulWidget {
  const LocationPicker({super.key, required this.initial, required this.onChanged, this.height = 260});

  final LatLng initial;
  final ValueChanged<LatLng> onChanged;
  final double height;

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final _map = MapController();
  bool _locating = false;

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _snack('Izin lokasi ditolak. Geser peta untuk menandai lokasi.');
        return;
      }
      final p = await Geolocator.getCurrentPosition();
      final ll = LatLng(p.latitude, p.longitude);
      _map.move(ll, 17);
      widget.onChanged(ll);
    } catch (_) {
      _snack('Lokasi tidak bisa dibaca. Geser peta untuk menandai lokasi.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: widget.initial,
                initialZoom: 16,
                onPositionChanged: (camera, hasGesture) {
                  if (hasGesture) widget.onChanged(camera.center);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'GANTI_DENGAN_APPLICATION_ID',
                ),
              ],
            ),
            const IgnorePointer(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 36),
                  child: Icon(Icons.location_pin, size: 44, color: AppColors.amberDark),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: FloatingActionButton.small(
                heroTag: null,
                onPressed: _locating ? null : _useMyLocation,
                child: _locating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location_rounded),
              ),
            ),
            Positioned(
              left: 6,
              bottom: 4,
              child: Container(
                color: Colors.white70,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('© OpenStreetMap', style: AppTextStyles.caption.copyWith(color: Colors.black87)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

Ganti `GANTI_DENGAN_APPLICATION_ID` dengan `applicationId` sungguhan. Bila versi `flutter_map` yang terpasang memakai tanda tangan `onPositionChanged` lain, sesuaikan sesuai changelog paket tanpa mengubah perilaku (pin tengah → `onChanged` hanya saat digeser pengguna).

- [ ] **Step 4: Analyze**

Run: `FLUTTER analyze`
Expected: tanpa error baru.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist lib/features/delivery/presentation/widgets/location_picker.dart
git commit -m "feat(delivery): paket peta & lokasi + LocationPicker (pin tengah, lokasi saya)"
```

---

### Task 5: Layar alamat (daftar & form) + rute

**Files:**
- Create: `lib/features/delivery/presentation/address_list_screen.dart`
- Create: `lib/features/delivery/presentation/address_form_screen.dart`
- Modify: `lib/core/router/route_names.dart`, `lib/core/router/app_router.dart`

- [ ] **Step 1: Nama rute** — tambahkan di class `RouteNames`:

```dart
  static const String addresses = 'addresses';
  static const String addressesPath = '/addresses';

  static const String addressForm = 'address-form';
  static const String addressFormPath = '/addresses/form';

  static const String courier = 'courier';
  static const String courierPath = '/courier';

  static const String adminStoreSettings = 'admin-store-settings';
  static const String adminStoreSettingsPath = '/admin/store-settings';
```

- [ ] **Step 2: Form alamat**

```dart
// lib/features/delivery/presentation/address_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/network/api_exception.dart';
import '../../../shared/models/delivery_models.dart';
import '../../auth/application/auth_controller.dart';
import '../data/delivery_repository.dart';
import 'widgets/location_picker.dart';

/// Tambah / ubah alamat. `existing` null = alamat baru. Pop dengan [AddressModel] tersimpan.
class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key, this.existing});
  final AddressModel? existing;

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.existing?.label ?? 'Rumah');
  late final _address = TextEditingController(text: widget.existing?.addressText ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late final _name = TextEditingController(
      text: widget.existing?.recipientName ?? ref.read(authControllerProvider).user?.name ?? '');
  late final _phone = TextEditingController(
      text: widget.existing?.recipientPhone ?? ref.read(authControllerProvider).user?.phone ?? '');
  late LatLng _point = widget.existing == null
      ? rehatStoreLatLng
      : LatLng(widget.existing!.lat, widget.existing!.lng);
  late bool _isDefault = widget.existing?.isDefault ?? false;
  bool _pinMoved = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_label, _address, _notes, _name, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (widget.existing == null && !_pinMoved) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Geser peta atau tekan "Lokasi saya" untuk menandai lokasi alamat.')));
      return;
    }
    setState(() => _saving = true);
    final a = AddressModel(
      label: _label.text.trim(),
      addressText: _address.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      recipientName: _name.text.trim(),
      recipientPhone: _phone.text.trim(),
      lat: _point.latitude,
      lng: _point.longitude,
      isDefault: _isDefault,
    );
    try {
      final repo = ref.read(deliveryRepositoryProvider);
      final saved = widget.existing == null
          ? await repo.createAddress(a)
          : await repo.updateAddress(widget.existing!.id, a);
      ref.invalidate(addressesProvider);
      if (mounted) context.pop(saved);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Tambah alamat' : 'Ubah alamat')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            LocationPicker(
              initial: _point,
              onChanged: (ll) => setState(() {
                _point = ll;
                _pinMoved = true;
              }),
            ),
            const SizedBox(height: 6),
            const Text('Geser peta sampai pin tepat di lokasi pengantaran.'),
            const SizedBox(height: 16),
            TextFormField(controller: _label, decoration: const InputDecoration(labelText: 'Label (mis. Rumah, Kantor)'), validator: _required),
            const SizedBox(height: 12),
            TextFormField(controller: _address, maxLines: 2, decoration: const InputDecoration(labelText: 'Alamat lengkap'),
                validator: (v) => (v ?? '').trim().length < 5 ? 'Minimal 5 karakter' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _notes, decoration: const InputDecoration(labelText: 'Patokan (opsional)', hintText: 'Mis. pagar hijau, lantai 2')),
            const SizedBox(height: 12),
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nama penerima'), validator: _required),
            const SizedBox(height: 12),
            TextFormField(controller: _phone, keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'No. HP penerima'),
                validator: (v) => (v ?? '').replaceAll(RegExp(r'[^0-9]'), '').length < 8 ? 'Nomor HP tidak valid' : null),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
              title: const Text('Jadikan alamat utama'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Menyimpan…' : 'Simpan alamat'),
            ),
          ],
        ),
      ),
    );
  }
}
```

Bila `UserModel` memakai nama field lain untuk nama/HP, sesuaikan (`user?.name`, `user?.phone`).

- [ ] **Step 3: Daftar alamat**

```dart
// lib/features/delivery/presentation/address_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/route_names.dart';
import '../../../shared/models/delivery_models.dart';
import '../data/delivery_repository.dart';

class AddressListScreen extends ConsumerWidget {
  const AddressListScreen({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, AddressModel a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus alamat?'),
        content: Text(a.label),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(deliveryRepositoryProvider).deleteAddress(a.id);
      ref.invalidate(addressesProvider);
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(addressesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Alamat saya')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(RouteNames.addressForm),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Tambah alamat'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: TextButton(onPressed: () => ref.invalidate(addressesProvider), child: const Text('Gagal memuat. Coba lagi'))),
        data: (list) => list.isEmpty
            ? const Center(child: Text('Belum ada alamat tersimpan.'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final a = list[i];
                  return Card(
                    child: ListTile(
                      leading: Icon(a.isDefault ? Icons.home_rounded : Icons.location_on_outlined),
                      title: Text(a.isDefault ? '${a.label} • Utama' : a.label),
                      subtitle: Text('${a.addressText}\n${a.recipientName} • ${a.recipientPhone}'),
                      isThreeLine: true,
                      onTap: () => context.pushNamed(RouteNames.addressForm, extra: a),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => _delete(context, ref, a),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
```

- [ ] **Step 4: Daftarkan rute** di `app_router.dart` — import kedua layar, lalu tambahkan di daftar `routes:` tingkat atas (setelah rute `notifications`):

```dart
      GoRoute(
        path: RouteNames.addressesPath,
        name: RouteNames.addresses,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const AddressListScreen(),
      ),
      GoRoute(
        path: RouteNames.addressFormPath,
        name: RouteNames.addressForm,
        parentNavigatorKey: rootKey,
        builder: (context, state) => AddressFormScreen(
            existing: state.extra is AddressModel ? state.extra as AddressModel : null),
      ),
```

Urutan penting: rute `addresses` didaftarkan **sebelum** `addressForm` tidak masalah karena path berbeda penuh.

- [ ] **Step 5: Analyze & test**

Run: `FLUTTER analyze && FLUTTER test`
Expected: tanpa error; semua test PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/delivery/presentation lib/core/router
git commit -m "feat(delivery): layar daftar & form alamat dengan pin peta"
```

---

### Task 6: Checkout UI — kartu Delivery, alamat, ongkir; kasir tanpa delivery

**Files:**
- Create: `lib/features/delivery/presentation/widgets/delivery_address_section.dart`
- Modify: `lib/features/order/presentation/checkout_screen.dart`
- Modify: `lib/features/menu/presentation/widgets/cashier_actions.dart`

- [ ] **Step 1: Bagian alamat di checkout**

```dart
// lib/features/delivery/presentation/widgets/delivery_address_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/router/route_names.dart';
import '../../../../shared/models/delivery_models.dart';
import '../../../order/application/checkout_controller.dart';
import '../../data/delivery_repository.dart';

/// Alamat pengiriman terpilih + status cek jarak/ongkir (checkout delivery).
class DeliveryAddressSection extends ConsumerWidget {
  const DeliveryAddressSection({super.key});

  Future<void> _addNew(BuildContext context, WidgetRef ref) async {
    final saved = await context.pushNamed<AddressModel>(RouteNames.addressForm);
    if (saved != null) await ref.read(checkoutControllerProvider.notifier).selectAddress(saved.id);
  }

  Future<void> _pick(BuildContext context, WidgetRef ref, List<AddressModel> list) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final a in list)
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(a.label),
                subtitle: Text(a.addressText, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(c, a.id),
              ),
            ListTile(
              leading: const Icon(Icons.add_location_alt_outlined),
              title: const Text('Tambah alamat baru'),
              onTap: () => Navigator.pop(c, '__new__'),
            ),
          ],
        ),
      ),
    );
    if (chosen == null || !context.mounted) return;
    if (chosen == '__new__') return _addNew(context, ref);
    await ref.read(checkoutControllerProvider.notifier).selectAddress(chosen);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(checkoutControllerProvider);
    final list = ref.watch(addressesProvider).valueOrNull ?? const <AddressModel>[];
    final selected = list.where((a) => a.id == state.addressId).firstOrNull;
    final q = state.deliveryQuote;

    if (selected == null) {
      return OutlinedButton.icon(
        onPressed: () => _addNew(context, ref),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Tambah alamat pengiriman'),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.location_on_rounded, color: AppColors.amberDark),
              const SizedBox(width: 8),
              Expanded(child: Text(selected.label, style: AppTextStyles.titleMedium)),
              TextButton(onPressed: () => _pick(context, ref, list), child: const Text('Ganti')),
            ]),
            Text(selected.addressText, style: AppTextStyles.bodyMedium),
            if (selected.notes != null) Text(selected.notes!, style: AppTextStyles.bodySmall),
            Text('${selected.recipientName} • ${selected.recipientPhone}', style: AppTextStyles.bodySmall),
            const SizedBox(height: 8),
            if (state.isQuoting)
              const LinearProgressIndicator()
            else if (q != null && !q.available)
              Text(q.message ?? 'Alamat ini belum bisa dikirimi.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.error))
            else if (q != null)
              Text('Jarak ±${q.distanceKmLabel}', style: AppTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}
```

Bila `firstOrNull` tidak tersedia (butuh `package:collection` atau Dart 3), pakai `list.where(...).isEmpty ? null : ...first`.

- [ ] **Step 2: `checkout_screen.dart`**

Import tambahan:

```dart
import '../../delivery/data/delivery_repository.dart';
import '../../delivery/presentation/widgets/delivery_address_section.dart';
```

Ganti perhitungan total (baris ±72–73):

```dart
    final discount = state.discountAmount;
    final deliveryFee = state.deliveryFee;
    final total = subtotal - discount + deliveryFee;
    final deliveryConfig = ref.watch(deliveryConfigProvider).valueOrNull;
```

Ganti blok `Row(children: [ for (final type in OrderType.values) ...` (baris ±98–111) dengan:

```dart
        Builder(builder: (context) {
          final types = [OrderType.dineIn, OrderType.takeaway, if (!isGuest) OrderType.delivery];
          return Row(
            children: [
              for (final type in types) ...[
                Expanded(
                  child: Opacity(
                    opacity: type == OrderType.delivery && deliveryConfig?.available != true ? 0.5 : 1,
                    child: _OrderTypeCard(
                      type: type,
                      selected: state.orderType == type,
                      onTap: () {
                        if (type != OrderType.delivery) return notifier.setOrderType(type);
                        if (deliveryConfig?.available != true) {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(SnackBar(
                                content: Text(deliveryConfig?.message ?? 'Delivery sedang tidak tersedia.')));
                          return;
                        }
                        notifier.useDelivery();
                      },
                    ),
                  ),
                ),
                if (type != types.last) const SizedBox(width: 10),
              ],
            ],
          );
        }),
        if (state.orderType == OrderType.delivery) ...[
          const SizedBox(height: 24),
          const _SectionLabel('Alamat pengiriman'),
          const SizedBox(height: 10),
          const DeliveryAddressSection(),
        ],
```

Pertahankan argumen `_OrderTypeCard` seperti yang ada (`type`, `selected`, `onTap`); bila kartu memiliki parameter lain, ikuti tanda tangannya.

Di ringkasan, setelah blok `if (discount > 0) ...[ ... ],` (baris ±190–197) tambahkan:

```dart
            if (state.orderType == OrderType.delivery) ...[
              const SizedBox(height: 6),
              _summaryRow('Ongkir',
                  state.deliveryQuote != null && deliveryFee == 0 ? 'Gratis' : Formatters.rupiah(deliveryFee)),
              if ((state.deliveryQuote?.remainingForFree ?? 0) > 0 && deliveryFee > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Belanja ${Formatters.rupiah(state.deliveryQuote!.remainingForFree)} lagi untuk gratis ongkir',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.amberDark),
                    ),
                  ),
                ),
            ],
```

Tombol kirim (`submit`), ganti `onPressed`:

```dart
      onPressed: state.isSubmitting ||
              (state.orderType == OrderType.delivery &&
                  (state.isQuoting || state.deliveryQuote?.available != true))
          ? null
          : _placeOrder,
```

- [ ] **Step 3: Kasir tanpa delivery** — `cashier_actions.dart` baris ±166 & ±193: ganti `OrderType.values` dengan `OrderType.counterTypes` (dua tempat).

- [ ] **Step 4: Analyze & test**

Run: `FLUTTER analyze && FLUTTER test`
Expected: tanpa error; semua PASS.

- [ ] **Step 5: Uji manual singkat** (web, backend produksi, delivery masih mati)

Run: `FLUTTER run -d chrome --dart-define=API_BASE_URL=https://rehat-backend-production.up.railway.app/v1`
Expected: checkout menampilkan kartu **Delivery** pudar; menekannya memunculkan "Delivery sedang tidak tersedia."; dine-in/bawa pulang tetap normal. **Jangan** membuat pesanan.

- [ ] **Step 6: Commit**

```bash
git add lib/features/delivery/presentation/widgets/delivery_address_section.dart lib/features/order/presentation/checkout_screen.dart lib/features/menu/presentation/widgets/cashier_actions.dart
git commit -m "feat(delivery): checkout — kartu Delivery, alamat pengiriman & baris ongkir"
```

---

### Task 7: Detail pesanan — ongkir, info antaran, aksi admin

**Files:**
- Create: `lib/features/delivery/presentation/widgets/delivery_info_card.dart`
- Create: `lib/features/delivery/presentation/widgets/admin_delivery_actions.dart`
- Modify: `lib/features/order/presentation/order_detail_screen.dart`

- [ ] **Step 1: Kartu info antaran**

```dart
// lib/features/delivery/presentation/widgets/delivery_info_card.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/order_model.dart';

/// Nomor 08xx -> 628xx untuk link wa.me.
String waNumber(String phone) {
  final d = phone.replaceAll(RegExp(r'[^0-9]'), '');
  return d.startsWith('0') ? '62${d.substring(1)}' : d;
}

class DeliveryInfoCard extends StatelessWidget {
  const DeliveryInfoCard({super.key, required this.order});
  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final a = order.deliveryAddress;
    final s = order.deliveryStatus;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(s?.icon ?? Icons.delivery_dining_rounded, color: AppColors.amberDark),
              const SizedBox(width: 8),
              Text(s?.label ?? 'Menunggu pembayaran', style: AppTextStyles.titleMedium),
            ]),
            if (order.courierName != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: Text('Kurir: ${order.courierName}', style: AppTextStyles.bodyMedium)),
                if (order.courierPhone != null) ...[
                  IconButton(
                    tooltip: 'Telepon kurir',
                    icon: const Icon(Icons.call_rounded),
                    onPressed: () => launchUrl(Uri.parse('tel:${order.courierPhone}')),
                  ),
                  IconButton(
                    tooltip: 'WhatsApp kurir',
                    icon: const Icon(Icons.chat_rounded),
                    onPressed: () => launchUrl(Uri.parse('https://wa.me/${waNumber(order.courierPhone!)}'),
                        mode: LaunchMode.externalApplication),
                  ),
                ],
              ]),
            ],
            if (a != null) ...[
              const Divider(height: 20),
              Text('Diantar ke ${a.label}', style: AppTextStyles.label),
              Text(a.addressText, style: AppTextStyles.bodyMedium),
              if (a.notes != null) Text(a.notes!, style: AppTextStyles.bodySmall),
              Text('${a.recipientName} • ${a.recipientPhone}', style: AppTextStyles.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Aksi admin**

```dart
// lib/features/delivery/presentation/widgets/admin_delivery_actions.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../shared/models/delivery_models.dart';
import '../../../../shared/models/order_model.dart';
import '../../../order/data/order_repository.dart';
import '../../data/delivery_repository.dart';

/// Admin: pilihkan/pindahkan kurir & batalkan + refund ke Saldo Rehat.
class AdminDeliveryActions extends ConsumerWidget {
  const AdminDeliveryActions({super.key, required this.order});
  final OrderModel order;

  bool get _active =>
      (order.status == OrderStatus.paid || order.status == OrderStatus.preparing) &&
      order.deliveryStatus != DeliveryStatus.delivered &&
      order.deliveryStatus != DeliveryStatus.cancelled;

  void _refresh(WidgetRef ref) {
    ref.invalidate(adminOrderDetailProvider(order.id));
    ref.invalidate(adminOrdersProvider);
  }

  void _toast(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _assign(BuildContext context, WidgetRef ref) async {
    List<CourierInfo> couriers;
    try {
      couriers = await ref.read(couriersProvider.future);
    } on ApiException catch (e) {
      if (context.mounted) _toast(context, e.message);
      return;
    }
    if (!context.mounted) return;
    final id = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Pilih kurir'),
        children: [
          if (couriers.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Belum ada kurir.')),
          for (final k in couriers)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, k.id),
              child: Text('${k.name} ${k.onDuty ? '• bertugas' : '• tidak bertugas'}'),
            ),
        ],
      ),
    );
    if (id == null) return;
    try {
      await ref.read(deliveryRepositoryProvider).assignCourier(order.id, id);
      _refresh(ref);
      if (context.mounted) _toast(context, 'Kurir ditetapkan');
    } on ApiException catch (e) {
      if (context.mounted) _toast(context, e.message);
    }
  }

  Future<void> _refund(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Batalkan & refund ke Saldo Rehat?'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Alasan (wajib)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Refund')),
        ],
      ),
    );
    if (reason == null || reason.length < 3) {
      if (reason != null && context.mounted) _toast(context, 'Alasan minimal 3 karakter');
      return;
    }
    try {
      await ref.read(deliveryRepositoryProvider).refundDelivery(order.id, reason);
      _refresh(ref);
      if (context.mounted) _toast(context, 'Pesanan dibatalkan & dana masuk Saldo Rehat pelanggan');
    } on ApiException catch (e) {
      if (context.mounted) _toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!order.isDelivery || !_active) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _assign(context, ref),
            icon: const Icon(Icons.person_pin_circle_outlined),
            label: Text(order.courierName == null ? 'Pilihkan kurir' : 'Pindahkan kurir'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _refund(context, ref),
            icon: const Icon(Icons.undo_rounded),
            label: const Text('Batal & refund'),
          ),
        ),
      ]),
    );
  }
}
```

Pastikan `adminOrderDetailProvider` diekspor dari `order_repository.dart` (dipakai `order_detail_screen.dart`); bila didefinisikan di file lain, impor dari sana.

- [ ] **Step 3: `order_detail_screen.dart`**

Import kedua widget dan `isAdminProvider` sudah ada. Di ringkasan, setelah blok `if (order.discountAmount > 0) ...[ ... ],` (baris ±223–228) tambahkan:

```dart
              if (order.isDelivery) ...[
                const SizedBox(height: 8),
                _summaryRow('Ongkir', order.deliveryFee == 0 ? 'Gratis' : Formatters.rupiah(order.deliveryFee)),
              ],
```

Di `_Body`, tepat sebelum `_AdminStatusControls(order: order),` (baris ±180) tambahkan:

```dart
        if (order.isDelivery) ...[
          DeliveryInfoCard(order: order),
          if (isAdmin) AdminDeliveryActions(order: order),
          const SizedBox(height: 16),
        ],
```

- [ ] **Step 4: Analyze & test**

Run: `FLUTTER analyze && FLUTTER test`
Expected: tanpa error; semua PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/delivery/presentation/widgets lib/features/order/presentation/order_detail_screen.dart
git commit -m "feat(delivery): detail pesanan — ongkir, status antaran, kurir & aksi admin"
```

---

### Task 8: Daftar pesanan admin — tanda delivery

**Files:**
- Modify: `lib/features/admin/presentation/admin_orders_screen.dart`

- [ ] **Step 1: `_OrderTypeChip`** (baris ±219–220) — sorot juga delivery:

```dart
    final highlight = type != OrderType.dineIn;
    final color = highlight ? AppColors.amberDark : AppColors.textSecondary;
```
(ganti `takeaway` → `highlight` di baris yang memakainya)

- [ ] **Step 2: Status antaran & kurir di kartu** — import `../../../shared/models/delivery_models.dart`; di `_AdminOrderCard`, setelah `Row(...)` berisi chip & total (baris ±152–177) tambahkan:

```dart
            if (order.isDelivery && order.deliveryStatus != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(order.deliveryStatus!.icon, size: 16, color: AppColors.amberDark),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [
                      order.deliveryStatus!.label,
                      if (order.courierName != null) order.courierName!,
                      if (order.deliveryDistanceM != null)
                        '${(order.deliveryDistanceM! / 1000).toStringAsFixed(1)} km',
                    ].join(' • '),
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ]),
            ],
```

- [ ] **Step 3: Analyze & test**

Run: `FLUTTER analyze && FLUTTER test`
Expected: tanpa error; semua PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/admin/presentation/admin_orders_screen.dart
git commit -m "feat(delivery): daftar pesanan admin menampilkan status antaran & kurir"
```

---

### Task 9: Layar Antaran (kurir)

**Files:**
- Create: `lib/features/delivery/presentation/courier_screen.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: Layar**

```dart
// lib/features/delivery/presentation/courier_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/delivery_models.dart';
import '../../../shared/models/order_model.dart';
import '../data/delivery_repository.dart';
import 'widgets/delivery_info_card.dart' show waNumber;

/// Layar kurir: saklar bertugas, antaran menunggu & antaranku.
class CourierScreen extends ConsumerStatefulWidget {
  const CourierScreen({super.key});
  @override
  ConsumerState<CourierScreen> createState() => _CourierScreenState();
}

class _CourierScreenState extends ConsumerState<CourierScreen> {
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => ref.invalidate(courierDeliveriesProvider));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String okMsg) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(okMsg)));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      ref.invalidate(courierDeliveriesProvider);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fail(OrderModel o) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Antaran #${o.queueNumber} gagal?'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Alasan (mis. pelanggan tidak bisa dihubungi)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Laporkan')),
        ],
      ),
    );
    if (reason == null || reason.length < 3) return;
    await _run(() => ref.read(deliveryRepositoryProvider).markFailed(o.id, reason), 'Dilaporkan ke admin');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(courierDeliveriesProvider);
    final repo = ref.read(deliveryRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Antaran')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: TextButton(onPressed: () => ref.invalidate(courierDeliveriesProvider), child: Text(e is ApiException ? e.message : 'Gagal memuat. Coba lagi')),
        ),
        data: (d) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(courierDeliveriesProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              SwitchListTile(
                value: d.onDuty,
                onChanged: _busy ? null : (v) => _run(() => repo.setDuty(v), v ? 'Kamu bertugas' : 'Selesai bertugas'),
                title: Text(d.onDuty ? 'Saya bertugas' : 'Tidak bertugas', style: AppTextStyles.titleMedium),
                subtitle: Text('Terkirim hari ini: ${d.deliveredToday}'),
              ),
              const SizedBox(height: 8),
              Text('Antaranku', style: AppTextStyles.titleLarge),
              const SizedBox(height: 8),
              if (d.mine.isEmpty) const Text('Belum ada antaran yang kamu bawa.'),
              for (final o in d.mine)
                _DeliveryCard(
                  order: o,
                  actions: [
                    if (o.deliveryStatus == DeliveryStatus.assigned)
                      FilledButton(onPressed: _busy ? null : () => _run(() => repo.markOnTheWay(o.id), 'Selamat mengantar!'), child: const Text('Berangkat')),
                    if (o.deliveryStatus == DeliveryStatus.onTheWay)
                      FilledButton(onPressed: _busy ? null : () => _run(() => repo.markDelivered(o.id), 'Antaran selesai'), child: const Text('Terkirim')),
                    TextButton(onPressed: _busy ? null : () => _fail(o), child: const Text('Gagal')),
                  ],
                ),
              const SizedBox(height: 20),
              Text('Menunggu diambil', style: AppTextStyles.titleLarge),
              const SizedBox(height: 8),
              if (!d.onDuty) const Text('Nyalakan "Saya bertugas" untuk melihat & mengambil antaran.')
              else if (d.waiting.isEmpty) const Text('Belum ada antaran baru.'),
              for (final o in d.waiting)
                _DeliveryCard(
                  order: o,
                  actions: [
                    FilledButton(onPressed: _busy ? null : () => _run(() => repo.claim(o.id), 'Antaran diambil'), child: const Text('Ambil antaran')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.order, required this.actions});
  final OrderModel order;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final a = order.deliveryAddress;
    final items = order.items.map((i) => '${i.quantity}x ${i.name}').join(', ');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('#${order.queueNumber}', style: AppTextStyles.titleMedium.copyWith(color: AppColors.amberDark)),
              const Spacer(),
              if (order.deliveryDistanceM != null)
                Text('±${(order.deliveryDistanceM! / 1000).toStringAsFixed(1)} km', style: AppTextStyles.bodySmall),
            ]),
            if (a != null) ...[
              const SizedBox(height: 6),
              Text('${a.recipientName} • ${a.recipientPhone}', style: AppTextStyles.label),
              Text(a.addressText, style: AppTextStyles.bodyMedium),
              if (a.notes != null) Text(a.notes!, style: AppTextStyles.bodySmall),
            ],
            const SizedBox(height: 6),
            Text(items, style: AppTextStyles.bodySmall),
            Text('Sudah dibayar • ${Formatters.rupiah(order.total)}', style: AppTextStyles.bodySmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              if (a != null) ...[
                OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(a.mapsUrl), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.map_outlined), label: const Text('Peta')),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse('tel:${a.recipientPhone}')),
                  icon: const Icon(Icons.call_outlined), label: const Text('Telepon')),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse('https://wa.me/${waNumber(a.recipientPhone)}'), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.chat_outlined), label: const Text('WA')),
              ],
              ...actions,
            ]),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Rute** — di `app_router.dart` impor `CourierScreen` dan tambahkan di `routes:` tingkat atas:

```dart
      GoRoute(
        path: RouteNames.courierPath,
        name: RouteNames.courier,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const CourierScreen(),
      ),
```

Catatan: link WA kurir dari backend berbentuk `https://rehatflutter.vercel.app/#/courier`. Bila kurir belum login, redirect yang ada membawanya ke login; setelah masuk ia membuka **Profil → Antaran** (Task 11).

- [ ] **Step 3: Analyze & test**

Run: `FLUTTER analyze && FLUTTER test`
Expected: tanpa error; semua PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/delivery/presentation/courier_screen.dart lib/core/router/app_router.dart
git commit -m "feat(delivery): layar Antaran untuk kurir"
```

---

### Task 10: Layar admin Delivery & Kurir

**Files:**
- Create: `lib/features/delivery/presentation/store_settings_screen.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: Layar**

```dart
// lib/features/delivery/presentation/store_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/models/delivery_models.dart';
import '../data/delivery_repository.dart';
import 'widgets/location_picker.dart';

/// Admin: saklar delivery, radius, ongkir, jam buka, dan daftar kurir.
class StoreSettingsScreen extends ConsumerWidget {
  const StoreSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(storeSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery & Kurir')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: TextButton(onPressed: () => ref.invalidate(storeSettingsProvider), child: const Text('Gagal memuat. Coba lagi'))),
        data: (d) => _SettingsForm(settings: d.$1, hours: d.$2),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.settings, required this.hours});
  final StoreSettings settings;
  final List<StoreHour> hours;
  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late bool _enabled = widget.settings.deliveryEnabled;
  late final _radius = TextEditingController(text: '${widget.settings.radiusM}');
  late final _fee = TextEditingController(text: '${widget.settings.deliveryFee}');
  late final _freeMin = TextEditingController(text: '${widget.settings.freeDeliveryMin}');
  late final _cutoff = TextEditingController(text: '${widget.settings.cutoffMinutes}');
  late final _address = TextEditingController(text: widget.settings.storeAddress);
  late LatLng _point = widget.settings.storeLat == null
      ? rehatStoreLatLng
      : LatLng(widget.settings.storeLat!, widget.settings.storeLng!);
  late List<StoreHour> _hours = widget.hours.length == 7
      ? widget.hours
      : [for (var d = 0; d < 7; d++) StoreHour(dayOfWeek: d, openTime: '10:00', closeTime: '00:00')];
  bool _saving = false;

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  bool _validTime(String? t) => t != null && RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(t);

  Future<void> _save() async {
    for (final h in _hours) {
      if (!h.isClosed && (!_validTime(h.openTime) || !_validTime(h.closeTime))) {
        return _toast('Jam ${StoreHour.dayNames[h.dayOfWeek]} harus format JJ:MM (24.00 ditulis 00:00)');
      }
    }
    final s = StoreSettings(
      storeLat: _point.latitude,
      storeLng: _point.longitude,
      storeAddress: _address.text.trim(),
      deliveryEnabled: _enabled,
      radiusM: int.tryParse(_radius.text) ?? widget.settings.radiusM,
      deliveryFee: int.tryParse(_fee.text) ?? widget.settings.deliveryFee,
      freeDeliveryMin: int.tryParse(_freeMin.text) ?? widget.settings.freeDeliveryMin,
      cutoffMinutes: int.tryParse(_cutoff.text) ?? widget.settings.cutoffMinutes,
    );
    setState(() => _saving = true);
    try {
      final repo = ref.read(deliveryRepositoryProvider);
      await repo.updateStoreSettings(s);
      await repo.saveStoreHours(_hours);
      ref.invalidate(storeSettingsProvider);
      ref.invalidate(deliveryConfigProvider);
      _toast('Pengaturan disimpan');
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _num(TextEditingController c, String label) => TextField(
      controller: c, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: label));

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _enabled,
          onChanged: (v) => setState(() => _enabled = v),
          title: Text('Delivery aktif', style: AppTextStyles.titleMedium),
          subtitle: const Text('Matikan untuk menutup delivery sementara.'),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _num(_radius, 'Radius (meter)')),
          const SizedBox(width: 12),
          Expanded(child: _num(_cutoff, 'Batas sebelum tutup (menit)')),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _num(_fee, 'Ongkir (Rp)')),
          const SizedBox(width: 12),
          Expanded(child: _num(_freeMin, 'Gratis ongkir mulai (Rp)')),
        ]),
        const SizedBox(height: 20),
        Text('Titik toko', style: AppTextStyles.titleMedium),
        const SizedBox(height: 8),
        LocationPicker(initial: _point, onChanged: (ll) => setState(() => _point = ll), height: 220),
        const SizedBox(height: 8),
        TextField(controller: _address, decoration: const InputDecoration(labelText: 'Alamat toko')),
        const SizedBox(height: 20),
        Text('Jam buka (WIB)', style: AppTextStyles.titleMedium),
        for (var i = 0; i < _hours.length; i++)
          _HourRow(
            hour: _hours[i],
            onChanged: (h) => setState(() => _hours = [..._hours]..[i] = h),
          ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Menyimpan…' : 'Simpan pengaturan')),
        const SizedBox(height: 28),
        const _CouriersSection(),
      ],
    );
  }
}

class _HourRow extends StatelessWidget {
  const _HourRow({required this.hour, required this.onChanged});
  final StoreHour hour;
  final ValueChanged<StoreHour> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        SizedBox(width: 64, child: Text(StoreHour.dayNames[hour.dayOfWeek])),
        Expanded(
          child: TextFormField(
            initialValue: hour.openTime,
            enabled: !hour.isClosed,
            decoration: const InputDecoration(labelText: 'Buka', hintText: '10:00'),
            onChanged: (v) => onChanged(hour.copyWith(openTime: v.trim())),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            initialValue: hour.closeTime,
            enabled: !hour.isClosed,
            decoration: const InputDecoration(labelText: 'Tutup', hintText: '00:00'),
            onChanged: (v) => onChanged(hour.copyWith(closeTime: v.trim())),
          ),
        ),
        const SizedBox(width: 4),
        Column(children: [
          const Text('Libur', style: TextStyle(fontSize: 12)),
          Switch(value: hour.isClosed, onChanged: (v) => onChanged(hour.copyWith(isClosed: v))),
        ]),
      ]),
    );
  }
}

class _CouriersSection extends ConsumerWidget {
  const _CouriersSection();

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Tambah kurir'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'No. HP akun kurir', helperText: 'Kurir harus sudah daftar di app sebagai pelanggan'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Tambah')),
        ],
      ),
    );
    if (phone == null || phone.isEmpty) return;
    try {
      await ref.read(deliveryRepositoryProvider).addCourier(phone);
      ref.invalidate(couriersProvider);
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, CourierInfo k) async {
    try {
      await ref.read(deliveryRepositoryProvider).removeCourier(k.id);
      ref.invalidate(couriersProvider);
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(couriersProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Kurir', style: AppTextStyles.titleMedium),
          const Spacer(),
          TextButton.icon(onPressed: () => _add(context, ref), icon: const Icon(Icons.person_add_alt_1_outlined), label: const Text('Tambah')),
        ]),
        async.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => const Text('Gagal memuat kurir.'),
          data: (list) => list.isEmpty
              ? const Text('Belum ada kurir.')
              : Column(children: [
                  for (final k in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.circle, size: 12, color: k.onDuty ? Colors.green : Colors.grey),
                      title: Text(k.name.isEmpty ? k.phone : k.name),
                      subtitle: Text('${k.phone} • ${k.onDuty ? 'bertugas' : 'tidak bertugas'}'),
                      trailing: IconButton(icon: const Icon(Icons.person_remove_outlined), onPressed: () => _remove(context, ref, k)),
                    ),
                ]),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Rute** — di `app_router.dart` impor `StoreSettingsScreen` dan tambahkan di `routes:` tingkat atas:

```dart
      GoRoute(
        path: RouteNames.adminStoreSettingsPath,
        name: RouteNames.adminStoreSettings,
        parentNavigatorKey: rootKey,
        builder: (context, state) => const StoreSettingsScreen(),
      ),
```

- [ ] **Step 3: Analyze & test**

Run: `FLUTTER analyze && FLUTTER test`
Expected: tanpa error; semua PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/delivery/presentation/store_settings_screen.dart lib/core/router/app_router.dart
git commit -m "feat(delivery): layar admin Delivery & Kurir (pengaturan, jam buka, kurir)"
```

---

### Task 11: Pintu masuk di Profil

**Files:**
- Modify: `lib/features/profile/presentation/profile_screen.dart`

- [ ] **Step 1: Tile baru**

Di list `account` (baris ±66–85), setelah tile `'Pesanan'` tambahkan:

```dart
          _tile(Icons.location_on_outlined, 'Alamat saya',
              onTap: () => context.pushNamed(RouteNames.addresses)),
          if (user?.isCourier == true)
            _tile(Icons.delivery_dining_rounded, 'Antaran',
                onTap: () => context.pushNamed(RouteNames.courier)),
```

Di list `admin` (baris ±86–108), setelah tile `'Tutup Kasir'` tambahkan:

```dart
            _tile(Icons.delivery_dining_outlined, 'Delivery & Kurir',
                onTap: () => context.pushNamed(RouteNames.adminStoreSettings)),
```

- [ ] **Step 2: Analyze & test**

Run: `FLUTTER analyze && FLUTTER test`
Expected: tanpa error; semua PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/features/profile/presentation/profile_screen.dart
git commit -m "feat(delivery): menu Alamat saya, Antaran (kurir) & Delivery & Kurir (admin) di Profil"
```

---

### Task 12: Verifikasi menyeluruh

- [ ] **Step 1:** `FLUTTER analyze` → tanpa error/warning baru. `FLUTTER test` → semua PASS.
- [ ] **Step 2:** `FLUTTER build web --release --pwa-strategy=none --dart-define=API_BASE_URL=https://rehat-backend-production.up.railway.app/v1` → build sukses (sama dengan CI).
- [ ] **Step 3: Uji manual di Chrome** (`FLUTTER run -d chrome --dart-define=API_BASE_URL=...`), login akun dummy `081200000001`:
  - Profil → **Alamat saya** → tambah alamat dengan pin peta → tersimpan & tampil.
  - Checkout → kartu Delivery **pudar** dengan pesan "Delivery sedang tidak tersedia." (delivery masih mati di produksi).
  - Dine-in/bawa pulang tetap bisa dipilih; **jangan** membuat pesanan.
  - Akun admin → Profil → **Delivery & Kurir** tampil dengan radius 3000, ongkir 5000, gratis mulai 50000, jam 10:00–00:00. **Jangan** menyimpan perubahan.
- [ ] **Step 4:** Laporkan hasil; tunggu persetujuan pemilik untuk rilis.

---

### Task 13: Rilis app — **minta persetujuan pemilik dulu**

Push ke `main` = deploy web produksi (CI: analyze + test → build → Vercel).

```bash
git checkout main
git merge --no-ff feat/delivery-app
git push origin main
```

Cek sekali: `gh run list --repo chooo17/rehatflutter --limit 2` → "Deploy Web (Vercel)" `success`; buka `https://www.rehat-coffeehouse.my.id/preorder` → checkout menampilkan kartu Delivery pudar.

**Setelah rilis (operasional, oleh pemilik/admin):**
1. Kurir daftar akun di app seperti pelanggan → admin: Profil → Delivery & Kurir → **Tambah** (no. HP kurir).
2. Kurir login → Profil → **Antaran** → nyalakan **Saya bertugas**.
3. Admin: Profil → Delivery & Kurir → nyalakan **Delivery aktif** → Simpan.
4. Uji satu pesanan delivery nyata dalam radius 3 km sebelum diumumkan.
