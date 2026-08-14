# Rehat Coffeehouse — Panduan Proyek (CLAUDE.md)

> Dokumentasi ringkas & mandiri untuk melanjutkan pekerjaan lintas sesi / lintas PC.
> Aplikasi mobile ordering untuk kedai kopi **Rehat Coffeehouse** (pelanggan + kasir/admin).

---

## 1. Gambaran & Arsitektur

| Lapisan | Teknologi | Lokasi |
|---|---|---|
| **Frontend** | Flutter (Dart, ~114 file, Riverpod + go_router) | repo ini (`lib/`) |
| **Backend** | Node.js + Express + Supabase (Postgres) | repo terpisah: `D:\REHAT\rehat-backend\rehat-backend` |
| **Pembayaran** | DOKU (QRIS/SNAP + Checkout) — **PRODUKSI (uang nyata)** | `src/services/dokuService.js`, `dokuSnapService.js` |
| **Notifikasi** | Firebase Cloud Messaging (push) + in-app polling | `firebase_messaging`, `notificationService.js` |
| **Crash** | Firebase Crashlytics (mobile) | `main.dart` |
| **OTP** | WhatsApp via Fonnte (device `087777601617`) | `authService.js`, `config/whatsapp.js` |

- **Web live:** https://rehatflutter.vercel.app (Vercel, project `rehatflutter`)
- **Backend live:** https://rehat-backend-production.up.railway.app/v1 (Railway, service `rehat-backend`)
- **Envelope respons:** `{ success, data, message }`; error `{ success:false, error:{ code, message } }`. Klien meng-unwrap `data`.

### Arsitektur frontend (feature-first)
`lib/features/<fitur>/{data,application,presentation}` + `lib/core/` (router, constants, network, utils) + `lib/shared/` (models, widgets).

---

## 2. Lingkungan Dev (SESUAIKAN di PC lain)

Path berikut spesifik mesin dev saat ini — ganti sesuai PC-mu:

| Alat | Path (mesin saat ini) |
|---|---|
| Flutter SDK | `C:\Users\thezu\flutter\bin\flutter.bat` (Flutter 3.44.4 stable) — **tidak di PATH**, panggil path penuh |
| Android SDK / adb | `D:\Sdk\platform-tools\adb.exe` |
| Emulator | `D:\Sdk\emulator\emulator.exe -avd Pixel_8_Pro` |
| Backend repo | `D:\REHAT\rehat-backend\rehat-backend` |

> Di PC lain: install Flutter 3.44.x, set `flutter.sdk` di `android/local.properties`, `flutter pub get`.

---

## 3. Build & Deploy (PENTING — baca sebelum build)

### ⚠️ Aturan wajib
- **CI GitHub Actions AKTIF & bisa tabrakan dgn deploy manual.** `.github/workflows/deploy-web.yml` **auto-deploy web ke Vercel setiap push ke `main`** yang menyentuh `lib/**`/`web/**`/`pubspec.yaml`. `build-apk.yml` (dispatch/tag `v*`) build APK **tanpa** `--obfuscate` → jangan dipakai rilis (crash tak bisa di-decode). `test.yml` = gate `analyze --fatal-infos` + `test`.
  - **Aturan:** sebelum `bash scripts/deploy_web.sh` manual, **cek tab Actions** — kalau run CI sedang jalan, tunggu; jangan deploy dua jalur bersamaan. Untuk rilis APK, **selalu pakai script lokal** (`scripts/build_*_apk.sh`), bukan CI.
- **Ada Android product flavors `customer` & `admin`** → `flutter build apk` polos **GAGAL**. Selalu `--flavor`.
- **Selalu sertakan** `--dart-define=API_BASE_URL=https://rehat-backend-production.up.railway.app/v1`, kalau tidak app menunjuk `localhost` (default `api_constants.dart`) & tak bisa konek.
- `--dart-define=ADMIN_BUILD=true|false` harus cocok dgn flavor (gating `UserModel.isAdmin`).
- Web build **wajib** `--pwa-strategy=none` (service worker cache bikin stuck-loading saat redeploy).

### 🔴 URUTAN DEPLOY (jebakan yang pernah menggigit)
`scripts/deploy_web.sh` menjalankan **`flutter clean`** → menghapus SELURUH `build/`, **termasuk APK yang sudah jadi**, tanpa peringatan.

> **Urutan benar: DEPLOY WEB DULU → baru BUILD APK.**
> Kalau terbalik, APK yang baru dibuat lenyap dan kamu mengira masih ada (pernah terjadi: APK admin hilang, dikira tak perlu rebuild).
> Selalu verifikasi hasil akhir: `ls -lh build/app/outputs/flutter-apk/*.apk` (cek timestamp).

### APK (pakai script)
```bash
bash scripts/build_customer_apk.sh   # pelanggan: no izin Bluetooth, no UI admin
bash scripts/build_admin_apk.sh      # kasir: printer Bluetooth + UI admin
```
Keduanya: `--flavor <x> --split-per-abi --obfuscate --split-debug-info=build/symbols/<x>`.
Output: `build/app/outputs/flutter-apk/app-<abi>-<flavor>-release.apk` (pakai **arm64-v8a** untuk HP modern).
> Signing masih **debug key** (belum Play-Store ready). Simbol → `build/symbols/` (untuk decode crash Crashlytics).

### Web (Vercel)
```bash
bash scripts/deploy_web.sh   # clean → build web --pwa-strategy=none → deploy prod
```

**Cache browser — jangan sampai deploy "tak kelihatan".**
Flutter web menghasilkan **`main.dart.js` TANPA hash di nama file** (namanya selalu sama tiap build), sehingga browser menyajikan versi lama dan perubahan tak muncul sampai hard-refresh. Ini pernah bikin bingung: perbaikan jam WIB dikira gagal padahal build sudah benar — **dan pelanggan pun bisa tertahan di versi lama tanpa sadar.**

Sudah diatasi permanen lewat header di [`web/vercel.json`](web/vercel.json):
- `index.html`, `main.dart.js`, `flutter_bootstrap.js`, `version.json`, `manifest.json`, dan `/assets/*` → `Cache-Control: no-cache, must-revalidate` (wajib revalidasi; kalau tak berubah server balas **304**, tetap ringan)
- `/canvaskit/*` → cache 1 tahun `immutable` (sudah ber-versi di path, aman)

`deploy_web.sh` menyalin `web/vercel.json` ke `build/web/` — jadi jangan hapus file itu.
Verifikasi setelah deploy: `curl -sI https://rehatflutter.vercel.app/main.dart.js | grep -i cache-control`

### Backend (Railway)
```bash
cd D:\REHAT\rehat-backend\rehat-backend
railway up --service rehat-backend --detach
```
Deteksi deploy baru live: endpoint baru balas **401** (route ada) vs **404** (belum).

### Migrasi DB (MANUAL)
`DATABASE_URL` di `.env` adalah **placeholder** → runner `pg`/psql **tidak jalan**. SQL di `src/db/migrations/*.sql` **dijalankan manual di Supabase Dashboard → SQL Editor**. Verifikasi via `supabaseAdmin.from(x).select().limit(1)`.
**Tabel status migrasi** (perbarui baris ini di commit yang sama saat menambah `.sql` baru):

| # | Isi | Status |
|---|---|---|
| 001–007 | skema awal (users, menu, orders, dll.) | ✅ terpasang |
| 008 | `cost_price` (HPP) | ✅ terpasang |
| 009 | referral + wallet | ✅ terpasang |
| 010 | RPC `increment_balance` (saldo atomik) | ✅ terpasang |
| 011 | `orders.source` | ✅ terpasang |
| 012 | refund tunai (`refunded_at/by/reason` + enum `'refunded'`) | ✅ terpasang (`node src/db/verify-012.js`) |
| 013 | voucher stamp (`voucher_source+='stamp'` + `vouchers.reward_type`) | ✅ terpasang (`node src/db/verify-013.js`) — penukaran stamp digital |
| 014 | belanja poin (`users.lifetime_points` + `voucher_source+='points'`) | ✅ terpasang (`node src/db/verify-014.js`) — belanja poin |
| 015 | QR meja (`orders.table_number`) | ✅ terpasang (`node src/db/verify-015.js`) |
| 016 | modul keuangan (`finance_settings`, `fixed_costs`, `finance_ledger`, `finance_calibration`, `expenses.bucket`, `users.can_access_finance`; backfill `expenses.bucket='restock'`) | ✅ terpasang (`node src/db/verify-016.js`) |
| 017 | `finance_ledger_expense_ref_unique` (unique index parsial `(ref_id) WHERE source='expense'`) — idempotensi pencatatan pengeluaran memotong amplop | ✅ terpasang (`src/db/verify-017.js` sudah **dihapus** — menulis probe langsung ke `finance_ledger` produksi, lihat 018) |
| 018 | `finance_ledger_adjustment_ref_unique` (unique index parsial `(ref_id) WHERE source='adjustment'`) — idempotensi PEMBALIKAN saat pengeluaran dihapus (mencegah amplop dikredit ganda oleh hapus-dua-kali) | ✅ terpasang (terverifikasi: duplikat `adjustment` ditolak). SQL: (`src/db/migrations/018_adjustment_ref_unique.sql`). Verifikasi juga manual (`src/db/verify-018.js` HANYA mencetak query SQL, tidak menulis ke produksi — lihat komentar di berkas itu untuk alasannya) |
| 019 | Master bahan & resep (`ingredients`, `recipes`) — Manajemen Stok Fase A, dasar penghitungan HPP menu dari resep × harga bahan (menggantikan `menu_items.cost_price` yang diisi tangan). Task 1: hanya membuat tabel, belum ada perilaku yang berubah. SQL: `src/db/migrations/019_stock_master.sql` (repo backend) | ✅ terpasang (`node src/db/verify-019.js` — non-destruktif, hanya membaca). Penjaga terverifikasi lewat probe yang membersihkan dirinya: CHECK `base_unit`, CHECK `units_per_purchase > 0`, dan unique `lower(name)` semuanya menolak. **`cost_per_base` terbukti menyimpan pecahan utuh** — 3,5 tetap 3,5, tidak dibulatkan |
| 020 | `ingredients.purchase_price` (numeric(14,4), `CHECK >= 0`, default 0) — simpan harga beli TERAKHIR sebagai kolom (disepakati saat review Task 3/CRUD bahan), supaya PATCH harga-saja atau isi-saja bisa memakai pasangan lama+baru tanpa `INCOMPLETE_COST_UPDATE` (kode itu dihapus). `cost_per_base` tetap turunan yang dihitung SERVER. SQL: `src/db/migrations/020_ingredient_purchase_price.sql` (repo backend) | ⏳ belum dipasang (jalankan manual di Supabase SQL Editor sebelum ~100 bahan didata, lalu `node src/db/verify-020.js` — non-destruktif, hanya membaca) |

**Modul Keuangan Tahap 2 (amplop alokasi, lihat §5g) TIDAK menambah migrasi** — semua tabel (`finance_settings`, `finance_ledger`, dll.) sudah ada dari migrasi 016; Tahap 2 murni logika baru di atasnya.

Pola verifikasi umum: skrip sekali-pakai di folder backend pakai `supabaseAdmin` (contoh §8). `DATABASE_URL` placeholder → `pg`/psql tak jalan.

**Pola WAJIB saat menambah kolom:** buat query-nya **defensif** (coba dengan kolom baru → ulangi tanpa kolom itu bila error menyebut kolom tsb). Tanpa ini, migrasi yang tertinggal bisa **merusak alur pembayaran**. Contoh ada di `getSalesReport` (cost_price), `updateOrderStatus` (source), dan `createGuestOrder` (`optionalCols`).

---

## 4. Konvensi & Jebakan (Gotchas)

- **AppColors**: token tema (espresso, crema, textPrimary…) adalah **getter runtime**, BUKAN const → jangan pakai `const` dgn itu (build rusak). Token semantik (`success`, `error`, `warning`, `amber`) memang `const`.
- **Widget Neu** (`shared/widgets/neu.dart`): sudah **flat** (border tipis), dependency `flutter_neumorphic_plus` **dihapus**. API dipertahankan (`NeuCard/NeuButton/NeuInset/NeuCircleButton/NeuBottomBar/NeuThemeScope`).
- **`NeuButton` dulu mengoper `borderRadius` DAN `shape` ke `Material`** — `Material` memprioritaskan `borderRadius`, jadi `BorderSide` pada varian non-accent **tak pernah tampil di rilis**, dan di build debug ia meledak di assert (memblokir semua widget test). Diperbaiki (Tahap 2 keuangan, task buku besar): `borderRadius` dibuang, `shape` dipertahankan → ~24 tombol non-accent di 27 berkas kini menampilkan border tipis sesuai desain yang memang dimaksud. Varian accent tidak berubah tampilannya.
- **Navbar** (`main_shell.dart`): floating pill + micro-interactions (press-scale, haptic, ikon scale+fade).
- **NeuButton** membungkus child dengan `Align(heightFactor:1)` — penting agar tak memuai di `bottomNavigationBar`.
- **Font**: di-bundle lokal (`assets/fonts/`, Inter+Cormorant+Archivo+Anton), `google_fonts` **dihapus**.
- **Cache build basi**: perubahan Dart kadang TIDAK ikut terkompilasi di build inkremental (pernah terjadi pada `cashier_actions.dart`). Gejalanya: fitur baru tak muncul di APK padahal kode benar & analyze bersih.
  - **Cara cek pasti**: grep string baru di dalam APK →
    `unzip -p build/app/outputs/flutter-apk/<apk> lib/x86_64/libapp.so | grep -a -c "Teks Baru"`
  - **Obatnya**: `flutter clean` lalu rebuild.
- **Disk**: build rilis butuh ruang. Kalau `No space left on device` → hapus `~/.gradle/caches` (regenerable; pernah membebaskan **11 GB**). Build berikutnya lebih lama karena unduh ulang dependency (± 850 dtk) — itu normal.
- **Emulator**: `adb install -r` pada app yang SEDANG berjalan tidak memuat kode baru. Selalu `adb shell am force-stop com.rehat.rehat_app` lalu luncurkan ulang.
- **Restart proses menghapus isi keranjang** (cart disimpan di memori, bukan persisten).
- **`GET /orders` HANYA mengembalikan pesanan milik akun yang login** (`.eq('user_id', userId)`). Pesanan kasir adalah pesanan tamu (`user_id = null`) → **tak muncul di sana**. Untuk tampilan admin gunakan `/admin/orders` (`fetchAllOrders`). Ini pernah bikin kartu lacak kosong padahal Pesanan Masuk penuh.
- **Kolom hasil migrasi baru wajib diambil secara defensif.** Pola di `updateOrderStatus`: coba `select` dengan kolom opsional (`source`, `order_type`) → bila error menyebut kolom itu, ulangi tanpa kolom opsional. Tanpa ini, migrasi yang tertinggal bisa **merusak seluruh alur pembayaran**.
- **Auth OTP**: register OTP-gated (akun baru ada setelah verify). DEV OTP **tidak** diprint di Railway (produksi) → OTP hanya via WhatsApp.
- **Modul keuangan hanya untuk pemilik.** Gate-nya kolom `users.can_access_finance` (migrasi 016), BUKAN `role='admin'` — ada dua akun admin dan hanya `irurr` (087864504924) yang boleh; `irur` (087777601617) tidak. Penegakannya di middleware `requireFinanceAccess` (`src/middleware/auth.js`), membalas **404** (bukan 403) supaya keberadaan modul tidak bocor lewat status code. **Jangan pakai `adminAccess` untuk route keuangan** — jalur `x-admin-key`-nya melewati `authenticate`, sehingga `req.user` kosong dan flag `can_access_finance` tak pernah terperiksa. Gating di Flutter (`financeAccessProvider`, kartu di dashboard admin) murni kosmetik; batas nyata satu-satunya adalah middleware backend.
- **Backend kini punya test** (sebelumnya tidak ada sama sekali). Jest + Supertest: `cd D:\REHAT\rehat-backend\rehat-backend && npx jest` → 23 test lulus, sengaja lulus **tanpa `.env`** (test file `jest.mock` `config/supabase`). Logika keuangan murni ada di `financeCalc.js` (`computePnl`) & `expenseService.js`/`financeService.js` (`splitByBucket`, `sumFixedCosts`) — semua tanpa DB supaya bisa diuji.
- **`net_profit` di `/admin/reports/sales` masih memotong restock dua kali** (restock sudah masuk HPP). Angka yang benar ada di `/admin/finance/pnl` (`getMonthlyPnl`). Endpoint lama sengaja dibiarkan apa adanya agar dashboard existing tidak pecah — jangan jadikan `net_profit` lama sebagai sumber kebenaran laba.
  **JANGAN mencatat belanja bahan (restock) sebagai baris `expenses` demi "supaya masuk laba rugi"** — itu justru membuat dashboard memotongnya dua kali, dan sangat kelihatan di hari berjalan. Pernah terjadi (12 Agt 2026): 3 penarikan restock Rp703.000 diubah jadi pengeluaran, laba 11 Agt langsung tertekan Rp400.000 palsu. Sudah dikembalikan. `cash_in_drawer = omzet − qris − pengeluaran` memang BENAR memotong restock (uangnya sungguh keluar laci); yang salah hanya `net_profit`. Kalau suatu saat diperbaiki: kecualikan restock dari `net_profit` saja, JANGAN dari `cash_in_drawer`.
- **Menghapus pengeluaran mengembalikan uangnya ke amplop** (baris pembalik `adjustment`). Jadi jangan menggabungkan penarikan manual dengan pengeluaran: begitu digabung, menghapus sisi pengeluarannya ikut membatalkan penarikannya, dan uang yang sungguh keluar tampak kembali ke amplop. Penarikan (`source='withdrawal'`) dan pengeluaran (`source='expense'`) sengaja tetap dua jalur terpisah.
- **Biaya tetap tidak punya tanggal berlaku** — `getMonthlyPnl` menjumlah baris `fixed_costs` yang ada **saat ini** untuk **semua** bulan yang diminta. Tambah biaya sewa bulan September → laba rugi Juli yang sudah dilaporkan ikut turun retroaktif; hapus satu baris (`deleteFixedCost` hard delete) → laba naik. Artinya **P&L historis tidak reproducible**: dicetak hari ini vs bulan depan bisa beda angka untuk bulan yang sama. Dapat diterima untuk Tahap 1; Tahap 2 perlu kolom `effective_from`/`effective_to` di `fixed_costs` agar tiap bulan memakai biaya tetap yang berlaku saat itu.
- **Alokasi amplop otomatis HANYA untuk hari WIB KEMARIN** (`financeService.yesterdayWibKey()`), dipicu dari `GET /admin/reports/closing`. Alasannya: endpoint itu **bukan** aksi "tutup kasir", melainkan tembakan otomatis tiap kali layar Tutup Kasir dibuka (watch di `build()`, pull-to-refresh, ganti tanggal). Memicu untuk **hari berjalan** mengunci alokasi pada omzet **PARSIAL** — dan **tak ada endpoint koreksi mana pun** (`allocateForDate` hubung-singkat begitu sudah ada baris untuk tanggal itu; satu-satunya jalan perbaikan adalah SQL manual di Supabase). Ini regresi nyata yang sempat lolos & ditutup di Task 5 (Tahap 2) — **jangan "disederhanakan" jadi hari ini**.
- **`POST /admin/finance/allocate` default-nya HARI INI** (`wibDateKey(new Date())` bila `date` tak dikirim) — default itu **berbahaya** persis karena alasan di atas. `FinanceRepository.allocate()` di Flutter **mewajibkan tanggal eksplisit** (parameter wajib, tak ada default) — jangan tambahkan overload tanpa tanggal.
- **Paginasi buku besar (`GET /admin/finance/ledger`) wajib keyset komposit** `before` (created_at ISO) + `before_id` (uuid), **berpasangan**. Sebabnya konkret: `allocateForDate` menulis 5–6 baris dalam **satu insert**, jadi `created_at`-nya identik untuk semua baris hari itu (terbukti di data produksi 9 Agt 2026). Cursor `.lt(created_at)` biasa akan membuang seluruh baris ber-timestamp sama → **baris alokasi hilang permanen** dari buku besar. Klien harus meneruskan `next_before`/`next_before_id` dari respons apa adanya, jangan menyusun cursor sendiri dari item terakhir.
- **`breakEvenDaily == 0` TIDAK berarti aman.** `GET /admin/finance/overview` membedakan penyebabnya lewat flag: `insufficient_data` (belum ada omzet bulan dasar), `margin_non_positive` (jual rugi, atau margin <0,5% dibulatkan jadi 0), dan biaya bulanan kosong (`fixed_costs` belum diisi → `monthlyCost` 0). UI (`BreakEvenStatus` di `finance_overview_view.dart`) wajib membedakan ketiganya — menampilkan "Rp0" polos sebagai kabar baik adalah cacat rambu uang (pernah divonis CRITICAL saat review Task 7).
- **Dasar rambu break-even/runway = bulan LENGKAP terakhir** (`basis: 'previous'`), fallback ke bulan berjalan yang di-run-rate (`basis: 'current_partial'`) bila bulan lalu kosong. Ini **sengaja menyimpang** dari rencana awal yang memakai bulan berjalan mentah — rencana itu cacat: tiap tanggal 1, omzet MTD = 0 → margin 0 → `breakEvenDaily` dilaporkan Rp0 alias "aman" justru saat belum ada dasar apa pun.
- **`variable_expenses_unavailable`**: bila query pengeluaran non-restock gagal, biaya kena remehkan → runway dilaporkan lebih panjang dari nyatanya & rem tarik-pribadi (`personalWithdrawBlocked`) bisa `false` padahal seharusnya `true`. Flag ini **harus** diteruskan sampai ke UI, jangan dibuang di lapisan mana pun.
- **Idempotensi penarikan (`POST /admin/finance/withdraw`) hanya lapis aplikasi** — menolak penarikan identik (bucket+amount+note+created_by) dalam jendela 60 detik → 409 `DUPLICATE_WITHDRAWAL`. **Bukan** unique index seperti alokasi; masih ada race dua request bersamaan (diakui di komentar kode `financeService.js`).
- **Saldo pos amplop BOLEH NEGATIF** — baris shortfall alokasi & penarikan yang melebihi saldo memang diizinkan tanpa clamp (rambunya ada di UI, bukan di data). Jangan `clamp(0, ...)` saldo pos di widget mana pun.
- **`finance_settings.pct_restock` adalah PERSEN (mis. 42), bukan pecahan** — jangan dikalikan/dibagi 100 lagi saat ditampilkan.
- **`missing_allocation_dates` / `missing_allocation_count`** di `GET /admin/finance/overview`: daftar tanggal WIB dari `started_on` s/d **kemarin** yang belum punya baris alokasi (array dipotong 60 tanggal terbaru, `count` tetap jumlah sebenarnya). Ini satu-satunya cara pemilik tahu pembukuannya bolong — kegagalan alokasi otomatis saat tutup kasir hanya dicatat via `console.error` (tak pernah sampai ke pemilik, karena yang membuka layar Tutup Kasir adalah kasir, bukan pemilik). Layar Ringkasan Keuangan (§5g) **wajib** menampilkan ini dengan aksi "Alokasikan tanggal bolong" yang memanggil `allocate()` per tanggal — jangan pakai default endpoint (= hari ini).
- **Pengeluaran (`POST/DELETE /admin/expenses`) memotong/mengembalikan amplop otomatis** (`expenseService.js`, ledger `source:'expense'` saat catat, `source:'adjustment'` saat hapus) — **kedua arah dilindungi unique index parsial** (017 untuk `source='expense'`, **018** untuk `source='adjustment'`); tanpa 018, menghapus pengeluaran yang sama dua kali (double-tap, retry jaringan) mengkredit amplop dua kali dari udara. `deleteExpense` mengecek dulu baris `expenses` masih ada (404 `EXPENSE_NOT_FOUND` bila tidak) — mencegah menulis pembalik untuk pengeluaran yang sudah tiada. Baris pembalik memakai `ref_date` dari `spent_at` **ASLI** pengeluaran (bukan hari hapus), supaya mutasi masuk/keluar tetap satu periode buku besar. Kegagalan rollback saat MENCATAT (bukan menghapus) punya dua kode error berbeda: `EXPENSE_LEDGER_FAILED` (rollback sukses, aman dicoba lagi) vs `EXPENSE_LEDGER_ORPHANED` (rollback JUGA gagal — baris `expenses` tersisa tanpa amplop terpotong, butuh perbaikan manual). `GET /admin/finance/overview` menyurfacekan baris yatim ini via `expense_ledger_orphans`/`expense_ledger_orphan_count`/`expense_ledger_orphans_unavailable`, ditampilkan di layar Ringkasan Keuangan (`_OrphanedExpensesCard`) — tanpa tombol perbaikan otomatis (tak ada endpoint koreksi ledger).
  **Deteksi yatim DIBATASI ke pengeluaran sejak `finance_settings.started_on`** (`listExpenseIds(sinceIso)`, batas dari `wibDayBounds(started_on)[0]`). Tanpa batas itu seluruh isi tabel `expenses` dilaporkan yatim — pernah terjadi: 142 baris dilaporkan, 124 di antaranya dari sebelum sistem amplop ada dan memang wajar tak punya baris ledger. Alarm palsu bervolume penuh di layar yang seluruh gunanya adalah sinyal uang yang bisa dipercaya.
- **Pos pengeluaran menentukan amplop mana yang dipotong**, jadi salah pos = salah amplop, dan tak ada endpoint koreksi. Dialog "Catat Pengeluaran" punya pemilih pos (default **Restock**). Aturan yang dipakai saat backfill data lama (12 Agt 2026): "uang makan" → **Operasional** (tunjangan makan karyawan = biaya usaha), sapaan nama orang (`mas`/`mbak`/`bu`/`pak`) → **Pribadi** (prive pemilik), sisanya (cleo, yakult, skm, soda, cup, es batu) → **Restock**.
- **Pos `personal` DIKECUALIKAN dari biaya di Laba Rugi** (`splitByBucket`/`sumNonRestockBetween`) — itu prive pemilik, bukan biaya usaha; memasukkannya membuat laba bersih terlihat lebih kecil dari kenyataan dan `breakEvenDaily` naik palsu. Tapi ia **tetap memotong amplop pribadi**. Akibatnya ada DUA jalur untuk uang pribadi (`POST /admin/finance/withdraw` bucket personal, dan mencatat pengeluaran bucket personal) — keduanya memotong amplop yang sama dan keduanya di luar P&L.
- **Fallback yang menjatuhkan kolom `bucket` di `createExpense` SUDAH DIBUANG.** Dulu bila insert gagal menyebut kolom `bucket`, ia mengulang tanpa kolom itu → baris tersimpan `bucket = NULL`. Itu penyebab 6 baris ber-`bucket` kosong di produksi (9-10 Agt 2026, Rp144.000). Sejak `bucket` menentukan amplop, fallback itu menghasilkan **dua buku berbeda**: amplop terpotong sesuai pos yang dimaksud, tapi `splitByBucket` membaca NULL sebagai restock. Migrasi 016 sudah terpasang & terverifikasi — fallback itu kini hanya menyembunyikan kegagalan.
- **Pengeluaran bucket `personal` TETAP memotong amplop pribadi TAPI DIKECUALIKAN dari Laba Rugi** — `expenseService.splitByBucket` memisahkan `personal` dari `nonRestock` (yang masuk `variableExpenses` P&L). Alasannya: itu prive pemilik, bukan biaya usaha. Ada DUA jalur uang pribadi yang keduanya memotong amplop `personal` sekaligus keduanya di luar P&L: `POST /admin/finance/withdraw` (bucket personal) dan pengeluaran ber-bucket `personal`.

---

## 5. Inventaris Fitur

### Pelanggan
Login OTP/tamu · Menu (kategori, cari, urut, opsi size/gula/suhu) · Keranjang & Checkout (dine-in/takeaway) · **Bayar: QRIS (DOKU) + Saldo Rehat** · Nomor antrian + linimasa status live · **Tracker pesanan di halaman Menu** (banner progres 4 tahap, **FIFO** — pesanan paling dulu dibuat; auto-hilang bila tak ada pesanan aktif) · **Layar "Lacak Pesanan"** via ikon struk di app bar (Sedang berjalan FIFO + Riwayat) · Riwayat pesanan · **Pesan Lagi** (reorder) · Loyalti (poin + stamp + tier) · Spin wheel · Favorit · Ulasan menu · Notifikasi push · **Dompet/Saldo (top-up DOKU + riwayat)** · **Referral (ajak teman, voucher 15%)** · Hadiah ulang tahun otomatis · Mode gelap.

### Admin / Kasir
Dashboard penjualan (**omzet, HPP, laba kotor & bersih RIIL, margin%**) · Grafik harian + kalender · Item terlaris (dgn margin) · **Analitik** (jam sibuk, hari, AOV, repeat-rate) · **Tutup Kasir + rekonsiliasi DOKU + ekspor CSV** · **Segmen Pelanggan (RFM) + broadcast promo** · Pesanan masuk & pending · POS kasir (Tunai/QRIS/**Saldo**/Simpan) · Ubah status pesanan · **HPP & Margin Menu** (editor modal) · Kelola gambar menu · Kelola banner · Pesanan tersimpan · Printer thermal Bluetooth + auto-struk · Pengeluaran · **Keuangan (KHUSUS PEMILIK)**: Laba Rugi bulanan + biaya tetap (Tahap 1), **amplop alokasi + buku besar + rambu break-even/runway** (Tahap 2, lihat §5g).

### Loyalti — mekanisme saat ini
- **Poin**: 1 poin / Rp 1.000 (`POINTS_PER_RUPIAH = 1/1000`), dihitung saat order dibuat (`points_earned`). Menentukan **TIER**: Bronze(0)/Silver(500)/Gold(1000)/Platinum(1500). **Poin belum bisa dibelanjakan** (hanya status — label "Poin tersedia" di UI agak menyesatkan).
- **Stamp**: +1 per pesanan. **9 stamp = 1 kopi gratis** (`stamps_to_free = 9 − stamp%9`). **Penukaran masih MANUAL** — tak ada tombol tukar, tak ada reset, tak ada voucher otomatis; kasir menghormatinya secara informal.
- **Diberikan saat status `paid`** (bukan lagi `completed`), idempoten via `loyalty_history.ref_order_id` → aman meski dipanggil lagi saat `completed`.
- Hanya untuk pesanan **berakun**. Pesanan kasir/tamu `points_earned = 0` → tak dapat poin/stamp.

---

## 5b. Notifikasi WhatsApp (Fonnte) — ATURAN PENTING

Gateway: **Fonnte**, device pengirim **`087777601617`** (paket Free, kuota 1000/bulan). `sendWhatsapp` sudah mendukung target grup (ID `…@g.us` diteruskan apa adanya, tidak dinormalkan).

> ⚠️ **Riwayat & jebakan (Juli 2026):** device `087777601617` **di-soft-ban WhatsApp** untuk *cold-outbound* — OTP 1-lawan-1 ke nomor baru **tak terkirim** (status Fonnte "connect" & "queued" tapi tak sampai), **sementara pesan ke grup tetap jalan** (device anggota grup = tepercaya; OTP ke banyak orang asing = sidik jari spam). Sempat dicoba `087864504924` (nomor admin — berisiko membakar WA pribadi), lalu dipindah ke **nomor `087864504924`**. Token pengirim = `FONNTE_TOKEN` (Railway + `.env` lokal); ganti device = ganti token itu. **Ini solusi sementara** — nomor unofficial baru pun berisiko kena flag yang sama seiring volume OTP. Solusi andal jangka panjang: **WhatsApp Business API resmi** atau OTP via **email/SMS provider transaksional**. Kode `sendOtp` kini **tak pernah 500** saat gagal (kembalikan `otpSent`), layar OTP menampilkan peringatan + tombol kirim ulang.
> **Update terbaru (permintaan user):** device pengirim **dikembalikan ke `087777601617`** (token `FONNTE_TOKEN` diganti di Railway + `.env`). ⚠️ Ini nomor yang **dulu kena soft-ban** (lihat riwayat di atas) & merupakan **nomor admin `irur`** — pantau ketat apakah OTP ke nomor baru benar-benar sampai; bila "queued" tapi tak terkirim, itu gejala flag berulang.
> **Saat ganti device Fonnte:** pastikan nomor baru juga **anggota (admin) grup** `WA_ANNOUNCE_GROUP`, kalau tidak pengumuman grup berhenti.

**Siapa dapat WA otomatis:**
| Jenis pesanan | `source` | WA ke pelanggan | Pengumuman grup |
|---|---|---|---|
| Pelanggan berakun | `app` | ✅ | ✅ |
| Tamu via app | `app` | ✅ (HP **wajib**) | ✅ |
| **Kasir (walk-in)** | `cashier` | ❌ | ❌ |

- **Pembeda = kolom `orders.source`** (migrasi 011), BUKAN tebakan dari ada/tidaknya nomor HP. Dulu pakai heuristik `!user_id && !guest_phone` — **rapuh**, karena tamu tanpa HP identik dengan pesanan kasir.
- **WA admin per-nomor DIHENTIKAN** — `sendWhatsappToAdmins` tak lagi dipanggil. Env `ADMIN_WA_NUMBER` masih ada tapi **tak terpakai**. Notifikasi in-app + push ke admin tetap jalan.
- **Pengumuman grup**: env **`WA_ANNOUNCE_GROUP`** (Railway) = `120363427346432341@g.us` (grup pengumuman komunitas Rehat). Ganti grup cukup ubah env — tak perlu ubah kode.
- Syarat kirim ke grup: device pengirim **harus anggota** grup (untuk grup announcement komunitas, biasanya harus **admin**). Cek daftar grup: `POST https://api.fonnte.com/get-whatsapp-group` (header `Authorization: <FONNTE_TOKEN>`).
- ⚠️ Respons Fonnte `"success! message in queue"` hanya berarti **diterima antrean**, BUKAN terkirim. Verifikasi manual di WhatsApp.

**Format pesan pengumuman grup** (saat pesanan lunas): no. antrian, **nama pemesan**, **tipe pesanan**, **metode bayar**, detail item, total.
Label: `PAYMENT_LABELS` (qris→QRIS, cash→Tunai, balance→Saldo Rehat, dst) & `ORDER_TYPE_LABELS` (dine_in→Dine-in 🍽️, takeaway→Bawa Pulang 🥤).
Pesan ke pelanggan saat lunas juga memuat metode + tipe + antrian + info "sedang diproses"; saat selesai ada WA "pesanan selesai".

---

## 5c. Pelacakan Pesanan (tracking)

Sumber data: **`ordersTrackingProvider`** (`order_repository.dart`) — StreamProvider `autoDispose`.
- **Admin → `fetchAllOrders()`** (semua pesanan, selaras dengan layar Pesanan Masuk). **Pelanggan → `fetchHistory()`** (pesanan sendiri).
- Polling **3 dtk** saat ada pesanan berjalan, melambat **20 dtk** saat tak ada (hemat baterai/kuota).
- **Refresh seketika saat aplikasi kembali ke depan** (`AppLifecycleState.resumed`) — kunci agar status langsung ter-update sepulang bayar di browser DOKU.
- Di-`invalidate` juga setelah pesanan dibuat/dibayar & setelah "Tandai Selesai".

Turunannya: **`activeOrderProvider`** memilih pesanan aktif **paling dulu dibuat (FIFO)** untuk banner di Menu.
Widget bersama: `OrderTrackCard` (kartu + progres 4 tahap) & `CompleteOrderButton` (**tombol hanya tampil untuk admin**; pelanggan cuma memantau).

**Responsivitas UI:** pakai pola *keep-previous-data* — spinner/skeleton HANYA saat belum ada data sama sekali (`valueOrNull == null`); saat refresh, data lama tetap tampil supaya layar tak berkedip "loading". Sudah diterapkan di layar Lacak Pesanan & grid Menu.

---

## 5d. Zona Waktu — SEMUA pakai WIB (UTC+7)

Server Railway berjalan **UTC**, perangkat bisa zona apa saja. Tanpa konversi eksplisit, jam meleset 7 jam. Aturannya:

**Backend** — helper terpusat di `orderService.js`:
`wibDateKey(d)` · `wibDayRange('YYYY-MM-DD')` · `wibStartOfDaysAgo(n)`
Dipakai untuk: **reset nomor antrian** (tengah malam WIB), laporan penjualan, kalender, **analitik jam sibuk** (geser ke WIB lalu baca `getUTCHours/getUTCDay`), dan tutup kasir.
> Jangan pernah pakai `new Date().toISOString().slice(0,10)`, `setHours(0,0,0,0)`, atau `getHours()` mentah untuk batas "hari" — itu UTC server.

**Frontend** — konversi terpusat di `core/utils/formatters.dart`:
```dart
static DateTime toWib(DateTime d) => d.toUtc().add(const Duration(hours: 7));
```
`tanggal()` / `tanggalJam()` / `jam()` semuanya sudah lewat `toWib`. **Jangan memakai `DateFormat` langsung** di layar — nanti jam kembali tampil UTC (bug ini pernah terjadi di Riwayat Pesanan). `toUtc()` dipanggil dulu agar aman untuk DateTime UTC maupun lokal.
Default "hari ini" (tutup kasir) & "bulan ini" (kalender) juga memakai `Formatters.toWib(DateTime.now())`, bukan jam perangkat.

---

## 5e. Alur Status Pesanan

**Dibuat → Dibayar → Diproses → Selesai** (4 tahap).

- Saat pembayaran diterima, `updateOrderStatus(id,'paid')` **menyimpan status `processing`** (auto-advance) — semua efek 'paid' tetap jalan (`paid_at`, nomor antrian, poin & stamp, notifikasi, pengumuman grup).
- Status **`ready` ("Siap diambil") DIHAPUS dari alur** — tak bisa di-set lagi (dibuang dari `ORDER_STATUSES`, skema route, `OrderStatus.flow`, timeline). Nilainya **masih dikenali** agar pesanan lama tetap tampil. `SOLD_STATUSES` tetap memuatnya supaya laporan lama akurat.
- Satu-satunya aksi manual staf: **Tandai Selesai** (`CompleteOrderButton`, dipakai bersama oleh layar Pesanan Masuk **dan** kartu lacak). Tombol "Tandai Diproses" sudah dihapus.

---

## 5f. Aturan Bisnis / Validasi

- **Nama pelanggan WAJIB** di semua jalur — termasuk **kasir** (dulu opsional & di-default `'Pelanggan'`; default itu sudah dihapus). Divalidasi di frontend **dan** backend.
- **No. HP tamu WAJIB** (min 8 angka) untuk pesanan tamu via aplikasi — karena WA satu-satunya kanal notifikasi mereka. **Kasir dikecualikan** (`source='cashier'`, pelanggan hadir langsung).
- **Bayar pakai Saldo**: tersedia di checkout pelanggan **dan** di kasir. Kasir memakai `POST /admin/orders/:id/pay-balance` → memotong saldo **admin yang login** (order kasir = guest, tak punya pemilik).
- **Saldo bersifat atomik** lewat RPC `increment_balance` (migrasi 010); ada fallback read-modify-write bila RPC belum ada.

---

## 5g. Modul Keuangan Tahap 2 (amplop alokasi) — KHUSUS PEMILIK

Lanjutan Modul Keuangan Tahap 1 (§8). Omzet harian dipecah **waterfall** ke 5 pos ("amplop"): **restock, operational, personal, scaling, emergency**. Tiap alokasi/penarikan ditulis sebagai **baris di `finance_ledger`** (`direction: 'in'|'out'`, `source: 'allocation'|'withdrawal'`) — **saldo pos TIDAK PERNAH disimpan sebagai kolom**, selalu dijumlah ulang dari ledger (event-sourced, `bucketBalances()` di `financeCalc.js`). **Tidak menambah migrasi DB** — tabel sudah tersedia dari migrasi 016.

- **Alokasi** (`financeService.allocateForDate`): waterfall 3-arah dari jatah pemilik (restock % dari `finance_settings.pct_restock`, operational tetap harian, sisanya dibagi rasio personal/scaling/emergency). Idempoten permanen lewat **unique index parsial** `(bucket, ref_date) WHERE source='allocation'` — memanggil dua kali untuk tanggal sama tidak menggandakan baris.
- **Penarikan** (`financeService.withdrawFromBucket`): baris `direction:'out'`, idempotensi hanya **lapis aplikasi** (lihat §4).
- **Rambu keputusan** (`GET /admin/finance/overview`): `breakEvenDaily` (omzet harian minimum biar bulan ini impas) + `runwayDays` (berapa hari saldo **`operational`** bertahan menutup biaya bulanan — `floor(saldo.operational / (biaya/30))`, BUKAN saldo `personal`) + `personalWithdrawBlocked` (rem otomatis tarik-pribadi, menyala saat `saldo.operational < biaya`). Dasar perhitungan = **bulan LENGKAP terakhir** (`basis:'previous'`), fallback bulan berjalan yang di-run-rate (`basis:'current_partial'`) — lihat §4 untuk alasan.
- **Layar Flutter**: Ringkasan Keuangan (`finance-overview`, `/profile/finance/overview`, `finance_overview_screen.dart`) — kartu 5 pos + rambu + aksi backfill tanggal bolong. Buku Besar (`finance-ledger`, `/profile/finance/ledger`, `finance_ledger_screen.dart`) — daftar mutasi berpaginasi keyset, filter per pos.
- **Repository**: `FinanceRepository` (`finance_repository.dart`) — `fetchOverview()`, `fetchLedger({bucket,limit,before,beforeId})`, `withdraw({bucket,amount,note})`, `allocate(String date)` (tanggal **wajib**, tak ada default).
- Detail jebakan (jendela pemicu, bentuk cursor, flag rambu, dll.) ada di §4.

---

## 6. Endpoint Backend (peta ringkas)

- **Auth**: `POST /auth/{register,verify-otp,login,resend-otp,refresh,logout}` (identifier-based, camelCase token).
- **User**: `GET/PUT /users/me`, `POST /users/me/avatar`. (`/users/me` juga memicu hadiah ulang tahun.)
- **Menu**: `GET /menu/items` (limit default 100; `available_only`), `/menu/items/:id`, `/menu/featured`, `/menu/categories`, `PUT /menu/items/:id/image`, **`PATCH /menu/items/:id`** (HPP/harga/available).
- **Order**: `POST /orders`, `GET /orders`, `/orders/:id`, `POST /orders/:id/{pay,qris,reorder,pay-balance}`, `POST /admin/orders`, `POST /admin/orders/:id/pay-balance`, `PATCH /orders/:id/status`.
- **Loyalty/Spin/Voucher/Favorites/Notifications**: `GET /loyalty`, `/loyalty/history`, `/spin`, `/spin/status`, `/vouchers`, `/vouchers/validate`, `/favorites`, `/notifications`, `POST /admin/broadcast`.
- **Referral/Wallet**: `GET /referrals/me`, `POST /referrals/apply`, `GET /wallet`, `POST /wallet/topup`.
- **Admin reports**: `/admin/reports/{sales,calendar,closing,analytics}`, `/admin/customers/segments`, `/admin/expenses`.
- **Admin finance** (KHUSUS PEMILIK, lihat §4 & §5g): `GET /admin/finance/ping`, `GET/POST /admin/finance/fixed-costs`, `DELETE /admin/finance/fixed-costs/:id`, `GET /admin/finance/pnl?month=YYYY-MM` (Tahap 1); `POST /admin/finance/allocate` (default HARI INI — berbahaya, lihat §4), `GET /admin/finance/overview`, `POST /admin/finance/withdraw`, `GET /admin/finance/ledger` (Tahap 2). Semua di belakang `authenticate` + `requireFinanceAccess` (404 utk non-pemilik).
- **Payments webhook**: `POST /payments/doku/notify` (cabang `TOPUP-*` → kredit saldo; selain itu → order paid).

Detail model & validasi ada di kode (`src/routes/index.js`, `src/services/*`). Enum `notif_type` & `voucher_source` ketat — nilai tak dikenal di-coerce/gagal senyap.

---

## 7. Rekomendasi Fitur ke Depan

### 🔴 Kesiapan produksi (paling penting untuk "profesional")
1. **Keystore rilis + build AAB** — syarat Play Store (kini masih debug-signed).
2. **Pengujian otomatis** — Flutter: **150 unit test** (jalur uang: checkout, **kasir**, cart, loyalti, tracking, keuangan) + CI gate (`flutter analyze --fatal-infos` + `flutter test`). Backend: **mulai punya test** (Jest+Supertest, 23 test, cakupan baru modul keuangan — `npx jest` di repo backend). Utang tersisa: **widget/integration test** layar checkout & kasir, plus test backend untuk modul selain keuangan (orders, auth, loyalty, dll. masih tanpa test).

### 🟡 Fitur produk
3. **CRUD Menu di panel admin** — saat ini **belum ada layar "Tambah Menu"**; menu baru harus di-INSERT langsung ke tabel `menu_items` di Supabase (yang tersedia baru edit HPP/harga/ketersediaan via `PATCH /menu/items/:id` + unggah gambar). Perlu: tambah/ubah/arsipkan menu, pilih kategori, atur `sort_order`, deskripsi, & opsi. *(disepakati: nanti)*
4. **Penukaran stamp digital** — tombol "Tukar kopi gratis" → voucher 100% + reset 9 stamp (kini manual). *(disepakati: nanti)*
5. **Belanja poin** — poin → voucher/diskon (kini poin cuma tier). *(disepakati: nanti)*
6. **Manajemen stok** — catat stok, kurangi otomatis, "habis" otomatis + peringatan.
7. **Kitchen Display System (KDS)** + waktu penyajian.
8. **Pra-pesan terjadwal**, **QR pesan-dari-meja** (dine-in), **langganan kopi**, **tip barista**.

### 🟢 Optimasi
9. Manajemen stok gambar/CDN, skeleton loader lebih luas, aksesibilitas lanjutan, refund/void beraudit, shift/staf (penjualan per kasir), multi-outlet.

---

## 8. Status Terkini (ringkas)

- ✅ Semua fitur di §5 **live** (web + backend), APK admin & customer ter-build (arm64/v7a/x86_64, obfuscated).
- ✅ Migrasi **001–011** dijalankan & terverifikasi (HPP, wallet, referral, atomic-balance, `orders.source`).
- ✅ Terverifikasi end-to-end di produksi: top-up DOKU → webhook kredit saldo → bayar pakai saldo (potong atomik) → riwayat transaksi benar.
- ✅ Notifikasi WA grup aktif; WA admin per-nomor dihentikan; kasir tanpa WA otomatis.
- ✅ Waktu seluruh sistem konsisten **WIB** (penyimpanan UTC → perhitungan WIB → tampilan WIB).
- ✅ Alur status disederhanakan (tanpa "Siap diambil"), auto-proses setelah bayar, tracking FIFO.
- 👤 **Akun admin saat ini (2):** `irur` (087777601617) & `irurr` (087864504924). **Device Fonnte pengirim OTP kini nomor `087777601617`** (= nomor admin `irur`; perhatikan riwayat soft-ban di §5b).
  Menjadikan admin: `node src/db/set-admin.js <nomor>` di folder backend.
- ⏳ **Ditunda (permintaan user):** penukaran stamp digital & belanja poin.
- ✅ **Refund tunai** live (backend `POST /admin/orders/:id/refund` + tombol di detail pesanan admin); migrasi 012 terpasang. Masih **tunai-only** (QRIS/Saldo belum).
- ✅ **Modul Keuangan Tahap 1** live (layar Laba Rugi bulanan + Biaya Tetap, khusus pemilik `irurr`); migrasi 016 terpasang. Margin kotor produksi **58,6%** (HPP 41,4%), biaya tetap **Rp8.000.000/bulan**, P&L Juli 2026: omzet Rp15.055.400 → laba bersih **Rp742.877 (5%)**.
- ✅ **Modul Keuangan Tahap 2 (amplop alokasi, lihat §5g) selesai di branch `feat/keuangan-tahap2`** (backend + Flutter, kedua repo) — **belum di-push, belum deploy**. Tidak menambah migrasi. Sanity produksi 2026-08-09: alokasi harian idempoten (5 baris ledger, Σ persis omzet hari itu), `breakEvenDaily` Rp462.128 (basis Juli 2026 penuh), `runwayDays` 1, `personalWithdrawBlocked` true. Backend 133/133 test, Flutter 281/281 test, keduanya lulus tanpa kredensial.
- ⏳ **Tahap 3 (auto-kalibrasi: shrinkage `w=n/(n+30)`, deadband 2 poin persen, batas gerak ±3 poin/bulan, wizard kalibrasi) belum dikerjakan.**
- ⏳ **Utang Tahap 2 yang sengaja ditunda:** tak ada endpoint koreksi/pembatalan baris `finance_ledger` (hanya SQL manual Supabase); tak ada batas atas `amount` penarikan; paginasi `getFinanceOverview` masih offset (keyset hanya di `listLedger`); `runwayDays` boleh negatif tanpa dibatasi; `grossMarginPct` dibulatkan ke integer oleh `pct()`.
- ⏳ **Belum:** keystore rilis + AAB, manajemen stok, refund QRIS/Saldo beraudit.

### Cara cepat verifikasi skema/DB (tanpa psql)
Buat skrip sekali pakai **di dalam folder backend** (agar `node_modules` ter-resolve), pakai client yang sudah ada:
```js
require('dotenv').config()
const { supabaseAdmin: sb } = require('./src/config/supabase')
;(async () => {
  const r = await sb.from('orders').select('id, source').limit(1)
  console.log(r.error ? '❌ ' + r.error.message : '✅ kolom ada')
})()
```
`DATABASE_URL` placeholder → `pg`/psql TIDAK bisa dipakai; hanya `SUPABASE_URL` + service key yang valid.

---

## 9. Referensi rahasia (JANGAN commit)
- Backend `.env` (server-only): kunci DOKU (produksi), Supabase service key, Fonnte token, `ADMIN_WA_NUMBER`. **Tidak ada rahasia di kode Flutter.**
- `.gitignore` sudah menutup `*.env`, keystore (`*.jks`/`key.properties`).
- `google-services.json` (Firebase client) ter-track — API key client bukan rahasia (aman untuk app), keamanan via Firebase Rules.
