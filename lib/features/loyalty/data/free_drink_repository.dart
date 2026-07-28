import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';

/// Voucher gratis-minuman aktif milik pelanggan (hasil lookup kasir).
class FreeDrinkVoucher {
  const FreeDrinkVoucher({
    required this.voucherId,
    required this.code,
    required this.customerName,
    this.expiresAt,
  });

  final String voucherId;
  final String code;
  final String customerName;
  final DateTime? expiresAt;

  factory FreeDrinkVoucher.fromJson(Map<String, dynamic> j) => FreeDrinkVoucher(
        voucherId: (j['voucherId'] ?? j['id'] ?? '').toString(),
        code: (j['code'] ?? '').toString(),
        customerName: (j['customerName'] ?? j['customer_name'] ?? '-').toString(),
        expiresAt: DateTime.tryParse((j['expires_at'] ?? '').toString()),
      );
}

/// Pelanggan yang stamp-nya siap ditukar kasir (hasil lookup stamp).
class StampRedeemCandidate {
  const StampRedeemCandidate({
    required this.userId,
    required this.name,
    required this.availableStamps,
    required this.redeemableRewards,
    this.phone,
  });

  final String userId;
  final String name;
  final String? phone;
  final int availableStamps;

  /// Berapa minuman gratis yang bisa ditukar sekarang (floor(available/9)).
  final int redeemableRewards;

  factory StampRedeemCandidate.fromJson(Map<String, dynamic> j) {
    int asInt(dynamic v) => v is int ? v : int.tryParse('${v ?? 0}') ?? 0;
    return StampRedeemCandidate(
      userId: (j['userId'] ?? j['user_id'] ?? j['id'] ?? '').toString(),
      name: (j['name'] ?? j['customerName'] ?? '-').toString(),
      phone: j['phone']?.toString(),
      availableStamps: asInt(j['availableStamps'] ?? j['available_stamps']),
      redeemableRewards:
          asInt(j['redeemableRewards'] ?? j['redeemable_rewards']),
    );
  }
}

/// (Kasir) Cari & tandai-terpakai voucher gratis-minuman pelanggan, serta
/// tukar stamp pelanggan langsung dari sisi kasir.
class FreeDrinkRepository {
  FreeDrinkRepository({required DioClient client}) : _client = client;

  final DioClient _client;

  /// Cari voucher aktif via no. HP (+ nama opsional).
  Future<List<FreeDrinkVoucher>> lookup(
      {required String phone, String? name}) async {
    final res = await _client.get<dynamic>(
      ApiConstants.freeDrinkVouchers,
      query: {
        'phone': phone,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      },
    );
    final data = res.data;
    final list = data is Map ? (data['data'] ?? data['vouchers']) : data;
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => FreeDrinkVoucher.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  /// Cari pelanggan yang stamp-nya siap ditukar (≥9) via no. HP (+ nama opsional).
  Future<List<StampRedeemCandidate>> lookupStamps(
      {required String phone, String? name}) async {
    final res = await _client.get<dynamic>(
      ApiConstants.stampLookup,
      query: {
        'phone': phone,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      },
    );
    final data = res.data;
    final list = data is Map ? (data['data'] ?? data['customers']) : data;
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) =>
              StampRedeemCandidate.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  /// Tukar 9 stamp pelanggan + langsung serahkan (voucher tercatat terpakai).
  Future<void> redeemForCustomer(String userId) async {
    await _client.post<dynamic>(
      ApiConstants.stampRedeem,
      data: {'userId': userId},
    );
  }

  /// Tandai voucher terpakai (minuman diserahkan ke pelanggan).
  Future<void> markUsed(String voucherId) async {
    await _client.post<dynamic>(ApiConstants.freeDrinkVoucherUse(voucherId));
  }
}

final freeDrinkRepositoryProvider = Provider<FreeDrinkRepository>((ref) {
  return FreeDrinkRepository(client: ref.watch(dioClientProvider));
});
