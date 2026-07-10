import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/menu_item_model.dart';

/// Akses data untuk layar beranda (menu unggulan).
class HomeRepository {
  HomeRepository({required DioClient client}) : _client = client;

  final DioClient _client;

  /// Mengambil daftar menu unggulan untuk ditampilkan di beranda.
  Future<List<MenuItemModel>> fetchFeatured() async {
    final res = await _client.get<dynamic>(ApiConstants.featuredMenu);
    return _parseList(res.data);
  }

  List<MenuItemModel> _parseList(dynamic data) {
    // Backend bisa membalas List langsung, atau { data: [...] } / { items: [...] }.
    final list = data is Map
        ? (data['data'] ?? data['items'] ?? data['menu'])
        : data;
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => MenuItemModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }
}

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(client: ref.watch(dioClientProvider));
});

/// Menu unggulan untuk beranda (auto-refresh saat di-invalidate).
final featuredMenuProvider = FutureProvider<List<MenuItemModel>>((ref) {
  return ref.watch(homeRepositoryProvider).fetchFeatured();
});
