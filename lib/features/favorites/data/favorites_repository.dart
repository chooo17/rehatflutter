import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/menu_item_model.dart';

/// Akses data menu favorit pengguna.
class FavoritesRepository {
  FavoritesRepository({required DioClient client}) : _client = client;

  final DioClient _client;

  /// Daftar item menu yang difavoritkan (bentuk sama seperti katalog menu).
  Future<List<MenuItemModel>> fetchFavorites() async {
    final res = await _client.get<dynamic>(ApiConstants.favorites);
    final data = res.data;
    final list = data is Map ? (data['data'] ?? data['favorites']) : data;
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => MenuItemModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  Future<void> add(String menuItemId) async {
    await _client.post<dynamic>(ApiConstants.favorite(menuItemId));
  }

  Future<void> remove(String menuItemId) async {
    await _client.delete<dynamic>(ApiConstants.favorite(menuItemId));
  }
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepository(client: ref.watch(dioClientProvider));
});
