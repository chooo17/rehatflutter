import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/core/network/api_exception.dart';

DioException _bad(Map<String, dynamic> data, {int status = 400}) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: status, data: data),
    );

void main() {
  test('VALIDATION_ERROR dengan details menyertakan field + pesan pertama', () {
    final e = ApiException.fromDio(_bad({
      'success': false,
      'error': {
        'code': 'VALIDATION_ERROR',
        'message': 'Data tidak valid',
        'details': [
          {'field': 'delivery_radius_m', 'message': 'min 500'},
          {'field': 'x', 'message': 'y'},
        ],
      },
    }));
    expect(e.message, contains('delivery_radius_m'));
    expect(e.message, contains('min 500'));
    expect(e.message, contains('Data tidak valid'));
    expect(e.code, 'VALIDATION_ERROR');
  });

  test('tanpa details pesan tidak berubah', () {
    final e = ApiException.fromDio(_bad({
      'error': {'code': 'VALIDATION_ERROR', 'message': 'Data tidak valid'},
    }));
    expect(e.message, 'Data tidak valid');
  });

  test('code lain dengan details tidak diubah', () {
    final e = ApiException.fromDio(_bad({
      'error': {'code': 'NOPE', 'message': 'Gagal', 'details': [{'field': 'a', 'message': 'b'}]},
    }));
    expect(e.message, 'Gagal');
  });
}
