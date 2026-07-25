# Kasir Tukar Stamp Pelanggan (Sekali Tap) — Desain

**Tanggal:** 2026-07-25
**Status:** Disetujui, siap implementasi

## Masalah

Saat ini voucher gratis-minuman dari stamp hanya lahir bila **pelanggan** menekan tombol
"Tukar kopi gratis" di aplikasinya (`POST /loyalty/stamps/redeem`). Kasir hanya bisa
*menandai terpakai* voucher yang sudah lahir (`GET/POST /admin/free-drink-vouchers`).

Akibatnya: pelanggan dengan ≥9 stamp yang **belum** menekan tombol tukar **tidak muncul**
di pencarian kasir. Kasir tak bisa melayani "stampku penuh, mau kopi gratis" tanpa menyuruh
pelanggan membuka app dan menekan tombol dulu.

## Tujuan

Kasir dapat mencari pelanggan via HP, melihat stamp yang siap ditukar, lalu **menukar +
menyerahkan minuman dalam sekali tap** — tanpa pelanggan perlu menyentuh aplikasinya.

## Keputusan desain (disepakati)

1. **Sekali tap: tukar + langsung terpakai.** Voucher dibuat langsung `is_used=true`.
2. **Digabung** di sheet "Tukar Voucher Gratis" yang ada — satu pencarian HP, dua seksi hasil.
3. **Kirim notifikasi** ke pelanggan: "1 kopi gratismu baru ditukar di kasir".

## Backend

Menambah dua endpoint di `src/routes/index.js` (guard `adminAccess`) + fungsi di
`src/services/loyaltyService.js`. Konstanta `STAMP_TARGET = 9` dan helper `availableStamps`
sudah ada — dipakai ulang.

### `GET /admin/stamp-lookup?phone=&name=`
- Validasi `phone` ≥ 3 angka (pola sama `findFreeDrinkVouchers`), else `400 LOOKUP_PHONE_REQUIRED`.
- Cari user: `users` `ilike('phone', %clean%)` limit 10; filter `ilike('name', %name%)` bila diisi.
- Ambil `stamp_cards` (`user_id, stamp_count, redeemed_count`) untuk user tsb, hitung
  `available = availableStamps(card)`.
- Kembalikan hanya `available >= STAMP_TARGET`:
  `{ userId, name, phone, availableStamps, redeemableRewards: floor(available/9) }`.
- Urutkan by nama (stabil).

### `POST /admin/stamp-redeem` body `{ userId }`
Fungsi `redeemStampForCustomer(userId)`:
- Baca `stamp_cards`; hitung `available`. Bila `< STAMP_TARGET` → `400 STAMP_NOT_ENOUGH`.
- **Kunci optimistik** (sama seperti `redeemStamp`): `update redeemed_count = current+1`
  `.eq('redeemed_count', current)`. Bila 0 baris → `409 STAMP_REDEEM_CONFLICT` (aman dari
  balapan dengan tap pelanggan sendiri — 9 stamp tak terpotong dua kali).
- Buat voucher **langsung terpakai**: `source='stamp'`, `reward_type='free_drink'`,
  `discount_pct=100`, `is_used=true`, `used_at=now()`, `expires_at=+30h` (redundan tapi
  konsisten skema). Bila insert gagal → rollback `redeemed_count`.
- Catat `loyalty_history` (best-effort).
- Kirim notifikasi (best-effort): judul "Kopi gratis ditukar ☕", body "1 kopi gratismu
  baru saja ditukar di kasir. Selamat menikmati!".
- Return `{ voucher, code }`.

Refactor kecil: ekstrak inti "naikkan redeemed_count + buat voucher" agar `redeemStamp`
(app, voucher belum-terpakai) dan `redeemStampForCustomer` (kasir, voucher terpakai) berbagi
logika lewat flag `markUsed`.

## Frontend

### `free_drink_repository.dart`
- Model baru `StampRedeemCandidate { userId, name, phone, availableStamps, redeemableRewards }`.
- `lookupStamps(phone, name) → List<StampRedeemCandidate>` (`GET /admin/stamp-lookup`).
- `redeemForCustomer(userId) → void` (`POST /admin/stamp-redeem`).

### `free_drink_controller.dart`
- `FreeDrinkState` tambah `stampCandidates` + `redeemingUserId`.
- `lookup()` memanggil voucher-lookup **dan** stamp-lookup paralel (`Future.wait`); anti-balapan
  `_seq` yang ada tetap menjaga hanya respons terbaru dipakai.
- `redeemStampFor(userId) → bool`: set `redeemingUserId`, panggil repo, sukses → panggil ulang
  `lookup` (refresh sisa) atau kurangi kandidat lokal.

### `free_drink_redeem_screen.dart`
- `_results()` render dua seksi: (1) "Voucher gratis aktif" (existing), (2) "Stamp siap tukar".
- Kartu stamp: nama + "N kopi gratis siap" + tombol **"Tukar & serahkan"** (spinner `busy`
  per-kartu). Tekan → dialog konfirmasi → `redeemStampFor` → snackbar.
- Empty-state gabungan: bila kedua daftar kosong setelah cari → pesan "Tak ada voucher/stamp".

## Testing

- **Backend:** `redeemStampForCustomer` — cukup vs kurang stamp; double-tap → satu `409`;
  voucher lahir `is_used=true`. `stamp-lookup` hanya mengembalikan `available >= 9`.
- **Frontend:** controller `lookup` menggabung dua sumber; `_seq` anti-balapan tetap jalan;
  `redeemStampFor` sukses/gagal memperbarui state benar.

## Di luar cakupan

- Menukar poin dari sisi kasir (hanya stamp).
- UI riwayat penukaran kasir (KPI stamp existing `getStampRedemptionStats` sudah mencatat).
