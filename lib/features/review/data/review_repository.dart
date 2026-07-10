import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/review_model.dart';

/// Akses data ulasan menu.
class ReviewRepository {
  ReviewRepository({required DioClient client}) : _client = client;

  final DioClient _client;

  /// Mengirim ulasan untuk satu item dalam pesanan yang sudah selesai.
  Future<void> submitReview({
    required String menuItemId,
    required String orderId,
    required int rating,
    String? comment,
  }) async {
    await _client.post<dynamic>(
      ApiConstants.reviews,
      data: {
        'menu_item_id': menuItemId,
        'order_id': orderId,
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
    );
  }

  /// Mengambil ulasan untuk satu menu.
  Future<List<ReviewModel>> fetchForItem(String menuItemId,
      {String sort = 'recent'}) async {
    final res = await _client.get<dynamic>(
      ApiConstants.menuItemReviews(menuItemId),
      query: {'sort': sort},
    );
    final data = res.data;
    final list = data is Map ? (data['data'] ?? data['reviews']) : data;
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => ReviewModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }
}

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(client: ref.watch(dioClientProvider));
});

/// Ulasan untuk satu menu (berdasarkan id).
final itemReviewsProvider =
    FutureProvider.family<List<ReviewModel>, String>((ref, id) {
  return ref.watch(reviewRepositoryProvider).fetchForItem(id);
});
