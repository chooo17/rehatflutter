import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/menu_category_model.dart';
import '../../../shared/models/menu_item_model.dart';
import '../application/menu_sort.dart';

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
    int limit = 100,
    bool includeUnavailable = false,
  }) async {
    final params = <String, dynamic>{'limit': limit.toString()};
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

/// Daftar menu sesuai kategori, pencarian & pengurutan aktif.
final menuListProvider = FutureProvider<List<MenuItemModel>>((ref) async {
  final categoryId = ref.watch(selectedCategoryProvider);
  final query = ref.watch(menuSearchQueryProvider);
  final sort = ref.watch(menuSortProvider);
  return ref.watch(menuRepositoryProvider).fetchMenu(
        categoryId: categoryId,
        query: query,
        sort: sort.apiValue,
      );
});

/// Detail satu item menu berdasarkan id.
final menuDetailProvider =
    FutureProvider.family<MenuItemModel, String>((ref, id) async {
  return ref.watch(menuRepositoryProvider).fetchDetail(id);
});

/// Semua item menu tanpa filter (untuk panel admin gambar menu).
/// Sertakan item "Habis" & naikkan limit agar seluruh katalog bisa dikelola.
final allMenuItemsProvider = FutureProvider<List<MenuItemModel>>((ref) {
  return ref
      .watch(menuRepositoryProvider)
      .fetchMenu(limit: 500, includeUnavailable: true);
});
