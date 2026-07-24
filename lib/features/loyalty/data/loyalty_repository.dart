import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/loyalty_history_model.dart';
import '../../../shared/models/loyalty_model.dart';
import '../../../shared/models/voucher_model.dart';

/// Akses data loyalitas: ringkasan poin/stamp & voucher.
class LoyaltyRepository {
  LoyaltyRepository({required DioClient client}) : _client = client;

  final DioClient _client;

  Future<LoyaltySummary> fetchSummary() async {
    final res = await _client.get<dynamic>(ApiConstants.loyalty);
    final data = res.data;
    final json = data is Map ? (data['data'] ?? data['summary'] ?? data) : data;
    return LoyaltySummary.fromJson(Map<String, dynamic>.from(json as Map));
  }

  /// Voucher milik pengguna yang masih berlaku (`GET /vouchers`).
  Future<List<VoucherModel>> fetchVouchers() async {
    final res = await _client.get<dynamic>(ApiConstants.vouchers);
    final data = res.data;
    final list =
        data is Map ? (data['data'] ?? data['vouchers'] ?? data['items']) : data;
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => VoucherModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  /// Tukar 9 stamp → voucher gratis 1 minuman (`POST /loyalty/stamps/redeem`).
  Future<void> redeemStamp() async {
    await _client.post<dynamic>(ApiConstants.loyaltyStampRedeem);
  }

  /// Tukar poin → voucher diskon (`POST /loyalty/points/redeem`).
  Future<void> redeemPoints(int discountPct) async {
    await _client.post<dynamic>(
      ApiConstants.loyaltyPointsRedeem,
      data: {'discountPct': discountPct},
    );
  }

  /// Riwayat transaksi poin (`GET /loyalty/history`).
  Future<List<LoyaltyHistoryEntry>> fetchHistory() async {
    final res = await _client.get<dynamic>(ApiConstants.loyaltyHistory);
    final data = res.data;
    final list = data is Map ? (data['data'] ?? data['history']) : data;
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => LoyaltyHistoryEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }
}

final loyaltyRepositoryProvider = Provider<LoyaltyRepository>((ref) {
  return LoyaltyRepository(client: ref.watch(dioClientProvider));
});

final loyaltySummaryProvider = FutureProvider<LoyaltySummary>((ref) {
  return ref.watch(loyaltyRepositoryProvider).fetchSummary();
});

final vouchersProvider = FutureProvider<List<VoucherModel>>((ref) {
  return ref.watch(loyaltyRepositoryProvider).fetchVouchers();
});

final loyaltyHistoryProvider =
    FutureProvider<List<LoyaltyHistoryEntry>>((ref) {
  return ref.watch(loyaltyRepositoryProvider).fetchHistory();
});
