import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/menu_item_model.dart';
import '../data/favorites_repository.dart';

/// Menyimpan daftar menu favorit & menangani toggle dengan pembaruan optimistis.
class FavoritesController extends AsyncNotifier<List<MenuItemModel>> {
  @override
  Future<List<MenuItemModel>> build() {
    return ref.watch(favoritesRepositoryProvider).fetchFavorites();
  }

  bool isFavorite(String menuItemId) {
    return state.value?.any((e) => e.id == menuItemId) ?? false;
  }

  /// Menambah/menghapus favorit. Mengubah state dulu (optimistis), lalu
  /// memanggil server; bila gagal, dikembalikan seperti semula.
  Future<void> toggle(MenuItemModel item) async {
    final current = state.value ?? const [];
    final exists = current.any((e) => e.id == item.id);
    final repo = ref.read(favoritesRepositoryProvider);

    // Optimistis.
    state = AsyncData(
      exists
          ? current.where((e) => e.id != item.id).toList()
          : [item, ...current],
    );

    try {
      if (exists) {
        await repo.remove(item.id);
      } else {
        await repo.add(item.id);
      }
    } catch (_) {
      // Rollback.
      state = AsyncData(current);
      rethrow;
    }
  }
}

final favoritesControllerProvider =
    AsyncNotifierProvider<FavoritesController, List<MenuItemModel>>(
        FavoritesController.new);

/// Himpunan id menu yang difavoritkan — untuk status ikon hati.
final favoriteIdsProvider = Provider<Set<String>>((ref) {
  final async = ref.watch(favoritesControllerProvider);
  return async.maybeWhen(
    data: (list) => list.map((e) => e.id).toSet(),
    orElse: () => const <String>{},
  );
});
