# Manajemen Stok & HPP Terverifikasi — Rancangan

> Rehat Coffeehouse. Ditulis 12 Agustus 2026.
> Melanjutkan Modul Keuangan Tahap 1 & 2 (lihat `2026-08-09-manajemen-keuangan-design.md`).

---

## 1. Kenapa ini dibangun

Modul keuangan sekarang melacak **kas** (amplop alokasi) dan **laba** (laba rugi), tapi tidak
melacak **stok**. Padahal untuk kedai kopi, stok adalah pos modal kerja terbesar. Akibatnya:

| Gejala | Akar |
|---|---|
| Belanja bahan dipotong dua kali dari laba (Rp1,4 jt/bulan) | Tak ada tempat mencatat "uang berubah jadi barang, bukan hilang" |
| Margin 58,5% tak pernah bisa diuji benar/salah | `cost_price` diisi tangan, tak pernah dicocokkan ke belanja nyata |
| Tak tahu cup akan habis 8 hari lagi (dikira 3 minggu) | Tak ada yang menghitung laju pakai |
| Susut/terbuang/kelebihan takar tak terdeteksi | Tak ada pembanding antara "seharusnya terpakai" dan "nyatanya terpakai" |

Seluruh rambu keuangan (break-even, runway, rem tarik-pribadi) bertumpu pada margin yang belum
pernah diverifikasi. Kalau `cost_price` meleset 5 poin, semuanya meleset — dan tak ada mekanisme
yang akan memberi tahu.

**Sasaran:** persamaan ini selalu bisa diuji.

```
stok awal + pembelian − pemakaian ± susut = stok akhir
```

Kalau tidak seimbang, ada angka yang salah — dan pemilik langsung tahu di mana.

## 2. Skala nyata (data produksi, 12 Agt 2026)

| | |
|---|---|
| Omzet | ~Rp1,26 jt/hari (naik 2,6× dari Juli) |
| HPP | 41,5% dari omzet ≈ Rp15,7 jt/bulan |
| Menu | 58 (47 terjual Agustus); **21 menu = 80% omzet** |
| Porsi | ~90/hari, ~50 pesanan/hari |
| Bahan | ~100 jenis |
| Amplop restock | 42% omzet — terkalibrasi 1,2% terhadap HPP |

## 3. Konsep inti

### 3.1 Bahan (`ingredients`)

Satuan dasar per bahan: **g**, **ml**, atau **pcs**. Semua perhitungan internal memakai satuan
dasar. Pembelian boleh memakai satuan beli (kg, liter, dus) dengan faktor konversi tetap per
bahan — mis. kopi: satuan dasar `g`, satuan beli `kg`, konversi 1000.

### 3.2 Resep (`recipes`)

Satu menu → banyak baris bahan, masing-masing dengan takaran dalam satuan dasar.
Contoh: *Kopi Susu Pisang* = 18 g kopi + 120 ml susu + 30 ml sirup pisang + 1 pcs cup + 1 pcs sedotan.

**Varian suhu:** baris resep boleh diberi penanda `hot` / `iced`. Baris tanpa penanda berlaku
untuk keduanya — jadi menu yang tidak punya dua versi cukup didata sekali.

**Ukuran & gula sengaja TIDAK didukung.** Dasarnya data produksi (1.000 baris pesanan terakhir):

| Opsi | Pemakaian nyata | Putusan |
|---|---|---|
| Ukuran | **2 baris**, keduanya `regular` — cup kedai hanya satu ukuran | tidak didukung |
| Gula | 379 baris, **359 di antaranya 100%** — variasi tipis, ongkos receh | tidak didukung |
| **Suhu** | **168 panas vs 211 dingin** — hampir separuh-separuh | **didukung** |

Suhu mengubah bahan sungguhan (es batu, dan cup dingin yang berbeda dari cup panas), jadi
mengabaikannya membuat menu laris versi dingin tampak lebih untung dari kenyataan. Ukuran & gula
tidak mengubah ongkos secara berarti — mendukungnya hanya melipatgandakan pekerjaan pendataan.

> Catatan di luar lingkup: 57 menu masih menawarkan pilihan ukuran small/regular/large ke
> pelanggan padahal cup hanya satu ukuran. Menyesatkan pembeli; layak dicabut dari definisi menu
> di pekerjaan terpisah.

**HPP menu jadi terhitung, bukan diisi tangan:** `cost_price` berhenti jadi sumber kebenaran dan
menjadi angka turunan dari resep × harga rata-rata bahan.

### 3.3 Penerimaan barang (`stock_receipts` + `stock_receipt_items`)

Menggantikan pencatatan pengeluaran ber-pos Restock. Satu penerimaan = satu transaksi belanja,
boleh berisi banyak bahan (belanja pasar sekali jalan). Menambah stok, **bukan** biaya di laba.

Tetap memotong **amplop restock** — uangnya memang keluar. Jadi satu pencatatan, dua akibat:
stok naik, amplop turun.

### 3.4 Pemakaian (`stock_consumption`)

Dihitung dari penjualan × resep, **diringkas satu baris per bahan per hari** (bukan per pesanan).
Pada ~90 porsi/hari ini menghasilkan ≤100 baris/hari, bukan ~500.

### 3.5 Opname (`stock_counts`)

Hitung fisik. Sistem menyodorkan **jumlah seharusnya** (dari perhitungan), pemilik mengisi
**jumlah nyata**, selisihnya tersimpan sebagai **susut**. Opname adalah **jangkar kebenaran** —
setelah opname, saldo stok direset ke hasil hitungan fisik.

### 3.6 Penyesuaian (`stock_adjustments`)

Pencatatan sadar di luar penjualan: tumpah, kedaluwarsa, dipakai untuk tester/latihan barista.
Terpisah dari susut hasil opname supaya keduanya bisa dibedakan saat menelusuri masalah.

## 4. Golongan ABC & jadwal opname

Opname harian atas 100 bahan ditolak dengan alasan: ~33 menit/hari, dan untuk bahan lambat
**ketelitian pengukuran lebih besar daripada pemakaian hariannya** — yang terukur cuma derau.

| Golongan | Isi | Opname | Perkiraan |
|---|---|---|---|
| **A** | nilai besar & cepat habis: kopi, susu, cup, sirup utama, es batu | **harian** | 12–15 bahan, ~5 menit |
| **B** | sirup lain, topping, kemasan | mingguan | ~30 bahan |
| **C** | bumbu & pelengkap receh | bulanan | ~55 bahan |

Golongan hanya menentukan **kapan sistem menagih**, bukan batas apa yang boleh dihitung — pemilik
selalu boleh menghitung apa pun kapan pun. Golongan bisa diubah per bahan.

## 5. Harga bahan: rata-rata bergerak tertimbang

Saat barang masuk:

```
rata2_baru = (stok_lama × rata2_lama + qty_masuk × harga_satuan_masuk) / (stok_lama + qty_masuk)
```

Dipilih karena stabil, standar, dan tidak menuntut pelacakan per-batch (FIFO) yang tak realistis
untuk kedai. Stok yang tercatat negatif diperlakukan nol dalam rumus ini agar rata-rata tak rusak.

## 6. Alur harian

Menempel pada **Tutup Kasir** yang sudah ada — bukan layar baru yang harus diingat:

1. Kasir membuka Tutup Kasir seperti biasa.
2. Sistem menghitung pemakaian hari itu dari penjualan × resep.
3. Muncul daftar bahan **golongan A** dengan jumlah seharusnya.
4. Kasir mengisi jumlah nyata (hanya angka; ~5 menit).
5. Selisih tersimpan sebagai susut, saldo stok direset ke hitungan fisik.
6. Bahan yang menembus batas minimum muncul sebagai **peringatan pesan ulang**.

Opname mingguan/bulanan muncul sebagai tugas tertunda saat jatuh tempo, bukan memaksa harian.

## 7. Sambungan ke modul yang sudah ada

| Modul lama | Perubahan |
|---|---|
| **HPP / `cost_price`** | Jadi angka turunan dari resep × rata-rata bahan. Kolom lama dipertahankan sebagai cadangan bagi menu yang belum punya resep |
| **Laba rugi** | HPP dari pemakaian nyata; belanja bahan **keluar** dari daftar biaya (jadi stok) → potong-dua-kali hilang secara struktural |
| **Amplop restock** | Tetap diisi 42% omzet, tetap dipotong oleh penerimaan barang. Kini berpasangan dengan **nilai stok** |
| **Uang di laci** | Tetap dipotong seluruh uang keluar termasuk belanja bahan — tidak berubah |
| **Pengeluaran** | Pos Restock berpindah ke alur penerimaan barang. Pos lain (Operasional, Pribadi, Scaling, Darurat) tidak berubah |

**Invarian baru yang bisa diperiksa siapa pun:**
`saldo amplop restock + nilai stok` ≈ uang yang disiapkan untuk bahan. Kalau jumlah ini terus
turun sementara omzet tetap, ada kebocoran.

## 8. Skema basis data (migrasi 019)

```
ingredients          id, name, base_unit, purchase_unit, units_per_purchase,
                     avg_cost, min_stock, abc_class, is_active
recipes              id, menu_item_id, ingredient_id, qty_base, temperature (nullable: hot|iced)
stock_receipts       id, received_at, total_cost, note, created_by, ledger_ref_id
stock_receipt_items  id, receipt_id, ingredient_id, qty_base, unit_cost
stock_consumption    id, ref_date, ingredient_id, qty_base, unit_cost   -- 1 baris/bahan/hari
stock_counts         id, counted_at, ingredient_id, qty_expected, qty_counted,
                     variance_qty, variance_value, created_by
stock_adjustments    id, adjusted_at, ingredient_id, qty_base, reason, created_by
```

Semua tabel **event-sourced** seperti `finance_ledger`: saldo stok tak pernah disimpan sebagai
kolom, selalu dihitung ulang. Migrasi dijalankan **manual di Supabase SQL Editor** (pola proyek).

**Idempotensi:** unique index parsial pada `stock_consumption (ref_date, ingredient_id)` dan pada
`stock_counts (counted_at::date, ingredient_id)` — perhitungan ulang tidak menggandakan baris.

## 9. Endpoint (semua owner-only, di balik `authenticate` + `requireFinanceAccess`)

```
GET/POST/PATCH  /admin/stock/ingredients
GET/PUT         /admin/stock/recipes/:menuItemId
POST            /admin/stock/receipts
GET             /admin/stock/balances          -- saldo + nilai stok + status pesan ulang
GET             /admin/stock/count-sheet?class=A   -- lembar opname + jumlah seharusnya
POST            /admin/stock/counts
POST            /admin/stock/adjustments
GET             /admin/stock/variance?month=   -- susut per bahan & nilainya
```

## 10. Layar Flutter

1. **Bahan** — daftar, saldo, nilai, status pesan ulang; ubah golongan ABC & batas minimum.
2. **Resep** — per menu, pilih bahan + takaran; menampilkan HPP terhitung dan margin di sampingnya.
3. **Terima Barang** — banyak bahan dalam satu transaksi.
4. **Opname** — lembar hitung, jumlah seharusnya di sisi kiri, isian nyata di kanan, selisih langsung terlihat.
5. **Ringkasan Keuangan** — tambah kartu **nilai stok** & **susut bulan ini**.
6. **Tutup Kasir** — sisipkan langkah opname golongan A.

## 11. Rollout bertahap (tiap fase bisa dideploy sendiri)

| Fase | Isi | Yang didapat |
|---|---|---|
| **A** | Master bahan + satuan + resep (data saja, perilaku belum berubah) | HPP terhitung bisa **dibandingkan** dengan `cost_price` lama — selisihnya langsung memberi tahu seberapa meleset tebakan selama ini |
| **B** | Penerimaan barang menggantikan pengeluaran pos Restock | Belanja bahan keluar dari laba → potong-dua-kali hilang |
| **C** | Pemakaian dari resep + opname harian golongan A | Susut terdeteksi harian; stok jadi angka nyata |
| **D** | Laba rugi & amplop beralih ke angka terverifikasi | Rambu keuangan berdiri di atas margin yang teruji |
| **E** | Titik pesan ulang + laporan susut | Peringatan sebelum kehabisan, bukan sesudah |

Fase A memberi hasil paling berharga dengan risiko paling kecil: **tanpa mengubah satu pun angka
yang sedang berjalan**, pemilik langsung tahu apakah HPP-nya selama ini benar.

**Prioritas pendataan:** 21 menu penyumbang 80% omzet dulu, sisanya menyusul. Menu tanpa resep
tetap memakai `cost_price` lama, jadi sistem berjalan campuran tanpa rusak.

## 12. Yang sengaja TIDAK dibangun

- **Pembukuan berpasangan / jurnal umum / neraca formal** — beban administrasi yang tak akan
  dipakai dan tak menghasilkan keputusan lebih baik untuk satu kedai.
- **FIFO / pelacakan per batch** — menuntut disiplin yang tak realistis; rata-rata bergerak cukup.
- **Kedaluwarsa per batch** — dicatat lewat penyesuaian manual bila perlu.
- **Multi-gudang / multi-outlet** — belum relevan.
- **Pemesanan otomatis ke pemasok** — peringatan pesan ulang cukup.

## 13. Risiko

| Risiko | Penanganan |
|---|---|
| **Opname berhenti dijalankan** → angka stok jadi salah tapi terlihat resmi | Tampilkan usia opname terakhir per bahan; angka yang basi ditandai, bukan disajikan sebagai fakta |
| **Pendataan resep 58 menu memakan waktu** | Mulai dari 21 menu penyumbang 80% omzet; sistem berjalan campuran |
| **Takaran barista tak seragam** → susut besar palsu | Justru inilah yang seharusnya ketahuan; bandingkan tren, bukan satu hari |
| **Satuan salah konversi** (kg vs g) → nilai stok meleset 1000× | Validasi ketat saat input, dan uji kewajaran: nilai stok yang melonjak tak wajar ditolak dengan peringatan |
| **Perubahan alur mengganggu operasional kasir** | Opname menempel di Tutup Kasir yang sudah jadi kebiasaan; golongan A saja (~5 menit) |

## 14. Keputusan yang sudah diambil pemilik

- Opname **bertingkat** (A harian / B mingguan / C bulanan), bukan harian penuh 100 bahan.
- Resep **didata** supaya HPP per produk nyata dan presisi.
- Resep mendukung **suhu** (panas/dingin), **tidak** mendukung ukuran & gula — lihat §3.2.
- **Pemilik sendiri** yang mendata resep, jadi layar resep cukup di balik gate keuangan yang
  sudah ada (`requireFinanceAccess`); tak perlu peran baru untuk barista.
- 7 menu tanpa HPP **tidak dihapus** — semuanya punya riwayat penjualan; 6 sudah tidak aktif.
- Pos `personal` tetap di luar laba rugi (prive), tetap memotong amplop.
