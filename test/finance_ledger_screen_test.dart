import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rehat_app/core/network/dio_client.dart';
import 'package:rehat_app/core/storage/secure_storage.dart';
import 'package:rehat_app/features/finance/data/finance_repository.dart';
import 'package:rehat_app/features/finance/presentation/finance_ledger_screen.dart';

/// Widget test untuk layar Buku Besar (Task 8 re-review) — mencakup
/// perilaku yang HANYA bisa dibuktikan dengan merender widget & mengontrol
/// urutan kedatangan respons jaringan (fungsi murni di
/// `finance_ledger_view.dart` diuji terpisah di
/// `finance_ledger_view_test.dart`).
///
/// Fokus: C-1 (kunjungan kedua ke layar harus fetch ulang, bukan stuck
/// "Belum ada mutasi"), C-2 (respons load-more basi milik filter LAMA tidak
/// boleh tercampur ke filter BARU), C-3 (refresh saat load-more pending
/// tidak boleh menghilangkan baris atau menimpa cursor dengan snapshot
/// basi).
///
/// Prasyarat: `NeuButton` non-accent (dipakai tombol "Muat lebih banyak")
/// sudah diperbaiki (lihat `neu.dart`) supaya tidak memicu assert
/// `Material(shape+borderRadius)` di setiap render debug — tanpa perbaikan
/// itu, widget test apa pun yang me-render layar ini butuh `takeException()`
/// di setiap `pump()`.
class _FakeFinanceRepository extends FinanceRepository {
  _FakeFinanceRepository() : super(client: DioClient(storage: SecureStorage()));

  final List<Completer<LedgerPage>> completers = [];
  final List<({String? bucket, String? before, String? beforeId})> calls = [];

  @override
  Future<LedgerPage> fetchLedger({
    String? bucket,
    int limit = 20,
    String? before,
    String? beforeId,
  }) {
    calls.add((bucket: bucket, before: before, beforeId: beforeId));
    final c = Completer<LedgerPage>();
    completers.add(c);
    return c.future;
  }
}

LedgerEntry _entry(String id, {String bucket = 'restock'}) => LedgerEntry(
      id: id,
      bucket: bucket,
      direction: 'in',
      source: 'allocation',
      amount: 10000,
      note: '',
      refDate: '2026-08-05',
      createdAt: DateTime.utc(2026, 8, 5, 3, 0, 0),
    );

Future<void> _mountScreen(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: FinanceLedgerScreen()),
    ),
  );
}

Future<void> _unmountScreen(WidgetTester tester, ProviderContainer container) async {
  // Menggantikan layar dengan widget kosong TAPI mempertahankan
  // `ProviderContainer` yang sama — ini yang terjadi saat navigasi pop
  // (State layar dibuang, tapi container di akar app tetap hidup). Berbeda
  // dari membuat `ProviderContainer` baru, yang tidak menguji apa pun
  // (tentu saja fetch ulang kalau containernya juga baru).
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SizedBox()),
    ),
  );
  // Beri kesempatan `autoDispose` membuang provider setelah listener
  // terakhir (dari State yang baru saja di-dispose) lepas.
  await tester.pump();
}

void main() {
  // `_LedgerRow` memformat tanggal lewat `Formatters.tanggalJam` (locale
  // 'id_ID', lihat aturan proyek: JANGAN `DateFormat` langsung). Tanpa
  // inisialisasi ini, `intl` melempar `LocaleDataException` saat me-render
  // baris pertama.
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  testWidgets(
      'C-1: kunjungan KEDUA ke layar (pop lalu push, ProviderContainer SAMA) '
      'memicu fetch baru & menampilkan data — bukan stuck "Belum ada mutasi"',
      (tester) async {
    final repo = _FakeFinanceRepository();
    final container = ProviderContainer(
      overrides: [financeRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    // Kunjungan pertama.
    await _mountScreen(tester, container);
    await tester.pump();
    expect(repo.calls.length, 1, reason: 'kunjungan pertama harus fetch');
    repo.completers[0].complete(LedgerPage(items: [_entry('a')]));
    await tester.pump();
    await tester.pump();
    expect(find.text('Belum ada mutasi untuk filter ini.'), findsNothing);

    // Pop.
    await _unmountScreen(tester, container);

    // Push lagi — dengan container yang SAMA.
    await _mountScreen(tester, container);
    await tester.pump();
    expect(repo.calls.length, 2,
        reason: 'autoDispose harus memicu fetch BARU di kunjungan kedua, '
            'bukan memakai cache lama diam-diam');
    repo.completers[1].complete(LedgerPage(items: [_entry('b')]));
    await tester.pump();
    await tester.pump();
    expect(find.text('Belum ada mutasi untuk filter ini.'), findsNothing,
        reason: 'C-1: kunjungan kedua wajib menampilkan data begitu fetch '
            'barunya selesai, tidak boleh stuck di pesan kosong');
  });

  testWidgets(
      'MUTASI (a) — jaring: respons "muat lebih banyak" yang BASI (filter '
      'sudah berganti sebelum respons tiba) dibuang, tidak tercampur ke '
      'daftar filter BARU', (tester) async {
    final repo = _FakeFinanceRepository();
    final container = ProviderContainer(
      overrides: [financeRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await _mountScreen(tester, container);
    await tester.pump();
    // Halaman pertama filter "Semua".
    repo.completers[0].complete(LedgerPage(
      items: [_entry('a', bucket: 'restock')],
      hasMore: true,
      nextBefore: '2026-08-05T03:00:00.000Z',
      nextBeforeId: 'cur-semua',
    ));
    await tester.pump();
    await tester.pump();

    // Tap "Muat lebih banyak" untuk filter "Semua" — request terkirim,
    // TAPI dibiarkan menggantung (belum di-complete).
    await tester.tap(find.text('Muat lebih banyak'));
    await tester.pump();
    expect(repo.calls.length, 2);
    expect(repo.calls[1].bucket, isNull);
    expect(repo.calls[1].beforeId, 'cur-semua');

    // Sementara request itu masih menggantung, user berpindah filter ke
    // "Restock" — memicu request BARU (halaman pertama restock).
    await tester.tap(find.widgetWithText(ChoiceChip, 'Restock'));
    await tester.pump();
    expect(repo.calls.length, 3);
    expect(repo.calls[2].bucket, 'restock');
    repo.completers[2].complete(LedgerPage(
      items: [_entry('r1', bucket: 'restock')],
      hasMore: false,
    ));
    await tester.pump();
    await tester.pump();

    // BARU SEKARANG request "muat lebih banyak" filter "Semua" yang lama
    // (basi) tiba.
    repo.completers[1].complete(LedgerPage(
      items: [_entry('b-basi', bucket: 'restock')],
      hasMore: false,
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Sudah menampilkan semua mutasi.'), findsOneWidget);
    // Item basi TIDAK boleh muncul — kalau pemeriksaan basi di `_loadMore`
    // dihapus (mutasi a), baris ini akan ter-append ke daftar restock.
    expect(find.byKey(const Key('ledger-entry-b-basi')), findsNothing);
  });

  testWidgets(
      'MUTASI (d) — jaring: halaman PERTAMA filter baru harus MENGGANTIKAN '
      '(bukan APPEND ke) state filter lama', (tester) async {
    final repo = _FakeFinanceRepository();
    final container = ProviderContainer(
      overrides: [financeRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await _mountScreen(tester, container);
    await tester.pump();
    repo.completers[0].complete(LedgerPage(items: [_entry('a-semua')]));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Restock'));
    await tester.pump();
    repo.completers[1].complete(LedgerPage(items: [_entry('r1-restock')]));
    await tester.pump();
    await tester.pump();

    // Kalau `_onFirstPage` APPEND (mutasi d) alih-alih REPLACE, entri
    // "Semua" lama akan tetap tampil bersebelahan dengan entri restock —
    // jadi baris lama WAJIB sudah hilang, dan hanya baris restock yang ada.
    expect(find.byKey(const Key('ledger-entry-a-semua')), findsNothing,
        reason: 'halaman pertama filter baru harus MENGGANTIKAN state lama, '
            'bukan APPEND ke atasnya');
    expect(find.byKey(const Key('ledger-entry-r1-restock')), findsOneWidget);
  });

  testWidgets(
      'C-3: tarik-untuk-refresh saat "muat lebih banyak" masih pending TIDAK '
      'boleh menghilangkan baris atau menimpa cursor dengan snapshot basi',
      (tester) async {
    final repo = _FakeFinanceRepository();
    final container = ProviderContainer(
      overrides: [financeRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await _mountScreen(tester, container);
    await tester.pump();
    // Halaman 1 awal: [a, b], masih ada lanjutan.
    repo.completers[0].complete(LedgerPage(
      items: [_entry('a'), _entry('b')],
      hasMore: true,
      nextBefore: '2026-08-05T03:00:00.000Z',
      nextBeforeId: 'cur-1',
    ));
    await tester.pump();
    await tester.pump();

    // Tap "Muat lebih banyak" — request #2 terkirim, DIBIARKAN pending.
    await tester.tap(find.text('Muat lebih banyak'));
    await tester.pump();
    expect(repo.calls.length, 2);
    expect(repo.calls[1].beforeId, 'cur-1');

    // Sementara request #2 masih menggantung, user tarik-untuk-refresh —
    // filter TIDAK berubah (tetap "Semua"), tapi ini memicu halaman 1 BARU.
    container.invalidate(ledgerProvider);
    await tester.pump();
    expect(repo.calls.length, 3);
    expect(repo.calls[2].bucket, isNull);
    expect(repo.calls[2].before, isNull, reason: 'refresh selalu kembali ke halaman 1');

    // Halaman 1 hasil refresh tiba lebih dulu: data sudah berubah (mis. ada
    // baris baru masuk), cursor BARU.
    repo.completers[2].complete(LedgerPage(
      items: [_entry('baru'), _entry('a')],
      hasMore: true,
      nextBefore: '2026-08-05T04:00:00.000Z',
      nextBeforeId: 'cur-2',
    ));
    await tester.pump();
    await tester.pump();

    // BARU SEKARANG respons "muat lebih banyak" #2 yang basi (dikirim
    // sebelum refresh) tiba.
    repo.completers[1].complete(LedgerPage(
      items: [_entry('c-basi')],
      hasMore: false,
    ));
    await tester.pump();
    await tester.pump();

    // Baris basi tidak boleh muncul, dan baris hasil refresh ('baru', 'a')
    // tidak boleh hilang.
    expect(find.byKey(const Key('ledger-entry-c-basi')), findsNothing);
    expect(find.byKey(const Key('ledger-entry-baru')), findsOneWidget);
    expect(find.byKey(const Key('ledger-entry-a')), findsOneWidget);

    // Cursor tidak boleh tertimpa oleh snapshot basi (yang hasMore-nya
    // false) — tombol "Muat lebih banyak" HARUS tetap aktif memakai cursor
    // hasil refresh (cur-2), bukan berhenti karena cursor basi menimpanya.
    expect(find.text('Muat lebih banyak'), findsOneWidget);
    await tester.tap(find.text('Muat lebih banyak'));
    await tester.pump();
    expect(repo.calls.length, 4);
    expect(repo.calls[3].beforeId, 'cur-2',
        reason: 'cursor lanjutan wajib memakai cursor hasil refresh, bukan '
            'cursor snapshot basi yang tiba belakangan');
  });
}
