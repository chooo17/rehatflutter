import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/features/finance/application/finance_ledger_view.dart';
import 'package:rehat_app/features/finance/data/finance_repository.dart';

/// Menguji logika penyajian & paginasi MURNI layar Buku Besar (Task 8) —
/// tanpa merender widget apa pun. Fokus utama: kontrak paginasi keyset
/// komposit HARUS diambil apa adanya dari respons (`next_before`/
/// `next_before_id`), TIDAK PERNAH disusun ulang dari item terakhir —
/// itu cacat paling berbahaya di layar ini (lihat komentar berkas
/// `finance_ledger_view.dart`).

LedgerEntry _entry({
  String id = 'e1',
  String bucket = 'restock',
  String direction = 'in',
  String source = 'allocation',
  int amount = 10000,
  String note = '',
  String refDate = '2026-08-05',
  DateTime? createdAt,
  String? createdBy,
}) =>
    LedgerEntry(
      id: id,
      bucket: bucket,
      direction: direction,
      source: source,
      amount: amount,
      note: note,
      refDate: refDate,
      createdAt: createdAt ?? DateTime.utc(2026, 8, 5, 3, 0, 0),
      createdBy: createdBy,
    );

void main() {
  group('appendLedgerPage', () {
    test('APPEND: item lama tetap ada, item baru ditambahkan di akhir', () {
      final state = LedgerListState(items: [_entry(id: 'a')]);
      final page = LedgerPage(items: [_entry(id: 'b'), _entry(id: 'c')]);
      final result = appendLedgerPage(state, page);
      expect(result.items.map((e) => e.id).toList(), ['a', 'b', 'c'],
          reason: 'harus APPEND, bukan REPLACE — mutasi "items: page.items" '
              'harus terdeteksi di sini');
    });

    test(
        'CURSOR KRITIS: nextBefore/nextBeforeId diambil dari page.next*, '
        'BUKAN dari createdAt/id item terakhir', () {
      // Skenario nyata: 5 baris alokasi harian ditulis dalam SATU insert →
      // created_at IDENTIK untuk semuanya. Backend tetap membalas kursor
      // keyset yang BENAR (next_before/next_before_id) yang mungkin BEDA
      // dari created_at/id item manapun di halaman ini. Andai klien
      // menyusun kursor sendiri dari item terakhir, baris yang berbagi
      // created_at akan hilang permanen dari buku besar.
      final identicalTimestamp = DateTime.utc(2026, 8, 5, 3, 0, 0);
      final lastItem = _entry(
        id: 'item-terakhir-di-halaman',
        createdAt: identicalTimestamp,
      );
      final page = LedgerPage(
        items: [
          _entry(id: 'x1', createdAt: identicalTimestamp),
          lastItem,
        ],
        hasMore: true,
        // Kursor backend SENGAJA dibuat BEDA dari id/created_at item
        // terakhir supaya test ini gagal bila kode menyusun kursor sendiri
        // dari item terakhir alih-alih memakai field ini apa adanya.
        nextBefore: '2026-08-05T03:00:00.000Z',
        nextBeforeId: 'kursor-dari-backend-bukan-item-terakhir',
      );
      final result = appendLedgerPage(LedgerListState.initial, page);
      expect(result.nextBeforeId, 'kursor-dari-backend-bukan-item-terakhir');
      expect(result.nextBeforeId, isNot(lastItem.id),
          reason: 'kursor tidak boleh disamakan dengan id item terakhir');
      expect(result.nextBefore, page.nextBefore);
    });

    test('hasMore diambil apa adanya dari page (true)', () {
      final page = LedgerPage(items: [_entry()], hasMore: true);
      final result = appendLedgerPage(LedgerListState.initial, page);
      expect(result.hasMore, isTrue);
    });

    test('hasMore diambil apa adanya dari page (false) walau state lama true', () {
      const oldState = LedgerListState(hasMore: true, nextBefore: 'x', nextBeforeId: 'y');
      final page = LedgerPage(items: [_entry()], hasMore: false);
      final result = appendLedgerPage(oldState, page);
      expect(result.hasMore, isFalse);
    });

    test('halaman kosong (items: []) tetap memperbarui cursor/hasMore', () {
      const page = LedgerPage(items: [], hasMore: false, nextBefore: null, nextBeforeId: null);
      final state = LedgerListState(items: [_entry()], hasMore: true, nextBefore: 'a', nextBeforeId: 'b');
      final result = appendLedgerPage(state, page);
      expect(result.items.length, 1, reason: 'item lama tetap ada walau halaman baru kosong');
      expect(result.hasMore, isFalse);
      expect(result.nextBefore, isNull);
    });
  });

  group('resetLedgerState', () {
    test('mengembalikan state kosong total (items, cursor, hasMore)', () {
      final r = resetLedgerState();
      expect(r.items, isEmpty);
      expect(r.hasMore, isFalse);
      expect(r.nextBefore, isNull);
      expect(r.nextBeforeId, isNull);
    });
  });

  group('canLoadMore', () {
    test('hasMore true → true', () {
      expect(canLoadMore(const LedgerListState(hasMore: true)), isTrue);
    });

    test('hasMore false → false, walau items tidak kosong', () {
      expect(
        canLoadMore(LedgerListState(items: [_entry()], hasMore: false)),
        isFalse,
      );
    });

    test('items kosong tapi hasMore true → tetap true (bukan disimpulkan dari panjang items)', () {
      expect(canLoadMore(const LedgerListState(items: [], hasMore: true)), isTrue);
    });
  });

  group('bucketLabel', () {
    test('lima pos dikenal diterjemahkan ke Bahasa Indonesia', () {
      expect(bucketLabel('restock'), 'Restock');
      expect(bucketLabel('operational'), 'Operasional');
      expect(bucketLabel('personal'), 'Pribadi');
      expect(bucketLabel('scaling'), 'Scaling');
      expect(bucketLabel('emergency'), 'Dana Darurat');
    });

    test('kunci tak dikenal → fallback apa adanya, bukan crash/kosong', () {
      expect(bucketLabel('entah'), 'entah');
    });
  });

  group('sourceLabel', () {
    test('lima sumber sesuai brief diterjemahkan', () {
      expect(sourceLabel('allocation'), 'Alokasi harian');
      expect(sourceLabel('withdrawal'), 'Penarikan');
      expect(sourceLabel('expense'), 'Pengeluaran');
      expect(sourceLabel('correction'), 'Koreksi');
      expect(sourceLabel('shortfall'), 'Kekurangan');
    });

    test('kode mentah TIDAK PERNAH bocor ke tampilan untuk kunci dikenal', () {
      for (final code in ['allocation', 'withdrawal', 'expense', 'correction', 'shortfall']) {
        expect(sourceLabel(code), isNot(code));
      }
    });

    test('kunci tak dikenal → fallback apa adanya', () {
      expect(sourceLabel('lain_lain'), 'lain_lain');
    });
  });

  group('isInflow & directionLabel', () {
    test("direction 'in' → masuk", () {
      expect(isInflow('in'), isTrue);
      expect(directionLabel('in'), 'Masuk');
    });

    test("direction 'out' → keluar", () {
      expect(isInflow('out'), isFalse);
      expect(directionLabel('out'), 'Keluar');
    });

    test('direction tak dikenal → default aman KELUAR, bukan MASUK', () {
      expect(isInflow('???'), isFalse);
      expect(directionLabel('???'), 'Keluar');
    });
  });

  group('signedAmountLabel', () {
    test("direction 'in' → diberi tanda plus", () {
      final e = _entry(direction: 'in', amount: 50000);
      expect(signedAmountLabel(e), startsWith('+'));
      expect(signedAmountLabel(e), contains('50.000'));
    });

    test("direction 'out' → diberi tanda minus", () {
      final e = _entry(direction: 'out', amount: 50000);
      expect(signedAmountLabel(e), startsWith('−'));
      expect(signedAmountLabel(e), contains('50.000'));
    });

    test('tanda mengikuti direction, BUKAN tanda mentah amount (amount negatif + direction out)', () {
      // Backend bisa mengirim amount negatif untuk baris tertentu — tanda
      // tampilan harus tetap mengikuti `direction` (sumber kebenaran arah),
      // memakai nilai absolut, bukan menggandakan tanda minus mentah.
      final e = _entry(direction: 'out', amount: -50000);
      final label = signedAmountLabel(e);
      expect(label, startsWith('−'));
      expect(label, isNot(contains('−−')));
      expect(label, contains('50.000'));
    });

    test('tanda mengikuti direction, BUKAN tanda mentah amount (amount negatif + direction in)', () {
      final e = _entry(direction: 'in', amount: -50000);
      final label = signedAmountLabel(e);
      expect(label, startsWith('+'));
      expect(label, contains('50.000'));
    });
  });
}
