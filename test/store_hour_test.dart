import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/shared/models/delivery_models.dart';

void main() {
  test('StoreHour.fromJson memangkas detik dari jam', () {
    final h = StoreHour.fromJson({
      'day_of_week': 1,
      'open_time': '10:00:00',
      'close_time': '00:00:00',
      'is_closed': false,
    });
    expect(h.openTime, '10:00');
    expect(h.closeTime, '00:00');
    expect(h.dayOfWeek, 1);
  });

  test('StoreHour toJson round-trip', () {
    const h = StoreHour(dayOfWeek: 3, openTime: '09:30', closeTime: '22:00', isClosed: true);
    final back = StoreHour.fromJson(h.toJson());
    expect(back.dayOfWeek, 3);
    expect(back.openTime, '09:30');
    expect(back.closeTime, '22:00');
    expect(back.isClosed, true);
  });

  test('StoreHour.copyWith mempertahankan dayOfWeek', () {
    const h = StoreHour(dayOfWeek: 5, openTime: '10:00', closeTime: '00:00');
    final c = h.copyWith(openTime: '11:00', isClosed: true);
    expect(c.dayOfWeek, 5);
    expect(c.openTime, '11:00');
    expect(c.closeTime, '00:00');
    expect(c.isClosed, true);
  });

  test('StoreSettings.toJson tanpa store_lat/lng bila null', () {
    const s = StoreSettings(
      storeAddress: 'Jl. Contoh',
      deliveryEnabled: true,
      radiusM: 3000,
      deliveryFee: 5000,
      freeDeliveryMin: 50000,
      cutoffMinutes: 30,
    );
    final j = s.toJson();
    expect(j.containsKey('store_lat'), false);
    expect(j.containsKey('store_lng'), false);
    expect(j['delivery_radius_m'], 3000);
  });
}
