import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/menu_category_model.dart';
import '../../../shared/models/menu_item_model.dart';
import '../application/menu_sort.dart';
import 'menu_query.dart';

/// Akses data katalog menu.
class MenuRepository {
  MenuRepository({required DioClient client}) : _client = client;

  final DioClient _client;

  /// Mengambil daftar menu, opsional difilter [categoryId] (UUID) & [query],
  /// serta diurutkan [sort] (`sort_order`/`price_asc`/`price_desc`/`rating`).
  ///
  /// [limit] menaikkan batas item per halaman (default backend hanya 20 → item
  /// ke-21 dst. tak muncul). [includeUnavailable] menyertakan item "Habis"
  /// (default backend hanya mengembalikan yang tersedia).
  Future<List<MenuItemModel>> fetchMenu({
    String? categoryId,
    String? query,
    String? sort,
    int page = 1,
    int limit = 100,
    bool includeUnavailable = false,
  }) async {
    final params = <String, dynamic>{
      'limit': limit.toString(),
      'page': page.toString(),
    };
    if (includeUnavailable) params['available_only'] = 'false';
    if (categoryId != null && categoryId.isNotEmpty) {
      params['category_id'] = categoryId;
    }
    if (query != null && query.isNotEmpty) {
      params['search'] = query;
    }
    if (sort != null && sort.isNotEmpty && sort != 'sort_order') {
      params['sort'] = sort;
    }
    final res = await _client.get<dynamic>(
      ApiConstants.menu,
      query: params.isEmpty ? null : params,
    );
    return _parseList(res.data);
  }

  /// Mengambil daftar kategori menu.
  Future<List<MenuCategory>> fetchCategories() async {
    final res = await _client.get<dynamic>(ApiConstants.menuCategories);
    final data = res.data;
    final list = data is Map ? (data['data'] ?? data['categories']) : data;
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => MenuCategory.fromJson(Map<String, dynamic>.from(e)))
          .where((c) => c.name.isNotEmpty)
          .toList();
    }
    return const [];
  }

  Future<MenuItemModel> fetchDetail(String id) async {
    final res = await _client.get<dynamic>(ApiConstants.menuDetail(id));
    final data = res.data;
    final json = data is Map
        ? (data['data'] ?? data['item'] ?? data['menu'] ?? data)
        : data;
    return MenuItemModel.fromJson(Map<String, dynamic>.from(json as Map));
  }

  /// (Admin) Mengunggah / mengganti gambar satu menu. Mengembalikan URL baru.
  Future<String> uploadItemImage({
    required String itemId,
    required List<int> bytes,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _client.put<dynamic>(
      ApiConstants.menuItemImage(itemId),
      data: form,
    );
    final data = res.data;
    final inner = data is Map ? (data['data'] ?? data) : const {};
    final url = (inner is Map ? inner['image_url'] : null)?.toString();
    if (url == null || url.isEmpty) {
      throw Exception('URL gambar tidak ditemukan pada respons.');
    }
    return url;
  }

  /// (Admin) Perbarui field menu (`PATCH /menu/items/:id`). Kirim yang diubah saja.
  Future<void> updateItem(
    String itemId, {
    String? name,
    String? description,
    String? categoryId,
    int? costPrice,
    int? price,
    int? sortOrder,
    bool? isAvailable,
    bool? isFeatured,
  }) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (categoryId != null) 'category_id': categoryId,
      if (costPrice != null) 'cost_price': costPrice,
      if (price != null) 'price': price,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isAvailable != null) 'is_available': isAvailable,
      if (isFeatured != null) 'is_featured': isFeatured,
    };
    if (body.isEmpty) return;
    await _client.patch<dynamic>(ApiConstants.menuItemUpdate(itemId), data: body);
  }

  /// (Admin) Buat menu baru (`POST /menu/items`). `name`/`categoryId`/`price` wajib.
  Future<void> createItem({
    required String name,
    required String categoryId,
    required int price,
    int costPrice = 0,
    String? description,
    int sortOrder = 0,
    bool isAvailable = true,
    bool isFeatured = false,
  }) async {
    await _client.post<dynamic>(ApiConstants.menu, data: {
      'name': name,
      'category_id': categoryId,
      'price': price,
      'cost_price': costPrice,
      if (description != null && description.isNotEmpty) 'description': description,
      'sort_order': sortOrder,
      'is_available': isAvailable,
      'is_featured': isFeatured,
    });
  }

  List<MenuItemModel> _parseList(dynamic data) {
    final list =
        data is Map ? (data['data'] ?? data['items'] ?? data['menu']) : data;
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => MenuItemModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }
}

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return MenuRepository(client: ref.watch(dioClientProvider));
});

/// Id kategori aktif di layar menu ('' = Semua / tanpa filter).
final selectedCategoryProvider = StateProvider<String>((ref) => '');

/// Kata kunci pencarian di layar menu.
final menuSearchQueryProvider = StateProvider<String>((ref) => '');

/// Pengurutan aktif di layar menu.
final menuSortProvider = StateProvider<MenuSort>((ref) => MenuSort.recommended);

/// Daftar kategori (selalu diawali "Semua").
final menuCategoriesProvider = FutureProvider<List<MenuCategory>>((ref) async {
  final categories = await ref.watch(menuRepositoryProvider).fetchCategories();
  return [MenuCategory.all, ...categories];
});

/// Katalog MENTAH — seluruh menu tersedia, urut `sort_order` dari backend.
///
/// Diambil SEKALI lalu dipakai ulang; penyaringan kategori/pencarian/urutan
/// dilakukan di perangkat oleh [menuListProvider]. `invalidate` provider ini
/// untuk memaksa ambil ulang (mis. tarik-untuk-segarkan).
/// Ukuran halaman saat menarik katalog. Backend memotong dengan
/// `.range(offset, offset + limit - 1)`, jadi satu permintaan TIDAK PERNAH
/// mengembalikan lebih dari ini.
const _catalogPageSize = 200;

/// Batas aman: kalau backend selalu mengembalikan halaman penuh (mis. bug
/// paginasi), berhenti daripada memutar tanpa henti.
const _catalogMaxPages = 10;

/// Menarik SELURUH katalog per halaman sampai halaman tidak penuh.
///
/// Sebelumnya katalog diambil dengan satu permintaan ber-`limit`; begitu isi
/// menu melewati batas itu, sisanya hilang DIAM-DIAM tanpa error apa pun.
Future<List<MenuItemModel>> _fetchAllPages(
  MenuRepository repo, {
  bool includeUnavailable = false,
}) async {
  final all = <MenuItemModel>[];
  for (var page = 1; page <= _catalogMaxPages; page++) {
    final batch = await repo.fetchMenu(
      page: page,
      limit: _catalogPageSize,
      includeUnavailable: includeUnavailable,
    );
    all.addAll(batch);
    if (batch.length < _catalogPageSize) break;
  }
  return all;
}

final menuCatalogProvider = FutureProvider<List<MenuItemModel>>((ref) async {
  return _fetchAllPages(ref.watch(menuRepositoryProvider));
});

/// Daftar menu sesuai kategori, pencarian & pengurutan aktif.
///
/// Turunan MURNI dari [menuCatalogProvider] — mengganti filter tidak menembak
/// backend sama sekali.
final menuListProvider = FutureProvider<List<MenuItemModel>>((ref) async {
  final catalog = await ref.watch(menuCatalogProvider.future);
  return applyMenuQuery(
    catalog,
    categoryId: ref.watch(selectedCategoryProvider),
    query: ref.watch(menuSearchQueryProvider),
    sort: ref.watch(menuSortProvider),
  );
});

/// Detail satu item menu berdasarkan id.
final menuDetailProvider =
    FutureProvider.family<MenuItemModel, String>((ref, id) async {
  return ref.watch(menuRepositoryProvider).fetchDetail(id);
});

/// Semua item menu tanpa filter (untuk panel admin gambar/HPP).
/// Sertakan item "Habis"; ditarik per halaman agar katalog sebesar apa pun
/// bisa dikelola (dulu satu permintaan `limit: 500` — item ke-501 dst. tak
/// pernah muncul di panel admin).
/// autoDispose: dilepas saat keluar layar admin (data segar tiap masuk).
final allMenuItemsProvider =
    FutureProvider.autoDispose<List<MenuItemModel>>((ref) {
  return _fetchAllPages(ref.watch(menuRepositoryProvider),
      includeUnavailable: true);
});
