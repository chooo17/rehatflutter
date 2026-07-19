import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

Map<String, dynamic> _data(dynamic body) => (body is Map && body['data'] is Map)
    ? Map<String, dynamic>.from(body['data'] as Map)
    : Map<String, dynamic>.from(body as Map);

/// Info referral pengguna.
class ReferralInfo {
  const ReferralInfo({required this.code, required this.referredCount, required this.rewardPct});
  final String code;
  final int referredCount;
  final int rewardPct;
  factory ReferralInfo.fromJson(Map<String, dynamic> j) => ReferralInfo(
        code: (j['code'] ?? '').toString(),
        referredCount: _int(j['referred_count']),
        rewardPct: _int(j['reward_pct']),
      );
}

/// Satu transaksi saldo.
class WalletTxn {
  const WalletTxn({required this.amount, required this.type, required this.description, required this.createdAt});
  final int amount;
  final String type;
  final String description;
  final DateTime createdAt;
  factory WalletTxn.fromJson(Map<String, dynamic> j) => WalletTxn(
        amount: _int(j['amount']),
        type: (j['type'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        createdAt: DateTime.tryParse((j['created_at'] ?? '').toString()) ?? DateTime.now(),
      );
}

/// Saldo + riwayat transaksi.
class WalletData {
  const WalletData({required this.balance, required this.transactions});
  final int balance;
  final List<WalletTxn> transactions;
}

class WalletRepository {
  WalletRepository({required DioClient client}) : _client = client;
  final DioClient _client;

  // Referral ----------------------------------------------------------
  Future<ReferralInfo> fetchReferral() async {
    final res = await _client.get<dynamic>(ApiConstants.referralMe);
    return ReferralInfo.fromJson(_data(res.data));
  }

  Future<void> applyReferral(String code) async {
    await _client.post<dynamic>(ApiConstants.referralApply, data: {'code': code});
  }

  // Wallet ------------------------------------------------------------
  Future<WalletData> fetchWallet() async {
    final res = await _client.get<dynamic>(ApiConstants.wallet);
    final d = _data(res.data);
    return WalletData(
      balance: _int(d['balance']),
      transactions: ((d['transactions'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => WalletTxn.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  /// Mulai top-up → kembalikan URL pembayaran DOKU.
  Future<String> topup(int amount) async {
    final res = await _client.post<dynamic>(
      ApiConstants.walletTopup,
      data: {'amount': amount},
    );
    return (_data(res.data)['payment_url'] ?? '').toString();
  }

  /// Bayar sebuah pesanan memakai saldo (pelanggan, pesanan sendiri).
  Future<void> payWithBalance(String orderId) async {
    await _client.post<dynamic>(ApiConstants.orderPayBalance(orderId));
  }

  /// (Kasir) Bayar pesanan kasir/guest memakai saldo admin yang login.
  Future<void> adminPayWithBalance(String orderId) async {
    await _client.post<dynamic>(ApiConstants.adminOrderPayBalance(orderId));
  }
}

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(client: ref.watch(dioClientProvider));
});

// autoDispose: data selalu segar tiap layar dibuka & tak menahan memori.
final referralProvider = FutureProvider.autoDispose<ReferralInfo>((ref) {
  return ref.watch(walletRepositoryProvider).fetchReferral();
});

final walletProvider = FutureProvider.autoDispose<WalletData>((ref) {
  return ref.watch(walletRepositoryProvider).fetchWallet();
});
