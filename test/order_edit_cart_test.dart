import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/features/order/application/order_edit_cart.dart';

/// Menguji logika keranjang edit pesanan tersimpan: tambah/dedup, +/- jumlah,
/// hapus, hitung total, dan konversi payload.

EditLine _line(String id, {int price = 10000, int qty = 1, String opt = ''}) =>
    EditLine(
        menuItemId: id, name: 'Item $id', unitPrice: price, quantity: qty,
        optionSummary: opt);

void main() {
  group('total & isEmpty', () {
    test('total = jumlah subtotal', () {
      final cart = OrderEditCart([
        _line('a', price: 10000, qty: 2), // 20000
        _line('b', price: 15000, qty: 1), // 15000
      ]);
      expect(cart.total, 35000);
      expect(cart.isEmpty, isFalse);
    });

    test('kosong → isEmpty true & total 0', () {
      final cart = OrderEditCart([]);
      expect(cart.isEmpty, isTrue);
      expect(cart.total, 0);
    });
  });

  group('inc / dec', () {
    test('inc menaikkan jumlah & total', () {
      final cart = OrderEditCart([_line('a', price: 10000, qty: 1)]);
      cart.inc(cart.lines.first);
      expect(cart.lines.first.quantity, 2);
      expect(cart.total, 20000);
    });

    test('dec dari 2 → 1 (baris tetap ada)', () {
      final cart = OrderEditCart([_line('a', qty: 2)]);
      cart.dec(cart.lines.first);
      expect(cart.lines.length, 1);
      expect(cart.lines.first.quantity, 1);
    });

    test('dec dari 1 → baris terhapus', () {
      final cart = OrderEditCart([_line('a', qty: 1), _line('b', qty: 1)]);
      cart.dec(cart.lines.first);
      expect(cart.lines.map((l) => l.menuItemId), ['b']);
    });
  });

  test('remove menghapus baris', () {
    final cart = OrderEditCart([_line('a'), _line('b')]);
    cart.remove(cart.lines.first);
    expect(cart.lines.map((l) => l.menuItemId), ['b']);
  });

  group('addMenu', () {
    test('menu baru → baris baru qty 1', () {
      final cart = OrderEditCart([]);
      cart.addMenu(menuItemId: 'x', name: 'Kopi', unitPrice: 18000);
      expect(cart.lines.length, 1);
      expect(cart.lines.first.quantity, 1);
      expect(cart.total, 18000);
    });

    test('menu sama tanpa opsi → naikkan jumlah (tak duplikat)', () {
      final cart = OrderEditCart([_line('x', price: 18000, qty: 1)]);
      cart.addMenu(menuItemId: 'x', name: 'Item x', unitPrice: 18000);
      expect(cart.lines.length, 1);
      expect(cart.lines.first.quantity, 2);
    });

    test('menu sama TAPI baris lama beropsi → baris baru terpisah', () {
      final cart = OrderEditCart([_line('x', price: 18000, qty: 1, opt: 'Large')]);
      cart.addMenu(menuItemId: 'x', name: 'Item x', unitPrice: 18000);
      expect(cart.lines.length, 2);
    });
  });

  group('toItems', () {
    test('memetakan id/jumlah/customization', () {
      final cart = OrderEditCart([
        EditLine(
            menuItemId: 'a',
            name: 'A',
            unitPrice: 10000,
            quantity: 3,
            customization: {'size': 'Large'}),
      ]);
      final items = cart.toItems();
      expect(items.length, 1);
      expect(items.first.menuItemId, 'a');
      expect(items.first.quantity, 3);
      expect(items.first.customization, {'size': 'Large'});
    });
  });
}
