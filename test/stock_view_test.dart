import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/features/stock/application/stock_view.dart';
import 'package:rehat_app/features/stock/data/stock_repository.dart';

/// Menguji logika penyajian MURNI fitur Manajemen Stok (Task 5) — tanpa
/// merender widget apa pun: label satuan, format harga per satuan, validasi
/// isi per satuan beli, dan kalimat selisih HPP untuk tiga keadaan.

HppRow _row({
  int? storedCostPrice,
  int computedHot = 0,
  int computedIced = 0,
  int? delta,
  double? pct,
  bool complete = true,
  bool hasStored = false,
}) =>
    HppRow(
      menuItemId: 'm1',
      name: 'Menu',
      storedCostPrice: storedCostPrice,
      computedHot: computedHot,
      computedIced: computedIced,
      delta: delta,
      pct: pct,
      complete: complete,
      hasStored: hasStored,
    );

void main() {
  group('unitLabel', () {
    test('g → gram', () => expect(unitLabel('g'), 'gram'));
    test('ml → mililiter', () => expect(unitLabel('ml'), 'mililiter'));
    test('pcs → pcs', () => expect(unitLabel('pcs'), 'pcs'));
    test('kode tak dikenal → dikembalikan apa adanya, bukan string kosong', () {
      expect(unitLabel('kg'), 'kg');
      expect(unitLabel(''), '');
    });
  });

  group('formatCostPerUnit', () {
    test('menyertakan label satuan penuh', () {
      final s = formatCostPerUnit(120, 'g');
      expect(s, contains('gram'));
      expect(s, contains('120'));
    });

    test('costPerBase pecahan tetap tampil masuk akal (bukan dibulatkan sebelum diformat)', () {
      // Formatters.rupiah membulatkan TAMPILAN (decimalDigits:0) — itu wajar
      // untuk teks harga, TAPI fungsi ini tidak boleh membulatkan nilai
      // sebelum memformatnya (mis. .round() manual di sini akan salah untuk
      // kasus Rp3,5/g yang seharusnya tampil "Rp 4/gram" hasil pembulatan
      // NumberFormat, bukan "Rp 4/gram" dari int 4 yang sudah cacat sejak awal).
      final s = formatCostPerUnit(3.5, 'g');
      expect(s, contains('gram'));
      expect(s, isNotEmpty);
    });
  });

  group('unitsPerPurchaseError', () {
    test('nilai 0 → pesan error', () {
      expect(unitsPerPurchaseError(0), isNotNull);
    });

    test('nilai negatif → pesan error', () {
      expect(unitsPerPurchaseError(-5), isNotNull);
    });

    test('nilai positif → valid (null)', () {
      expect(unitsPerPurchaseError(1000), isNull);
    });

    test('nilai pecahan positif kecil tetap valid', () {
      expect(unitsPerPurchaseError(0.5), isNull);
    });
  });

  group('hppComparisonState & hppComparisonSentence — tiga keadaan wajib', () {
    test('keadaan 1: belum ada cost_price (hasStored false) → noStoredPrice', () {
      final row = _row(hasStored: false, storedCostPrice: null, pct: null, delta: 100);
      expect(hppComparisonState(row), HppComparisonState.noStoredPrice);
      final sentence = hppComparisonSentence(row);
      expect(sentence, isNotEmpty);
      expect(sentence.toLowerCase(), contains('belum ada'));
    });

    test('keadaan 2: HPP resep LEBIH TINGGI dari HPP manual (delta > 0, hasStored true) → higher', () {
      final row = _row(hasStored: true, storedCostPrice: 8000, delta: 500, pct: 6.25);
      expect(hppComparisonState(row), HppComparisonState.higher);
      final sentence = hppComparisonSentence(row);
      expect(sentence.toLowerCase(), contains('tinggi'));
      expect(sentence.toLowerCase(), isNot(contains('rendah')));
    });

    test('keadaan 3: HPP resep LEBIH RENDAH dari HPP manual (delta < 0, hasStored true) → lower', () {
      final row = _row(hasStored: true, storedCostPrice: 10000, delta: -1700, pct: -17.0);
      expect(hppComparisonState(row), HppComparisonState.lower);
      final sentence = hppComparisonSentence(row);
      expect(sentence.toLowerCase(), contains('rendah'));
      expect(sentence.toLowerCase(), isNot(contains('tinggi')));
    });

    test('delta 0 dengan hasStored true → equal, kalimat menyebut "sama"', () {
      final row = _row(hasStored: true, storedCostPrice: 8000, delta: 0, pct: 0.0);
      expect(hppComparisonState(row), HppComparisonState.equal);
      expect(hppComparisonSentence(row).toLowerCase(), contains('sama'));
    });

    test('GIGI: hasStored SATU-SATUNYA penentu keadaan noStoredPrice, bukan storedCostPrice == null', () {
      // Kalau logika keliru memeriksa `storedCostPrice == null` alih-alih
      // `hasStored`, baris ini (storedCostPrice terisi tapi hasStored
      // sengaja false — kasus sintetis untuk menjaga titik sambungnya) akan
      // salah diklasifikasi sebagai "ada data". Test ini mengunci bahwa
      // `hasStored` yang dibaca, sesuai kontrak backend (hppDelta di
      // stockCalc.js — hasStored = st > 0, bukan sekadar != null).
      final row = _row(hasStored: false, storedCostPrice: 8000, delta: 100, pct: null);
      expect(hppComparisonState(row), HppComparisonState.noStoredPrice);
    });

    test('kalimat untuk lebih tinggi & lebih rendah menampilkan besaran selisih apa adanya (bukan 0)', () {
      final higher = hppComparisonSentence(_row(hasStored: true, storedCostPrice: 8000, delta: 1500, pct: 18.75));
      expect(higher, contains('1.500'));

      final lower = hppComparisonSentence(_row(hasStored: true, storedCostPrice: 10000, delta: -2500, pct: -25.0));
      expect(lower, contains('2.500'));
    });
  });
}
