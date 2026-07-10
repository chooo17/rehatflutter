/// Ringkasan loyalitas pengguna (dari `GET /loyalty`).
///
/// Backend: `{ points, tier, stamp_count, stamps_to_free, next_tier,
/// points_to_next, lifetime_orders, tier_thresholds }`.
class LoyaltySummary {
  const LoyaltySummary({
    this.points = 0,
    this.stamps = 0,
    this.stampTarget = 9,
    this.stampsToReward = 9,
    this.tier = 'bronze',
    this.nextTier,
    this.pointsToNext = 0,
    this.lifetimeOrders = 0,
  });

  final int points;

  /// Jumlah stamp terkumpul (backend: `stamp_count`).
  final int stamps;

  /// Jumlah stamp untuk 1 kopi gratis (backend memakai 9).
  final int stampTarget;

  /// Sisa stamp menuju reward (backend: `stamps_to_free`).
  final int stampsToReward;

  /// Tier saat ini (bronze/silver/gold/platinum).
  final String tier;

  /// Tier berikutnya, null bila sudah tertinggi.
  final String? nextTier;

  /// Poin yang dibutuhkan menuju tier berikutnya.
  final int pointsToNext;

  /// Total pesanan selesai sepanjang waktu.
  final int lifetimeOrders;

  /// Progres stamp 0.0–1.0 pada kartu berjalan.
  double get stampProgress {
    if (stampTarget <= 0) return 0;
    final filled = stamps % stampTarget;
    // Saat stamp penuh tepat kelipatan target, tampilkan penuh.
    if (filled == 0 && stamps > 0) return 1;
    return filled / stampTarget;
  }

  /// Label tier dengan huruf kapital di depan.
  String get tierLabel =>
      tier.isEmpty ? 'Bronze' : tier[0].toUpperCase() + tier.substring(1);

  factory LoyaltySummary.fromJson(Map<String, dynamic> json) {
    final target = _asInt(json['stamp_target'] ?? json['stampTarget']);
    return LoyaltySummary(
      points: _asInt(json['points'] ?? json['loyalty_points']),
      stamps: _asInt(json['stamp_count'] ?? json['stamps']),
      stampTarget: target == 0 ? 9 : target,
      stampsToReward: _asInt(json['stamps_to_free'] ?? json['stampsToReward']),
      tier: (json['tier'] ?? json['level'] ?? 'bronze').toString(),
      nextTier: json['next_tier']?.toString(),
      pointsToNext: _asInt(json['points_to_next']),
      lifetimeOrders: _asInt(json['lifetime_orders']),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
