# Filter Rentang Tanggal di Laporan Penjualan — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tambah filter rentang tanggal bebas (start–end, maks 90 hari) di layar `Laporan Penjualan`, terpisah dari pill preset (Hari ini/7 Hari/30 Hari) dan tombol tanggal tunggal yang sudah ada.

**Architecture:** Perluas `getSalesReport`/`expenseService.rangeBounds` yang sudah ada dengan parameter `endDate` opsional (bukan endpoint/fungsi baru). Frontend menambah satu `StateProvider<DateTimeRange?>` baru (`salesDateRangeProvider`) yang menang atas tanggal tunggal & pill saat diisi, dan satu tombol UI baru di sebelah "Pilih tanggal".

**Tech Stack:** Backend: Node/Express/Supabase (repo `D:\REHAT\rehat-backend\rehat-backend`), Jest+Supertest. Frontend: Flutter/Riverpod (repo ini), `flutter_test`.

## Global Constraints

- Rentang tanggal kustom maks **90 hari** (inklusif) — divalidasi di frontend (sebelum request) **dan** backend (defense-in-depth) untuk `/admin/reports/sales`. Tidak divalidasi di `/admin/expenses` (di luar cakupan spec §3.1).
- `date` menang atas `range`; rentang kustom (`date`+`end`) menang atas `date`-saja. Precedence ini TIDAK BOLEH mengubah perilaku existing (mode `date`-saja & mode `range` preset harus identik output-nya dengan sebelum perubahan).
- Kalender Penjualan (grid bulanan) **tidak** disentuh sama sekali oleh plan ini.
- Referensi desain lengkap: `docs/superpowers/specs/2026-08-23-filter-rentang-tanggal-laporan-design.md`.

---

## Task 1: Backend — `getSalesReport` menerima rentang tanggal kustom

**Files:**
- Modify: `D:\REHAT\rehat-backend\rehat-backend\src\services\orderService.js` (fungsi `getSalesReport`, sekitar baris 629-646)
- Test: `D:\REHAT\rehat-backend\rehat-backend\src\services\__tests__\salesReportRange.test.js` (baru)

**Interfaces:**
- Produces: `getSalesReport(range = '7d', date = null, endDate = null)` — signature baru (parameter ketiga `endDate`, opsional, default `null`, 100% backward compatible). Bentuk return TIDAK berubah (`{ range, date, start, summary, series, top_items }`).

- [ ] **Step 1: Tulis test yang gagal**

Buat `D:\REHAT\rehat-backend\rehat-backend\src\services\__tests__\salesReportRange.test.js`:

```js
// Mengikuti pola stub di financePnl.test.js: stub src/config/supabase SEBELUM
// orderService di-require (createClient() eager meledak tanpa SUPABASE_URL
// asli). Builder menghormati .range(from,to) sungguhan (slice fixture) supaya
// test paginasi (kalau kelak ada >1000 baris di rentang kustom) tidak curang.
let ordersFixture = []

const makeOrdersBuilder = () => {
  const b = {}
  let rangeFrom = 0
  let rangeTo = ordersFixture.length - 1
  b.select = () => b
  b.in = () => b
  b.gte = () => b
  b.lte = () => b
  b.order = () => b
  b.range = (from, to) => {
    rangeFrom = from
    rangeTo = to
    return b
  }
  b.then = (resolve) => {
    resolve({ data: ordersFixture.slice(rangeFrom, rangeTo + 1), error: null })
  }
  return b
}

jest.mock('../../config/supabase', () => ({
  supabaseAdmin: { from: () => makeOrdersBuilder() },
}))

const { getSalesReport } = require('../orderService')

describe('getSalesReport — rentang tanggal kustom (date + endDate)', () => {
  test('menjumlah omzet 3 hari WIB berturut-turut, series berisi 3 titik sesuai tanggal', async () => {
    ordersFixture = [
      // 2026-07-05T03:00:00.000Z + 7 jam = 10:00 WIB 5 Jul.
      { total: 10000, status: 'completed', payment_method: 'cash', ordered_at: '2026-07-05T03:00:00.000Z', order_items: [] },
      { total: 20000, status: 'completed', payment_method: 'cash', ordered_at: '2026-07-06T03:00:00.000Z', order_items: [] },
      { total: 30000, status: 'completed', payment_method: 'cash', ordered_at: '2026-07-07T03:00:00.000Z', order_items: [] },
    ]

    const result = await getSalesReport('7d', '2026-07-05', '2026-07-07')

    expect(result.summary.revenue).toBe(60000)
    expect(result.summary.orders).toBe(3)
    expect(result.series).toEqual([
      { date: '2026-07-05', revenue: 10000, orders: 1 },
      { date: '2026-07-06', revenue: 20000, orders: 1 },
      { date: '2026-07-07', revenue: 30000, orders: 1 },
    ])
  })

  test('rentang lintas bulan menghasilkan dayBuckets yang benar melewati batas bulan', async () => {
    ordersFixture = [
      { total: 5000, status: 'completed', payment_method: 'cash', ordered_at: '2026-07-30T03:00:00.000Z', order_items: [] },
      { total: 7000, status: 'completed', payment_method: 'cash', ordered_at: '2026-08-01T03:00:00.000Z', order_items: [] },
    ]

    const result = await getSalesReport('7d', '2026-07-30', '2026-08-02')

    expect(result.series.map((p) => p.date)).toEqual([
      '2026-07-30', '2026-07-31', '2026-08-01', '2026-08-02',
    ])
    expect(result.summary.revenue).toBe(12000)
  })

  test('rentang 1 hari (date === endDate) menghasilkan hasil identik dengan mode date-saja', async () => {
    ordersFixture = [
      { total: 15000, status: 'completed', payment_method: 'qris', ordered_at: '2026-07-05T03:00:00.000Z', order_items: [] },
    ]

    const single = await getSalesReport('7d', '2026-07-05')
    const rangeOfOne = await getSalesReport('7d', '2026-07-05', '2026-07-05')

    expect(rangeOfOne.summary.revenue).toBe(single.summary.revenue)
    expect(rangeOfOne.summary.orders).toBe(single.summary.orders)
    expect(rangeOfOne.series).toEqual(single.series)
  })
})
```

- [ ] **Step 2: Jalankan test, pastikan GAGAL**

Run: `cd D:\REHAT\rehat-backend\rehat-backend && npx jest salesReportRange`
Expected: FAIL — test pertama & kedua gagal karena `date`+`endDate` masih diperlakukan sebagai mode 1-hari (endDate diabaikan), jadi `series` cuma berisi 1 titik, bukan 3/4.

- [ ] **Step 3: Implementasi minimal**

Di `orderService.js`, ganti fungsi `getSalesReport` (baris ~629-646):

```js
/**
 * Agregasi penjualan untuk dashboard admin.
 * @param {'today'|'7d'|'30d'} range rentang waktu (default '7d').
 * @param {string|null} date tanggal spesifik YYYY-MM-DD, atau awal rentang kustom bila `endDate` juga diisi.
 * @param {string|null} endDate akhir rentang kustom YYYY-MM-DD. Diabaikan bila `date` kosong.
 */
const getSalesReport = async (range = '7d', date = null, endDate = null) => {
  // Semua batas hari dihitung dalam WIB (bukan UTC server).
  let start, end, days
  if (date && endDate) {
    // Rentang tanggal kustom (YYYY-MM-DD..YYYY-MM-DD) → laporan multi-hari WIB.
    start = new Date(wibDayRange(date).start)
    end = new Date(wibDayRange(endDate).end)
    days = Math.round(
      (new Date(`${endDate}T00:00:00Z`) - new Date(`${date}T00:00:00Z`)) / 86400000
    ) + 1
  } else if (date) {
    // Tanggal spesifik (YYYY-MM-DD) → laporan satu hari WIB.
    const r = wibDayRange(date)
    start = new Date(r.start)
    end = new Date(r.end)
    days = 1
  } else {
    days = range === 'today' ? 1 : (range === '30d' ? 30 : 7)
    start = new Date(wibStartOfDaysAgo(days - 1))
    end = new Date(wibDayRange(wibDateKey()).end)
  }
```

(Baris-baris setelah blok `if/else` ini — query berpaginasi, `dayBuckets`, dst. — TIDAK berubah sama sekali.)

- [ ] **Step 4: Jalankan test, pastikan LULUS**

Run: `cd D:\REHAT\rehat-backend\rehat-backend && npx jest salesReportRange`
Expected: PASS — 3 test lulus.

- [ ] **Step 5: Commit**

```bash
cd D:\REHAT\rehat-backend\rehat-backend
git add src/services/orderService.js src/services/__tests__/salesReportRange.test.js
git commit -m "feat: getSalesReport terima rentang tanggal kustom (date+endDate)"
```

---

## Task 2: Backend — route `/admin/reports/sales` terima `end` + validasi 90 hari

**Files:**
- Modify: `D:\REHAT\rehat-backend\rehat-backend\src\routes\index.js` (route `GET /admin/reports/sales`, sekitar baris 457-465)
- Test: `D:\REHAT\rehat-backend\rehat-backend\src\routes\__tests__\salesReportRange.test.js` (baru)

**Interfaces:**
- Consumes: `orderService.getSalesReport(range, date, endDate)` dari Task 1.
- Produces: `GET /admin/reports/sales?date=YYYY-MM-DD&end=YYYY-MM-DD` — param `end` baru, opsional. `end` tanpa `date` diabaikan. Rentang >90 hari → `400 { success:false, error:{ code:'RANGE_TOO_LARGE' } }`.

- [ ] **Step 1: Tulis test yang gagal**

Buat `D:\REHAT\rehat-backend\rehat-backend\src\routes\__tests__\salesReportRange.test.js`:

```js
// Pola mock mengikuti closingAllocation.test.js: stub src/config/supabase
// (generik, tak tersentuh karena getSalesReport di-mock), mock
// orderService.getSalesReport (sudah punya test sendiri di Task 1) supaya di
// sini kita HANYA menguji lem di route: parsing query `end`, validasi 90
// hari, dan argumen yang diteruskan ke service.

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret'
process.env.ADMIN_API_KEY = process.env.ADMIN_API_KEY || 'test-admin-key'

jest.mock('../../config/supabase', () => ({
  supabaseAdmin: {
    from: () => {
      const generic = {}
      const chain = () => generic
      Object.assign(generic, {
        select: chain, eq: chain, gte: chain, lte: chain, in: chain,
        order: chain, limit: chain, or: chain, range: chain,
        maybeSingle: () => Promise.resolve({ data: null, error: null }),
        single: () => Promise.resolve({ data: null, error: null }),
        then: (resolve) => resolve({ data: [], error: null, count: 0 }),
      })
      return generic
    },
  },
}))

jest.mock('../../services/orderService', () => {
  const actual = jest.requireActual('../../services/orderService')
  return { ...actual, getSalesReport: jest.fn() }
})

const express = require('express')
const request = require('supertest')
const orderService = require('../../services/orderService')
const routes = require('../index')

const app = express()
app.use(express.json())
app.use('/v1', routes)

const FAKE_REPORT = { range: '7d', summary: { revenue: 0 }, series: [], top_items: [] }

beforeEach(() => {
  orderService.getSalesReport.mockReset().mockResolvedValue({ ...FAKE_REPORT })
})

describe('GET /admin/reports/sales -- parameter `end` (rentang kustom)', () => {
  test('date + end valid (<=90 hari) -> getSalesReport dipanggil dgn ketiga argumen', async () => {
    const res = await request(app)
      .get('/v1/admin/reports/sales?date=2026-07-01&end=2026-07-10')
      .set('x-admin-key', process.env.ADMIN_API_KEY)

    expect(res.status).toBe(200)
    expect(orderService.getSalesReport).toHaveBeenCalledWith('7d', '2026-07-01', '2026-07-10')
  })

  test('end tanpa date -> diabaikan, getSalesReport dipanggil tanpa end', async () => {
    const res = await request(app)
      .get('/v1/admin/reports/sales?end=2026-07-10')
      .set('x-admin-key', process.env.ADMIN_API_KEY)

    expect(res.status).toBe(200)
    expect(orderService.getSalesReport).toHaveBeenCalledWith('7d', null, null)
  })

  test('rentang >90 hari -> 400 RANGE_TOO_LARGE, getSalesReport TIDAK dipanggil', async () => {
    const res = await request(app)
      .get('/v1/admin/reports/sales?date=2026-01-01&end=2026-12-31')
      .set('x-admin-key', process.env.ADMIN_API_KEY)

    expect(res.status).toBe(400)
    expect(res.body.error.code).toBe('RANGE_TOO_LARGE')
    expect(orderService.getSalesReport).not.toHaveBeenCalled()
  })

  test('rentang persis 90 hari (2026-07-01..2026-09-28) -> diterima (boundary)', async () => {
    const res = await request(app)
      .get('/v1/admin/reports/sales?date=2026-07-01&end=2026-09-28')
      .set('x-admin-key', process.env.ADMIN_API_KEY)

    expect(res.status).toBe(200)
    expect(orderService.getSalesReport).toHaveBeenCalledWith('7d', '2026-07-01', '2026-09-28')
  })

  test('tanpa kredensial admin -> ditolak (401), getSalesReport tidak dipanggil', async () => {
    const res = await request(app).get('/v1/admin/reports/sales?date=2026-07-01&end=2026-07-10')
    expect(res.status).toBe(401)
    expect(orderService.getSalesReport).not.toHaveBeenCalled()
  })
})
```

- [ ] **Step 2: Jalankan test, pastikan GAGAL**

Run: `cd D:\REHAT\rehat-backend\rehat-backend && npx jest routes/__tests__/salesReportRange`
Expected: FAIL — route belum mengenal query `end` sama sekali, jadi `getSalesReport` selalu dipanggil dengan 2 argumen saja dan test >90 hari tidak mendapat 400.

- [ ] **Step 3: Implementasi minimal**

Di `routes/index.js`, ganti handler `GET /admin/reports/sales` (baris ~457-465):

```js
// (Admin) Laporan penjualan agregat (?range=today|7d|30d, ?date=YYYY-MM-DD,
// atau rentang kustom ?date=YYYY-MM-DD&end=YYYY-MM-DD, maks 90 hari).
router.get('/admin/reports/sales', adminAccess, async (req, res, next) => {
  try {
    const range = ['today', '7d', '30d'].includes(req.query.range) ? req.query.range : '7d'
    const date = /^\d{4}-\d{2}-\d{2}$/.test(req.query.date || '') ? req.query.date : null
    const end = date && /^\d{4}-\d{2}-\d{2}$/.test(req.query.end || '') ? req.query.end : null
    if (date && end) {
      const spanDays = Math.round(
        (new Date(`${end}T00:00:00Z`) - new Date(`${date}T00:00:00Z`)) / 86400000
      ) + 1
      if (spanDays > 90) return fail(res, 'RANGE_TOO_LARGE', 'Rentang maksimal 90 hari', 400)
    }
    const data = await orderService.getSalesReport(range, date, end)
    return success(res, data)
  } catch (err) { next(err) }
})
```

- [ ] **Step 4: Jalankan test, pastikan LULUS**

Run: `cd D:\REHAT\rehat-backend\rehat-backend && npx jest routes/__tests__/salesReportRange`
Expected: PASS — 5 test lulus.

- [ ] **Step 5: Commit**

```bash
cd D:\REHAT\rehat-backend\rehat-backend
git add src/routes/index.js src/routes/__tests__/salesReportRange.test.js
git commit -m "feat: route /admin/reports/sales terima rentang kustom (end, maks 90 hari)"
```

---

## Task 3: Backend — `expenseService` & route `/admin/expenses` ikut rentang kustom

**Files:**
- Modify: `D:\REHAT\rehat-backend\rehat-backend\src\services\expenseService.js` (`rangeBounds` baris ~6-19, `listExpenses` baris ~146-168)
- Modify: `D:\REHAT\rehat-backend\rehat-backend\src\routes\index.js` (route `GET /admin/expenses`, sekitar baris 683-690)
- Test: `D:\REHAT\rehat-backend\rehat-backend\src\services\__tests__\expenseRangeBounds.test.js` (baru)

**Interfaces:**
- Produces: `rangeBounds(range = '7d', date = null, endDate = null)` dan `listExpenses({ range, date, endDate })` — parameter baru, opsional, backward compatible.

- [ ] **Step 1: Tulis test yang gagal**

Buat `D:\REHAT\rehat-backend\rehat-backend\src\services\__tests__\expenseRangeBounds.test.js`:

```js
// rangeBounds murni (tanpa DB) -- stub kosong cukup, mengikuti pola
// expenseBucket.test.js. Fake timers dipakai supaya perbandingan cabang
// preset (yang memakai `new Date()` internal) deterministik.
jest.mock('../../config/supabase', () => ({ supabaseAdmin: {} }))

const { rangeBounds } = require('../expenseService')

describe('rangeBounds — rentang tanggal kustom (date + endDate)', () => {
  beforeEach(() => {
    jest.useFakeTimers({ doNotFake: ['nextTick', 'setImmediate'] })
    jest.setSystemTime(new Date('2026-08-23T05:00:00.000Z'))
  })

  afterEach(() => {
    jest.useRealTimers()
  })

  test('date + endDate -> rentang mencakup persis 3 hari penuh (endDate inklusif)', () => {
    const [start, end] = rangeBounds('7d', '2026-07-05', '2026-07-07')
    const spanMs = new Date(end).getTime() - new Date(start).getTime()
    expect(spanMs).toBe(3 * 86400000 - 1)
  })

  test('endDate tanpa date -> diabaikan, hasil sama dgn preset range', () => {
    const withEndOnly = rangeBounds('7d', null, '2026-07-07')
    const preset = rangeBounds('7d', null)
    expect(withEndOnly).toEqual(preset)
  })

  test('date saja (tanpa endDate) -> perilaku lama tidak berubah (rentang 1 hari)', () => {
    const [start, end] = rangeBounds('7d', '2026-07-05')
    const spanMs = new Date(end).getTime() - new Date(start).getTime()
    expect(spanMs).toBe(86400000 - 1)
  })
})
```

- [ ] **Step 2: Jalankan test, pastikan GAGAL**

Run: `cd D:\REHAT\rehat-backend\rehat-backend && npx jest expenseRangeBounds`
Expected: FAIL — test pertama gagal (`endDate` belum dikenal parameter ketiga, jadi rentang tetap 1 hari, bukan 3).

- [ ] **Step 3: Implementasi minimal**

Di `expenseService.js`, ganti `rangeBounds` (baris ~6-19):

```js
// Rentang → [startIso, endIso]. `date` (YYYY-MM-DD) menang atas `range`.
// `date`+`endDate` bersama-sama → rentang kustom inklusif.
const rangeBounds = (range = '7d', date = null, endDate = null) => {
  if (date && endDate) {
    const d = new Date(`${date}T00:00:00`)
    const e = new Date(`${endDate}T00:00:00`)
    const end = new Date(e.getTime() + 86400000 - 1)
    return [d.toISOString(), end.toISOString()]
  }
  if (date) {
    const d = new Date(`${date}T00:00:00`)
    const end = new Date(d.getTime() + 86400000 - 1)
    return [d.toISOString(), end.toISOString()]
  }
  const now = new Date()
  const end = now.toISOString()
  const start = new Date()
  if (range === 'today') start.setHours(0, 0, 0, 0)
  else if (range === '30d') { start.setTime(now.getTime() - 29 * 86400000); start.setHours(0, 0, 0, 0) }
  else { start.setTime(now.getTime() - 6 * 86400000); start.setHours(0, 0, 0, 0) }
  return [start.toISOString(), end]
}
```

Lalu ganti baris pertama `listExpenses` (baris ~146-147) dari:

```js
const listExpenses = async ({ range = '7d', date = null } = {}) => {
  const [start, end] = rangeBounds(range, date)
```

menjadi:

```js
const listExpenses = async ({ range = '7d', date = null, endDate = null } = {}) => {
  const [start, end] = rangeBounds(range, date, endDate)
```

- [ ] **Step 4: Jalankan test, pastikan LULUS**

Run: `cd D:\REHAT\rehat-backend\rehat-backend && npx jest expenseRangeBounds`
Expected: PASS — 3 test lulus.

- [ ] **Step 5: Sambungkan route `/admin/expenses`**

Di `routes/index.js`, ganti handler `GET /admin/expenses` (baris ~683-690):

```js
router.get('/admin/expenses', adminAccess, async (req, res, next) => {
  try {
    const range = ['today', '7d', '30d'].includes(req.query.range) ? req.query.range : '7d'
    const date = /^\d{4}-\d{2}-\d{2}$/.test(req.query.date || '') ? req.query.date : null
    const endDate = /^\d{4}-\d{2}-\d{2}$/.test(req.query.end || '') ? req.query.end : null
    const data = await expenseService.listExpenses({ range, date, endDate })
    return success(res, data)
  } catch (err) { next(err) }
})
```

- [ ] **Step 6: Jalankan SELURUH test suite backend, pastikan tidak ada regresi**

Run: `cd D:\REHAT\rehat-backend\rehat-backend && npx jest`
Expected: PASS — semua test (termasuk yang sudah ada sebelum plan ini) tetap lulus.

- [ ] **Step 7: Commit**

```bash
cd D:\REHAT\rehat-backend\rehat-backend
git add src/services/expenseService.js src/routes/index.js src/services/__tests__/expenseRangeBounds.test.js
git commit -m "feat: expenseService & route /admin/expenses ikut rentang tanggal kustom"
```

---

## Task 4: Frontend — `Formatters.rentang` (label rentang tanggal)

**Files:**
- Modify: `lib\core\utils\formatters.dart`
- Test: `test\formatters_rentang_test.dart` (baru)

**Interfaces:**
- Produces: `Formatters.rentang(DateTime start, DateTime end) -> String` — mis. `"23 Agu – 30 Agu 2026"` (tahun awal disembunyikan bila sama dengan tahun akhir).

- [ ] **Step 1: Tulis test yang gagal**

Buat `test\formatters_rentang_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rehat_app/core/utils/formatters.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  group('Formatters.rentang', () {
    test('tahun sama -> tahun awal disembunyikan, en dash memisahkan', () {
      // 2026-08-22T17:00:00Z + 7 jam = 2026-08-23 00:00 WIB.
      final start = DateTime.utc(2026, 8, 22, 17);
      // 2026-08-29T16:59:59.999Z + 7 jam = 2026-08-29 23:59:59.999 WIB.
      final end = DateTime.utc(2026, 8, 29, 16, 59, 59, 999);

      expect(Formatters.rentang(start, end), '23 Agu – 29 Agu 2026');
    });

    test('tahun beda -> tahun awal ikut ditampilkan', () {
      // 2025-12-29T17:00:00Z + 7 jam = 2025-12-30 00:00 WIB.
      final start = DateTime.utc(2025, 12, 29, 17);
      // 2026-01-02T16:59:59.999Z + 7 jam = 2026-01-02 23:59:59.999 WIB.
      final end = DateTime.utc(2026, 1, 2, 16, 59, 59, 999);

      expect(Formatters.rentang(start, end), '30 Des 2025 – 2 Jan 2026');
    });
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan GAGAL**

Run: `C:\Users\thezu\flutter\bin\flutter.bat test test\formatters_rentang_test.dart`
Expected: FAIL — kompilasi gagal, `Formatters.rentang` belum ada.

- [ ] **Step 3: Implementasi minimal**

Di `lib\core\utils\formatters.dart`, tambahkan method baru setelah `jam()` (sebelum penutup `}` class, baris ~37):

```dart
  /// Format rentang tanggal menjadi "23 Agu – 30 Agu 2026" (WIB). Tahun pada
  /// tanggal awal disembunyikan bila sama dengan tahun akhir (ringkas untuk
  /// tombol filter rentang di Laporan Penjualan).
  static String rentang(DateTime start, DateTime end) {
    final s = toWib(start);
    final e = toWib(end);
    final startFmt = s.year == e.year
        ? DateFormat('d MMM', 'id_ID').format(s)
        : DateFormat('d MMM yyyy', 'id_ID').format(s);
    final endFmt = DateFormat('d MMM yyyy', 'id_ID').format(e);
    return '$startFmt – $endFmt';
  }
```

- [ ] **Step 4: Jalankan test, pastikan LULUS**

Run: `C:\Users\thezu\flutter\bin\flutter.bat test test\formatters_rentang_test.dart`
Expected: PASS — 2 test lulus.

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/formatters.dart test/formatters_rentang_test.dart
git commit -m "feat: Formatters.rentang untuk label filter rentang tanggal"
```

---

## Task 5: Frontend — `AdminReportRepository` & provider rentang tanggal

**Files:**
- Modify: `lib\features\admin\data\admin_report_repository.dart`
- Test: `test\admin_report_repository_range_test.dart` (baru)

**Interfaces:**
- Consumes: tidak ada (murni perluasan repository/provider yang sudah ada).
- Produces:
  - `AdminReportRepository.fetchSales({String range, String? date, String? endDate})` — parameter `endDate` baru.
  - `AdminReportRepository.fetchExpenses({String range, String? date, String? endDate})` — parameter `endDate` baru.
  - `salesDateRangeProvider` (`StateProvider<DateTimeRange?>`, default `null`) — dipakai Task 6.
  - `salesReportProvider`/`expensesProvider` — watch provider baru, prioritas `salesDateRangeProvider` > `salesDateProvider` > `salesRangeProvider`.

- [ ] **Step 1: Tulis test yang gagal**

Buat `test\admin_report_repository_range_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/core/network/dio_client.dart';
import 'package:rehat_app/core/storage/secure_storage.dart';
import 'package:rehat_app/features/admin/data/admin_report_repository.dart';

/// `AdminReportRepository.fetchSales`/`fetchExpenses` -- filter rentang
/// tanggal kustom. Query param JARINGAN sungguhan (`end`) diverifikasi lewat
/// adapter Dio palsu (pola sama seperti admin_report_repository_expense_test.dart),
/// bukan fake repository yang tidak pernah menyentuh kode aslinya.
class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;
  String body = '{"success":true,"data":{}}';

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    lastOptions = options;
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _CapturingAdapter adapter;
  late AdminReportRepository repo;

  setUp(() {
    adapter = _CapturingAdapter();
    final client = DioClient(storage: SecureStorage());
    client.raw.interceptors.clear();
    client.raw.httpClientAdapter = adapter;
    repo = AdminReportRepository(client: client);
  });

  test('fetchSales mengirim query `end` saat endDate diisi', () async {
    await repo
        .fetchSales(date: '2026-07-01', endDate: '2026-07-10')
        .timeout(const Duration(seconds: 10));

    final uri = adapter.lastOptions!.uri;
    expect(uri.queryParameters['date'], '2026-07-01');
    expect(uri.queryParameters['end'], '2026-07-10');
  });

  test('fetchSales TIDAK mengirim query `end` saat endDate null', () async {
    await repo.fetchSales(date: '2026-07-01').timeout(const Duration(seconds: 10));

    final uri = adapter.lastOptions!.uri;
    expect(uri.queryParameters['date'], '2026-07-01');
    expect(uri.queryParameters.containsKey('end'), isFalse);
  });

  test('fetchExpenses mengirim query `end` saat endDate diisi', () async {
    adapter.body = '{"success":true,"data":{"items":[],"total":0}}';
    await repo
        .fetchExpenses(date: '2026-07-01', endDate: '2026-07-10')
        .timeout(const Duration(seconds: 10));

    final uri = adapter.lastOptions!.uri;
    expect(uri.queryParameters['end'], '2026-07-10');
  });
}
```

- [ ] **Step 2: Jalankan test, pastikan GAGAL**

Run: `C:\Users\thezu\flutter\bin\flutter.bat test test\admin_report_repository_range_test.dart`
Expected: FAIL — kompilasi gagal, `fetchSales`/`fetchExpenses` belum punya parameter `endDate`.

- [ ] **Step 3: Implementasi minimal**

Di `admin_report_repository.dart`, tambahkan import di baris atas (setelah `import 'package:flutter_riverpod/flutter_riverpod.dart';`):

```dart
import 'package:flutter/material.dart';
```

Ganti `fetchSales` (baris ~300-307):

```dart
  /// [date] (YYYY-MM-DD) menang atas [range] bila diisi. [endDate] (opsional,
  /// juga YYYY-MM-DD) mengubah [date] jadi awal rentang kustom — WAJIB
  /// dikirim bersama [date], diabaikan backend bila [date] kosong.
  Future<SalesReport> fetchSales(
      {String range = '7d', String? date, String? endDate}) async {
    final res = await _client.get<dynamic>(
      ApiConstants.adminSalesReport,
      query: {
        'range': range,
        if (date != null) 'date': date,
        if (endDate != null) 'end': endDate,
      },
    );
    return SalesReport.fromJson(_unwrap(res.data));
  }
```

Ganti `fetchExpenses` (baris ~324-338):

```dart
  Future<ExpenseList> fetchExpenses(
      {String range = '7d', String? date, String? endDate}) async {
    final res = await _client.get<dynamic>(
      ApiConstants.adminExpenses,
      query: {
        'range': range,
        if (date != null) 'date': date,
        if (endDate != null) 'end': endDate,
      },
    );
    final data = _unwrap(res.data);
    final items = (data['items'] as List?) ?? const [];
    return ExpenseList(
      items: items
          .whereType<Map>()
          .map((e) => ExpenseItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      total: _int(data['total']),
    );
  }
```

- [ ] **Step 4: Jalankan test, pastikan LULUS**

Run: `C:\Users\thezu\flutter\bin\flutter.bat test test\admin_report_repository_range_test.dart`
Expected: PASS — 3 test lulus.

- [ ] **Step 5: Tambah provider rentang & sambungkan prioritas**

Di `admin_report_repository.dart`, tambahkan provider baru setelah `salesDateProvider` (baris ~382):

```dart
/// Tanggal spesifik yang dipilih (null = pakai pill rentang).
final salesDateProvider = StateProvider<DateTime?>((ref) => null);

/// Rentang tanggal kustom yang dipilih (null = pakai pill/tanggal tunggal).
/// Menang atas [salesDateProvider] & [salesRangeProvider] bila diisi (lihat
/// wiring saling meng-null-kan di admin_dashboard_screen.dart).
final salesDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);
```

Lalu ganti `salesReportProvider` & `expensesProvider` (baris ~391-408):

```dart
/// Laporan penjualan untuk rentang/tanggal aktif.
final salesReportProvider = FutureProvider<SalesReport>((ref) {
  final range = ref.watch(salesRangeProvider);
  final date = ref.watch(salesDateProvider);
  final dateRange = ref.watch(salesDateRangeProvider);
  return ref.watch(adminReportRepositoryProvider).fetchSales(
        range: range,
        date: dateRange != null
            ? _fmtDate(dateRange.start)
            : (date != null ? _fmtDate(date) : null),
        endDate: dateRange != null ? _fmtDate(dateRange.end) : null,
      );
});

/// Pengeluaran untuk rentang/tanggal aktif (mengikuti pilihan laporan).
final expensesProvider = FutureProvider<ExpenseList>((ref) {
  final range = ref.watch(salesRangeProvider);
  final date = ref.watch(salesDateProvider);
  final dateRange = ref.watch(salesDateRangeProvider);
  return ref.watch(adminReportRepositoryProvider).fetchExpenses(
        range: range,
        date: dateRange != null
            ? _fmtDate(dateRange.start)
            : (date != null ? _fmtDate(date) : null),
        endDate: dateRange != null ? _fmtDate(dateRange.end) : null,
      );
});
```

- [ ] **Step 6: `flutter analyze` bersih**

Run: `C:\Users\thezu\flutter\bin\flutter.bat analyze lib/features/admin/data/admin_report_repository.dart`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/features/admin/data/admin_report_repository.dart test/admin_report_repository_range_test.dart
git commit -m "feat: AdminReportRepository & salesDateRangeProvider untuk rentang tanggal kustom"
```

---

## Task 6: Frontend — tombol "Rentang tanggal" di `AdminDashboardScreen`

**Files:**
- Modify: `lib\features\admin\presentation\admin_dashboard_screen.dart` (baris ~24-130)

**Interfaces:**
- Consumes: `salesDateRangeProvider`, `Formatters.rentang` dari Task 4 & 5.

- [ ] **Step 1: Baca ulang blok yang akan diubah untuk memastikan anchor masih cocok**

Run: buka `lib\features\admin\presentation\admin_dashboard_screen.dart`, konfirmasi baris 24-130 masih sama persis dengan cuplikan di bawah (belum ada perubahan lain sejak plan ini ditulis):

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(salesRangeProvider);
    final date = ref.watch(salesDateProvider);
    final async = ref.watch(salesReportProvider);

    Future<void> pickDate() async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: date ?? now,
        firstDate: DateTime(now.year - 2),
        lastDate: now,
      );
      if (picked != null) ref.read(salesDateProvider.notifier).state = picked;
    }
```

- [ ] **Step 2: Tambah state `dateRange` & fungsi `pickDateRange`**

Ganti blok di atas dengan:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(salesRangeProvider);
    final date = ref.watch(salesDateProvider);
    final dateRange = ref.watch(salesDateRangeProvider);
    final async = ref.watch(salesReportProvider);

    Future<void> pickDate() async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: date ?? now,
        firstDate: DateTime(now.year - 2),
        lastDate: now,
      );
      if (picked != null) {
        ref.read(salesDateProvider.notifier).state = picked;
        ref.read(salesDateRangeProvider.notifier).state = null;
      }
    }

    Future<void> pickDateRange() async {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        initialDateRange: dateRange,
        firstDate: DateTime(now.year - 2),
        lastDate: now,
      );
      if (picked == null) return;
      final spanDays = picked.end.difference(picked.start).inDays + 1;
      if (spanDays > 90) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
              const SnackBar(content: Text('Rentang maksimal 90 hari')));
        return;
      }
      ref.read(salesDateRangeProvider.notifier).state = picked;
      ref.read(salesDateProvider.notifier).state = null;
    }
```

- [ ] **Step 3: Pill juga meng-null-kan `salesDateRangeProvider`**

Cari blok pill (dalam `for (final (value, label) in _ranges)`), ganti:

```dart
                        child: NeuButton(
                          onPressed: () {
                            ref.read(salesRangeProvider.notifier).state = value;
                            ref.read(salesDateProvider.notifier).state = null;
                          },
                          accent: value == range && date == null,
                          radius: 11,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            label,
                            style: AppTextStyles.caption.copyWith(
                              color: value == range && date == null
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
```

menjadi:

```dart
                        child: NeuButton(
                          onPressed: () {
                            ref.read(salesRangeProvider.notifier).state = value;
                            ref.read(salesDateProvider.notifier).state = null;
                            ref.read(salesDateRangeProvider.notifier).state = null;
                          },
                          accent: value == range && date == null && dateRange == null,
                          radius: 11,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            label,
                            style: AppTextStyles.caption.copyWith(
                              color: value == range && date == null && dateRange == null
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
```

- [ ] **Step 4: Ganti Row "Pilih tanggal" jadi dua tombol berdampingan**

Cari blok (persis setelah `const SizedBox(height: 10),` yang mengikuti pill):

```dart
            const SizedBox(height: 10),
            // Pilih tanggal spesifik.
            Row(
              children: [
                Expanded(
                  child: NeuButton(
                    onPressed: pickDate,
                    accent: date != null,
                    radius: 12,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 16,
                            color: date != null
                                ? Colors.white
                                : AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          date != null
                              ? Formatters.tanggal(date)
                              : 'Pilih tanggal',
                          style: AppTextStyles.caption.copyWith(
                            color: date != null
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (date != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () =>
                        ref.read(salesDateProvider.notifier).state = null,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Hapus filter tanggal',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
```

Ganti dengan:

```dart
            const SizedBox(height: 10),
            // Pilih tanggal spesifik ATAU rentang tanggal kustom (saling
            // menggantikan pill di atas & satu sama lain).
            Row(
              children: [
                Expanded(
                  child: NeuButton(
                    onPressed: pickDate,
                    accent: date != null,
                    radius: 12,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 16,
                            color: date != null
                                ? Colors.white
                                : AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            date != null
                                ? Formatters.tanggal(date)
                                : 'Pilih tanggal',
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: date != null
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (date != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () =>
                        ref.read(salesDateProvider.notifier).state = null,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Hapus filter tanggal',
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: NeuButton(
                    onPressed: pickDateRange,
                    accent: dateRange != null,
                    radius: 12,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.date_range_rounded,
                            size: 16,
                            color: dateRange != null
                                ? Colors.white
                                : AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            dateRange != null
                                ? Formatters.rentang(
                                    dateRange.start, dateRange.end)
                                : 'Rentang tanggal',
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: dateRange != null
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (dateRange != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () =>
                        ref.read(salesDateRangeProvider.notifier).state = null,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Hapus filter rentang',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
```

- [ ] **Step 5: `flutter analyze` bersih**

Run: `C:\Users\thezu\flutter\bin\flutter.bat analyze lib/features/admin/presentation/admin_dashboard_screen.dart`
Expected: `No issues found!`

- [ ] **Step 6: Jalankan seluruh test suite Flutter, pastikan tidak ada regresi**

Run: `C:\Users\thezu\flutter\bin\flutter.bat test`
Expected: PASS — semua test (termasuk yang baru dari Task 4 & 5) lulus.

- [ ] **Step 7: Commit**

```bash
git add lib/features/admin/presentation/admin_dashboard_screen.dart
git commit -m "feat: tombol Rentang tanggal di Laporan Penjualan"
```

---

## Task 7: Verifikasi manual di app

- [ ] **Step 1: Jalankan app di emulator**

Run: `D:\Sdk\emulator\emulator.exe -avd Pixel_8_Pro` (kalau emulator belum jalan), lalu
`C:\Users\thezu\flutter\bin\flutter.bat run --flavor admin --dart-define=API_BASE_URL=https://rehat-backend-production.up.railway.app/v1 --dart-define=ADMIN_BUILD=true`

- [ ] **Step 2: Login sebagai admin, buka Laporan Penjualan**

Verifikasi tombol "Rentang tanggal" muncul di sebelah "Pilih tanggal", label default "Rentang tanggal" (belum aktif).

- [ ] **Step 3: Pilih rentang 3 hari yang ada datanya**

Tap "Rentang tanggal" → pilih start & end (mis. 3 hari terakhir) → verifikasi:
- Label tombol berubah jadi `"<start> – <end>"`.
- Pill & "Pilih tanggal" jadi non-accent (tidak aktif).
- Kartu "Total omzet" & grafik "Pendapatan harian" ter-update sesuai rentang.
- Kartu "Pengeluaran" ikut ter-update ke rentang yang sama.

- [ ] **Step 4: Bandingkan total dengan jumlah manual 3 tanggal tunggal**

Untuk masing-masing dari 3 hari itu, tap "Pilih tanggal" (bukan rentang) satu-satu, catat `revenue` tiap hari, jumlahkan manual → harus sama persis dengan `revenue` yang ditampilkan saat rentang 3-hari dipilih.

- [ ] **Step 5: Uji validasi 90 hari**

Tap "Rentang tanggal" → pilih rentang >90 hari (mis. awal tahun s/d hari ini bila sudah lewat 90 hari) → verifikasi muncul `SnackBar` "Rentang maksimal 90 hari" dan filter TIDAK berubah (label tombol tetap seperti sebelumnya).

- [ ] **Step 6: Uji saling-menggantikan**

Dengan rentang aktif, tap pill "Hari ini" → verifikasi tombol rentang kembali ke label default "Rentang tanggal" (ter-null-kan). Ulangi: aktifkan rentang lagi, lalu tap "Pilih tanggal" (tanggal tunggal) → verifikasi rentang ter-null-kan.
