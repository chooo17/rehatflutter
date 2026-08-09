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
| Cara membagi | **Waterfall berurutan**, bukan lima persentase paralel |
| Sifat pos | **Amplop hidup** dengan saldo berjalan + pencatatan realisasi |
| Ritme alokasi | **Otomatis harian** saat tutup kasir |
| Parameter | **Auto-kalibrasi bertingkat**; perubahan butuh persetujuan pemilik |
| Biaya tetap | Modul tersendiri, terpisah dari `expenses` harian |
| Rekonsiliasi kas fisik | **Di luar scope** modul ini |

### Persentase pos

Diturunkan dari data riil, bukan dari template Profit First Amerika.
Basis: target omzet **Rp36jt/bulan**, HPP riil **41,4%**, biaya tetap **Rp8jt**.

Alokasi berjalan **berurutan (waterfall)**, bukan lima persentase paralel.
Alasannya ada di bawah tabel.

| Urutan | Pos | Aturan | Nominal @Rp36jt |
|---|---|---|---|
| 1 | Restock | **42% dari omzet** | Rp15.120.000 |
| 2 | Operasional | **nominal Rp286.667/hari** | Rp8.600.010 |
| 3 | Sisa dibagi 2 : 1 : 0,8 | Pribadi | Rp6.463.000 |
| | | Scaling | Rp3.232.000 |
| | | Darurat | Rp2.585.000 |
| | **Total** | | **Rp36.000.000** |

### Kenapa Operasional nominal, bukan persentase

Sewa dan gaji tidak peduli omzet. Persentase membuat pos ini ikut menyusut
justru ketika ia paling dibutuhkan:

| Skenario | Operasional @24% | Operasional nominal |
|---|---|---|
| Omzet Rp36jt | Rp8,64jt ✅ | Rp8,6jt ✅ |
| Omzet Rp30jt | Rp7,20jt ❌ **defisit Rp1,4jt — sewa tak terbayar** | Rp8,6jt ✅ |

Dengan waterfall, yang menyusut saat omzet turun adalah **bagian pemilik**
(Pribadi/Scaling/Darurat), bukan kewajiban. Itu perilaku yang benar secara
ekonomi: owner adalah penerima sisa, bukan penerima prioritas.

Contoh omzet Rp30jt: Restock Rp12,6jt (HPP riil Rp12,42jt ✓), Operasional
Rp8,6jt penuh, sisa Rp8,8jt → Pribadi Rp4,63jt / Scaling Rp2,32jt /
Darurat Rp1,85jt.

### Titik kritis

Sisa menjadi nol saat omzet **≈ Rp14,83jt/bulan** (`0,58 × omzet = Rp8,6jt`) —
sejalan dengan break-even harian Rp489.192 di §8. Di bawah itu:

- Pribadi, Scaling, Darurat dialokasi **Rp0** (bukan negatif);
- Operasional menerima sisa yang ada dan **kekurangannya dicatat** sebagai
  `shortfall` di ledger, ditampilkan merah di ringkasan.

Modul mencatat kenyataan, tidak memaksa angka tetap terlihat sehat.

### Restock tetap persentase

Restock memang proporsional terhadap penjualan, jadi persentase tepat.
Angka 42% diambil sedikit di atas HPP riil 41,4% sebagai bantalan tipis
(+Rp218rb/bulan) — cukup untuk fluktuasi harga bahan, tidak cukup untuk
menyembunyikan uang yang seharusnya bisa diambil pemilik.

### Parameter kalibrasi

Hanya ada **tiga angka** yang perlu ditetapkan, sisanya turunan:

| Parameter | Nilai awal | Sumber |
|---|---|---|
| `pct_restock` | 42% | HPP riil terobservasi + bantalan 0,6 poin |
| `operational_daily` | Rp286.667 | (biaya tetap Rp8jt + variabel Rp500rb + fee QRIS Rp103rb) ÷ 30 |
| rasio sisa | 2 : 1 : 0,8 | kebijakan pemilik, dapat disunting |

Ketiganya **bukan konstanta yang ditanam di kode**. `pct_restock` dan
`operational_daily` diperbarui oleh mesin auto-kalibrasi (§5), rasio sisa hanya
berubah bila pemilik menyuntingnya. Wizard menolak konfigurasi yang membuat
titik kritis melampaui baseline omzet terobservasi — artinya usaha belum layak
ambil gaji owner, dan menyembunyikannya justru berbahaya.

---

## 3. Kontrol akses — khusus pemilik

Modul ini menampilkan penghasilan pribadi pemilik. Ia **tidak boleh** terbuka
untuk seluruh admin — hanya untuk **087864504924 (`irurr`)**.

Ini lebih ketat daripada gating admin yang sudah ada di proyek. Saat ini ada
**dua** akun ber-`role: admin`:

| Nomor | Nama | Akses keuangan |
|---|---|---|
| 087864504924 | `irurr` | ✅ **ya** |
| 087777601617 | `irur` | ❌ **tidak** |

### Mekanisme: flag di database, bukan nomor di kode

Tambahkan kolom **`users.can_access_finance`** (boolean, default `false`),
di-seed `true` hanya untuk id `649a989c-e9c2-45d4-815d-f95b7df158bc`
(= 087864504924).

Nomor telepon **tidak di-hardcode di source code**. Tiga alasan:

1. **Ganti nomor = ganti satu baris SQL**, bukan rebuild + deploy ulang APK dan
   web. Nomor HP bisa berubah; kode yang sudah ter-obfuscate di APK pelanggan
   tidak bisa ditarik kembali.
2. **Nomor pribadi tidak masuk git history.** Sekali ter-commit, ia permanen di
   repo — dan repo ini punya CI publik.
3. Perbandingan nomor rawan salah format (`08…` vs `628…` vs spasi/strip).
   Perbandingan `boolean` tidak.

Hasil akhirnya persis seperti yang diminta: hanya akun 087864504924 yang bisa
masuk. Yang berbeda hanya cara menyatakannya.

### Penegakan di backend — ini yang sesungguhnya mengamankan

Middleware **`requireFinanceAccess`** dipasang pada **seluruh** route
`/admin/finance/*` **dan** pada endpoint P&L. Menolak dengan **404**, bukan 403,
supaya keberadaan modul ini tidak bocor ke admin lain.

> **Menyembunyikan menu di Flutter tidak mengamankan apa pun.** Endpoint tetap
> bisa dipanggil langsung dengan token admin mana pun memakai `curl`. Gating
> frontend murni kosmetik; middleware backend adalah satu-satunya batas nyata.
> Karena itu urutan implementasinya: **middleware dulu, layar belakangan.**

### Cakupan yang ikut terkunci

Mudah terlewat, dan tiap satu di antaranya membocorkan angka yang sama:

- `GET /users/me` **tidak** mengembalikan `can_access_finance` kepada
  pengguna lain — hanya kepada dirinya sendiri.
- Kartu "Keuangan" di dashboard admin hanya dirender bila flag `true`.
- Rute go_router `/admin/finance/*` memakai `redirect` guard, sehingga
  deep-link langsung tetap tertolak.
- **Notifikasi & push** dari modul ini (usulan kalibrasi, alarm HPP, rem tarik
  pribadi) hanya dikirim ke pemilik — jangan lewat broadcast admin yang ada.
- **Struk & laporan cetak** dari printer thermal tidak boleh memuat angka pos
  atau laba bersih.

### Batasan yang jujur

Flag ini melindungi dari **admin lain**, bukan dari seseorang yang menguasai
akun pemilik atau service key Supabase. Service role key melewati semua
pemeriksaan ini — jadi kerahasiaan `.env` backend tetap syarat utama.

---

## 4. Model data — buku besar amplop (event-sourced)

Saldo pos **tidak disimpan** sebagai kolom angka; ia dijumlah dari buku besar.
Alasannya: auditable, tidak bisa melenceng diam-diam, dan bebas dari race
condition penulisan bersamaan.

**Migrasi `016_add_finance_module.sql`** — 4 tabel baru + 2 kolom
(`expenses.bucket`, `users.can_access_finance`).

### `finance_settings` (baris tunggal)

| Kolom | Tipe | Catatan |
|---|---|---|
| `id` | uuid PK | |
| `pct_restock` | numeric(5,2) | % omzet untuk Restock (mis. 42,00) |
| `operational_daily` | bigint | nominal harian pos Operasional (rupiah) |
| `ratio_personal` / `ratio_scaling` / `ratio_emergency` | numeric(4,2) ×3 | rasio pembagian sisa, bawaan 2 / 1 / 0,8 |
| `emergency_target` | bigint | target dana darurat |
| `started_on` | date | alokasi tidak berjalan mundur sebelum tanggal ini |
| `calibrated_at` | timestamptz | kapan parameter terakhir dikunci |
| `updated_at` | timestamptz | |

Tidak ada CHECK "berjumlah 100" — model waterfall tidak memakai lima persentase
paralel, jadi constraint itu tidak berlaku. Yang divalidasi: `pct_restock`
antara 0–100 dan `operational_daily` ≥ 0.

### `finance_calibration` (riwayat usulan kalibrasi)

| Kolom | Tipe | Catatan |
|---|---|---|
| `id` | uuid PK | |
| `observed_at` | date | tanggal observasi |
| `metric` | text | `hpp_pct` \| `operational_daily` \| `revenue_baseline` |
| `observed_value` | numeric | hasil observasi mentah |
| `smoothed_value` | numeric | setelah shrinkage (§5) |
| `sample_days` | int | n hari bersih yang dipakai |
| `status` | text | `observed` \| `proposed` \| `accepted` \| `dismissed` |
| `applied_at`, `created_at` | | |

Tabel ini yang membuat kalibrasi dapat diaudit: setiap perubahan parameter punya
jejak angka dan tanggalnya, bukan berubah diam-diam.

### `finance_ledger`

| Kolom | Tipe | Catatan |
|---|---|---|
| `id` | uuid PK | |
| `bucket` | text | `restock`\|`operational`\|`personal`\|`scaling`\|`emergency` |
| `direction` | text | `in`\|`out` |
| `amount` | bigint | selalu positif; arah ditentukan `direction` |
| `source` | text | `allocation`\|`withdrawal`\|`expense`\|`adjustment`\|`shortfall` |
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

## 5. Mesin auto-kalibrasi

Tujuannya: **semakin banyak data, semakin dapat dipercaya — tanpa menjadi
gelisah.** Dua sifat itu bertentangan kalau parameter langsung mengikuti data
terbaru, jadi modul memisahkan *observasi* dari *kebijakan*.

| | Diobservasi otomatis, harian | Dikunci sampai disetujui |
|---|---|---|
| Apa | HPP%, baseline omzet, biaya variabel | `pct_restock`, `operational_daily`, rasio sisa |
| Kenapa | murah, akurat, tak perlu keputusan | kalau berubah tiap hari, pemilik tak bisa merencanakan apa pun |

Biaya tetap **tidak pernah** diobservasi otomatis — ia tidak muncul di data
transaksi dan hanya bisa diinput manual.

### Bukti bahwa pemisahan ini perlu

Diuji pada data produksi Rehat (31 hari aktif):

| Data terkumpul | HPP% kumulatif | | HPP% per minggu |
|---|---|---|---|
| 7 hari | 20,70% | Minggu 1 | 20,70% ← soft launch, omzet Rp401rb |
| 14 hari | 40,02% | Minggu 2 | 41,59% |
| 21 hari | 41,22% | Minggu 3 | 41,99% |
| 28 hari | 41,39% | Minggu 4 | 41,65% |
| 31 hari | **41,40%** | Minggu 5 | 41,43% |

**HPP% konvergen cepat** — setelah minggu pertama bergerak hanya dalam rentang
0,56 poin persen. Aman diobservasi otomatis.

**Omzet harian sebaliknya liar:** CV **72,9%**, min Rp20.000, P25 Rp68.000,
median Rp1.018.000, max Rp1.988.000. Mean (Rp843.677) bahkan **di bawah** median
karena ditarik hari-hari soft-launch yang sudah tidak mewakili Rehat. Parameter
yang mengikuti angka ini mentah-mentah akan berayun tiap minggu.

### Penyaringan sampel

Sebelum dihitung, hari-hari berikut dibuang:

1. **Hari berjalan** (belum tutup kasir) — mis. 9 Agt yang baru Rp256.000.
2. **Hari tutup / tidak berjualan** — omzet < 20% median berjalan.
3. **Ekstrem** — trim 5% teratas dan terbawah (winsorize).
4. **Di luar jendela** — hanya **12 minggu bergulir** terakhir.

Minimum **21 hari bersih**; di bawah itu mesin tetap mengobservasi tapi tidak
pernah mengusulkan perubahan.

### Pembobotan kepercayaan (shrinkage)

Estimasi tidak menelan data baru mentah-mentah, melainkan dicampur dengan nilai
yang sedang terkunci:

```
estimasi = w × observasi + (1 − w) × nilai_terkunci
w = n / (n + 30)          n = jumlah hari bersih
```

| n (hari bersih) | Bobot observasi |
|---|---|
| 14 | 32% |
| 30 | 50% |
| 90 | 75% |
| 180 | 86% |

Awalnya modul skeptis terhadap data sendiri, lalu makin percaya seiring bukti
menumpuk — otomatis, tanpa pengaturan. Konstanta `k = 30` dipilih agar bobot
mencapai 50% tepat saat sampel setara satu bulan penuh.

### Kapan usulan muncul (deadband + histeresis)

Usulan rekalibrasi hanya diterbitkan bila **ketiganya** terpenuhi:

- selisih `|estimasi − nilai_terkunci|` ≥ **2 poin persen** (atau ≥ 5% untuk
  nilai nominal),
- selisih itu **bertahan ≥ 14 hari berturut-turut**,
- sampel bersih ≥ 21 hari.

Perubahan juga dibatasi **maksimal ±3 poin persen per pos per bulan**, sehingga
tidak ada lompatan mendadak sekalipun data berubah drastis.

### Persetujuan pemilik

Usulan tampil sebagai kartu di ringkasan keuangan, **selalu menyertakan
konsekuensi rupiahnya**:

> **HPP naik 41,4% → 44,1%** selama 3 minggu terakhir (n=63 hari).
> Sesuaikan Restock **42% → 45%**?
> Akibatnya bagian Pribadi turun **±Rp1.080.000/bulan**.
> [Sesuaikan] [Abaikan 30 hari]

Parameter **tidak pernah berubah tanpa tap ini**. Menolak usulan tidak
menghapusnya dari `finance_calibration` — observasinya tetap tercatat sebagai
`dismissed`, sehingga tren tetap bisa ditinjau belakangan.

### Baseline omzet: konservatif, bukan rata-rata

Baseline dipakai untuk rambu (break-even, runway, proyeksi), **bukan** untuk
alokasi harian — alokasi selalu memakai omzet aktual hari itu.

Estimatornya **persentil 40 dari sampel bersih**, bukan mean. Alasannya asimetris:
alokasi yang meleset ke bawah hanya menyisakan uang menganggur, sedangkan yang
meleset ke atas membuat pos defisit dan sewa tak terbayar. Median dan mean
memberi peluang ±50% meleset ke atas; P40 menggeser risiko itu ke sisi yang aman.

---

## 6. Mesin alokasi

Dipicu saat tutup kasir (`GET /admin/reports/closing` sudah ada) dan juga bisa
dipanggil manual.

1. Ambil omzet hari itu memakai helper WIB terpusat `wibDayRange` di
   `orderService.js` — **jangan** memakai batas hari UTC.
2. **Waterfall**, berurutan:
   ```
   restock     = floor(omzet × pct_restock / 100)
   operational = min(operational_daily, omzet − restock)
   sisa        = omzet − restock − operational
   pribadi/scaling/darurat = bagi sisa menurut rasio 2 : 1 : 0,8
   ```
3. **Hari kurus.** Bila `omzet − restock < operational_daily`, pos Operasional
   menerima apa yang ada, tiga pos terakhir dapat **Rp0** (tidak pernah negatif),
   dan kekurangannya ditulis satu baris `source='shortfall'`, `direction='out'`,
   `amount = operational_daily − operational` sebagai penanda utang internal.
   Ringkasan menampilkannya merah.
4. **Pembulatan:** tiap pos dibulatkan ke bawah ke rupiah bulat; **selisih sisa
   dilempar seluruhnya ke pos Restock**, sehingga `Σ alokasi == omzet` persis.
5. Tulis baris `finance_ledger` dengan `source='allocation'`, `direction='in'`.
   Konflik pada unique index = hari itu sudah dialokasikan → operasi tidak
   melakukan apa-apa (idempoten), bukan error.
6. Alokasi tidak berjalan untuk tanggal sebelum `finance_settings.started_on`.

Catatan: `operational_daily` adalah nominal **per hari kalender**, bukan per hari
buka. Bila kedai tutup, hari itu tidak menghasilkan alokasi sama sekali —
sehingga pos Operasional secara alami akan tertinggal dari kebutuhan bulanannya.
Rambu runway di §8 yang menangkap kondisi ini.

**Pengurangan pos** terjadi saat:
- pengeluaran dicatat → `direction='out'` pada `expenses.bucket`
- penarikan pribadi/scaling/darurat → `source='withdrawal'`
- koreksi manual → `source='adjustment'`

Saldo pos boleh negatif (menandakan overspend) dan ditampilkan merah — modul
tidak memblokir pencatatan realitas.

---

## 7. Laporan Laba Rugi

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

Bandingkan dengan alokasi: Pribadi + Scaling + Darurat = Rp12.280.000, yaitu
**98,3% dari laba bersih riil**. Sisa Rp214.729 mengendap sebagai bantalan di pos
Restock. Angka alokasi tidak dikarang — ia memang menghabiskan laba yang
benar-benar ada, dan kecocokan ini adalah uji kewarasan model: kalau alokasi
jauh melampaui laba bersih, parameternya salah.

**Perubahan kritis:** pengeluaran dengan `bucket='restock'` **tidak dikurangkan
lagi** di sini — sudah terhitung di HPP. Hanya `expenses` dengan bucket selain
`restock` yang masuk sebagai biaya variabel. Inilah perbaikan double-counting-nya.

Kompatibilitas: `net_profit` lama tetap dikembalikan oleh `/admin/reports/sales`
agar dashboard yang ada tidak pecah, tetapi layar Laba Rugi memakai perhitungan
baru dan menjadi sumber kebenaran.

---

## 8. Rambu keputusan

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

## 9. Endpoint backend

Semua di bawah middleware **`requireFinanceAccess`** (§3) — bukan sekadar guard
admin. Akses tanpa flag dijawab **404**, bukan 403.

| Method | Path | Fungsi |
|---|---|---|
| GET | `/admin/finance/overview` | saldo 5 pos, alokasi bulan berjalan, rambu |
| GET/PUT | `/admin/finance/settings` | baca/simpan parameter (validasi `pct_restock` 0–100, `operational_daily` ≥ 0, rasio > 0) |
| POST | `/admin/finance/allocate` | jalankan alokasi untuk `date` (idempoten) |
| POST | `/admin/finance/withdraw` | tarik dari pos; body `{bucket, amount, note}` |
| GET | `/admin/finance/ledger` | riwayat mutasi, filter pos & rentang |
| GET/POST/DELETE | `/admin/finance/fixed-costs` | CRUD biaya tetap |
| GET | `/admin/finance/pnl?month=YYYY-MM` | laba rugi bulanan |
| GET | `/admin/finance/calibration` | observasi terkini + usulan aktif (bila ada) |
| POST | `/admin/finance/calibration/accept` | terapkan usulan → tulis parameter baru + `calibrated_at` |
| POST | `/admin/finance/calibration/dismiss` | tandai `dismissed`, tunda 30 hari |

Mengikuti envelope proyek: `{ success, data, message }`.

---

## 10. Frontend

Fitur baru `lib/features/finance/` mengikuti pola feature-first proyek
(`data` / `application` / `presentation`).

```
lib/features/finance/
  data/finance_repository.dart          model + repository + provider Riverpod
  application/allocation_calculator.dart  waterfall + pembulatan, murni & teruji
  application/calibration_engine.dart     penyaringan sampel, shrinkage, deadband
  presentation/finance_overview_screen.dart
  presentation/finance_setup_screen.dart    wizard kalibrasi
  presentation/profit_loss_screen.dart
  presentation/fixed_costs_screen.dart
  presentation/finance_ledger_screen.dart
  presentation/widgets/bucket_card.dart
  presentation/widgets/calibration_card.dart     usulan + konsekuensi rupiah
```

- Rute baru di `core/router/route_names.dart` + `app_router.dart`.
- Pintu masuk: kartu "Keuangan" di dashboard admin.
- Gating: hanya `UserModel.isAdmin`.
- **Wajib** pakai `Formatters.toWib` untuk semua tanggal — jangan `DateFormat` langsung.
- **Wajib** ingat `AppColors` adalah getter runtime, bukan const.
- Pakai widget `Neu*` yang ada agar konsisten.
- Pola *keep-previous-data*: spinner hanya saat `valueOrNull == null`.

---

## 11. Prasyarat data

Dikerjakan sebagai bagian implementasi, bukan diserahkan ke pemilik:

1. ~~Isi `cost_price` untuk menu yang kosong.~~ **Selesai 9 Agt 2026** — seluruh
   menu aktif sudah ber-HPP; sisanya menu nonaktif. Tidak ada pekerjaan tersisa.
   Yang tetap perlu: **seed `fixed_costs` dengan biaya tetap Rp8.000.000** yang
   sudah ditetapkan pemilik. Rinciannya (sewa / gaji / listrik / wifi) belum
   dipecah — implementasi boleh memasukkannya sebagai satu baris
   "Biaya tetap bulanan" Rp8jt, dan pemilik memecahnya sendiri belakangan lewat
   layar Biaya Tetap. Memecah tanpa data = mengarang.
1b. **Seed `can_access_finance = true`** hanya untuk
   `649a989c-e9c2-45d4-815d-f95b7df158bc` (087864504924, `irurr`). Verifikasi
   bahwa `irur` tetap `false`.
2. Backfill `expenses.bucket = 'restock'` untuk 124 catatan lama — sesuai isi
   catatannya yang memang semuanya bahan. Dapat dikoreksi manual setelahnya.
3. Migrasi `016` dijalankan **manual di Supabase SQL Editor** (`DATABASE_URL`
   adalah placeholder — `pg`/psql tidak jalan), lalu diverifikasi dengan skrip
   `src/db/verify-016.js` bergaya skrip verify yang sudah ada.
4. Perbarui tabel status migrasi di `CLAUDE.md` §3 pada commit yang sama.

---

## 12. Pengujian

| Unit | Yang diuji |
|---|---|
| `allocation_calculator` | Σ alokasi == omzet persis di banyak nominal acak; sisa rupiah selalu ke Restock; Operasional tak pernah melebihi `operational_daily` |
| Waterfall hari kurus | omzet Rp300rb → Pribadi/Scaling/Darurat = Rp0, tidak negatif, dan baris `shortfall` tertulis dgn nominal benar |
| Waterfall @Rp36jt | menghasilkan Restock Rp15,12jt / Operasional Rp8,6jt / Pribadi Rp6,463jt / Scaling Rp3,232jt / Darurat Rp2,585jt |
| Penyaringan sampel | hari berjalan, hari tutup (<20% median), dan 5% ekstrem terbuang; < 21 hari bersih → tidak pernah mengusulkan |
| Shrinkage | w = n/(n+30): n=14→32%, n=30→50%, n=90→75%; estimasi selalu di antara observasi dan nilai terkunci |
| Deadband | selisih 1,5 poin persen → tidak ada usulan; 2,5 poin selama 10 hari → belum; 14 hari → baru muncul |
| Batas gerak | usulan tidak pernah menggeser parameter > 3 poin persen dalam sebulan |
| Baseline omzet | P40 dari sampel bersih; data Rehat tidak menghasilkan baseline > median |
| **Kontrol akses** | tiap route `/admin/finance/*` + P&L membalas **404** untuk token admin `irur`; **200** untuk `irurr`; 401 tanpa token. Tes ini wajib menutup **semua** route, bukan sampel |
| Kebocoran akses | `GET /users/me` admin lain tidak memuat `can_access_finance`; guard go_router menolak deep-link |
| Mesin alokasi (backend) | idempotensi (panggil 2×, ledger tetap 5 baris); hormati `started_on`; batas hari WIB benar |
| Kalkulator P&L | restock tidak dipotong dua kali; biaya tetap masuk; QRIS fee benar |
| Rambu | break-even, runway, ambang rem tarik pribadi |

Gate CI yang berlaku: `flutter analyze --fatal-infos` + `flutter test`.

---

## 13. Batasan yang dinyatakan terbuka

- **Saldo pos adalah saldo buku, bukan saldo bank.** QRIS (40% omzet) baru cair
  setelah DOKU settle, jadi pos bisa menunjukkan uang yang belum sepenuhnya ada
  di tangan. Rekonsiliasi ke kas fisik sengaja di luar scope.
- **Alokasi berbasis omzet, bukan kas diterima.** Pesanan yang di-refund setelah
  dialokasikan tidak otomatis membalik ledger; koreksi dilakukan lewat
  `source='adjustment'`. Volume refund saat ini nihil sehingga risikonya kecil.
- **Satu outlet.** Skema tidak menyediakan dimensi outlet.
- **Biaya tetap dianggap rata per hari** (÷30) untuk runway dan break-even,
  walaupun pembayaran riilnya menumpuk di tanggal tertentu.
- **Auto-kalibrasi hanya menyesuaikan diri dengan masa lalu.** Ia tidak
  mengantisipasi perubahan yang belum terjadi — kenaikan sewa bulan depan,
  harga bahan yang baru naik minggu ini, atau musim ramai. Deadband 14 hari
  berarti perubahan nyata pun baru tertangkap setelah dua minggu. Untuk kejadian
  yang sudah diketahui pemilik, jalur yang benar adalah menyunting parameter
  manual, bukan menunggu mesin.
- **Baseline P40 sengaja pesimistis.** Saat usaha sedang tumbuh cepat — seperti
  Rehat sekarang (Juli Rp717rb/hari → Agustus Rp1.279rb/hari) — baseline akan
  konsisten tertinggal di belakang kenyataan. Itu pilihan sadar: risiko
  meleset ke bawah (uang menganggur) jauh lebih murah daripada meleset ke atas
  (sewa tak terbayar).
- **Semua parameter dan rambu berasumsi satu pemilik tunggal.** Tidak ada
  pembagian laba antar-partner.
