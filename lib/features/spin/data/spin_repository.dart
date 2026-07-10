import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/spin_model.dart';

/// Status roda putar: daftar hadiah & apakah pengguna boleh memutar.
class SpinStatus {
  const SpinStatus({
    required this.prizes,
    this.canSpin = true,
    this.nextSpinAt,
  });

  final List<SpinPrize> prizes;
  final bool canSpin;
  final DateTime? nextSpinAt;
}

/// Akses data permainan Spin the Wheel.
///
/// Segmen roda dibuat di sisi-klien agar cocok dengan bobot hadiah backend
/// (`spinService.SPIN_PRIZES`): 3%, zonk, 5%, zonk, 7%, 10%. Backend hanya
/// mengembalikan `discountPct`, lalu kita petakan ke indeks segmen.
class SpinRepository {
  SpinRepository({required DioClient client}) : _client = client;

  final DioClient _client;
  final Random _rng = Random();

  /// 6 segmen sesuai urutan backend.
  static const List<SpinPrize> wheelPrizes = [
    SpinPrize(id: '3', label: 'Diskon\n3%', discountPct: 3),
    SpinPrize(id: '0a', label: 'Coba\nLagi', isWin: false),
    SpinPrize(id: '5', label: 'Diskon\n5%', discountPct: 5),
    SpinPrize(id: '0b', label: 'Coba\nLagi', isWin: false),
    SpinPrize(id: '7', label: 'Diskon\n7%', discountPct: 7),
    SpinPrize(id: '10', label: 'Diskon\n10%', discountPct: 10),
  ];

  Future<SpinStatus> fetchStatus() async {
    final res = await _client.get<dynamic>(ApiConstants.spinStatus);
    final data = res.data;
    final body = data is Map ? (data['data'] ?? data) : data;
    final canSpin = body is Map ? (body['can_spin'] ?? true) == true : true;
    final nextSpinAt = body is Map
        ? DateTime.tryParse((body['next_spin_at'] ?? '').toString())
        : null;
    return SpinStatus(
      prizes: wheelPrizes,
      canSpin: canSpin,
      nextSpinAt: nextSpinAt,
    );
  }

  /// Memutar roda (`POST /spin`). Memetakan `discountPct` ke indeks segmen.
  Future<SpinResult> spin() async {
    final res = await _client.post<dynamic>(ApiConstants.spin);
    final data = res.data;
    final body = data is Map ? (data['data'] ?? data) : data;

    final isWin = body is Map ? (body['result'] == 'win') : false;
    final pct = body is Map ? _asInt(body['discountPct'] ?? body['discount_pct']) : 0;
    final voucherJson = body is Map ? body['voucher'] : null;
    final voucherCode = voucherJson is Map ? voucherJson['code']?.toString() : null;

    final index = _indexForResult(isWin: isWin, pct: pct);
    return SpinResult(
      prizeIndex: index,
      prize: wheelPrizes[index],
      message: isWin
          ? 'Kamu memenangkan diskon $pct%!${voucherCode != null ? '\nKode: $voucherCode' : ''}'
          : 'Belum beruntung. Coba lagi besok, ya!',
      voucherCode: voucherCode,
    );
  }

  /// Memilih indeks segmen untuk hasil backend.
  int _indexForResult({required bool isWin, required int pct}) {
    if (isWin && pct > 0) {
      final i = wheelPrizes.indexWhere((p) => p.discountPct == pct);
      if (i >= 0) return i;
    }
    // Zonk: pilih salah satu segmen "Coba Lagi" secara acak.
    final zonkIdx = [
      for (var i = 0; i < wheelPrizes.length; i++)
        if (!wheelPrizes[i].isWin) i
    ];
    return zonkIdx[_rng.nextInt(zonkIdx.length)];
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

final spinRepositoryProvider = Provider<SpinRepository>((ref) {
  return SpinRepository(client: ref.watch(dioClientProvider));
});

final spinStatusProvider = FutureProvider<SpinStatus>((ref) {
  return ref.watch(spinRepositoryProvider).fetchStatus();
});
