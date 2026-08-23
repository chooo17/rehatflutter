import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rehat_app/core/network/dio_client.dart';
import 'package:rehat_app/core/storage/secure_storage.dart';
import 'package:rehat_app/features/admin/data/admin_report_repository.dart';
import 'package:rehat_app/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:rehat_app/features/finance/data/finance_repository.dart';

/// Widget test untuk dialog "Catat Pengeluaran" (`admin_dashboard_screen.dart`)
/// — perbaikan temuan I-6 (review pengeluaran-potong-amplop): lima mutasi di
/// bawah ini SEBELUMNYA lolos seluruh suite tanpa satu test pun merah. Test
/// murni di `admin_expense_bucket_test.dart` hanya menguji fungsi MURNI
/// (`resolveExpenseBucket`), TIDAK menguji apakah dialog & repository
/// benar-benar MEMAKAINYA -- mutasi yang mengganti pemanggilan
/// `resolveExpenseBucket(_bucket)` dengan literal `'emergency'`, atau yang
/// menghapus `'bucket'` dari payload `addExpense`, tidak tersentuh sama
/// sekali oleh test murni. Hanya widget test (atau test payload) yang
/// benar-benar merender dialog & memeriksa argumen yang diteruskan ke
/// repository bisa menangkap itu.
class _FakeAdminReportRepository extends AdminReportRepository {
  _FakeAdminReportRepository() : super(client: DioClient(storage: SecureStorage()));

  final List<({int amount, String? note, String? category, String bucket})>
      addExpenseCalls = [];
  final List<String> deleteExpenseCalls = [];

  /// Bila di-set, `fetchExpenses` mengembalikan daftar ini (dipakai untuk
  /// menguji tombol hapus & dialog konfirmasi -- C-1 sisi Flutter).
  ExpenseList expensesToReturn = const ExpenseList(items: [], total: 0);

  /// Bila di-set, `deleteExpense` MENGGANTUNG sampai completer ini
  /// diselesaikan manual -- dipakai untuk menguji tombol hapus dinonaktifkan
  /// selama request in-flight (C-1).
  Completer<void>? deleteExpensePending;

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
      expensesToReturn;

  @override
  Future<Map<String, int>> fetchCalendar(String month) async => {};

  @override
  Future<void> addExpense(
      {required int amount,
      String? note,
      String? category,
      required String bucket}) async {
    addExpenseCalls.add((amount: amount, note: note, category: category, bucket: bucket));
  }

  @override
  Future<void> deleteExpense(String id) async {
    deleteExpenseCalls.add(id);
    final pending = deleteExpensePending;
    if (pending != null) await pending.future;
  }
}

Future<void> _mountDashboard(
    WidgetTester tester, ProviderContainer container) async {
  // Viewport besar -- ListView (bukan .builder) tetap melakukan virtualisasi
  // berdasar cacheExtent; tanpa ini, bagian bawah layar (`_ExpensesSection`,
  // tempat dialog "Catat Pengeluaran" dipicu) tidak pernah dibangun sama
  // sekali, "Catat" tak pernah ditemukan finder walau kodenya benar.
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
  // Biarkan fetchSales/fetchExpenses/fetchCalendar (semuanya resolve
  // seketika di fake) & financeAccessProvider selesai.
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

void main() {
  // `_ExpenseRow` memformat tanggal lewat `Formatters.tanggalJam` (locale
  // 'id_ID') -- tanpa ini, test C-1 yang merender baris pengeluaran
  // (dengan `expensesToReturn`) melempar `LocaleDataException`.
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  testWidgets(
      'MUTASI I-6 (default dialog) -- Simpan ditekan TANPA mengubah pilihan '
      'pos harus mengirim bucket restock, BUKAN personal', (tester) async {
    final repo = _FakeAdminReportRepository();
    final container = ProviderContainer(overrides: [
      adminReportRepositoryProvider.overrideWithValue(repo),
      financeAccessProvider.overrideWith((ref) async => false),
    ]);
    addTearDown(container.dispose);

    await _mountDashboard(tester, container);

    await tester.tap(find.text('Catat'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '50000');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(repo.addExpenseCalls, hasLength(1));
    expect(repo.addExpenseCalls.single.bucket, 'restock',
        reason: 'default pos dialog HARUS restock (perilaku lama) -- '
            'mutasi yang mengganti default jadi personal tidak boleh lolos');
  });

  testWidgets(
      'MUTASI I-6 (dialog selalu kirim emergency) -- memilih pos LAIN di '
      'dropdown harus mengirim pos yang DIPILIH, bukan literal emergency',
      (tester) async {
    final repo = _FakeAdminReportRepository();
    final container = ProviderContainer(overrides: [
      adminReportRepositoryProvider.overrideWithValue(repo),
      financeAccessProvider.overrideWith((ref) async => false),
    ]);
    addTearDown(container.dispose);

    await _mountDashboard(tester, container);

    await tester.tap(find.text('Catat'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '75000');

    // Buka dropdown pos & pilih "Operasional" (BUKAN emergency/darurat).
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Operasional').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(repo.addExpenseCalls, hasLength(1));
    expect(repo.addExpenseCalls.single.bucket, 'operational',
        reason: 'dialog harus mengirim pos yang benar-benar dipilih '
            'pengguna -- mutasi yang mengganti argumen jadi literal '
            "'emergency' tidak boleh lolos");
  });

  testWidgets(
      'MUTASI I-6 (addExpense tidak kirim bucket) -- payload yang dikirim ke '
      'repository WAJIB memuat argumen bucket eksplisit', (tester) async {
    final repo = _FakeAdminReportRepository();
    final container = ProviderContainer(overrides: [
      adminReportRepositoryProvider.overrideWithValue(repo),
      financeAccessProvider.overrideWith((ref) async => false),
    ]);
    addTearDown(container.dispose);

    await _mountDashboard(tester, container);

    await tester.tap(find.text('Catat'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '10000');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(repo.addExpenseCalls, hasLength(1));
    // `bucket` di `_FakeAdminReportRepository.addExpense` adalah parameter
    // WAJIB (`required String bucket`) -- kalau `_add()` di
    // `admin_dashboard_screen.dart` berhenti mengirimnya, ini gagal compile,
    // bukan gagal saat runtime. Assert eksplisit di bawah tetap menjaga
    // niatnya terdokumentasi & memastikan nilainya bukan string kosong/null.
    expect(repo.addExpenseCalls.single.bucket, isNotEmpty);
  });

  group('C-1 (hapus pengeluaran) -- dialog konfirmasi + tombol dinonaktifkan saat in-flight', () {
    ExpenseItem sampleExpense() => ExpenseItem(
          id: 'exp-1',
          amount: 50000,
          note: 'Token listrik',
          bucket: 'operational',
          spentAt: DateTime.utc(2026, 8, 10, 3, 0, 0),
        );

    testWidgets('menekan ikon hapus menampilkan dialog konfirmasi -- deleteExpense BELUM terpanggil sebelum konfirmasi',
        (tester) async {
      final repo = _FakeAdminReportRepository()
        ..expensesToReturn = ExpenseList(items: [sampleExpense()], total: 50000);
      final container = ProviderContainer(overrides: [
        adminReportRepositoryProvider.overrideWithValue(repo),
        financeAccessProvider.overrideWith((ref) async => false),
      ]);
      addTearDown(container.dispose);

      await _mountDashboard(tester, container);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Hapus pengeluaran?'), findsOneWidget);
      expect(repo.deleteExpenseCalls, isEmpty,
          reason: 'dialog konfirmasi wajib tampil DULU -- deleteExpense tidak boleh '
              'terpanggil sebelum pengguna menekan tombol Hapus di dialog');
    });

    testWidgets('menekan Batal di dialog konfirmasi -- deleteExpense TIDAK PERNAH terpanggil', (tester) async {
      final repo = _FakeAdminReportRepository()
        ..expensesToReturn = ExpenseList(items: [sampleExpense()], total: 50000);
      final container = ProviderContainer(overrides: [
        adminReportRepositoryProvider.overrideWithValue(repo),
        financeAccessProvider.overrideWith((ref) async => false),
      ]);
      addTearDown(container.dispose);

      await _mountDashboard(tester, container);
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(repo.deleteExpenseCalls, isEmpty);
    });

    testWidgets(
        'MUTASI C-1 (dobel-tap saat in-flight): tombol hapus berganti jadi spinner selama request '
        'berjalan -- ikon hapus tidak bisa ditekan lagi, hanya SATU panggilan deleteExpense',
        (tester) async {
      final repo = _FakeAdminReportRepository()
        ..expensesToReturn = ExpenseList(items: [sampleExpense()], total: 50000)
        ..deleteExpensePending = Completer<void>();
      final container = ProviderContainer(overrides: [
        adminReportRepositoryProvider.overrideWithValue(repo),
        financeAccessProvider.overrideWith((ref) async => false),
      ]);
      addTearDown(container.dispose);

      await _mountDashboard(tester, container);
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pump(); // request dikirim, SENGAJA dibiarkan pending

      expect(repo.deleteExpenseCalls, hasLength(1));
      // Selama request pertama masih di jalan, ikon hapus HARUS sudah
      // berganti jadi spinner -- tidak ada lagi ikon yang bisa ditekan.
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing,
          reason: 'ikon hapus wajib diganti indikator loading selama request '
              'in-flight, supaya tak bisa di-tap dua kali');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Selesaikan request yang tadi menggantung supaya tak membocorkan timer.
      // `pumpAndSettle` TIDAK dipakai di sini -- `CircularProgressIndicator`
      // indeterminate berputar tanpa henti, jadi `pumpAndSettle` akan
      // timeout menunggu animasi berhenti (tak pernah).
      repo.deleteExpensePending!.complete();
      await tester.pump();
      await tester.pump();
      expect(repo.deleteExpenseCalls, hasLength(1),
          reason: 'total panggilan deleteExpense tetap SATU -- tak ada jalan '
              'untuk men-tap tombol kedua kalinya selagi in-flight');
    });
  });
}
