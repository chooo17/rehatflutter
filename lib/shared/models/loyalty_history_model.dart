/// Satu entri riwayat poin loyalitas (`GET /loyalty/history`).
class LoyaltyHistoryEntry {
  const LoyaltyHistoryEntry({
    required this.id,
    required this.type,
    required this.amount,
    this.description = '',
    this.balanceAfter = 0,
    this.createdAt,
  });

  final String id;

  /// 'earn' (dapat poin) atau 'redeem' (tukar poin).
  final String type;

  /// Jumlah poin (positif untuk earn).
  final int amount;
  final String description;
  final int balanceAfter;
  final DateTime? createdAt;

  bool get isEarn => type.toLowerCase() == 'earn';

  factory LoyaltyHistoryEntry.fromJson(Map<String, dynamic> json) {
    return LoyaltyHistoryEntry(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      amount: _asInt(json['amount']),
      description: (json['description'] ?? '').toString(),
      balanceAfter: _asInt(json['balance_after']),
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
