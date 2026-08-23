import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/core/constants/app_fonts.dart';
import 'package:rehat_app/core/constants/app_theme.dart';
import 'package:rehat_app/core/network/dio_client.dart';
import 'package:rehat_app/core/storage/secure_storage.dart';
import 'package:rehat_app/features/stock/data/stock_repository.dart';
import 'package:rehat_app/features/stock/presentation/ingredients_screen.dart';

/// Widget test layar Master Bahan (Manajemen Stok Fase A, Task 6). Harness
/// SAMA persis dengan `finance_overview_screen_test.dart` (360×800 logis,
/// font asli, `AppTheme` asli) — 360×800 adalah ukuran HP standar yang
/// dipakai reviewer untuk menemukan overflow nyata di modul Keuangan;
/// dipakai lagi di sini untuk alasan yang sama.
///
/// Fake repository di bawah TIDAK menyentuh jaringan sama sekali (beda dari
/// `stock_repository_test.dart` yang sengaja menembus adapter Dio palsu) —
/// tugasnya di sini murni merekam pemanggilan `createIngredient` supaya
/// bisa dibuktikan validasi klien (form kosong, isi per satuan beli <= 0)
/// benar-benar MENGHENTIKAN pemanggilan sebelum sempat "menyentuh jaringan".
class _FakeStockRepository extends StockRepository {
  _FakeStockRepository({this.ingredients = const []})
      : super(client: DioClient(storage: SecureStorage()));

  final List<Map<String, dynamic>> createCalls = [];
  final List<Ingredient> ingredients;

  @override
  Future<List<Ingredient>> fetchIngredients({bool? activeOnly, String? abc}) async =>
      ingredients;

  @override
  Future<Ingredient> createIngredient({
    required String name,
    required String baseUnit,
    required String purchaseUnit,
    required double unitsPerPurchase,
    required double purchasePrice,
    double? minStock,
    String? abcClass,
  }) async {
    createCalls.add({
      'name': name,
      'baseUnit': baseUnit,
      'purchaseUnit': purchaseUnit,
      'unitsPerPurchase': unitsPerPurchase,
      'purchasePrice': purchasePrice,
      'minStock': minStock,
      'abcClass': abcClass,
    });
    return Ingredient(
      id: 'new-1',
      name: name,
      baseUnit: baseUnit,
      purchaseUnit: purchaseUnit,
      unitsPerPurchase: unitsPerPurchase,
      purchasePrice: purchasePrice,
      costPerBase: unitsPerPurchase > 0 ? purchasePrice / unitsPerPurchase : 0,
      abcClass: abcClass ?? 'C',
    );
  }
}

/// `flutter test` TIDAK memuat font kustom yang dibundel (`assets/fonts/`)
/// secara default — teks dirender dengan font fallback generik yang lebar
/// glyph-nya beda dari Inter sungguhan. Tanpa ini, overflow/exception layout
/// bisa PALSU (font pengganti lebih lebar) atau TERSEMBUNYI (font pengganti
/// lebih sempit). Sama pola & alasan dengan `finance_overview_screen_test.dart`.
Future<void> _loadAppFonts() async {
  final inter = FontLoader(AppFonts.body)..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
  await inter.load();
  final cormorant = FontLoader(AppFonts.display)
    ..addFont(rootBundle.load('assets/fonts/CormorantGaramond.ttf'));
  await cormorant.load();
}

void main() {
  setUpAll(_loadAppFonts);

  // 360×800 logis @ device pixel ratio 3.0 == 1080×2400 fisik — ukuran HP
  // nyata standar, sama dengan harness modul Keuangan.
  Future<void> setPhoneSize(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<_FakeStockRepository> renderAndOpenAddSheet(WidgetTester tester) async {
    final repo = _FakeStockRepository();
    final container = ProviderContainer(
      overrides: [stockRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await setPhoneSize(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.build(Brightness.light),
          home: const IngredientsScreen(),
        ),
      ),
    );
    // Biarkan ingredientsProvider (FutureProvider.autoDispose) resolve ke
    // daftar kosong.
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets(
      'render layar kosong 360×800 dengan font & tema asli → nol exception layout',
      (tester) async {
    final repo = _FakeStockRepository();
    final container = ProviderContainer(
      overrides: [stockRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await setPhoneSize(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.build(Brightness.light),
          home: const IngredientsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Master Bahan'), findsOneWidget);
    expect(find.textContaining('Belum ada bahan'), findsOneWidget);
  });

  testWidgets(
      'render daftar bahan TERISI 360×800 → ListTile bahan punya Material '
      'ancestor sendiri (efek tap ink splash/highlight terlihat, bukan '
      '"ditembus" ke Material Scaffold yang jauh di atas NeuCard)',
      (tester) async {
    final repo = _FakeStockRepository(ingredients: const [
      Ingredient(
        id: 'ing-kopi',
        name: 'Kopi Arabika',
        baseUnit: 'g',
        purchaseUnit: 'kg',
        unitsPerPurchase: 1000,
        purchasePrice: 150000,
        costPerBase: 150,
        abcClass: 'A',
      ),
    ]);
    final container = ProviderContainer(
      overrides: [stockRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await setPhoneSize(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.build(Brightness.light),
          home: const IngredientsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Kopi Arabika'), findsOneWidget);

    final listTileFinder = find.byType(ListTile);
    expect(listTileFinder, findsOneWidget);

    // ListTile SELALU menemukan *suatu* Material ancestor jauh di atasnya
    // (mis. milik Scaffold, `MaterialType.canvas`) — itu tidak cukup untuk
    // membuktikan fix ini, karena assertion Flutter yang dilanggar sebelum
    // fix menyoal Material yang LANGSUNG membungkusnya. Bukti yang benar:
    // ada Material `type: transparency` sebagai ancestor — persis yang
    // ditambahkan `Material(type: MaterialType.transparency)` di dalam
    // NeuCard. Tanpa fix, tidak ada Material transparency sama sekali di
    // sini (satu-satunya Material ancestor adalah milik Scaffold, `canvas`).
    final materialAncestors =
        find.ancestor(of: listTileFinder, matching: find.byType(Material));
    final transparencyAncestors = tester
        .widgetList<Material>(materialAncestors)
        .where((m) => m.type == MaterialType.transparency);
    expect(transparencyAncestors, isNotEmpty,
        reason: 'ListTile bahan wajib dibungkus Material(type: transparency) '
            'sendiri di dalam NeuCard, sama pola dengan RecipeListScreen — '
            'tanpa ini efek tap (ink splash/highlight) ListTile tak pernah '
            'terlihat walau tetap bisa ditekan');
  });

  testWidgets(
      'render form tambah bahan (bottom sheet) 360×800 → nol exception layout',
      (tester) async {
    await renderAndOpenAddSheet(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Tambah Bahan'), findsOneWidget);
  });

  testWidgets(
      'form KOSONG ditolak: tekan Simpan tanpa mengisi apa pun tidak memanggil '
      'createIngredient & menampilkan pesan validasi', (tester) async {
    final repo = await renderAndOpenAddSheet(tester);

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(repo.createCalls, isEmpty,
        reason: 'form kosong wajib ditolak SEBELUM menyentuh jaringan sama sekali');
    expect(find.text('Nama wajib diisi'), findsOneWidget);
    expect(find.text('Satuan beli wajib diisi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'GIGI WAJIB: isi per satuan beli 0 (satu-satunya field kosong lainnya '
      'terisi) ditolak KLIEN, createIngredient tidak dipanggil', (tester) async {
    final repo = await renderAndOpenAddSheet(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Nama'), 'Kopi Arabika');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Satuan beli'),
      'kg',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Isi per satuan beli'),
      '0',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Harga per satuan beli (Rp)'),
      '150000',
    );
    // Pilih satuan dasar "gram (g)" lewat dropdown.
    await tester.tap(find.text('Satuan dasar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('gram (g)').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(repo.createCalls, isEmpty,
        reason: 'isi per satuan beli <= 0 wajib ditolak KLIEN sebelum '
            'menyentuh jaringan (unitsPerPurchaseError dari Task 5)');
    expect(find.textContaining('lebih dari 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'GIGI WAJIB: pratinjau harga per satuan dasar untuk kopi 1 kg Rp150.000 '
      'menampilkan "Rp 150/gram" SAAT MENGETIK (sebelum submit)', (tester) async {
    await renderAndOpenAddSheet(tester);

    // Pilih satuan dasar "gram (g)" dulu.
    await tester.tap(find.text('Satuan dasar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('gram (g)').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Isi per satuan beli'),
      '1000',
    );
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Harga per satuan beli (Rp)'),
      '150000',
    );
    await tester.pump();

    expect(find.textContaining('Rp 150/gram'), findsOneWidget,
        reason: 'brief Task 6: pratinjau harga per satuan dasar harus muncul '
            'LANGSUNG saat mengetik, memakai formatCostPerUnit/unitLabel dari '
            'Task 5 (stock_view.dart) — bentuknya "Rp 150/gram", bukan '
            '"Rp150/gram" tanpa spasi (lihat Formatters.rupiah)');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'submit lengkap & valid → createIngredient dipanggil dengan nilai yang benar, '
      'sheet ditutup', (tester) async {
    final repo = await renderAndOpenAddSheet(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Nama'), 'Kopi Arabika');
    await tester.tap(find.text('Satuan dasar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('gram (g)').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Satuan beli'),
      'kg',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Isi per satuan beli'),
      '1000',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Harga per satuan beli (Rp)'),
      '150000',
    );
    await tester.pump();

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(repo.createCalls.length, 1);
    final call = repo.createCalls.single;
    expect(call['name'], 'Kopi Arabika');
    expect(call['baseUnit'], 'g');
    expect(call['purchaseUnit'], 'kg');
    expect(call['unitsPerPurchase'], 1000.0);
    expect(call['purchasePrice'], 150000.0);
    expect(call['abcClass'], 'C', reason: 'golongan ABC default C bila tak diubah pengguna');
    expect(find.text('Tambah Bahan'), findsNothing,
        reason: 'sheet wajib tertutup setelah submit sukses');
    expect(tester.takeException(), isNull);
  });
}
