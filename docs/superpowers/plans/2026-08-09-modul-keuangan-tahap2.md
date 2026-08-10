# Modul Keuangan Rehat — Tahap 2: Amplop Alokasi

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Memecah setiap rupiah yang masuk ke lima amplop (Restock, Operasional, Pribadi, Scaling, Darurat) secara otomatis harian, dengan saldo berjalan yang bisa ditarik dan dilacak, plus rambu yang mencegah pemilik mengambil uang yang sebenarnya milik sewa dan gaji.

**Architecture:** Buku besar event-sourced — saldo pos **tidak disimpan**, melainkan dijumlah dari `finance_ledger`. Alokasi berjalan waterfall berurutan, dipicu saat tutup kasir, idempoten lewat unique index. Logika hitung ditaruh di fungsi murni tanpa DB supaya bisa di-TDD.

**Tech Stack:** Node 20 + Express + Supabase + Zod + Jest (sudah terpasang di Tahap 1) · Flutter 3.44 + Riverpod + go_router.

## Global Constraints

- **Dua repo.** Backend `D:\REHAT\rehat-backend\rehat-backend` (branch `master`), Flutter `c:\Users\thezu\rehat_app` (branch `main`). Setiap task menyebut repo mana.
- **TIDAK ADA migrasi baru.** Migrasi 016 (Tahap 1) sudah membuat `finance_settings`, `finance_ledger`, `finance_calibration`, `fixed_costs`. Semua sudah terpasang & terverifikasi di produksi. Jangan menulis migrasi 017 untuk tahap ini.
- **Semua batas hari WIB (UTC+7).** Backend: helper `wibDayRange`/`wibDateKey` di `orderService.js` (const lokal, tidak di-export) dan `wibMonthBounds` di `financeService.js`. Flutter: `Formatters.toWib`. Dilarang `new Date().toISOString().slice(0,10)`, `setHours(0,0,0,0)`, `getHours()` mentah, atau `DateFormat` langsung di layar.
- **Semua rupiah integer.** `Σ alokasi == omzet` harus persis — tidak boleh ada rupiah hilang karena pembulatan.
- **Seluruh endpoint baru di balik `requireFinanceAccess`** (khusus pemilik, membalas 404). Taruh di `src/routes/finance.js` yang sudah ada — sudah di-mount `router.use('/admin/finance', authenticate, requireFinanceAccess, financeRouter)`, jadi **jangan ulangi guard per-route**.
- **Suite backend harus lulus tanpa kredensial.** File test yang transitif me-require `config/supabase` wajib `jest.mock('../../config/supabase', () => ({ supabaseAdmin: {} }))`. Verifikasi: `SUPABASE_URL= SUPABASE_SERVICE_ROLE_KEY= SUPABASE_ANON_KEY= npx jest`.
- **Pola defensif** untuk kolom hasil migrasi: konvensi proyek mensyaratkan nama kolom **DAN** `(does not exist|schema cache|column)` — lihat `orderService.js:117-119`. Jangan pakai regex nama kolom saja.
- **Paginasi wajib** untuk query yang bisa melebihi 1000 baris (PostgREST cap). `finance_ledger` akan tumbuh 5 baris/hari → lewat 1000 dalam ±7 bulan.
- Envelope `{ success, data, message }`. Bahasa UI & komentar: **Indonesia**.
- `AppColors` token tema adalah **getter runtime, BUKAN const**; token semantik (`success`, `error`, `warning`, `amber`) memang const. `AppColors` ada di `lib/core/constants/app_colors.dart`.
- `NeuCard` sudah ber-padding 16 bawaan; pakai `padding: EdgeInsets.zero` bila isinya `ListTile`.
- Rute Flutter: konvensi proyek = pasangan **name + path** di `RouteNames`, `GoRoute` bersarang (path relatif + `name:` eksplisit) di shell branch profile. Navigasi pakai `context.pushNamed`, **bukan** `context.push`.
- Gate CI: `flutter analyze --fatal-infos` (unscoped) bersih + `flutter test`. Flutter dipanggil di Git Bash sebagai `"/c/Users/thezu/flutter/bin/flutter.bat"` (forward slash, dikutip) — bentuk `C:\Users\...` gagal.

## Parameter aktif di produksi (jangan hardcode — baca dari `finance_settings`)

| Kolom | Nilai |
|---|---|
| `pct_restock` | 42 |
| `operational_daily` | 286667 |
| `ratio_personal` / `ratio_scaling` / `ratio_emergency` | 2 / 1 / 0,8 |
| `emergency_target` | 25800000 |
| `started_on` | 2026-08-09 |

`finance_ledger` saat ini **kosong (0 baris)**. Biaya tetap: 1 baris Rp8.000.000.

## Ringkasan Task

| # | Deliverable | Repo |
|---|---|---|
| 1 | Kalkulator waterfall murni (teruji) | backend |
| 2 | Mesin alokasi + tulis ledger (idempoten) | backend |
| 3 | Saldo pos + rambu (break-even, runway) | backend |
| 4 | Penarikan & koreksi | backend |
| 5 | Pemicu otomatis saat tutup kasir | backend |
| 6 | Repository + model Flutter | flutter |
| 7 | Layar Ringkasan Keuangan | flutter |
| 8 | Layar Riwayat buku besar | flutter |
| 9 | Dokumentasi | keduanya |

Wizard kalibrasi **sengaja tidak masuk Tahap 2** — parameter sudah terisi benar di produksi dan dapat disunting lewat SQL bila perlu. Menambahkannya sekarang membangun UI untuk kebutuhan yang belum ada (YAGNI). Ia masuk Tahap 3 bersama auto-kalibrasi, yang memang membutuhkannya.

---

## Task 1: Kalkulator waterfall murni

Inti seluruh tahap ini. Fungsi murni tanpa DB, sepenuhnya di-TDD.

**Repo:** `D:\REHAT\rehat-backend\rehat-backend`

**Files:**
- Modify: `src/services/financeCalc.js` (tambah fungsi, jangan ubah `computePnl`)
- Test: `src/services/__tests__/allocationCalc.test.js`

**Interfaces:**
- Consumes: —
- Produces:
  ```js
  allocateDaily({ revenue, pctRestock, operationalDaily, ratioPersonal, ratioScaling, ratioEmergency })
  // => { restock, operational, personal, scaling, emergency, shortfall }
  // Semua integer rupiah, semua >= 0.
  // Invarian: restock + operational + personal + scaling + emergency === revenue (persis)
  // shortfall = kekurangan pos Operasional pada hari kurus (0 bila cukup)
  ```

- [ ] **Step 1: Tulis test yang gagal**

Buat `src/services/__tests__/allocationCalc.test.js`:

```js
const { allocateDaily } = require('../financeCalc')

// Parameter produksi nyata (finance_settings).
const P = {
  pctRestock: 42,
  operationalDaily: 286667,
  ratioPersonal: 2,
  ratioScaling: 1,
  ratioEmergency: 0.8,
}

describe('allocateDaily — hari normal', () => {
  test('membagi omzet harian sesuai waterfall', () => {
    const r = allocateDaily({ revenue: 1279198, ...P })
    expect(r.restock).toBe(537263)      // floor(1.279.198 x 42%)
    expect(r.operational).toBe(286667)  // nominal penuh
    expect(r.shortfall).toBe(0)
    // sisa 455.268 dibagi 2:1:0,8
    expect(r.personal + r.scaling + r.emergency).toBe(1279198 - 537263 - 286667)
    expect(r.personal).toBeGreaterThan(r.scaling)
    expect(r.scaling).toBeGreaterThan(r.emergency)
  })

  test('INVARIAN: total alokasi persis sama dengan omzet', () => {
    for (const revenue of [1, 999, 1000, 12345, 500000, 1279198, 1988000, 9999999]) {
      const r = allocateDaily({ revenue, ...P })
      const total = r.restock + r.operational + r.personal + r.scaling + r.emergency
      expect(total).toBe(revenue)
    }
  })

  test('INVARIAN: tidak ada pos negatif, di nominal apa pun', () => {
    for (const revenue of [0, 1, 100, 286667, 500000, 3000000]) {
      const r = allocateDaily({ revenue, ...P })
      for (const [pos, nilai] of Object.entries(r)) {
        expect(nilai).toBeGreaterThanOrEqual(0)
      }
    }
  })

  test('sisa rupiah pembulatan dilempar ke Restock', () => {
    // Omzet yang tidak habis dibagi -> Restock menyerap sisanya.
    const r = allocateDaily({ revenue: 1000001, ...P })
    const total = r.restock + r.operational + r.personal + r.scaling + r.emergency
    expect(total).toBe(1000001)
  })
})

describe('allocateDaily — hari kurus', () => {
  test('omzet di bawah kebutuhan Operasional: 3 pos terakhir nol, shortfall dicatat', () => {
    const r = allocateDaily({ revenue: 300000, ...P })
    expect(r.restock).toBe(126000)       // 42%
    expect(r.operational).toBe(174000)   // sisa yang ada, bukan 286.667
    expect(r.shortfall).toBe(286667 - 174000)
    expect(r.personal).toBe(0)
    expect(r.scaling).toBe(0)
    expect(r.emergency).toBe(0)
    expect(r.restock + r.operational).toBe(300000)
  })

  test('omzet nol: semua pos nol, shortfall = kebutuhan penuh', () => {
    const r = allocateDaily({ revenue: 0, ...P })
    expect(r.restock).toBe(0)
    expect(r.operational).toBe(0)
    expect(r.personal).toBe(0)
    expect(r.shortfall).toBe(286667)
  })

  test('tepat di titik impas Operasional: shortfall nol, sisa nol', () => {
    // restock 42% + operasional penuh = omzet  =>  omzet = 286667 / 0,58
    const revenue = Math.ceil(286667 / 0.58)
    const r = allocateDaily({ revenue, ...P })
    expect(r.shortfall).toBe(0)
    expect(r.operational).toBe(286667)
    expect(r.personal + r.scaling + r.emergency).toBeGreaterThanOrEqual(0)
  })
})

describe('allocateDaily — masukan tidak wajar', () => {
  test('omzet negatif diperlakukan sebagai nol', () => {
    const r = allocateDaily({ revenue: -5000, ...P })
    expect(r.restock).toBe(0)
    expect(r.operational).toBe(0)
  })

  test('parameter hilang tidak menghasilkan NaN', () => {
    const r = allocateDaily({ revenue: 100000 })
    for (const nilai of Object.values(r)) {
      expect(Number.isFinite(nilai)).toBe(true)
    }
  })
})
```

- [ ] **Step 2: Jalankan test — pastikan GAGAL**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend" && npx jest allocationCalc
```

Expected: FAIL — `allocateDaily is not a function`.

- [ ] **Step 3: Implementasi**

Tambahkan di `src/services/financeCalc.js`, sebelum `module.exports`:

```js
/**
 * Alokasi harian ke lima amplop — MURNI, tanpa DB.
 *
 * Waterfall berurutan, bukan lima persentase paralel:
 *   1. Restock  = pctRestock% dari omzet (proporsional terhadap penjualan)
 *   2. Operasional = nominal tetap harian (sewa & gaji tidak peduli omzet)
 *   3. Sisanya dibagi Pribadi : Scaling : Darurat menurut rasio
 *
 * Kenapa Operasional nominal: dengan persentase, pos ini ikut menyusut justru
 * saat paling dibutuhkan -- omzet turun berarti sewa tak terbayar. Dengan
 * waterfall, yang menyusut adalah bagian pemilik. Owner adalah penerima sisa.
 *
 * Hari kurus (omzet < kebutuhan): Operasional menerima apa yang ada, tiga pos
 * terakhir nol (tidak pernah negatif), kekurangannya dicatat sebagai shortfall.
 */
const allocateDaily = ({
  revenue,
  pctRestock,
  operationalDaily,
  ratioPersonal,
  ratioScaling,
  ratioEmergency,
} = {}) => {
  const rev = Math.max(0, int(revenue))
  const pct = num(pctRestock)
  const opTarget = Math.max(0, int(operationalDaily))

  const restockRaw = Math.floor((rev * pct) / 100)
  const restock = Math.min(restockRaw, rev)

  const sisaSetelahRestock = rev - restock
  const operational = Math.min(opTarget, sisaSetelahRestock)
  const shortfall = opTarget - operational

  let sisa = sisaSetelahRestock - operational

  const rp = Math.max(0, num(ratioPersonal))
  const rs = Math.max(0, num(ratioScaling))
  const re = Math.max(0, num(ratioEmergency))
  const totalRasio = rp + rs + re

  let personal = 0
  let scaling = 0
  let emergency = 0
  if (sisa > 0 && totalRasio > 0) {
    personal = Math.floor((sisa * rp) / totalRasio)
    scaling = Math.floor((sisa * rs) / totalRasio)
    emergency = Math.floor((sisa * re) / totalRasio)
  }

  // Sisa rupiah dari pembagian TIGA ARAH diserap Pribadi -- sisa itu lahir dari
  // membagi jatah pemilik, jadi ia tetap milik kelompok itu. Melemparnya ke
  // Restock akan membuat Restock tidak lagi tepat pctRestock% dari omzet.
  if (sisa > 0 && totalRasio > 0) {
    personal += sisa - (personal + scaling + emergency)
  }

  // Jaring pengaman: hanya untuk kasus degenerate (rasio nol/hilang) di mana
  // sisa tidak terbagi sama sekali. Menjamin Σ alokasi == omzet PERSIS --
  // tanpa ini, rupiah menguap diam-diam setiap hari.
  const terbagi = restock + operational + personal + scaling + emergency
  const sisaPembulatan = rev - terbagi

  return {
    restock: restock + sisaPembulatan,
    operational,
    personal,
    scaling,
    emergency,
    shortfall,
  }
}
```

Bila `num()` belum ada di file itu, tambahkan di dekat `int()`:

```js
const num = (v) => {
  const n = Number(v)
  return Number.isFinite(n) ? n : 0
}
```

Tambahkan `allocateDaily` ke `module.exports`.

- [ ] **Step 4: Jalankan test — pastikan LULUS**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend" && npx jest allocationCalc
```

Expected: PASS, 9 test.

- [ ] **Step 5: Jalankan seluruh suite + tanpa kredensial**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend" && npx jest
SUPABASE_URL= SUPABASE_SERVICE_ROLE_KEY= SUPABASE_ANON_KEY= npx jest
```

Expected: 24 test lama + 9 baru = 33, keduanya lulus.

- [ ] **Step 6: Commit**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend"
git add src/services/financeCalc.js src/services/__tests__/allocationCalc.test.js
git commit -m "feat(finance): kalkulator alokasi waterfall murni

Restock % -> Operasional nominal -> sisa dibagi 2:1:0,8. Sisa rupiah
pembulatan ke Restock supaya total persis sama dengan omzet.
Hari kurus: tiga pos terakhir nol, kekurangan dicatat sebagai shortfall.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 2: Mesin alokasi + tulis ledger (idempoten)

**Repo:** `D:\REHAT\rehat-backend\rehat-backend`

**Files:**
- Modify: `src/services/financeService.js`
- Modify: `src/routes/finance.js`

**Interfaces:**
- Consumes: `allocateDaily` (Task 1), `orderService.getSalesReportBetween` (Tahap 1)
- Produces:
  ```js
  getSettings()                  // => baris finance_settings (dibaca, tidak di-hardcode)
  allocateForDate('YYYY-MM-DD')  // => { date, allocated: bool, alokasi: {...}, reason?: string }
  ```

**Idempotensi** dijamin `CREATE UNIQUE INDEX finance_ledger_alloc_unique ON finance_ledger (bucket, ref_date) WHERE source='allocation'` (sudah ada dari migrasi 016). Tutup kasir dibuka dua kali **tidak** boleh menggandakan alokasi.

- [ ] **Step 1: Implementasi `getSettings` + `allocateForDate`**

Di `src/services/financeService.js`, tambahkan sebelum `module.exports`:

```js
const { allocateDaily } = require('./financeCalc')

const BUCKETS = ['restock', 'operational', 'personal', 'scaling', 'emergency']

/** Parameter alokasi (baris tunggal). Dibaca dari DB -- jangan hardcode. */
const getSettings = async () => {
  const { data, error } = await supabaseAdmin.from('finance_settings').select('*').limit(1).maybeSingle()
  if (error) throw new AppError('FINANCE_SETTINGS_FETCH_FAILED', error.message, 500)
  if (!data) throw new AppError('FINANCE_SETTINGS_MISSING', 'Parameter keuangan belum diatur', 500)
  return data
}

/**
 * Alokasikan omzet satu hari (WIB) ke lima amplop. IDEMPOTEN.
 *
 * Dipanggil saat tutup kasir dan bisa juga manual. Memanggilnya dua kali untuk
 * tanggal yang sama TIDAK menggandakan alokasi -- unique index parsial pada
 * (bucket, ref_date) WHERE source='allocation' yang menjamin, bukan pengecekan
 * di aplikasi yang bisa balapan.
 */
const allocateForDate = async (dateStr) => {
  const settings = await getSettings()

  if (dateStr < settings.started_on) {
    return { date: dateStr, allocated: false, reason: 'sebelum started_on' }
  }

  // Sudah pernah dialokasikan?
  const { data: existing } = await supabaseAdmin
    .from('finance_ledger')
    .select('bucket, amount')
    .eq('ref_date', dateStr)
    .eq('source', 'allocation')
  if ((existing || []).length > 0) {
    return { date: dateStr, allocated: false, reason: 'sudah dialokasikan' }
  }

  // Omzet hari itu, batas hari WIB.
  const [startIso, endIso] = wibDayBounds(dateStr)
  const sales = await orderService.getSalesReportBetween(startIso, endIso)

  const alokasi = allocateDaily({
    revenue: sales.revenue,
    pctRestock: Number(settings.pct_restock),
    operationalDaily: Number(settings.operational_daily),
    ratioPersonal: Number(settings.ratio_personal),
    ratioScaling: Number(settings.ratio_scaling),
    ratioEmergency: Number(settings.ratio_emergency),
  })

  const rows = BUCKETS.map((b) => ({
    bucket: b,
    direction: 'in',
    amount: alokasi[b],
    source: 'allocation',
    ref_date: dateStr,
    note: `Alokasi otomatis omzet ${sales.revenue}`,
  }))

  if (alokasi.shortfall > 0) {
    rows.push({
      bucket: 'operational',
      direction: 'out',
      amount: alokasi.shortfall,
      source: 'shortfall',
      ref_date: dateStr,
      note: 'Omzet tidak cukup menutup kebutuhan operasional harian',
    })
  }

  const { error } = await supabaseAdmin.from('finance_ledger').insert(rows)
  if (error) {
    // Unique index menolak -> proses lain sudah mengalokasikan hari ini. Bukan error.
    if (/duplicate key|unique/i.test(error.message || '')) {
      return { date: dateStr, allocated: false, reason: 'sudah dialokasikan (bersamaan)' }
    }
    throw new AppError('ALLOCATION_FAILED', error.message, 500)
  }

  return { date: dateStr, allocated: true, revenue: sales.revenue, alokasi }
}
```

Tambahkan helper batas hari WIB di file yang sama (sejajar `wibMonthBounds` yang sudah ada):

```js
// Batas satu hari WIB (YYYY-MM-DD) dinyatakan sebagai ISO UTC.
// 00:00 WIB = 17:00 UTC hari sebelumnya.
const wibDayBounds = (dateStr) => {
  const [y, m, d] = dateStr.split('-').map(Number)
  const start = new Date(Date.UTC(y, m - 1, d, 0, 0, 0) - 7 * 3600 * 1000)
  const end = new Date(Date.UTC(y, m - 1, d + 1, 0, 0, 0) - 7 * 3600 * 1000 - 1)
  return [start.toISOString(), end.toISOString()]
}
```

Tambahkan `getSettings`, `allocateForDate`, `wibDayBounds` ke `module.exports`.

- [ ] **Step 2: Tambah route**

Di `src/routes/finance.js`, sebelum `module.exports`:

```js
router.post('/allocate', async (req, res, next) => {
  try {
    const raw = (req.body?.date || '').toString()
    let date = raw
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
      // Default: hari ini menurut WIB.
      date = new Date(Date.now() + 7 * 3600 * 1000).toISOString().slice(0, 10)
    }
    const data = await financeService.allocateForDate(date)
    return success(res, data, data.allocated ? 'Alokasi tersimpan' : 'Tidak ada alokasi baru')
  } catch (err) { next(err) }
})
```

- [ ] **Step 3: Uji idempotensi terhadap produksi**

Skrip sekali-pakai (hapus setelah dipakai, jangan di-commit):

```js
require('dotenv').config()
const f = require('./src/services/financeService')
const { supabaseAdmin: sb } = require('./src/config/supabase')
;(async () => {
  const d = '2026-08-09'
  console.log('panggilan 1:', JSON.stringify(await f.allocateForDate(d)))
  console.log('panggilan 2:', JSON.stringify(await f.allocateForDate(d)))
  const { data } = await sb.from('finance_ledger').select('bucket,amount,source').eq('ref_date', d)
  console.log('baris ledger:', data.length)
  const masuk = data.filter((r) => r.source === 'allocation').reduce((s, r) => s + Number(r.amount), 0)
  console.log('total alokasi:', masuk)
})()
```

Expected: panggilan 1 `allocated: true`; panggilan 2 `allocated: false` dengan `reason: 'sudah dialokasikan'`; **baris ledger tepat 5** (atau 6 bila ada shortfall); `total alokasi` **sama persis** dengan omzet hari itu.

Bila baris ledger jadi 10, idempotensi gagal — **laporkan BLOCKED**, jangan lanjut.

- [ ] **Step 4: Commit**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend"
git add src/services/financeService.js src/routes/finance.js
git commit -m "feat(finance): mesin alokasi harian idempoten

Idempotensi dijamin unique index parsial (bucket, ref_date) WHERE
source='allocation', bukan pengecekan aplikasi yang bisa balapan.
Batas hari WIB; tidak berjalan sebelum started_on.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 3: Saldo pos + rambu keputusan

**Repo:** `D:\REHAT\rehat-backend\rehat-backend`

**Files:**
- Modify: `src/services/financeCalc.js` (fungsi murni rambu)
- Modify: `src/services/financeService.js`
- Modify: `src/routes/finance.js`
- Test: `src/services/__tests__/financeGuards.test.js`

**Interfaces:**
- Produces:
  ```js
  // MURNI (financeCalc.js)
  bucketBalances(ledgerRows)  // => { restock, operational, personal, scaling, emergency }
  computeGuards({ balances, monthlyCost, emergencyTarget, grossMarginPct })
  // => { breakEvenDaily, runwayDays, personalWithdrawBlocked, emergencyReached, emergencyPct }

  // ber-DB (financeService.js)
  getFinanceOverview()  // => { balances, guards, settings, lastAllocatedDate }
  ```

Rumus rambu (dari spec):

| Rambu | Rumus |
|---|---|
| Break-even harian | biaya bulanan ÷ 30 ÷ (margin kotor/100) |
| Runway operasional | saldo Operasional ÷ (biaya bulanan ÷ 30) |
| Rem tarik pribadi | saldo Operasional < 1× biaya bulanan → `true` |
| Dana darurat selesai | saldo Darurat ≥ `emergency_target` |

- [ ] **Step 1: Tulis test yang gagal**

Buat `src/services/__tests__/financeGuards.test.js`:

```js
const { bucketBalances, computeGuards } = require('../financeCalc')

describe('bucketBalances', () => {
  test('menjumlah masuk dikurangi keluar per pos', () => {
    const b = bucketBalances([
      { bucket: 'restock', direction: 'in', amount: 500000 },
      { bucket: 'restock', direction: 'out', amount: 120000 },
      { bucket: 'personal', direction: 'in', amount: 200000 },
    ])
    expect(b.restock).toBe(380000)
    expect(b.personal).toBe(200000)
    expect(b.scaling).toBe(0)
  })

  test('saldo boleh negatif (overspend dicatat apa adanya)', () => {
    const b = bucketBalances([
      { bucket: 'restock', direction: 'in', amount: 100000 },
      { bucket: 'restock', direction: 'out', amount: 150000 },
    ])
    expect(b.restock).toBe(-50000)
  })

  test('baris shortfall ikut mengurangi Operasional', () => {
    const b = bucketBalances([
      { bucket: 'operational', direction: 'in', amount: 174000 },
      { bucket: 'operational', direction: 'out', amount: 112667 },
    ])
    expect(b.operational).toBe(61333)
  })

  test('daftar kosong / null => semua nol', () => {
    expect(bucketBalances([]).restock).toBe(0)
    expect(bucketBalances(null).operational).toBe(0)
  })
})

describe('computeGuards', () => {
  // Angka produksi: biaya bulanan Rp8,6jt, margin kotor 58,6%.
  const dasar = { monthlyCost: 8600000, emergencyTarget: 25800000, grossMarginPct: 58.6 }

  test('break-even harian', () => {
    const g = computeGuards({ balances: { operational: 0 }, ...dasar })
    expect(g.breakEvenDaily).toBe(489192) // 8.600.000 / 30 / 0,586
  })

  test('runway dari saldo Operasional', () => {
    const g = computeGuards({ balances: { operational: 2866670 }, ...dasar })
    expect(g.runwayDays).toBe(10) // 2.866.670 / (8.600.000/30)
  })

  test('rem tarik pribadi menyala saat Operasional < 1 bulan biaya', () => {
    expect(computeGuards({ balances: { operational: 5000000 }, ...dasar }).personalWithdrawBlocked).toBe(true)
    expect(computeGuards({ balances: { operational: 9000000 }, ...dasar }).personalWithdrawBlocked).toBe(false)
  })

  test('dana darurat tercapai', () => {
    expect(computeGuards({ balances: { emergency: 25800000 }, ...dasar }).emergencyReached).toBe(true)
    expect(computeGuards({ balances: { emergency: 25799999 }, ...dasar }).emergencyReached).toBe(false)
  })

  test('margin nol tidak membuat pembagian nol', () => {
    const g = computeGuards({ balances: {}, monthlyCost: 8600000, emergencyTarget: 1, grossMarginPct: 0 })
    expect(Number.isFinite(g.breakEvenDaily)).toBe(true)
  })

  test('biaya bulanan nol tidak membuat runway tak hingga', () => {
    const g = computeGuards({ balances: { operational: 100000 }, monthlyCost: 0, emergencyTarget: 1, grossMarginPct: 58 })
    expect(Number.isFinite(g.runwayDays)).toBe(true)
  })
})
```

- [ ] **Step 2: Jalankan test — pastikan GAGAL**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend" && npx jest financeGuards
```

Expected: FAIL — `bucketBalances is not a function`.

- [ ] **Step 3: Implementasi fungsi murni**

Di `src/services/financeCalc.js`, sebelum `module.exports`:

```js
const BUCKET_KEYS = ['restock', 'operational', 'personal', 'scaling', 'emergency']

/** Saldo tiap pos dari buku besar. MURNI. Saldo boleh negatif (overspend). */
const bucketBalances = (rows) => {
  const saldo = {}
  for (const k of BUCKET_KEYS) saldo[k] = 0
  for (const r of rows || []) {
    if (!r || !BUCKET_KEYS.includes(r.bucket)) continue
    const a = int(r.amount)
    saldo[r.bucket] += r.direction === 'out' ? -a : a
  }
  return saldo
}

/**
 * Rambu keputusan. MURNI.
 * `monthlyCost` = biaya tetap + variabel + fee -- TIDAK termasuk HPP, karena
 * saat kedai sepi HPP ikut hilang sementara sewa dan gaji tetap jalan.
 */
const computeGuards = ({ balances, monthlyCost, emergencyTarget, grossMarginPct } = {}) => {
  const saldo = balances || {}
  const biaya = Math.max(0, int(monthlyCost))
  const harian = biaya / 30
  const margin = num(grossMarginPct) / 100

  const breakEvenDaily = margin > 0 ? Math.round(harian / margin) : 0
  const runwayDays = harian > 0 ? Math.floor(int(saldo.operational) / harian) : 0
  const target = Math.max(0, int(emergencyTarget))
  const darurat = int(saldo.emergency)

  return {
    breakEvenDaily,
    runwayDays,
    personalWithdrawBlocked: int(saldo.operational) < biaya,
    emergencyReached: target > 0 && darurat >= target,
    emergencyPct: target > 0 ? Math.min(100, Math.round((darurat / target) * 100)) : 0,
  }
}
```

Tambahkan keduanya ke `module.exports`.

- [ ] **Step 4: Jalankan test — pastikan LULUS**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend" && npx jest financeGuards
```

Expected: PASS, 11 test.

- [ ] **Step 5: Implementasi `getFinanceOverview` + route**

Di `src/services/financeService.js`:

```js
/**
 * Ringkasan keuangan: saldo 5 pos + rambu.
 * Paginasi ledger wajib -- 5 baris/hari akan melewati cap 1000 dalam ±7 bulan.
 */
const getFinanceOverview = async () => {
  const settings = await getSettings()

  let rows = []
  let from = 0
  for (;;) {
    const { data, error } = await supabaseAdmin
      .from('finance_ledger')
      .select('bucket, direction, amount, ref_date, source')
      .order('id')
      .range(from, from + 999)
    if (error) throw new AppError('LEDGER_FETCH_FAILED', error.message, 500)
    const batch = data || []
    rows = rows.concat(batch)
    if (batch.length < 1000) break
    from += 1000
  }

  const balances = bucketBalances(rows)

  // Biaya bulanan = biaya tetap aktif + rata-rata variabel non-restock + fee QRIS.
  // Dipakai untuk rambu, jadi ambil dari bulan berjalan.
  const fixedRows = await listFixedCosts()
  const monthlyCost = sumFixedCosts(fixedRows)

  const pnl = await getMonthlyPnl(new Date(Date.now() + 7 * 3600 * 1000).toISOString().slice(0, 7))

  const guards = computeGuards({
    balances,
    monthlyCost: monthlyCost + pnl.variableExpenses + pnl.paymentFees,
    emergencyTarget: Number(settings.emergency_target),
    grossMarginPct: pnl.grossMarginPct,
  })

  const allocDates = rows.filter((r) => r.source === 'allocation').map((r) => r.ref_date).sort()

  return {
    balances,
    guards,
    settings: {
      pct_restock: Number(settings.pct_restock),
      operational_daily: Number(settings.operational_daily),
      emergency_target: Number(settings.emergency_target),
      started_on: settings.started_on,
    },
    last_allocated_date: allocDates.length ? allocDates[allocDates.length - 1] : null,
  }
}
```

Impor `bucketBalances`, `computeGuards` dari `./financeCalc` di atas file.

Route di `src/routes/finance.js`:

```js
router.get('/overview', async (req, res, next) => {
  try {
    return success(res, await financeService.getFinanceOverview())
  } catch (err) { next(err) }
})
```

- [ ] **Step 6: Jalankan seluruh suite + verifikasi produksi**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend" && npx jest
SUPABASE_URL= SUPABASE_SERVICE_ROLE_KEY= SUPABASE_ANON_KEY= npx jest
```

Lalu skrip sekali-pakai (hapus setelahnya) memanggil `getFinanceOverview()` dan tampilkan hasilnya. Periksa kewarasan: `breakEvenDaily` harus mendekati **Rp489.000** dan saldo pos harus konsisten dengan alokasi yang sudah ditulis Task 2.

- [ ] **Step 7: Commit**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend"
git add src/services/financeCalc.js src/services/financeService.js src/routes/finance.js src/services/__tests__/financeGuards.test.js
git commit -m "feat(finance): saldo pos & rambu keputusan

Saldo dijumlah dari buku besar (event-sourced), bukan disimpan.
Rambu: break-even harian, runway operasional, rem tarik pribadi,
progres dana darurat. Biaya bulanan sengaja TIDAK memuat HPP --
saat kedai sepi HPP ikut hilang, sewa dan gaji tidak.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 4: Penarikan & koreksi

**Repo:** `D:\REHAT\rehat-backend\rehat-backend`

**Files:** Modify `src/services/financeService.js`, `src/routes/finance.js`

**Interfaces:**
```js
withdrawFromBucket({ bucket, amount, note, userId })  // => baris ledger
listLedger({ bucket, limit, before })                 // => { items, has_more }
```

- [ ] **Step 1: Implementasi service**

```js
/**
 * Tarik uang dari sebuah pos. Saldo boleh jadi negatif -- modul mencatat
 * kenyataan, bukan memaksa angka terlihat sehat. Rambu di UI yang memberi
 * peringatan, bukan blokir di sini.
 */
const withdrawFromBucket = async ({ bucket, amount, note = null, userId = null }) => {
  if (!BUCKETS.includes(bucket)) {
    throw new AppError('INVALID_BUCKET', 'Pos tidak dikenal', 400)
  }
  const nominal = Math.max(0, Math.round(Number(amount) || 0))
  if (nominal <= 0) {
    throw new AppError('INVALID_AMOUNT', 'Nominal harus lebih dari 0', 400)
  }
  const row = {
    bucket,
    direction: 'out',
    amount: nominal,
    source: 'withdrawal',
    ref_date: new Date(Date.now() + 7 * 3600 * 1000).toISOString().slice(0, 10),
    note: note ? String(note).slice(0, 200) : null,
    created_by: userId,
  }
  const { data, error } = await supabaseAdmin.from('finance_ledger').insert(row).select('*').single()
  if (error) throw new AppError('WITHDRAW_FAILED', error.message, 500)
  return data
}

/** Riwayat buku besar, terbaru dulu. Paginasi berbasis cursor `before` (created_at). */
const listLedger = async ({ bucket = null, limit = 50, before = null } = {}) => {
  const take = Math.min(100, Math.max(1, Number(limit) || 50))
  let q = supabaseAdmin
    .from('finance_ledger')
    .select('id, bucket, direction, amount, source, ref_date, note, created_at')
    .order('created_at', { ascending: false })
    .limit(take + 1)
  if (bucket && BUCKETS.includes(bucket)) q = q.eq('bucket', bucket)
  if (before) q = q.lt('created_at', before)
  const { data, error } = await q
  if (error) throw new AppError('LEDGER_FETCH_FAILED', error.message, 500)
  const rows = data || []
  const hasMore = rows.length > take
  return { items: hasMore ? rows.slice(0, take) : rows, has_more: hasMore }
}
```

- [ ] **Step 2: Route**

```js
const withdrawSchema = z.object({
  bucket: z.enum(['restock', 'operational', 'personal', 'scaling', 'emergency']),
  amount: z.number().int().positive(),
  note: z.string().max(200).optional().nullable(),
})

router.post('/withdraw', async (req, res, next) => {
  try {
    const b = withdrawSchema.parse(req.body)
    const data = await financeService.withdrawFromBucket({
      bucket: b.bucket, amount: b.amount, note: b.note, userId: req.user?.id || null,
    })
    return created(res, data, 'Penarikan dicatat')
  } catch (err) { next(err) }
})

router.get('/ledger', async (req, res, next) => {
  try {
    return success(res, await financeService.listLedger({
      bucket: req.query.bucket || null,
      limit: req.query.limit,
      before: req.query.before || null,
    }))
  } catch (err) { next(err) }
})
```

Tambahkan keduanya ke `module.exports` service.

- [ ] **Step 3: Suite + commit**

```bash
cd "D:/REHAT/rehat-backend/rehat-backend" && npx jest && SUPABASE_URL= npx jest
git add src/services/financeService.js src/routes/finance.js
git commit -m "feat(finance): penarikan pos & riwayat buku besar

Saldo boleh negatif -- modul mencatat kenyataan, rambu di UI yang
memperingatkan. Riwayat pakai paginasi cursor.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 5: Pemicu otomatis saat tutup kasir

**Repo:** `D:\REHAT\rehat-backend\rehat-backend`

**Files:** Modify `src/routes/index.js` (handler `/admin/reports/closing`)

Alokasi harus jalan sendiri, bukan menunggu pemilik menekan tombol.

- [ ] **Step 1: Sisipkan pemicu**

Di handler `GET /admin/reports/closing` (sekitar baris 470), **setelah** laporan berhasil diambil, panggil alokasi untuk tanggal yang sama — dan **jangan biarkan kegagalannya merusak tutup kasir**:

```js
    // Picu alokasi amplop untuk hari itu. Idempoten, jadi aman dipanggil
    // berkali-kali. Kegagalan di sini TIDAK boleh menggagalkan tutup kasir --
    // laporan kasir jauh lebih penting daripada pembukuan amplop.
    try {
      await require('../services/financeService').allocateForDate(date || wibToday())
    } catch (e) {
      console.error('[closing] alokasi amplop gagal:', e.message)
    }
```

Pakai tanggal yang sama dengan yang dipakai laporan tutup kasir — jangan menghitung ulang "hari ini" secara terpisah, nanti bisa meleset di sekitar tengah malam WIB.

- [ ] **Step 2: Verifikasi produksi**

Panggil endpoint tutup kasir dua kali untuk tanggal yang sama (lewat skrip service langsung, karena token HTTP tidak tersedia), lalu hitung baris `finance_ledger` untuk tanggal itu. Harus tetap 5 (atau 6 dengan shortfall), bukan 10.

- [ ] **Step 3: Commit**

```bash
git add src/routes/index.js
git commit -m "feat(finance): picu alokasi otomatis saat tutup kasir

Kegagalan alokasi sengaja ditelan (dengan log) -- laporan tutup kasir
tidak boleh gagal gara-gara pembukuan amplop.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 6: Repository & model Flutter

**Repo:** `c:\Users\thezu\rehat_app`

**Files:**
- Modify: `lib/core/constants/api_constants.dart`, `lib/features/finance/data/finance_repository.dart`
- Test: `test/finance_overview_test.dart`

**Interfaces:**
```dart
class BucketBalances { int restock, operational, personal, scaling, emergency; }
class FinanceGuards { int breakEvenDaily, runwayDays, emergencyPct;
                      bool personalWithdrawBlocked, emergencyReached; }
class FinanceOverview { BucketBalances balances; FinanceGuards guards;
                        int emergencyTarget; String? lastAllocatedDate; }
class LedgerEntry { String id, bucket, direction, source, note; int amount;
                    DateTime createdAt; String refDate; }
// Provider: financeOverviewProvider, ledgerBucketFilterProvider, ledgerProvider
```

Endpoint: `GET /admin/finance/overview`, `POST /admin/finance/withdraw`, `GET /admin/finance/ledger`, `POST /admin/finance/allocate`.

- [ ] **Step 1: TDD parsing** — tulis `test/finance_overview_test.dart` menguji: parsing lengkap, field hilang → 0, saldo negatif terbaca apa adanya, `has_more` terbaca. Jalankan sampai GAGAL.
- [ ] **Step 2: Implementasi** model + method repository + provider, mengikuti pola `finance_repository.dart` yang sudah ada (helper `_int`, `_unwrap`, `ApiException` untuk 404).
- [ ] **Step 3:** `"/c/Users/thezu/flutter/bin/flutter.bat" test test/finance_overview_test.dart` → LULUS.
- [ ] **Step 4:** analyze unscoped + suite penuh, lalu commit.

---

## Task 7: Layar Ringkasan Keuangan

**Repo:** `c:\Users\thezu\rehat_app`
**Files:** Create `lib/features/finance/presentation/finance_overview_screen.dart`, `widgets/bucket_card.dart`; modify router + kartu dashboard.

Isi layar:
- **Lima kartu amplop** dengan saldo. Saldo negatif diwarnai `AppColors.error` — overspend harus terlihat, bukan disembunyikan.
- **Cincin/progres dana darurat** terhadap `emergency_target` (Rp25,8jt), dengan persentasenya.
- **Rambu**: break-even harian vs omzet rata-rata, dan runway operasional ("cukup N hari").
- **Tombol tarik** pada pos Pribadi/Scaling/Darurat. Bila `personalWithdrawBlocked` true, tombol Pribadi berubah merah dan memunculkan dialog konfirmasi yang menjelaskan **konsekuensinya dalam rupiah** — bukan sekadar "yakin?".
- **Peringatan bila `last_allocated_date` tertinggal** dari kemarin — artinya tutup kasir tidak dijalankan dan pembukuan amplop bolong.

Rute baru mengikuti konvensi: pasangan name+path di `RouteNames`, `GoRoute` bersarang di shell branch profile, navigasi `context.pushNamed`. Kartu dashboard "Keuangan" diarahkan ke layar ini (Ringkasan jadi pintu masuk; Laba Rugi & Biaya Tetap dicapai dari sini).

Verifikasi: analyze unscoped bersih + suite lulus.

---

## Task 8: Layar Riwayat buku besar

**Repo:** `c:\Users\thezu\rehat_app`
**Files:** Create `lib/features/finance/presentation/finance_ledger_screen.dart`

- Daftar mutasi terbaru dulu, dengan filter pos (chip).
- Tiap baris: tanggal (via `Formatters.tanggal`), pos, nominal bertanda (+/−), sumber (`alokasi`/`penarikan`/`pengeluaran`/`koreksi`/`kekurangan`) dalam bahasa Indonesia, dan catatan.
- Paginasi "muat lebih banyak" memakai cursor `before`.
- Pola keep-previous-data.

Verifikasi: analyze unscoped bersih + suite lulus.

---

## Task 9: Dokumentasi

**Repo:** keduanya
**Files:** `CLAUDE.md`

- §3: catat bahwa Tahap 2 **tidak** menambah migrasi (memakai tabel dari 016).
- §5: tambahkan modul amplop alokasi ke inventaris fitur admin.
- §4: gotcha baru — idempotensi alokasi bergantung pada unique index parsial, bukan pengecekan aplikasi; alokasi dipicu tutup kasir dan kegagalannya sengaja ditelan; saldo pos boleh negatif; alokasi tidak berjalan sebelum `started_on` (2026-08-09), jadi Juli tidak akan pernah teralokasi.
- §6: daftar endpoint baru.
- §8: perbarui status.

---

## Definition of Done — Tahap 2

- [ ] `npx jest` backend hijau, dan tetap hijau tanpa kredensial
- [ ] `flutter analyze --fatal-infos` (unscoped) bersih, `flutter test` hijau
- [ ] Memanggil alokasi dua kali untuk tanggal sama → ledger tetap 5–6 baris
- [ ] Σ alokasi satu hari **persis** sama dengan omzet hari itu
- [ ] `breakEvenDaily` ≈ Rp489.000 pada data produksi
- [ ] Token `irur` → seluruh endpoint baru membalas **404**
- [ ] Tutup kasir dua kali tidak menggandakan alokasi

## Belum termasuk (Tahap 3)

Auto-kalibrasi (penyaringan sampel, shrinkage `w = n/(n+30)`, deadband 2 poin persen selama 14 hari, batas gerak ±3 poin/bulan, kartu usulan) **dan wizard kalibrasi** yang menyertainya.
