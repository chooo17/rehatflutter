import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/core/network/dio_client.dart';
import 'package:rehat_app/core/storage/secure_storage.dart';
import 'package:rehat_app/features/admin/data/admin_report_repository.dart';

/// `AdminReportRepository.addExpense` -- perbaikan temuan I-6 (review
/// pengeluaran-potong-amplop): payload JARINGAN sungguhan yang dikirim ke
/// `POST /admin/expenses` WAJIB memuat `bucket`. Ini TIDAK bisa dibuktikan
/// oleh widget test manapun yang mem-fake seluruh `AdminReportRepository`
/// (fake macam itu tidak pernah menyentuh kode `addExpense` yang sebenarnya)
/// -- harus lewat adapter Dio palsu yang menangkap `RequestOptions.data`
/// persis seperti yang benar-benar dikirim.
class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    lastOptions = options;
    return ResponseBody.fromString(
      '{"success":true,"data":{},"message":"OK"}',
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
  test(
      'MUTASI I-6 (addExpense tidak kirim bucket) -- payload POST /admin/expenses '
      'WAJIB memuat field bucket persis sesuai yang diminta pemanggil', () async {
    final adapter = _CapturingAdapter();
    final client = DioClient(storage: SecureStorage());
    // `AuthInterceptor` (dipasang otomatis oleh `DioClient`) membaca token
    // lewat `flutter_secure_storage`, yang memanggil MethodChannel platform
    // asli -- di lingkungan `flutter test` tanpa mock, panggilan itu
    // menggantung selamanya (bukan error, bukan timeout). Test ini hanya
    // peduli pada BODY request yang dikirim `addExpense`, bukan header
    // otorisasi, jadi interceptor auth dilepas dulu.
    client.raw.interceptors.clear();
    client.raw.httpClientAdapter = adapter;
    final repo = AdminReportRepository(client: client);

    await repo
        .addExpense(amount: 45000, note: 'Token listrik', bucket: 'operational')
        .timeout(const Duration(seconds: 10));

    final data = adapter.lastOptions!.data;
    expect(data, isA<Map>());
    expect((data as Map)['bucket'], 'operational',
        reason: 'payload jaringan sungguhan harus memuat pos yang dipilih '
            '-- mutasi yang menghapus `bucket` dari body tidak boleh lolos');
    expect(data['amount'], 45000);
  });
}
