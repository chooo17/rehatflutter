# Penukaran Stamp Digital — Design Spec

**Tanggal:** 2026-07-24
**Fitur:** Menukar 9 stamp menjadi voucher "gratis 1 minuman" secara digital, ditukar di kasir.
**Status:** Disetujui (menunggu review spec) → lanjut ke rencana implementasi.

---

## 1. Tujuan & Ruang Lingkup

Menggantikan penukaran stamp yang selama ini **manual & informal** (bergantung ingatan
barista) dengan alur digital yang **tertelusur**:

- Pelanggan menukar 9 stamp lewat tombol di app → dapat voucher **"gratis 1 minuman"**.
- Voucher **hanya ditukar di kasir** (in-store), bukan checkout online.
- Barista memasukkan kode voucher di POS → 1 minuman termahal di keranjang jadi gratis.
- Semua langkah atomik & tercatat; biaya giveaway mengalir sebagai diskon pesanan nyata.

**Di luar ruang lingkup:** belanja poin (fitur terpisah), penukaran online, refund voucher.

## 2. Keputusan Bisnis (sudah dikonfirmasi)

| Keputusan | Nilai |
|---|---|
| Wujud hadiah | Gratis **1 minuman apa saja** (pelanggan pilih ke barista, tak dibatasi sistem) |
| Tempat tukar | **Kasir / in-store saja** |
| Alur redeem | Pelanggan **tekan "Tukar" di app dulu** (buat voucher) → kasir mengonfirmasi |
| Cara kasir menemukan voucher | **Cari pelanggan via no. HP + nama** di POS |
| Cara kasir menerapkan | **Tandai voucher terpakai** (minuman diserahkan langsung) |
| Integrasi biaya/pesanan | **Tidak ada** — tak masuk aliran biaya/diskon order |
| Pelacakan | **KPI: jumlah stamp tertukar** (voucher gratis diterbitkan + berapa terpakai) |
| Masa berlaku voucher | 30 hari sejak dibuat |
| Stamp per hadiah | 9 |

## 3. Data Model

### 3.1 `stamp_cards` (sudah ada — tanpa migrasi)
Kolom: `user_id, stamp_count, redeemed_count, updated_at`.
- `stamp_count` = total stamp kumulatif (tak pernah turun).
- `redeemed_count` = jumlah hadiah yang sudah ditukar.
- **available = `stamp_count − 9 × redeemed_count`**. Bisa tukar bila `available ≥ 9`.
- `stampsToReward` (UI) = `9 − (available mod 9)` bila available>0, else 9. *(Perlu diselaraskan
  dengan perhitungan sekarang yang murni `stamp_count % 9`; lihat §7 Perubahan.)*

### 3.2 Migrasi 013 (`013_add_stamp_reward_voucher.sql`, manual di Supabase)
```sql
-- 1. Tambah nilai enum voucher_source (statement mandiri, di luar transaksi).
ALTER TYPE voucher_source ADD VALUE IF NOT EXISTS 'stamp';

-- 2. Jenis reward voucher: null/'percent' = voucher diskon persen biasa;
--    'free_drink' = gratis 1 minuman.
ALTER TABLE public.vouchers
  ADD COLUMN IF NOT EXISTS reward_type text;
```

### 3.3 Voucher hasil tukar stamp
| Kolom | Nilai |
|---|---|
| `source` | `'stamp'` |
| `reward_type` | `'free_drink'` |
| `discount_pct` | `100` (penanda; tak dipakai untuk hitung) |
| `code` | unik, mis. `STAMP-XXXXXX` (6 char base32) |
| `expires_at` | `now + 30 hari` |
| `is_used` | `false` → `true` saat dipakai kasir |

## 4. Alur Pelanggan — Redeem

**Endpoint:** `POST /loyalty/stamps/redeem` (authenticated).

Langkah (atomik — cegah double-redeem saat dobel-klik):
1. Ambil `stamp_cards` milik user. Hitung `available`.
2. Bila `available < 9` → `AppError('STAMP_NOT_ENOUGH', 400)`.
3. **Naikkan `redeemed_count` secara kondisional** (guard optimistik):
   `update stamp_cards set redeemed_count = redeemed_count + 1
    where user_id = ? and (stamp_count - 9*redeemed_count) >= 9` → cek jumlah baris terpengaruh.
   Bila 0 baris → gagal (sudah ditukar bersamaan) → error.
4. Buat voucher (§3.3) dengan kode unik.
5. Catat `loyalty_history` (`type='stamp_redeem'` bila enum mengizinkan, else `'redeem'`;
   `amount=0`, `description='Tukar 9 stamp → gratis 1 minuman'`).
6. Kembalikan voucher (kode, expires_at).

**UI Loyalti** (`loyalty_screen.dart`):
- Saat `available ≥ 9`: tombol **"Tukar kopi gratis"** aktif (bukan hanya teks).
- Tekan → panggil redeem → sukses: snackbar + `invalidate` voucher & loyalty providers →
  voucher muncul di "Voucher Saya" bertanda **"Gratis 1 minuman • Tunjukkan ke kasir"**;
  stamp berkurang 9 (dari `redeemed_count`).
- Gagal → snackbar pesan server.

## 5. Alur Kasir — Lookup & Tandai Terpakai

> **Terpisah dari alur pesanan.** Penukaran stamp TIDAK menyentuh order/diskon/biaya.
> Barista mengonfirmasi voucher lalu menyerahkan minuman yang diminta pelanggan.

### 5.1 Lookup voucher pelanggan
**Endpoint baru:** `GET /admin/free-drink-vouchers?phone=...&name=...` (adminAccess).
- Cari user via **no. HP** (cocok persis/awalan) — `name` sebagai konfirmasi/penyaring.
- Kembalikan voucher aktif milik user itu: `source='stamp'`, `reward_type='free_drink'`,
  `is_used=false`, `expires_at > now`. Sertakan `voucherId`, `code`, `customerName`, `expires_at`.
- Tak ada hasil → daftar kosong (UI: "tak ada voucher gratis aktif untuk pelanggan ini").
- Privasi: admin-only, data minimal.

### 5.2 Tandai terpakai
**Endpoint baru:** `POST /admin/free-drink-vouchers/:id/use` (adminAccess).
- Validasi voucher: `reward_type='free_drink'`, `is_used=false`, `expires_at > now`.
  Selain itu → error jelas (`FREE_DRINK_VOUCHER_INVALID` / `FREE_DRINK_VOUCHER_USED` /
  `FREE_DRINK_VOUCHER_EXPIRED`).
- Set `is_used=true, used_at=now` (atomik, guard `where is_used=false`).
- Tak ada perubahan pada pesanan/omzet/COGS. Barista membuat minuman pilihan pelanggan.

**UI kasir** (layar/section terpisah, mis. dari POS atau menu admin):
- Section *"Tukar Voucher Gratis"*: isi **no. HP** (+ nama) → lookup → tampilkan voucher aktif.
- Tekan voucher → dialog konfirmasi *"Serahkan 1 minuman gratis untuk {nama}?"* → **Tandai Terpakai**.
- Sukses → voucher hilang dari daftar aktif; snackbar konfirmasi.

## 6. Pelacakan (KPI, bukan biaya)

Penukaran stamp **tidak** dimasukkan ke aliran biaya/margin. Cukup expose **KPI**:

- **`stamp_redemptions`** = jumlah voucher gratis-minuman yang **diterbitkan** dari stamp
  dalam rentang laporan (hitung dari `vouchers` `source='stamp'` berdasarkan `created_at`).
- **`stamp_redemptions_used`** = berapa di antaranya sudah **terpakai** (`is_used=true`).
- Ditambahkan ke ringkasan `GET /admin/reports/sales` (ikut rentang `today/7d/30d`) dan
  ditampilkan sebagai satu kartu KPI di dashboard admin ("Kopi gratis ditukar: X (Y terpakai)").

> Karena tak menyentuh order, tak ada dampak ke omzet/COGS/laba di laporan.

## 7. Perubahan pada Kode yang Ada

- **`stamp_cards` perhitungan available/stampsToReward**: pastikan backend `getLoyalty`
  (atau sejenis) & frontend `LoyaltySummary` memakai `stamp_count − 9×redeemed_count`,
  bukan `stamp_count % 9` mentah — supaya setelah redeem, hitungan turun benar.
- **Notifikasi stamp penuh** (`awardPointsAndStamp`): syarat "penuh" jadi berbasis `available`,
  bukan `stamp_count % 9 == 0`.
- **Label loyalti**: teks "Tunjukkan ke kasir untuk tukar" (sudah diubah) tetap; tambah tombol.

## 8. Edge Cases & Keamanan

- **Double-redeem**: dicegah via update kondisional (§4 langkah 3).
- **Voucher sekali pakai**: `is_used` guard; expired 30 hari.
- **Hanya akun**: tamu tak punya stamp → endpoint authenticated.
- **Kode salah/expired di kasir**: error jelas, pesanan tak dibuat dgn diskon.
- **Keranjang tanpa minuman**: ditolak dengan pesan actionable.

## 9. Testing

- **Frontend (unit, pola karakterisasi seperti checkout/cashier):**
  - Redeem controller (pelanggan): available≥9 → sukses & state; available<9 → error;
    dobel panggil idempoten.
  - Lookup+use controller (kasir): lookup mengembalikan voucher aktif; "tandai terpakai"
    sukses menghapus dari daftar; voucher sudah terpakai/expired → error.
- **Backend:** belum ada test runner. Sertakan skrip verifikasi (`verify-013.js`).
- **Gate:** `flutter analyze --fatal-infos` + `flutter test` hijau sebelum selesai.

## 10. Rencana Rollout

1. Jalankan migrasi 013 di Supabase, verifikasi (`verify-013.js`).
2. Backend: endpoint redeem (pelanggan), lookup + tandai-terpakai (kasir), KPI di sales report,
   penyesuaian perhitungan `available`/notifikasi "stamp penuh".
3. Frontend: tombol redeem di Loyalti + layar/section "Tukar Voucher Gratis" kasir + kartu KPI
   dashboard + test controller.
4. Verifikasi `analyze`/`test`, uji manual alur end-to-end.
