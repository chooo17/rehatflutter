import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/formatters.dart';

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

/// Satu pos biaya tetap bulanan (sewa, gaji, listrik…).
class FixedCost {
  const FixedCost({
    required this.id,
    required this.name,
    required this.amount,
    this.category = '',
    this.dueDay,
    this.isActive = true,
  });

  final String id;
  final String name;
  final int amount;
  final String category;
  final int? dueDay;
  final bool isActive;

  factory FixedCost.fromJson(Map<String, dynamic> j) => FixedCost(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        amount: _int(j['amount']),
        category: (j['category'] ?? '').toString(),
        dueDay: j['due_day'] == null ? null : _int(j['due_day']),
        isActive: j['is_active'] == null ? true : j['is_active'] == true,
      );
}

/// Laporan laba rugi satu bulan.
class ProfitLoss {
  const ProfitLoss({
    required this.month,
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    required this.grossMarginPct,
    required this.fixedCosts,
    required this.variableExpenses,
    required this.paymentFees,
    required this.netProfit,
    required this.netMarginPct,
    required this.fixedCostItems,
    this.variableExpensesUnavailable = false,
  });

  final String month;
  final int revenue;
  final int cogs;
  final int grossProfit;
  final int grossMarginPct;
  final int fixedCosts;
  final int variableExpenses;
  final int paymentFees;
  final int netProfit;
  final int netMarginPct;
  final List<FixedCost> fixedCostItems;

  /// True bila query pengeluaran variabel (non-restock) gagal di backend —
  /// artinya [variableExpenses] (dan angka turunannya) DEFAULT 0, bukan
  /// data nyata. Layar wajib memperingatkan, bukan menampilkan Rp0 diam-diam.
  final bool variableExpensesUnavailable;

  factory ProfitLoss.fromJson(Map<String, dynamic> j) => ProfitLoss(
        month: (j['month'] ?? '').toString(),
        revenue: _int(j['revenue']),
        cogs: _int(j['cogs']),
        grossProfit: _int(j['grossProfit']),
        grossMarginPct: _int(j['grossMarginPct']),
        fixedCosts: _int(j['fixedCosts']),
        variableExpenses: _int(j['variableExpenses']),
        paymentFees: _int(j['paymentFees']),
        netProfit: _int(j['netProfit']),
        netMarginPct: _int(j['netMarginPct']),
        fixedCostItems: ((j['fixed_cost_items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => FixedCost.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        variableExpensesUnavailable: j['variable_expenses_unavailable'] == true,
      );
}

Map<String, dynamic> _unwrap(dynamic body) => (body is Map && body['data'] is Map)
    ? Map<String, dynamic>.from(body['data'] as Map)
    : Map<String, dynamic>.from(body as Map);

/// Akses modul keuangan (khusus pemilik). Endpoint membalas 404 untuk akun
/// lain — HANYA itu yang berarti "tidak punya akses". Kegagalan lain
/// (jaringan mati, timeout, sesi kedaluwarsa, server error) dilempar ulang
/// supaya pemanggil (FutureProvider) bisa membedakannya, alih-alih diam-diam
/// menyembunyikan menu Keuangan seolah pengguna memang tak berhak.
class FinanceRepository {
  FinanceRepository({required DioClient client}) : _client = client;
  final DioClient _client;

  Future<bool> hasAccess() async {
    try {
      await _client.get<dynamic>(ApiConstants.financePing);
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return false;
      rethrow;
    }
  }

  Future<List<FixedCost>> fetchFixedCosts() async {
    final res = await _client.get<dynamic>(ApiConstants.financeFixedCosts);
    final data = _unwrap(res.data);
    return ((data['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => FixedCost.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> addFixedCost({
    required String name,
    required int amount,
    String? category,
    int? dueDay,
  }) async {
    await _client.post<dynamic>(ApiConstants.financeFixedCosts, data: {
      'name': name.trim(),
      'amount': amount,
      if (category != null && category.trim().isNotEmpty) 'category': category.trim(),
      if (dueDay != null) 'due_day': dueDay,
    });
  }

  Future<void> deleteFixedCost(String id) async {
    await _client.delete<dynamic>(ApiConstants.financeFixedCost(id));
  }

  Future<ProfitLoss> fetchPnl(String month) async {
    final res = await _client.get<dynamic>(
      ApiConstants.financePnl,
      query: {'month': month},
    );
    return ProfitLoss.fromJson(_unwrap(res.data));
  }
}

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(client: ref.watch(dioClientProvider));
});

/// Apakah akun yang login boleh membuka modul keuangan.
final financeAccessProvider = FutureProvider<bool>((ref) {
  return ref.watch(financeRepositoryProvider).hasAccess();
});

final fixedCostsProvider = FutureProvider<List<FixedCost>>((ref) {
  return ref.watch(financeRepositoryProvider).fetchFixedCosts();
});

/// Bulan aktif laporan laba rugi (default: bulan berjalan menurut WIB).
final pnlMonthProvider = StateProvider<DateTime>((ref) {
  final now = Formatters.toWib(DateTime.now());
  return DateTime(now.year, now.month);
});

final pnlProvider = FutureProvider<ProfitLoss>((ref) {
  final m = ref.watch(pnlMonthProvider);
  final month =
      '${m.year.toString().padLeft(4, '0')}-${m.month.toString().padLeft(2, '0')}';
  return ref.watch(financeRepositoryProvider).fetchPnl(month);
});
