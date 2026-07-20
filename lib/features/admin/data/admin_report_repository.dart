import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/formatters.dart';

/// Satu titik penjualan harian (untuk grafik).
class SalesPoint {
  const SalesPoint({required this.date, required this.revenue, required this.orders});

  final String date; // 'YYYY-MM-DD'
  final int revenue;
  final int orders;

  factory SalesPoint.fromJson(Map<String, dynamic> j) => SalesPoint(
        date: (j['date'] ?? '').toString(),
        revenue: _int(j['revenue']),
        orders: _int(j['orders']),
      );
}

/// Item terlaris pada rentang laporan.
class TopItem {
  const TopItem({
    required this.name,
    required this.quantity,
    required this.revenue,
    this.cost = 0,
    this.profit = 0,
    this.marginPct = 0,
  });

  final String name;
  final int quantity;
  final int revenue;
  final int cost;
  final int profit;
  final int marginPct;

  factory TopItem.fromJson(Map<String, dynamic> j) => TopItem(
        name: (j['name'] ?? 'Lainnya').toString(),
        quantity: _int(j['quantity']),
        revenue: _int(j['revenue']),
        cost: _int(j['cost']),
        profit: _int(j['profit']),
        marginPct: _int(j['margin_pct']),
      );
}

/// Laporan penjualan agregat untuk dashboard admin.
class SalesReport {
  const SalesReport({
    required this.range,
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    required this.grossMarginPct,
    required this.netProfit,
    required this.qrisRevenue,
    required this.cashRevenue,
    required this.expenses,
    required this.cashInDrawer,
    required this.orders,
    required this.itemsSold,
    required this.avgOrderValue,
    required this.series,
    required this.topItems,
  });

  final String range;
  final int revenue;

  /// HPP total (Σ modal × qty terjual) & laba kotor (omzet - HPP).
  final int cogs;
  final int grossProfit;

  /// Margin kotor (%).
  final int grossMarginPct;

  /// Laba bersih RIIL = omzet - HPP - pengeluaran (dihitung backend).
  final int netProfit;

  /// Penerimaan dipisah per metode bayar.
  final int qrisRevenue;
  final int cashRevenue;

  /// Total pengeluaran & kas tunai di kasir (omzet - qris - pengeluaran).
  final int expenses;
  final int cashInDrawer;

  final int orders;
  final int itemsSold;
  final int avgOrderValue;
  final List<SalesPoint> series;
  final List<TopItem> topItems;

  factory SalesReport.fromJson(Map<String, dynamic> j) {
    final summary = (j['summary'] is Map)
        ? Map<String, dynamic>.from(j['summary'] as Map)
        : const <String, dynamic>{};
    final series = (j['series'] as List?) ?? const [];
    final top = (j['top_items'] as List?) ?? const [];
    return SalesReport(
      range: (j['range'] ?? '7d').toString(),
      revenue: _int(summary['revenue']),
      cogs: _int(summary['cogs']),
      grossProfit: _int(summary['gross_profit']),
      grossMarginPct: _int(summary['gross_margin_pct']),
      netProfit: _int(summary['net_profit']),
      qrisRevenue: _int(summary['qris_revenue']),
      cashRevenue: _int(summary['cash_revenue']),
      expenses: _int(summary['expenses']),
      cashInDrawer: _int(summary['cash_in_drawer']),
      orders: _int(summary['orders']),
      itemsSold: _int(summary['items_sold']),
      avgOrderValue: _int(summary['avg_order_value']),
      series: series
          .whereType<Map>()
          .map((e) => SalesPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      topItems: top
          .whereType<Map>()
          .map((e) => TopItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

/// Satu catatan pengeluaran.
class ExpenseItem {
  const ExpenseItem(
      {required this.id, required this.amount, this.note = '', this.category = '', required this.spentAt});
  final String id;
  final int amount;
  final String note;
  final String category;
  final DateTime spentAt;

  factory ExpenseItem.fromJson(Map<String, dynamic> j) => ExpenseItem(
        id: (j['id'] ?? '').toString(),
        amount: _int(j['amount']),
        note: (j['note'] ?? '').toString(),
        category: (j['category'] ?? '').toString(),
        spentAt: DateTime.tryParse((j['spent_at'] ?? '').toString()) ?? DateTime.now(),
      );
}

/// Daftar + total pengeluaran pada rentang.
class ExpenseList {
  const ExpenseList({required this.items, required this.total});
  final List<ExpenseItem> items;
  final int total;
}

/// Satu baris rekonsiliasi (jumlah transaksi + nominal).
class ReconLine {
  const ReconLine({required this.count, required this.amount});
  final int count;
  final int amount;
  factory ReconLine.fromJson(dynamic j) => (j is Map)
      ? ReconLine(count: _int(j['count']), amount: _int(j['amount']))
      : const ReconLine(count: 0, amount: 0);
}

/// Laporan tutup kasir harian + rekonsiliasi pembayaran.
class ClosingReport {
  const ClosingReport({
    required this.date,
    required this.summary,
    required this.topItems,
    required this.qrisSettled,
    required this.qrisPending,
    required this.cashSettled,
    required this.cancelled,
    required this.expectedCashDrawer,
    required this.digitalReceived,
    required this.unsettled,
  });

  final String date;
  final SalesReport summary; // ringkasan penjualan hari itu (omzet, HPP, laba…)
  final List<TopItem> topItems;
  final ReconLine qrisSettled; // QRIS lunas (uang masuk)
  final ReconLine qrisPending; // QRIS diinisiasi, belum lunas
  final ReconLine cashSettled; // tunai lunas
  final ReconLine cancelled;
  final int expectedCashDrawer; // kas tunai yang harus ada = tunai - pengeluaran
  final int digitalReceived; // total non-tunai masuk (banding dgn DOKU)
  final int unsettled; // QRIS menggantung (belum settle)

  factory ClosingReport.fromJson(Map<String, dynamic> j) {
    final rec = (j['reconciliation'] is Map)
        ? Map<String, dynamic>.from(j['reconciliation'] as Map)
        : const <String, dynamic>{};
    final top = (j['top_items'] as List?) ?? const [];
    // SalesReport.fromJson mengharap {summary, series, top_items} → susun ulang.
    final summaryReport = SalesReport.fromJson({
      'range': 'today',
      'summary': j['summary'],
      'series': const [],
      'top_items': top,
    });
    return ClosingReport(
      date: (j['date'] ?? '').toString(),
      summary: summaryReport,
      topItems: summaryReport.topItems,
      qrisSettled: ReconLine.fromJson(rec['qris_settled']),
      qrisPending: ReconLine.fromJson(rec['qris_pending']),
      cashSettled: ReconLine.fromJson(rec['cash_settled']),
      cancelled: ReconLine.fromJson(rec['cancelled']),
      expectedCashDrawer: _int(rec['expected_cash_drawer']),
      digitalReceived: _int(rec['digital_received']),
      unsettled: _int(rec['unsettled']),
    );
  }
}

Map<String, dynamic> _unwrap(dynamic body) => (body is Map && body['data'] is Map)
    ? Map<String, dynamic>.from(body['data'] as Map)
    : Map<String, dynamic>.from(body as Map);

/// Analitik lanjutan: jam sibuk, hari, AOV, repeat-rate.
class Analytics {
  const Analytics({
    required this.orders,
    required this.avgOrderValue,
    required this.repeatRatePct,
    required this.uniqueBuyers,
    required this.peakHour,
    required this.hourly,
    required this.dow,
  });

  final int orders;
  final int avgOrderValue;
  final int repeatRatePct;
  final int uniqueBuyers;
  final int? peakHour;
  final List<int> hourly; // 24 nilai = jumlah pesanan per jam
  final List<int> dow; // 7 nilai = jumlah pesanan per hari (0=Minggu)

  factory Analytics.fromJson(Map<String, dynamic> j) {
    List<int> pick(String key) => ((j[key] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => _int(e['orders']))
        .toList();
    return Analytics(
      orders: _int(j['orders']),
      avgOrderValue: _int(j['avg_order_value']),
      repeatRatePct: _int(j['repeat_rate_pct']),
      uniqueBuyers: _int(j['unique_buyers']),
      peakHour: j['peak_hour'] == null ? null : _int(j['peak_hour']),
      hourly: pick('hourly'),
      dow: pick('dow'),
    );
  }
}

/// Akses laporan penjualan & pengeluaran (admin).
class AdminReportRepository {
  AdminReportRepository({required DioClient client}) : _client = client;
  final DioClient _client;

  /// [date] (YYYY-MM-DD) menang atas [range] bila diisi.
  Future<SalesReport> fetchSales({String range = '7d', String? date}) async {
    final res = await _client.get<dynamic>(
      ApiConstants.adminSalesReport,
      query: {'range': range, if (date != null) 'date': date},
    );
    return SalesReport.fromJson(_unwrap(res.data));
  }

  /// Kalender omzet harian untuk satu bulan (YYYY-MM) → {'YYYY-MM-DD': omzet}.
  Future<Map<String, int>> fetchCalendar(String month) async {
    final res = await _client.get<dynamic>(
      ApiConstants.adminReportCalendar,
      query: {'month': month},
    );
    final data = _unwrap(res.data);
    final days = data['days'];
    final out = <String, int>{};
    if (days is Map) {
      days.forEach((k, v) => out[k.toString()] = _int(v));
    }
    return out;
  }

  Future<ExpenseList> fetchExpenses({String range = '7d', String? date}) async {
    final res = await _client.get<dynamic>(
      ApiConstants.adminExpenses,
      query: {'range': range, if (date != null) 'date': date},
    );
    final data = _unwrap(res.data);
    final items = (data['items'] as List?) ?? const [];
    return ExpenseList(
      items: items
          .whereType<Map>()
          .map((e) => ExpenseItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      total: _int(data['total']),
    );
  }

  Future<void> addExpense({required int amount, String? note, String? category}) async {
    await _client.post<dynamic>(ApiConstants.adminExpenses, data: {
      'amount': amount,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      if (category != null && category.trim().isNotEmpty) 'category': category.trim(),
    });
  }

  Future<void> deleteExpense(String id) async {
    await _client.delete<dynamic>(ApiConstants.adminExpense(id));
  }

  Future<Analytics> fetchAnalytics({String range = '30d'}) async {
    final res = await _client.get<dynamic>(
      ApiConstants.adminAnalytics,
      query: {'range': range},
    );
    return Analytics.fromJson(_unwrap(res.data));
  }

  /// Tutup kasir + rekonsiliasi untuk [date] (YYYY-MM-DD, null = hari ini).
  Future<ClosingReport> fetchClosing({String? date}) async {
    final res = await _client.get<dynamic>(
      ApiConstants.adminClosingReport,
      query: {if (date != null) 'date': date},
    );
    return ClosingReport.fromJson(_unwrap(res.data));
  }
}

final adminReportRepositoryProvider = Provider<AdminReportRepository>((ref) {
  return AdminReportRepository(client: ref.watch(dioClientProvider));
});

/// Tanggal spesifik yang dipilih (null = pakai pill rentang).
final salesDateProvider = StateProvider<DateTime?>((ref) => null);

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Rentang aktif dashboard ('today' | '7d' | '30d').
final salesRangeProvider = StateProvider<String>((ref) => '7d');

/// Laporan penjualan untuk rentang/tanggal aktif.
final salesReportProvider = FutureProvider<SalesReport>((ref) {
  final range = ref.watch(salesRangeProvider);
  final date = ref.watch(salesDateProvider);
  return ref.watch(adminReportRepositoryProvider).fetchSales(
        range: range,
        date: date != null ? _fmtDate(date) : null,
      );
});

/// Pengeluaran untuk rentang/tanggal aktif (mengikuti pilihan laporan).
final expensesProvider = FutureProvider<ExpenseList>((ref) {
  final range = ref.watch(salesRangeProvider);
  final date = ref.watch(salesDateProvider);
  return ref.watch(adminReportRepositoryProvider).fetchExpenses(
        range: range,
        date: date != null ? _fmtDate(date) : null,
      );
});

/// Rentang analitik ('today'|'7d'|'30d').
final analyticsRangeProvider = StateProvider<String>((ref) => '30d');

/// Analitik lanjutan untuk rentang aktif (autoDispose: selalu segar).
final analyticsProvider = FutureProvider.autoDispose<Analytics>((ref) {
  final range = ref.watch(analyticsRangeProvider);
  return ref.watch(adminReportRepositoryProvider).fetchAnalytics(range: range);
});

/// Tanggal tutup kasir yang dipilih (default hari ini).
/// Default "hari ini" mengikuti WIB, bukan zona waktu perangkat — supaya
/// tutup kasir menunjuk hari gerai yang benar meski perangkat/emulator
/// tidak diset ke WIB.
final closingDateProvider =
    StateProvider<DateTime>((ref) => Formatters.toWib(DateTime.now()));

/// Laporan tutup kasir untuk tanggal aktif.
final closingReportProvider = FutureProvider<ClosingReport>((ref) {
  final d = ref.watch(closingDateProvider);
  return ref.watch(adminReportRepositoryProvider).fetchClosing(date: _fmtDate(d));
});

/// Bulan aktif kalender penjualan (default: bulan berjalan menurut WIB).
final calendarMonthProvider = StateProvider<DateTime>((ref) {
  final now = Formatters.toWib(DateTime.now());
  return DateTime(now.year, now.month);
});

/// Omzet harian untuk bulan aktif → {'YYYY-MM-DD': omzet}.
final salesCalendarProvider = FutureProvider<Map<String, int>>((ref) {
  final m = ref.watch(calendarMonthProvider);
  final month = '${m.year.toString().padLeft(4, '0')}-${m.month.toString().padLeft(2, '0')}';
  return ref.watch(adminReportRepositoryProvider).fetchCalendar(month);
});
