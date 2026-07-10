import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';

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
  const TopItem({required this.name, required this.quantity, required this.revenue});

  final String name;
  final int quantity;
  final int revenue;

  factory TopItem.fromJson(Map<String, dynamic> j) => TopItem(
        name: (j['name'] ?? 'Lainnya').toString(),
        quantity: _int(j['quantity']),
        revenue: _int(j['revenue']),
      );
}

/// Laporan penjualan agregat untuk dashboard admin.
class SalesReport {
  const SalesReport({
    required this.range,
    required this.revenue,
    required this.orders,
    required this.itemsSold,
    required this.avgOrderValue,
    required this.series,
    required this.topItems,
  });

  final String range;
  final int revenue;
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

/// Akses laporan penjualan (admin).
class AdminReportRepository {
  AdminReportRepository({required DioClient client}) : _client = client;
  final DioClient _client;

  Future<SalesReport> fetchSales({String range = '7d'}) async {
    final res = await _client.get<dynamic>(
      ApiConstants.adminSalesReport,
      query: {'range': range},
    );
    final body = res.data;
    final data = (body is Map && body['data'] is Map)
        ? Map<String, dynamic>.from(body['data'] as Map)
        : Map<String, dynamic>.from(body as Map);
    return SalesReport.fromJson(data);
  }
}

final adminReportRepositoryProvider = Provider<AdminReportRepository>((ref) {
  return AdminReportRepository(client: ref.watch(dioClientProvider));
});

/// Rentang aktif dashboard ('today' | '7d' | '30d').
final salesRangeProvider = StateProvider<String>((ref) => '7d');

/// Laporan penjualan untuk rentang aktif.
final salesReportProvider = FutureProvider<SalesReport>((ref) {
  final range = ref.watch(salesRangeProvider);
  return ref.watch(adminReportRepositoryProvider).fetchSales(range: range);
});
