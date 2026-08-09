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
| HPP | Rp10.826.500 (**41,4%**) → **margin kotor 58,6%** |
| Biaya tetap bulanan | **Rp8.000.000** (ditetapkan pemilik, 9 Agt 2026) |
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

3. ~~**5 menu belum punya `cost_price`**~~ — **selesai 9 Agt 2026.** Pemilik telah
   mengisi HPP seluruh menu aktif. Enam menu yang masih kosong
   (Matcha Latte, Avocado Toast, Banana Bread, Cookies, Lemon Honey Tea,
   V60 Pour Over) semuanya `is_available = false` alias tidak dijual, sehingga
   tidak memengaruhi margin ke depan. Satu-satunya jejak historis adalah
   **Matcha Latte 5 pcs** yang terlanjur terjual tanpa HPP — dampaknya < 0,1%
   dan sengaja dibiarkan, bukan ditambal dengan angka karangan.

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

Diturunkan dari data riil, bukan dari template Profit First Amerika.
Basis: target omzet **Rp36jt/bulan**, HPP riil **41,4%**, biaya tetap **Rp8jt**.

| Pos | % | Nominal @Rp36jt | Kebutuhan riil | Selisih |
|---|---|---|---|---|
| Restock | **42%** | Rp15.120.000 | HPP Rp14.902.271 | +Rp217.729 |
| Operasional | **24%** | Rp8.640.000 | tetap Rp8jt + variabel & fee ±Rp603rb | +Rp37.000 |
| Pribadi | **18%** | Rp6.480.000 | gaji owner | — |
| Scaling | **9%** | Rp3.240.000 | alat, outlet, stok awal | — |
| Darurat | **7%** | Rp2.520.000 | target Rp25,8jt (3× biaya bulanan) | tercapai ±10 bulan |
| **Total** | **100%** | **Rp36.000.000** | | |

Catatan penting soal dua pos pertama: **surplusnya tipis** (Rp218rb dan Rp37rb
per bulan). Itu memang disengaja — Restock dan Operasional adalah kewajiban,
bukan tabungan; kelebihan besar di situ hanya menyembunyikan uang yang
seharusnya bisa diambil pemilik. Tapi konsekuensinya: **kalau omzet turun di
bawah Rp36jt/bulan, kedua pos ini yang pertama defisit.** Rambu runway di §6
ada persis untuk memberi sinyal itu lebih awal.

**Persentase ini adalah hasil kalibrasi, bukan konstanta yang ditanam di kode.**
Wizard menghitungnya ulang setiap kali biaya tetap atau target omzet berubah:

1. `pct_restock` = HPP riil 12 minggu terakhir, dibulatkan **ke atas** ke persen.
2. `pct_operational` = `(Σ fixed_costs + rata-rata biaya variabel + fee QRIS) ÷ target omzet`, dibulatkan **ke atas**.
3. Sisa = `100 − pct_restock − pct_operational`, dibagi ke Pribadi:Scaling:Darurat
   dengan rasio bawaan **2:1:0,8**, memakai **metode sisa terbesar**
   (*largest remainder*): bulatkan ke bawah dulu, lalu persen yang belum
   terbagi diberikan satu per satu ke pos dengan pecahan terbesar.
   Dengan sisa 34% hasilnya **18 / 9 / 7** — sesuai tabel di atas.
   (Pembulatan ke bawah polos lalu melempar semua sisa ke Pribadi akan
   menghasilkan 19/8/7 dan **tidak** cocok dengan tabel; jangan pakai cara itu.)
4. Semua boleh disunting manual, dengan slider yang dikunci agar total tetap 100.
5. Jika sisa ≤ 0%, wizard **menolak lanjut** dan menampilkan peringatan bahwa
   biaya tetap melebihi kapasitas omzet — kondisi itu berarti usaha belum layak
   ambil gaji owner, dan menyembunyikannya justru berbahaya.

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
Omzet                               Rp36.000.000
− HPP (Σ cost_price × qty)          Rp14.902.271   41,4%
= Laba Kotor                        Rp21.097.729   58,6%
− Biaya tetap (Σ fixed_costs aktif) Rp 8.000.000
− Biaya variabel non-restock        Rp   500.000
− Biaya transaksi QRIS (DOKU)       Rp   103.000
= Laba Bersih                       Rp12.494.729   34,7%
```

Bandingkan dengan alokasi: Pribadi + Scaling + Darurat = Rp12.240.000, yaitu
**98% dari laba bersih riil**. Sisa Rp254.729 mengendap sebagai buffer di pos
Restock dan Operasional. Angka alokasi tidak dikarang — ia memang menghabiskan
laba yang benar-benar ada.

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
| **Break-even harian** | biaya bulanan ÷ 30 ÷ margin kotor | Rp8,6jt/30/0,586 = **Rp489.192/hari**; Rehat Rp1.279.198 = aman **2,6×** |
| **Runway operasional** | saldo Operasional ÷ (biaya bulanan ÷ 30) | ditampilkan "cukup N hari" |
| **Rem tarik pribadi** | saldo Operasional < 1× biaya bulanan | tombol tarik Pribadi jadi merah + dialog konfirmasi |
| **Dana darurat selesai** | saldo ≥ **Rp25,8jt** (3× biaya bulanan) | sarankan alihkan 7% ke Scaling |
| **Alarm HPP** | realisasi restock > alokasi, 3 hari berturut | "HPP naik — cek harga bahan atau harga jual" |

**Definisi "biaya bulanan" di tabel ini = Rp8,6jt** — biaya tetap Rp8jt + biaya
variabel non-restock ±Rp500rb + fee QRIS ±Rp103rb. **HPP sengaja tidak termasuk**,
karena saat kedai sepi atau tutup, HPP ikut hilang sendiri sementara sewa dan
gaji tetap jalan. Itu pula dasar target dana darurat Rp25,8jt: tiga bulan
bertahan tanpa penjualan sama sekali.

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

1. ~~Isi `cost_price` untuk menu yang kosong.~~ **Selesai 9 Agt 2026** — seluruh
   menu aktif sudah ber-HPP; sisanya menu nonaktif. Tidak ada pekerjaan tersisa.
   Yang tetap perlu: **seed `fixed_costs` dengan biaya tetap Rp8.000.000** yang
   sudah ditetapkan pemilik. Rinciannya (sewa / gaji / listrik / wifi) belum
   dipecah — implementasi boleh memasukkannya sebagai satu baris
   "Biaya tetap bulanan" Rp8jt, dan pemilik memecahnya sendiri belakangan lewat
   layar Biaya Tetap. Memecah tanpa data = mengarang.
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
| `allocation_calculator` | Σ alokasi == omzet persis di banyak nominal acak; sisa rupiah selalu ke Restock; tolak Σ% ≠ 100 |
| Kalibrasi persen | metode sisa terbesar: input (HPP 41,4%, biaya Rp8,6jt, omzet Rp36jt) → **42/24/18/9/7**; Σ selalu 100 di berbagai input; tolak bila sisa ≤ 0 |
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
