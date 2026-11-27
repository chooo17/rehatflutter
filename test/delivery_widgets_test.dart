import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/features/delivery/presentation/widgets/delivery_info_card.dart';
import 'package:rehat_app/shared/models/delivery_models.dart';
import 'package:rehat_app/shared/models/order_model.dart';

void main() {
  testWidgets('DeliveryInfoCard menampilkan status, kurir & alamat', (tester) async {
    final order = OrderModel(
      id: 'o1',
      queueNumber: 'A-1',
      total: 50000,
      status: OrderStatus.paid,
      createdAt: DateTime(2026, 11, 27),
      orderType: OrderType.delivery,
      deliveryStatus: DeliveryStatus.assigned,
      courierName: 'Budi',
      courierPhone: '08123456789',
      deliveryAddress: const AddressModel(
        label: 'Rumah',
        addressText: 'Jl. Mawar No. 5',
        recipientName: 'Sari',
        recipientPhone: '0811111',
        lat: -7.0,
        lng: 110.0,
      ),
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DeliveryInfoCard(order: order))));
    expect(find.text(DeliveryStatus.assigned.label), findsOneWidget);
    expect(find.text('Kurir: Budi'), findsOneWidget);
    expect(find.text('Jl. Mawar No. 5'), findsOneWidget);
  });

  test('waNumber menormalkan nomor', () {
    expect(waNumber('08123456'), '628123456');
    expect(waNumber('+62 812'), '62812');
    expect(waNumber('0812-3456'), '628123456');
  });
}
