/// Ulasan satu menu (dari `GET /menu/items/:id/reviews`).
class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.rating,
    this.comment = '',
    this.userName = 'Pelanggan',
    this.userAvatarUrl,
    this.createdAt,
  });

  final String id;
  final int rating;
  final String comment;
  final String userName;
  final String? userAvatarUrl;
  final DateTime? createdAt;

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final u = user is Map ? Map<String, dynamic>.from(user) : const {};
    return ReviewModel(
      id: (json['id'] ?? '').toString(),
      rating: _asInt(json['rating']),
      comment: (json['comment'] ?? '').toString(),
      userName: (u['name'] ?? 'Pelanggan').toString(),
      userAvatarUrl: (u['avatar_url'] ?? u['avatarUrl']) as String?,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
