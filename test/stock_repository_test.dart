import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/core/constants/api_constants.dart';
import 'package:rehat_app/core/network/api_exception.dart';
import 'package:rehat_app/core/network/dio_client.dart';
import 'package:rehat_app/core/storage/secure_storage.dart';
import 'package:rehat_app/features/stock/data/stock_repository.dart';

/// Menguji parsing model Manajemen Stok Fase A: tahan nilai null/hilang,
/// dan terutama tiga "gigi" yang wajib dibuktikan (brief Task 5, Step 5):
/// - `HppRow.pct` null terbaca NULL (bukan 0.0) saat `hasStored` false.
/// - `Ingredient.costPerBase` pecahan (3.5) terbaca UTUH, tidak dibulatkan.
/// - `MenuRecipe.complete` mengikuti field JSON `complete`, bukan hardcode true.
///
/// Grup `StockRepository network methods (Task 6)` di bawah menguji
/// `createIngredient`/`updateIngredient`/`deactivateIngredient` — ditulis
/// RETROAKTIF (implementasi datang lebih dulu dari implementer sebelumnya,
/// terputus sesi sebelum sempat menulis test). Pola adapter Dio palsu sama
/// dengan `admin_report_repository_expense_test.dart`: menangkap
/// `RequestOptions` SUNGGUHAN yang dikirim (method, path, body) dan
/// membalas respons berskenario, supaya bug seperti "field bucket hilang
/// dari payload" tidak lolos di belakang fake repository manapun.

/// Adapter Dio palsu yang menangkap request TERAKHIR dan membalas dengan
/// status/body yang diskenariokan per test.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter({required this.statusCode, required this.body});

  final int statusCode;
  final Map<String, dynamic> body;

  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// `AuthInterceptor` (dipasang otomatis oleh `DioClient`) membaca token
/// lewat `flutter_secure_storage`, yang memanggil MethodChannel platform
/// asli — di `flutter test` tanpa mock itu menggantung selamanya (bukan
/// error, bukan timeout). Test di sini hanya peduli pada request/response
/// yang lewat `_ScriptedAdapter`, jadi interceptor auth dilepas dulu (sama
/// pola dengan `admin_report_repository_expense_test.dart`).
DioClient _clientWith(_ScriptedAdapter adapter) {
  final client = DioClient(storage: SecureStorage());
  client.raw.interceptors.clear();
  client.raw.httpClientAdapter = adapter;
  return client;
}

void main() {
  group('Ingredient.fromJson', () {
    test('membaca baris lengkap (raw DB row, snake_case)', () {
      final i = Ingredient.fromJson({
        'id': 'ing-1',
        'name': 'Kopi Arabika',
        'base_unit': 'g',
        'purchase_unit': 'kg',
        'units_per_purchase': 1000,
        'purchase_price': 120000,
        'cost_per_base': 120,
        'min_stock': 500,
        'abc_class': 'A',
        'is_active': true,
      });
      expect(i.id, 'ing-1');
      expect(i.name, 'Kopi Arabika');
      expect(i.baseUnit, 'g');
      expect(i.purchaseUnit, 'kg');
      expect(i.unitsPerPurchase, 1000.0);
      expect(i.purchasePrice, 120000.0);
      expect(i.costPerBase, 120.0);
      expect(i.minStock, 500.0);
      expect(i.abcClass, 'A');
      expect(i.isActive, isTrue);
    });

    test('field hilang → nilai aman, tidak crash', () {
      final i = Ingredient.fromJson(const {'id': 'x', 'name': 'Y'});
      expect(i.baseUnit, '');
      expect(i.purchaseUnit, '');
      expect(i.unitsPerPurchase, 0.0);
      expect(i.purchasePrice, 0.0);
      expect(i.costPerBase, 0.0);
      expect(i.minStock, 0.0);
      expect(i.abcClass, '');
      expect(i.isActive, isTrue); // default aktif, sama pola FixedCost
    });

    test('GIGI WAJIB: cost_per_base pecahan (3,5) terbaca utuh, TIDAK dibulatkan jadi 4', () {
      final i = Ingredient.fromJson({'id': 'x', 'name': 'Es Batu', 'cost_per_base': 3.5});
      expect(i.costPerBase, 3.5,
          reason: 'es batu Rp35.000/10kg = Rp3,5/g — membulatkan ke 4 meleset ~14% di resep');
      expect(i.costPerBase, isNot(4));
      expect(i.costPerBase, isA<double>());
    });

    test('units_per_purchase, purchase_price, min_stock juga pecahan utuh (bukan int)', () {
      final i = Ingredient.fromJson({
        'id': 'x', 'name': 'Y',
        'units_per_purchase': 10.25,
        'purchase_price': 99.9,
        'min_stock': 2.75,
      });
      expect(i.unitsPerPurchase, 10.25);
      expect(i.purchasePrice, 99.9);
      expect(i.minStock, 2.75);
    });

    test('is_active false terbaca apa adanya', () {
      final i = Ingredient.fromJson({'id': 'x', 'name': 'Y', 'is_active': false});
      expect(i.isActive, isFalse);
    });
  });

  group('RecipeLine.fromJson', () {
    test('membaca satu baris (camelCase, dari GET recipe)', () {
      final l = RecipeLine.fromJson({
        'id': 'line-1',
        'ingredientId': 'ing-1',
        'ingredientName': 'Kopi Arabika',
        'baseUnit': 'g',
        'qtyBase': 18.5,
        'costPerBase': 120.0,
        'temperature': 'hot',
      });
      expect(l.id, 'line-1');
      expect(l.ingredientId, 'ing-1');
      expect(l.ingredientName, 'Kopi Arabika');
      expect(l.baseUnit, 'g');
      expect(l.qtyBase, 18.5);
      expect(l.costPerBase, 120.0);
      expect(l.temperature, 'hot');
    });

    test('temperature null → berlaku kedua varian, bukan string "null"', () {
      final l = RecipeLine.fromJson({
        'ingredientId': 'ing-1', 'ingredientName': 'Gula', 'baseUnit': 'g', 'qtyBase': 10,
        'temperature': null,
      });
      expect(l.temperature, isNull);
    });

    test('field hilang → nilai aman', () {
      final l = RecipeLine.fromJson(const {});
      expect(l.ingredientId, '');
      expect(l.ingredientName, '');
      expect(l.baseUnit, '');
      expect(l.qtyBase, 0.0);
      expect(l.costPerBase, 0.0);
      expect(l.temperature, isNull);
    });

    test('qtyBase pecahan utuh, tidak dibulatkan', () {
      final l = RecipeLine.fromJson({'qtyBase': 18.5});
      expect(l.qtyBase, 18.5);
    });
  });

  group('MenuRecipe.fromJson', () {
    test('membaca resep lengkap dengan beberapa baris + hpp', () {
      final r = MenuRecipe.fromJson({
        'lines': [
          {'ingredientId': 'a', 'ingredientName': 'Kopi', 'baseUnit': 'g', 'qtyBase': 18, 'temperature': null},
          {'ingredientId': 'b', 'ingredientName': 'Susu', 'baseUnit': 'ml', 'qtyBase': 150, 'temperature': 'iced'},
        ],
        'hpp': {'hot': 8500, 'iced': 9200},
        'complete': true,
      });
      expect(r.lines.length, 2);
      expect(r.lines.first.ingredientName, 'Kopi');
      expect(r.hppHot, 8500);
      expect(r.hppIced, 9200);
      expect(r.complete, isTrue);
    });

    test('respons kosong → lines kosong, hpp 0, complete false — bukan exception', () {
      final r = MenuRecipe.fromJson(const {});
      expect(r.lines, isEmpty);
      expect(r.hppHot, 0);
      expect(r.hppIced, 0);
      expect(r.complete, isFalse);
    });

    test('GIGI WAJIB: complete mengikuti field JSON, BUKAN hardcode true', () {
      final rFalse = MenuRecipe.fromJson({
        'lines': [
          {'ingredientId': 'a', 'ingredientName': 'Kopi', 'baseUnit': 'g', 'qtyBase': 18},
        ],
        'hpp': {'hot': 100, 'iced': 100},
        'complete': false,
      });
      expect(rFalse.complete, isFalse,
          reason: 'backend bisa membalas complete:false walau lines tidak kosong (kasus lain) — '
              'model wajib meneruskan field ini apa adanya, bukan menyimpulkan dari lines.isNotEmpty');

      final rTrue = MenuRecipe.fromJson({'lines': const [], 'hpp': {'hot': 0, 'iced': 0}, 'complete': true});
      expect(rTrue.complete, isTrue);
    });

    test('hpp.hot dan hpp.iced tidak tertukar', () {
      final r = MenuRecipe.fromJson({
        'lines': const [],
        'hpp': {'hot': 111, 'iced': 222},
        'complete': false,
      });
      expect(r.hppHot, 111);
      expect(r.hppIced, 222);
    });
  });

  group('HppRow.fromJson', () {
    test('membaca baris lengkap dengan storedCostPrice terisi', () {
      final row = HppRow.fromJson({
        'menuItemId': 'm1',
        'name': 'Espresso',
        'storedCostPrice': 8000,
        'computedHot': 8500,
        'computedIced': 9200,
        'delta': 500,
        'pct': 6.25,
        'complete': true,
        'hasStored': true,
      });
      expect(row.menuItemId, 'm1');
      expect(row.name, 'Espresso');
      expect(row.storedCostPrice, 8000);
      expect(row.computedHot, 8500);
      expect(row.computedIced, 9200);
      expect(row.delta, 500);
      expect(row.pct, 6.25);
      expect(row.complete, isTrue);
      expect(row.hasStored, isTrue);
    });

    test('GIGI WAJIB: hasStored false → pct terbaca NULL, BUKAN 0.0', () {
      final row = HppRow.fromJson({
        'menuItemId': 'm1', 'name': 'Menu Baru',
        'storedCostPrice': null, 'computedHot': 100, 'computedIced': 100,
        'delta': 100, 'pct': null, 'complete': true, 'hasStored': false,
      });
      expect(row.pct, isNull,
          reason: 'null berarti "belum ada harga lama untuk dibandingkan" — 0.0 berarti '
              '"pas sama harga lama". Menyamakan keduanya cacat rambu uang (lihat CLAUDE.md §4).');
      expect(row.pct, isNot(0.0));
      expect(row.hasStored, isFalse);
      expect(row.storedCostPrice, isNull);
    });

    test('pct 0.0 ASLI (hasStored true, delta 0) tetap terbaca 0.0, bukan ikut jadi null', () {
      final row = HppRow.fromJson({
        'menuItemId': 'm1', 'name': 'Menu Sama', 'storedCostPrice': 8000,
        'computedHot': 8000, 'computedIced': 8000, 'delta': 0, 'pct': 0.0,
        'complete': true, 'hasStored': true,
      });
      expect(row.pct, 0.0);
      expect(row.hasStored, isTrue);
    });

    test('delta negatif (HPP resep lebih rendah) terbaca apa adanya', () {
      final row = HppRow.fromJson({
        'menuItemId': 'm1', 'name': 'X', 'storedCostPrice': 10000,
        'computedHot': 8300, 'computedIced': 8300, 'delta': -1700, 'pct': -17.0,
        'complete': true, 'hasStored': true,
      });
      expect(row.delta, -1700);
      expect(row.pct, -17.0);
    });

    test('field hilang → nilai aman, tidak crash', () {
      final row = HppRow.fromJson(const {});
      expect(row.menuItemId, '');
      expect(row.name, '');
      expect(row.storedCostPrice, isNull);
      expect(row.computedHot, 0);
      expect(row.computedIced, 0);
      expect(row.delta, isNull);
      expect(row.pct, isNull);
      expect(row.complete, isFalse);
      expect(row.hasStored, isFalse);
    });
  });

  group('StockRepository network methods (Task 6)', () {
    test(
        'createIngredient mengirim payload lengkap (nama & satuan beli TRIM) '
        'ke POST /admin/stock/ingredients & mengurai respons 201', () async {
      final adapter = _ScriptedAdapter(statusCode: 201, body: {
        'success': true,
        'data': {
          'id': 'ing-9',
          'name': 'Kopi Arabika',
          'base_unit': 'g',
          'purchase_unit': 'kg',
          'units_per_purchase': 1000,
          'purchase_price': 150000,
          'cost_per_base': 150,
          'min_stock': 500,
          'abc_class': 'A',
          'is_active': true,
        },
      });
      final repo = StockRepository(client: _clientWith(adapter));

      final result = await repo
          .createIngredient(
            name: '  Kopi Arabika  ',
            baseUnit: 'g',
            purchaseUnit: ' kg ',
            unitsPerPurchase: 1000,
            purchasePrice: 150000,
            minStock: 500,
            abcClass: 'A',
          )
          .timeout(const Duration(seconds: 10));

      final sent = adapter.lastOptions!;
      expect(sent.method, 'POST');
      expect(sent.path, ApiConstants.stockIngredients);
      final data = sent.data as Map;
      expect(data['name'], 'Kopi Arabika', reason: 'nama wajib di-trim sebelum dikirim');
      expect(data['base_unit'], 'g');
      expect(data['purchase_unit'], 'kg', reason: 'satuan beli wajib di-trim sebelum dikirim');
      expect(data['units_per_purchase'], 1000);
      expect(data['purchase_price'], 150000);
      expect(data['min_stock'], 500);
      expect(data['abc_class'], 'A');

      expect(result.id, 'ing-9');
      expect(result.costPerBase, 150.0);
      expect(result.abcClass, 'A');
    });

    test(
        'createIngredient TIDAK mengirim min_stock/abc_class saat tak diisi '
        '(field opsional — backend yang menentukan default)', () async {
      final adapter = _ScriptedAdapter(statusCode: 201, body: {
        'success': true,
        'data': {'id': 'ing-1', 'name': 'Gula'},
      });
      final repo = StockRepository(client: _clientWith(adapter));

      await repo
          .createIngredient(
            name: 'Gula',
            baseUnit: 'g',
            purchaseUnit: 'kg',
            unitsPerPurchase: 1000,
            purchasePrice: 15000,
          )
          .timeout(const Duration(seconds: 10));

      final data = adapter.lastOptions!.data as Map;
      expect(data.containsKey('min_stock'), isFalse);
      expect(data.containsKey('abc_class'), isFalse);
    });

    test(
        'GIGI WAJIB: createIngredient 409 INGREDIENT_DUPLICATE_NAME dilempar '
        'sebagai ApiException apa adanya (code & message Bahasa Indonesia utuh)',
        () async {
      final adapter = _ScriptedAdapter(statusCode: 409, body: {
        'success': false,
        'error': {
          'code': 'INGREDIENT_DUPLICATE_NAME',
          'message': 'Nama bahan sudah dipakai.',
        },
      });
      final repo = StockRepository(client: _clientWith(adapter));

      await expectLater(
        repo
            .createIngredient(
              name: 'Kopi Arabika',
              baseUnit: 'g',
              purchaseUnit: 'kg',
              unitsPerPurchase: 1000,
              purchasePrice: 150000,
            )
            .timeout(const Duration(seconds: 10)),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.code, 'code', 'INGREDIENT_DUPLICATE_NAME')
              .having((e) => e.message, 'message', 'Nama bahan sudah dipakai.'),
        ),
      );
    });

    test(
        'updateIngredient (PATCH) mengirim HANYA field yang diisi (partial) '
        'ke path bahan yang benar & mengurai respons 200', () async {
      final adapter = _ScriptedAdapter(statusCode: 200, body: {
        'success': true,
        'data': {
          'id': 'ing-1',
          'name': 'Kopi Arabika',
          'purchase_price': 160000,
          'cost_per_base': 160,
        },
      });
      final repo = StockRepository(client: _clientWith(adapter));

      final result = await repo
          .updateIngredient('ing-1', purchasePrice: 160000)
          .timeout(const Duration(seconds: 10));

      final sent = adapter.lastOptions!;
      expect(sent.method, 'PATCH');
      expect(sent.path, ApiConstants.stockIngredient('ing-1'));
      final data = sent.data as Map;
      expect(data.keys, ['purchase_price'],
          reason: 'field lain yang TIDAK diisi tidak boleh ikut terkirim — '
              'backend membalas 400 EMPTY_PATCH hanya bila BENAR-BENAR kosong, '
              'tapi mengirim field yang tak dimaksud bisa menimpa nilai lain '
              'secara tak sengaja');
      expect(result.costPerBase, 160.0);
    });

    test('updateIngredient isActive:true mengirim is_active untuk reaktivasi bahan nonaktif',
        () async {
      final adapter = _ScriptedAdapter(statusCode: 200, body: {
        'success': true,
        'data': {'id': 'ing-1', 'name': 'Kopi Arabika', 'is_active': true},
      });
      final repo = StockRepository(client: _clientWith(adapter));

      final result = await repo
          .updateIngredient('ing-1', isActive: true)
          .timeout(const Duration(seconds: 10));

      final data = adapter.lastOptions!.data as Map;
      expect(data['is_active'], true);
      expect(result.isActive, isTrue);
    });

    test(
        'updateIngredient 404 INGREDIENT_NOT_FOUND dilempar sebagai ApiException apa adanya',
        () async {
      final adapter = _ScriptedAdapter(statusCode: 404, body: {
        'success': false,
        'error': {'code': 'INGREDIENT_NOT_FOUND', 'message': 'Bahan tidak ditemukan.'},
      });
      final repo = StockRepository(client: _clientWith(adapter));

      await expectLater(
        repo.updateIngredient('missing', purchasePrice: 1000).timeout(const Duration(seconds: 10)),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.code, 'code', 'INGREDIENT_NOT_FOUND'),
        ),
      );
    });

    test(
        'deactivateIngredient mengirim DELETE ke path bahan (menonaktifkan, '
        'BUKAN menghapus baris — dibuktikan lewat method HTTP & path yang '
        'benar-benar dikirim)', () async {
      final adapter = _ScriptedAdapter(statusCode: 200, body: {
        'success': true,
        'data': {'id': 'ing-1', 'name': 'Kopi Arabika', 'is_active': false},
      });
      final repo = StockRepository(client: _clientWith(adapter));

      await repo.deactivateIngredient('ing-1').timeout(const Duration(seconds: 10));

      final sent = adapter.lastOptions!;
      expect(sent.method, 'DELETE');
      expect(sent.path, ApiConstants.stockIngredient('ing-1'));
    });

    test(
        'deactivateIngredient 404 INGREDIENT_NOT_FOUND dilempar sebagai ApiException apa adanya',
        () async {
      final adapter = _ScriptedAdapter(statusCode: 404, body: {
        'success': false,
        'error': {'code': 'INGREDIENT_NOT_FOUND', 'message': 'Bahan tidak ditemukan.'},
      });
      final repo = StockRepository(client: _clientWith(adapter));

      await expectLater(
        repo.deactivateIngredient('missing').timeout(const Duration(seconds: 10)),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.code, 'code', 'INGREDIENT_NOT_FOUND'),
        ),
      );
    });
  });
}
