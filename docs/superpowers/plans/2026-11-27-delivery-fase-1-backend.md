# Delivery Fase 1 — Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. It will decide whether each batch should run in parallel or serial subagent mode and will pass only task-local context to each subagent. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Backend `rehat-backend` mendukung pesanan delivery yang diantar kurir Rehat sendiri: alamat, ongkir, dispatch otomatis ke kurir via WA, layar/endpoint kurir, admin, refund ke Saldo Rehat, dan laporan.

**Architecture:** Status antaran disimpan di kolom terpisah (`orders.delivery_status`) agar alur pembayaran/antrean/poin yang ada tidak berubah. Logika murni (ongkir, jarak, jam) di `deliveryPricing.js` (mudah dites); akses DB di `deliveryService.js`, `addressService.js`, `courierService.js`; semua endpoint baru di `src/routes/delivery.js` yang di-mount di router utama. Hook kecil di `orderService` (createOrder, updateOrderStatus, laporan).

**Tech Stack:** Node 18+, Express, Supabase JS (PostgREST), Zod v4, Jest 29 + supertest. WA lewat `notificationService` (Fonnte).

**Spec:** `docs/superpowers/specs/2026-11-27-delivery-fase-1-design.md` (repo `rehatflutter`).

**Repo & perintah:**
- Repo: `D:\REHAT\rehat-backend\rehat-backend`, branch `master`, remote `origin` (CI: test → deploy Railway; push ke `master` = deploy produksi).
- Git di repo ini butuh: `git -c safe.directory=D:/REHAT/rehat-backend/rehat-backend <perintah>`. Di plan ditulis `git` saja; tambahkan flag itu.
- Jalankan test dari root repo: `npx jest <path>`; semua: `npm test`.
- Kerjakan di branch fitur `feat/delivery-fase-1`; jangan push ke `master` sampai Task 14.

---

## File Structure

| File | Status | Tanggung jawab |
|---|---|---|
| `src/testUtils/supabaseQueueMock.js` | baru | Mock Supabase berbasis antrean, dipakai bersama test baru |
| `src/db/migrations/022_add_delivery.sql` | baru | Skema: role kurir, kolom delivery, alamat, pengaturan toko, jam |
| `src/services/deliveryPricing.js` | baru | Fungsi murni: haversine, ongkir, jendela jam delivery |
| `src/services/deliveryService.js` | baru | Config/quote, dispatch, pengaturan toko, refund delivery, pengingat |
| `src/services/addressService.js` | baru | CRUD alamat pelanggan |
| `src/services/courierService.js` | baru | Aksi kurir (ambil/berangkat/terkirim/gagal/bertugas) + admin kurir |
| `src/routes/delivery.js` | baru | Semua endpoint delivery/alamat/kurir/admin-delivery |
| `src/middleware/auth.js` | ubah | Tambah `courierAccess` |
| `src/services/orderService.js` | ubah | createOrder delivery, hook dispatch, label, `delivery_income`, ringkasan delivery di closing, export `wibDayRange` |
| `src/routes/index.js` | ubah | Schema order + mount `delivery.js` |
| `src/index.js` | ubah | Interval pengingat antaran |

---

### Task 1: Shared Supabase queue mock

**Files:**
- Create: `src/testUtils/supabaseQueueMock.js`
- Test: `src/testUtils/__tests__/supabaseQueueMock.test.js`

- [ ] **Step 1: Write the failing test**

```js
// src/testUtils/__tests__/supabaseQueueMock.test.js
const mock = require('../supabaseQueueMock')

beforeEach(() => mock.reset())

test('from() mengambil hasil berurutan dan merekam operasi', async () => {
  mock.state.results = [{ data: { id: 1 }, error: null }, { data: [1, 2], error: null }]
  const a = await mock.supabaseAdmin.from('orders').select('id').eq('id', 1).maybeSingle()
  const b = await mock.supabaseAdmin.from('users').select('id').in('role', ['x'])
  expect(a.data).toEqual({ id: 1 })
  expect(b.data).toEqual([1, 2])
  expect(mock.state.calls[0].table).toBe('orders')
  expect(mock.findOp(0, 'eq')).toEqual(['eq', 'id', 1])
  expect(mock.findOp(1, 'in')).toEqual(['in', 'role', ['x']])
})

test('antrean kosong -> { data: null, error: null }; rpc direkam terpisah', async () => {
  const r = await mock.supabaseAdmin.from('x').select('*').single()
  expect(r).toEqual({ data: null, error: null })
  mock.state.rpcResults = [{ data: 5, error: null }]
  const rr = await mock.supabaseAdmin.rpc('increment_balance', { p_user: 'u', p_delta: 5 })
  expect(rr.data).toBe(5)
  expect(mock.state.rpcCalls[0]).toEqual(['increment_balance', { p_user: 'u', p_delta: 5 }])
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx jest src/testUtils/__tests__/supabaseQueueMock.test.js`
Expected: FAIL — `Cannot find module '../supabaseQueueMock'`

- [ ] **Step 3: Write minimal implementation**

```js
// src/testUtils/supabaseQueueMock.js
// Mock Supabase berbasis ANTREAN untuk test. Tiap `from()` mengambil hasil
// berikutnya dari `state.results`; operasi yang dipanggil direkam di
// `state.calls[i].ops` agar test bisa memeriksa apa yang benar-benar ditulis.
// Pakai: jest.mock('<path>/config/supabase', () => require('<path>/testUtils/supabaseQueueMock'))
const state = { results: [], calls: [], rpcResults: [], rpcCalls: [] }
const OPS = ['select', 'eq', 'neq', 'in', 'is', 'gte', 'lte', 'order', 'limit', 'range', 'or',
  'update', 'insert', 'upsert', 'delete']

const from = (table) => {
  const rec = { table, ops: [] }
  state.calls.push(rec)
  const result = state.results.shift() || { data: null, error: null }
  const chain = {}
  for (const op of OPS) chain[op] = (...args) => { rec.ops.push([op, ...args]); return chain }
  chain.maybeSingle = () => Promise.resolve(result)
  chain.single = () => Promise.resolve(result)
  chain.then = (resolve, reject) => Promise.resolve(result).then(resolve, reject)
  return chain
}

const rpc = (name, args) => {
  state.rpcCalls.push([name, args])
  return Promise.resolve(state.rpcResults.shift() || { data: null, error: null })
}

const reset = () => { state.results = []; state.calls = []; state.rpcResults = []; state.rpcCalls = [] }
const findOp = (i, name) => state.calls[i].ops.find((o) => o[0] === name)

module.exports = { supabaseAdmin: { from, rpc }, state, reset, findOp }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx jest src/testUtils/__tests__/supabaseQueueMock.test.js`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git checkout -b feat/delivery-fase-1
git add src/testUtils
git commit -m "test: mock Supabase berbasis antrean untuk dipakai bersama"
```

---

### Task 2: Migrasi 022

**Files:**
- Create: `src/db/migrations/022_add_delivery.sql`

- [ ] **Step 1: Tulis migrasi** (idempoten, mengikuti pola 003/015)

```sql
-- 022_add_delivery.sql — Delivery Fase 1 (kurir sendiri).
-- Idempoten. Jalankan lewat `npm run migrate` (DATABASE_URL) atau Supabase SQL Editor.

-- 1. Peran kurir + status bertugas
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE public.users ADD CONSTRAINT users_role_check
  CHECK (role IN ('customer', 'admin', 'courier'));
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS courier_on_duty boolean NOT NULL DEFAULT false;

-- 2. order_type: tambah 'delivery'
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_order_type_check;
ALTER TABLE public.orders ADD CONSTRAINT orders_order_type_check
  CHECK (order_type IN ('dine_in', 'takeaway', 'delivery'));

-- 3. Kolom delivery di orders
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS delivery_fee         int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS delivery_address     jsonb,
  ADD COLUMN IF NOT EXISTS delivery_distance_m  int,
  ADD COLUMN IF NOT EXISTS delivery_status      text,
  ADD COLUMN IF NOT EXISTS courier_id           uuid REFERENCES public.users(id),
  ADD COLUMN IF NOT EXISTS courier_assigned_at  timestamptz,
  ADD COLUMN IF NOT EXISTS picked_up_at         timestamptz,
  ADD COLUMN IF NOT EXISTS delivered_at         timestamptz,
  ADD COLUMN IF NOT EXISTS delivery_fail_reason text,
  ADD COLUMN IF NOT EXISTS courier_reminded_at  timestamptz;
CREATE INDEX IF NOT EXISTS idx_orders_delivery_status ON public.orders(delivery_status)
  WHERE delivery_status IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_orders_courier ON public.orders(courier_id)
  WHERE courier_id IS NOT NULL;

-- 4. Alamat tersimpan pelanggan
CREATE TABLE IF NOT EXISTS public.user_addresses (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  label           text NOT NULL,
  address_text    text NOT NULL,
  notes           text,
  recipient_name  text NOT NULL,
  recipient_phone text NOT NULL,
  lat             double precision NOT NULL,
  lng             double precision NOT NULL,
  is_default      boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_user_addresses_user ON public.user_addresses(user_id);
ALTER TABLE public.user_addresses ENABLE ROW LEVEL SECURITY;

-- 5. Pengaturan toko (satu baris)
CREATE TABLE IF NOT EXISTS public.store_settings (
  id                      int PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  store_lat               double precision,
  store_lng               double precision,
  store_address           text,
  delivery_enabled        boolean NOT NULL DEFAULT false,
  delivery_radius_m       int NOT NULL DEFAULT 3000,
  delivery_fee            int NOT NULL DEFAULT 5000,
  free_delivery_min       int NOT NULL DEFAULT 50000,
  delivery_cutoff_minutes int NOT NULL DEFAULT 60,
  updated_at              timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.store_settings ENABLE ROW LEVEL SECURITY;
INSERT INTO public.store_settings (id, store_lat, store_lng, store_address)
VALUES (1, -7.1940555, 113.2508814, 'Jl. KH. Hasyim Asyari 26, Sampang, Jawa Timur')
ON CONFLICT DO NOTHING;

-- 6. Jam buka per hari (0=Minggu..6=Sabtu, WIB). 24.00 disimpan sebagai 00:00.
CREATE TABLE IF NOT EXISTS public.store_hours (
  day_of_week int PRIMARY KEY CHECK (day_of_week BETWEEN 0 AND 6),
  open_time   time,
  close_time  time,
  is_closed   boolean NOT NULL DEFAULT false
);
ALTER TABLE public.store_hours ENABLE ROW LEVEL SECURITY;
INSERT INTO public.store_hours (day_of_week, open_time, close_time)
SELECT d, '10:00', '00:00' FROM generate_series(0, 6) AS d
ON CONFLICT DO NOTHING;

-- Verifikasi (opsional):
--   SELECT column_name FROM information_schema.columns WHERE table_name='orders' AND column_name LIKE 'deliver%';
--   SELECT * FROM public.store_settings; SELECT * FROM public.store_hours ORDER BY 1;
```

RLS diaktifkan tanpa policy: tabel hanya diakses lewat service role (backend), sama seperti tabel lain.
Migrasi **belum dijalankan** di produksi sampai Task 14.

- [ ] **Step 2: Commit**

```bash
git add src/db/migrations/022_add_delivery.sql
git commit -m "feat(delivery): migrasi 022 — kurir, kolom delivery, alamat, pengaturan & jam toko"
```

---

### Task 3: `deliveryPricing` (fungsi murni)

**Files:**
- Create: `src/services/deliveryPricing.js`
- Test: `src/services/__tests__/deliveryPricing.test.js`

- [ ] **Step 1: Write the failing test**

```js
// src/services/__tests__/deliveryPricing.test.js
const { haversineMeters, computeDeliveryFee, deliveryWindow } = require('../deliveryPricing')

const SETTINGS = { delivery_fee: 5000, free_delivery_min: 50000 }
const EVERYDAY_10_TO_24 = [0, 1, 2, 3, 4, 5, 6].map((d) => (
  { day_of_week: d, open_time: '10:00:00', close_time: '00:00:00', is_closed: false }))
// Waktu WIB -> Date (UTC = WIB - 7 jam)
const wib = (iso) => new Date(`${iso}+07:00`)

describe('haversineMeters', () => {
  test('titik sama = 0', () => {
    expect(haversineMeters(-7.1940555, 113.2508814, -7.1940555, 113.2508814)).toBe(0)
  })
  test('0,01 derajat lintang ≈ 1112 m', () => {
    const d = haversineMeters(-7.19, 113.25, -7.18, 113.25)
    expect(d).toBeGreaterThan(1100)
    expect(d).toBeLessThan(1125)
  })
})

describe('computeDeliveryFee', () => {
  test.each([
    [0, 5000], [49999, 5000], [50000, 0], [120000, 0],
  ])('items_net %i -> ongkir %i', (net, fee) => {
    expect(computeDeliveryFee(net, SETTINGS)).toBe(fee)
  })
})

describe('deliveryWindow (toko 10.00–24.00, batas 60 menit)', () => {
  test.each([
    ['2026-11-27T09:59:00', false],
    ['2026-11-27T10:00:00', true],
    ['2026-11-27T22:59:00', true],
    ['2026-11-27T23:00:00', true],
    ['2026-11-27T23:01:00', false],
    ['2026-11-28T00:30:00', false],
  ])('%s WIB -> open=%s', (t, open) => {
    const w = deliveryWindow(wib(t), EVERYDAY_10_TO_24, 60)
    expect(w.open).toBe(open)
    expect(w.lastOrderAt).toBe('23:00')
  })

  test('hari tutup -> tidak buka', () => {
    const hours = EVERYDAY_10_TO_24.map((h) => (h.day_of_week === 5 ? { ...h, is_closed: true } : h))
    // 2026-11-27 adalah Jumat (day_of_week 5)
    expect(deliveryWindow(wib('2026-11-27T12:00:00'), hours, 60).open).toBe(false)
  })

  test('tutup lewat tengah malam (18.00–02.00) -> 00.30 masih buka dari jendela kemarin', () => {
    const hours = EVERYDAY_10_TO_24.map((h) => ({ ...h, open_time: '18:00', close_time: '02:00' }))
    const w = deliveryWindow(wib('2026-11-28T00:30:00'), hours, 60)
    expect(w.open).toBe(true)
    expect(w.lastOrderAt).toBe('01:00')
  })

  test('jam belum diisi -> tidak buka, lastOrderAt null', () => {
    expect(deliveryWindow(wib('2026-11-27T12:00:00'), [], 60)).toEqual({ open: false, lastOrderAt: null })
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx jest src/services/__tests__/deliveryPricing.test.js`
Expected: FAIL — `Cannot find module '../deliveryPricing'`

- [ ] **Step 3: Write minimal implementation**

```js
// src/services/deliveryPricing.js
// Fungsi MURNI untuk delivery (tanpa DB) — jarak, ongkir, jendela jam (WIB).

const EARTH_RADIUS_M = 6371000
const toRad = (deg) => (deg * Math.PI) / 180
const WIB_OFFSET_MS = 7 * 60 * 60 * 1000
const DAY_MIN = 24 * 60

/** Jarak garis lurus (meter, dibulatkan) antara dua koordinat. */
const haversineMeters = (lat1, lng1, lat2, lng2) => {
  const dLat = toRad(lat2 - lat1)
  const dLng = toRad(lng2 - lng1)
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2
  return Math.round(2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(a)))
}

/** Ongkir yang dibayar pelanggan. `itemsNet` = subtotal menu − diskon voucher. */
const computeDeliveryFee = (itemsNet, { delivery_fee, free_delivery_min }) =>
  (itemsNet >= free_delivery_min ? 0 : delivery_fee)

const toMinutes = (t) => {
  const [h, m] = String(t).split(':').map(Number)
  return h * 60 + m
}
const fmt = (mins) => {
  const m = ((mins % DAY_MIN) + DAY_MIN) % DAY_MIN
  return `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`
}

/**
 * Apakah delivery sedang buka. Toko tutup lewat tengah malam (close <= open)
 * dihitung sampai hari berikutnya, jadi jendela "kemarin" juga diperiksa.
 * @returns {{ open: boolean, lastOrderAt: string|null }} lastOrderAt 'HH:MM' WIB
 */
const deliveryWindow = (now, hoursRows, cutoffMinutes) => {
  const wib = new Date(now.getTime() + WIB_OFFSET_MS)
  const dow = wib.getUTCDay()
  const nowMin = wib.getUTCHours() * 60 + wib.getUTCMinutes()
  const byDay = new Map((hoursRows || []).map((r) => [Number(r.day_of_week), r]))

  const windowOf = (row) => {
    if (!row || row.is_closed || !row.open_time || !row.close_time) return null
    const open = toMinutes(row.open_time)
    let close = toMinutes(row.close_time)
    if (close <= open) close += DAY_MIN
    return { open, last: close - cutoffMinutes }
  }

  const today = windowOf(byDay.get(dow))
  const yesterday = windowOf(byDay.get((dow + 6) % 7))
  const inToday = !!today && nowMin >= today.open && nowMin <= today.last
  const inYesterday = !!yesterday && nowMin + DAY_MIN >= yesterday.open && nowMin + DAY_MIN <= yesterday.last
  const active = inYesterday ? yesterday : today
  return { open: inToday || inYesterday, lastOrderAt: active ? fmt(active.last) : null }
}

module.exports = { haversineMeters, computeDeliveryFee, deliveryWindow }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx jest src/services/__tests__/deliveryPricing.test.js`
Expected: PASS (semua kasus)

- [ ] **Step 5: Commit**

```bash
git add src/services/deliveryPricing.js src/services/__tests__/deliveryPricing.test.js
git commit -m "feat(delivery): fungsi murni jarak, ongkir & jendela jam delivery"
```

---

### Task 4: `deliveryService` — config & quote

**Files:**
- Create: `src/services/deliveryService.js`
- Test: `src/services/__tests__/deliveryQuote.test.js`

- [ ] **Step 1: Write the failing test**

```js
// src/services/__tests__/deliveryQuote.test.js
jest.mock('../../config/supabase', () => require('../../testUtils/supabaseQueueMock'))
jest.mock('../notificationService', () => ({
  create: jest.fn(), sendWhatsappSafe: jest.fn(), notifyAdmins: jest.fn(), sendWhatsappToAdmins: jest.fn(),
}))
const mock = require('../../testUtils/supabaseQueueMock')
const delivery = require('../deliveryService')

const STORE = { lat: -7.1940555, lng: 113.2508814 }
const settings = (over = {}) => ({
  data: {
    id: 1, store_lat: STORE.lat, store_lng: STORE.lng, delivery_enabled: true,
    delivery_radius_m: 3000, delivery_fee: 5000, free_delivery_min: 50000, delivery_cutoff_minutes: 60, ...over,
  },
  error: null,
})
const HOURS = { data: [0, 1, 2, 3, 4, 5, 6].map((d) => ({ day_of_week: d, open_time: '10:00', close_time: '00:00', is_closed: false })), error: null }
const couriers = (n) => ({ count: n, data: null, error: null })
const NOON = new Date('2026-11-27T12:00:00+07:00')
const NEAR = { lat: STORE.lat + 0.01, lng: STORE.lng } // ±1,1 km
const FAR = { lat: STORE.lat + 0.05, lng: STORE.lng } // ±5,6 km

beforeEach(() => { mock.reset(); jest.clearAllMocks() })

describe('quote', () => {
  test('dekat, di bawah 50rb -> tersedia, ongkir 5000, sisa untuk gratis', async () => {
    mock.state.results = [settings(), HOURS, couriers(1)]
    const q = await delivery.quote({ ...NEAR, itemsNet: 30000 }, NOON)
    expect(q).toMatchObject({ available: true, reason: null, delivery_fee: 5000, remaining_for_free: 20000 })
    expect(q.distance_m).toBeGreaterThan(1000)
  })

  test('>= 50rb -> gratis ongkir', async () => {
    mock.state.results = [settings(), HOURS, couriers(1)]
    const q = await delivery.quote({ ...NEAR, itemsNet: 50000 }, NOON)
    expect(q).toMatchObject({ available: true, delivery_fee: 0, remaining_for_free: 0 })
  })

  test.each([
    ['delivery dimatikan', [settings({ delivery_enabled: false }), HOURS, couriers(1)], NEAR, NOON, 'DELIVERY_DISABLED'],
    ['di luar jam', [settings(), HOURS, couriers(1)], NEAR, new Date('2026-11-27T23:30:00+07:00'), 'OUTSIDE_HOURS'],
    ['tidak ada kurir', [settings(), HOURS, couriers(0)], NEAR, NOON, 'NO_COURIER_ON_DUTY'],
    ['di luar radius', [settings(), HOURS, couriers(1)], FAR, NOON, 'OUT_OF_RADIUS'],
    ['lokasi toko kosong', [settings({ store_lat: null }), HOURS, couriers(1)], NEAR, NOON, 'STORE_LOCATION_NOT_SET'],
  ])('%s -> %s', async (_, results, pos, now, reason) => {
    mock.state.results = results
    const q = await delivery.quote({ ...pos, itemsNet: 30000 }, now)
    expect(q.available).toBe(false)
    expect(q.reason).toBe(reason)
    expect(typeof q.message).toBe('string')
  })
})

describe('getConfig', () => {
  test('ringkasan untuk UI', async () => {
    mock.state.results = [settings(), HOURS, couriers(2)]
    const c = await delivery.getConfig(NOON)
    expect(c).toEqual({
      enabled: true, available: true, reason: null, message: null, last_order_at: '23:00',
      radius_m: 3000, delivery_fee: 5000, free_delivery_min: 50000,
    })
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx jest src/services/__tests__/deliveryQuote.test.js`
Expected: FAIL — `Cannot find module '../deliveryService'`

- [ ] **Step 3: Write minimal implementation**

```js
// src/services/deliveryService.js
const { supabaseAdmin } = require('../config/supabase')
const { AppError } = require('../middleware/response')
const pricing = require('./deliveryPricing')

const REASON_MESSAGES = {
  DELIVERY_DISABLED: 'Delivery sedang tidak tersedia.',
  STORE_LOCATION_NOT_SET: 'Delivery belum siap (lokasi toko belum diatur).',
  OUTSIDE_HOURS: 'Delivery sedang tutup.',
  NO_COURIER_ON_DUTY: 'Kurir sedang tidak bertugas.',
  OUT_OF_RADIUS: 'Alamat di luar jangkauan delivery. Pesan lewat GrabFood ya.',
}

const loadState = async () => {
  const { data: settings, error } = await supabaseAdmin
    .from('store_settings').select('*').eq('id', 1).maybeSingle()
  if (error) throw new AppError('DELIVERY_SETTINGS_FAILED', error.message, 500)
  const { data: hours } = await supabaseAdmin.from('store_hours').select('*')
  const { count } = await supabaseAdmin
    .from('users').select('id', { count: 'exact', head: true })
    .eq('role', 'courier').eq('courier_on_duty', true)
  return { settings, hours: hours || [], couriersOnDuty: count || 0 }
}

const availabilityReason = (s, win, couriersOnDuty) => {
  if (!s || !s.delivery_enabled) return 'DELIVERY_DISABLED'
  if (s.store_lat == null || s.store_lng == null) return 'STORE_LOCATION_NOT_SET'
  if (!win.open) return 'OUTSIDE_HOURS'
  if (couriersOnDuty < 1) return 'NO_COURIER_ON_DUTY'
  return null
}

const messageFor = (reason, win) => {
  if (!reason) return null
  if (reason === 'OUTSIDE_HOURS' && win.lastOrderAt) {
    return `Delivery sedang tutup. Pesanan delivery terakhir pukul ${win.lastOrderAt}.`
  }
  return REASON_MESSAGES[reason]
}

const getConfig = async (now = new Date()) => {
  const { settings: s, hours, couriersOnDuty } = await loadState()
  const win = pricing.deliveryWindow(now, hours, s?.delivery_cutoff_minutes ?? 60)
  const reason = availabilityReason(s, win, couriersOnDuty)
  return {
    enabled: !!s?.delivery_enabled,
    available: !reason,
    reason,
    message: messageFor(reason, win),
    last_order_at: win.lastOrderAt,
    radius_m: s?.delivery_radius_m ?? null,
    delivery_fee: s?.delivery_fee ?? null,
    free_delivery_min: s?.free_delivery_min ?? null,
  }
}

/** Cek alamat (lat/lng) + hitung ongkir. Dipakai app (pratinjau) & createOrder (final). */
const quote = async ({ lat, lng, itemsNet }, now = new Date()) => {
  const { settings: s, hours, couriersOnDuty } = await loadState()
  const win = pricing.deliveryWindow(now, hours, s?.delivery_cutoff_minutes ?? 60)
  let reason = availabilityReason(s, win, couriersOnDuty)
  const distanceM = s && s.store_lat != null && s.store_lng != null
    ? pricing.haversineMeters(s.store_lat, s.store_lng, Number(lat), Number(lng))
    : null
  if (!reason && distanceM > s.delivery_radius_m) reason = 'OUT_OF_RADIUS'
  const fee = s ? pricing.computeDeliveryFee(itemsNet, s) : null
  return {
    available: !reason,
    reason,
    message: messageFor(reason, win),
    distance_m: distanceM,
    delivery_fee: fee,
    free_delivery_min: s?.free_delivery_min ?? null,
    remaining_for_free: s ? Math.max(0, s.free_delivery_min - itemsNet) : null,
  }
}

module.exports = { getConfig, quote, REASON_MESSAGES }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx jest src/services/__tests__/deliveryQuote.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/services/deliveryService.js src/services/__tests__/deliveryQuote.test.js
git commit -m "feat(delivery): config & quote (radius, jam, kurir bertugas, ongkir)"
```

---

### Task 5: Alamat pelanggan + endpoint config/quote

**Files:**
- Create: `src/services/addressService.js`
- Create: `src/routes/delivery.js`
- Modify: `src/routes/index.js` (mount router; sebelum `module.exports = router` di baris terakhir)
- Test: `src/routes/__tests__/deliveryAddresses.test.js`

- [ ] **Step 1: Write the failing test**

```js
// src/routes/__tests__/deliveryAddresses.test.js
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret'
jest.mock('../../config/supabase', () => require('../../testUtils/supabaseQueueMock'))
jest.mock('../../services/notificationService', () => ({
  create: jest.fn(), sendWhatsappSafe: jest.fn(), notifyAdmins: jest.fn(), sendWhatsappToAdmins: jest.fn(),
}))
const jwt = require('jsonwebtoken')
const express = require('express')
const request = require('supertest')
const mock = require('../../testUtils/supabaseQueueMock')
const routes = require('../index')
const { errorHandler } = require('../../middleware/response')

const app = express()
app.use(express.json())
app.use('/v1', routes)
app.use(errorHandler)

const UID = '22222222-2222-4222-8222-222222222222'
const AID = '33333333-3333-4333-8333-333333333333'
const token = jwt.sign({ userId: UID }, process.env.JWT_SECRET)
const USER = { data: { id: UID, role: 'customer', is_active: true, phone: '0812' }, error: null }
const auth = (r) => r.set('Authorization', `Bearer ${token}`)
const BODY = {
  label: 'Rumah', address_text: 'Jl. Melati 5, Sampang', notes: 'Pagar hijau',
  recipient_name: 'Nadia', recipient_phone: '081234567890', lat: -7.19, lng: 113.25,
}

beforeEach(() => mock.reset())

test('POST /me/addresses: alamat pertama otomatis default', async () => {
  mock.state.results = [USER, { count: 0, data: null, error: null }, { data: null, error: null }, { data: { id: AID, ...BODY, is_default: true }, error: null }]
  const res = await auth(request(app).post('/v1/me/addresses')).send(BODY)
  expect(res.status).toBe(201)
  expect(res.body.data.id).toBe(AID)
  const insert = mock.findOp(3, 'insert')[1]
  expect(insert).toMatchObject({ user_id: UID, is_default: true, label: 'Rumah' })
})

test('POST /me/addresses: ditolak bila sudah 10 alamat', async () => {
  mock.state.results = [USER, { count: 10, data: null, error: null }]
  const res = await auth(request(app).post('/v1/me/addresses')).send(BODY)
  expect(res.status).toBe(400)
  expect(res.body.error.code).toBe('ADDRESS_LIMIT')
})

test('POST /me/addresses: lat di luar rentang -> 422 VALIDATION_ERROR', async () => {
  mock.state.results = [USER]
  const res = await auth(request(app).post('/v1/me/addresses')).send({ ...BODY, lat: 200 })
  expect(res.status).toBe(422)
  expect(res.body.error.code).toBe('VALIDATION_ERROR')
})

test('PATCH /me/addresses/:id milik user lain -> 404', async () => {
  mock.state.results = [USER, { data: null, error: null }]
  const res = await auth(request(app).patch(`/v1/me/addresses/${AID}`)).send({ label: 'Kantor' })
  expect(res.status).toBe(404)
  expect(mock.findOp(1, 'eq')).toEqual(['eq', 'id', AID])
  expect(mock.state.calls[1].ops).toContainEqual(['eq', 'user_id', UID])
})

test('DELETE /me/addresses/:id', async () => {
  mock.state.results = [USER, { data: { id: AID }, error: null }]
  const res = await auth(request(app).delete(`/v1/me/addresses/${AID}`))
  expect(res.status).toBe(200)
  expect(mock.state.calls[1].ops.map((o) => o[0])).toContain('delete')
})

test('POST /delivery/quote memakai alamat milik user', async () => {
  const addr = { data: { id: AID, user_id: UID, lat: -7.1840555, lng: 113.2508814 }, error: null }
  const settings = { data: { id: 1, store_lat: -7.1940555, store_lng: 113.2508814, delivery_enabled: true, delivery_radius_m: 3000, delivery_fee: 5000, free_delivery_min: 50000, delivery_cutoff_minutes: 0 }, error: null }
  const hours = { data: [0, 1, 2, 3, 4, 5, 6].map((d) => ({ day_of_week: d, open_time: '00:00', close_time: '00:00', is_closed: false })), error: null }
  mock.state.results = [USER, addr, settings, hours, { count: 1, data: null, error: null }]
  const res = await auth(request(app).post('/v1/delivery/quote')).send({ address_id: AID, items_net: 30000 })
  expect(res.status).toBe(200)
  expect(res.body.data).toMatchObject({ available: true, delivery_fee: 5000 })
})
```

Catatan: jam `00:00–00:00` dengan batas 0 menit = buka 24 jam, agar test tidak bergantung jam saat dijalankan.

- [ ] **Step 2: Run test to verify it fails**

Run: `npx jest src/routes/__tests__/deliveryAddresses.test.js`
Expected: FAIL — status 404 (endpoint belum ada)

- [ ] **Step 3: Write `addressService.js`**

```js
// src/services/addressService.js
const { supabaseAdmin } = require('../config/supabase')
const { AppError } = require('../middleware/response')

const MAX_ADDRESSES = 10
const FIELDS = 'id, label, address_text, notes, recipient_name, recipient_phone, lat, lng, is_default, created_at'

const list = async (userId) => {
  const { data, error } = await supabaseAdmin
    .from('user_addresses').select(FIELDS).eq('user_id', userId)
    .order('is_default', { ascending: false }).order('created_at', { ascending: false })
  if (error) throw new AppError('ADDRESS_FETCH_FAILED', error.message, 500)
  return data || []
}

const clearDefault = (userId) => supabaseAdmin
  .from('user_addresses').update({ is_default: false }).eq('user_id', userId).eq('is_default', true)

const create = async (userId, input) => {
  const { count } = await supabaseAdmin
    .from('user_addresses').select('id', { count: 'exact', head: true }).eq('user_id', userId)
  const existing = count || 0
  if (existing >= MAX_ADDRESSES) {
    throw new AppError('ADDRESS_LIMIT', `Maksimal ${MAX_ADDRESSES} alamat tersimpan`, 400)
  }
  const isDefault = input.is_default === true || existing === 0
  if (isDefault) await clearDefault(userId)
  const { data, error } = await supabaseAdmin
    .from('user_addresses')
    .insert({ ...input, notes: input.notes || null, user_id: userId, is_default: isDefault })
    .select(FIELDS).single()
  if (error) throw new AppError('ADDRESS_SAVE_FAILED', error.message, 500)
  return data
}

const update = async (userId, id, input) => {
  if (input.is_default === true) await clearDefault(userId)
  const { data, error } = await supabaseAdmin
    .from('user_addresses').update(input).eq('id', id).eq('user_id', userId)
    .select(FIELDS).maybeSingle()
  if (error) throw new AppError('ADDRESS_SAVE_FAILED', error.message, 500)
  if (!data) throw new AppError('ADDRESS_NOT_FOUND', 'Alamat tidak ditemukan', 404)
  return data
}

const remove = async (userId, id) => {
  const { data, error } = await supabaseAdmin
    .from('user_addresses').delete().eq('id', id).eq('user_id', userId).select('id').maybeSingle()
  if (error) throw new AppError('ADDRESS_DELETE_FAILED', error.message, 500)
  if (!data) throw new AppError('ADDRESS_NOT_FOUND', 'Alamat tidak ditemukan', 404)
  return { id }
}

/** Alamat milik user (atau 404). Dipakai quote & createOrder. */
const getOwned = async (userId, id) => {
  const { data } = await supabaseAdmin
    .from('user_addresses').select('*').eq('id', id).eq('user_id', userId).maybeSingle()
  if (!data) throw new AppError('ADDRESS_NOT_FOUND', 'Alamat tidak ditemukan', 404)
  return data
}

module.exports = { list, create, update, remove, getOwned, MAX_ADDRESSES }
```

- [ ] **Step 4: Write `src/routes/delivery.js`** (endpoint lain ditambahkan di task berikutnya)

```js
// src/routes/delivery.js — endpoint delivery, alamat, kurir, admin-delivery.
const express = require('express')
const { z } = require('zod')
const { authenticate } = require('../middleware/auth')
const { success, created } = require('../middleware/response')
const deliveryService = require('../services/deliveryService')
const addressService = require('../services/addressService')

const router = express.Router()

const addressSchema = z.object({
  label: z.string().trim().min(1).max(30),
  address_text: z.string().trim().min(5).max(300),
  notes: z.string().trim().max(200).optional().nullable(),
  recipient_name: z.string().trim().min(1).max(80),
  recipient_phone: z.string().trim().min(8).max(25).regex(/^[0-9+\-\s()]+$/, 'Nomor HP tidak valid'),
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
  is_default: z.boolean().optional(),
})

router.get('/delivery/config', async (req, res, next) => {
  try { return success(res, await deliveryService.getConfig()) } catch (err) { next(err) }
})

router.post('/delivery/quote', authenticate, async (req, res, next) => {
  try {
    const { address_id, items_net } = z.object({
      address_id: z.string().uuid(),
      items_net: z.number().int().min(0),
    }).parse(req.body)
    const addr = await addressService.getOwned(req.user.id, address_id)
    return success(res, await deliveryService.quote({ lat: addr.lat, lng: addr.lng, itemsNet: items_net }))
  } catch (err) { next(err) }
})

router.get('/me/addresses', authenticate, async (req, res, next) => {
  try { return success(res, await addressService.list(req.user.id)) } catch (err) { next(err) }
})

router.post('/me/addresses', authenticate, async (req, res, next) => {
  try {
    const input = addressSchema.parse(req.body)
    return created(res, await addressService.create(req.user.id, input), 'Alamat disimpan')
  } catch (err) { next(err) }
})

router.patch('/me/addresses/:id', authenticate, async (req, res, next) => {
  try {
    const input = addressSchema.partial().parse(req.body)
    return success(res, await addressService.update(req.user.id, req.params.id, input), 'Alamat diperbarui')
  } catch (err) { next(err) }
})

router.delete('/me/addresses/:id', authenticate, async (req, res, next) => {
  try { return success(res, await addressService.remove(req.user.id, req.params.id), 'Alamat dihapus') } catch (err) { next(err) }
})

module.exports = router
```

- [ ] **Step 5: Mount di `src/routes/index.js`** — tepat sebelum `module.exports = router` (baris terakhir):

```js
// Delivery (alamat, ongkir, kurir) — lihat src/routes/delivery.js
router.use(require('./delivery'))

module.exports = router
```

`errorHandler` (`src/middleware/response.js`) sudah memetakan `ZodError` → 422 `VALIDATION_ERROR` dan `AppError` → `statusCode`-nya; tidak perlu diubah.

- [ ] **Step 6: Run test to verify it passes**

Run: `npx jest src/routes/__tests__/deliveryAddresses.test.js`
Expected: PASS (6 tests)

- [ ] **Step 7: Commit**

```bash
git add src/services/addressService.js src/routes/delivery.js src/routes/index.js src/routes/__tests__/deliveryAddresses.test.js
git commit -m "feat(delivery): CRUD alamat pelanggan + endpoint config & quote"
```

---

### Task 6: `createOrder` mendukung delivery

**Files:**
- Modify: `src/services/orderService.js` (fungsi `createOrder` baris ±58–161; `ORDER_TYPE_LABELS` baris ±459)
- Modify: `src/routes/index.js` (`orderSchema` baris ±36–51; route `POST /orders` baris ±466–473)
- Test: `src/services/__tests__/createOrderDelivery.test.js`

- [ ] **Step 1: Write the failing test**

```js
// src/services/__tests__/createOrderDelivery.test.js
jest.mock('../../config/supabase', () => require('../../testUtils/supabaseQueueMock'))
jest.mock('../notificationService', () => ({
  create: jest.fn(), sendWhatsappSafe: jest.fn(), notifyAdmins: jest.fn(), sendWhatsappToAdmins: jest.fn(),
}))
const mock = require('../../testUtils/supabaseQueueMock')
const orderService = require('../orderService')

const UID = '22222222-2222-4222-8222-222222222222'
const AID = '33333333-3333-4333-8333-333333333333'
const MENU = '44444444-4444-4444-8444-444444444444'
const menu = (price) => ({ data: { id: MENU, name: 'Kopi Susu', price, is_available: true }, error: null })
const ADDRESS = {
  data: { id: AID, user_id: UID, label: 'Rumah', address_text: 'Jl. Melati 5', notes: null,
    recipient_name: 'Nadia', recipient_phone: '0812', lat: -7.1840555, lng: 113.2508814 },
  error: null,
}
const SETTINGS = { data: { id: 1, store_lat: -7.1940555, store_lng: 113.2508814, delivery_enabled: true, delivery_radius_m: 3000, delivery_fee: 5000, free_delivery_min: 50000, delivery_cutoff_minutes: 0 }, error: null }
const HOURS_24H = { data: [0, 1, 2, 3, 4, 5, 6].map((d) => ({ day_of_week: d, open_time: '00:00', close_time: '00:00', is_closed: false })), error: null }
const ONE_COURIER = { count: 1, data: null, error: null }
const ORDER_ID = '55555555-5555-4555-8555-555555555555'

beforeEach(() => mock.reset())

const insertedOrder = () => mock.state.calls.find((c) => c.table === 'orders').ops.find((o) => o[0] === 'insert')[1]

test('delivery < 50rb: ongkir 5000 masuk total, poin dari harga menu saja', async () => {
  mock.state.results = [menu(20000), ADDRESS, SETTINGS, HOURS_24H, ONE_COURIER, { data: { id: ORDER_ID, queue_number: '' }, error: null }, { data: null, error: null }]
  const r = await orderService.createOrder(UID, [{ menuItemId: MENU, quantity: 1 }], null, 'qris', 'delivery', null, '7', { addressId: AID })
  expect(r).toMatchObject({ subtotal: 20000, discountAmount: 0, deliveryFee: 5000, total: 25000, orderType: 'delivery' })
  expect(insertedOrder()).toMatchObject({
    order_type: 'delivery', delivery_fee: 5000, total: 25000, points_earned: 20, table_number: null,
    delivery_address: expect.objectContaining({ recipient_name: 'Nadia', lat: -7.1840555 }),
  })
  expect(insertedOrder().delivery_distance_m).toBeGreaterThan(1000)
})

test('delivery >= 50rb: gratis ongkir', async () => {
  mock.state.results = [menu(25000), ADDRESS, SETTINGS, HOURS_24H, ONE_COURIER, { data: { id: ORDER_ID, queue_number: '' }, error: null }, { data: null, error: null }]
  const r = await orderService.createOrder(UID, [{ menuItemId: MENU, quantity: 2 }], null, 'qris', 'delivery', null, null, { addressId: AID })
  expect(r).toMatchObject({ deliveryFee: 0, total: 50000 })
})

test('delivery tanpa alamat -> ADDRESS_REQUIRED', async () => {
  mock.state.results = [menu(20000)]
  await expect(orderService.createOrder(UID, [{ menuItemId: MENU, quantity: 1 }], null, 'qris', 'delivery'))
    .rejects.toMatchObject({ code: 'ADDRESS_REQUIRED' })
})

test('delivery tidak tersedia (tidak ada kurir) -> ditolak, order tidak dibuat', async () => {
  mock.state.results = [menu(20000), ADDRESS, SETTINGS, HOURS_24H, { count: 0, data: null, error: null }]
  await expect(orderService.createOrder(UID, [{ menuItemId: MENU, quantity: 1 }], null, 'qris', 'delivery', null, null, { addressId: AID }))
    .rejects.toMatchObject({ code: 'NO_COURIER_ON_DUTY' })
  expect(mock.state.calls.some((c) => c.table === 'orders')).toBe(false)
})

test('takeaway tetap seperti dulu: tanpa kolom delivery', async () => {
  mock.state.results = [menu(20000), { data: { id: ORDER_ID, queue_number: '' }, error: null }, { data: null, error: null }]
  const r = await orderService.createOrder(UID, [{ menuItemId: MENU, quantity: 1 }], null, 'qris', 'takeaway')
  expect(r).toMatchObject({ total: 20000, deliveryFee: 0, orderType: 'takeaway' })
  expect(insertedOrder()).not.toHaveProperty('delivery_fee')
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx jest src/services/__tests__/createOrderDelivery.test.js`
Expected: FAIL — `deliveryFee` undefined / order_type jadi `dine_in`

- [ ] **Step 3: Ubah `createOrder`** di `src/services/orderService.js`

Ganti tanda tangan & baris tipe (baris 58–59):

```js
const createOrder = async (userId, items, voucherCode, paymentMethod, orderType = 'dine_in', notes = null, tableNumber = null, { addressId = null } = {}) => {
  const type = ['takeaway', 'delivery'].includes(orderType) ? orderType : 'dine_in'
```

Ganti blok "2. Validasi voucher" sampai akhir `orderRow` (baris 83–102) dengan:

```js
  // 2. Validasi voucher
  const voucherData = await validateVoucher(userId, voucherCode, subtotal)
  const discountAmount = voucherData?.discountAmount ?? 0
  const itemsNet = subtotal - discountAmount

  // 2b. Delivery: alamat milik user + cek radius/jam/kurir + ongkir — SELALU di server.
  let delivery = null
  if (type === 'delivery') {
    if (!addressId) throw new AppError('ADDRESS_REQUIRED', 'Pilih alamat pengiriman', 400)
    const addr = await require('./addressService').getOwned(userId, addressId)
    const q = await require('./deliveryService').quote({ lat: addr.lat, lng: addr.lng, itemsNet })
    if (!q.available) throw new AppError(q.reason, q.message, 400)
    delivery = {
      fee: q.delivery_fee,
      distanceM: q.distance_m,
      snapshot: {
        label: addr.label, address_text: addr.address_text, notes: addr.notes,
        recipient_name: addr.recipient_name, recipient_phone: addr.recipient_phone,
        lat: addr.lat, lng: addr.lng,
      },
    }
  }
  const deliveryFee = delivery?.fee ?? 0
  const total = itemsNet + deliveryFee
  // Poin dari harga menu (setelah diskon), BUKAN dari ongkir.
  const pointsEarned = Math.floor(itemsNet * POINTS_PER_RUPIAH)

  // 3. Buat order — nomor antrian dikosongkan; baru diberikan setelah dibayar.
  const orderRow = {
    user_id: userId,
    queue_number: '',
    subtotal,
    discount_amount: discountAmount,
    total,
    payment_method: paymentMethod,
    order_type: type,
    notes: cleanNotes,
    table_number: type === 'delivery' ? null : cleanTable,
    voucher_id: voucherData?.voucherId ?? null,
    points_earned: pointsEarned,
  }
  if (delivery) {
    orderRow.delivery_fee = deliveryFee
    orderRow.delivery_address = delivery.snapshot
    orderRow.delivery_distance_m = delivery.distanceM
  }
```

Ubah objek `return` di akhir `createOrder` (baris ±152–160) menjadi:

```js
  return {
    orderId: order.id,
    queueNumber: order.queue_number,
    subtotal,
    discountAmount,
    deliveryFee,
    total,
    orderType: type,
    payment: paymentData,
  }
```

Tambah label delivery (baris ±459):

```js
const ORDER_TYPE_LABELS = { dine_in: 'Dine-in 🍽️', takeaway: 'Bawa Pulang 🥤', delivery: 'Delivery 🛵' }
```

- [ ] **Step 4: Ubah route** di `src/routes/index.js`

Di `orderSchema` ganti baris `order_type` dan tambah `address_id`:

```js
  order_type: z.enum(['dine_in', 'takeaway', 'delivery']).optional(),
  address_id: z.string().uuid().optional(),
```

Route `POST /orders`:

```js
router.post('/orders', authenticate, async (req, res, next) => {
  try {
    const { items, voucher_code, payment_method, order_type, notes, table_number, address_id } = orderSchema.parse(req.body)
    const mapped = items.map(i => ({ menuItemId: i.menu_item_id, quantity: i.quantity, customization: i.customization }))
    const data = await orderService.createOrder(req.user.id, mapped, voucher_code, payment_method, order_type, notes, table_number, { addressId: address_id })
    return created(res, data, 'Pesanan berhasil dibuat')
  } catch (err) { next(err) }
})
```

`guestOrderSchema` tetap `['dine_in', 'takeaway']` (delivery wajib login).

- [ ] **Step 5: Run tests**

Run: `npx jest src/services/__tests__/createOrderDelivery.test.js src/services/__tests__/orderStatusGuard.test.js`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add src/services/orderService.js src/routes/index.js src/services/__tests__/createOrderDelivery.test.js
git commit -m "feat(delivery): createOrder menerima delivery — alamat, ongkir & total dihitung server"
```

---

### Task 7: Middleware `courierAccess`

**Files:**
- Modify: `src/middleware/auth.js`
- Test: `src/middleware/__tests__/courierAccess.test.js`

- [ ] **Step 1: Write the failing test**

```js
// src/middleware/__tests__/courierAccess.test.js
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret'
jest.mock('../../config/supabase', () => require('../../testUtils/supabaseQueueMock'))
const jwt = require('jsonwebtoken')
const mock = require('../../testUtils/supabaseQueueMock')
const { courierAccess } = require('../auth')

const run = (role) => new Promise((resolve) => {
  mock.reset()
  mock.state.results = [{ data: { id: 'u1', role, is_active: true }, error: null }]
  const req = { headers: { authorization: `Bearer ${jwt.sign({ userId: 'u1' }, process.env.JWT_SECRET)}` } }
  const res = { status: (code) => ({ json: (body) => resolve({ code, body }) }) }
  courierAccess(req, res, () => resolve({ code: 'next', user: req.user }))
})

test.each([['courier', 'next'], ['admin', 'next'], ['customer', 403]])('role %s -> %s', async (role, expected) => {
  const r = await run(role)
  expect(r.code).toBe(expected)
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx jest src/middleware/__tests__/courierAccess.test.js`
Expected: FAIL — `courierAccess is not a function`

- [ ] **Step 3: Implementasi** — di `src/middleware/auth.js`, sebelum `module.exports`:

```js
// Akses kurir: JWT user dengan role 'courier' (atau 'admin' untuk membantu/menguji).
const courierAccess = (req, res, next) => authenticate(req, res, () => {
  if (!['courier', 'admin'].includes(req.user?.role)) {
    return res.status(403).json({
      success: false,
      error: { code: 'FORBIDDEN', message: 'Hanya kurir yang bisa mengakses endpoint ini' },
    })
  }
  next()
})
```

Dan ubah export:

```js
module.exports = { authenticate, adminOnly, adminKey, adminAccess, requireFinanceAccess, courierAccess }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx jest src/middleware/__tests__/courierAccess.test.js`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add src/middleware/auth.js src/middleware/__tests__/courierAccess.test.js
git commit -m "feat(delivery): middleware courierAccess"
```

---

### Task 8: Dispatch otomatis saat dibayar

**Files:**
- Modify: `src/services/deliveryService.js` (tambah `dispatch`, `courierNewDeliveryMessage`)
- Modify: `src/services/orderService.js` (`updateOrderStatus`, setelah blok `awardPointsAndStamp` baris ±531–533)
- Test: `src/services/__tests__/deliveryDispatch.test.js`

- [ ] **Step 1: Write the failing test**

```js
// src/services/__tests__/deliveryDispatch.test.js
jest.mock('../../config/supabase', () => require('../../testUtils/supabaseQueueMock'))
jest.mock('../notificationService', () => ({
  create: jest.fn(), sendWhatsappSafe: jest.fn(), notifyAdmins: jest.fn(), sendWhatsappToAdmins: jest.fn(),
}))
const mock = require('../../testUtils/supabaseQueueMock')
const notif = require('../notificationService')
const delivery = require('../deliveryService')

const OID = '55555555-5555-4555-8555-555555555555'
const ORDER = {
  id: OID, queue_number: 'A-7', delivery_distance_m: 1234,
  delivery_address: { recipient_name: 'Nadia', recipient_phone: '0812', address_text: 'Jl. Melati 5', notes: 'Pagar hijau', lat: -7.18, lng: 113.25 },
  order_items: [{ quantity: 2, menu_items: { name: 'Kopi Susu' } }],
}

beforeEach(() => { mock.reset(); jest.clearAllMocks() })

test('dispatch: set waiting_courier bersyarat & WA ke semua kurir bertugas', async () => {
  mock.state.results = [{ data: ORDER, error: null }, { data: [{ id: 'c1', phone: '0811' }, { id: 'c2', phone: '0822' }], error: null }]
  const r = await delivery.dispatch(OID)
  expect(r.id).toBe(OID)
  const ops = mock.state.calls[0].ops
  expect(ops).toContainEqual(['update', { delivery_status: 'waiting_courier' }])
  expect(ops).toContainEqual(['eq', 'order_type', 'delivery'])
  expect(ops).toContainEqual(['is', 'delivery_status', null])
  expect(notif.sendWhatsappSafe).toHaveBeenCalledTimes(2)
  const msg = notif.sendWhatsappSafe.mock.calls[0][1]
  expect(msg).toContain('ANTARAN BARU')
  expect(msg).toContain('#A-7')
  expect(msg).toContain('https://maps.google.com/?q=-7.18,113.25')
  expect(msg).toContain('2x Kopi Susu')
  expect(msg).toContain('±1.2 km')
})

test('dispatch idempoten: sudah dikirim -> null, tanpa WA', async () => {
  mock.state.results = [{ data: null, error: null }]
  expect(await delivery.dispatch(OID)).toBeNull()
  expect(notif.sendWhatsappSafe).not.toHaveBeenCalled()
})
```

Tambahkan juga test hook di file baru `src/services/__tests__/orderStatusDeliveryHook.test.js`:

```js
jest.mock('../../config/supabase', () => require('../../testUtils/supabaseQueueMock'))
jest.mock('../notificationService', () => ({
  create: jest.fn(), sendWhatsappSafe: jest.fn(), notifyAdmins: jest.fn(), sendWhatsappToAdmins: jest.fn(),
}))
jest.mock('../deliveryService', () => ({ dispatch: jest.fn() }))
const mock = require('../../testUtils/supabaseQueueMock')
const orderService = require('../orderService')
const deliveryService = require('../deliveryService')

const ID = '11111111-1111-4111-8111-111111111111'
const order = (type) => ({ data: { id: ID, status: 'pending_payment', user_id: null, queue_number: 'A-3', guest_phone: null, total: 25000, order_items: [], source: 'app', order_type: type }, error: null })
const UPDATED = { data: { id: ID, status: 'processing', queue_number: 'A-3' }, error: null }

beforeEach(() => { mock.reset(); jest.clearAllMocks() })

test('order delivery dibayar -> dispatch dipanggil', async () => {
  mock.state.results = [order('delivery'), UPDATED]
  await orderService.updateOrderStatus(ID, 'paid', { fromStatuses: ['pending_payment'] })
  expect(deliveryService.dispatch).toHaveBeenCalledWith(ID)
})

test('order takeaway dibayar -> tanpa dispatch', async () => {
  mock.state.results = [order('takeaway'), UPDATED]
  await orderService.updateOrderStatus(ID, 'paid', { fromStatuses: ['pending_payment'] })
  expect(deliveryService.dispatch).not.toHaveBeenCalled()
})
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx jest src/services/__tests__/deliveryDispatch.test.js src/services/__tests__/orderStatusDeliveryHook.test.js`
Expected: FAIL — `delivery.dispatch is not a function`; hook tidak memanggil dispatch

- [ ] **Step 3: Tambah ke `deliveryService.js`** (di atas `module.exports`, lalu tambahkan ke export)

```js
const notif = require('./notificationService')

const APP_URL = process.env.ORDER_APP_URL || 'https://rehatflutter.vercel.app'
const COURIER_SCREEN_URL = `${APP_URL}/#/courier`

const itemsText = (o) => (o.order_items || [])
  .map((i) => `${i.quantity}x ${i.menu_items?.name || '-'}`).join(', ') || '-'

/** Pesan WA untuk kurir saat ada antaran baru. */
const courierNewDeliveryMessage = (o) => {
  const a = o.delivery_address || {}
  return [
    `*ANTARAN BARU* 🛵 #${o.queue_number}`,
    `${a.recipient_name || '-'} • ${a.recipient_phone || '-'}`,
    `${a.address_text || '-'}${a.notes ? ` (${a.notes})` : ''}`,
    `Peta: https://maps.google.com/?q=${a.lat},${a.lng}`,
    `Jarak ±${((o.delivery_distance_m || 0) / 1000).toFixed(1)} km • Sudah dibayar`,
    `Pesanan: ${itemsText(o)}`,
    `Ambil tugas: ${COURIER_SCREEN_URL}`,
  ].join('\n')
}

/**
 * Kirim pesanan delivery yang baru dibayar ke kurir bertugas. Idempoten:
 * update bersyarat `delivery_status IS NULL` — panggilan kedua tak mengubah apa pun.
 */
const dispatch = async (orderId) => {
  const { data: o, error } = await supabaseAdmin
    .from('orders')
    .update({ delivery_status: 'waiting_courier' })
    .eq('id', orderId)
    .eq('order_type', 'delivery')
    .is('delivery_status', null)
    .select('id, queue_number, delivery_address, delivery_distance_m, order_items(quantity, menu_items(name))')
    .maybeSingle()
  if (error) throw new AppError('DELIVERY_DISPATCH_FAILED', error.message, 500)
  if (!o) return null

  const { data: couriers } = await supabaseAdmin
    .from('users').select('id, phone').eq('role', 'courier').eq('courier_on_duty', true)
  const msg = courierNewDeliveryMessage(o)
  for (const c of couriers || []) {
    await notif.sendWhatsappSafe(c.phone, msg)
    await notif.create(c.id, {
      type: 'general',
      title: `Antaran baru #${o.queue_number} 🛵`,
      body: o.delivery_address?.address_text || 'Buka layar Antaran',
    })
  }
  return o
}
```

Export menjadi:

```js
module.exports = { getConfig, quote, dispatch, courierNewDeliveryMessage, REASON_MESSAGES, COURIER_SCREEN_URL }
```

- [ ] **Step 4: Hook di `updateOrderStatus`** (`src/services/orderService.js`), tepat setelah blok:

```js
  if (status === 'paid' || status === 'completed') {
    await awardPointsAndStamp(orderId)
  }
```

tambahkan:

```js
  // Delivery: begitu dibayar, kirim ke kurir bertugas (WA + layar Antaran).
  // Best-effort: kegagalan dispatch tak boleh menggagalkan konfirmasi pembayaran.
  if (status === 'paid' && order.order_type === 'delivery') {
    try {
      await require('./deliveryService').dispatch(orderId)
    } catch (e) {
      console.error('[delivery] dispatch gagal:', e.message)
    }
  }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `npx jest src/services/__tests__/deliveryDispatch.test.js src/services/__tests__/orderStatusDeliveryHook.test.js src/services/__tests__/orderStatusGuard.test.js`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add src/services/deliveryService.js src/services/orderService.js src/services/__tests__/deliveryDispatch.test.js src/services/__tests__/orderStatusDeliveryHook.test.js
git commit -m "feat(delivery): dispatch otomatis ke kurir bertugas saat pesanan dibayar"
```

---

### Task 9: Aksi kurir (bertugas, daftar, ambil, berangkat, terkirim, gagal)

**Files:**
- Create: `src/services/courierService.js`
- Modify: `src/services/orderService.js` (export `wibDayRange`)
- Modify: `src/routes/delivery.js`
- Test: `src/services/__tests__/courierService.test.js`

- [ ] **Step 1: Write the failing test**

```js
// src/services/__tests__/courierService.test.js
jest.mock('../../config/supabase', () => require('../../testUtils/supabaseQueueMock'))
jest.mock('../notificationService', () => ({
  create: jest.fn(), sendWhatsappSafe: jest.fn(), notifyAdmins: jest.fn(), sendWhatsappToAdmins: jest.fn(),
}))
jest.mock('../orderService', () => ({
  updateOrderStatus: jest.fn(),
  wibDateKey: () => '2026-11-27',
  wibDayRange: () => ({ start: '2026-11-26T17:00:00.000Z', end: '2026-11-27T16:59:59.999Z' }),
}))
const mock = require('../../testUtils/supabaseQueueMock')
const notif = require('../notificationService')
const orderService = require('../orderService')
const courier = require('../courierService')

const OID = '55555555-5555-4555-8555-555555555555'
const ME = { id: 'c1', role: 'courier', name: 'Budi', phone: '0811', courier_on_duty: true }
const ROW = { data: { id: OID, queue_number: 'A-7', user_id: 'u1', users: { phone: '0812' } }, error: null }

beforeEach(() => { mock.reset(); jest.clearAllMocks() })

test('claim: update bersyarat waiting_courier & kabari pelanggan nama+HP kurir', async () => {
  mock.state.results = [ROW]
  await courier.claim(OID, ME)
  const ops = mock.state.calls[0].ops
  expect(ops.find((o) => o[0] === 'update')[1]).toMatchObject({ delivery_status: 'assigned', courier_id: 'c1' })
  expect(ops).toContainEqual(['eq', 'delivery_status', 'waiting_courier'])
  expect(notif.sendWhatsappSafe.mock.calls[0][0]).toBe('0812')
  expect(notif.sendWhatsappSafe.mock.calls[0][1]).toContain('Budi')
})

test('claim kalah balapan -> 409 DELIVERY_NOT_AVAILABLE', async () => {
  mock.state.results = [{ data: null, error: null }]
  await expect(courier.claim(OID, ME)).rejects.toMatchObject({ code: 'DELIVERY_NOT_AVAILABLE', statusCode: 409 })
})

test('advance on_the_way: hanya dari assigned & milik kurir ini', async () => {
  mock.state.results = [ROW]
  await courier.advance(OID, ME, 'on_the_way')
  const ops = mock.state.calls[0].ops
  expect(ops).toContainEqual(['in', 'delivery_status', ['assigned']])
  expect(ops).toContainEqual(['eq', 'courier_id', 'c1'])
  expect(ops.find((o) => o[0] === 'update')[1]).toHaveProperty('picked_up_at')
})

test('advance delivered -> pesanan completed', async () => {
  mock.state.results = [ROW]
  await courier.advance(OID, ME, 'delivered')
  expect(mock.state.calls[0].ops).toContainEqual(['in', 'delivery_status', ['on_the_way']])
  expect(orderService.updateOrderStatus).toHaveBeenCalledWith(OID, 'completed')
})

test('advance failed tanpa alasan -> REASON_REQUIRED', async () => {
  await expect(courier.advance(OID, ME, 'failed', { reason: '' })).rejects.toMatchObject({ code: 'REASON_REQUIRED' })
})

test('advance failed -> admin diberi tahu', async () => {
  mock.state.results = [ROW]
  await courier.advance(OID, ME, 'failed', { reason: 'Pelanggan tidak bisa dihubungi' })
  expect(notif.sendWhatsappToAdmins).toHaveBeenCalled()
})

test('admin boleh advance tanpa filter courier_id', async () => {
  mock.state.results = [ROW]
  await courier.advance(OID, { id: 'a1', role: 'admin' }, 'delivered')
  expect(mock.state.calls[0].ops.some((o) => o[0] === 'eq' && o[1] === 'courier_id')).toBe(false)
})

test('status tidak sesuai -> 409 INVALID_DELIVERY_STATE', async () => {
  mock.state.results = [{ data: null, error: null }]
  await expect(courier.advance(OID, ME, 'delivered')).rejects.toMatchObject({ code: 'INVALID_DELIVERY_STATE' })
})

test('setDuty(false) ditolak bila masih ada antaran aktif', async () => {
  mock.state.results = [{ count: 1, data: null, error: null }]
  await expect(courier.setDuty(ME, false)).rejects.toMatchObject({ code: 'HAS_ACTIVE_DELIVERY' })
})

test('setDuty(true) -> update users', async () => {
  mock.state.results = [{ data: { id: 'c1', courier_on_duty: true }, error: null }]
  const r = await courier.setDuty(ME, true)
  expect(r.courier_on_duty).toBe(true)
  expect(mock.state.calls[0].table).toBe('users')
})

test('listForCourier: menunggu + milikku + jumlah terkirim hari ini', async () => {
  mock.state.results = [{ data: [{ id: 'o1' }], error: null }, { data: [{ id: 'o2' }], error: null }, { count: 3, data: null, error: null }]
  const r = await courier.listForCourier(ME)
  expect(r).toEqual({ on_duty: true, waiting: [{ id: 'o1' }], mine: [{ id: 'o2' }], delivered_today: 3 })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx jest src/services/__tests__/courierService.test.js`
Expected: FAIL — `Cannot find module '../courierService'`

- [ ] **Step 3: Export `wibDayRange`** — di `module.exports` `src/services/orderService.js` ubah baris `wibDateKey,` menjadi `wibDateKey, wibDayRange,`.

- [ ] **Step 4: Write `courierService.js`**

```js
// src/services/courierService.js — aksi kurir & pengelolaan kurir oleh admin.
const { supabaseAdmin } = require('../config/supabase')
const { AppError } = require('../middleware/response')
const notif = require('./notificationService')

const ACTIVE = ['assigned', 'on_the_way']
const TRANSITIONS = {
  on_the_way: ['assigned'],
  delivered: ['on_the_way'],
  failed: ['assigned', 'on_the_way'],
}
const ORDER_COLS = 'id, queue_number, user_id, delivery_address, users!user_id(phone)'
const LIST_COLS = 'id, queue_number, delivery_status, delivery_address, delivery_distance_m, total, courier_id, courier_assigned_at, picked_up_at, order_items(quantity, customization, menu_items(name))'
const nowIso = () => new Date().toISOString()

const tellCustomer = async (o, text) => {
  await notif.sendWhatsappSafe(o?.users?.phone, `*Rehat Coffeehouse* 🛵\n${text}`)
  if (o?.user_id) await notif.create(o.user_id, { type: 'general', title: 'Update antaran', body: text })
}

const claim = async (orderId, courier) => {
  const { data: o, error } = await supabaseAdmin
    .from('orders')
    .update({ delivery_status: 'assigned', courier_id: courier.id, courier_assigned_at: nowIso() })
    .eq('id', orderId)
    .eq('delivery_status', 'waiting_courier')
    .select(ORDER_COLS)
    .maybeSingle()
  if (error) throw new AppError('DELIVERY_UPDATE_FAILED', error.message, 500)
  if (!o) throw new AppError('DELIVERY_NOT_AVAILABLE', 'Antaran ini sudah diambil kurir lain atau tidak tersedia', 409)
  await tellCustomer(o, `Pesanan #${o.queue_number} akan diantar oleh *${courier.name || 'kurir Rehat'}* (${courier.phone || '-'}).`)
  return o
}

const advance = async (orderId, actor, next, { reason } = {}) => {
  if (!TRANSITIONS[next]) throw new AppError('INVALID_DELIVERY_STATE', 'Status antaran tidak dikenal', 400)
  const patch = { delivery_status: next }
  if (next === 'on_the_way') patch.picked_up_at = nowIso()
  if (next === 'delivered') patch.delivered_at = nowIso()
  if (next === 'failed') {
    const r = String(reason || '').trim()
    if (r.length < 3) throw new AppError('REASON_REQUIRED', 'Alasan gagal wajib diisi (min 3 karakter)', 400)
    patch.delivery_fail_reason = r.slice(0, 300)
  }
  let query = supabaseAdmin.from('orders').update(patch).eq('id', orderId)
    .in('delivery_status', TRANSITIONS[next])
  if (actor.role !== 'admin') query = query.eq('courier_id', actor.id)
  const { data: o, error } = await query.select(ORDER_COLS).maybeSingle()
  if (error) throw new AppError('DELIVERY_UPDATE_FAILED', error.message, 500)
  if (!o) throw new AppError('INVALID_DELIVERY_STATE', 'Status antaran tidak bisa diubah dari kondisi sekarang', 409)

  if (next === 'on_the_way') {
    await tellCustomer(o, `Pesanan #${o.queue_number} sedang diantar ke alamatmu.`)
  }
  if (next === 'delivered') {
    // Memicu alur "selesai" yang sudah ada (completed_at + WA "selesai").
    await require('./orderService').updateOrderStatus(orderId, 'completed')
  }
  if (next === 'failed') {
    const msg = `Antaran #${o.queue_number} GAGAL: ${patch.delivery_fail_reason}. Pilihkan kurir lain atau refund ke Saldo Rehat.`
    await notif.notifyAdmins({ type: 'general', title: 'Antaran gagal', body: msg })
    await notif.sendWhatsappToAdmins(msg)
  }
  return o
}

const setDuty = async (courier, onDuty) => {
  if (!onDuty) {
    const { count } = await supabaseAdmin
      .from('orders').select('id', { count: 'exact', head: true })
      .eq('courier_id', courier.id).in('delivery_status', ACTIVE)
    if ((count || 0) > 0) {
      throw new AppError('HAS_ACTIVE_DELIVERY', 'Selesaikan antaran yang sedang berjalan dulu', 409)
    }
  }
  const { data, error } = await supabaseAdmin
    .from('users').update({ courier_on_duty: !!onDuty }).eq('id', courier.id)
    .select('id, courier_on_duty').single()
  if (error) throw new AppError('COURIER_UPDATE_FAILED', error.message, 500)
  return data
}

const listForCourier = async (courier) => {
  const { wibDayRange, wibDateKey } = require('./orderService')
  const { data: waiting } = await supabaseAdmin
    .from('orders').select(LIST_COLS).eq('delivery_status', 'waiting_courier')
    .order('ordered_at', { ascending: true })
  const { data: mine } = await supabaseAdmin
    .from('orders').select(LIST_COLS).eq('courier_id', courier.id).in('delivery_status', ACTIVE)
    .order('courier_assigned_at', { ascending: true })
  const { count } = await supabaseAdmin
    .from('orders').select('id', { count: 'exact', head: true })
    .eq('courier_id', courier.id).eq('delivery_status', 'delivered')
    .gte('delivered_at', wibDayRange(wibDateKey()).start)
  return { on_duty: !!courier.courier_on_duty, waiting: waiting || [], mine: mine || [], delivered_today: count || 0 }
}

module.exports = { claim, advance, setDuty, listForCourier, ACTIVE, ORDER_COLS }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `npx jest src/services/__tests__/courierService.test.js`
Expected: PASS

- [ ] **Step 6: Endpoint kurir** — di `src/routes/delivery.js` ubah import auth & tambah require, lalu tambahkan route sebelum `module.exports`:

```js
const { authenticate, courierAccess } = require('../middleware/auth')
const courierService = require('../services/courierService')
```

```js
router.get('/courier/deliveries', courierAccess, async (req, res, next) => {
  try { return success(res, await courierService.listForCourier(req.user)) } catch (err) { next(err) }
})

router.patch('/courier/duty', courierAccess, async (req, res, next) => {
  try {
    const { on_duty } = z.object({ on_duty: z.boolean() }).parse(req.body)
    return success(res, await courierService.setDuty(req.user, on_duty))
  } catch (err) { next(err) }
})

router.post('/courier/deliveries/:id/claim', courierAccess, async (req, res, next) => {
  try { return success(res, await courierService.claim(req.params.id, req.user), 'Antaran diambil') } catch (err) { next(err) }
})

for (const [path, status] of [['on-the-way', 'on_the_way'], ['delivered', 'delivered'], ['failed', 'failed']]) {
  router.post(`/courier/deliveries/:id/${path}`, courierAccess, async (req, res, next) => {
    try {
      const data = await courierService.advance(req.params.id, req.user, status, { reason: req.body?.reason })
      return success(res, data, 'Status antaran diperbarui')
    } catch (err) { next(err) }
  })
}
```

- [ ] **Step 7: Run all tests**

Run: `npm test`
Expected: PASS (semua, termasuk test lama)

- [ ] **Step 8: Commit**

```bash
git add src/services/courierService.js src/services/orderService.js src/routes/delivery.js src/services/__tests__/courierService.test.js
git commit -m "feat(delivery): aksi kurir — bertugas, ambil, berangkat, terkirim, gagal"
```

---

### Task 10: Admin — pilihkan kurir, kelola kurir, pengaturan & jam toko

**Files:**
- Modify: `src/services/courierService.js` (tambah `assign`, `listCouriers`, `addCourier`, `removeCourier`)
- Modify: `src/services/deliveryService.js` (tambah `getStoreSettings`, `updateStoreSettings`, `replaceStoreHours`)
- Modify: `src/routes/delivery.js`
- Test: `src/services/__tests__/deliveryAdmin.test.js`

- [ ] **Step 1: Write the failing test**

```js
// src/services/__tests__/deliveryAdmin.test.js
jest.mock('../../config/supabase', () => require('../../testUtils/supabaseQueueMock'))
jest.mock('../notificationService', () => ({
  create: jest.fn(), sendWhatsappSafe: jest.fn(), notifyAdmins: jest.fn(), sendWhatsappToAdmins: jest.fn(),
}))
const mock = require('../../testUtils/supabaseQueueMock')
const notif = require('../notificationService')
const courier = require('../courierService')
const delivery = require('../deliveryService')

const OID = '55555555-5555-4555-8555-555555555555'
beforeEach(() => { mock.reset(); jest.clearAllMocks() })

test('assign: hanya ke user ber-role courier', async () => {
  mock.state.results = [{ data: { id: 'x', role: 'customer' }, error: null }]
  await expect(courier.assign(OID, 'x')).rejects.toMatchObject({ code: 'NOT_A_COURIER' })
})

test('assign: update dari waiting/assigned/failed, WA ke kurir & pelanggan', async () => {
  mock.state.results = [
    { data: { id: 'c1', role: 'courier', name: 'Budi', phone: '0811' }, error: null },
    { data: { id: OID, queue_number: 'A-7', user_id: 'u1', users: { phone: '0812' } }, error: null },
  ]
  await courier.assign(OID, 'c1')
  expect(mock.state.calls[1].ops).toContainEqual(['in', 'delivery_status', ['waiting_courier', 'assigned', 'failed']])
  const phones = notif.sendWhatsappSafe.mock.calls.map((c) => c[0])
  expect(phones).toEqual(expect.arrayContaining(['0811', '0812']))
})

test('addCourier: hanya mengubah akun customer dengan nomor itu', async () => {
  mock.state.results = [{ data: { id: 'c9', name: 'Andi', phone: '0899', role: 'courier' }, error: null }]
  const r = await courier.addCourier('0899')
  expect(r.role).toBe('courier')
  expect(mock.state.calls[0].ops).toContainEqual(['eq', 'role', 'customer'])
})

test('addCourier: nomor tidak ditemukan -> 404', async () => {
  mock.state.results = [{ data: null, error: null }]
  await expect(courier.addCourier('0000')).rejects.toMatchObject({ code: 'USER_NOT_FOUND' })
})

test('removeCourier: ditolak bila masih ada antaran aktif', async () => {
  mock.state.results = [{ count: 2, data: null, error: null }]
  await expect(courier.removeCourier('c1')).rejects.toMatchObject({ code: 'HAS_ACTIVE_DELIVERY' })
})

test('replaceStoreHours: upsert 7 baris', async () => {
  const rows = [0, 1, 2, 3, 4, 5, 6].map((d) => ({ day_of_week: d, open_time: '10:00', close_time: '00:00', is_closed: false }))
  mock.state.results = [{ data: rows, error: null }]
  await delivery.replaceStoreHours(rows)
  expect(mock.state.calls[0].ops.find((o) => o[0] === 'upsert')[1]).toHaveLength(7)
})

test('updateStoreSettings: menulis ke baris id=1 dengan updated_at', async () => {
  mock.state.results = [{ data: { id: 1, delivery_enabled: true }, error: null }]
  await delivery.updateStoreSettings({ delivery_enabled: true })
  const ops = mock.state.calls[0].ops
  expect(ops.find((o) => o[0] === 'update')[1]).toMatchObject({ delivery_enabled: true })
  expect(ops.find((o) => o[0] === 'update')[1]).toHaveProperty('updated_at')
  expect(ops).toContainEqual(['eq', 'id', 1])
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx jest src/services/__tests__/deliveryAdmin.test.js`
Expected: FAIL — `courier.assign is not a function`

- [ ] **Step 3: Tambah ke `courierService.js`** (sebelum `module.exports`; tambahkan nama-nama baru ke export)

```js
const assign = async (orderId, courierId) => {
  const { data: c } = await supabaseAdmin
    .from('users').select('id, role, name, phone').eq('id', courierId).maybeSingle()
  if (!c || c.role !== 'courier') throw new AppError('NOT_A_COURIER', 'User ini bukan kurir', 400)
  const { data: o, error } = await supabaseAdmin
    .from('orders')
    .update({ delivery_status: 'assigned', courier_id: c.id, courier_assigned_at: nowIso(), delivery_fail_reason: null })
    .eq('id', orderId)
    .in('delivery_status', ['waiting_courier', 'assigned', 'failed'])
    .select(ORDER_COLS)
    .maybeSingle()
  if (error) throw new AppError('DELIVERY_UPDATE_FAILED', error.message, 500)
  if (!o) throw new AppError('INVALID_DELIVERY_STATE', 'Antaran ini tidak bisa dipindahkan sekarang', 409)
  const { COURIER_SCREEN_URL } = require('./deliveryService')
  await notif.sendWhatsappSafe(c.phone, `*Rehat* 🛵 Kamu ditugaskan mengantar #${o.queue_number}.\nBuka: ${COURIER_SCREEN_URL}`)
  await tellCustomer(o, `Pesanan #${o.queue_number} akan diantar oleh *${c.name || 'kurir Rehat'}* (${c.phone || '-'}).`)
  return o
}

const listCouriers = async () => {
  const { data, error } = await supabaseAdmin
    .from('users').select('id, name, phone, courier_on_duty').eq('role', 'courier').order('name')
  if (error) throw new AppError('COURIER_FETCH_FAILED', error.message, 500)
  return data || []
}

/** Jadikan akun pelanggan (berdasarkan no. HP) sebagai kurir. Admin tidak diturunkan. */
const addCourier = async (phone) => {
  const { data, error } = await supabaseAdmin
    .from('users').update({ role: 'courier' })
    .eq('phone', String(phone).trim()).eq('role', 'customer')
    .select('id, name, phone, role').maybeSingle()
  if (error) throw new AppError('COURIER_UPDATE_FAILED', error.message, 500)
  if (!data) throw new AppError('USER_NOT_FOUND', 'Akun pelanggan dengan nomor itu tidak ditemukan', 404)
  return data
}

const removeCourier = async (courierId) => {
  const { count } = await supabaseAdmin
    .from('orders').select('id', { count: 'exact', head: true })
    .eq('courier_id', courierId).in('delivery_status', ACTIVE)
  if ((count || 0) > 0) throw new AppError('HAS_ACTIVE_DELIVERY', 'Kurir ini masih punya antaran aktif', 409)
  const { data, error } = await supabaseAdmin
    .from('users').update({ role: 'customer', courier_on_duty: false })
    .eq('id', courierId).eq('role', 'courier')
    .select('id').maybeSingle()
  if (error) throw new AppError('COURIER_UPDATE_FAILED', error.message, 500)
  if (!data) throw new AppError('USER_NOT_FOUND', 'Kurir tidak ditemukan', 404)
  return { id: courierId }
}
```

Export menjadi:

```js
module.exports = { claim, advance, setDuty, listForCourier, assign, listCouriers, addCourier, removeCourier, ACTIVE, ORDER_COLS }
```

- [ ] **Step 4: Tambah ke `deliveryService.js`** (dan ke export)

```js
const getStoreSettings = async () => {
  const { data: settings } = await supabaseAdmin.from('store_settings').select('*').eq('id', 1).maybeSingle()
  const { data: hours } = await supabaseAdmin.from('store_hours').select('*').order('day_of_week')
  return { settings, hours: hours || [] }
}

const updateStoreSettings = async (patch) => {
  const { data, error } = await supabaseAdmin
    .from('store_settings').update({ ...patch, updated_at: new Date().toISOString() })
    .eq('id', 1).select('*').single()
  if (error) throw new AppError('DELIVERY_SETTINGS_FAILED', error.message, 500)
  return data
}

const replaceStoreHours = async (rows) => {
  const { data, error } = await supabaseAdmin
    .from('store_hours').upsert(rows, { onConflict: 'day_of_week' }).select('*')
  if (error) throw new AppError('STORE_HOURS_FAILED', error.message, 500)
  return data
}
```

```js
module.exports = {
  getConfig, quote, dispatch, courierNewDeliveryMessage, getStoreSettings, updateStoreSettings, replaceStoreHours,
  REASON_MESSAGES, COURIER_SCREEN_URL,
}
```

- [ ] **Step 5: Endpoint admin** — di `src/routes/delivery.js` ubah import auth menjadi `const { authenticate, adminAccess, courierAccess } = require('../middleware/auth')` lalu tambahkan:

```js
const settingsSchema = z.object({
  store_lat: z.number().min(-90).max(90),
  store_lng: z.number().min(-180).max(180),
  store_address: z.string().trim().max(300),
  delivery_enabled: z.boolean(),
  delivery_radius_m: z.number().int().min(500).max(20000),
  delivery_fee: z.number().int().min(0).max(100000),
  free_delivery_min: z.number().int().min(0).max(10000000),
  delivery_cutoff_minutes: z.number().int().min(0).max(240),
}).partial()
const TIME = z.string().regex(/^\d{2}:\d{2}$/).nullable()
const hoursSchema = z.array(z.object({
  day_of_week: z.number().int().min(0).max(6),
  open_time: TIME,
  close_time: TIME,
  is_closed: z.boolean(),
})).length(7)

router.get('/admin/store-settings', adminAccess, async (req, res, next) => {
  try { return success(res, await deliveryService.getStoreSettings()) } catch (err) { next(err) }
})
router.patch('/admin/store-settings', adminAccess, async (req, res, next) => {
  try { return success(res, await deliveryService.updateStoreSettings(settingsSchema.parse(req.body)), 'Pengaturan disimpan') } catch (err) { next(err) }
})
router.put('/admin/store-hours', adminAccess, async (req, res, next) => {
  try { return success(res, await deliveryService.replaceStoreHours(hoursSchema.parse(req.body)), 'Jam buka disimpan') } catch (err) { next(err) }
})
router.get('/admin/couriers', adminAccess, async (req, res, next) => {
  try { return success(res, await courierService.listCouriers()) } catch (err) { next(err) }
})
router.post('/admin/couriers', adminAccess, async (req, res, next) => {
  try {
    const { phone } = z.object({ phone: z.string().trim().min(8).max(25) }).parse(req.body)
    return created(res, await courierService.addCourier(phone), 'Kurir ditambahkan')
  } catch (err) { next(err) }
})
router.delete('/admin/couriers/:id', adminAccess, async (req, res, next) => {
  try { return success(res, await courierService.removeCourier(req.params.id), 'Kurir dicabut') } catch (err) { next(err) }
})
router.post('/admin/orders/:id/assign-courier', adminAccess, async (req, res, next) => {
  try {
    const { courier_id } = z.object({ courier_id: z.string().uuid() }).parse(req.body)
    return success(res, await courierService.assign(req.params.id, courier_id), 'Kurir ditetapkan')
  } catch (err) { next(err) }
})
```

- [ ] **Step 6: Run tests**

Run: `npx jest src/services/__tests__/deliveryAdmin.test.js && npm test`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add src/services/courierService.js src/services/deliveryService.js src/routes/delivery.js src/services/__tests__/deliveryAdmin.test.js
git commit -m "feat(delivery): admin — pilihkan kurir, kelola kurir, pengaturan & jam toko"
```

---

### Task 11: Refund pesanan delivery ke Saldo Rehat

**Files:**
- Modify: `src/services/deliveryService.js` (tambah `refundDelivery`, `reverseOrderLoyalty`)
- Modify: `src/routes/delivery.js`
- Test: `src/services/__tests__/deliveryRefund.test.js`

Perilaku: hanya pesanan `order_type = 'delivery'` yang sudah dibayar (`paid`/`processing`) dan belum `delivered`.
Update bersyarat → refund tidak bisa terjadi dua kali. Mode `wallet` mengkredit `total` (termasuk ongkir) ke Saldo
Rehat; mode `manual` (sudah ditransfer di luar app) hanya menandai. Poin yang dibelanjakan (`loyalty_points`) dan
1 stamp ditarik kembali; `lifetime_points`/tier tidak diubah (sengaja, YAGNI). Baris pembalikan di
`loyalty_history` memakai `type: 'redeem'` dan `ref_order_id: null` (agar pengecekan idempoten `awardPointsAndStamp`
yang memakai `maybeSingle()` per `ref_order_id` tidak rusak).

- [ ] **Step 1: Write the failing test**

```js
// src/services/__tests__/deliveryRefund.test.js
jest.mock('../../config/supabase', () => require('../../testUtils/supabaseQueueMock'))
jest.mock('../notificationService', () => ({
  create: jest.fn(), sendWhatsappSafe: jest.fn(), notifyAdmins: jest.fn(), sendWhatsappToAdmins: jest.fn(),
}))
const mock = require('../../testUtils/supabaseQueueMock')
const delivery = require('../deliveryService')

const OID = '55555555-5555-4555-8555-555555555555'
const ORDER = (over = {}) => ({ data: { id: OID, status: 'processing', order_type: 'delivery', user_id: 'u1', total: 25000, points_earned: 20, delivery_status: 'failed', queue_number: 'A-7', users: { phone: '0812' }, ...over }, error: null })

beforeEach(() => mock.reset())

test('alasan kosong -> REFUND_REASON_REQUIRED', async () => {
  await expect(delivery.refundDelivery(OID, 'admin1', { reason: '' })).rejects.toMatchObject({ code: 'REFUND_REASON_REQUIRED' })
})

test('bukan delivery -> NOT_DELIVERY', async () => {
  mock.state.results = [ORDER({ order_type: 'takeaway' })]
  await expect(delivery.refundDelivery(OID, 'admin1', { reason: 'Kurir sakit' })).rejects.toMatchObject({ code: 'NOT_DELIVERY' })
})

test('sudah terkirim -> ALREADY_DELIVERED', async () => {
  mock.state.results = [ORDER({ delivery_status: 'delivered' })]
  await expect(delivery.refundDelivery(OID, 'admin1', { reason: 'Kurir sakit' })).rejects.toMatchObject({ code: 'ALREADY_DELIVERED' })
})

test('wallet: update bersyarat, kredit saldo total, tarik poin & stamp', async () => {
  mock.state.results = [
    ORDER(), // baca pesanan
    { data: { id: OID }, error: null }, // update bersyarat status
    // applyTxn: rpc (antrean rpc) lalu insert wallet_transactions
    { data: null, error: null },
    { data: { user_id: 'u1', amount: 20 }, error: null }, // loyalty earn
    { data: { loyalty_points: 120 }, error: null }, // users poin
    { data: null, error: null }, // update users
    { data: null, error: null }, // insert loyalty_history pembalikan
    { data: { stamp_count: 4 }, error: null }, // stamp
    { data: null, error: null }, // update stamp
  ]
  mock.state.rpcResults = [{ data: 25000, error: null }]
  const r = await delivery.refundDelivery(OID, 'admin1', { reason: 'Kurir sakit', mode: 'wallet' })
  expect(r).toMatchObject({ id: OID, refunded_to: 'wallet', amount: 25000 })
  expect(mock.state.calls[1].ops).toContainEqual(['in', 'status', ['paid', 'processing']])
  expect(mock.state.calls[1].ops.find((o) => o[0] === 'update')[1]).toMatchObject({ status: 'refunded', delivery_status: 'cancelled', refund_reason: 'Kurir sakit' })
  expect(mock.state.rpcCalls[0]).toEqual(['increment_balance', { p_user: 'u1', p_delta: 25000 }])
  const usersUpdate = mock.state.calls.find((c) => c.table === 'users' && c.ops.some((o) => o[0] === 'update'))
  expect(usersUpdate.ops.find((o) => o[0] === 'update')[1]).toEqual({ loyalty_points: 100 })
  const hist = mock.state.calls.filter((c) => c.table === 'loyalty_history').pop()
  expect(hist.ops.find((o) => o[0] === 'insert')[1]).toMatchObject({ type: 'redeem', amount: 20, ref_order_id: null })
  const stampUpd = mock.state.calls.filter((c) => c.table === 'stamp_cards').pop()
  expect(stampUpd.ops.find((o) => o[0] === 'update')[1]).toMatchObject({ stamp_count: 3 })
})

test('kalah balapan (sudah di-refund) -> 409', async () => {
  mock.state.results = [ORDER(), { data: null, error: null }]
  await expect(delivery.refundDelivery(OID, 'admin1', { reason: 'Kurir sakit' })).rejects.toMatchObject({ code: 'REFUND_NOT_ALLOWED' })
})

test('manual: tanpa kredit saldo', async () => {
  mock.state.results = [ORDER({ points_earned: 0 }), { data: { id: OID }, error: null }, { data: null, error: null }]
  const r = await delivery.refundDelivery(OID, 'admin1', { reason: 'Sudah transfer BCA', mode: 'manual' })
  expect(r.refunded_to).toBe('manual')
  expect(mock.state.rpcCalls).toHaveLength(0)
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx jest src/services/__tests__/deliveryRefund.test.js`
Expected: FAIL — `delivery.refundDelivery is not a function`

- [ ] **Step 3: Implementasi** — tambah ke `deliveryService.js` (dan ke export: `refundDelivery`)

```js
const REFUNDABLE = ['paid', 'processing']

/** Tarik kembali poin (saldo belanja) & 1 stamp dari pesanan yang dibatalkan. */
const reverseOrderLoyalty = async (orderId, queueNumber) => {
  const { data: earn } = await supabaseAdmin
    .from('loyalty_history').select('user_id, amount')
    .eq('ref_order_id', orderId).eq('type', 'earn').maybeSingle()
  if (!earn) return
  const { data: u } = await supabaseAdmin
    .from('users').select('loyalty_points').eq('id', earn.user_id).maybeSingle()
  const newPoints = Math.max(0, (u?.loyalty_points || 0) - earn.amount)
  await supabaseAdmin.from('users').update({ loyalty_points: newPoints }).eq('id', earn.user_id)
  await supabaseAdmin.from('loyalty_history').insert({
    user_id: earn.user_id,
    type: 'redeem',
    amount: earn.amount,
    description: `Pembatalan pesanan #${queueNumber || orderId.substring(0, 8).toUpperCase()}`,
    balance_after: newPoints,
    ref_order_id: null,
  })
  const { data: stamp } = await supabaseAdmin
    .from('stamp_cards').select('stamp_count').eq('user_id', earn.user_id).maybeSingle()
  if (stamp) {
    await supabaseAdmin.from('stamp_cards')
      .update({ stamp_count: Math.max(0, (stamp.stamp_count || 0) - 1), updated_at: new Date().toISOString() })
      .eq('user_id', earn.user_id)
  }
}

/**
 * Batalkan pesanan delivery yang sudah dibayar & kembalikan dananya.
 * mode 'wallet' = kredit `total` ke Saldo Rehat; 'manual' = sudah ditransfer di luar app.
 */
const refundDelivery = async (orderId, adminUserId, { reason, mode = 'wallet' } = {}) => {
  const cleanReason = String(reason || '').trim()
  if (cleanReason.length < 3) {
    throw new AppError('REFUND_REASON_REQUIRED', 'Alasan refund wajib diisi (min 3 karakter)', 400)
  }
  const { data: o } = await supabaseAdmin
    .from('orders')
    .select('id, status, order_type, user_id, total, points_earned, delivery_status, queue_number, users!user_id(phone)')
    .eq('id', orderId).maybeSingle()
  if (!o) throw new AppError('ORDER_NOT_FOUND', 'Pesanan tidak ditemukan', 404)
  if (o.order_type !== 'delivery') throw new AppError('NOT_DELIVERY', 'Bukan pesanan delivery', 400)
  if (o.delivery_status === 'delivered') throw new AppError('ALREADY_DELIVERED', 'Pesanan sudah terkirim', 400)

  const { data: upd } = await supabaseAdmin
    .from('orders')
    .update({
      status: 'refunded',
      delivery_status: 'cancelled',
      refunded_at: new Date().toISOString(),
      refunded_by: adminUserId || null,
      refund_reason: cleanReason,
    })
    .eq('id', orderId)
    .in('status', REFUNDABLE)
    .select('id')
    .maybeSingle()
  if (!upd) {
    throw new AppError('REFUND_NOT_ALLOWED', 'Pesanan ini tidak bisa di-refund (belum dibayar atau sudah di-refund/dibatalkan)', 409)
  }

  if (mode === 'wallet') {
    await require('./walletService').applyTxn(o.user_id, o.total, 'refund', {
      description: `Refund pesanan #${o.queue_number}`, ref: orderId,
    })
  }
  if (o.points_earned > 0) await reverseOrderLoyalty(orderId, o.queue_number)

  const text = mode === 'wallet'
    ? `Pesanan #${o.queue_number} dibatalkan. Rp ${Number(o.total).toLocaleString('id-ID')} sudah dikembalikan ke Saldo Rehat kamu.`
    : `Pesanan #${o.queue_number} dibatalkan dan dananya sudah dikembalikan.`
  await notif.sendWhatsappSafe(o.users?.phone, `*Rehat Coffeehouse*\n${text}`)
  if (o.user_id) await notif.create(o.user_id, { type: 'general', title: 'Pesanan dibatalkan', body: text })

  return { id: orderId, refunded_to: mode, amount: o.total }
}
```

- [ ] **Step 4: Endpoint** — di `src/routes/delivery.js`:

```js
router.post('/admin/orders/:id/delivery-refund', adminAccess, async (req, res, next) => {
  try {
    const { reason, mode } = z.object({
      reason: z.string().trim().min(3).max(300),
      mode: z.enum(['wallet', 'manual']).default('wallet'),
    }).parse(req.body)
    const data = await deliveryService.refundDelivery(req.params.id, req.user?.id, { reason, mode })
    return success(res, data, 'Pesanan dibatalkan & dana dikembalikan')
  } catch (err) { next(err) }
})
```

- [ ] **Step 5: Run tests**

Run: `npx jest src/services/__tests__/deliveryRefund.test.js && npm test`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add src/services/deliveryService.js src/routes/delivery.js src/services/__tests__/deliveryRefund.test.js
git commit -m "feat(delivery): refund pesanan delivery ke Saldo Rehat + tarik poin & stamp"
```

---

### Task 12: Pengingat antaran belum diambil (10 menit)

**Files:**
- Modify: `src/services/deliveryService.js` (tambah `remindUnclaimed`)
- Modify: `src/index.js`
- Test: `src/services/__tests__/deliveryReminder.test.js`

- [ ] **Step 1: Write the failing test**

```js
// src/services/__tests__/deliveryReminder.test.js
jest.mock('../../config/supabase', () => require('../../testUtils/supabaseQueueMock'))
jest.mock('../notificationService', () => ({
  create: jest.fn(), sendWhatsappSafe: jest.fn(), notifyAdmins: jest.fn(), sendWhatsappToAdmins: jest.fn(),
}))
const mock = require('../../testUtils/supabaseQueueMock')
const notif = require('../notificationService')
const delivery = require('../deliveryService')

beforeEach(() => { mock.reset(); jest.clearAllMocks() })

test('menandai & mengingatkan admin sekali untuk antaran > 10 menit', async () => {
  const now = new Date('2026-11-27T12:00:00Z')
  mock.state.results = [{ data: [{ id: 'o1', queue_number: 'A-7' }], error: null }]
  const n = await delivery.remindUnclaimed(now)
  expect(n).toBe(1)
  const ops = mock.state.calls[0].ops
  expect(ops).toContainEqual(['eq', 'delivery_status', 'waiting_courier'])
  expect(ops).toContainEqual(['is', 'courier_reminded_at', null])
  expect(ops).toContainEqual(['lte', 'paid_at', '2026-11-27T11:50:00.000Z'])
  expect(notif.sendWhatsappToAdmins).toHaveBeenCalledWith(expect.stringContaining('#A-7'))
})

test('tidak ada -> 0, tanpa WA', async () => {
  mock.state.results = [{ data: [], error: null }]
  expect(await delivery.remindUnclaimed(new Date())).toBe(0)
  expect(notif.sendWhatsappToAdmins).not.toHaveBeenCalled()
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx jest src/services/__tests__/deliveryReminder.test.js`
Expected: FAIL — `delivery.remindUnclaimed is not a function`

- [ ] **Step 3: Implementasi** — tambah ke `deliveryService.js` (dan export `remindUnclaimed`)

```js
const REMIND_AFTER_MS = 10 * 60 * 1000

/** Satu kali pengingat ke admin untuk antaran yang >10 menit belum diambil kurir. */
const remindUnclaimed = async (now = new Date()) => {
  const { data } = await supabaseAdmin
    .from('orders')
    .update({ courier_reminded_at: now.toISOString() })
    .eq('delivery_status', 'waiting_courier')
    .is('courier_reminded_at', null)
    .lte('paid_at', new Date(now.getTime() - REMIND_AFTER_MS).toISOString())
    .select('id, queue_number')
  for (const o of data || []) {
    const msg = `Antaran #${o.queue_number} belum diambil kurir lebih dari 10 menit. Pilihkan kurir di menu Pesanan.`
    await notif.notifyAdmins({ type: 'general', title: 'Antaran belum diambil', body: msg })
    await notif.sendWhatsappToAdmins(msg)
  }
  return (data || []).length
}
```

- [ ] **Step 4: Jadwalkan** di `src/index.js`, setelah pemanggilan `app.listen(...)`:

```js
// Pengingat antaran delivery yang belum diambil kurir (cek tiap 2 menit).
if (process.env.NODE_ENV !== 'test') {
  const deliveryService = require('./services/deliveryService')
  setInterval(() => {
    deliveryService.remindUnclaimed().catch((e) => console.error('[delivery] pengingat gagal:', e.message))
  }, 2 * 60 * 1000).unref()
}
```

- [ ] **Step 5: Run tests**

Run: `npx jest src/services/__tests__/deliveryReminder.test.js && npm test`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add src/services/deliveryService.js src/index.js src/services/__tests__/deliveryReminder.test.js
git commit -m "feat(delivery): pengingat admin bila antaran belum diambil 10 menit"
```

---

### Task 13: Laporan — `delivery_income` & ringkasan delivery di tutup kasir

**Files:**
- Modify: `src/services/orderService.js` (`getSalesReport` baris ±683–817; `getClosingReport` baris ±875–928)
- Test: `src/services/__tests__/deliveryReports.test.js`

- [ ] **Step 1: Write the failing test**

```js
// src/services/__tests__/deliveryReports.test.js
jest.mock('../../config/supabase', () => require('../../testUtils/supabaseQueueMock'))
jest.mock('../notificationService', () => ({
  create: jest.fn(), sendWhatsappSafe: jest.fn(), notifyAdmins: jest.fn(), sendWhatsappToAdmins: jest.fn(),
}))
jest.mock('../expenseService', () => ({ sumBetween: jest.fn().mockResolvedValue(0) }))
jest.mock('../loyaltyService', () => ({ getStampRedemptionStats: jest.fn().mockResolvedValue({ issued: 0, used: 0 }) }))
const mock = require('../../testUtils/supabaseQueueMock')
const orderService = require('../orderService')

beforeEach(() => mock.reset())

test('summarizeDeliveries: jumlah, ongkir, terkirim per kurir', () => {
  const r = orderService.summarizeDeliveries([
    { delivery_fee: 5000, delivery_status: 'delivered', courier: { name: 'Budi' } },
    { delivery_fee: 0, delivery_status: 'delivered', courier: { name: 'Budi' } },
    { delivery_fee: 5000, delivery_status: 'on_the_way', courier: { name: 'Andi' } },
  ])
  expect(r).toEqual({ count: 3, fee_income: 10000, by_courier: [{ name: 'Budi', delivered: 2 }] })
})

test('getSalesReport: delivery_income dari kolom delivery_fee', async () => {
  const now = new Date().toISOString()
  mock.state.results = [
    { data: [
      { total: 25000, delivery_fee: 5000, status: 'completed', payment_method: 'qris', ordered_at: now, order_items: [] },
      { total: 30000, delivery_fee: 0, status: 'completed', payment_method: 'cash', ordered_at: now, order_items: [] },
    ], error: null },
    { count: 0, data: null, error: null }, // menu tanpa HPP
  ]
  const r = await orderService.getSalesReport('today')
  expect(r.summary.revenue).toBe(55000)
  expect(r.summary.delivery_income).toBe(5000)
  expect(mock.state.calls[0].ops.find((o) => o[0] === 'select')[1]).toContain('delivery_fee')
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx jest src/services/__tests__/deliveryReports.test.js`
Expected: FAIL — `orderService.summarizeDeliveries is not a function`

- [ ] **Step 3: Ubah `getSalesReport`**

Di `buildQuery`, ganti select menjadi:

```js
    .select(`total, delivery_fee, status, payment_method, ordered_at, order_items(quantity, subtotal, menu_items(name${withCost ? ', cost_price' : ''}))`)
```

Di deklarasi akumulator (setelah `let revenue = 0`) tambah:

```js
  let deliveryIncome = 0 // bagian omzet dari ongkir delivery (kurir Rehat sendiri)
```

Di loop `for (const o of orders)`, setelah `revenue += total` tambah:

```js
    deliveryIncome += Number(o.delivery_fee) || 0
```

Di objek `summary`, setelah `revenue,` tambah:

```js
      // Ongkir delivery yang ikut omzet (kurir Rehat sendiri).
      delivery_income: deliveryIncome,
```

- [ ] **Step 4: Tambah `summarizeDeliveries` & blok delivery di `getClosingReport`**

Di atas `getClosingReport`:

```js
/** Ringkasan antaran hari itu untuk tutup kasir. */
const summarizeDeliveries = (rows) => {
  const byCourier = {}
  let feeIncome = 0
  for (const d of rows || []) {
    feeIncome += Number(d.delivery_fee) || 0
    if (d.delivery_status === 'delivered') {
      const name = d.courier?.name || 'Tanpa nama'
      byCourier[name] = (byCourier[name] || 0) + 1
    }
  }
  return {
    count: (rows || []).length,
    fee_income: feeIncome,
    by_courier: Object.entries(byCourier).map(([name, delivered]) => ({ name, delivered })),
  }
}
```

Di `getClosingReport`, sebelum `const expenses = sales.summary.expenses`:

```js
  const { data: deliveryRows } = await supabaseAdmin
    .from('orders')
    .select('delivery_fee, delivery_status, courier:users!courier_id(name)')
    .eq('order_type', 'delivery')
    .in('status', SOLD_STATUSES)
    .gte('ordered_at', start.toISOString())
    .lte('ordered_at', end.toISOString())
```

dan di objek `return` tambahkan `delivery: summarizeDeliveries(deliveryRows),` setelah `top_items: sales.top_items,`.

Tambahkan `summarizeDeliveries` ke `module.exports`.

- [ ] **Step 5: Run tests**

Run: `npx jest src/services/__tests__/deliveryReports.test.js && npm test`
Expected: PASS (termasuk `salesReportRange`, `salesReportTopLimit`, `closingAllocation` lama — bila ada yang gagal karena antrean mock bergeser oleh query baru di `getClosingReport`, tambahkan satu hasil `{ data: [], error: null }` di posisi query delivery pada test lama itu)

- [ ] **Step 6: Commit**

```bash
git add src/services/orderService.js src/services/__tests__/deliveryReports.test.js
git commit -m "feat(delivery): laporan — delivery_income & ringkasan antaran per kurir di tutup kasir"
```

---

### Task 14: Verifikasi akhir & rilis backend

- [ ] **Step 1: Semua test**

Run: `npm test`
Expected: semua PASS, tanpa test lama yang rusak.

- [ ] **Step 2: Uji lokal singkat** (opsional, butuh `.env` lokal)

Run: `npm run dev` lalu `curl http://localhost:3000/v1/delivery/config`
Expected: JSON dengan `enabled: false` (bila migrasi sudah jalan) atau error 500 `DELIVERY_SETTINGS_FAILED` (bila belum) — keduanya tidak boleh membuat server crash.

- [ ] **Step 3: Jalankan migrasi 022 di produksi** — **minta persetujuan pemilik dulu.**

Run: `npm run migrate`
Expected: `▶ 022_add_delivery.sql … ok` dan semua migrasi lain `ok` (idempoten).
Verifikasi: `SELECT * FROM public.store_settings;` → satu baris, `delivery_enabled = false`, koordinat terisi.

- [ ] **Step 4: Merge & deploy** — **minta persetujuan pemilik dulu** (push ke `master` = deploy Railway setelah CI test lulus).

```bash
git checkout master
git merge --no-ff feat/delivery-fase-1
git push origin master
```

Cek sekali: `gh run list --limit 1` → CI test + deploy `success`; lalu `curl https://rehat-backend-production.up.railway.app/v1/delivery/config` → `enabled: false`.

Delivery tetap **mati** sampai app Flutter (plan terpisah) siap dan admin menyalakannya dari layar Pengaturan Toko.
