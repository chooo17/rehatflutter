import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/features/menu/application/menu_sort.dart';
import 'package:rehat_app/features/menu/data/menu_query.dart';
import 'package:rehat_app/shared/models/menu_item_model.dart';

MenuItemModel _item(
  String id, {
  String name = 'Kopi',
  String description = '',
  int price = 20000,
  String categoryId = 'c1',
  double? rating,
}) =>
    MenuItemModel(
      id: id,
      name: name,
      description: description,
      price: price,
      categoryId: categoryId,
      rating: rating,
    );

void main() {
  group('MenuItemModel.fromJson — categoryId', () {
    test('membaca kolom category_id langsung', () {
      final m = MenuItemModel.fromJson({
        'id': 'm1',
        'name': 'Latte',
        'price': 22000,
        'category_id': 'cat-kopi',
      });
      expect(m.categoryId, 'cat-kopi');
    });

    test('jatuh ke id di objek category bila kolom tak ada', () {
      final m = MenuItemModel.fromJson({
        'id': 'm1',
        'name': 'Latte',
        'price': 22000,
        'category': {'id': 'cat-kopi', 'name': 'Kopi'},
      });
      expect(m.categoryId, 'cat-kopi');
      // Nama kategori tetap terbaca seperti sebelumnya.
      expect(m.category, 'Kopi');
    });

    test('kosong bila backend tak mengirim kategori sama sekali', () {
      final m = MenuItemModel.fromJson({'id': 'm1', 'name': 'Latte'});
      expect(m.categoryId, '');
    });
  });

  group('applyMenuQuery — filter kategori', () {
    final items = [
      _item('a', categoryId: 'kopi'),
      _item('b', categoryId: 'makanan'),
      _item('c', categoryId: 'kopi'),
    ];

    test('kategori kosong berarti SEMUA', () {
      final out = applyMenuQuery(items, categoryId: '');
      expect(out.map((e) => e.id), ['a', 'b', 'c']);
    });

    test('menyaring sesuai categoryId', () {
      final out = applyMenuQuery(items, categoryId: 'kopi');
      expect(out.map((e) => e.id), ['a', 'c']);
    });
  });

  group('applyMenuQuery — pencarian', () {
    final items = [
      _item('a', name: 'Kopi Susu', description: 'manis'),
      _item('b', name: 'Teh Tarik', description: 'gurih dan kopi-ish'),
      _item('c', name: 'Roti Bakar', description: 'cokelat'),
    ];

    test('mencocokkan nama tanpa peduli huruf besar/kecil', () {
      final out = applyMenuQuery(items, query: 'kOpI sUsU');
      expect(out.map((e) => e.id), ['a']);
    });

    test('mencocokkan deskripsi juga (seperti ilike OR di backend)', () {
      final out = applyMenuQuery(items, query: 'kopi');
      expect(out.map((e) => e.id), ['a', 'b']);
    });

    test('spasi di tepi diabaikan', () {
      final out = applyMenuQuery(items, query: '  roti  ');
      expect(out.map((e) => e.id), ['c']);
    });

    test('tanpa kecocokan mengembalikan daftar kosong', () {
      expect(applyMenuQuery(items, query: 'zzz'), isEmpty);
    });
  });

  group('applyMenuQuery — pengurutan', () {
    final items = [
      _item('a', price: 30000, rating: 4.0),
      _item('b', price: 10000, rating: null),
      _item('c', price: 20000, rating: 4.8),
    ];

    test('recommended mempertahankan urutan dari backend (sort_order)', () {
      final out = applyMenuQuery(items, sort: MenuSort.recommended);
      expect(out.map((e) => e.id), ['a', 'b', 'c']);
    });

    test('priceAsc mengurutkan harga menaik', () {
      final out = applyMenuQuery(items, sort: MenuSort.priceAsc);
      expect(out.map((e) => e.id), ['b', 'c', 'a']);
    });

    test('priceDesc mengurutkan harga menurun', () {
      final out = applyMenuQuery(items, sort: MenuSort.priceDesc);
      expect(out.map((e) => e.id), ['a', 'c', 'b']);
    });

    test('rating tertinggi dulu, item tanpa rating di BELAKANG', () {
      final out = applyMenuQuery(items, sort: MenuSort.rating);
      expect(out.map((e) => e.id), ['c', 'a', 'b']);
    });

    test('tidak mengubah daftar sumber', () {
      final source = [...items];
      applyMenuQuery(source, sort: MenuSort.priceAsc);
      expect(source.map((e) => e.id), ['a', 'b', 'c']);
    });
  });

  test('filter, pencarian, dan urutan digabung', () {
    final items = [
      _item('a', name: 'Kopi Susu', categoryId: 'kopi', price: 30000),
      _item('b', name: 'Kopi Hitam', categoryId: 'kopi', price: 15000),
      _item('c', name: 'Kopi Roti', categoryId: 'makanan', price: 10000),
    ];

    final out = applyMenuQuery(
      items,
      categoryId: 'kopi',
      query: 'kopi',
      sort: MenuSort.priceAsc,
    );

    expect(out.map((e) => e.id), ['b', 'a']);
  });
}
