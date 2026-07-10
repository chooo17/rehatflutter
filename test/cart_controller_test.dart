import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/features/menu/application/cart_controller.dart';
import 'package:rehat_app/shared/models/menu_item_model.dart';

MenuItemModel _item(String id, int price) =>
    MenuItemModel(id: id, name: 'Item $id', price: price);

void main() {
  late ProviderContainer container;
  CartController cart() => container.read(cartControllerProvider.notifier);

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('keranjang awalnya kosong', () {
    expect(container.read(cartControllerProvider), isEmpty);
    expect(container.read(cartCountProvider), 0);
    expect(container.read(cartTotalProvider), 0);
  });

  test('menambah item + harga & jumlah terhitung benar', () {
    cart().add(_item('a', 20000), size: 'regular', quantity: 2);
    expect(container.read(cartControllerProvider).length, 1);
    expect(container.read(cartCountProvider), 2);
    expect(container.read(cartTotalProvider), 40000);
  });

  test('item + kustomisasi sama digabung (jumlah bertambah)', () {
    cart().add(_item('a', 20000), size: 'regular', temperature: 'iced');
    cart().add(_item('a', 20000), size: 'regular', temperature: 'iced');
    expect(container.read(cartControllerProvider).length, 1);
    expect(container.read(cartCountProvider), 2);
  });

  test('kustomisasi berbeda menjadi baris terpisah', () {
    cart().add(_item('a', 20000), size: 'small');
    cart().add(_item('a', 20000), size: 'large');
    expect(container.read(cartControllerProvider).length, 2);
  });

  test('increment/decrement/remove', () {
    cart().add(_item('a', 10000), size: 'regular');
    final id = container.read(cartControllerProvider).first.lineId;

    cart().increment(id);
    expect(container.read(cartCountProvider), 2);

    cart().decrement(id);
    expect(container.read(cartCountProvider), 1);

    // decrement sampai 0 menghapus baris.
    cart().decrement(id);
    expect(container.read(cartControllerProvider), isEmpty);
  });

  test('clear mengosongkan keranjang', () {
    cart().add(_item('a', 10000));
    cart().add(_item('b', 15000));
    expect(container.read(cartTotalProvider), 25000);
    cart().clear();
    expect(container.read(cartControllerProvider), isEmpty);
  });

  test('harga pakai harga dasar (ukuran tidak menambah harga)', () {
    cart().add(_item('a', 18000), size: 'large', quantity: 3);
    expect(container.read(cartTotalProvider), 54000);
  });
}
