# Modul Keuangan Rehat — Tahap 1: Fondasi, Kontrol Akses & Laporan Benar

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mengunci modul keuangan hanya untuk pemilik (087864504924), mencatat biaya tetap bulanan, mengkategorikan pengeluaran, dan menerbitkan Laporan Laba Rugi yang benar — menghapus bug double-counting yang membuat laba bersih hari ini keliru.

**Architecture:** Dua repo. Backend Node/Express (`D:\REHAT\rehat-backend\rehat-backend`) mendapat migrasi DB, middleware akses, router keuangan terpisah, dan kalkulator P&L murni yang teruji. Frontend Flutter (`c:\Users\thezu\rehat_app`) mendapat fitur `lib/features/finance/` dengan dua layar. Logika hitung ditaruh di fungsi murni tanpa DB supaya bisa di-TDD.

**Tech Stack:** Node 20 + Express + Supabase (postgrest client) + Zod + Jest/Supertest (baru) · Flutter 3.44 + Riverpod + go_router.

## Global Constraints

- **Dua repo terpisah.** Backend: `D:\REHAT\rehat-backend\rehat-backend`. Flutter: `c:\Users\thezu\rehat_app`. Setiap task menyebut repo mana.
- **Migrasi SQL dijalankan MANUAL** di Supabase Dashboard → SQL Editor. `DATABASE_URL` adalah placeholder; `pg`/`psql` tidak jalan. Verifikasi lewat skrip `supabaseAdmin`.
- **Pola defensif wajib untuk kolom baru:** setiap query yang menyentuh kolom hasil migrasi harus mencoba dengan kolom itu, lalu mengulang tanpa kolom bila error menyebut nama kolom tersebut. Tanpa ini migrasi yang tertinggal bisa merusak alur pembayaran.
- **Semua batas hari memakai WIB (UTC+7).** Backend: helper `wibDayRange` / `wibDateKey` di `orderService.js`. Flutter: `Formatters.toWib`. Dilarang memakai `new Date().toISOString().slice(0,10)`, `setHours(0,0,0,0)`, `getHours()` mentah, atau `DateFormat` langsung di layar.
- **Envelope respons:** `{ success, data, message }`; error `{ success:false, error:{ code, message } }`.
- **`AppColors` adalah getter runtime, BUKAN const** — jangan pakai `const` dengan token tema (espresso, crema, textPrimary…). Token semantik (`success`, `error`, `warning`, `amber`) memang const.
- **Pakai widget `Neu*`** dari `lib/shared/widgets/neu.dart` agar konsisten.
- **Pola keep-previous-data** di layar: spinner hanya saat `valueOrNull == null`.
- **Gate CI:** `flutter analyze --fatal-infos` dan `flutter test` harus lulus. Flutter dipanggil lewat path penuh: `C:\Users\thezu\flutter\bin\flutter.bat`.
- **Bahasa UI: Indonesia.** Semua label, pesan error, dan judul layar.
- **Jangan commit rahasia.** Tidak ada nomor telepon pemilik di source code (lihat Task 3).

---

## Ringkasan Task

| # | Deliverable | Repo |
|---|---|---|
| 1 | Jest + kalkulator P&L murni (teruji) | backend |
| 2 | Migrasi 016 + skrip verifikasi + seed akses | backend |
| 3 | Middleware `requireFinanceAccess` + router keuangan | backend |
| 4 | CRUD biaya tetap | backend |
| 5 | Kategorisasi pengeluaran (`expenses.bucket`) + backfill | backend |
| 6 | Endpoint P&L (menyambung 1, 4, 5) | backend |
| 7 | Repository + model Flutter | flutter |
| 8 | Guard akses + kartu dashboard | flutter |
| 9 | Layar Biaya Tetap | flutter |
| 10 | Layar Laba Rugi | flutter |
| 11 | Dokumentasi + tabel status migrasi | keduanya |

---

## Task 1: Jest + kalkulator P&L murni

Backend belum punya test sama sekali. Task ini memasang Jest sekaligus memakainya untuk logika paling penting: perhitungan laba rugi. Fungsi ini **murni** (tanpa DB), jadi bisa di-TDD sepenuhnya.

**Repo:** `D:\REHAT\rehat-backend\rehat-backend`

**Files:**
- Modify: `package.json` (tambah devDeps + script `test`)
- Create: `src/services/financeCalc.js`
- Test: `src/services/__tests__/financeCalc.test.js`

**Interfaces:**
- Consumes: (tidak ada — task pertama)
- Produces:
  ```js
  computePnl({ revenue, cogs, fixedCosts, variableExpenses, qrisRevenue, qrisFeePct })
  // => { revenue, cogs, grossProfit, grossMarginPct, fixedCosts,
  //      variableExpenses, paymentFees, netProfit, netMarginPct }
  // Semua nilai integer rupiah; *MarginPct integer persen (dibulatkan).
  ```

- [ ] **Step 1: Pasang Jest**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend"
npm install --save-dev jest@29 supertest@7
```

- [ ] **Step 2: Tambah script test di `package.json`**

Ubah blok `"scripts"` menjadi:

```json
"scripts": {
  "start": "node src/index.js",
  "dev": "nodemon src/index.js",
  "migrate": "node src/db/migrate.js",
  "seed": "node src/db/seed.js",
  "test": "jest"
}
```

- [ ] **Step 3: Tulis test yang gagal**

Buat `src/services/__tests__/financeCalc.test.js`:

```js
const { computePnl } = require('../financeCalc')

describe('computePnl', () => {
  // Angka dari spec: omzet Rp36jt, HPP 41,4%, biaya tetap Rp8jt.
  const base = {
    revenue: 36000000,
    cogs: 14902271,
    fixedCosts: 8000000,
    variableExpenses: 500000,
    qrisRevenue: 14400000,
    qrisFeePct: 0.7,
  }

  test('menghitung laba kotor & margin', () => {
    const r = computePnl(base)
    expect(r.grossProfit).toBe(21097729)
    expect(r.grossMarginPct).toBe(59) // 58,6% dibulatkan
  })

  test('fee QRIS = persentase dari omzet QRIS saja, bukan total omzet', () => {
    const r = computePnl(base)
    expect(r.paymentFees).toBe(100800) // 14.400.000 x 0,7%
  })

  test('laba bersih = kotor - tetap - variabel - fee', () => {
    const r = computePnl(base)
    expect(r.netProfit).toBe(21097729 - 8000000 - 500000 - 100800)
  })

  test('pengeluaran restock TIDAK ikut variableExpenses (anti double-counting)', () => {
    // Pemanggil wajib mengirim hanya pengeluaran non-restock.
    // Bila restock Rp2jt ikut terkirim, laba bersih turun Rp2jt -> salah.
    const withRestock = computePnl({ ...base, variableExpenses: 2500000 })
    const correct = computePnl(base)
    expect(correct.netProfit - withRestock.netProfit).toBe(2000000)
  })

  test('nilai kosong/undefined diperlakukan sebagai 0, tidak NaN', () => {
    const r = computePnl({ revenue: 1000000 })
    expect(r.cogs).toBe(0)
    expect(r.netProfit).toBe(1000000)
    expect(Number.isNaN(r.netMarginPct)).toBe(false)
  })

  test('omzet 0 tidak menghasilkan pembagian nol', () => {
    const r = computePnl({ revenue: 0, cogs: 0 })
    expect(r.grossMarginPct).toBe(0)
    expect(r.netMarginPct).toBe(0)
  })

  test('margin negatif dilaporkan apa adanya, tidak di-clamp ke 0', () => {
    const r = computePnl({ revenue: 1000000, cogs: 900000, fixedCosts: 500000 })
    expect(r.netProfit).toBe(-400000)
    expect(r.netMarginPct).toBe(-40)
  })
})
```

- [ ] **Step 4: Jalankan test — pastikan GAGAL**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend" && npx jest financeCalc
```

Expected: FAIL — `Cannot find module '../financeCalc'`.

- [ ] **Step 5: Implementasi minimal**

Buat `src/services/financeCalc.js`:

```js
// Kalkulator keuangan MURNI — tanpa DB, tanpa I/O, supaya bisa diuji penuh.
// Semua nilai rupiah integer.

const int = (v) => {
  const n = Number(v)
  return Number.isFinite(n) ? Math.round(n) : 0
}

const pct = (part, whole) => (whole ? Math.round((part / whole) * 100) : 0)

/**
 * Laba rugi satu periode.
 *
 * PENTING: `variableExpenses` HANYA boleh berisi pengeluaran NON-restock.
 * Pengeluaran restock sudah terhitung di `cogs` lewat menu_items.cost_price;
 * memasukkannya lagi di sini adalah bug double-counting yang jadi alasan
 * modul ini dibuat.
 */
const computePnl = ({
  revenue,
  cogs,
  fixedCosts,
  variableExpenses,
  qrisRevenue,
  qrisFeePct,
} = {}) => {
  const rev = int(revenue)
  const c = int(cogs)
  const fixed = int(fixedCosts)
  const variable = int(variableExpenses)
  const feeRate = Number(qrisFeePct)
  const paymentFees = int((int(qrisRevenue) * (Number.isFinite(feeRate) ? feeRate : 0)) / 100)

  const grossProfit = rev - c
  const netProfit = grossProfit - fixed - variable - paymentFees

  return {
    revenue: rev,
    cogs: c,
    grossProfit,
    grossMarginPct: pct(grossProfit, rev),
    fixedCosts: fixed,
    variableExpenses: variable,
    paymentFees,
    netProfit,
    netMarginPct: pct(netProfit, rev),
  }
}

module.exports = { computePnl }
```

- [ ] **Step 6: Jalankan test — pastikan LULUS**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend" && npx jest financeCalc
```

Expected: PASS, 7 test.

- [ ] **Step 7: Commit**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend"
git add package.json package-lock.json src/services/financeCalc.js src/services/__tests__/financeCalc.test.js
git commit -m "feat(finance): kalkulator P&L murni + setup Jest

Pengeluaran restock sengaja TIDAK masuk variableExpenses -- sudah
terhitung di cogs. Ini memperbaiki double-counting di orderService.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 2: Migrasi 016 + verifikasi + seed akses

**Repo:** `D:\REHAT\rehat-backend\rehat-backend`

**Files:**
- Create: `src/db/migrations/016_add_finance_module.sql`
- Create: `src/db/verify-016.js`

**Interfaces:**
- Consumes: (tidak ada)
- Produces: tabel `finance_settings`, `finance_ledger`, `finance_calibration`, `fixed_costs`; kolom `expenses.bucket`, `users.can_access_finance`.

Catatan: seluruh tabel dibuat sekaligus dalam satu migrasi walau Tahap 1 hanya memakai `fixed_costs`, `expenses.bucket`, dan `users.can_access_finance`. Alasannya migrasi dijalankan manual di dashboard — memecahnya jadi tiga kesempatan lupa.

- [ ] **Step 1: Tulis SQL migrasi**

Buat `src/db/migrations/016_add_finance_module.sql`:

```sql
-- 016: Modul keuangan (amplop alokasi, biaya tetap, kalibrasi, kontrol akses)
-- Dijalankan MANUAL di Supabase Dashboard -> SQL Editor.

-- 1. Kontrol akses khusus pemilik -------------------------------------------
ALTER TABLE users ADD COLUMN IF NOT EXISTS can_access_finance boolean NOT NULL DEFAULT false;

-- 2. Parameter alokasi (baris tunggal) ---------------------------------------
CREATE TABLE IF NOT EXISTS finance_settings (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pct_restock        numeric(5,2) NOT NULL DEFAULT 42.00 CHECK (pct_restock >= 0 AND pct_restock <= 100),
  operational_daily  bigint       NOT NULL DEFAULT 286667 CHECK (operational_daily >= 0),
  ratio_personal     numeric(4,2) NOT NULL DEFAULT 2.00 CHECK (ratio_personal > 0),
  ratio_scaling      numeric(4,2) NOT NULL DEFAULT 1.00 CHECK (ratio_scaling > 0),
  ratio_emergency    numeric(4,2) NOT NULL DEFAULT 0.80 CHECK (ratio_emergency > 0),
  emergency_target   bigint       NOT NULL DEFAULT 25800000,
  started_on         date         NOT NULL DEFAULT CURRENT_DATE,
  calibrated_at      timestamptz,
  updated_at         timestamptz  NOT NULL DEFAULT now()
);

-- 3. Biaya tetap bulanan ------------------------------------------------------
CREATE TABLE IF NOT EXISTS fixed_costs (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name       text   NOT NULL,
  amount     bigint NOT NULL CHECK (amount >= 0),
  category   text,
  due_day    smallint CHECK (due_day IS NULL OR (due_day >= 1 AND due_day <= 31)),
  is_active  boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS fixed_costs_active_idx ON fixed_costs (is_active);

-- 4. Buku besar amplop --------------------------------------------------------
CREATE TABLE IF NOT EXISTS finance_ledger (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bucket     text   NOT NULL CHECK (bucket IN ('restock','operational','personal','scaling','emergency')),
  direction  text   NOT NULL CHECK (direction IN ('in','out')),
  amount     bigint NOT NULL CHECK (amount >= 0),
  source     text   NOT NULL CHECK (source IN ('allocation','withdrawal','expense','adjustment','shortfall')),
  ref_date   date   NOT NULL,
  ref_id     uuid,
  note       text,
  created_by uuid REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);
-- Idempotensi alokasi: satu pos hanya boleh dialokasikan sekali per hari.
CREATE UNIQUE INDEX IF NOT EXISTS finance_ledger_alloc_unique
  ON finance_ledger (bucket, ref_date) WHERE source = 'allocation';
CREATE INDEX IF NOT EXISTS finance_ledger_bucket_idx ON finance_ledger (bucket, created_at DESC);

-- 5. Riwayat kalibrasi --------------------------------------------------------
CREATE TABLE IF NOT EXISTS finance_calibration (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  observed_at    date NOT NULL,
  metric         text NOT NULL CHECK (metric IN ('hpp_pct','operational_daily','revenue_baseline')),
  observed_value numeric NOT NULL,
  smoothed_value numeric NOT NULL,
  sample_days    int NOT NULL,
  status         text NOT NULL DEFAULT 'observed' CHECK (status IN ('observed','proposed','accepted','dismissed')),
  applied_at     timestamptz,
  created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS finance_calibration_metric_idx ON finance_calibration (metric, observed_at DESC);

-- 6. Kategori pos pada pengeluaran --------------------------------------------
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS bucket text
  CHECK (bucket IS NULL OR bucket IN ('restock','operational','personal','scaling','emergency'));

-- Backfill: seluruh 124 catatan lama isinya bahan (SKM, es batu, cup, sedotan).
UPDATE expenses SET bucket = 'restock' WHERE bucket IS NULL;

-- 7. Baris parameter awal ------------------------------------------------------
INSERT INTO finance_settings (id)
SELECT gen_random_uuid() WHERE NOT EXISTS (SELECT 1 FROM finance_settings);
```

- [ ] **Step 2: Jalankan migrasi di Supabase Dashboard**

Buka Supabase Dashboard → SQL Editor → tempel isi file di atas → Run.

Expected: `Success. No rows returned`.

- [ ] **Step 3: Tulis skrip verifikasi**

Buat `src/db/verify-016.js`:

```js
// Verifikasi migrasi 016. Jalankan: node src/db/verify-016.js
require('dotenv').config()
const { supabaseAdmin: sb } = require('../config/supabase')

const OWNER_PHONE = '087864504924'

;(async () => {
  let ok = true
  const check = (label, cond, extra = '') => {
    console.log(cond ? `✅ ${label}` : `❌ ${label} ${extra}`)
    if (!cond) ok = false
  }

  for (const t of ['finance_settings', 'fixed_costs', 'finance_ledger', 'finance_calibration']) {
    const r = await sb.from(t).select('*').limit(1)
    check(`tabel ${t}`, !r.error, r.error?.message || '')
  }

  const e = await sb.from('expenses').select('id, bucket').limit(1)
  check('kolom expenses.bucket', !e.error, e.error?.message || '')

  const u = await sb.from('users').select('id, can_access_finance').limit(1)
  check('kolom users.can_access_finance', !u.error, u.error?.message || '')

  const s = await sb.from('finance_settings').select('*')
  check('finance_settings punya tepat 1 baris', (s.data || []).length === 1,
    `-> ada ${(s.data || []).length}`)

  const nulls = await sb.from('expenses').select('id', { count: 'exact', head: true }).is('bucket', null)
  check('tidak ada expenses.bucket NULL', (nulls.count || 0) === 0, `-> ${nulls.count} tersisa`)

  const owner = await sb.from('users').select('id, name, phone, can_access_finance').eq('phone', OWNER_PHONE).maybeSingle()
  check('akun pemilik ditemukan', !!owner.data, '-> ' + OWNER_PHONE)
  if (owner.data) {
    console.log(`   ${owner.data.name} (${owner.data.phone}) akses keuangan: ${owner.data.can_access_finance}`)
  }

  const others = await sb.from('users').select('phone, name').eq('can_access_finance', true).neq('phone', OWNER_PHONE)
  check('tidak ada akun lain yang punya akses', (others.data || []).length === 0,
    '-> ' + JSON.stringify(others.data))

  process.exit(ok ? 0 : 1)
})()
```

- [ ] **Step 4: Jalankan verifikasi**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend" && node src/db/verify-016.js
```

Expected: semua ✅ **kecuali** "akun pemilik" akan menunjukkan `akses keuangan: false` (belum di-seed). Itu benar untuk langkah ini.

- [ ] **Step 5: Seed akses pemilik di Supabase SQL Editor**

```sql
UPDATE users SET can_access_finance = true
WHERE id = '649a989c-e9c2-45d4-815d-f95b7df158bc';
```

Expected: `Success. 1 row affected`.

- [ ] **Step 6: Verifikasi ulang**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend" && node src/db/verify-016.js
```

Expected: semua ✅, dan baris pemilik menunjukkan `akses keuangan: true`. Exit code 0.

- [ ] **Step 7: Commit**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend"
git add src/db/migrations/016_add_finance_module.sql src/db/verify-016.js
git commit -m "feat(db): migrasi 016 modul keuangan + verifikasi

4 tabel baru (finance_settings, fixed_costs, finance_ledger,
finance_calibration) + kolom expenses.bucket & users.can_access_finance.
Backfill 124 expenses lama ke bucket restock.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 3: Middleware `requireFinanceAccess` + router keuangan

Ini batas keamanan yang sesungguhnya. Dikerjakan **sebelum** layar apa pun.

**Repo:** `D:\REHAT\rehat-backend\rehat-backend`

**Files:**
- Modify: `src/middleware/auth.js` (tambah export baru, jangan ubah yang ada)
- Create: `src/routes/finance.js`
- Modify: `src/routes/index.js` (mount router)
- Test: `src/middleware/__tests__/financeAccess.test.js`

**Interfaces:**
- Consumes: `users.can_access_finance` (Task 2)
- Produces:
  ```js
  // src/middleware/auth.js
  requireFinanceAccess(req, res, next)  // 401 tanpa token; 404 bila flag false
  // src/routes/finance.js
  module.exports = router   // Express router, di-mount di /admin/finance
  ```

**Kenapa 404 dan bukan 403:** 403 memberi tahu admin lain bahwa modul ini ada. 404 tidak membocorkan apa pun.

**Kenapa `adminAccess` tidak dipakai:** `adminAccess` di `src/middleware/auth.js:82` memberi jalan pintas lewat header `x-admin-key` **tanpa user sama sekali** — `req.user` jadi `undefined`, sehingga flag tidak bisa diperiksa. Modul keuangan wajib punya user JWT.

- [ ] **Step 1: Tulis test yang gagal**

Buat `src/middleware/__tests__/financeAccess.test.js`:

```js
const { requireFinanceAccess } = require('../auth')

// Helper: bikin res palsu yang merekam status & body.
const mockRes = () => {
  const res = {}
  res.statusCode = null
  res.body = null
  res.status = (c) => { res.statusCode = c; return res }
  res.json = (b) => { res.body = b; return res }
  return res
}

describe('requireFinanceAccess', () => {
  test('meneruskan user dengan can_access_finance = true', () => {
    const req = { user: { id: 'u1', role: 'admin', can_access_finance: true } }
    const res = mockRes()
    let called = false
    requireFinanceAccess(req, res, () => { called = true })
    expect(called).toBe(true)
    expect(res.statusCode).toBeNull()
  })

  test('menolak admin lain dengan 404, bukan 403', () => {
    const req = { user: { id: 'u2', role: 'admin', can_access_finance: false } }
    const res = mockRes()
    let called = false
    requireFinanceAccess(req, res, () => { called = true })
    expect(called).toBe(false)
    expect(res.statusCode).toBe(404)
    expect(res.body.success).toBe(false)
  })

  test('flag tidak ada (migrasi belum jalan) diperlakukan sebagai TIDAK boleh', () => {
    const req = { user: { id: 'u3', role: 'admin' } }
    const res = mockRes()
    requireFinanceAccess(req, res, () => {})
    expect(res.statusCode).toBe(404)
  })

  test('tanpa user (mis. lolos lewat x-admin-key) ditolak 401', () => {
    const req = {}
    const res = mockRes()
    requireFinanceAccess(req, res, () => {})
    expect(res.statusCode).toBe(401)
  })

  test('pesan error tidak menyebut keuangan (tidak membocorkan modul)', () => {
    const req = { user: { id: 'u2', can_access_finance: false } }
    const res = mockRes()
    requireFinanceAccess(req, res, () => {})
    expect(JSON.stringify(res.body).toLowerCase()).not.toContain('keuangan')
    expect(JSON.stringify(res.body).toLowerCase()).not.toContain('finance')
  })
})
```

- [ ] **Step 2: Jalankan test — pastikan GAGAL**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend" && npx jest financeAccess
```

Expected: FAIL — `requireFinanceAccess is not a function`.

- [ ] **Step 3: Implementasi middleware**

Di `src/middleware/auth.js`, tambahkan **sebelum** baris `module.exports`:

```js
// Akses modul keuangan: HANYA pemilik (kolom users.can_access_finance).
// Lebih ketat dari adminOnly -- modul ini menampilkan penghasilan pribadi,
// jadi admin/kasir lain tidak boleh melihatnya.
//
// Menolak dengan 404 (bukan 403) supaya keberadaan modul tidak bocor.
// Sengaja TIDAK memakai adminAccess: jalur `x-admin-key` melewati JWT
// sehingga req.user kosong dan flag tak bisa diperiksa.
const requireFinanceAccess = (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({
      success: false,
      error: { code: 'MISSING_TOKEN', message: 'Authorization token diperlukan' },
    })
  }
  if (req.user.can_access_finance !== true) {
    return res.status(404).json({
      success: false,
      error: { code: 'NOT_FOUND', message: 'Endpoint tidak ditemukan' },
    })
  }
  next()
}
```

Lalu ubah baris terakhir menjadi:

```js
module.exports = { authenticate, adminOnly, adminKey, adminAccess, requireFinanceAccess }
```

- [ ] **Step 4: Jalankan test — pastikan LULUS**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend" && npx jest financeAccess
```

Expected: PASS, 5 test.

- [ ] **Step 5: Buat router keuangan**

Buat `src/routes/finance.js`:

```js
// Router modul keuangan. SEMUA route di file ini sudah berada di balik
// authenticate + requireFinanceAccess (dipasang saat mount di index.js),
// jadi tidak perlu mengulang guard per-route.
//
// Dipisah dari routes/index.js yang sudah >1200 baris.
const express = require('express')
const { success } = require('../middleware/response')

const router = express.Router()

// Ping internal: dipakai frontend untuk mengecek apakah akun punya akses.
router.get('/ping', (req, res) => success(res, { ok: true }))

module.exports = router
```

- [ ] **Step 6: Mount router di `src/routes/index.js`**

Tambahkan di baris impor teratas (dekat `const { authenticate, adminAccess } = require('../middleware/auth')`):

```js
const { requireFinanceAccess } = require('../middleware/auth')
const financeRouter = require('./finance')
```

Lalu tambahkan mount **sebelum** `module.exports = router` di akhir file:

```js
// Modul keuangan — khusus pemilik. authenticate dulu (mengisi req.user),
// baru requireFinanceAccess memeriksa flag.
router.use('/admin/finance', authenticate, requireFinanceAccess, financeRouter)
```

- [ ] **Step 7: Uji manual terhadap server lokal**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend" && npm run dev
```

Di terminal lain, uji tanpa token:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/v1/admin/finance/ping
```

Expected: `401`.

- [ ] **Step 8: Commit**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend"
git add src/middleware/auth.js src/middleware/__tests__/financeAccess.test.js src/routes/finance.js src/routes/index.js
git commit -m "feat(finance): middleware requireFinanceAccess + router terpisah

Hanya akun dgn users.can_access_finance = true yang bisa masuk.
Menolak 404 bukan 403 supaya keberadaan modul tidak bocor ke admin lain.
Tidak memakai adminAccess karena jalur x-admin-key melewati JWT.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 4: CRUD biaya tetap

**Repo:** `D:\REHAT\rehat-backend\rehat-backend`

**Files:**
- Create: `src/services/financeService.js`
- Modify: `src/routes/finance.js`
- Test: `src/services/__tests__/financeCalc.test.js` (tambah describe baru untuk `sumFixedCosts`)

**Interfaces:**
- Consumes: tabel `fixed_costs` (Task 2), `computePnl` (Task 1)
- Produces:
  ```js
  // src/services/financeService.js
  listFixedCosts()                          // => [{id,name,amount,category,due_day,is_active}]
  createFixedCost({ name, amount, category, dueDay })  // => row
  deleteFixedCost(id)                       // => void
  sumFixedCosts(rows)                       // MURNI: => int total yang is_active
  ```

- [ ] **Step 1: Tulis test yang gagal untuk fungsi murni**

Tambahkan di akhir `src/services/__tests__/financeCalc.test.js`:

```js
const { sumFixedCosts } = require('../financeService')

describe('sumFixedCosts', () => {
  test('menjumlah hanya yang aktif', () => {
    expect(sumFixedCosts([
      { amount: 3000000, is_active: true },
      { amount: 4000000, is_active: true },
      { amount: 9000000, is_active: false },
    ])).toBe(7000000)
  })

  test('daftar kosong / null => 0', () => {
    expect(sumFixedCosts([])).toBe(0)
    expect(sumFixedCosts(null)).toBe(0)
  })

  test('nominal non-numerik diabaikan, tidak NaN', () => {
    expect(sumFixedCosts([{ amount: 'x', is_active: true }, { amount: 5000, is_active: true }])).toBe(5000)
  })
})
```

- [ ] **Step 2: Jalankan test — pastikan GAGAL**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend" && npx jest financeCalc
```

Expected: FAIL — `Cannot find module '../financeService'`.

- [ ] **Step 3: Implementasi service**

Buat `src/services/financeService.js`:

```js
const { supabaseAdmin } = require('../config/supabase')
const { AppError } = require('../middleware/response')

const int = (v) => {
  const n = Number(v)
  return Number.isFinite(n) ? Math.round(n) : 0
}

// MURNI: total biaya tetap yang aktif. Dipisah agar bisa diuji tanpa DB.
const sumFixedCosts = (rows) =>
  (rows || []).reduce((s, r) => s + (r?.is_active ? int(r.amount) : 0), 0)

const listFixedCosts = async () => {
  const { data, error } = await supabaseAdmin
    .from('fixed_costs')
    .select('id, name, amount, category, due_day, is_active')
    .order('amount', { ascending: false })
  if (error) throw new AppError('FIXED_COSTS_FETCH_FAILED', error.message, 500)
  return data || []
}

const createFixedCost = async ({ name, amount, category = null, dueDay = null }) => {
  const row = {
    name: String(name).trim().slice(0, 80),
    amount: Math.max(0, int(amount)),
    category: category ? String(category).trim().slice(0, 60) : null,
    due_day: dueDay == null ? null : Math.min(31, Math.max(1, int(dueDay))),
  }
  const { data, error } = await supabaseAdmin.from('fixed_costs').insert(row).select('*').single()
  if (error) throw new AppError('FIXED_COST_CREATE_FAILED', error.message, 500)
  return data
}

const deleteFixedCost = async (id) => {
  const { error } = await supabaseAdmin.from('fixed_costs').delete().eq('id', id)
  if (error) throw new AppError('FIXED_COST_DELETE_FAILED', error.message, 500)
}

module.exports = { sumFixedCosts, listFixedCosts, createFixedCost, deleteFixedCost }
```

- [ ] **Step 4: Jalankan test — pastikan LULUS**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend" && npx jest financeCalc
```

Expected: PASS, 10 test.

- [ ] **Step 5: Tambah route**

Di `src/routes/finance.js`, ganti seluruh isi menjadi:

```js
// Router modul keuangan. SEMUA route di file ini sudah berada di balik
// authenticate + requireFinanceAccess (dipasang saat mount di index.js),
// jadi tidak perlu mengulang guard per-route.
const express = require('express')
const { z } = require('zod')
const { success, created } = require('../middleware/response')
const financeService = require('../services/financeService')

const router = express.Router()

router.get('/ping', (req, res) => success(res, { ok: true }))

const fixedCostSchema = z.object({
  name: z.string().min(1, 'Nama biaya wajib diisi').max(80),
  amount: z.number().int().min(0),
  category: z.string().max(60).optional().nullable(),
  due_day: z.number().int().min(1).max(31).optional().nullable(),
})

router.get('/fixed-costs', async (req, res, next) => {
  try {
    const items = await financeService.listFixedCosts()
    return success(res, { items, total: financeService.sumFixedCosts(items) })
  } catch (err) { next(err) }
})

router.post('/fixed-costs', async (req, res, next) => {
  try {
    const b = fixedCostSchema.parse(req.body)
    const data = await financeService.createFixedCost({
      name: b.name, amount: b.amount, category: b.category, dueDay: b.due_day,
    })
    return created(res, data, 'Biaya tetap disimpan')
  } catch (err) { next(err) }
})

router.delete('/fixed-costs/:id', async (req, res, next) => {
  try {
    await financeService.deleteFixedCost(req.params.id)
    return success(res, { deleted: true }, 'Biaya tetap dihapus')
  } catch (err) { next(err) }
})

module.exports = router
```

- [ ] **Step 6: Seed biaya tetap Rp8jt**

Di Supabase SQL Editor:

```sql
INSERT INTO fixed_costs (name, amount, category, is_active)
SELECT 'Biaya tetap bulanan', 8000000, 'umum', true
WHERE NOT EXISTS (SELECT 1 FROM fixed_costs);
```

Expected: `Success. 1 row affected`. Pemilik memecahnya sendiri belakangan lewat layar Biaya Tetap.

- [ ] **Step 7: Commit**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend"
git add src/services/financeService.js src/services/__tests__/financeCalc.test.js src/routes/finance.js
git commit -m "feat(finance): CRUD biaya tetap bulanan

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 5: Kategorisasi pengeluaran (`expenses.bucket`)

Inilah yang memisahkan restock dari biaya lain — prasyarat perbaikan double-counting.

**Repo:** `D:\REHAT\rehat-backend\rehat-backend`

**Files:**
- Modify: `src/services/expenseService.js`
- Modify: `src/routes/index.js:628-646` (schema + handler expenses)
- Test: `src/services/__tests__/expenseBucket.test.js`

**Interfaces:**
- Consumes: kolom `expenses.bucket` (Task 2)
- Produces:
  ```js
  // src/services/expenseService.js — tambahan
  splitByBucket(rows)   // MURNI: => { restock: int, nonRestock: int, total: int }
  sumNonRestockBetween(startIso, endIso)  // => int
  // createExpense/listExpenses kini menerima & mengembalikan `bucket`
  ```

- [ ] **Step 1: Tulis test yang gagal**

Buat `src/services/__tests__/expenseBucket.test.js`:

```js
const { splitByBucket } = require('../expenseService')

describe('splitByBucket', () => {
  test('memisahkan restock dari pos lain', () => {
    const r = splitByBucket([
      { amount: 60000, bucket: 'restock' },   // SKM
      { amount: 49000, bucket: 'restock' },   // es batu
      { amount: 52000, bucket: 'operational' }, // token listrik
    ])
    expect(r.restock).toBe(109000)
    expect(r.nonRestock).toBe(52000)
    expect(r.total).toBe(161000)
  })

  test('bucket null dianggap restock (sesuai backfill migrasi 016)', () => {
    const r = splitByBucket([{ amount: 30000, bucket: null }])
    expect(r.restock).toBe(30000)
    expect(r.nonRestock).toBe(0)
  })

  test('daftar kosong / null => semua 0', () => {
    expect(splitByBucket([])).toEqual({ restock: 0, nonRestock: 0, total: 0 })
    expect(splitByBucket(null)).toEqual({ restock: 0, nonRestock: 0, total: 0 })
  })

  test('nominal non-numerik diabaikan, tidak NaN', () => {
    const r = splitByBucket([{ amount: 'x', bucket: 'restock' }, { amount: 1000, bucket: 'restock' }])
    expect(r.restock).toBe(1000)
  })
})
```

- [ ] **Step 2: Jalankan test — pastikan GAGAL**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend" && npx jest expenseBucket
```

Expected: FAIL — `splitByBucket is not a function`.

- [ ] **Step 3: Tambah fungsi murni + query defensif di `expenseService.js`**

Tambahkan **sebelum** `module.exports`:

```js
const intAmt = (v) => {
  const n = Number(v)
  return Number.isFinite(n) ? Math.round(n) : 0
}

// MURNI: pisahkan pengeluaran restock dari pos lain.
// `bucket` null diperlakukan restock — sesuai backfill migrasi 016 dan
// karena isi historis tabel ini memang seluruhnya bahan.
const splitByBucket = (rows) => {
  let restock = 0
  let nonRestock = 0
  for (const r of rows || []) {
    const a = intAmt(r?.amount)
    if (!r?.bucket || r.bucket === 'restock') restock += a
    else nonRestock += a
  }
  return { restock, nonRestock, total: restock + nonRestock }
}

// Total pengeluaran NON-restock dalam rentang — dipakai P&L supaya restock
// tidak dipotong dua kali (sudah ada di HPP).
// Defensif: bila kolom `bucket` belum ada (migrasi 016 tertinggal), kembalikan
// 0 daripada meledak — laporan boleh kurang detail, tapi tidak boleh error.
const sumNonRestockBetween = async (startIso, endIso) => {
  try {
    const { data, error } = await supabaseAdmin
      .from('expenses')
      .select('amount, bucket')
      .gte('spent_at', startIso)
      .lte('spent_at', endIso)
    if (error) return 0
    return splitByBucket(data).nonRestock
  } catch (_) {
    return 0
  }
}
```

Ubah baris `module.exports` menjadi:

```js
module.exports = {
  createExpense, listExpenses, deleteExpense, sumBetween, rangeBounds,
  splitByBucket, sumNonRestockBetween,
}
```

- [ ] **Step 4: Jalankan test — pastikan LULUS**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend" && npx jest expenseBucket
```

Expected: PASS, 4 test.

- [ ] **Step 5: Terima & kembalikan `bucket` di createExpense/listExpenses**

Di `src/services/expenseService.js`, ubah `createExpense` — tambahkan `bucket` ke parameter dan row:

```js
const createExpense = async ({ amount, note = null, category = null, spentAt = null, createdBy = null, bucket = 'restock' }) => {
  const VALID = ['restock', 'operational', 'personal', 'scaling', 'emergency']
  const row = {
    amount: Math.max(0, Math.round(Number(amount) || 0)),
    note: note ? String(note).slice(0, 200) : null,
    category: category ? String(category).slice(0, 60) : null,
    created_by: createdBy,
    bucket: VALID.includes(bucket) ? bucket : 'restock',
  }
  if (spentAt) row.spent_at = spentAt
  let { data, error } = await supabaseAdmin.from('expenses').insert(row).select('*').single()
  // Defensif: bila kolom `bucket` belum ada, ulangi tanpa kolom itu.
  if (error && /bucket/i.test(error.message || '')) {
    const { bucket: _drop, ...fallback } = row
    ;({ data, error } = await supabaseAdmin.from('expenses').insert(fallback).select('*').single())
  }
  if (error) throw new AppError('EXPENSE_CREATE_FAILED', error.message, 500)
  return data
}
```

Ubah `listExpenses` agar ikut memilih `bucket` dan mengembalikan pecahannya:

```js
const listExpenses = async ({ range = '7d', date = null } = {}) => {
  const [start, end] = rangeBounds(range, date)
  const cols = 'id, amount, note, category, spent_at, bucket'
  let { data, error } = await supabaseAdmin
    .from('expenses').select(cols)
    .gte('spent_at', start).lte('spent_at', end)
    .order('spent_at', { ascending: false })
  // Defensif: kolom `bucket` belum ada -> ulangi tanpa kolom itu.
  if (error && /bucket/i.test(error.message || '')) {
    ;({ data, error } = await supabaseAdmin
      .from('expenses').select('id, amount, note, category, spent_at')
      .gte('spent_at', start).lte('spent_at', end)
      .order('spent_at', { ascending: false }))
  }
  if (error) throw new AppError('EXPENSES_FETCH_FAILED', error.message, 500)
  const items = data || []
  const split = splitByBucket(items)
  return { items, total: split.total, restock: split.restock, non_restock: split.nonRestock }
}
```

- [ ] **Step 6: Terima `bucket` di route**

Di `src/routes/index.js`, cari `expenseSchema` (dekat baris 620) dan tambahkan field:

```js
  bucket: z.enum(['restock', 'operational', 'personal', 'scaling', 'emergency']).optional(),
```

Lalu di handler `POST /admin/expenses` (baris ~631), teruskan nilainya:

```js
    const data = await expenseService.createExpense({
      amount: b.amount, note: b.note, category: b.category,
      spentAt: b.spent_at || null, createdBy: req.user?.id || null,
      bucket: b.bucket || 'restock',
    })
```

- [ ] **Step 7: Jalankan seluruh test**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend" && npx jest
```

Expected: PASS, 14 test.

- [ ] **Step 8: Commit**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend"
git add src/services/expenseService.js src/services/__tests__/expenseBucket.test.js src/routes/index.js
git commit -m "feat(finance): kategorisasi pengeluaran per pos

splitByBucket memisahkan restock dari biaya lain. sumNonRestockBetween
dipakai P&L supaya restock tidak dipotong dua kali (sudah di HPP).
Query defensif: kolom bucket belum ada -> fallback tanpa kolom.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 6: Endpoint Laporan Laba Rugi

Menyambung Task 1, 4, dan 5 menjadi satu endpoint.

**Repo:** `D:\REHAT\rehat-backend\rehat-backend`

**Files:**
- Modify: `src/services/financeService.js` (tambah `getMonthlyPnl`)
- Modify: `src/routes/finance.js` (tambah route)

**Interfaces:**
- Consumes: `computePnl` (Task 1), `sumFixedCosts`/`listFixedCosts` (Task 4), `sumNonRestockBetween` (Task 5), `orderService.getSalesReport`
- Produces:
  ```js
  getMonthlyPnl('YYYY-MM')
  // => { month, revenue, cogs, grossProfit, grossMarginPct, fixedCosts,
  //      variableExpenses, paymentFees, netProfit, netMarginPct,
  //      fixed_cost_items: [...] }
  ```

- [ ] **Step 1: Pahami apa yang sudah ada di `orderService.js` (sudah diverifikasi)**

Fakta yang sudah dipastikan — tidak perlu dicek ulang:

| Simbol | Lokasi | Status |
|---|---|---|
| `SOLD_STATUSES = ['paid','processing','ready','completed']` | `orderService.js:603` | const lokal, **tidak** di-export |
| `wibDateKey` / `wibDayRange` / `wibStartOfDaysAgo` | `orderService.js:613–623` | const lokal, **tidak** di-export |
| `module.exports` | `orderService.js:1220` | memuat `getSalesReport`, `getClosingReport`, `getAnalytics`, `ORDER_STATUSES`, dll. |

Karena `getSalesReportBetween` ditulis **di dalam** `orderService.js`, ia bisa memakai `SOLD_STATUSES` dan `supabaseAdmin` langsung tanpa export tambahan. Yang perlu ditambahkan ke `module.exports` hanya `getSalesReportBetween` itu sendiri.

- [ ] **Step 2: Implementasi `getMonthlyPnl`**

Di `src/services/financeService.js`, tambahkan impor di atas:

```js
const { computePnl } = require('./financeCalc')
const expenseService = require('./expenseService')
const orderService = require('./orderService')
```

dan tambahkan sebelum `module.exports`:

```js
// Batas bulan dalam WIB: [awal 1 hb 00:00 WIB, akhir hb terakhir 23:59:59 WIB]
// dinyatakan dalam ISO UTC. WIB = UTC+7, jadi 00:00 WIB = 17:00 UTC hari sebelumnya.
const wibMonthBounds = (month) => {
  const [y, m] = month.split('-').map(Number)
  const startUtc = new Date(Date.UTC(y, m - 1, 1, 0, 0, 0) - 7 * 3600 * 1000)
  const endUtc = new Date(Date.UTC(y, m, 1, 0, 0, 0) - 7 * 3600 * 1000 - 1)
  return [startUtc.toISOString(), endUtc.toISOString()]
}

/** Laba rugi satu bulan (YYYY-MM), semua batas hari WIB. */
const getMonthlyPnl = async (month) => {
  const [startIso, endIso] = wibMonthBounds(month)

  const [sales, fixedRows, variableExpenses] = await Promise.all([
    orderService.getSalesReportBetween(startIso, endIso),
    listFixedCosts(),
    expenseService.sumNonRestockBetween(startIso, endIso),
  ])

  const pnl = computePnl({
    revenue: sales.revenue,
    cogs: sales.cogs,
    fixedCosts: sumFixedCosts(fixedRows),
    variableExpenses,
    qrisRevenue: sales.qrisRevenue,
    qrisFeePct: Number(process.env.DOKU_QRIS_FEE_PCT || 0.7),
  })

  return { month, ...pnl, fixed_cost_items: fixedRows.filter((r) => r.is_active) }
}
```

- [ ] **Step 3: Sediakan `getSalesReportBetween` di `orderService.js`**

`getSalesReport` hanya menerima `range`/`date`, bukan rentang bebas. Tambahkan helper yang mengembalikan tiga angka yang dibutuhkan P&L, memakai logika HPP yang sudah ada.

Di `src/services/orderService.js`, tambahkan sebelum `module.exports`:

```js
// Omzet, HPP, dan omzet QRIS untuk rentang ISO bebas — dipakai laporan
// laba rugi bulanan. Memakai SOLD_STATUSES yang sama dengan getSalesReport
// supaya definisi "terjual" konsisten di seluruh sistem.
const getSalesReportBetween = async (startIso, endIso) => {
  const { data: orders, error } = await supabaseAdmin
    .from('orders')
    .select('id, total, payment_method')
    .in('status', SOLD_STATUSES)
    .gte('ordered_at', startIso)
    .lte('ordered_at', endIso)
  if (error) throw new AppError('SALES_FETCH_FAILED', error.message, 500)

  const rows = orders || []
  const revenue = rows.reduce((s, o) => s + (Number(o.total) || 0), 0)
  const qrisRevenue = rows
    .filter((o) => o.payment_method === 'qris')
    .reduce((s, o) => s + (Number(o.total) || 0), 0)

  // HPP: ambil item milik pesanan tsb. Paginasi wajib — PostgREST membatasi
  // 1000 baris per permintaan, dan tanpa ini HPP diam-diam terpotong.
  const ids = rows.map((o) => o.id)
  let cogs = 0
  for (let i = 0; i < ids.length; i += 200) {
    const chunk = ids.slice(i, i + 200)
    if (!chunk.length) break
    let from = 0
    for (;;) {
      const { data: items } = await supabaseAdmin
        .from('order_items')
        .select('quantity, menu_items(cost_price)')
        .in('order_id', chunk)
        .range(from, from + 999)
      const batch = items || []
      for (const it of batch) {
        cogs += (Number(it.menu_items?.cost_price) || 0) * (Number(it.quantity) || 0)
      }
      if (batch.length < 1000) break
      from += 1000
    }
  }

  return { revenue, cogs, qrisRevenue, orders: rows.length }
}
```

Lalu ubah `module.exports` di `orderService.js:1220` — tambahkan `getSalesReportBetween` ke daftar (setelah `getSalesReport`):

```js
  validateVoucher, awardPointsAndStamp, updateOrderStatus, refundOrder, getSalesReport, getSalesReportBetween, getSalesCalendar, getClosingReport, getAnalytics, ORDER_STATUSES,
```

- [ ] **Step 4: Tambah route P&L**

Di `src/routes/finance.js`, tambahkan sebelum `module.exports`:

```js
router.get('/pnl', async (req, res, next) => {
  try {
    const month = /^\d{4}-\d{2}$/.test(req.query.month || '')
      ? req.query.month
      : new Date(Date.now() + 7 * 3600 * 1000).toISOString().slice(0, 7) // bulan berjalan WIB
    const data = await financeService.getMonthlyPnl(month)
    return success(res, data)
  } catch (err) { next(err) }
})
```

- [ ] **Step 5: Uji terhadap data produksi**

Jalankan server (`npm run dev`), ambil token pemilik lewat login, lalu:

```bash
curl -s -H "Authorization: Bearer <TOKEN_IRURR>" \
  "http://localhost:3000/v1/admin/finance/pnl?month=2026-07" | node -e "
let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{
const d=JSON.parse(s).data;
const rp=n=>'Rp'+Number(n).toLocaleString('id-ID');
console.log('omzet      ',rp(d.revenue));
console.log('HPP        ',rp(d.cogs));
console.log('laba kotor ',rp(d.grossProfit),d.grossMarginPct+'%');
console.log('biaya tetap',rp(d.fixedCosts));
console.log('variabel   ',rp(d.variableExpenses));
console.log('fee QRIS   ',rp(d.paymentFees));
console.log('LABA BERSIH',rp(d.netProfit),d.netMarginPct+'%');})"
```

Expected untuk Juli 2026: omzet ≈ Rp15.055.400, margin kotor ≈ 58–59%, biaya tetap Rp8.000.000. **Periksa kewarasan:** `variableExpenses` harus jauh lebih kecil dari total pengeluaran Juli (Rp1.420.000), karena hampir semuanya restock. Bila `variableExpenses` ≈ Rp1.420.000, berarti backfill bucket gagal — kembali ke Task 2.

- [ ] **Step 6: Uji kontrol akses dengan token admin lain**

```bash
curl -s -o /dev/null -w "%{http_code}\n" -H "Authorization: Bearer <TOKEN_IRUR>" \
  "http://localhost:3000/v1/admin/finance/pnl?month=2026-07"
```

Expected: `404`. Bila `200`, **hentikan** — kontrol akses bocor.

- [ ] **Step 7: Commit**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend"
git add src/services/financeService.js src/services/orderService.js src/routes/finance.js
git commit -m "feat(finance): endpoint laba rugi bulanan

Restock tidak lagi dipotong dua kali: variableExpenses hanya berisi
pengeluaran non-restock. Batas bulan WIB. Paginasi order_items supaya
HPP tidak terpotong di 1000 baris.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 7: Repository & model Flutter

**Repo:** `c:\Users\thezu\rehat_app`

**Files:**
- Create: `lib/features/finance/data/finance_repository.dart`
- Modify: `lib/core/constants/api_constants.dart`
- Test: `test/finance_models_test.dart`

**Interfaces:**
- Consumes: endpoint `/admin/finance/{ping,fixed-costs,pnl}` (Task 3–6)
- Produces:
  ```dart
  class FixedCost { String id; String name; int amount; String category; int? dueDay; bool isActive; }
  class ProfitLoss { String month; int revenue, cogs, grossProfit, fixedCosts,
                     variableExpenses, paymentFees, netProfit;
                     int grossMarginPct, netMarginPct; List<FixedCost> fixedCostItems; }
  class FinanceRepository { fetchFixedCosts(); addFixedCost(); deleteFixedCost(); fetchPnl(); hasAccess(); }
  final financeRepositoryProvider, fixedCostsProvider, pnlMonthProvider, pnlProvider, financeAccessProvider
  ```

- [ ] **Step 1: Tambah konstanta endpoint**

Di `lib/core/constants/api_constants.dart`, tambahkan di dalam class:

```dart
  static const String financePing = '/admin/finance/ping';
  static const String financeFixedCosts = '/admin/finance/fixed-costs';
  static String financeFixedCost(String id) => '/admin/finance/fixed-costs/$id';
  static const String financePnl = '/admin/finance/pnl';
```

- [ ] **Step 2: Tulis test yang gagal**

Buat `test/finance_models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/features/finance/data/finance_repository.dart';

/// Menguji parsing model keuangan: tahan nilai null, string angka, dan
/// field yang belum dikirim backend.

void main() {
  group('FixedCost.fromJson', () {
    test('membaca field lengkap', () {
      final c = FixedCost.fromJson({
        'id': 'a1', 'name': 'Sewa', 'amount': 3000000,
        'category': 'tempat', 'due_day': 5, 'is_active': true,
      });
      expect(c.id, 'a1');
      expect(c.name, 'Sewa');
      expect(c.amount, 3000000);
      expect(c.dueDay, 5);
      expect(c.isActive, isTrue);
    });

    test('nilai null tidak bikin crash', () {
      final c = FixedCost.fromJson({'id': 'a1', 'name': 'X', 'amount': null});
      expect(c.amount, 0);
      expect(c.category, '');
      expect(c.dueDay, isNull);
      expect(c.isActive, isTrue); // default aktif
    });

    test('amount berupa string angka tetap terbaca', () {
      expect(FixedCost.fromJson({'id': 'a', 'name': 'X', 'amount': '250000'}).amount, 250000);
    });
  });

  group('ProfitLoss.fromJson', () {
    test('membaca ringkasan laba rugi', () {
      final p = ProfitLoss.fromJson({
        'month': '2026-08',
        'revenue': 36000000, 'cogs': 14902271,
        'grossProfit': 21097729, 'grossMarginPct': 59,
        'fixedCosts': 8000000, 'variableExpenses': 500000,
        'paymentFees': 100800, 'netProfit': 12496929, 'netMarginPct': 35,
        'fixed_cost_items': [
          {'id': 'f1', 'name': 'Sewa', 'amount': 8000000, 'is_active': true},
        ],
      });
      expect(p.month, '2026-08');
      expect(p.revenue, 36000000);
      expect(p.netProfit, 12496929);
      expect(p.fixedCostItems.length, 1);
      expect(p.fixedCostItems.first.name, 'Sewa');
    });

    test('laba bersih negatif terbaca apa adanya', () {
      final p = ProfitLoss.fromJson({'month': '2026-01', 'netProfit': -400000, 'netMarginPct': -40});
      expect(p.netProfit, -400000);
      expect(p.netMarginPct, -40);
    });

    test('respons kosong menghasilkan nol, bukan exception', () {
      final p = ProfitLoss.fromJson(const {});
      expect(p.revenue, 0);
      expect(p.netProfit, 0);
      expect(p.fixedCostItems, isEmpty);
    });
  });
}
```

- [ ] **Step 3: Jalankan test — pastikan GAGAL**

```bash
C:\Users\thezu\flutter\bin\flutter.bat test test/finance_models_test.dart
```

Expected: FAIL — file `finance_repository.dart` tidak ada.

- [ ] **Step 4: Implementasi repository**

Buat `lib/features/finance/data/finance_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/formatters.dart';

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

/// Satu pos biaya tetap bulanan (sewa, gaji, listrik…).
class FixedCost {
  const FixedCost({
    required this.id,
    required this.name,
    required this.amount,
    this.category = '',
    this.dueDay,
    this.isActive = true,
  });

  final String id;
  final String name;
  final int amount;
  final String category;
  final int? dueDay;
  final bool isActive;

  factory FixedCost.fromJson(Map<String, dynamic> j) => FixedCost(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        amount: _int(j['amount']),
        category: (j['category'] ?? '').toString(),
        dueDay: j['due_day'] == null ? null : _int(j['due_day']),
        isActive: j['is_active'] == null ? true : j['is_active'] == true,
      );
}

/// Laporan laba rugi satu bulan.
class ProfitLoss {
  const ProfitLoss({
    required this.month,
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    required this.grossMarginPct,
    required this.fixedCosts,
    required this.variableExpenses,
    required this.paymentFees,
    required this.netProfit,
    required this.netMarginPct,
    required this.fixedCostItems,
  });

  final String month;
  final int revenue;
  final int cogs;
  final int grossProfit;
  final int grossMarginPct;
  final int fixedCosts;
  final int variableExpenses;
  final int paymentFees;
  final int netProfit;
  final int netMarginPct;
  final List<FixedCost> fixedCostItems;

  factory ProfitLoss.fromJson(Map<String, dynamic> j) => ProfitLoss(
        month: (j['month'] ?? '').toString(),
        revenue: _int(j['revenue']),
        cogs: _int(j['cogs']),
        grossProfit: _int(j['grossProfit']),
        grossMarginPct: _int(j['grossMarginPct']),
        fixedCosts: _int(j['fixedCosts']),
        variableExpenses: _int(j['variableExpenses']),
        paymentFees: _int(j['paymentFees']),
        netProfit: _int(j['netProfit']),
        netMarginPct: _int(j['netMarginPct']),
        fixedCostItems: ((j['fixed_cost_items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => FixedCost.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

Map<String, dynamic> _unwrap(dynamic body) => (body is Map && body['data'] is Map)
    ? Map<String, dynamic>.from(body['data'] as Map)
    : Map<String, dynamic>.from(body as Map);

/// Akses modul keuangan (khusus pemilik). Endpoint membalas 404 untuk akun
/// lain, jadi kegagalan apa pun diperlakukan sebagai "tidak punya akses".
class FinanceRepository {
  FinanceRepository({required DioClient client}) : _client = client;
  final DioClient _client;

  Future<bool> hasAccess() async {
    try {
      await _client.get<dynamic>(ApiConstants.financePing);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<FixedCost>> fetchFixedCosts() async {
    final res = await _client.get<dynamic>(ApiConstants.financeFixedCosts);
    final data = _unwrap(res.data);
    return ((data['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => FixedCost.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> addFixedCost({
    required String name,
    required int amount,
    String? category,
    int? dueDay,
  }) async {
    await _client.post<dynamic>(ApiConstants.financeFixedCosts, data: {
      'name': name.trim(),
      'amount': amount,
      if (category != null && category.trim().isNotEmpty) 'category': category.trim(),
      if (dueDay != null) 'due_day': dueDay,
    });
  }

  Future<void> deleteFixedCost(String id) async {
    await _client.delete<dynamic>(ApiConstants.financeFixedCost(id));
  }

  Future<ProfitLoss> fetchPnl(String month) async {
    final res = await _client.get<dynamic>(
      ApiConstants.financePnl,
      query: {'month': month},
    );
    return ProfitLoss.fromJson(_unwrap(res.data));
  }
}

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(client: ref.watch(dioClientProvider));
});

/// Apakah akun yang login boleh membuka modul keuangan.
final financeAccessProvider = FutureProvider<bool>((ref) {
  return ref.watch(financeRepositoryProvider).hasAccess();
});

final fixedCostsProvider = FutureProvider<List<FixedCost>>((ref) {
  return ref.watch(financeRepositoryProvider).fetchFixedCosts();
});

/// Bulan aktif laporan laba rugi (default: bulan berjalan menurut WIB).
final pnlMonthProvider = StateProvider<DateTime>((ref) {
  final now = Formatters.toWib(DateTime.now());
  return DateTime(now.year, now.month);
});

final pnlProvider = FutureProvider<ProfitLoss>((ref) {
  final m = ref.watch(pnlMonthProvider);
  final month =
      '${m.year.toString().padLeft(4, '0')}-${m.month.toString().padLeft(2, '0')}';
  return ref.watch(financeRepositoryProvider).fetchPnl(month);
});
```

- [ ] **Step 5: Jalankan test — pastikan LULUS**

```bash
C:\Users\thezu\flutter\bin\flutter.bat test test/finance_models_test.dart
```

Expected: PASS, 6 test.

- [ ] **Step 6: Analyze**

```bash
C:\Users\thezu\flutter\bin\flutter.bat analyze --fatal-infos lib/features/finance test/finance_models_test.dart
```

Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
cd "c:/Users/thezu/rehat_app"
git add lib/core/constants/api_constants.dart lib/features/finance test/finance_models_test.dart
git commit -m "feat(finance): repository & model keuangan Flutter

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 8: Guard akses & kartu dashboard

**Repo:** `c:\Users\thezu\rehat_app`

**Files:**
- Modify: `lib/core/router/route_names.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/admin/presentation/admin_dashboard_screen.dart`

**Interfaces:**
- Consumes: `financeAccessProvider` (Task 7)
- Produces: rute `RouteNames.financePnl` & `RouteNames.financeFixedCosts`; kartu masuk di dashboard.

> Gating di sini **kosmetik** — keamanan sesungguhnya ada di middleware Task 3. Tujuannya hanya agar admin lain tidak melihat menu yang akan menolaknya.

- [ ] **Step 1: Tambah nama rute**

Di `lib/core/router/route_names.dart`, tambahkan:

```dart
  static const String financePnl = '/admin/finance/pnl';
  static const String financeFixedCosts = '/admin/finance/fixed-costs';
```

- [ ] **Step 2: Daftarkan rute dengan guard**

Di `lib/core/router/app_router.dart`, tambahkan dua `GoRoute` mengikuti pola rute admin yang sudah ada di file itu:

```dart
      GoRoute(
        path: RouteNames.financePnl,
        builder: (context, state) => const ProfitLossScreen(),
      ),
      GoRoute(
        path: RouteNames.financeFixedCosts,
        builder: (context, state) => const FixedCostsScreen(),
      ),
```

Tambahkan impor di bagian atas file:

```dart
import '../../features/finance/presentation/profit_loss_screen.dart';
import '../../features/finance/presentation/fixed_costs_screen.dart';
```

> Kedua layar dibuat di Task 9 & 10. Kerjakan Task 9 dan 10 lebih dulu bila ingin proyek tetap kompilasi di antara commit; atau selesaikan Task 8–10 sebagai satu commit.

- [ ] **Step 3: Tambah kartu di dashboard**

Di `lib/features/admin/presentation/admin_dashboard_screen.dart`, sisipkan di dalam `build` (mengikuti pola kartu admin lain di file itu):

```dart
        // Kartu Keuangan — hanya tampil untuk pemilik. Ini kosmetik;
        // batas nyata ada di middleware requireFinanceAccess di backend.
        ref.watch(financeAccessProvider).maybeWhen(
              data: (allowed) => allowed
                  ? NeuCard(
                      padding: EdgeInsets.zero, // ListTile bawa padding sendiri
                      child: ListTile(
                        leading: const Icon(Icons.account_balance_wallet_outlined),
                        title: const Text('Keuangan'),
                        subtitle: const Text('Laba rugi & biaya tetap'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(RouteNames.financePnl),
                      ),
                    )
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
```

Tambahkan impor `financeAccessProvider`:

```dart
import '../../finance/data/finance_repository.dart';
```

- [ ] **Step 4: Analyze**

```bash
C:\Users\thezu\flutter\bin\flutter.bat analyze --fatal-infos
```

Expected: `No issues found!`

- [ ] **Step 5: Commit** (bersama Task 9 & 10 bila dikerjakan berurutan)

```bash
cd "c:/Users/thezu/rehat_app"
git add lib/core/router lib/features/admin/presentation/admin_dashboard_screen.dart
git commit -m "feat(finance): rute & kartu masuk modul keuangan

Kartu hanya tampil bila financeAccessProvider true. Gating ini kosmetik;
batas nyata ada di middleware backend.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 9: Layar Biaya Tetap

**Repo:** `c:\Users\thezu\rehat_app`

**Files:**
- Create: `lib/features/finance/presentation/fixed_costs_screen.dart`

**Interfaces:**
- Consumes: `fixedCostsProvider`, `FinanceRepository.addFixedCost/deleteFixedCost` (Task 7)
- Produces: `class FixedCostsScreen extends ConsumerWidget`

- [ ] **Step 1: Buat layar**

Buat `lib/features/finance/presentation/fixed_costs_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/neu.dart';
import '../data/finance_repository.dart';

/// Kelola biaya tetap bulanan (sewa, gaji, listrik, wifi).
/// Angka di sini menentukan laba bersih DAN break-even — bukan sekadar catatan.
class FixedCostsScreen extends ConsumerWidget {
  const FixedCostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(fixedCostsProvider);
    final items = async.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Biaya Tetap Bulanan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      // Keep-previous-data: spinner hanya saat benar-benar belum ada data.
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(fixedCostsProvider),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // NeuCard SUDAH memberi padding 16 secara bawaan —
                  // jangan bungkus lagi dengan Padding (padding ganda).
                  NeuCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total per bulan',
                            style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 4),
                        Text(
                          Formatters.rupiah(
                              items.where((e) => e.isActive).fold<int>(0, (s, e) => s + e.amount)),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(color: AppColors.espresso),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Dipakai untuk menghitung laba bersih dan break-even harian.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'Belum ada biaya tetap.\nTambahkan sewa, gaji, listrik, dan wifi '
                        'supaya laba bersih tidak terlalu optimis.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final c in items)
                    NeuCard(
                      // ListTile membawa padding sendiri -> matikan padding kartu.
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        title: Text(c.name),
                        subtitle: Text([
                          if (c.category.isNotEmpty) c.category,
                          if (c.dueDay != null) 'jatuh tempo tgl ${c.dueDay}',
                        ].join(' · ')),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(Formatters.rupiah(c.amount)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _confirmDelete(context, ref, c),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, FixedCost c) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus biaya tetap?'),
        content: Text(
            '${c.name} (${Formatters.rupiah(c.amount)}) akan dihapus. '
            'Laba bersih dan break-even akan ikut berubah.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (yes != true) return;
    await ref.read(financeRepositoryProvider).deleteFixedCost(c.id);
    ref.invalidate(fixedCostsProvider);
  }

  Future<void> _showAddSheet(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama biaya (mis. Sewa)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Nominal per bulan (Rp)'),
                validator: (v) {
                  final n = int.tryParse((v ?? '').replaceAll(RegExp(r'[^0-9]'), ''));
                  if (n == null || n <= 0) return 'Nominal harus lebih dari 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: categoryCtrl,
                decoration: const InputDecoration(labelText: 'Kategori (opsional)'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: NeuButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    await ref.read(financeRepositoryProvider).addFixedCost(
                          name: nameCtrl.text,
                          amount: int.parse(
                              amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')),
                          category: categoryCtrl.text,
                        );
                    ref.invalidate(fixedCostsProvider);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Simpan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze**

```bash
C:\Users\thezu\flutter\bin\flutter.bat analyze --fatal-infos lib/features/finance
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd "c:/Users/thezu/rehat_app"
git add lib/features/finance/presentation/fixed_costs_screen.dart
git commit -m "feat(finance): layar kelola biaya tetap bulanan

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 10: Layar Laba Rugi

**Repo:** `c:\Users\thezu\rehat_app`

**Files:**
- Create: `lib/features/finance/presentation/profit_loss_screen.dart`

**Interfaces:**
- Consumes: `pnlProvider`, `pnlMonthProvider` (Task 7); rute `RouteNames.financeFixedCosts` (Task 8)
- Produces: `class ProfitLossScreen extends ConsumerWidget`

- [ ] **Step 1: Buat layar**

Buat `lib/features/finance/presentation/profit_loss_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/neu.dart';
import '../data/finance_repository.dart';

/// Laporan laba rugi bulanan.
///
/// Berbeda dari "laba bersih" di dashboard lama: pengeluaran restock TIDAK
/// dipotong dua kali (sudah terhitung di HPP), dan biaya tetap ikut masuk.
class ProfitLossScreen extends ConsumerWidget {
  const ProfitLossScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(pnlMonthProvider);
    final async = ref.watch(pnlProvider);
    final p = async.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laba Rugi'),
        actions: [
          IconButton(
            tooltip: 'Biaya tetap',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.push(RouteNames.financeFixedCosts),
          ),
        ],
      ),
      body: Column(
        children: [
          _MonthPicker(month: month, ref: ref),
          Expanded(
            child: p == null
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(pnlProvider),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _Row(label: 'Omzet', value: p.revenue, bold: true),
                        _Row(label: 'HPP (modal bahan)', value: -p.cogs),
                        const Divider(),
                        _Row(
                          label: 'Laba Kotor',
                          value: p.grossProfit,
                          bold: true,
                          suffix: '${p.grossMarginPct}%',
                        ),
                        _Row(label: 'Biaya tetap', value: -p.fixedCosts),
                        _Row(label: 'Biaya variabel (non-restock)', value: -p.variableExpenses),
                        _Row(label: 'Biaya transaksi QRIS', value: -p.paymentFees),
                        const Divider(),
                        _Row(
                          label: 'Laba Bersih',
                          value: p.netProfit,
                          bold: true,
                          suffix: '${p.netMarginPct}%',
                          highlight: true,
                        ),
                        const SizedBox(height: 24),
                        // NeuCard sudah ber-padding 16 secara bawaan.
                        NeuCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Rincian biaya tetap',
                                  style: Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 8),
                              if (p.fixedCostItems.isEmpty)
                                const Text(
                                    'Belum ada biaya tetap. Laba bersih di atas '
                                    'masih terlalu optimis.'),
                              for (final c in p.fixedCostItems)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(c.name),
                                      Text(Formatters.rupiah(c.amount)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MonthPicker extends StatelessWidget {
  const _MonthPicker({required this.month, required this.ref});
  final DateTime month;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    void shift(int delta) {
      ref.read(pnlMonthProvider.notifier).state =
          DateTime(month.year, month.month + delta);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => shift(-1)),
          Text(
            Formatters.tanggal(month).replaceAll(RegExp(r'^\d+\s'), ''),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => shift(1)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.bold = false,
    this.suffix,
    this.highlight = false,
  });

  final String label;
  final int value;
  final bool bold;
  final String? suffix;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: highlight
              ? (value >= 0 ? AppColors.success : AppColors.error)
              : null,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: style)),
          if (suffix != null) ...[
            Text(suffix!, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(width: 8),
          ],
          Text(Formatters.rupiah(value), style: style),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze & test penuh**

```bash
cd "c:/Users/thezu/rehat_app"
C:\Users\thezu\flutter\bin\flutter.bat analyze --fatal-infos
C:\Users\thezu\flutter\bin\flutter.bat test
```

Expected: `No issues found!` dan seluruh test lulus (≈122 test).

- [ ] **Step 3: Jalankan di emulator & verifikasi dengan mata**

```bash
D:\Sdk\emulator\emulator.exe -avd Pixel_8_Pro &
cd "c:/Users/thezu/rehat_app"
C:\Users\thezu\flutter\bin\flutter.bat run --flavor admin \
  --dart-define=API_BASE_URL=https://rehat-backend-production.up.railway.app/v1 \
  --dart-define=ADMIN_BUILD=true
```

Login sebagai **irurr (087864504924)** → kartu "Keuangan" harus muncul di dashboard → buka Laba Rugi.

Lalu **logout dan login sebagai irur (087777601617)** → kartu "Keuangan" **tidak boleh muncul**. Ini verifikasi akhir kontrol akses dari sisi pengguna.

- [ ] **Step 4: Commit**

```bash
cd "c:/Users/thezu/rehat_app"
git add lib/features/finance/presentation/profit_loss_screen.dart
git commit -m "feat(finance): layar laba rugi bulanan

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 11: Dokumentasi

**Repo:** keduanya

**Files:**
- Modify: `c:\Users\thezu\rehat_app\CLAUDE.md`

- [ ] **Step 1: Perbarui tabel status migrasi**

Di `CLAUDE.md` §3, tambahkan baris pada tabel migrasi:

```markdown
| 016 | modul keuangan (finance_settings, fixed_costs, finance_ledger, finance_calibration, `expenses.bucket`, `users.can_access_finance`) | ✅ terpasang (`node src/db/verify-016.js`) |
```

- [ ] **Step 2: Tambah catatan modul keuangan di §5 (Inventaris Fitur)**

Di bagian **Admin / Kasir**, tambahkan:

```markdown
· **Keuangan (KHUSUS PEMILIK)**: Laba Rugi bulanan yang benar + biaya tetap
```

- [ ] **Step 3: Tambah gotcha kontrol akses di §4**

```markdown
- **Modul keuangan hanya untuk pemilik.** Gate-nya kolom `users.can_access_finance` (migrasi 016), BUKAN `role='admin'` — ada dua akun admin dan hanya `irurr` (087864504924) yang boleh. Penegakannya di middleware `requireFinanceAccess` (`src/middleware/auth.js`), membalas **404** bukan 403 supaya modul tidak bocor. **Jangan pakai `adminAccess` untuk route keuangan** — jalur `x-admin-key` melewati JWT sehingga `req.user` kosong dan flag tak terperiksa. Gating di Flutter murni kosmetik.
- **Backend kini punya test.** `cd D:\REHAT\rehat-backend\rehat-backend && npx jest`. Logika keuangan murni ada di `financeCalc.js` & fungsi `splitByBucket`/`sumFixedCosts` — semua tanpa DB supaya bisa diuji.
- **`net_profit` di `/admin/reports/sales` masih memotong restock dua kali.** Angka yang benar ada di `/admin/finance/pnl`. Endpoint lama sengaja dibiarkan agar dashboard existing tidak pecah.
```

- [ ] **Step 4: Commit**

```bash
cd "c:/Users/thezu/rehat_app"
git add CLAUDE.md
git commit -m "docs: catat modul keuangan tahap 1 di panduan proyek

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Definition of Done — Tahap 1

- [ ] `npx jest` di backend: seluruh test lulus (≈14 test)
- [ ] `flutter analyze --fatal-infos`: bersih
- [ ] `flutter test`: seluruh test lulus
- [ ] `node src/db/verify-016.js`: exit 0, semua ✅
- [ ] Token `irur` → `/admin/finance/*` membalas **404** di setiap route
- [ ] Token `irurr` → membalas **200**
- [ ] Login sebagai `irur` di app → kartu Keuangan tidak muncul
- [ ] Laba Rugi Juli 2026 menampilkan `variableExpenses` ≪ Rp1.420.000 (bukti backfill bucket berhasil)

## Belum termasuk (Tahap 2 & 3)

- **Tahap 2 — Amplop alokasi:** mesin waterfall, ledger, saldo pos, penarikan, wizard kalibrasi, layar Ringkasan & Riwayat, rambu (break-even, runway, rem tarik pribadi).
- **Tahap 3 — Auto-kalibrasi:** penyaringan sampel, shrinkage, deadband, kartu usulan.

Rencana keduanya ditulis setelah Tahap 1 selesai, karena detailnya bergantung pada bentuk kode yang dihasilkan di sini.
