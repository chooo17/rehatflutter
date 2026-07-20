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
Migrasi ada: `001`–`011` (**semua sudah dijalankan & terverifikasi**).
Terbaru: `008` cost_price (HPP) · `009` referral+wallet · `010` RPC `increment_balance` · `011` `orders.source`.

**Pola WAJIB saat menambah kolom:** buat query-nya **defensif** (coba dengan kolom baru → ulangi tanpa kolom itu bila error menyebut kolom tsb). Tanpa ini, migrasi yang tertinggal bisa **merusak alur pembayaran**. Contoh ada di `getSalesReport` (cost_price), `updateOrderStatus` (source), dan `createGuestOrder` (`optionalCols`).

---

## 4. Konvensi & Jebakan (Gotchas)

- **AppColors**: token tema (espresso, crema, textPrimary…) adalah **getter runtime**, BUKAN const → jangan pakai `const` dgn itu (build rusak). Token semantik (`success`, `error`, `warning`, `amber`) memang `const`.
- **Widget Neu** (`shared/widgets/neu.dart`): sudah **flat** (border tipis), dependency `flutter_neumorphic_plus` **dihapus**. API dipertahankan (`NeuCard/NeuButton/NeuInset/NeuCircleButton/NeuBottomBar/NeuThemeScope`).
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

---

## 5. Inventaris Fitur

### Pelanggan
Login OTP/tamu · Menu (kategori, cari, urut, opsi size/gula/suhu) · Keranjang & Checkout (dine-in/takeaway) · **Bayar: QRIS (DOKU) + Saldo Rehat** · Nomor antrian + linimasa status live · **Tracker pesanan di halaman Menu** (banner progres 4 tahap, **FIFO** — pesanan paling dulu dibuat; auto-hilang bila tak ada pesanan aktif) · **Layar "Lacak Pesanan"** via ikon struk di app bar (Sedang berjalan FIFO + Riwayat) · Riwayat pesanan · **Pesan Lagi** (reorder) · Loyalti (poin + stamp + tier) · Spin wheel · Favorit · Ulasan menu · Notifikasi push · **Dompet/Saldo (top-up DOKU + riwayat)** · **Referral (ajak teman, voucher 15%)** · Hadiah ulang tahun otomatis · Mode gelap.

### Admin / Kasir
Dashboard penjualan (**omzet, HPP, laba kotor & bersih RIIL, margin%**) · Grafik harian + kalender · Item terlaris (dgn margin) · **Analitik** (jam sibuk, hari, AOV, repeat-rate) · **Tutup Kasir + rekonsiliasi DOKU + ekspor CSV** · **Segmen Pelanggan (RFM) + broadcast promo** · Pesanan masuk & pending · POS kasir (Tunai/QRIS/**Saldo**/Simpan) · Ubah status pesanan · **HPP & Margin Menu** (editor modal) · Kelola gambar menu · Kelola banner · Pesanan tersimpan · Printer thermal Bluetooth + auto-struk · Pengeluaran.

### Loyalti — mekanisme saat ini
- **Poin**: 1 poin / Rp 1.000 (`POINTS_PER_RUPIAH = 1/1000`), dihitung saat order dibuat (`points_earned`). Menentukan **TIER**: Bronze(0)/Silver(500)/Gold(1000)/Platinum(1500). **Poin belum bisa dibelanjakan** (hanya status — label "Poin tersedia" di UI agak menyesatkan).
- **Stamp**: +1 per pesanan. **9 stamp = 1 kopi gratis** (`stamps_to_free = 9 − stamp%9`). **Penukaran masih MANUAL** — tak ada tombol tukar, tak ada reset, tak ada voucher otomatis; kasir menghormatinya secara informal.
- **Diberikan saat status `paid`** (bukan lagi `completed`), idempoten via `loyalty_history.ref_order_id` → aman meski dipanggil lagi saat `completed`.
- Hanya untuk pesanan **berakun**. Pesanan kasir/tamu `points_earned = 0` → tak dapat poin/stamp.

---

## 5b. Notifikasi WhatsApp (Fonnte) — ATURAN PENTING

Gateway: **Fonnte**, device pengirim **`087777601617`** (paket Free, kuota ~950/bulan). `sendWhatsapp` sudah mendukung target grup (ID `…@g.us` diteruskan apa adanya, tidak dinormalkan).

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

## 6. Endpoint Backend (peta ringkas)

- **Auth**: `POST /auth/{register,verify-otp,login,resend-otp,refresh,logout}` (identifier-based, camelCase token).
- **User**: `GET/PUT /users/me`, `POST /users/me/avatar`. (`/users/me` juga memicu hadiah ulang tahun.)
- **Menu**: `GET /menu/items` (limit default 100; `available_only`), `/menu/items/:id`, `/menu/featured`, `/menu/categories`, `PUT /menu/items/:id/image`, **`PATCH /menu/items/:id`** (HPP/harga/available).
- **Order**: `POST /orders`, `GET /orders`, `/orders/:id`, `POST /orders/:id/{pay,qris,reorder,pay-balance}`, `POST /admin/orders`, `POST /admin/orders/:id/pay-balance`, `PATCH /orders/:id/status`.
- **Loyalty/Spin/Voucher/Favorites/Notifications**: `GET /loyalty`, `/loyalty/history`, `/spin`, `/spin/status`, `/vouchers`, `/vouchers/validate`, `/favorites`, `/notifications`, `POST /admin/broadcast`.
- **Referral/Wallet**: `GET /referrals/me`, `POST /referrals/apply`, `GET /wallet`, `POST /wallet/topup`.
- **Admin reports**: `/admin/reports/{sales,calendar,closing,analytics}`, `/admin/customers/segments`, `/admin/expenses`.
- **Payments webhook**: `POST /payments/doku/notify` (cabang `TOPUP-*` → kredit saldo; selain itu → order paid).

Detail model & validasi ada di kode (`src/routes/index.js`, `src/services/*`). Enum `notif_type` & `voucher_source` ketat — nilai tak dikenal di-coerce/gagal senyap.

---

## 7. Rekomendasi Fitur ke Depan

### 🔴 Kesiapan produksi (paling penting untuk "profesional")
1. **Keystore rilis + build AAB** — syarat Play Store (kini masih debug-signed).
2. **Pengujian otomatis** — nyaris nol test; prioritaskan alur uang (checkout/pembayaran/loyalti) + gate `flutter analyze`/test di CI.

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
- 👤 **Akun admin saat ini (2):** `irur` (087777601617, device Fonnte) & `irurr` (087864504924).
  Menjadikan admin: `node src/db/set-admin.js <nomor>` di folder backend.
- ⏳ **Ditunda (permintaan user):** penukaran stamp digital & belanja poin.
- ⏳ **Belum:** keystore rilis + AAB, pengujian otomatis, manajemen stok.

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
