import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rehat_app/core/network/dio_client.dart';
import 'package:rehat_app/core/storage/secure_storage.dart';
import 'package:rehat_app/core/utils/responsive.dart';
import 'package:rehat_app/features/admin/data/admin_report_repository.dart';
import 'package:rehat_app/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:rehat_app/features/finance/data/finance_repository.dart';

/// Regresi tampilan layar lebar (Okt 2026): layar dulu melar sampai 1920px
/// (lingkaran stamp & sel kalender raksasa, baris label–nilai terpisah jauh).
/// Kini tata letak adaptif: grid/kolom bertambah di layar lebar, HP tetap.
class _FakeAdminReportRepository extends AdminReportRepository {
  _FakeAdminReportRepository() : super(client: DioClient(storage: SecureStorage()));

  @override
  Future<SalesReport> fetchSales(
          {String range = '7d', String? date, String? endDate, int? topLimit}) async =>
      const SalesReport(
        range: '7d',
        revenue: 0,
        cogs: 0,
        grossProfit: 0,
        grossMarginPct: 0,
        netProfit: 0,
        qrisRevenue: 0,
        cashRevenue: 0,
        expenses: 0,
        cashInDrawer: 0,
        orders: 0,
        itemsSold: 0,
        avgOrderValue: 0,
        series: [],
        topItems: [],
      );

  @override
  Future<ExpenseList> fetchExpenses({String range = '7d', String? date, String? endDate}) async =>
      const ExpenseList(items: [], total: 0);

  @override
  Future<Map<String, int>> fetchCalendar(String month) async => {};
}

void _view(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Kotak bertanda untuk mengukur posisi/lebar sel grid.
Widget _cell(int i) => SizedBox(key: ValueKey('cell$i'), height: 40);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  group('columnsFor', () {
    test('HP selalu satu kolom', () {
      expect(columnsFor(350, minItemWidth: 340), 1);
    });
    test('kolom bertambah mengikuti lebar & dibatasi maxColumns', () {
      expect(columnsFor(800, minItemWidth: 340), 2);
      expect(columnsFor(1600, minItemWidth: 340), 4);
      expect(columnsFor(1600, minItemWidth: 340, maxColumns: 3), 3);
    });
    test('lebar sempit ekstrem tetap ≥ 1', () {
      expect(columnsFor(10, minItemWidth: 340), 1);
    });
  });

  Future<void> pumpGrid(WidgetTester tester, double width) async {
    _view(tester, Size(width, 800));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(children: [
          ResponsiveGrid(
            minItemWidth: 340,
            maxColumns: 3,
            spacing: 12,
            children: [for (var i = 0; i < 5; i++) _cell(i)],
          ),
        ]),
      ),
    ));
  }

  testWidgets('ResponsiveGrid: HP satu kolom penuh-lebar', (tester) async {
    await pumpGrid(tester, 390);
    final a = tester.getRect(find.byKey(const ValueKey('cell0')));
    final b = tester.getRect(find.byKey(const ValueKey('cell1')));
    expect(a.width, 390);
    expect(b.top, greaterThan(a.bottom), reason: 'item kedua di bawah, bukan di samping');
  });

  testWidgets('ResponsiveGrid: desktop 3 kolom mengisi lebar', (tester) async {
    await pumpGrid(tester, 1200);
    final a = tester.getRect(find.byKey(const ValueKey('cell0')));
    final b = tester.getRect(find.byKey(const ValueKey('cell1')));
    final d = tester.getRect(find.byKey(const ValueKey('cell3')));
    expect(a.top, b.top, reason: 'sebaris');
    expect(a.width, closeTo((1200 - 24) / 3, 0.01));
    expect(d.left, a.left, reason: 'item ke-4 membuka baris kedua');
  });

  testWidgets('AdaptiveColumns: berdampingan di layar lebar, bertumpuk di HP',
      (tester) async {
    Widget app() => MaterialApp(
          home: Scaffold(
            body: AdaptiveColumns(
              left: [_cell(0)],
              right: [_cell(1)],
            ),
          ),
        );
    _view(tester, const Size(1400, 900));
    await tester.pumpWidget(app());
    var l = tester.getRect(find.byKey(const ValueKey('cell0')));
    var r = tester.getRect(find.byKey(const ValueKey('cell1')));
    expect(l.top, r.top);
    expect(r.left, greaterThan(l.right));

    _view(tester, const Size(390, 844));
    await tester.pumpWidget(app());
    l = tester.getRect(find.byKey(const ValueKey('cell0')));
    r = tester.getRect(find.byKey(const ValueKey('cell1')));
    expect(r.top, greaterThan(l.bottom));
  });

  testWidgets('sel kalender penjualan bertinggi tetap 56 di layar lebar',
      (tester) async {
    _view(tester, const Size(1920, 4000));
    final container = ProviderContainer(overrides: [
      adminReportRepositoryProvider.overrideWithValue(_FakeAdminReportRepository()),
      financeAccessProvider.overrideWith((ref) async => false),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AdminDashboardScreen()),
    ));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    final grid = find.byWidgetPredicate((w) =>
        w is GridView &&
        w.gridDelegate is SliverGridDelegateWithFixedCrossAxisCount &&
        (w.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
                .crossAxisCount ==
            7);
    expect(grid, findsOneWidget);
    final cell = find.descendant(of: grid, matching: find.text('28'));
    final cellBox = find.ancestor(of: cell, matching: find.byType(Container)).first;
    expect(tester.getSize(cellBox).height, 56,
        reason: 'dgn childAspectRatio, sel memanjang sebanding lebar layar');
  });
}
