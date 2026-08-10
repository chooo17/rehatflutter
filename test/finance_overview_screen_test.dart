import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/core/constants/app_fonts.dart';
import 'package:rehat_app/core/constants/app_theme.dart';
import 'package:rehat_app/core/network/dio_client.dart';
import 'package:rehat_app/core/storage/secure_storage.dart';
import 'package:rehat_app/features/finance/data/finance_repository.dart';
import 'package:rehat_app/features/finance/presentation/finance_overview_screen.dart';

/// Fake repo untuk C-2 — mengontrol kapan `fetchOverview()` resolve lewat
/// `Completer`, dan menghitung berapa kali dipanggil (bukti bahwa
/// `autoDispose` memicu fetch BARU tiap kunjungan, bukan memakai cache lama).
class _FakeFinanceRepository extends FinanceRepository {
  _FakeFinanceRepository() : super(client: DioClient(storage: SecureStorage()));

  final List<Completer<FinanceOverview>> completers = [];

  @override
  Future<FinanceOverview> fetchOverview() {
    final c = Completer<FinanceOverview>();
    completers.add(c);
    return c.future;
  }
}

FinanceOverview _simpleOverview(int restockBalance) => FinanceOverview(
      balances: BucketBalances(restock: restockBalance),
      guards: const FinanceGuards(),
      settings: const FinanceSettings(),
    );

/// `flutter test` TIDAK memuat font kustom yang dibundel (`assets/fonts/`)
/// secara default — teks dirender dengan font fallback generik yang lebar
/// glyph-nya BERBEDA (biasanya lebih lebar) dari Inter sungguhan. Tanpa ini,
/// widget lain di layar (mis. `_GuardsCard`, yang TIDAK termasuk temuan C-1
/// dan aman di aplikasi produksi) bisa overflow PALSU akibat font pengganti
/// itu — mengaburkan sinyal overflow yang sedang diuji di sini (khusus grid
/// kartu amplop). Memuat font sungguhan membuat lebar teks di test sama
/// persis dengan yang dilihat reviewer saat merender di HP asli.
Future<void> _loadAppFonts() async {
  final inter = FontLoader(AppFonts.body)
    ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
  await inter.load();
  final cormorant = FontLoader(AppFonts.display)
    ..addFont(rootBundle.load('assets/fonts/CormorantGaramond.ttf'));
  await cormorant.load();
}

/// Widget test untuk layar Ringkasan Keuangan — final whole-branch review,
/// C-1: kartu amplop OVERFLOW di HP nyata (360×800 logis, ukuran layar
/// standar) untuk empat kombinasi keadaan (positif/defisit ×
/// diblokir/tidak) karena `GridView` memakai `childAspectRatio` TETAP yang
/// tidak cukup tinggi untuk saldo jutaan (membungkus 2-3 baris) + tombol
/// Tarik + teks defisit + `blockedReason` sekaligus.
///
/// Reviewer menemukan ini dengan MERENDER layar sungguhan, bukan membaca
/// kode — jadi perbaikannya WAJIB dibuktikan dengan cara yang sama: render
/// pada ukuran HP nyata dan tegaskan NOL exception layout untuk keempat
/// keadaan, dengan nominal jutaan yang realistis.
void main() {
  setUpAll(_loadAppFonts);

  // 360×800 logis @ device pixel ratio 3.0 == 1080×2400 fisik — persis
  // ukuran yang dipakai reviewer untuk menemukan C-1.
  Future<void> setPhoneSize(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<FinanceOverview> buildOverview({
    required int personalBalance,
    required bool personalWithdrawBlocked,
  }) async =>
      FinanceOverview(
        balances: BucketBalances(
          restock: 15000000,
          operational: 8000000,
          personal: personalBalance,
          scaling: 3000000,
          emergency: 2000000,
        ),
        guards: FinanceGuards(
          breakEvenDaily: 850000,
          runwayDays: 45,
          emergencyPct: 60,
          personalWithdrawBlocked: personalWithdrawBlocked,
          emergencyReached: false,
        ),
        settings: const FinanceSettings(
          pctRestock: 42,
          operationalDaily: 150000,
          emergencyTarget: 25800000,
        ),
        basis: 'previous',
        basisMonth: '2026-07',
      );

  Future<void> renderAndSettle(
    WidgetTester tester,
    FinanceOverview overview,
  ) async {
    final container = ProviderContainer(
      overrides: [
        financeOverviewProvider.overrideWith((ref) async => overview),
      ],
    );
    addTearDown(container.dispose);

    await setPhoneSize(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        // Tema APLIKASI SUNGGUHAN (`AppTheme.build`), bukan Material default
        // — ukuran font di sini menentukan lebar teks nyata yang dilihat
        // reviewer saat merender di HP asli. Material default punya ukuran
        // font lebih besar untuk beberapa gaya, yang akan memunculkan
        // overflow PALSU di widget lain (mis. `_GuardsCard`) yang sebenarnya
        // aman di aplikasi produksi — mengaburkan sinyal C-1 yang sedang
        // diuji (khusus grid kartu amplop).
        child: MaterialApp(
          theme: AppTheme.build(Brightness.light),
          home: const FinanceOverviewScreen(),
        ),
      ),
    );
    // Biarkan FutureProvider resolve.
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
      'C-1: saldo POSITIF, TIDAK diblokir (jalur normal) → nol exception layout '
      'pada 360×800 dengan nominal jutaan', (tester) async {
    await renderAndSettle(
      tester,
      await buildOverview(personalBalance: 5000000, personalWithdrawBlocked: false),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Defisit'), findsNothing);
  });

  testWidgets(
      'C-1: saldo POSITIF, personalWithdrawBlocked TRUE → nol exception layout, '
      'blockedReason tetap terbaca', (tester) async {
    await renderAndSettle(
      tester,
      await buildOverview(personalBalance: 5000000, personalWithdrawBlocked: true),
    );
    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('tarik pribadi'),
      findsOneWidget,
      reason: 'blockedReason wajib tetap terbaca, bukan terpotong diam-diam',
    );
  });

  testWidgets(
      'C-1: saldo DEFISIT (−1.234.567), TIDAK diblokir → nol exception layout, '
      'teks defisit tetap terbaca', (tester) async {
    await renderAndSettle(
      tester,
      await buildOverview(personalBalance: -1234567, personalWithdrawBlocked: false),
    );
    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('Defisit'),
      findsOneWidget,
      reason: 'peringatan defisit wajib tetap terbaca, bukan terpotong diam-diam',
    );
  });

  testWidgets(
      'C-1: DEFISIT dan diblokir sekaligus (kombinasi terburuk) → nol exception '
      'layout, kedua peringatan tetap terbaca', (tester) async {
    await renderAndSettle(
      tester,
      await buildOverview(personalBalance: -1234567, personalWithdrawBlocked: true),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Defisit'), findsOneWidget,
        reason: 'peringatan defisit wajib tetap terbaca');
    expect(find.textContaining('tarik pribadi'), findsOneWidget,
        reason: 'blockedReason wajib tetap terbaca — dua rambu uang paling '
            'mahal di layar ini tidak boleh hilang bersamaan');
  });

  testWidgets(
      'C-2: kunjungan KEDUA ke layar (pop lalu push, ProviderContainer SAMA) '
      'memicu fetch BARU & menampilkan saldo baru — bukan saldo BASI',
      (tester) async {
    final repo = _FakeFinanceRepository();
    final container = ProviderContainer(
      overrides: [financeRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await setPhoneSize(tester);

    // Kunjungan pertama: saldo restock Rp1.000.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.build(Brightness.light),
          home: const FinanceOverviewScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(repo.completers.length, 1, reason: 'kunjungan pertama harus fetch');
    repo.completers[0].complete(_simpleOverview(1000));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Rp 1.000'), findsOneWidget);

    // Pop — gantikan layar dengan widget kosong TAPI `ProviderContainer`
    // yang SAMA (ini yang sungguhan terjadi saat navigasi pop: State layar
    // dibuang, container di akar app tetap hidup).
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SizedBox()),
      ),
    );
    // Beri kesempatan `autoDispose` membuang provider setelah listener
    // terakhir (dari State yang baru saja di-dispose) lepas.
    await tester.pump();

    // Push lagi. Sementara itu saldo di server berubah jadi -Rp999.999
    // (probe dari temuan reviewer).
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.build(Brightness.light),
          home: const FinanceOverviewScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(repo.completers.length, 2,
        reason: 'C-2: autoDispose harus memicu fetch BARU di kunjungan '
            'kedua, bukan memakai cache lama diam-diam (tanpa autoDispose, '
            'fetchOverview() hanya dipanggil 1x total dan layar menampilkan '
            'saldo BASI Rp1.000 tanpa spinner/tanda apa pun)');
    repo.completers[1].complete(_simpleOverview(-999999));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Rp 1.000'), findsNothing,
        reason: 'saldo BASI dari kunjungan pertama tidak boleh tersisa');
    expect(find.textContaining('999.999'), findsWidgets,
        reason: 'saldo BARU dari kunjungan kedua wajib tampil (nilai '
            'muncul di kartu saldo & di teks keterangan defisit)');
  });
}
