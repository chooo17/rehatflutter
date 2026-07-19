import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

/// Satu pelanggan dalam sebuah segmen (hasil analisis RFM).
class SegmentCustomer {
  const SegmentCustomer({
    required this.id,
    required this.name,
    required this.phone,
    required this.frequency,
    required this.monetary,
    this.recencyDays,
  });

  final String id;
  final String name;
  final String phone;
  final int frequency; // jumlah pesanan
  final int monetary; // total belanja
  final int? recencyDays; // hari sejak pesanan terakhir (null = belum pernah)

  factory SegmentCustomer.fromJson(Map<String, dynamic> j) => SegmentCustomer(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? 'Tanpa nama').toString(),
        phone: (j['phone'] ?? '').toString(),
        frequency: _int(j['frequency']),
        monetary: _int(j['monetary']),
        recencyDays: j['recency_days'] == null ? null : _int(j['recency_days']),
      );
}

/// Satu segmen pelanggan + daftar anggotanya.
class CustomerSegment {
  const CustomerSegment({
    required this.key,
    required this.label,
    required this.description,
    required this.count,
    required this.customers,
  });

  final String key;
  final String label;
  final String description;
  final int count;
  final List<SegmentCustomer> customers;

  factory CustomerSegment.fromJson(Map<String, dynamic> j) => CustomerSegment(
        key: (j['key'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        count: _int(j['count']),
        customers: ((j['customers'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => SegmentCustomer.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// Hasil analisis segmentasi seluruh pelanggan.
class CustomerSegments {
  const CustomerSegments({required this.totalCustomers, required this.segments});
  final int totalCustomers;
  final List<CustomerSegment> segments;
}

class CustomerSegmentRepository {
  CustomerSegmentRepository({required DioClient client}) : _client = client;
  final DioClient _client;

  Future<CustomerSegments> fetchSegments() async {
    final res = await _client.get<dynamic>(ApiConstants.adminCustomerSegments);
    final data = (res.data is Map && res.data['data'] is Map)
        ? Map<String, dynamic>.from(res.data['data'] as Map)
        : Map<String, dynamic>.from(res.data as Map);
    return CustomerSegments(
      totalCustomers: _int(data['total_customers']),
      segments: ((data['segments'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => CustomerSegment.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  /// Kirim promo ke [segment] ('all' untuk semua). Mengembalikan jumlah terkirim.
  Future<int> broadcast({
    required String segment,
    required String title,
    required String body,
  }) async {
    final res = await _client.post<dynamic>(
      ApiConstants.adminBroadcast,
      data: {'segment': segment, 'title': title, 'body': body},
    );
    final data = res.data;
    final inner = (data is Map && data['data'] is Map) ? data['data'] : data;
    return _int(inner is Map ? inner['sent'] : 0);
  }
}

final customerSegmentRepositoryProvider =
    Provider<CustomerSegmentRepository>((ref) {
  return CustomerSegmentRepository(client: ref.watch(dioClientProvider));
});

final customerSegmentsProvider =
    FutureProvider.autoDispose<CustomerSegments>((ref) {
  return ref.watch(customerSegmentRepositoryProvider).fetchSegments();
});
