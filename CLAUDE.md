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

### Backend (Railway)
```bash
cd D:\REHAT\rehat-backend\rehat-backend
railway up --service rehat-backend --detach
```
Deteksi deploy baru live: endpoint baru balas **401** (route ada) vs **404** (belum).

### Migrasi DB (MANUAL)
`DATABASE_URL` di `.env` adalah **placeholder** → runner `pg`/psql **tidak jalan**. SQL di `src/db/migrations/*.sql` **dijalankan manual di Supabase Dashboard → SQL Editor**. Verifikasi via `supabaseAdmin.from(x).select().limit(1)`.
Migrasi ada: `001`–`010` (semua sudah dijalankan). Terbaru: `008` cost_price (HPP), `009` referral+wallet, `010` RPC `increment_balance`.

---

## 4. Konvensi & Jebakan (Gotchas)

- **AppColors**: token tema (espresso, crema, textPrimary…) adalah **getter runtime**, BUKAN const → jangan pakai `const` dgn itu (build rusak). Token semantik (`success`, `error`, `warning`, `amber`) memang `const`.
- **Widget Neu** (`shared/widgets/neu.dart`): sudah **flat** (border tipis), dependency `flutter_neumorphic_plus` **dihapus**. API dipertahankan (`NeuCard/NeuButton/NeuInset/NeuCircleButton/NeuBottomBar/NeuThemeScope`).
- **Navbar** (`main_shell.dart`): floating pill + micro-interactions (press-scale, haptic, ikon scale+fade).
- **NeuButton** membungkus child dengan `Align(heightFactor:1)` — penting agar tak memuai di `bottomNavigationBar`.
- **Font**: di-bundle lokal (`assets/fonts/`, Inter+Cormorant+Archivo+Anton), `google_fonts` **dihapus**.
- **Cache build basi**: setelah edit besar, kalau perubahan tak muncul di APK → `flutter clean` lalu rebuild (pernah terjadi: string tak ikut terkompilasi).
- **Disk**: build rilis butuh ruang; kalau "No space left" → hapus `~/.gradle/caches` (regenerable, bebaskan ~11 GB).
- **Auth OTP**: register OTP-gated (akun baru ada setelah verify). DEV OTP **tidak** diprint di Railway (produksi) → OTP hanya via WhatsApp.

---

## 5. Inventaris Fitur

### Pelanggan
Login OTP/tamu · Menu (kategori, cari, urut, opsi size/gula/suhu) · Keranjang & Checkout (dine-in/takeaway) · **Bayar: QRIS (DOKU) + Saldo Rehat** · Nomor antrian + linimasa status live · Riwayat pesanan · **Pesan Lagi** (reorder) · Loyalti (poin + stamp + tier) · Spin wheel · Favorit · Ulasan menu · Notifikasi push · **Dompet/Saldo (top-up DOKU + riwayat)** · **Referral (ajak teman, voucher 15%)** · Hadiah ulang tahun otomatis · Mode gelap.

### Admin / Kasir
Dashboard penjualan (**omzet, HPP, laba kotor & bersih RIIL, margin%**) · Grafik harian + kalender · Item terlaris (dgn margin) · **Analitik** (jam sibuk, hari, AOV, repeat-rate) · **Tutup Kasir + rekonsiliasi DOKU + ekspor CSV** · **Segmen Pelanggan (RFM) + broadcast promo** · Pesanan masuk & pending · POS kasir (Tunai/QRIS/**Saldo**/Simpan) · Ubah status pesanan · **HPP & Margin Menu** (editor modal) · Kelola gambar menu · Kelola banner · Pesanan tersimpan · Printer thermal Bluetooth + auto-struk · Pengeluaran.

### Loyalti — mekanisme saat ini
- **Poin**: 1 poin / Rp 1.000. Menentukan **TIER**: Bronze(0)/Silver(500)/Gold(1000)/Platinum(1500). **Poin belum bisa dibelanjakan** (hanya status).
- **Stamp**: +1 per pesanan **dibayar** (`paid`, idempoten). **9 stamp = 1 kopi gratis**. **Penukaran masih MANUAL** (tak ada tombol tukar / reset / voucher otomatis).
- Poin+stamp hanya untuk pesanan **berakun** (kasir/tamu `points_earned=0`).

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
3. **Penukaran stamp digital** — tombol "Tukar kopi gratis" → voucher 100% + reset 9 stamp (kini manual). *(disepakati: nanti)*
4. **Belanja poin** — poin → voucher/diskon (kini poin cuma tier). *(disepakati: nanti)*
5. **Manajemen stok** — catat stok, kurangi otomatis, "habis" otomatis + peringatan.
6. **Kitchen Display System (KDS)** + waktu penyajian.
7. **Pra-pesan terjadwal**, **QR pesan-dari-meja** (dine-in), **langganan kopi**, **tip barista**.

### 🟢 Optimasi
8. Manajemen stok gambar/CDN, skeleton loader lebih luas, aksesibilitas lanjutan, refund/void beraudit, shift/staf (penjualan per kasir), multi-outlet.

---

## 8. Status Terkini (ringkas)

- ✅ Semua fitur di §5 **live** (web + backend), APK admin & customer ter-build (arm64/v7a/x86_64, obfuscated).
- ✅ Migrasi 001–010 dijalankan. Wallet/referral/HPP/atomic-balance aktif & terverifikasi.
- ⏳ **Ditunda (permintaan user):** penukaran stamp digital & belanja poin.
- ⏳ **Belum:** keystore rilis, testing, manajemen stok.

---

## 9. Referensi rahasia (JANGAN commit)
- Backend `.env` (server-only): kunci DOKU (produksi), Supabase service key, Fonnte token, `ADMIN_WA_NUMBER`. **Tidak ada rahasia di kode Flutter.**
- `.gitignore` sudah menutup `*.env`, keystore (`*.jks`/`key.properties`).
- `google-services.json` (Firebase client) ter-track — API key client bukan rahasia (aman untuk app), keamanan via Firebase Rules.
