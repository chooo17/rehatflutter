import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/core/constants/app_fonts.dart';
import 'package:rehat_app/core/constants/app_theme.dart';
import 'package:rehat_app/core/network/dio_client.dart';
import 'package:rehat_app/core/storage/secure_storage.dart';
import 'package:rehat_app/features/admin/data/admin_report_repository.dart';
import 'package:rehat_app/features/menu/data/menu_repository.dart';
import 'package:rehat_app/features/stock/data/stock_repository.dart';
import 'package:rehat_app/features/stock/presentation/recipe_screen.dart';
import 'package:rehat_app/shared/models/menu_item_model.dart';

/// Widget test layar Resep (Manajemen Stok Fase A, Task 7). Harness SAMA
/// dengan `ingredients_screen_test.dart`/`finance_overview_screen_test.dart`
/// (360×800 logis, font asli, `AppTheme` asli).
///
/// Fake repository di bawah TIDAK menyentuh jaringan sama sekali — hanya
/// merekam pemanggilan `saveRecipe` supaya bisa dibuktikan baris resep
/// (tambah/hapus) & payload yang dikirim benar.
class _FakeStockRepository extends StockRepository {
  _FakeStockRepository({this.initialLines = const []})
      : super(client: DioClient(storage: SecureStorage()));

  final List<RecipeLine> initialLines;
  final List<List<RecipeLineInput>> saveCalls = [];

  /// Jumlah panggilan `fetchHppComparison` — dipakai untuk membuktikan
  /// `hppComparisonProvider` benar-benar DIBANGUN ULANG (bukan cuma
  /// `menuRecipeProvider` milik menu ini sendiri) setelah `_save()` sukses.
  int fetchHppComparisonCalls = 0;

  @override
  Future<List<HppRow>> fetchHppComparison() async {
    fetchHppComparisonCalls++;
    return const [];
  }

  @override
  Future<List<Ingredient>> fetchIngredients({bool? activeOnly, String? abc}) async => [
        const Ingredient(
          id: 'ing-kopi',
          name: 'Kopi Arabika',
          baseUnit: 'g',
          purchaseUnit: 'kg',
          unitsPerPurchase: 1000,
          purchasePrice: 150000,
          costPerBase: 150, // Rp150/gram
        ),
        const Ingredient(
          id: 'ing-susu',
          name: 'Susu UHT',
          baseUnit: 'ml',
          purchaseUnit: 'liter',
          unitsPerPurchase: 1000,
          purchasePrice: 20000,
          costPerBase: 20, // Rp20/ml
        ),
      ];

  @override
  Future<MenuRecipe> fetchRecipe(String menuItemId) async =>
      MenuRecipe(lines: initialLines, hppHot: 0, hppIced: 0, complete: initialLines.isNotEmpty);

  @override
  Future<void> saveRecipe(String menuItemId, List<RecipeLineInput> lines) async {
    saveCalls.add(lines);
  }
}

/// `flutter test` TIDAK memuat font kustom yang dibundel (`assets/fonts/`)
/// secara default — sama pola & alasan dengan `finance_overview_screen_test.dart`.
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
  // standar, sama dengan harness Master Bahan/modul Keuangan.
  Future<void> setPhoneSize(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<_FakeStockRepository> renderRecipeScreen(
    WidgetTester tester, {
    List<RecipeLine> initialLines = const [],
    int menuCostPrice = 0,
  }) async {
    final repo = _FakeStockRepository(initialLines: initialLines);
    final container = ProviderContainer(
      overrides: [
        stockRepositoryProvider.overrideWithValue(repo),
        allMenuItemsProvider.overrideWith((ref) async => [
              MenuItemModel(
                id: 'menu-1',
                name: 'Kopi Susu Gula Aren',
                price: 20000,
                costPrice: menuCostPrice,
              ),
            ]),
      ],
    );
    addTearDown(container.dispose);

    await setPhoneSize(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.build(Brightness.light),
          home: const RecipeScreen(menuItemId: 'menu-1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return repo;
  }

  testWidgets(
      'render layar entri resep KOSONG 360×800 dengan font & tema asli → nol exception layout',
      (tester) async {
    await renderRecipeScreen(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Kopi Susu Gula Aren'), findsOneWidget);
    expect(find.textContaining('Belum ada baris resep'), findsOneWidget);
  });

  testWidgets('tambah baris resep lewat tombol "Tambah Bahan" → baris baru muncul, nol exception layout',
      (tester) async {
    await renderRecipeScreen(tester);

    await tester.tap(find.text('Tambah Bahan'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Belum ada baris resep. Tekan "Tambah Bahan" untuk mulai.'), findsNothing);
    expect(find.widgetWithText(DropdownButtonFormField<String>, 'Bahan'), findsOneWidget);
  });

  testWidgets('hapus baris resep lewat ikon sampah → baris hilang', (tester) async {
    await renderRecipeScreen(tester);

    await tester.tap(find.text('Tambah Bahan'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.text('Belum ada baris resep. Tekan "Tambah Bahan" untuk mulai.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'GIGI WAJIB: HPP terhitung berubah SAAT TAKARAN DIUBAH (langsung, tanpa submit)',
      (tester) async {
    await renderRecipeScreen(tester);

    // Sebelum ada baris apa pun: HPP 0 untuk kedua varian.
    expect(find.text('Panas: Rp 0'), findsOneWidget);
    expect(find.text('Dingin: Rp 0'), findsOneWidget);

    await tester.tap(find.text('Tambah Bahan'));
    await tester.pumpAndSettle();

    // Pilih bahan "Kopi Arabika" (Rp150/gram) lewat dropdown.
    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Bahan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kopi Arabika').last);
    await tester.pumpAndSettle();

    // Isi takaran 20 gram -> HPP 20 * 150 = 3000, berlaku KEDUA varian
    // (suhu default "Berlaku keduanya").
    await tester.enterText(find.widgetWithText(TextFormField, 'Takaran'), '20');
    await tester.pump();

    expect(find.text('Panas: Rp 3.000'), findsOneWidget,
        reason: 'HPP terhitung wajib berubah LANGSUNG saat takaran diketik, tanpa submit');
    expect(find.text('Dingin: Rp 3.000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'GIGI WAJIB: baris bertemperatur HANYA masuk hitungan varian yang sama '
      '(hot & iced menampilkan angka BERBEDA, bukan tertukar)', (tester) async {
    await renderRecipeScreen(tester);

    await tester.tap(find.text('Tambah Bahan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Bahan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kopi Arabika').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Takaran'), '10');
    await tester.pump();
    // 10 * 150 = 1500 -> tandai baris ini KHUSUS "Panas".
    await tester.tap(find.widgetWithText(DropdownButtonFormField<String?>, 'Suhu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Panas').last);
    await tester.pumpAndSettle();

    expect(find.text('Panas: Rp 1.500'), findsOneWidget);
    expect(find.text('Dingin: Rp 0'), findsOneWidget,
        reason: 'baris khusus "hot" tidak boleh ikut terhitung ke "iced"');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'GIGI WAJIB: menu TANPA cost_price (costPrice 0) TIDAK menampilkan selisih '
      'palsu — hanya pesan "belum ada HPP manual"', (tester) async {
    await renderRecipeScreen(tester, menuCostPrice: 0);

    expect(
      find.text('Belum ada HPP manual (cost_price) untuk menu ini — belum bisa dibandingkan.'),
      findsOneWidget,
    );
    expect(find.textContaining('Selisih:'), findsNothing,
        reason: 'tak boleh ada baris "Selisih" sama sekali saat cost_price kosong/0');
    expect(tester.takeException(), isNull);
  });

  testWidgets('menu DENGAN cost_price menampilkan selisih HPP yang benar', (tester) async {
    await renderRecipeScreen(tester, menuCostPrice: 2000);

    await tester.tap(find.text('Tambah Bahan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Bahan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kopi Arabika').last);
    await tester.pumpAndSettle();
    // 20 * 150 = 3000, delta = 3000 - 2000 = 1000.
    await tester.enterText(find.widgetWithText(TextFormField, 'Takaran'), '20');
    await tester.pump();

    expect(find.textContaining('Selisih: Rp 1.000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('simpan resep → saveRecipe dipanggil dengan baris yang valid saja', (tester) async {
    final repo = await renderRecipeScreen(tester);

    await tester.tap(find.text('Tambah Bahan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Bahan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kopi Arabika').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Takaran'), '15');
    await tester.pump();

    // Baris KEDUA sengaja dibiarkan kosong (belum pilih bahan) — wajib
    // diabaikan, bukan dikirim/menyebabkan error.
    await tester.tap(find.text('Tambah Bahan'));
    await tester.pumpAndSettle();

    // Tombol "Simpan Resep" bisa berada di bawah layar (di dalam
    // SingleChildScrollView) — sama seperti pengguna sungguhan wajib
    // menggulir untuk mencapainya.
    await tester.ensureVisible(find.text('Simpan Resep'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan Resep'));
    await tester.pumpAndSettle();

    expect(repo.saveCalls.length, 1);
    final sent = repo.saveCalls.single;
    expect(sent.length, 1, reason: 'baris kosong (tanpa bahan terpilih) wajib diabaikan');
    expect(sent.single.ingredientId, 'ing-kopi');
    expect(sent.single.qtyBase, 15.0);
    expect(find.text('Resep tersimpan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'simpan resep sukses → hppComparisonProvider ikut di-invalidate '
      '(bukan cuma menuRecipeProvider), supaya badge status resep di '
      'RecipeListScreen yang tetap ter-mount di bawahnya tidak basi',
      (tester) async {
    final repo = _FakeStockRepository();
    final container = ProviderContainer(
      overrides: [
        stockRepositoryProvider.overrideWithValue(repo),
        allMenuItemsProvider.overrideWith((ref) async => [
              const MenuItemModel(id: 'menu-1', name: 'Kopi Susu Gula Aren', price: 20000),
            ]),
      ],
    );
    addTearDown(container.dispose);

    // Priming: sama seperti RecipeListScreen yang tetap ter-mount di BAWAH
    // RecipeScreen (push, bukan replace) dan sudah membaca provider ini
    // SEBELUM RecipeScreen dibuka.
    await container.read(hppComparisonProvider.future);
    expect(repo.fetchHppComparisonCalls, 1);

    await setPhoneSize(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.build(Brightness.light),
          home: const RecipeScreen(menuItemId: 'menu-1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Tambah Bahan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Bahan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kopi Arabika').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Takaran'), '15');
    await tester.pump();

    await tester.ensureVisible(find.text('Simpan Resep'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan Resep'));
    await tester.pumpAndSettle();

    expect(repo.saveCalls.length, 1);

    // Baca ulang lewat container (bukan lewat widget — RecipeListScreen
    // tidak ter-mount di test ini) untuk memastikan provider itu sendiri
    // BENAR-BENAR dibangun ulang, bukan sekadar tak error di layar ini.
    await container.read(hppComparisonProvider.future);
    expect(repo.fetchHppComparisonCalls, 2,
        reason: 'RecipeScreen._save() wajib ref.invalidate(hppComparisonProvider) '
            'juga, bukan cuma menuRecipeProvider(widget.menuItemId) — tanpa itu '
            'badge "sudah/belum ada resep" di RecipeListScreen tetap basi sampai '
            'pull-to-refresh manual walau resep baru saja tersimpan sukses');
    expect(tester.takeException(), isNull);
  });

  testWidgets('render RecipeListScreen 360×800 → nol exception layout, status resep terlihat',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        allMenuItemsProvider.overrideWith((ref) async => [
              const MenuItemModel(id: 'm1', name: 'Americano', price: 15000),
              const MenuItemModel(id: 'm2', name: 'Latte', price: 22000),
            ]),
        hppComparisonProvider.overrideWith((ref) async => const [
              HppRow(menuItemId: 'm1', name: 'Americano', complete: true, hasStored: false),
              HppRow(menuItemId: 'm2', name: 'Latte', complete: false, hasStored: false),
            ]),
        stockTopSellingItemsProvider.overrideWith((ref) async => const [
              TopItem(name: 'Latte', quantity: 40, revenue: 0),
            ]),
      ],
    );
    addTearDown(container.dispose);

    await setPhoneSize(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.build(Brightness.light),
          home: const RecipeListScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    // Latte (di topItems) wajib tampil DI ATAS Americano (tidak).
    final latteCenter = tester.getCenter(find.text('Latte'));
    final americanoCenter = tester.getCenter(find.text('Americano'));
    expect(latteCenter.dy, lessThan(americanoCenter.dy));
    // Americano (complete:true) -> "Resep sudah ada"; Latte (complete:false)
    // -> "Belum ada resep" — masing-masing tepat satu baris.
    expect(find.text('Resep sudah ada'), findsOneWidget);
    expect(find.text('Belum ada resep'), findsOneWidget);
  });
}
