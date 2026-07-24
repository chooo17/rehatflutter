# Belanja Poin — Design Spec

**Tanggal:** 2026-07-24
**Fitur:** Menukar poin loyalti menjadi voucher diskon (10% / 20% / 30%).
**Status:** Disetujui → implementasi.

## 1. Keputusan (dikonfirmasi)

| Keputusan | Nilai |
|---|---|
| Wujud tukar poin | Voucher **diskon persen**: 10% / 20% / 30% |
| Biaya poin | **200 / 400 / 600** poin |
| Efek ke tier | **Tidak turun** — tier dari poin **seumur hidup** (`lifetime_points`) |
| Saldo bisa dibelanjakan | `loyalty_points` (turun saat tukar) |
| Pemakaian voucher | Lewat alur checkout yang sudah ada (online + kasir) |
| Masa berlaku voucher | 30 hari |

## 2. Model poin (migrasi 014)

`014_add_lifetime_points.sql` (manual di Supabase):
```sql
-- Poin seumur hidup: hanya NAIK, menentukan tier (tak turun saat belanja poin).
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS lifetime_points integer NOT NULL DEFAULT 0;
-- Backfill: sebelum fitur ini belum ada yang dibelanjakan → seumur hidup = saldo kini.
UPDATE public.users
  SET lifetime_points = GREATEST(lifetime_points, COALESCE(loyalty_points, 0));
-- Sumber voucher hasil tukar poin.
ALTER TYPE voucher_source ADD VALUE IF NOT EXISTS 'points';
```

Perubahan makna:
- `loyalty_points` → **saldo bisa dibelanjakan** (earn: +; tukar poin: −).
- `lifetime_points` → **total earn seumur hidup**, menentukan tier.

Perubahan kode:
- `awardPointsAndStamp` (orderService): naikkan **kedua** kolom; hitung tier dari `lifetime_points`.
- `GET /loyalty`: `points` = `loyalty_points` (saldo); `tier`/`points_to_next` dari `lifetime_points`.

## 3. Penukaran — `POST /loyalty/points/redeem`

Body: `{ discountPct: 10 | 20 | 30 }`.
Peta biaya: `{ 10: 200, 20: 400, 30: 600 }`.

Langkah (atomik):
1. Validasi `discountPct` ∈ {10,20,30}; tentukan `cost`.
2. Baca `loyalty_points`. Bila `< cost` → `POINTS_NOT_ENOUGH` (400).
3. Kunci optimistik: `update users set loyalty_points = loyalty_points - cost
   where id=? and loyalty_points = <nilai_terbaca>`. 0 baris → `POINTS_REDEEM_CONFLICT` (409).
4. Buat voucher: `source='points'`, `discount_pct=discountPct`, `code` unik, `expires_at=+30h`.
   Bila gagal → rollback saldo.
5. Catat `loyalty_history` type `spend` (best-effort; `amount=-cost`, `balance_after=saldo baru`).
6. Notifikasi (best-effort).

## 4. Frontend

- **Repo** `LoyaltyRepository.redeemPoints(int pct)` → `POST /loyalty/points/redeem`.
- **Layar Loyalti**: section **"Tukar Poin jadi Voucher"** — tampil saldo poin + 3 kartu
  (10%/200, 20%/400, 30%/600). Tombol Tukar nonaktif bila saldo kurang.
  Sukses → `invalidate` summary + vouchers → voucher muncul di "Voucher Saya"; saldo turun.
- Voucher dipakai di checkout via alur voucher yang sudah ada (tanpa perubahan checkout).

## 5. Testing

- Frontend unit (pola controller): redeem sukses memanggil repo dgn pct benar & refresh;
  saldo kurang → tombol nonaktif (logika UI); error API → snackbar.
- Backend: skrip `verify-014.js`.
- Gate `analyze --fatal-infos` + `test`.

## 6. Rollout

1. Migrasi 014 (Supabase) + verifikasi.
2. Backend: award (dua kolom + tier lifetime), `/loyalty` sesuaikan, endpoint redeem.
3. Frontend: repo + section Tukar Poin + test.
4. Verifikasi analyze/test.
