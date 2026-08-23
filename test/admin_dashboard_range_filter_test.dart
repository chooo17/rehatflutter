import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rehat_app/core/constants/app_colors.dart';
import 'package:rehat_app/core/network/dio_client.dart';
import 'package:rehat_app/core/storage/secure_storage.dart';
import 'package:rehat_app/features/admin/data/admin_report_repository.dart';
import 'package:rehat_app/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:rehat_app/features/finance/data/finance_repository.dart';

/// Widget test untuk saling-eksklusifitas tiga cara memfilter Laporan
/// Penjualan (pill Hari ini/7 Hari/30 Hari, tombol tanggal tunggal, tombol
/// rentang tanggal kustom) di `admin_dashboard_screen.dart`.
///
/// Wiring ini SUDAH ADA (commit 915928b) tapi TIDAK PERNAH punya test — celah
/// yang review final menandai sebagai temuan Penting: mutasi yang diam-diam
/// menghapus salah satu baris `.state = null` (mis. di `pickDate()` atau di
/// `onPressed` pill) akan lolos seluruh suite tanpa satu test pun merah,
/// menghidupkan lagi kelas bug "dua kartu menampilkan periode berbeda" yang
/// jadi alasan fitur rentang tanggal ini dibangun.
class _FakeAdminReportRepository extends AdminReportRepository {
  _FakeAdminReportRepository() : super(client: DioClient(storage: SecureStorage()));

  @override
  Future<SalesReport> fetchSales({String range = '7d', String? date, String? endDate}) async =>
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

Future<void> _mountDashboard(WidgetTester tester, ProviderContainer container) async {
  // Viewport besar -- sama seperti admin_expense_dialog_test.dart -- supaya
  // ListView memvirtualisasi cukup jauh agar tombol tanggal/rentang di dekat
  // atas tetap ter-render dengan aman.
  tester.view.physicalSize = const Size(1000, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AdminDashboardScreen()),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

ProviderContainer _buildContainer(_FakeAdminReportRepository repo) {
  return ProviderContainer(overrides: [
    adminReportRepositoryProvider.overrideWithValue(repo),
    financeAccessProvider.overrideWith((ref) async => false),
  ]);
}

void main() {
  setUpAll(() async {
    // Formatters.rentang()/tanggal() memakai locale 'id_ID' secara tetap
    // (lihat formatters.dart) -- tanpa ini, merender tombol rentang/tanggal
    // aktif melempar LocaleDataException.
    await initializeDateFormatting('id_ID');
  });

  testWidgets(
      'menekan pill "Hari ini" saat rentang tanggal aktif menonaktifkan '
      'KEDUA filter tanggal (salesDateProvider & salesDateRangeProvider '
      'sama-sama kembali null)', (tester) async {
    final repo = _FakeAdminReportRepository();
    final container = _buildContainer(repo);
    addTearDown(container.dispose);

    await _mountDashboard(tester, container);

    final now = DateTime.now();
    final range = DateTimeRange(
      start: DateTime(now.year - 1, 1, 1),
      end: DateTime(now.year - 1, 1, 10),
    );
    container.read(salesDateRangeProvider.notifier).state = range;
    await tester.pump();
    await tester.pump();

    expect(container.read(salesDateRangeProvider), isNotNull,
        reason: 'sanity check -- rentang harus tersimpan dulu sebelum pill ditekan');

    await tester.tap(find.text('Hari ini'));
    await tester.pumpAndSettle();

    expect(container.read(salesDateProvider), isNull,
        reason: 'memilih pill wajib meng-null-kan filter tanggal tunggal');
    expect(container.read(salesDateRangeProvider), isNull,
        reason: 'memilih pill wajib meng-null-kan filter rentang tanggal -- '
            'kalau tidak, kartu laporan & kalender bisa menampilkan periode '
            'berbeda (bug class yang fitur ini dibangun untuk mencegah)');
    expect(container.read(salesRangeProvider), 'today');
  });

  testWidgets(
      'memilih tanggal tunggal lewat showDatePicker sungguhan (tap tombol → '
      'konfirmasi dialog OK) saat rentang tanggal aktif menonaktifkan filter '
      'rentang', (tester) async {
    final repo = _FakeAdminReportRepository();
    final container = _buildContainer(repo);
    addTearDown(container.dispose);

    await _mountDashboard(tester, container);

    final now = DateTime.now();
    final range = DateTimeRange(
      start: DateTime(now.year - 1, 1, 1),
      end: DateTime(now.year - 1, 1, 10),
    );
    container.read(salesDateRangeProvider.notifier).state = range;
    await tester.pump();
    await tester.pump();

    expect(container.read(salesDateRangeProvider), isNotNull);

    // Jalur nyata: tap tombol "Pilih tanggal" -> showDatePicker() Material
    // sungguhan terbuka -> konfirmasi dengan tombol OK (initialDate default
    // dipakai apa adanya, tak perlu memilih hari lain di kalender).
    await tester.tap(find.text('Pilih tanggal'));
    await tester.pumpAndSettle();

    expect(find.text('OK'), findsOneWidget,
        reason: 'dialog showDatePicker Material harus terbuka dengan tombol OK');

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(container.read(salesDateProvider), isNotNull,
        reason: 'tanggal hasil pilihan (initialDate default) harus tersimpan');
    expect(container.read(salesDateRangeProvider), isNull,
        reason: 'memilih tanggal tunggal wajib meng-null-kan filter rentang '
            'yang sebelumnya aktif -- ini baris yang paling rawan hilang '
            'diam-diam tanpa test (pickDate() di admin_dashboard_screen.dart)');
  });

  testWidgets(
      'rentang tanggal lebih dari 90 hari via showDateRangePicker sungguhan '
      '(mode input, tap OK) DITOLAK -- provider tidak ditulis & SnackBar '
      'merah muncul', (tester) async {
    final repo = _FakeAdminReportRepository();
    final container = _buildContainer(repo);
    addTearDown(container.dispose);

    await _mountDashboard(tester, container);

    expect(container.read(salesDateRangeProvider), isNull);

    await tester.tap(find.text('Rentang tanggal'));
    await tester.pumpAndSettle();

    // Beralih dari kalender ke mode input teks (ikon edit Material 3) --
    // jauh lebih andal daripada mengetuk sel kalender lintas bulan untuk
    // memilih dua tanggal berjarak >90 hari.
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));

    // Rentang 1 Jan -> 1 Mei tahun lalu = 121 hari (>90), selalu di masa
    // lalu relatif ke "sekarang" jadi selalu berada dalam batas firstDate
    // (now.year - 2) .. lastDate (now) apa pun kapan test ini dijalankan.
    final lastYear = DateTime.now().year - 1;
    final startText =
        '01/01/${lastYear.toString().padLeft(4, '0')}'; // format Material default: mm/dd/yyyy
    final endText = '05/01/${lastYear.toString().padLeft(4, '0')}';
    await tester.enterText(fields.first, startText);
    await tester.pump();
    await tester.enterText(fields.last, endText);
    await tester.pump();

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(container.read(salesDateRangeProvider), isNull,
        reason: 'rentang >90 hari tidak boleh pernah ditulis ke '
            'salesDateRangeProvider -- guard `if (spanDays > 90)` di '
            'pickDateRange() wajib return lebih dulu');
    expect(find.text('Rentang maksimal 90 hari'), findsOneWidget,
        reason: 'SnackBar penolakan wajib tampil supaya pengguna tahu '
            'kenapa rentang tak berubah');

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.backgroundColor, AppColors.error,
        reason: 'temuan review Minor: SnackBar penolakan harus merah '
            '(AppColors.error), bukan warna netral default');
  });
}
