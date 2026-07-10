import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/core/utils/customization_labels.dart';
import 'package:rehat_app/shared/models/menu_item_model.dart';
import 'package:rehat_app/shared/models/order_model.dart';
import 'package:rehat_app/shared/models/user_model.dart';
import 'package:rehat_app/shared/models/voucher_model.dart';

void main() {
  group('UserModel.fromJson', () {
    test('memetakan field backend (loyalty_points, stamp_count)', () {
      final u = UserModel.fromJson({
        'id': 'u1',
        'name': 'Irur',
        'phone': '08123',
        'loyalty_points': 120,
        'stamp_count': 3,
        'tier': 'silver',
      });
      expect(u.points, 120);
      expect(u.stamps, 3);
      expect(u.tier, 'silver');
      // is_profile_complete diturunkan dari ada-nya nama.
      expect(u.isProfileComplete, isTrue);
    });

    test('profil belum lengkap saat nama kosong', () {
      final u = UserModel.fromJson({'id': 'u1', 'phone': '08123'});
      expect(u.isProfileComplete, isFalse);
    });
  });

  group('MenuItemModel.fromJson', () {
    test('kategori sebagai objek + avg_rating + options', () {
      final m = MenuItemModel.fromJson({
        'id': 'm1',
        'name': 'Matcha Latte',
        'price': 30000,
        'avg_rating': 4.7,
        'category': {'id': 'c1', 'name': 'Non-Kopi'},
        'options': {
          'sizes': ['small', 'regular', 'large'],
          'sugar_levels': [0, 50, 100],
          'temperatures': ['hot', 'iced'],
        },
      });
      expect(m.category, 'Non-Kopi');
      expect(m.rating, 4.7);
      expect(m.options.sizes, ['small', 'regular', 'large']);
      expect(m.options.sugarLevels, [0, 50, 100]);
      expect(m.options.temperatures, ['hot', 'iced']);
    });

    test('kategori dari menu_categories (featured)', () {
      final m = MenuItemModel.fromJson({
        'id': 'm2',
        'name': 'Espresso',
        'price': 18000,
        'menu_categories': {'name': 'Kopi'},
      });
      expect(m.category, 'Kopi');
    });
  });

  group('OrderModel & status', () {
    test('riwayat: queue_number, item_count, items_summary, ordered_at', () {
      final o = OrderModel.fromJson({
        'id': 'o1',
        'queue_number': 'A-3',
        'status': 'preparing',
        'total': 60000,
        'item_count': 2,
        'items_summary': 'Espresso, Matcha Latte',
        'ordered_at': '2026-06-29T10:00:00Z',
      });
      expect(o.queueNumber, 'A-3');
      expect(o.itemCount, 2);
      expect(o.status, OrderStatus.preparing);
    });

    test('status fallback ke pending untuk nilai tak dikenal', () {
      expect(OrderStatus.fromString('blah'), OrderStatus.pending);
      expect(OrderStatus.fromString('completed'), OrderStatus.completed);
    });

    test('OrderItem membaca customization', () {
      final i = OrderItemModel.fromJson({
        'name': 'Latte',
        'quantity': 2,
        'unit_price': 25000,
        'customization': {'size': 'large', 'sugar_level': 50, 'temperature': 'iced'},
      });
      expect(i.subtotal, 50000);
      expect(i.size, 'large');
      expect(i.customizationSummary, 'Large · Dingin · Gula 50%');
    });
  });

  group('VoucherModel', () {
    test('usable bila belum dipakai & belum kedaluwarsa', () {
      final v = VoucherModel.fromJson({
        'id': 'v1',
        'code': 'REHAT-10OFF-ABC',
        'discount_pct': 10,
        'source': 'spin',
        'is_used': false,
        'expires_at':
            DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      });
      expect(v.isUsable, isTrue);
      expect(v.valueLabel, '10%');
      expect(v.sourceLabel, 'Hadiah Spin');
    });

    test('tidak usable bila kedaluwarsa', () {
      final v = VoucherModel.fromJson({
        'id': 'v2',
        'code': 'X',
        'discount_pct': 5,
        'expires_at':
            DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      });
      expect(v.isExpired, isTrue);
      expect(v.isUsable, isFalse);
    });
  });

  group('CustomizationLabels', () {
    test('label Bahasa Indonesia', () {
      expect(CustomizationLabels.size('regular'), 'Reguler');
      expect(CustomizationLabels.temperature('iced'), 'Dingin');
      expect(CustomizationLabels.sugar(0), 'Tanpa gula');
      expect(CustomizationLabels.sugar(50), 'Gula 50%');
    });

    test('ringkasan gabungan', () {
      expect(
        CustomizationLabels.summary(size: 'small', temperature: 'hot', sugarLevel: 25),
        'Small · Panas · Gula 25%',
      );
    });
  });
}
