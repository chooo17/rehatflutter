# Manajemen Stok Fase A — Master Bahan, Resep & HPP Terhitung

> **Untuk pekerja agentik:** SUB-SKILL WAJIB — pakai superpowers:subagent-driven-development
> untuk mengeksekusi rencana ini task demi task. Langkah memakai checkbox (`- [ ]`).

**Spec:** [`docs/superpowers/specs/2026-08-12-manajemen-stok-design.md`](../specs/2026-08-12-manajemen-stok-design.md)

**Tujuan:** mendata bahan & resep, lalu menghitung HPP per menu dari resep × harga bahan —
**tanpa mengubah satu pun angka yang sedang berjalan**. Hasilnya: pemilik bisa membandingkan HPP
terhitung dengan `cost_price` yang selama ini diisi tangan, dan tahu seberapa meleset tebakannya.

**Arsitektur:** dua tabel baru (`ingredients`, `recipes`) + kalkulator MURNI untuk konversi
satuan dan HPP. Endpoint owner-only di belakang `requireFinanceAccess`. Layar Flutter untuk
entri bahan, entri resep, dan perbandingan HPP.

**Tech:** Node/Express/Supabase (backend, repo terpisah `D:\REHAT\rehat-backend\rehat-backend`),
Flutter/Riverpod/go_router (`c:\Users\thezu\rehat_app`).

---

## Global Constraints

Berlaku untuk SEMUA task. Pelanggaran = task ditolak review.

- **TDD**: tulis test dulu, jalankan sampai GAGAL, baru implementasi.
- **Backend test WAJIB lulus tanpa `.env`**: `SUPABASE_URL= SUPABASE_SERVICE_KEY= npx jest`.
  Baseline saat ini **175/175**. Pola: stub `../../config/supabase` sebelum `require`.
- **Flutter**: `"/c/Users/thezu/flutter/bin/flutter.bat" test` (baseline **313**) dan
  `... analyze --fatal-infos` wajib bersih. Git Bash, path lengkap — Flutter TIDAK ada di PATH.
- **Kalkulator murni** (`*Calc.js`): tanpa DB/IO/env/`Date.now()`. Waktu masuk sebagai parameter.
- **Batas hari/bulan WIB (UTC+7)**, server jalan UTC. DILARANG `toISOString().slice(0,10)` mentah,
  `setHours(0,0,0,0)`, `getHours()`. Helper: `orderService.wibDateKey`,
  `financeService.wibDayBounds`, `financeService.wibMonthBounds`.
- **Query PostgREST yang bisa >1000 baris WAJIB dipaginasi + `.order(...)`.**
- **Route stok owner-only**: `authenticate` + `requireFinanceAccess`. JANGAN `adminAccess`
  (jalur `x-admin-key`-nya melewati `authenticate` sehingga `req.user` kosong).
- **Uang**: nilai yang dilihat pengguna tetap **rupiah bulat**. PENGECUALIAN yang disengaja:
  `ingredients.cost_per_base` disimpan `numeric(14,4)` (rupiah per gram/ml/pcs) — membulatkannya
  merusak presisi (es batu Rp3,5/g → Rp4/g = meleset 14%). Pembulatan ke rupiah bulat HANYA di
  angka akhir (HPP per menu).
- **Envelope respons** `{ success, data, message }`. String pengguna **bahasa Indonesia**.
- **Flutter**: `AppColors` (`lib/core/constants/app_colors.dart`) adalah **getter runtime, BUKAN
  const** — memakai `const` dengannya MERUSAK BUILD. Token semantik (`success`, `error`,
  `warning`, `amber`) memang const. JANGAN `DateFormat` langsung — pakai `Formatters` (sudah WIB).
  Bottom sheet/dialog berinput WAJIB `StatefulWidget` yang men-`dispose` controller-nya.
  Pola *keep-previous-data*: spinner hanya saat `valueOrNull == null`.
- **JANGAN menulis apa pun ke DB produksi** (142 baris `expenses`, 36 baris `finance_ledger`,
  58 `menu_items` nyata). Test memakai stub.
- **Migrasi dijalankan MANUAL oleh pemilik di Supabase SQL Editor** — `DATABASE_URL` di `.env`
  hanya placeholder, runner `pg`/psql TIDAK jalan. Tulis SQL idempoten (`IF NOT EXISTS`).
- Commit tiap task (Conventional Commits, bahasa Indonesia). Jangan push.

---

## Struktur berkas

**Backend** (`D:\REHAT\rehat-backend\rehat-backend`)

| Berkas | Tanggung jawab |
|---|---|
| `src/db/migrations/019_stock_master.sql` | Tabel `ingredients` + `recipes` |
| `src/services/stockCalc.js` | **MURNI**: konversi satuan, harga per satuan dasar, HPP dari resep |
| `src/services/ingredientService.js` | CRUD bahan (DB) |
| `src/services/recipeService.js` | CRUD resep + HPP terhitung per menu (DB) |
| `src/routes/stock.js` | Router `/admin/stock/*`, di-mount di `routes/index.js` |

**Flutter** (`c:\Users\thezu\rehat_app`)

| Berkas | Tanggung jawab |
|---|---|
| `lib/features/stock/data/stock_repository.dart` | Model + repository + provider |
| `lib/features/stock/application/stock_view.dart` | **MURNI**: label satuan, format, validasi, hitung selisih HPP |
| `lib/features/stock/presentation/ingredients_screen.dart` | Daftar & entri bahan |
| `lib/features/stock/presentation/recipe_screen.dart` | Entri resep per menu |
| `lib/features/stock/presentation/hpp_comparison_screen.dart` | HPP terhitung vs `cost_price` |

---

## Task 1: Migrasi 019 — tabel bahan & resep

**Files:**
- Create: `src/db/migrations/019_stock_master.sql`
- Create: `src/db/verify-019.js`
- Modify: `c:\Users\thezu\rehat_app\CLAUDE.md` (tabel status migrasi §3, tambah baris 019)

**Interfaces — Produces:** dua tabel yang dipakai seluruh task berikutnya.

- [ ] **Step 1: Tulis SQL migrasi**

```sql
-- 019: Master bahan & resep (Manajemen Stok Fase A)
-- Dijalankan MANUAL di Supabase SQL Editor.

CREATE TABLE IF NOT EXISTS ingredients (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name                text NOT NULL,
  base_unit           text NOT NULL CHECK (base_unit IN ('g','ml','pcs')),
  purchase_unit       text NOT NULL,            -- 'kg','liter','botol','dus','pcs', bebas
  units_per_purchase  numeric(14,4) NOT NULL CHECK (units_per_purchase > 0),
  cost_per_base       numeric(14,4) NOT NULL DEFAULT 0 CHECK (cost_per_base >= 0),
  min_stock           numeric(14,4) NOT NULL DEFAULT 0 CHECK (min_stock >= 0),
  abc_class           text NOT NULL DEFAULT 'C' CHECK (abc_class IN ('A','B','C')),
  is_active           boolean NOT NULL DEFAULT true,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS ingredients_name_unique
  ON ingredients (lower(name)) WHERE is_active;
CREATE INDEX IF NOT EXISTS ingredients_abc_idx ON ingredients (abc_class) WHERE is_active;

CREATE TABLE IF NOT EXISTS recipes (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  menu_item_id  uuid NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
  ingredient_id uuid NOT NULL REFERENCES ingredients(id) ON DELETE RESTRICT,
  qty_base      numeric(14,4) NOT NULL CHECK (qty_base > 0),
  temperature   text CHECK (temperature IS NULL OR temperature IN ('hot','iced')),
  created_at    timestamptz NOT NULL DEFAULT now()
);
-- Satu bahan hanya boleh muncul sekali per (menu, suhu).
-- `temperature` NULL = berlaku untuk kedua suhu; COALESCE menyeragamkannya
-- supaya NULL tidak lolos dari unique index (NULL != NULL di Postgres).
CREATE UNIQUE INDEX IF NOT EXISTS recipes_menu_ingredient_temp_unique
  ON recipes (menu_item_id, ingredient_id, COALESCE(temperature,'*'));
CREATE INDEX IF NOT EXISTS recipes_menu_idx ON recipes (menu_item_id);
```

- [ ] **Step 2: Skrip verifikasi NON-DESTRUKTIF**

`src/db/verify-019.js` — HANYA membaca. **JANGAN menulis baris probe ke produksi** (pelajaran
dari `verify-017.js` yang sempat menulis ke `finance_ledger` produksi lalu dihapus). Cukup:
`select('id').limit(1)` pada kedua tabel; laporkan ✅ bila tak ada error kolom/tabel.

- [ ] **Step 3: Perbarui tabel migrasi di `CLAUDE.md` §3**, baris 019, status "⏳ belum dipasang".

- [ ] **Step 4: Commit** — `feat(stok): migrasi 019 master bahan & resep`

> **Setelah task ini, controller WAJIB meminta pemilik menjalankan SQL-nya di Supabase dan
> memverifikasi lewat `node src/db/verify-019.js` sebelum Task 2 dimulai.**

---

## Task 2: Kalkulator murni konversi & HPP (`stockCalc.js`)

**Files:**
- Create: `src/services/stockCalc.js`
- Test: `src/services/__tests__/stockCalc.test.js`

**Interfaces — Produces:**
```js
costPerBase({ purchasePrice, unitsPerPurchase })      // => number (rupiah per satuan dasar)
recipeCost(lines)                                     // => number (rupiah, PECAHAN, belum dibulatkan)
menuHpp(lines, temperature)                           // => integer rupiah (dibulatkan di sini)
hppDelta({ computed, stored })                        // => { delta, pct, hasStored }
// lines: [{ qtyBase, costPerBase, temperature }]
```

- [ ] **Step 1: Tulis test yang GAGAL** — `src/services/__tests__/stockCalc.test.js`

```js
const { costPerBase, recipeCost, menuHpp, hppDelta } = require('../stockCalc')

describe('costPerBase', () => {
  test('kopi 1 kg Rp150.000 -> Rp150/g', () => {
    expect(costPerBase({ purchasePrice: 150000, unitsPerPurchase: 1000 })).toBe(150)
  })
  test('es batu Rp35.000 per 10 kg -> Rp3,5/g (TIDAK dibulatkan)', () => {
    expect(costPerBase({ purchasePrice: 35000, unitsPerPurchase: 10000 })).toBeCloseTo(3.5, 4)
  })
  test('cup 1000 pcs Rp1.400.000 -> Rp1.400/pcs', () => {
    expect(costPerBase({ purchasePrice: 1400000, unitsPerPurchase: 1000 })).toBe(1400)
  })
  test('isi per satuan beli nol/negatif -> 0, bukan Infinity/NaN', () => {
    expect(costPerBase({ purchasePrice: 150000, unitsPerPurchase: 0 })).toBe(0)
    expect(costPerBase({ purchasePrice: 150000, unitsPerPurchase: -5 })).toBe(0)
  })
  test('masukan bukan angka -> 0', () => {
    expect(costPerBase({ purchasePrice: 'abc', unitsPerPurchase: 1000 })).toBe(0)
    expect(costPerBase({})).toBe(0)
  })
})

describe('menuHpp', () => {
  const lines = [
    { qtyBase: 18, costPerBase: 150, temperature: null },    // kopi 2700
    { qtyBase: 120, costPerBase: 20, temperature: null },    // susu 2400
    { qtyBase: 1, costPerBase: 1400, temperature: 'iced' },  // cup dingin
    { qtyBase: 1, costPerBase: 1200, temperature: 'hot' },   // cup panas
    { qtyBase: 150, costPerBase: 3.5, temperature: 'iced' }, // es batu 525
  ]
  test('versi dingin memakai baris tanpa suhu + baris iced', () => {
    expect(menuHpp(lines, 'iced')).toBe(2700 + 2400 + 1400 + 525) // 7025
  })
  test('versi panas memakai baris tanpa suhu + baris hot', () => {
    expect(menuHpp(lines, 'hot')).toBe(2700 + 2400 + 1200) // 6300
  })
  test('dibulatkan ke rupiah bulat, pecahan tak bocor', () => {
    expect(Number.isInteger(menuHpp(lines, 'iced'))).toBe(true)
  })
  test('resep kosong -> 0', () => {
    expect(menuHpp([], 'iced')).toBe(0)
    expect(menuHpp(null, 'hot')).toBe(0)
  })
  test('suhu tak dikenal diperlakukan seperti tanpa suhu (hanya baris umum)', () => {
    expect(menuHpp(lines, 'zzz')).toBe(2700 + 2400)
  })
})

describe('hppDelta', () => {
  test('cost_price lama lebih tinggi -> delta negatif', () => {
    const d = hppDelta({ computed: 6300, stored: 8000 })
    expect(d.delta).toBe(-1700)
    expect(d.pct).toBeCloseTo(-21.25, 2)
    expect(d.hasStored).toBe(true)
  })
  test('belum ada cost_price -> hasStored false, pct null (BUKAN 0)', () => {
    const d = hppDelta({ computed: 6300, stored: null })
    expect(d.hasStored).toBe(false)
    expect(d.pct).toBeNull()
  })
  test('cost_price 0 diperlakukan belum diisi', () => {
    expect(hppDelta({ computed: 6300, stored: 0 }).hasStored).toBe(false)
  })
})
```

- [ ] **Step 2: Jalankan, pastikan GAGAL**
  `cd D:\REHAT\rehat-backend\rehat-backend && npx jest stockCalc` → FAIL "Cannot find module"

- [ ] **Step 3: Implementasi `src/services/stockCalc.js`**

MURNI — tanpa `require` ke DB/config, tanpa `Date`. Catatan implementasi:
- `costPerBase` = `purchasePrice / unitsPerPurchase`; `unitsPerPurchase <= 0` atau bukan angka → `0`.
  **Jangan dibulatkan** — presisi pecahan adalah alasan fungsi ini ada.
- `menuHpp(lines, temperature)` menjumlahkan baris yang `temperature == null` ATAU sama persis
  dengan argumen, lalu `Math.round` **sekali di akhir**.
- `hppDelta` mengembalikan `pct: null` bila `stored` kosong/0 — **bukan 0**, supaya UI bisa
  membedakan "belum diisi" dari "pas sama". (Pelajaran dari modul keuangan: nilai sentinel 0 yang
  tak dibedakan dari nol beneran adalah cacat rambu uang yang berulang di proyek ini.)

- [ ] **Step 4: Jalankan sampai LULUS** — `npx jest stockCalc`, lalu suite penuh
  `SUPABASE_URL= SUPABASE_SERVICE_KEY= npx jest` → 175 + test baru, semua lulus.

- [ ] **Step 5: Bukti gigi test** — rusak tiap perilaku, pastikan GAGAL, kembalikan. WAJIB:
  pembulatan `costPerBase`; `menuHpp` ikut menjumlah baris suhu lain; pembulatan di tiap baris
  (bukan sekali di akhir); `hppDelta.pct` jadi 0 saat `stored` kosong.

- [ ] **Step 6: Commit** — `feat(stok): kalkulator murni konversi satuan & HPP resep`

---

## Task 3: Service bahan (`ingredientService.js`) + route

**Files:**
- Create: `src/services/ingredientService.js`
- Create/Modify: `src/routes/stock.js`, mount di `src/routes/index.js`
- Test: `src/services/__tests__/ingredientService.test.js`

**Interfaces — Consumes:** `stockCalc.costPerBase`. **Produces:**
```js
listIngredients({ activeOnly, abcClass })   // => rows[]
createIngredient({ name, baseUnit, purchaseUnit, unitsPerPurchase, purchasePrice, minStock, abcClass })
updateIngredient(id, patch)
deactivateIngredient(id)     // is_active=false, TIDAK menghapus (dipakai resep)
```

- [ ] **Step 1: Test GAGAL** — cakup minimal:
  - `createIngredient` menyimpan `cost_per_base` hasil `costPerBase`, bukan `purchasePrice` mentah
  - `baseUnit` di luar `g|ml|pcs` ditolak 400
  - `unitsPerPurchase <= 0` ditolak 400 (jangan sampai `cost_per_base` jadi 0 diam-diam)
  - nama duplikat (beda huruf besar/kecil) ditolak — unique index `lower(name)`
  - `deactivateIngredient` **tidak** menghapus baris (resep menunjuk ke sana; `ON DELETE RESTRICT`)
  - `listIngredients` dipaginasi + `.order('name')`
- [ ] **Step 2:** jalankan sampai GAGAL.
- [ ] **Step 3:** implementasi + route:
```
GET    /admin/stock/ingredients          ?active_only=&abc=
POST   /admin/stock/ingredients
PATCH  /admin/stock/ingredients/:id
DELETE /admin/stock/ingredients/:id      -> nonaktifkan, bukan hapus
```
Mount: `router.use('/admin/stock', authenticate, requireFinanceAccess, stockRouter)` di
`src/routes/index.js`. **JANGAN `adminAccess`.**
- [ ] **Step 4:** suite penuh lulus, dengan & tanpa kredensial.
- [ ] **Step 5: Bukti gigi** — rusak: validasi `baseUnit` dibuang; `cost_per_base` diisi
  `purchasePrice` mentah; `DELETE` benar-benar menghapus; `.order()` dihapus.
- [ ] **Step 6: Commit** — `feat(stok): CRUD bahan + endpoint owner-only`

---

## Task 4: Service resep (`recipeService.js`) + HPP terhitung

**Files:**
- Create: `src/services/recipeService.js`
- Modify: `src/routes/stock.js`
- Test: `src/services/__tests__/recipeService.test.js`

**Interfaces — Consumes:** `stockCalc.menuHpp`, `stockCalc.hppDelta`, `ingredientService`.
**Produces:**
```js
getRecipe(menuItemId)        // => { lines: [...], hpp: { hot, iced }, complete: bool }
putRecipe(menuItemId, lines) // ganti seluruh resep menu itu (atomik)
listHppComparison()          // => [{ menuItemId, name, storedCostPrice, computedHot, computedIced, delta, pct, complete }]
```

- [ ] **Step 1: Test GAGAL** — cakup minimal:
  - `putRecipe` **mengganti** seluruh baris menu itu, bukan menambah (hapus-lalu-sisip dalam satu alur)
  - bahan yang sama dua kali untuk suhu yang sama → ditolak (unique index 23505 → 400 berpesan jelas)
  - `qty_base <= 0` ditolak
  - `getRecipe` menghitung HPP **dua versi** (hot & iced) memakai `menuHpp`
  - `complete: false` bila menu belum punya baris resep sama sekali
  - `listHppComparison` **dipaginasi** dan `.order(...)` — 58 menu hari ini, tapi jangan
    bergantung pada itu
  - menu tanpa `cost_price` → `hasStored:false`, `pct: null` (bukan 0)
- [ ] **Step 2:** jalankan sampai GAGAL.
- [ ] **Step 3:** implementasi + route:
```
GET  /admin/stock/recipes/:menuItemId
PUT  /admin/stock/recipes/:menuItemId
GET  /admin/stock/hpp-comparison
```
- [ ] **Step 4:** suite penuh lulus, dengan & tanpa kredensial.
- [ ] **Step 5: Bukti gigi** — rusak: `putRecipe` menambah bukan mengganti; HPP hot dan iced
  ditukar; `pct` jadi 0 saat `cost_price` kosong; paginasi dipotong di halaman pertama.
- [ ] **Step 6: Commit** — `feat(stok): resep per menu + HPP terhitung & pembanding`

---

## Task 5: Flutter — model, repository, provider

**Files:**
- Create: `lib/features/stock/data/stock_repository.dart`
- Create: `lib/features/stock/application/stock_view.dart` (murni)
- Modify: `lib/core/constants/api_constants.dart`
- Test: `test/stock_repository_test.dart`, `test/stock_view_test.dart`

**Interfaces — Produces:**
```dart
class Ingredient { String id, name, baseUnit, purchaseUnit, abcClass;
                   double unitsPerPurchase, costPerBase, minStock; bool isActive; }
class RecipeLine { String ingredientId, ingredientName, baseUnit; double qtyBase; String? temperature; }
class MenuRecipe  { List<RecipeLine> lines; int hppHot, hppIced; bool complete; }
class HppRow      { String menuItemId, name; int? storedCostPrice; int computedHot, computedIced;
                    int? delta; double? pct; bool complete, hasStored; }
// Provider: ingredientsProvider, menuRecipeProvider(menuItemId), hppComparisonProvider
```

- [ ] **Step 1: Test GAGAL** — parsing lengkap; field hilang → nilai aman; `pct` **null** terbaca
  sebagai null (BUKAN 0); `costPerBase` pecahan (3.5) terbaca utuh, tidak dibulatkan jadi 4;
  fungsi murni di `stock_view.dart`: label satuan (`g`→"gram"), format harga per satuan,
  validasi input (isi per satuan beli harus >0), kalimat selisih HPP untuk tiga keadaan
  (lebih tinggi / lebih rendah / belum ada `cost_price`).
- [ ] **Step 2:** `"/c/Users/thezu/flutter/bin/flutter.bat" test test/stock_view_test.dart` → GAGAL.
- [ ] **Step 3:** implementasi mengikuti pola `lib/features/finance/data/finance_repository.dart`
  (helper `_int`, `_unwrap`, `ApiException` 404 = tak punya akses).
- [ ] **Step 4:** suite penuh + `analyze --fatal-infos` bersih.
- [ ] **Step 5: Bukti gigi** — rusak: `pct` null jadi 0; `costPerBase` di-`round`;
  `complete` selalu true.
- [ ] **Step 6: Commit** — `feat(stok): model, repository & provider Flutter`

---

## Task 6: Flutter — layar Bahan

**Files:**
- Create: `lib/features/stock/presentation/ingredients_screen.dart`
- Modify: `lib/core/router/route_names.dart`, `lib/core/router/app_router.dart`
- Test: `test/ingredients_screen_test.dart`

Rute: name `stock-ingredients`, path `/profile/stock/ingredients`, `GoRoute` bersarang di shell
profile, navigasi `context.pushNamed`. Dijangkau dari layar Ringkasan Keuangan.

**Form entri bahan** harus mengikuti cara pemilik benar-benar membeli:
> Nama · Satuan dasar (g/ml/pcs) · Satuan beli (kg/liter/botol/dus) · **Isi per satuan beli**
> (dalam satuan dasar) · **Harga per satuan beli** · Golongan ABC · Stok minimum

Sistem menampilkan **harga per satuan dasar** yang terhitung secara langsung saat mengetik
(mis. "Rp150/gram") — supaya salah konversi 1000× ketahuan saat itu juga, bukan setelah
merusak nilai stok.

- [ ] **Step 1:** widget test GAGAL — render 360×800 dengan font & tema asli (pakai harness
  `test/finance_overview_screen_test.dart`), tegaskan **nol exception layout**; form kosong
  ditolak; harga per satuan dasar tampil benar untuk kopi 1 kg Rp150.000.
- [ ] **Step 2-4:** implementasi, test lulus, analyze bersih.
- [ ] **Step 5: Bukti gigi** — rusak: pratinjau harga per satuan dasar dibuang; validasi isi
  per satuan beli >0 dibuang.
- [ ] **Step 6: Commit** — `feat(stok): layar master bahan`

---

## Task 7: Flutter — layar Resep

**Files:**
- Create: `lib/features/stock/presentation/recipe_screen.dart`
- Modify: `route_names.dart`, `app_router.dart`
- Test: `test/recipe_screen_test.dart`

Rute: name `stock-recipe`, path `/profile/stock/recipe/:menuItemId`.

Layar menampilkan daftar menu (58 buah) dengan penanda **sudah/belum ada resep**, diurutkan
dengan yang **paling laris di atas** — supaya 21 menu penyumbang 80% omzet didata lebih dulu.

Entri resep: pilih bahan, isi takaran dalam satuan dasar, tandai suhu (kosong = berlaku
keduanya). HPP terhitung tampil **langsung** di bawah, dua versi (panas & dingin), berdampingan
dengan `cost_price` lama beserta selisihnya.

- [ ] **Step 1:** widget test GAGAL — render 360×800, nol exception layout; baris resep bisa
  ditambah/dihapus; HPP terhitung berubah saat takaran diubah; menu tanpa `cost_price` tidak
  menampilkan selisih palsu.
- [ ] **Step 2-4:** implementasi, test lulus, analyze bersih.
- [ ] **Step 5: Bukti gigi** — rusak: HPP hot & iced ditukar; selisih ditampilkan padahal
  `cost_price` kosong.
- [ ] **Step 6: Commit** — `feat(stok): layar entri resep per menu`

---

## Task 8: Flutter — layar Perbandingan HPP

**Files:**
- Create: `lib/features/stock/presentation/hpp_comparison_screen.dart`
- Modify: `route_names.dart`, `app_router.dart`, `finance_overview_screen.dart` (tautan masuk)
- Test: `test/hpp_comparison_test.dart`

**Ini deliverable utama Fase A** — layar yang menjawab "apakah tebakan HPP saya selama ini benar".

Menampilkan per menu: `cost_price` lama · HPP terhitung (panas/dingin) · selisih rupiah & persen,
diurutkan **selisih terbesar di atas**. Ringkasan di puncak: berapa menu sudah punya resep,
dan **dampak gabungan** terhadap margin bila HPP terhitung dipakai — ditimbang menurut porsi
terjual, bukan rata-rata polos (menu laris harus berbobot lebih besar).

Menu tanpa resep dan menu tanpa `cost_price` **wajib dibedakan secara visual** dari menu yang
selisihnya nol — jangan tampilkan "Rp0" untuk keduanya.

- [ ] **Step 1:** widget test GAGAL — render 360×800, nol exception layout; tiga keadaan
  (belum ada resep / belum ada `cost_price` / selisih nol) tampil berbeda.
- [ ] **Step 2-4:** implementasi, test lulus, analyze bersih.
- [ ] **Step 5: Bukti gigi** — rusak: tiga keadaan itu ditampilkan sama; dampak gabungan
  memakai rata-rata polos alih-alih ditimbang porsi terjual.
- [ ] **Step 6: Commit** — `feat(stok): layar perbandingan HPP terhitung vs cost_price`

---

## Task 9: Dokumentasi

**Files:** Modify `c:\Users\thezu\rehat_app\CLAUDE.md`

- [ ] Tandai migrasi 019 terpasang; tambahkan §5h "Manajemen Stok Fase A" (konsep, endpoint,
  rute layar); tambahkan gotcha: **`cost_per_base` sengaja pecahan** (pengecualian aturan rupiah
  bulat) dan **`pct: null` ≠ 0** pada perbandingan HPP.
- [ ] Commit — `docs: manajemen stok Fase A`

---

## Review

Sesuai kesepakatan pemilik:

| Task | Review |
|---|---|
| 1–4 (migrasi & hitungan uang) | **per task** — salah di sini merusak HPP & laba, dan tak ada endpoint koreksi |
| 5–8 (Flutter/tampilan) | **digabung satu review** setelah Task 8 |
| Semua | **satu review menyeluruh** di akhir fase, sebelum merge |

---

## Definition of Done Fase A

- Migrasi 019 terpasang & terverifikasi di produksi.
- Backend & Flutter suite hijau, `analyze --fatal-infos` bersih.
- Pemilik bisa mendata bahan & resep, dan melihat selisih HPP terhitung vs `cost_price`.
- **Tidak ada satu pun angka berjalan yang berubah** — laba rugi, amplop, laporan penjualan,
  dan HPP yang dipakai `getSalesReport` semuanya masih memakai `cost_price` lama.
