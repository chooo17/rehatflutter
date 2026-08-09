# Modul Keuangan Rehat Coffeehouse — Desain

**Tanggal:** 2026-08-09
**Status:** disetujui, siap masuk rencana implementasi

---

## 1. Latar belakang & temuan data produksi

Desain ini dibangun di atas data produksi riil (dibaca read-only via `supabaseAdmin`,
rentang **30 Juni – 9 Agustus 2026**), bukan asumsi.

| Metrik | Nilai |
|---|---|
| Omzet total | Rp26.106.850 (944 pesanan, 31 hari aktif) |
| Baseline harian | Rp1.279.198/hari (13 hari penuh terakhir, 27 Jul–8 Agt) |
| Proyeksi bulanan | ≈ Rp38jt; dipakai konservatif **Rp36jt/bulan** |
| HPP | Rp10.332.500 → **margin kotor 60%** |
| Pengeluaran tercatat | Rp2.484.000 (**9,5% omzet**), 124 catatan, **0 berkategori** |
| Komposisi kas | Tunai 59% · QRIS 40% · lainnya 1% |
| Kanal | Kasir 93% · App 7% |
| Saldo wallet pelanggan | Rp0 (belum jadi kewajiban material) |

### Tiga cacat akuntansi yang jadi alasan modul ini ada

1. **Double counting.** `src/services/orderService.js:741` menghitung
   `netProfit = revenue − cogs − expenses − paymentFees`. Isi tabel `expenses`
   hampir seluruhnya restock bahan (SKM, es batu, cup, sedotan, minyak goreng) —
   yang **sudah** terhitung di `cogs` lewat `menu_items.cost_price`. Bahan yang
   sama dipotong dua kali, sehingga laba bersih yang dilaporkan terlalu rendah
   pada pos itu sekaligus menyesatkan.

2. **Biaya tetap tidak tercatat sama sekali.** Tidak ada satu pun catatan sewa,
   gaji, wifi, atau penyusutan alat — hanya 1× token listrik Rp52.000. Pemilik
   mengonfirmasi biaya-biaya ini **ada** tapi dicatat di luar app. Akibatnya laba
   bersih di dashboard **terlalu tinggi**, dan itu justru angka yang akan dipakai
   untuk memutuskan "berapa boleh diambil untuk pribadi".

3. **5 menu belum punya `cost_price`** — Air Mineral (108 pcs terjual),
   Hazelnut (48), Beef Pastry (3), Matcha (3), Matcha Latte (5). Margin sedikit
   di-overstate.

---

## 2. Keputusan desain

| Keputusan | Pilihan |
|---|---|
| Basis alokasi | **5 pos dari omzet kotor** (Restock, Operasional, Pribadi, Scaling, Darurat) |
| Sifat pos | **Amplop hidup** dengan saldo berjalan + pencatatan realisasi |
| Ritme alokasi | **Otomatis harian** saat tutup kasir |
| Biaya tetap | Modul tersendiri, terpisah dari `expenses` harian |
| Rekonsiliasi kas fisik | **Di luar scope** modul ini |

### Persentase pos

| Pos | % | Nominal @Rp36jt | Peran |
|---|---|---|---|
| Restock | 40% | Rp14,4jt | Amplop belanja bahan (HPP riil 39,6% — cocok) |
| Operasional | 22%* | Rp7,9jt | Sewa, gaji, listrik, air, wifi |
| Pribadi | 20% | Rp7,2jt | Gaji owner — dibayar rutin, bukan sisa |
| Scaling | 10% | Rp3,6jt | Alat baru, outlet, stok awal |
| Darurat | 8% | Rp2,9jt | Target 3× biaya bulanan |

\* **22% adalah placeholder tampilan saja, bukan default yang ditanam di kode.**
Wizard kalibrasi menghitung persentase Operasional sebagai
`Σ fixed_costs ÷ target_omzet_bulanan`, dibulatkan ke atas ke persen terdekat.
Sisa (100% − Restock − Operasional) dibagi ke Pribadi/Scaling/Darurat dengan
rasio bawaan 20:10:8 (dinormalisasi), lalu boleh disunting pemilik.
Jika perhitungan menghasilkan sisa ≤ 0%, wizard menolak lanjut dan menampilkan
peringatan bahwa biaya tetap melebihi kapasitas omzet.

---

## 3. Model data — buku besar amplop (event-sourced)

Saldo pos **tidak disimpan** sebagai kolom angka; ia dijumlah dari buku besar.
Alasannya: auditable, tidak bisa melenceng diam-diam, dan bebas dari race
condition penulisan bersamaan.

**Migrasi `016_add_finance_module.sql`** — 3 tabel baru + 1 kolom.

### `finance_settings` (baris tunggal)

| Kolom | Tipe | Catatan |
|---|---|---|
| `id` | uuid PK | |
| `monthly_revenue_target` | bigint | target omzet bulanan (rupiah) |
| `pct_restock` … `pct_emergency` | smallint ×5 | wajib berjumlah 100 (CHECK constraint) |
| `emergency_target` | bigint | target dana darurat |
| `started_on` | date | alokasi tidak berjalan mundur sebelum tanggal ini |
| `updated_at` | timestamptz | |

### `finance_ledger`

| Kolom | Tipe | Catatan |
|---|---|---|
| `id` | uuid PK | |
| `bucket` | text | `restock`\|`operational`\|`personal`\|`scaling`\|`emergency` |
| `direction` | text | `in`\|`out` |
| `amount` | bigint | selalu positif; arah ditentukan `direction` |
| `source` | text | `allocation`\|`withdrawal`\|`expense`\|`adjustment` |
| `ref_date` | date | hari WIB yang diwakili |
| `ref_id` | uuid null | mis. `expenses.id` |
| `note`, `created_by`, `created_at` | | |

**Kunci idempotensi:**
`CREATE UNIQUE INDEX ... ON finance_ledger (bucket, ref_date) WHERE source = 'allocation'`
— tutup kasir dibuka dua kali tidak menggandakan alokasi.

Indeks pendukung: `(bucket, created_at DESC)` untuk layar riwayat.

### `fixed_costs`

`id`, `name`, `amount` (bigint), `category`, `due_day` (smallint 1–31, boleh null),
`is_active` (bool), `created_at`.

### `expenses.bucket`

Kolom teks baru — pos mana yang dipotong saat pengeluaran dicatat.
Default `restock`. Mengikuti **pola defensif wajib** proyek ini (lihat CLAUDE.md §3):
query yang menyentuh kolom ini harus mencoba dengan kolom lalu mengulang tanpa
kolom bila error menyebutnya, supaya migrasi yang tertinggal tidak merusak alur
pembayaran.

---

## 4. Mesin alokasi

Dipicu saat tutup kasir (`GET /admin/reports/closing` sudah ada) dan juga bisa
dipanggil manual.

1. Ambil omzet hari itu memakai helper WIB terpusat `wibDayRange` di
   `orderService.js` — **jangan** memakai batas hari UTC.
2. Pecah ke 5 pos menurut persentase aktif.
3. **Pembulatan:** tiap pos dibulatkan ke bawah ke rupiah bulat; **selisih sisa
   dilempar seluruhnya ke pos Restock**, sehingga `Σ alokasi == omzet` persis.
4. Tulis 5 baris `finance_ledger` dengan `source='allocation'`, `direction='in'`.
   Konflik pada unique index = hari itu sudah dialokasikan → operasi tidak
   melakukan apa-apa (idempoten), bukan error.
5. Alokasi tidak berjalan untuk tanggal sebelum `finance_settings.started_on`.

**Pengurangan pos** terjadi saat:
- pengeluaran dicatat → `direction='out'` pada `expenses.bucket`
- penarikan pribadi/scaling/darurat → `source='withdrawal'`
- koreksi manual → `source='adjustment'`

Saldo pos boleh negatif (menandakan overspend) dan ditampilkan merah — modul
tidak memblokir pencatatan realitas.

---

## 5. Laporan Laba Rugi

Menggantikan perhitungan `net_profit` yang sekarang keliru.

```
Omzet                              Rp36.000.000
− HPP (Σ cost_price × qty)         Rp14.400.000
= Laba Kotor                       Rp21.600.000   60%
− Biaya tetap (Σ fixed_costs aktif) Rp 8.000.000
− Biaya variabel non-restock        Rp   500.000
− Biaya transaksi QRIS (DOKU)       Rp   103.000
= Laba Bersih                      Rp12.997.000   36%
```

**Perubahan kritis:** pengeluaran dengan `bucket='restock'` **tidak dikurangkan
lagi** di sini — sudah terhitung di HPP. Hanya `expenses` dengan bucket selain
`restock` yang masuk sebagai biaya variabel. Inilah perbaikan double-counting-nya.

Kompatibilitas: `net_profit` lama tetap dikembalikan oleh `/admin/reports/sales`
agar dashboard yang ada tidak pecah, tetapi layar Laba Rugi memakai perhitungan
baru dan menjadi sumber kebenaran.

---

## 6. Rambu keputusan

Bagian "manajemen"-nya — yang membedakan modul ini dari sekadar laporan.

| Rambu | Rumus | Nilai Rehat saat ini |
|---|---|---|
| **Break-even harian** | biaya tetap ÷ 30 ÷ margin kotor | Rp8jt/30/0,6 = **Rp444.444/hari**; Rehat Rp1,28jt = aman **2,9×** |
| **Runway operasional** | saldo Operasional ÷ (biaya tetap ÷ 30) | ditampilkan "cukup N hari" |
| **Rem tarik pribadi** | saldo Operasional < 1× biaya tetap bulanan | tombol tarik Pribadi jadi merah + dialog konfirmasi |
| **Dana darurat selesai** | saldo ≥ 3× biaya bulanan | sarankan alihkan 8% ke Scaling |
| **Alarm HPP** | realisasi restock > alokasi, 3 hari berturut | "HPP naik — cek harga bahan atau harga jual" |

Rambu bersifat **informatif dan tidak memblokir**, kecuali rem tarik pribadi yang
menambahkan satu langkah konfirmasi.

---

## 7. Endpoint backend

Semua di bawah guard admin yang sudah ada.

| Method | Path | Fungsi |
|---|---|---|
| GET | `/admin/finance/overview` | saldo 5 pos, alokasi bulan berjalan, rambu |
| GET/PUT | `/admin/finance/settings` | baca/simpan kalibrasi (validasi Σ% = 100) |
| POST | `/admin/finance/allocate` | jalankan alokasi untuk `date` (idempoten) |
| POST | `/admin/finance/withdraw` | tarik dari pos; body `{bucket, amount, note}` |
| GET | `/admin/finance/ledger` | riwayat mutasi, filter pos & rentang |
| GET/POST/DELETE | `/admin/finance/fixed-costs` | CRUD biaya tetap |
| GET | `/admin/finance/pnl?month=YYYY-MM` | laba rugi bulanan |

Mengikuti envelope proyek: `{ success, data, message }`.

---

## 8. Frontend

Fitur baru `lib/features/finance/` mengikuti pola feature-first proyek
(`data` / `application` / `presentation`).

```
lib/features/finance/
  data/finance_repository.dart          model + repository + provider Riverpod
  application/allocation_calculator.dart  pembulatan & validasi %, murni & teruji
  presentation/finance_overview_screen.dart
  presentation/finance_setup_screen.dart    wizard kalibrasi
  presentation/profit_loss_screen.dart
  presentation/fixed_costs_screen.dart
  presentation/finance_ledger_screen.dart
  presentation/widgets/bucket_card.dart
  presentation/widgets/allocation_sliders.dart   slider terkunci total 100%
```

- Rute baru di `core/router/route_names.dart` + `app_router.dart`.
- Pintu masuk: kartu "Keuangan" di dashboard admin.
- Gating: hanya `UserModel.isAdmin`.
- **Wajib** pakai `Formatters.toWib` untuk semua tanggal — jangan `DateFormat` langsung.
- **Wajib** ingat `AppColors` adalah getter runtime, bukan const.
- Pakai widget `Neu*` yang ada agar konsisten.
- Pola *keep-previous-data*: spinner hanya saat `valueOrNull == null`.

---

## 9. Prasyarat data

Dikerjakan sebagai bagian implementasi, bukan diserahkan ke pemilik:

1. Isi `cost_price` untuk 5 menu yang kosong (butuh input nominal dari pemilik;
   sediakan layar/skrip, jangan menebak angka).
2. Backfill `expenses.bucket = 'restock'` untuk 124 catatan lama — sesuai isi
   catatannya yang memang semuanya bahan. Dapat dikoreksi manual setelahnya.
3. Migrasi `016` dijalankan **manual di Supabase SQL Editor** (`DATABASE_URL`
   adalah placeholder — `pg`/psql tidak jalan), lalu diverifikasi dengan skrip
   `src/db/verify-016.js` bergaya skrip verify yang sudah ada.
4. Perbarui tabel status migrasi di `CLAUDE.md` §3 pada commit yang sama.

---

## 10. Pengujian

| Unit | Yang diuji |
|---|---|
| `allocation_calculator` | Σ alokasi == omzet persis di banyak nominal acak; sisa selalu ke Restock; tolak Σ% ≠ 100 |
| Mesin alokasi (backend) | idempotensi (panggil 2×, ledger tetap 5 baris); hormati `started_on`; batas hari WIB benar |
| Kalkulator P&L | restock tidak dipotong dua kali; biaya tetap masuk; QRIS fee benar |
| Rambu | break-even, runway, ambang rem tarik pribadi |

Gate CI yang berlaku: `flutter analyze --fatal-infos` + `flutter test`.

---

## 11. Batasan yang dinyatakan terbuka

- **Saldo pos adalah saldo buku, bukan saldo bank.** QRIS (40% omzet) baru cair
  setelah DOKU settle, jadi pos bisa menunjukkan uang yang belum sepenuhnya ada
  di tangan. Rekonsiliasi ke kas fisik sengaja di luar scope.
- **Alokasi berbasis omzet, bukan kas diterima.** Pesanan yang di-refund setelah
  dialokasikan tidak otomatis membalik ledger; koreksi dilakukan lewat
  `source='adjustment'`. Volume refund saat ini nihil sehingga risikonya kecil.
- **Satu outlet.** Skema tidak menyediakan dimensi outlet.
- **Biaya tetap dianggap rata per hari** (÷30) untuk runway dan break-even,
  walaupun pembayaran riilnya menumpuk di tanggal tertentu.
