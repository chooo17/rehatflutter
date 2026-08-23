# Filter Rentang Tanggal di Laporan Penjualan — Rancangan

> Rehat Coffeehouse. Ditulis 23 Agustus 2026.
> Menyentuh dua repo: frontend Flutter (repo ini) dan backend Node
> (`D:\REHAT\rehat-backend\rehat-backend`).

---

## 1. Kenapa ini dibangun

Layar `Laporan Penjualan` (`admin_dashboard_screen.dart`) hanya punya dua cara memfilter
periode: pill preset (Hari ini / 7 Hari / 30 Hari) atau satu tanggal spesifik. Tidak ada cara
melihat rentang bebas (mis. "1–15 Agustus" untuk membandingkan dua minggu gajian, atau
"seluruh Juli" tanpa terikat awal bulan kalender). Pemilik harus menjumlah manual dari beberapa
tanggal tunggal.

Backend (`orderService.getSalesReport`) baru saja diperbaiki paginasinya (lihat commit
`6541877`, bug PostgREST 1000-baris) — jadi sudah aman dipakai untuk rentang lebih panjang dari
30 hari tanpa diam-diam memotong data.

## 2. Cakupan

**Termasuk:**
- Tombol baru "Rentang tanggal" di layar `Laporan Penjualan`, terpisah dari pill & tombol
  tanggal tunggal yang sudah ada.
- Backend `getSalesReport` menerima rentang tanggal bebas (bukan cuma preset/1-hari).
- Kartu "Pengeluaran" di layar yang sama ikut menyaring ke rentang yang sama (supaya tidak
  timpang dengan "Total omzet").
- Validasi rentang maksimum 90 hari (frontend + backend, defense-in-depth).

**Tidak termasuk (sengaja):**
- Kalender Penjualan (grid bulanan) **tidak** ikut menyaring — tetap navigasi per-bulan sendiri,
  sesuai perilakunya sekarang.
- Layar lain (Tutup Kasir, Analitik, Keuangan) tidak disentuh — masing-masing sudah punya
  pemilih tanggal/rentang sendiri di luar cakupan ini.
- Tidak memperbaiki bug WIB pre-existing di `expenseService.rangeBounds` (memakai jam server,
  bukan WIB, tidak seperti `orderService`) — di luar cakupan permintaan ini, dicatat sebagai
  utang terpisah di §6.

## 3. Desain

### 3.1 Backend

**`getSalesReport(range = '7d', date = null, endDate = null)`** (`orderService.js`) — tambah
parameter ketiga. Prioritas argumen (paling menang di atas):
1. `date` + `endDate` keduanya diisi → rentang kustom WIB inklusif `date`..`endDate`.
2. `date` saja (tanpa `endDate`) → perilaku lama, 1 hari WIB. **Tidak berubah.**
3. Tidak ada `date`/`endDate` → `range` preset lama (`today`/`7d`/`30d`). **Tidak berubah.**

Untuk kasus (1): `start = wibDayRange(date).start`, `end = wibDayRange(endDate).end`,
`days = jumlah hari WIB dari date sampai endDate inklusif`. Sisanya (query berpaginasi, hitung
`dayBuckets`, `itemMap`, `expenses`, `stampRedemptions`, dst.) memakai jalur yang sama persis
dengan yang sudah ada — tidak ada cabang logika baru di luar penentuan `start`/`end`/`days`.

**Route `GET /admin/reports/sales`** — tambah query param opsional `end` (format
`YYYY-MM-DD`, sama seperti `date`). Validasi di route handler:
- `end` tanpa `date` → diabaikan (perilaku sama seperti `date` tak valid sekarang: fallback ke
  `range`).
- `end < date` → tidak divalidasi eksplisit (secara praktis tak mungkin terjadi dari
  `showDateRangePicker` Flutter; kalau terjadi dari client lain, `days` akan negatif/nol dan
  fungsi mengembalikan laporan kosong — dianggap cukup aman, bukan celah data).
- Selisih `end - date` > 90 hari → `400 RANGE_TOO_LARGE`.

**`GET /admin/expenses`** & **`expenseService.listExpenses`/`rangeBounds`** — tambah param `end`
dengan pola identik (opsional, dilewatkan bila ada). `rangeBounds(range, date, endDate)`:
kalau `date`+`endDate` diisi, kembalikan `[start-of-date, end-of-endDate]`. **Tidak mengubah**
cara `rangeBounds` menghitung hari untuk preset (`range`) atau `date` tunggal — jadi bug WIB
pre-existing di jalur itu tetap seperti sekarang, tidak diperbaiki maupun diperparah di sini.

### 3.2 Frontend

**Provider baru** (`admin_report_repository.dart`):
```dart
final salesDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);
```

**Prioritas provider** (pola yang sudah ada: `salesRangeProvider` tetap tersimpan sebagai baseline
tapi kalah prioritas begitu `salesDateProvider` diisi — pola ini diperluas dengan satu tingkat
prioritas baru di atasnya):

`salesDateRangeProvider` (kalau ada) → `salesDateProvider` (kalau ada) → `salesRangeProvider`.

**Saling meng-null-kan saat memilih** (supaya cuma satu mode yang aktif setiap saat):
- Pilih pill → null-kan `salesDateProvider` **dan** `salesDateRangeProvider` (perluasan dari
  perilaku sekarang yang cuma null-kan `salesDateProvider`).
- Pilih tanggal tunggal → null-kan `salesDateRangeProvider` (baris baru; sebelumnya tidak perlu
  karena provider ini belum ada).
- Pilih rentang → null-kan `salesDateProvider`.

**UI**: tombol baru "Rentang tanggal" di `Row` yang sama dengan tombol "Pilih tanggal" (jadi dua
tombol berdampingan: `[Pilih tanggal] [Rentang tanggal]`, masing-masing `Expanded`). Pakai
`showDateRangePicker` bawaan Flutter. Setelah user memilih:
- Kalau `end.difference(start).inDays > 90` → `SnackBar` merah "Rentang maksimal 90 hari",
  seleksi **tidak** diterapkan (provider tidak diubah).
- Kalau valid → set `salesDateRangeProvider`, null-kan `salesDateProvider`.

Label tombol saat aktif: `"23 Agu – 30 Agu"` (format `Formatters.tanggal` tanpa tahun kalau
tahun sama dengan tahun berjalan, dengan tahun kalau beda — ikut pola singkat yang wajar untuk
ruang tombol yang sempit).

**`fetchSales`/`fetchExpenses`** (`AdminReportRepository`) — tambah parameter opsional
`endDate`, diteruskan sebagai query `end` kalau ada.

### 3.3 Data flow

```
User pilih rentang → showDateRangePicker → validasi ≤90 hari
  → salesDateRangeProvider = range, salesDateProvider = null
  → salesReportProvider & expensesProvider re-fetch (watch provider baru)
  → fetchSales(date: range.start, endDate: range.end)
  → GET /admin/reports/sales?date=...&end=...
  → getSalesReport(range, date, endDate) → cabang rentang kustom
  → response sama persis shape-nya dengan laporan biasa (SalesReport.fromJson tidak berubah)
```

## 4. Error handling

| Kasus | Penanganan |
|---|---|
| Rentang >90 hari (frontend) | Ditolak sebelum request, `SnackBar`, provider tak berubah |
| Rentang >90 hari (client lain / lolos ke API) | `400 RANGE_TOO_LARGE` dari route |
| `end` tanpa `date` | Diabaikan, fallback ke `range` (konsisten dgn validasi param lain) |
| Tidak ada data di rentang | Sama seperti sekarang untuk rentang kosong — kartu/grafik menampilkan nol/"Tidak ada data" |

## 5. Testing

- **Backend**: kasus baru untuk `getSalesReport` dengan `date`+`endDate` — rentang dalam sebulan,
  rentang lintas bulan, rentang 1 hari (harus sama persis dengan hasil mode `date`-saja untuk
  hari yang sama), rentang >90 hari ditolak di level route (test route, bukan service — service
  sendiri tidak perlu tahu soal batas 90 hari, itu murni validasi request).
- **Manual**: pilih rentang 3 hari yang ada datanya di app, bandingkan totalnya dengan jumlah
  manual dari 3 tanggal tunggal terpisah.
- `flutter analyze --fatal-infos` & `flutter test` (existing suite) tetap harus lulus.

## 6. Utang yang sengaja tidak disentuh

- `expenseService.rangeBounds` memakai jam **server** (bukan WIB) untuk preset/`date` — beda
  dari `orderService` yang sudah konsisten WIB. Perbaikan ini di luar cakupan; dicatat di sini
  supaya tidak terlupa kalau nanti ada laporan "pengeluaran hari ini" meleset di sekitar jam
  00:00–07:00 WIB.
