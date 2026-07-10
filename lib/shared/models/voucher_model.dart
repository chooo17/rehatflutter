/// Voucher diskon milik pengguna (didapat dari spin/promo).
///
/// Backend: `{ id, code, source, discount_pct, is_used, expires_at, used_at }`.
class VoucherModel {
  const VoucherModel({
    required this.id,
    required this.code,
    this.discountPct = 0,
    this.source = '',
    this.isUsed = false,
    this.expiresAt,
    this.usedAt,
  });

  final String id;
  final String code;

  /// Besar diskon dalam persen (mis. 10 untuk 10%).
  final int discountPct;

  /// Asal voucher: 'spin', 'promo', dll.
  final String source;

  final bool isUsed;
  final DateTime? expiresAt;
  final DateTime? usedAt;

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  /// Bisa dipakai: belum terpakai & belum kedaluwarsa.
  bool get isUsable => !isUsed && !isExpired;

  /// Judul tampilan, mis. "Diskon 10%".
  String get title => 'Diskon $discountPct%';

  /// Label nilai, mis. "10%".
  String get valueLabel => '$discountPct%';

  /// Label asal voucher dalam Bahasa Indonesia.
  String get sourceLabel {
    switch (source.toLowerCase()) {
      case 'spin':
        return 'Hadiah Spin';
      case 'promo':
        return 'Promo';
      case 'referral':
        return 'Referral';
      default:
        return source.isEmpty ? 'Voucher' : source;
    }
  }

  factory VoucherModel.fromJson(Map<String, dynamic> json) {
    return VoucherModel(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      discountPct: _asInt(json['discount_pct'] ?? json['discountPct']),
      source: (json['source'] ?? '').toString(),
      isUsed: (json['is_used'] ?? json['isUsed'] ?? false) == true,
      expiresAt: DateTime.tryParse(
          (json['expires_at'] ?? json['expiresAt'] ?? '').toString()),
      usedAt: DateTime.tryParse((json['used_at'] ?? json['usedAt'] ?? '').toString()),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
