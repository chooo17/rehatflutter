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
