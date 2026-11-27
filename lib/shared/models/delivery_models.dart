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
