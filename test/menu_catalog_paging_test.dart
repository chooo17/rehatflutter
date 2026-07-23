import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/core/network/dio_client.dart';
import 'package:rehat_app/core/storage/secure_storage.dart';
import 'package:rehat_app/features/menu/data/menu_repository.dart';
import 'package:rehat_app/shared/models/menu_item_model.dart';

/// Repository palsu dengan katalog SEBESAR APA PUN, dipotong per halaman
/// persis seperti backend (`.range(offset, offset + limit - 1)`).
class _PagingMenuRepository extends MenuRepository {
  _PagingMenuRepository(this.totalItems)
      : super(client: DioClient(storage: SecureStorage()));

  final int totalItems;
  final List<int> requestedPages = [];
  bool includeUnavailableSeen = false;

  @override
  Future<List<MenuItemModel>> fetchMenu({
    String? categoryId,
    String? query,
    String? sort,
    int page = 1,
    int limit = 100,
    bool includeUnavailable = false,
  }) async {
    requestedPages.add(page);
    if (includeUnavailable) includeUnavailableSeen = true;
    final start = (page - 1) * limit;
    if (start >= totalItems) return const [];
    final end = (start + limit) > totalItems ? totalItems : start + limit;
    return [
      for (var i = start; i < end; i++)
        MenuItemModel(id: 'm$i', name: 'Item $i', price: 10000),
    ];
  }
}

void main() {
  late _PagingMenuRepository repo;
  late ProviderContainer container;

  void build(int totalItems) {
    repo = _PagingMenuRepository(totalItems);
    container = ProviderContainer(
      overrides: [menuRepositoryProvider.overrideWithValue(repo)],
    );
  }

  tearDown(() => container.dispose());

  Future<List<MenuItemModel>> catalog() =>
      container.read(menuCatalogProvider.future);

  test('katalog kecil: satu permintaan saja', () async {
    build(40);

    final items = await catalog();

    expect(items.length, 40);
    expect(repo.requestedPages, [1]);
  });

  test('katalog besar TIDAK terpotong diam-diam', () async {
    build(450);

    final items = await catalog();

    expect(items.length, 450);
    expect(items.map((e) => e.id), contains('m449'));
  });

  test('berhenti begitu halaman tidak penuh', () async {
    build(450);

    await catalog();

    // 200 + 200 + 50 -> berhenti di halaman 3, tidak meminta halaman 4.
    expect(repo.requestedPages, [1, 2, 3]);
  });

  test('katalog pas sebesar satu halaman tetap mengambil halaman berikutnya',
      () async {
    build(200);

    final items = await catalog();

    // Halaman pertama penuh, jadi harus dipastikan tidak ada lanjutannya.
    expect(items.length, 200);
    expect(repo.requestedPages, [1, 2]);
  });

  test('panel admin juga menarik seluruh katalog, termasuk item habis',
      () async {
    build(450);

    final items = await container.read(allMenuItemsProvider.future);

    expect(items.length, 450);
    expect(repo.includeUnavailableSeen, isTrue);
  });

  test('ada batas aman supaya tidak memutar tanpa henti', () async {
    build(1000000);

    final items = await catalog();

    expect(repo.requestedPages.length, lessThanOrEqualTo(10));
    expect(items.length, lessThanOrEqualTo(2000));
  });
}
