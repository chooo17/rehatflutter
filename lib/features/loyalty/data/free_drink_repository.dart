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

/// (Kasir) Cari & tandai-terpakai voucher gratis-minuman pelanggan.
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

  /// Tandai voucher terpakai (minuman diserahkan ke pelanggan).
  Future<void> markUsed(String voucherId) async {
    await _client.post<dynamic>(ApiConstants.freeDrinkVoucherUse(voucherId));
  }
}

final freeDrinkRepositoryProvider = Provider<FreeDrinkRepository>((ref) {
  return FreeDrinkRepository(client: ref.watch(dioClientProvider));
});
