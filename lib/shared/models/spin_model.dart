/// Satu hadiah / segmen pada roda putar.
class SpinPrize {
  const SpinPrize({
    required this.id,
    required this.label,
    this.isWin = true,
    this.discountPct = 0,
  });

  final String id;
  final String label;

  /// `false` untuk segmen "Coba lagi"/zonk.
  final bool isWin;

  /// Besar diskon (persen) bila menang.
  final int discountPct;

  factory SpinPrize.fromJson(Map<String, dynamic> json) {
    return SpinPrize(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? json['name'] ?? json['title'] ?? '').toString(),
      isWin: (json['is_win'] ?? json['isWin'] ?? true) == true,
      discountPct: json['discount_pct'] is num
          ? (json['discount_pct'] as num).toInt()
          : 0,
    );
  }
}

/// Hasil satu kali putaran.
class SpinResult {
  const SpinResult({
    required this.prizeIndex,
    required this.prize,
    this.message,
    this.voucherCode,
  });

  /// Indeks segmen yang menang (untuk menyetop animasi tepat di hadiah).
  final int prizeIndex;
  final SpinPrize prize;
  final String? message;

  /// Kode voucher yang diberikan bila menang.
  final String? voucherCode;

  bool get isWin => prize.isWin;
}
