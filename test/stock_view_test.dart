import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/features/admin/data/admin_report_repository.dart';
import 'package:rehat_app/features/stock/application/stock_view.dart';
import 'package:rehat_app/features/stock/data/stock_repository.dart';
import 'package:rehat_app/shared/models/menu_item_model.dart';

/// Menguji logika penyajian MURNI fitur Manajemen Stok (Task 5) — tanpa
/// merender widget apa pun: label satuan, format harga per satuan, validasi
/// isi per satuan beli, dan kalimat selisih HPP untuk tiga keadaan.

HppRow _row({
  String menuItemId = 'm1',
  String name = 'Menu',
  int? storedCostPrice,
  int computedHot = 0,
  int computedIced = 0,
  int? delta,
  double? pct,
  bool complete = true,
  bool hasStored = false,
}) =>
    HppRow(
      menuItemId: menuItemId,
      name: name,
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

  group('livePricePreview (Task 6 — pratinjau harga per satuan dasar saat mengetik)', () {
    test(
        'GIGI WAJIB: kopi 1 kg Rp150.000 → pratinjau "Rp 150/gram" '
        '(supaya salah konversi 1000x ketahuan saat mengetik, bukan setelah '
        'merusak nilai stok — brief Task 6)', () {
      final s = livePricePreview(
        purchasePrice: 150000,
        unitsPerPurchase: 1000,
        baseUnit: 'g',
      );
      expect(s, formatCostPerUnit(150, 'g'));
      expect(s, contains('150'));
      expect(s, contains('gram'));
    });

    test('null selama isi per satuan beli belum valid (<= 0) — bukan hasil bagi-nol/infinity', () {
      expect(
        livePricePreview(purchasePrice: 150000, unitsPerPurchase: 0, baseUnit: 'g'),
        isNull,
      );
      expect(
        livePricePreview(purchasePrice: 150000, unitsPerPurchase: -5, baseUnit: 'g'),
        isNull,
      );
    });

    test('kolom isi per satuan beli masih kosong (ter-parse ke 0 oleh pemanggil) → null juga', () {
      // Widget form mem-parse text field kosong jadi 0 sebelum memanggil
      // fungsi ini -- kasus ini menegaskan ambang yang sama berlaku, bukan
      // exception saat pengguna belum selesai mengetik.
      expect(
        livePricePreview(purchasePrice: 0, unitsPerPurchase: 0, baseUnit: 'g'),
        isNull,
      );
    });

    test('mengikuti satuan dasar yang dipilih (ml, pcs) — bukan selalu gram', () {
      final ml = livePricePreview(purchasePrice: 24000, unitsPerPurchase: 1000, baseUnit: 'ml');
      expect(ml, contains('mililiter'));
      expect(ml, contains('24'));

      final pcs = livePricePreview(purchasePrice: 50000, unitsPerPurchase: 100, baseUnit: 'pcs');
      expect(pcs, contains('pcs'));
      expect(pcs, contains('500'));
    });

    test('pecahan (es batu Rp35.000/10kg = Rp3,5/g) tidak dibulatkan sebelum diformat', () {
      final s = livePricePreview(purchasePrice: 35000, unitsPerPurchase: 10000, baseUnit: 'g');
      // formatCostPerUnit membulatkan TAMPILAN lewat Formatters.rupiah
      // (decimalDigits:0) -> "Rp 4/gram", TAPI nilai yang dibagi sebelum
      // sampai ke situ tetap 3.5 utuh (bukan .round() manual di
      // livePricePreview sendiri) -- disamakan langsung terhadap
      // formatCostPerUnit(3.5, 'g') supaya titik pembulatan tunggal terjaga.
      expect(s, formatCostPerUnit(3.5, 'g'));
    });

    test('TIDAK memanggil ambang unitsPerPurchaseError sendiri — pemanggil tetap wajib '
        'menjalankannya terpisah untuk pesan validasi submit', () {
      // Bukti tak-langsung: livePricePreview mengembalikan non-null persis
      // pada unitsPerPurchase yang membuat unitsPerPurchaseError null juga
      // (>0) -- keduanya SEPAKAT pada ambang yang sama walau independen.
      expect(unitsPerPurchaseError(1000), isNull);
      expect(
        livePricePreview(purchasePrice: 1000, unitsPerPurchase: 1000, baseUnit: 'g'),
        isNotNull,
      );
      expect(unitsPerPurchaseError(0), isNotNull);
      expect(
        livePricePreview(purchasePrice: 1000, unitsPerPurchase: 0, baseUnit: 'g'),
        isNull,
      );
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

  group('sortMenusByPopularity (Task 7 — daftar menu layar Entri Resep)', () {
    MenuItemModel menu(String id, String name, {int costPrice = 0}) => MenuItemModel(
          id: id,
          name: name,
          price: 20000,
          costPrice: costPrice,
        );

    test('menu di topItems ditaruh di atas, mengikuti URUTAN backend (BUKAN diurutkan ulang)', () {
      // Backend sudah mengurutkan berdasar quantity descending — fungsi ini
      // TIDAK boleh menyusun ulang berdasar field lain (mis. quantity) karena
      // ties/rounding adalah keputusan backend.
      final rows = sortMenusByPopularity(
        menus: [menu('c', 'Cappuccino'), menu('a', 'Americano'), menu('l', 'Latte')],
        topItems: const [
          TopItem(name: 'Latte', quantity: 50, revenue: 0),
          TopItem(name: 'Cappuccino', quantity: 30, revenue: 0),
        ],
        hppRows: const [],
      );
      expect(rows.map((r) => r.id).toList(), ['l', 'c', 'a'],
          reason: 'Latte & Cappuccino ada di topItems (urutan backend dipertahankan), '
              'Americano tak ada di topItems jadi taruh terakhir');
    });

    test('menu TIDAK di topItems ditaruh setelah yang ada, diurutkan ALFABETIS', () {
      final rows = sortMenusByPopularity(
        menus: [menu('z', 'Zebra Mocha'), menu('a', 'Avocado Coffee'), menu('m', 'Matcha')],
        topItems: const [TopItem(name: 'Matcha', quantity: 10, revenue: 0)],
        hppRows: const [],
      );
      expect(rows.map((r) => r.name).toList(), ['Matcha', 'Avocado Coffee', 'Zebra Mocha']);
    });

    test('join key adalah nama PERSIS (exact match) — nama beda sama sekali tak cocok', () {
      final rows = sortMenusByPopularity(
        menus: [menu('a', 'Kopi Susu'), menu('b', 'Es Teh')],
        topItems: const [TopItem(name: 'kopi susu', quantity: 99, revenue: 0)], // beda kapital
        hppRows: const [],
      );
      // Tak ada yang cocok (exact match, case-sensitive) -> keduanya jatuh ke
      // jalur alfabetis.
      expect(rows.map((r) => r.name).toList(), ['Es Teh', 'Kopi Susu']);
    });

    test('hasRecipe diambil dari HppRow.complete, dicocokkan lewat menuItemId', () {
      final rows = sortMenusByPopularity(
        menus: [menu('a', 'A'), menu('b', 'B')],
        topItems: const [],
        hppRows: const [
          HppRow(menuItemId: 'a', complete: true),
          HppRow(menuItemId: 'b', complete: false),
        ],
      );
      final byId = {for (final r in rows) r.id: r};
      expect(byId['a']!.hasRecipe, isTrue);
      expect(byId['b']!.hasRecipe, isFalse);
    });

    test('menu TANPA baris HppRow sama sekali diperlakukan hasRecipe FALSE (aman, bukan crash)', () {
      final rows = sortMenusByPopularity(
        menus: [menu('a', 'A')],
        topItems: const [],
        hppRows: const [], // 'a' tidak muncul sama sekali
      );
      expect(rows.single.hasRecipe, isFalse);
    });

    test('costPrice ikut dibawa apa adanya dari MenuItemModel', () {
      final rows = sortMenusByPopularity(
        menus: [menu('a', 'A', costPrice: 7500)],
        topItems: const [],
        hppRows: const [],
      );
      expect(rows.single.costPrice, 7500);
    });
  });

  group('computeMenuHpp (Task 7 — port menuHpp dari stockCalc.js backend)', () {
    test('baris umum (temperature null) masuk hitungan KEDUA varian', () {
      final lines = [const LocalRecipeLine(qtyBase: 200, costPerBase: 5, temperature: null)]; // 1000
      expect(computeMenuHpp(lines, 'hot'), 1000);
      expect(computeMenuHpp(lines, 'iced'), 1000);
    });

    test(
        'GIGI WAJIB: baris khusus hot TIDAK masuk hitungan iced, dan sebaliknya '
        '(hot & iced HARUS menghasilkan total BERBEDA & benar atribusinya — '
        'menukar cabang if di implementasi wajib membuat test ini gagal)', () {
      final lines = [
        const LocalRecipeLine(qtyBase: 100, costPerBase: 3, temperature: 'hot'), // 300, hanya hot
        const LocalRecipeLine(qtyBase: 50, costPerBase: 8, temperature: 'iced'), // 400, hanya iced
        const LocalRecipeLine(qtyBase: 10, costPerBase: 10, temperature: null), // 100, keduanya
      ];
      final hot = computeMenuHpp(lines, 'hot');
      final iced = computeMenuHpp(lines, 'iced');
      expect(hot, 400, reason: '300 (baris hot) + 100 (baris umum) = 400');
      expect(iced, 500, reason: '400 (baris iced) + 100 (baris umum) = 500');
      expect(hot, isNot(equals(iced)), reason: 'hot & iced wajib beda karena baris khusus beda nilai');
    });

    test('dibulatkan SEKALI di akhir (bukan per baris) — pecahan menumpuk benar', () {
      // 3 baris @ 0.4 masing-masing -> jumlah 1.2, dibulatkan sekali jadi 1.
      // Bila dibulatkan PER BARIS dulu (masing-masing round ke 0), hasilnya
      // salah jadi 0.
      final lines = [
        const LocalRecipeLine(qtyBase: 1, costPerBase: 0.4, temperature: null),
        const LocalRecipeLine(qtyBase: 1, costPerBase: 0.4, temperature: null),
        const LocalRecipeLine(qtyBase: 1, costPerBase: 0.4, temperature: null),
      ];
      expect(computeMenuHpp(lines, 'hot'), 1);
    });

    test('daftar baris kosong -> 0', () {
      expect(computeMenuHpp(const [], 'hot'), 0);
    });
  });

  group('computeHppDelta (Task 7 — sentinel null vs 0, mirip hppDelta backend)', () {
    test(
        'GIGI WAJIB: storedCostPrice NULL -> delta & pct NULL (bukan 0) — '
        'tak boleh menampilkan selisih PALSU untuk menu tanpa cost_price', () {
      final r = computeHppDelta(computed: 5000, storedCostPrice: null);
      expect(r.hasStored, isFalse);
      expect(r.delta, isNull);
      expect(r.pct, isNull);
    });

    test(
        'GIGI WAJIB: storedCostPrice 0 (belum pernah diisi) -> hasStored FALSE, '
        'delta & pct NULL juga (0 BUKAN nilai valid untuk dibandingkan)', () {
      final r = computeHppDelta(computed: 5000, storedCostPrice: 0);
      expect(r.hasStored, isFalse);
      expect(r.delta, isNull);
      expect(r.pct, isNull);
    });

    test('storedCostPrice > 0 -> hasStored true, delta & pct dihitung', () {
      final r = computeHppDelta(computed: 8500, storedCostPrice: 8000);
      expect(r.hasStored, isTrue);
      expect(r.delta, 500);
      expect(r.pct, closeTo(6.25, 0.001));
    });

    test('computed lebih rendah dari stored -> delta negatif', () {
      final r = computeHppDelta(computed: 6000, storedCostPrice: 10000);
      expect(r.hasStored, isTrue);
      expect(r.delta, -4000);
      expect(r.pct, closeTo(-40.0, 0.001));
    });
  });

  group('sortHppRowsByBiggestDifference (Task 8 — urutan layar Perbandingan HPP)', () {
    test('baris berperingkat diurutkan berdasar NILAI ABSOLUT delta, TERBESAR di atas', () {
      final rows = [
        _row(menuItemId: 'kecil', hasStored: true, complete: true, delta: 50),
        _row(menuItemId: 'besarNegatif', hasStored: true, complete: true, delta: -900),
        _row(menuItemId: 'sedang', hasStored: true, complete: true, delta: 300),
      ];
      final sorted = sortHppRowsByBiggestDifference(rows);
      expect(sorted.map((r) => r.menuItemId).toList(), ['besarNegatif', 'sedang', 'kecil'],
          reason: 'selisih -900 (|900|) wajib di atas +300 dan +50, walau NEGATIF — '
              'HPP terlalu tinggi & terlalu rendah sama-sama layak diperhatikan pemilik');
    });

    test('baris tanpa delta nyata (!complete ATAU complete&&!hasStored) ditaruh SETELAH '
        'semua baris berperingkat, diurutkan ALFABETIS', () {
      final rows = [
        _row(menuItemId: 'a', name: 'Zebra Mocha', hasStored: false, complete: false), // no recipe
        _row(menuItemId: 'b', name: 'Kecil', hasStored: true, complete: true, delta: 10),
        _row(menuItemId: 'c', name: 'Avocado Coffee', hasStored: false, complete: true), // recipe, no cost_price
      ];
      final sorted = sortHppRowsByBiggestDifference(rows);
      expect(sorted.map((r) => r.name).toList(), ['Kecil', 'Avocado Coffee', 'Zebra Mocha'],
          reason: '"Kecil" satu-satunya baris berperingkat (delta nyata) → di atas; '
              'dua sisanya (tanpa delta nyata) diurutkan alfabetis di bawahnya');
    });

    test('GIGI: menukar ke perbandingan delta MENTAH (bukan .abs()) membuat test ini gagal — '
        'delta negatif besar wajib tetap di atas delta positif kecil', () {
      final rows = [
        _row(menuItemId: 'positifKecil', hasStored: true, complete: true, delta: 20),
        _row(menuItemId: 'negatifBesar', hasStored: true, complete: true, delta: -5000),
      ];
      final sorted = sortHppRowsByBiggestDifference(rows);
      expect(sorted.first.menuItemId, 'negatifBesar');
    });

    test('daftar kosong -> daftar kosong', () {
      expect(sortHppRowsByBiggestDifference(const []), isEmpty);
    });
  });

  group('hppRowVisualState (Task 8 — tiga keadaan tampilan WAJIB berbeda)', () {
    test('keadaan 1: !complete -> noRecipe, TERLEPAS dari hasStored', () {
      expect(hppRowVisualState(_row(complete: false, hasStored: false)),
          HppRowVisualState.noRecipe);
      // GIGI: cost_price lama ADA tapi resep BELUM ada -> tetap noRecipe,
      // BUKAN noStoredPrice/compared. Kalau implementasi keliru memeriksa
      // hasStored duluan, baris ini akan salah diklasifikasi.
      expect(hppRowVisualState(_row(complete: false, hasStored: true, storedCostPrice: 8000)),
          HppRowVisualState.noRecipe);
    });

    test('keadaan 2: complete && !hasStored -> noStoredPrice', () {
      expect(hppRowVisualState(_row(complete: true, hasStored: false)),
          HppRowVisualState.noStoredPrice);
    });

    test('keadaan 3: complete && hasStored -> compared (termasuk saat delta 0)', () {
      expect(
        hppRowVisualState(_row(complete: true, hasStored: true, storedCostPrice: 8000, delta: 0)),
        HppRowVisualState.compared,
      );
      expect(
        hppRowVisualState(
            _row(complete: true, hasStored: true, storedCostPrice: 8000, delta: 500)),
        HppRowVisualState.compared,
      );
    });

    test('ketiga keadaan SALING BERBEDA satu sama lain (bukti gigi utama brief)', () {
      final states = {
        hppRowVisualState(_row(complete: false, hasStored: false)),
        hppRowVisualState(_row(complete: true, hasStored: false)),
        hppRowVisualState(_row(complete: true, hasStored: true, storedCostPrice: 8000, delta: 0)),
      };
      expect(states.length, 3, reason: 'ketiga keadaan wajib jadi tiga nilai enum BERBEDA');
    });
  });

  group('eligibleHppImpactInputs (Task 8 — saring menu layak masuk dampak gabungan)', () {
    test('hanya menu hasStored&&complete DAN terjual (qty>0) yang ikut', () {
      final rows = [
        _row(menuItemId: 'a', name: 'Latte', hasStored: true, complete: true, delta: 500),
        _row(menuItemId: 'b', name: 'Americano', hasStored: false, complete: true, delta: null),
        _row(menuItemId: 'c', name: 'Cappuccino', hasStored: true, complete: false, delta: null),
        _row(menuItemId: 'd', name: 'Matcha', hasStored: true, complete: true, delta: 200),
      ];
      final eligible = eligibleHppImpactInputs(
        hppRows: rows,
        topItems: const [
          TopItem(name: 'Latte', quantity: 40, revenue: 0),
          TopItem(name: 'Americano', quantity: 99, revenue: 0), // tak eligible (hasStored false)
          TopItem(name: 'Cappuccino', quantity: 99, revenue: 0), // tak eligible (!complete)
          // 'Matcha' TIDAK muncul di topItems -> quantity 0 -> tersaring.
        ],
      );
      expect(eligible.length, 1);
      expect(eligible.single.delta, 500);
      expect(eligible.single.quantity, 40);
    });

    test('join key nama PERSIS (case-sensitive) — beda kapital tak cocok, tersaring', () {
      final rows = [_row(menuItemId: 'a', name: 'Kopi Susu', hasStored: true, complete: true, delta: 100)];
      final eligible = eligibleHppImpactInputs(
        hppRows: rows,
        topItems: const [TopItem(name: 'kopi susu', quantity: 50, revenue: 0)],
      );
      expect(eligible, isEmpty);
    });

    test('daftar hppRows kosong -> daftar kosong', () {
      expect(
        eligibleHppImpactInputs(hppRows: const [], topItems: const [TopItem(name: 'x', quantity: 1, revenue: 0)]),
        isEmpty,
      );
    });
  });

  group('computeWeightedHppImpact (Task 8 — dampak gabungan DITIMBANG porsi terjual)', () {
    test('daftar kosong -> weightedDelta null, menuCount 0 ("belum cukup data", bukan Rp0)', () {
      final r = computeWeightedHppImpact(const []);
      expect(r.weightedDelta, isNull);
      expect(r.menuCount, 0);
    });

    test('satu menu -> weightedDelta = delta menu itu sendiri', () {
      final r = computeWeightedHppImpact(const [HppImpactInput(delta: 700, quantity: 10)]);
      expect(r.weightedDelta, 700.0);
      expect(r.menuCount, 1);
    });

    test('perhitungan dasar: Σ(qty×delta)/Σqty', () {
      final r = computeWeightedHppImpact(const [
        HppImpactInput(delta: 100, quantity: 10), // 1000
        HppImpactInput(delta: 400, quantity: 5), // 2000
      ]);
      // (1000 + 2000) / 15 = 200.0
      expect(r.weightedDelta, closeTo(200.0, 0.0001));
      expect(r.menuCount, 2);
    });

    test(
        'GIGI WAJIB: hasil DITIMBANG wajib BEDA dari rata-rata POLOS pada fixture di mana '
        'outlier volume rendah + delta besar akan menggeser rata-rata polos jauh, tapi '
        'TIDAK menggeser rata-rata tertimbang sebanyak itu (brief: "menu laris harus '
        'berbobot lebih besar")', () {
      const bestSeller = HppImpactInput(delta: 100, quantity: 500); // laris, selisih kecil
      const outlier = HppImpactInput(delta: 10000, quantity: 2); // nyaris tak laku, selisih raksasa

      final weighted = computeWeightedHppImpact(const [bestSeller, outlier]);
      final naiveAverage = (bestSeller.delta + outlier.delta) / 2; // rata-rata POLOS: 5050.0

      expect(weighted.weightedDelta, isNotNull);
      // Weighted = (500*100 + 2*10000) / 502 = 70000/502 ≈ 139.44
      expect(weighted.weightedDelta, closeTo(139.44, 0.5));
      expect(naiveAverage, 5050.0);
      expect(weighted.weightedDelta, isNot(closeTo(naiveAverage, 100)),
          reason: 'rata-rata tertimbang wajib TETAP DEKAT ke delta menu TERLARIS (100), '
              'bukan tertarik jauh oleh satu menu nyaris-tak-laku dengan selisih raksasa — '
              'kalau implementasi diam-diam berubah jadi rata-rata polos (Σdelta/n), test '
              'ini gagal karena weightedDelta akan mendekati 5050, bukan ~139');
      // Bukti tambahan: tertimbang jauh lebih dekat ke delta best-seller (100)
      // daripada ke rata-rata polos (5050).
      expect((weighted.weightedDelta! - bestSeller.delta).abs(),
          lessThan((weighted.weightedDelta! - naiveAverage).abs()));
    });

    test('delta negatif ikut terhitung benar (bukan nilai absolut)', () {
      final r = computeWeightedHppImpact(const [
        HppImpactInput(delta: -200, quantity: 10), // -2000
        HppImpactInput(delta: 100, quantity: 10), // 1000
      ]);
      // (-2000 + 1000) / 20 = -50.0
      expect(r.weightedDelta, closeTo(-50.0, 0.0001));
    });

    test('baris dengan quantity 0 disaring sendiri (jaring pengaman pembagi nol)', () {
      final r = computeWeightedHppImpact(const [
        HppImpactInput(delta: 999999, quantity: 0), // wajib DIABAIKAN
        HppImpactInput(delta: 300, quantity: 10),
      ]);
      expect(r.weightedDelta, closeTo(300.0, 0.0001));
      expect(r.menuCount, 1, reason: 'baris quantity 0 tidak ikut dihitung menuCount');
    });
  });
}
