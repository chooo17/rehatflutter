import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/core/network/dio_client.dart';
import 'package:rehat_app/core/storage/secure_storage.dart';
import 'package:rehat_app/features/admin/data/admin_report_repository.dart';

/// `AdminReportRepository.fetchSales`/`fetchExpenses` -- filter rentang
/// tanggal kustom. Query param JARINGAN sungguhan (`end`) diverifikasi lewat
/// adapter Dio palsu (pola sama seperti admin_report_repository_expense_test.dart),
/// bukan fake repository yang tidak pernah menyentuh kode aslinya.
class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;
  String body = '{"success":true,"data":{}}';

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    lastOptions = options;
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _CapturingAdapter adapter;
  late AdminReportRepository repo;

  setUp(() {
    adapter = _CapturingAdapter();
    final client = DioClient(storage: SecureStorage());
    client.raw.interceptors.clear();
    client.raw.httpClientAdapter = adapter;
    repo = AdminReportRepository(client: client);
  });

  test('fetchSales mengirim query `end` saat endDate diisi', () async {
    await repo
        .fetchSales(date: '2026-07-01', endDate: '2026-07-10')
        .timeout(const Duration(seconds: 10));

    final uri = adapter.lastOptions!.uri;
    expect(uri.queryParameters['date'], '2026-07-01');
    expect(uri.queryParameters['end'], '2026-07-10');
  });

  test('fetchSales TIDAK mengirim query `end` saat endDate null', () async {
    await repo.fetchSales(date: '2026-07-01').timeout(const Duration(seconds: 10));

    final uri = adapter.lastOptions!.uri;
    expect(uri.queryParameters['date'], '2026-07-01');
    expect(uri.queryParameters.containsKey('end'), isFalse);
  });

  test('fetchExpenses mengirim query `end` saat endDate diisi', () async {
    adapter.body = '{"success":true,"data":{"items":[],"total":0}}';
    await repo
        .fetchExpenses(date: '2026-07-01', endDate: '2026-07-10')
        .timeout(const Duration(seconds: 10));

    final uri = adapter.lastOptions!.uri;
    expect(uri.queryParameters['end'], '2026-07-10');
  });
}
