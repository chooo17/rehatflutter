import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/core/network/dio_client.dart';
import 'package:rehat_app/core/storage/secure_storage.dart';
import 'package:rehat_app/features/menu/application/menu_sort.dart';
import 'package:rehat_app/features/menu/data/menu_repository.dart';
import 'package:rehat_app/shared/models/menu_item_model.dart';

/// Menghitung berapa kali katalog benar-benar diambil dari backend.
class _FakeMenuRepository extends MenuRepository {
  _FakeMenuRepository() : super(client: DioClient(storage: SecureStorage()));

  int fetchCalls = 0;

  @override
  Future<List<MenuItemModel>> fetchMenu({
    String? categoryId,
    String? query,
    String? sort,
    int page = 1,
    int limit = 100,
    bool includeUnavailable = false,
  }) async {
    fetchCalls++;
    return const [
      MenuItemModel(
          id: 'a', name: 'Kopi Susu', price: 30000, categoryId: 'kopi'),
      MenuItemModel(
          id: 'b', name: 'Kopi Hitam', price: 15000, categoryId: 'kopi'),
      MenuItemModel(
          id: 'c', name: 'Roti Bakar', price: 10000, categoryId: 'makanan'),
    ];
  }
}

void main() {
  late _FakeMenuRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = _FakeMenuRepository();
    container = ProviderContainer(
      overrides: [menuRepositoryProvider.overrideWithValue(repo)],
    );
  });
  tearDown(() => container.dispose());

  Future<List<MenuItemModel>> read() =>
      container.read(menuListProvider.future);

  test('katalog diambil dari backend sekali saja', () async {
    await read();
    await read();
    expect(repo.fetchCalls, 1);
  });

  test('ganti kategori TIDAK menembak backend lagi', () async {
    expect((await read()).length, 3);

    container.read(selectedCategoryProvider.notifier).state = 'kopi';
    final out = await read();

    expect(out.map((e) => e.id), ['a', 'b']);
    expect(repo.fetchCalls, 1);
  });

  test('mengetik pencarian TIDAK menembak backend lagi', () async {
    await read();

    container.read(menuSearchQueryProvider.notifier).state = 'roti';
    final out = await read();

    expect(out.map((e) => e.id), ['c']);
    expect(repo.fetchCalls, 1);
  });

  test('ganti urutan TIDAK menembak backend lagi', () async {
    await read();

    container.read(menuSortProvider.notifier).state = MenuSort.priceAsc;
    final out = await read();

    expect(out.map((e) => e.id), ['c', 'b', 'a']);
    expect(repo.fetchCalls, 1);
  });

  test('invalidate katalog memaksa ambil ulang (untuk tarik-segarkan)',
      () async {
    await read();
    container.invalidate(menuCatalogProvider);
    await read();
    expect(repo.fetchCalls, 2);
  });
}
