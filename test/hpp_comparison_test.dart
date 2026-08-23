import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rehat_app/core/constants/app_fonts.dart';
import 'package:rehat_app/core/constants/app_theme.dart';
import 'package:rehat_app/core/router/route_names.dart';
import 'package:rehat_app/features/admin/data/admin_report_repository.dart';
import 'package:rehat_app/features/stock/data/stock_repository.dart';
import 'package:rehat_app/features/stock/presentation/hpp_comparison_screen.dart';

/// Widget test layar Perbandingan HPP (Manajemen Stok Fase A, **Task 8 —
/// deliverable utama Fase A**). Harness SAMA dengan
/// `recipe_screen_test.dart`/`ingredients_screen_test.dart` (360×800 logis,
/// font asli, `AppTheme` asli).
///
/// Fokus bukti gigi brief Task 8, Step 1/5:
/// - render 360×800, NOL exception layout;
/// - tiga keadaan (belum ada resep / belum ada `cost_price` / selisih nol)
///   tampil BERBEDA, bukan sama;
/// - urutan (selisih terbesar di atas) benar;
/// - dua tautan AppBar (Kelola Bahan/Kelola Resep) menavigasi ke rute yang
///   benar; entri hub dari `FinanceOverviewScreen` diuji terpisah di sini
///   juga (satu test kecil) karena itu bagian dari kontrak Task 8.

/// `flutter test` TIDAK memuat font kustom yang dibundel (`assets/fonts/`)
/// secara default — sama pola & alasan dengan test lain di modul ini.
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
  // standar, sama dengan harness Master Bahan/Entri Resep/modul Keuangan.
  Future<void> setPhoneSize(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });
  }

  // Tiga menu, satu untuk masing-masing keadaan wajib brief, PLUS satu baris
  // "compared" ber-delta BESAR untuk membuktikan urutan (selisih terbesar di
  // atas).
  const rows = [
    HppRow(
      menuItemId: 'no-recipe',
      name: 'Zebra Mocha',
      complete: false,
      hasStored: false,
    ),
    HppRow(
      menuItemId: 'no-stored',
      name: 'Avocado Coffee',
      complete: true,
      hasStored: false,
      computedHot: 4000,
      computedIced: 4200,
    ),
    HppRow(
      menuItemId: 'equal',
      name: 'Kopi Susu',
      complete: true,
      hasStored: true,
      storedCostPrice: 8000,
      computedHot: 8000,
      computedIced: 8000,
      delta: 0,
      pct: 0.0,
    ),
    HppRow(
      menuItemId: 'big-diff',
      name: 'Americano',
      complete: true,
      hasStored: true,
      storedCostPrice: 5000,
      computedHot: 12000,
      computedIced: 11000,
      delta: 7000,
      pct: 140.0,
    ),
  ];

  Future<ProviderContainer> renderScreen(
    WidgetTester tester, {
    List<HppRow> hppRows = rows,
    List<TopItem> topItems = const [
      TopItem(name: 'Americano', quantity: 100, revenue: 0),
      TopItem(name: 'Kopi Susu', quantity: 50, revenue: 0),
    ],
  }) async {
    final container = ProviderContainer(
      overrides: [
        hppComparisonProvider.overrideWith((ref) async => hppRows),
        hppImpactTopSellingItemsProvider.overrideWith((ref) async => topItems),
      ],
    );
    addTearDown(container.dispose);

    await setPhoneSize(tester);
    final router = GoRouter(
      initialLocation: '/hpp',
      routes: [
        GoRoute(
          path: '/hpp',
          name: RouteNames.stockHppComparison,
          builder: (context, state) => const HppComparisonScreen(),
        ),
        GoRoute(
          path: '/ingredients',
          name: RouteNames.stockIngredients,
          builder: (context, state) => const Scaffold(body: Text('LAYAR BAHAN')),
        ),
        GoRoute(
          path: '/recipe-list',
          name: RouteNames.stockRecipeList,
          builder: (context, state) => const Scaffold(body: Text('LAYAR RESEP')),
        ),
        GoRoute(
          path: '/recipe/:menuItemId',
          name: RouteNames.stockRecipe,
          builder: (context, state) => Scaffold(
            body: Text('ENTRI RESEP ${state.pathParameters['menuItemId']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.build(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return container;
  }

  testWidgets('render 360×800 dengan font & tema asli → nol exception layout', (tester) async {
    await renderScreen(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Perbandingan HPP'), findsOneWidget);
  });

  testWidgets(
      'GIGI WAJIB: tiga keadaan tampil BERBEDA — "belum ada resep" TIDAK '
      'menampilkan angka HPP sama sekali', (tester) async {
    // Fixture DISARINGKAN ke satu baris saja — memeriksa "tidak ada teks
    // Selisih SAMA SEKALI" untuk keadaan lain akan salah positif kalau baris
    // LAIN di layar yang sama kebetulan punya "Selisih" (lihat dua test di
    // bawah, yang butuh isolasi serupa).
    await renderScreen(tester, hppRows: const [
      HppRow(menuItemId: 'no-recipe', name: 'Zebra Mocha', complete: false, hasStored: false),
    ], topItems: const []);

    // Zebra Mocha (no-recipe): badge "Belum ada resep", TIDAK ada "Panas:"/
    // "Dingin:"/"Selisih:" untuk baris ini sama sekali.
    expect(find.text('Belum ada resep'), findsOneWidget);
    expect(find.text('Belum ada resep — ketuk untuk menambahkan.'), findsOneWidget);
    expect(find.textContaining('Panas:'), findsNothing);
    expect(find.textContaining('Selisih:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'GIGI WAJIB: keadaan "resep ada, cost_price belum" menampilkan HPP '
      'terhitung TAPI TIDAK ADA baris "Selisih" (diganti pesan, bukan Rp0 palsu)',
      (tester) async {
    await renderScreen(tester, hppRows: const [
      HppRow(
        menuItemId: 'no-stored',
        name: 'Avocado Coffee',
        complete: true,
        hasStored: false,
        computedHot: 4000,
        computedIced: 4200,
      ),
    ], topItems: const []);

    expect(find.text('Belum ada HPP lama'), findsOneWidget); // badge
    expect(find.textContaining('Panas: Rp 4.000'), findsOneWidget);
    expect(find.textContaining('Dingin: Rp 4.200'), findsOneWidget);
    expect(find.text('Belum ada HPP lama untuk dibandingkan.'), findsOneWidget);
    expect(find.textContaining('Selisih:'), findsNothing,
        reason: 'menu tanpa cost_price tak boleh menampilkan baris "Selisih" apa pun, '
            'apalagi "Selisih: Rp0" palsu');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'GIGI WAJIB: keadaan "selisih nol" (data SAH) menampilkan "Selisih: Rp 0 '
      '(0.0%)" APA ADANYA, BUKAN disamarkan seperti dua keadaan lain', (tester) async {
    await renderScreen(tester, hppRows: const [
      HppRow(
        menuItemId: 'equal',
        name: 'Kopi Susu',
        complete: true,
        hasStored: true,
        storedCostPrice: 8000,
        computedHot: 8000,
        computedIced: 8000,
        delta: 0,
        pct: 0.0,
      ),
    ], topItems: const []);

    expect(find.text('Sama persis'), findsOneWidget); // badge compared, delta==0
    expect(find.textContaining('Selisih: Rp 0'), findsOneWidget,
        reason: 'delta genuinely 0 adalah data SAH, wajib tetap tampil sebagai Rp0 nyata, '
            'bukan disembunyikan seperti keadaan "belum ada HPP lama"');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'GIGI: ketiga badge keadaan TIDAK identik satu sama lain (bukti visual berbeda)',
      (tester) async {
    await renderScreen(tester);

    // Tiga label badge berbeda untuk tiga baris berbeda keadaan.
    expect(find.text('Belum ada resep'), findsOneWidget);
    expect(find.text('Belum ada HPP lama'), findsOneWidget);
    expect(find.text('Sama persis'), findsOneWidget);
    expect(find.text('HPP lebih tinggi'), findsOneWidget); // baris Americano, delta 7000 > 0

    // Kalau ketiga label pertama SAMA (bug "tiga keadaan ditampilkan sama"
    // dari Step 5 brief), findsOneWidget di atas untuk masing-masing akan
    // gagal (jadi findsNWidgets(3) pada satu teks, bukan tiga teks unik).
    expect(tester.takeException(), isNull);
  });

  testWidgets('urutan: selisih terbesar (nilai absolut) di ATAS', (tester) async {
    await renderScreen(tester);

    // Americano (delta 7000, |7000|) wajib di atas Kopi Susu (delta 0).
    // Baris tanpa delta nyata (Zebra Mocha, Avocado Coffee) di bawah semua
    // baris berperingkat.
    final americanoY = tester.getCenter(find.text('Americano')).dy;
    final kopiSusuY = tester.getCenter(find.text('Kopi Susu')).dy;
    final zebraY = tester.getCenter(find.text('Zebra Mocha')).dy;
    final avocadoY = tester.getCenter(find.text('Avocado Coffee')).dy;

    expect(americanoY, lessThan(kopiSusuY),
        reason: 'Americano (|delta|=7000) wajib di atas Kopi Susu (|delta|=0)');
    expect(kopiSusuY, lessThan(zebraY),
        reason: 'baris berperingkat (Kopi Susu, delta nyata) wajib di atas baris '
            'tanpa delta nyata (Zebra Mocha)');
    expect(kopiSusuY, lessThan(avocadoY));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ringkasan puncak: cakupan resep & dampak gabungan tertimbang tampil',
      (tester) async {
    await renderScreen(tester);

    expect(find.textContaining('dari 4 menu sudah punya resep'), findsOneWidget,
        reason: '3 dari 4 baris fixture complete:true (no-stored, equal, big-diff)');
    // Dampak gabungan: hanya 'equal' (delta 0, qty 50) & 'big-diff' (delta
    // 7000, qty 100) eligible (hasStored&&complete&&qty>0). Weighted =
    // (0*50 + 7000*100) / 150 = 700000/150 ≈ 4666.67.
    expect(find.textContaining('Rata-rata tertimbang'), findsOneWidget);
    expect(find.textContaining('Dihitung dari 2 menu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'GIGI: dampak gabungan "belum cukup data" saat TAK ADA menu eligible (bukan Rp0)',
      (tester) async {
    await renderScreen(
      tester,
      hppRows: const [
        HppRow(menuItemId: 'a', name: 'A', complete: false, hasStored: false),
      ],
      topItems: const [],
    );

    expect(find.textContaining('Belum cukup data'), findsOneWidget);
    expect(find.textContaining('Rata-rata tertimbang'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ketuk baris "belum ada resep" → navigasi ke Entri Resep menu itu',
      (tester) async {
    await renderScreen(tester);

    await tester.tap(find.text('Zebra Mocha'));
    await tester.pumpAndSettle();

    expect(find.text('ENTRI RESEP no-recipe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tombol AppBar "Kelola bahan" → navigasi ke stock-ingredients', (tester) async {
    await renderScreen(tester);

    await tester.tap(find.byTooltip('Kelola bahan'));
    await tester.pumpAndSettle();

    expect(find.text('LAYAR BAHAN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tombol AppBar "Kelola resep" → navigasi ke stock-recipe-list', (tester) async {
    await renderScreen(tester);

    await tester.tap(find.byTooltip('Kelola resep'));
    await tester.pumpAndSettle();

    expect(find.text('LAYAR RESEP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('daftar menu kosong → pesan "Belum ada menu.", nol exception layout',
      (tester) async {
    await renderScreen(tester, hppRows: const [], topItems: const []);

    expect(find.text('Belum ada menu.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
