# Delivery Order (Fase 1) — Design Spec

**Tanggal:** 2026-11-27
**Fitur:** Pelanggan berakun bisa memesan lewat app untuk **diantar kurir Rehat sendiri** ke alamatnya.
**Status:** Disetujui → lanjut ke rencana implementasi.

---

## 1. Tujuan & Ruang Lingkup

Delivery lewat app Rehat untuk pelanggan dekat (≤ 3 km), diantar 1–2 kurir yang bekerja untuk Rehat.
GrabFood tetap berjalan untuk pelanggan baru/jauh.

- Pelanggan memilih tipe **Delivery** di checkout, memilih/menambah alamat dengan pin peta.
- Server mengecek radius & jam delivery, menghitung ongkir, lalu total = menu − diskon + ongkir.
- Begitu dibayar, pesanan **otomatis** dikirim ke kurir: WhatsApp ke semua kurir yang bertugas,
  pengumuman di grup WA, dan pesan ke pelanggan. Pesanan juga masuk antrean dapur seperti biasa.
- Kurir memakai layar **Antaran** di app Rehat (akun berperan `courier`): ambil antaran → berangkat → terkirim.
- Pelanggan menerima WA di setiap langkah dan melihat nama & nomor kurir di app.

**Di luar ruang lingkup Fase 1:** kurir pihak ketiga, lokasi kurir langsung di peta, voucher gratis ongkir,
pencarian alamat (geocoding), estimasi waktu tiba, delivery untuk tamu, delivery terjadwal, COD (bayar di tempat).

## 2. Keputusan Bisnis (sudah dikonfirmasi)

| Keputusan | Nilai |
|---|---|
| Kanal | App Rehat (baru) + GrabFood (tetap berjalan) |
| Kurir | **1–2 kurir milik Rehat** (bukan GoSend/GrabExpress) |
| Pengiriman ke kurir | **Otomatis saat pesanan dibayar** |
| Notifikasi | WhatsApp ke **pelanggan**, **kurir**, dan **grup pengumuman** |
| Radius | **3 km** dari titik toko |
| Ongkir pelanggan | **Rp 5.000** bila belanja **< Rp 50.000**; **gratis** bila **≥ Rp 50.000** |
| Dasar batas Rp 50.000 | **Sesudah diskon voucher** |
| Minimal belanja | **Tidak ada** |
| Jam delivery | Sampai **1 jam sebelum tutup** |
| Menu | **Semua menu** boleh dikirim |
| Pembayaran | **Dibayar di app** (QRIS/e-wallet/Saldo Rehat). Tidak ada bayar di tempat |
| Akun | Delivery **wajib login** (perlu alamat & nomor HP valid) |
| Loyalti | Poin & stamp tetap berlaku. Poin dihitung dari harga menu (bukan ongkir) |

Semua angka (radius, Rp 5.000, Rp 50.000, 60 menit) disimpan di pengaturan dan bisa diubah admin tanpa update app.

## 3. Keputusan Lanjutan (sudah dikonfirmasi)

| # | Keputusan | Nilai |
|---|---|---|
| D5 | Pesanan sudah dibayar tapi batal diantar | **Refund ke Saldo Rehat** dari tombol admin; opsi "sudah ditransfer manual" bila pelanggan minta tunai |
| D7 | Dua kurir bertugas | **Siapa cepat dia dapat**; kasir bisa memilihkan / memindahkan kurir |
| D3 | Titik toko | **-7.1940555, 113.2508814** (pin Google Maps "Rehat Coffeehouse"), Jl. KH. Hasyim Asyari 26, Sampang |
| D3 | Jam buka | **Setiap hari 10.00–24.00** (dari Sanity `siteSettings`) → delivery **10.00–23.00** |

Nilai D3 diisi sebagai data awal migrasi dan tetap bisa diubah dari layar Pengaturan Toko (§6.4).
`close_time` 24.00 disimpan sebagai `00:00`; bila `close_time ≤ open_time`, waktu tutup dianggap **hari berikutnya**.

> Catatan terpisah: koordinat di JSON-LD website (`app/(site)/layout.tsx`, `-7.19405017, 113.24830648`) adalah
> titik tengah tampilan peta, bukan pin toko (meleset ±280 m ke barat). Perlu diperbaiki di repo website.

**Catatan Saldo Rehat vs pencairan DOKU.** Uang pembayaran QRIS tetap cair dari DOKU ke rekening Rehat (H+1)
seperti biasa, apa pun yang terjadi pada pesanan. Saldo Rehat hanyalah catatan di database Rehat:
"Rehat berutang Rp X ke pelanggan ini dalam bentuk saldo belanja". Saldo itu **tidak dicairkan DOKU** dan
tidak ada di DOKU. Saat pelanggan memakai saldo untuk pesanan berikutnya, tidak ada uang baru masuk;
pesanan itu dibayar dari uang yang sebelumnya sudah cair ke Rehat. Total saldo semua pelanggan dicatat
sebagai **kewajiban (utang) Rehat** (`getWalletLiability` sudah ada). Bila pelanggan ingin uangnya kembali
dalam bentuk tunai/transfer, admin mentransfer manual dari rekening Rehat, lalu menandainya di app.

## 4. Data Model

### 4.1 Migrasi `022_add_delivery.sql` (manual di Supabase, idempoten)

```sql
-- 1. Peran kurir
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE public.users ADD CONSTRAINT users_role_check
  CHECK (role IN ('customer', 'admin', 'courier'));
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS courier_on_duty boolean NOT NULL DEFAULT false;

-- 2. order_type: tambah 'delivery' (ganti check constraint dari migrasi 003)
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_order_type_check;
ALTER TABLE public.orders ADD CONSTRAINT orders_order_type_check
  CHECK (order_type IN ('dine_in', 'takeaway', 'delivery'));

-- 3. Kolom delivery di orders (null untuk non-delivery)
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS delivery_fee        int NOT NULL DEFAULT 0,  -- ongkir dibayar pelanggan
  ADD COLUMN IF NOT EXISTS delivery_address    jsonb,                    -- snapshot alamat saat pesan
  ADD COLUMN IF NOT EXISTS delivery_distance_m int,
  ADD COLUMN IF NOT EXISTS delivery_status     text,                     -- lihat §4.3
  ADD COLUMN IF NOT EXISTS courier_id          uuid REFERENCES public.users(id),
  ADD COLUMN IF NOT EXISTS courier_assigned_at timestamptz,
  ADD COLUMN IF NOT EXISTS picked_up_at        timestamptz,
  ADD COLUMN IF NOT EXISTS delivered_at        timestamptz,
  ADD COLUMN IF NOT EXISTS delivery_fail_reason text,
  ADD COLUMN IF NOT EXISTS courier_reminded_at timestamptz;              -- pengingat "belum diambil" sudah dikirim
CREATE INDEX IF NOT EXISTS idx_orders_delivery_status ON public.orders(delivery_status)
  WHERE delivery_status IS NOT NULL;

-- 4. Alamat tersimpan pelanggan
CREATE TABLE IF NOT EXISTS public.user_addresses (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  label           text NOT NULL,            -- "Rumah", "Kantor"
  address_text    text NOT NULL,
  notes           text,                     -- patokan, lantai, warna pagar
  recipient_name  text NOT NULL,
  recipient_phone text NOT NULL,
  lat             double precision NOT NULL,
  lng             double precision NOT NULL,
  is_default      boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_user_addresses_user ON public.user_addresses(user_id);

-- 5. Pengaturan toko (satu baris, id = 1)
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
INSERT INTO public.store_settings (id, store_lat, store_lng, store_address)
VALUES (1, -7.1940555, 113.2508814, 'Jl. KH. Hasyim Asyari 26, Sampang, Jawa Timur')
ON CONFLICT DO NOTHING;

-- 6. Jam buka per hari (0 = Minggu … 6 = Sabtu), waktu WIB
CREATE TABLE IF NOT EXISTS public.store_hours (
  day_of_week int PRIMARY KEY CHECK (day_of_week BETWEEN 0 AND 6),
  open_time   time,
  close_time  time,
  is_closed   boolean NOT NULL DEFAULT false
);
-- Setiap hari 10.00–24.00 (24.00 disimpan sebagai 00:00 = tengah malam berikutnya)
INSERT INTO public.store_hours (day_of_week, open_time, close_time)
SELECT d, '10:00', '00:00' FROM generate_series(0, 6) AS d
ON CONFLICT DO NOTHING;
```

`delivery_enabled` default **false**: fitur aktif setelah admin mengisi koordinat & jam, menetapkan kurir, lalu menyalakannya.

### 4.2 Rumus

- `subtotal` = Σ harga menu × qty (seperti sekarang).
- `discount_amount` = dari voucher, **hanya memotong menu** (seperti sekarang).
- `items_net` = `subtotal − discount_amount`.
- `delivery_fee` = `items_net ≥ free_delivery_min ? 0 : store_settings.delivery_fee`.
- `total` = `items_net + delivery_fee` → nominal yang ditagih DOKU / Saldo Rehat.
- `points_earned` = dari `items_net`, **bukan** `total`.
- Jarak = garis lurus (haversine) titik toko → pin alamat. Ditolak bila > `delivery_radius_m`.
  Jarak jalan biasanya ±1,3–1,6× jarak garis lurus.
- Jam: delivery dibuka selama toko buka **dan** `sekarang ≤ close_time − delivery_cutoff_minutes` (WIB).
  Dengan jam sekarang: delivery **10.00–23.00**. Tutup lewat tengah malam (`close_time ≤ open_time`)
  dihitung sebagai hari berikutnya.
- Delivery juga ditolak bila **tidak ada kurir bertugas** (`courier_on_duty = true`), dengan alasan
  "Kurir sedang tidak bertugas".

### 4.3 `delivery_status` (terpisah dari `orders.status`)

`orders.status` tetap memakai alur lama (`pending_payment → paid→processing → ready → completed`).
Status antaran dicatat terpisah agar logika pembayaran, antrean, poin & laporan yang ada tidak berubah:

| delivery_status | Arti | Pemicu | WhatsApp |
|---|---|---|---|
| `waiting_courier` | Dibayar, menunggu kurir mengambil tugas | Otomatis saat order delivery dibayar | Kurir bertugas, grup, pelanggan |
| `assigned` | Kurir sudah mengambil tugas | Kurir tekan "Ambil antaran" (atau kasir memilihkan) | Pelanggan: nama & HP kurir |
| `on_the_way` | Pesanan dibawa kurir | Kurir tekan "Berangkat" (`orders.status` tidak diubah; backend tidak memakai `ready`) | Pelanggan: "sedang diantar" |
| `delivered` | Sampai di pelanggan | Kurir tekan "Terkirim" → `orders.status = completed` | Pelanggan: notifikasi "selesai" yang sudah ada |
| `failed` | Gagal diantar | Kurir tekan "Gagal" + alasan | Admin & grup |
| `cancelled` | Dibatalkan Rehat (dengan refund) | Admin | Pelanggan |

## 5. Backend (`rehat-backend`)

### 5.1 Layanan baru `deliveryService.js`
- `getConfig()`: baca `store_settings` + `store_hours` + jumlah kurir bertugas; hitung `isOpenForDelivery`
  & `cutoffTime` hari ini (WIB).
- `quote({ lat, lng, itemsNet })` → `{ available, reason, distanceM, deliveryFee, freeDeliveryMin, remainingForFree }`.
  `reason`: `DELIVERY_DISABLED`, `OUTSIDE_HOURS`, `OUT_OF_RADIUS`, `NO_COURIER_ON_DUTY`, `STORE_LOCATION_NOT_SET`.
- `dispatch(orderId)`: dipanggil saat order delivery menjadi `paid`. Set `delivery_status = waiting_courier`,
  kirim WA ke semua kurir bertugas + grup + pelanggan (§5.5). Idempoten (hanya bila `delivery_status` masih null).
- `claim(orderId, courierId)`: update bersyarat `WHERE delivery_status = 'waiting_courier'` → hanya satu kurir
  yang berhasil bila dua menekan bersamaan; kurir lain mendapat pesan "Sudah diambil {nama}".
- `assign(orderId, courierId)` (admin): memilihkan / memindahkan kurir.
- `markOnTheWay`, `markDelivered`, `markFailed(reason)`: hanya oleh kurir yang ditugaskan (atau admin);
  status hanya boleh maju.

### 5.2 Endpoint
| Method | Path | Auth | Fungsi |
|---|---|---|---|
| GET | `/delivery/config` | publik | Aktif?, jam, batas waktu, aturan ongkir (untuk UI) |
| POST | `/delivery/quote` | user | Cek alamat: tersedia?, jarak, ongkir |
| GET/POST/PATCH/DELETE | `/me/addresses[/:id]` | user | CRUD alamat tersimpan (maks. 10 per user) |
| POST | `/orders` | user | Terima `order_type: 'delivery'` + `address_id` (§5.3) |
| GET | `/courier/deliveries` | courier | Antaran menunggu + milik kurir ini (hari ini) |
| PATCH | `/courier/duty` | courier | Mulai / selesai bertugas (`courier_on_duty`) |
| POST | `/courier/deliveries/:id/claim` | courier | Ambil antaran |
| POST | `/courier/deliveries/:id/on-the-way` · `/delivered` · `/failed` | courier | Ubah status |
| POST | `/admin/orders/:id/assign-courier` | admin | Pilihkan / pindahkan kurir |
| POST | `/admin/orders/:id/delivery-refund` | admin | Batalkan pesanan delivery & refund (D5, §5.4) |
| GET/PATCH | `/admin/store-settings`, `/admin/store-hours` | admin | Atur koordinat, radius, ongkir, jam |
| GET/POST/DELETE | `/admin/couriers` | admin | Jadikan user kurir (via no. HP) / cabut |

Middleware baru `courierAccess` (role `courier` atau `admin`).

### 5.3 Perubahan `createOrder`
- `orderSchema.order_type` tambah `'delivery'`; tambah `address_id` (uuid, wajib bila delivery).
- Bila delivery: ambil alamat milik user (tolak alamat user lain), jalankan `quote()` **di server**
  (tolak bila tidak tersedia, kirim `reason`), simpan snapshot alamat + jarak + `delivery_fee`, hitung `total` (§4.2).
  Ongkir **tidak pernah** diambil dari app.
- `table_number` diabaikan untuk delivery. `/orders/guest` & pesanan kasir **tidak** menerima delivery.
- Di `updateOrderStatus`, saat order delivery menjadi `paid`: panggil `dispatch()`. Pesan WA "Pembayaran diterima"
  ke pelanggan untuk delivery memakai teks khusus (menyebut alamat & bahwa kurir Rehat akan mengantar).

### 5.4 Refund pesanan delivery (D5)
Refund yang ada hanya untuk tunai (`REFUND_CASH_ONLY`). Tambah jalur khusus delivery:
kredit `total` ke Saldo Rehat lewat `walletService.applyTxn`
(tipe `refund`, `ref = orderId`, idempoten), `orders.status = refunded`, `delivery_status = cancelled`,
dan **tarik kembali poin & stamp** pesanan itu (lewat `loyalty_history.ref_order_id`).
Opsi "sudah ditransfer manual": tandai refund tanpa kredit saldo, wajib isi catatan.

### 5.5 WhatsApp (Fonnte, best-effort, tidak menggagalkan alur)

**Ke kurir bertugas** (saat `waiting_courier`):
```
*ANTARAN BARU* 🛵 #{q}
{nama penerima} • {HP penerima}
{alamat} ({patokan})
Peta: https://maps.google.com/?q={lat},{lng}
Jarak ±{km} km • Sudah dibayar
Pesanan: {2x Kopi Susu Kerabat, ...}
Ambil tugas di app: {link layar Antaran}
```
**Ke grup pengumuman:** memakai pengumuman "pesanan dibayar" yang sudah ada, ditambah label **DELIVERY**,
jarak, dan nama kurir begitu ada yang mengambil.
**Ke pelanggan:** dibayar (pesanan dibuat & akan diantar) → kurir ditetapkan (nama + HP) →
sedang diantar → selesai. Bila gagal/dibatalkan: kabar refund.

### 5.6 Laporan & keuangan
- Karena kurir milik Rehat, ongkir adalah pendapatan Rehat: `total` (termasuk ongkir) tetap dihitung sebagai omzet
  seperti sekarang, dan laporan penjualan menampilkan **`delivery_income`** (bagian omzet dari ongkir) secara terpisah.
- Closing report menambah: jumlah antaran, total ongkir diterima, dan **antaran per kurir**
  (dasar insentif per antaran bila ada).
- Gaji/insentif kurir dicatat lewat modul biaya yang sudah ada (bukan otomatis dari app).

## 6. App Flutter

### 6.1 Pelanggan
- `OrderType`: tambah `delivery('delivery', 'Delivery', 'Diantar ke alamatmu', Icons.delivery_dining_rounded)`.
- **Checkout:** kartu tipe ketiga, hanya untuk user login dan bukan dari QR meja.
  - Bila delivery tidak tersedia (mati, di luar jam, tidak ada kurir bertugas), kartu nonaktif dengan alasan.
  - Pilih delivery → bagian **Alamat** (default atau "Tambah alamat") → panggil `/delivery/quote`.
  - Di luar radius: "Alamat di luar jangkauan 3 km. Pesan lewat GrabFood ya", tombol bayar nonaktif.
  - Ringkasan: Subtotal, Diskon voucher, **Ongkir** (Rp 5.000 / **Gratis**), Total.
    Bila kena ongkir: "Belanja Rp {sisa} lagi untuk gratis ongkir."
  - Metode bayar: tanpa tunai.
- **Layar Alamat:** daftar + form (label, alamat lengkap, patokan, nama & HP penerima, default) + **pin peta**.
  Paket baru: `flutter_map` (OpenStreetMap, tanpa biaya API) + `geolocator` ("Lokasi saya").
  Fase 1 tanpa pencarian alamat; pelanggan menggeser pin.
- **Detail / lacak pesanan:** timeline (Dibayar → Diproses → Kurir ditetapkan → Diantar → Terkirim),
  nama kurir + tombol telepon/WA kurir, alamat tujuan.

### 6.2 Kurir (layar baru **Antaran**, role `courier`)
- Saklar **Saya bertugas** (mulai/selesai shift). Hanya kurir bertugas yang menerima antaran.
- Tab **Menunggu**: antaran `waiting_courier`, tombol **Ambil antaran**.
- Tab **Antaranku**: per pesanan tampil penerima, alamat, patokan, isi pesanan, tombol **Buka peta**,
  **Telepon**, **WA**, lalu tombol status berurutan: **Berangkat** → **Terkirim** (atau **Gagal** + alasan).
- Riwayat antaran hari ini (jumlah).
- Bisa dibuka dari link di WA (app web), login dengan akun kurir.

### 6.3 Kasir / admin (`admin_orders_screen`)
- Badge **DELIVERY** + jarak + status antaran + nama kurir; filter "Delivery".
- Detail: alamat, patokan, penerima (telepon & Google Maps).
- Tombol: **Pilihkan / pindahkan kurir**, **Batalkan & refund** (konfirmasi + alasan).

### 6.4 Pengaturan Toko & Kurir (layar admin baru)
- Koordinat toko (pin peta), alamat toko, saklar **Delivery aktif**, radius, ongkir, batas gratis ongkir,
  menit batas sebelum tutup, jam buka–tutup per hari.
- Daftar kurir: tambah dari nomor HP akun yang sudah terdaftar, cabut, lihat siapa yang sedang bertugas.

## 7. Kasus Tepi

| Kasus | Penanganan |
|---|---|
| Pesan sebelum batas waktu, bayar sesudahnya | Dicek saat **create**; pesanan yang sudah dibuat tetap diproses |
| Belum bayar QRIS lalu kedaluwarsa | Alur lama (dibatalkan); tidak ada WA ke kurir |
| Dua kurir menekan "Ambil" bersamaan | Update bersyarat di DB; hanya satu berhasil |
| Tidak ada kurir mengambil dalam 10 menit | Satu kali pengingat ke admin (in-app + WA admin, bukan grup komunitas); admin bisa memilihkan kurir |
| Kurir selesai bertugas padahal masih ada antaran | Tidak boleh mematikan "bertugas" selama ada antaran `assigned`/`on_the_way` |
| Alamat diubah setelah pesan | Tidak berpengaruh: pesanan memakai snapshot `delivery_address` |
| Pelanggan tidak bisa dihubungi / alamat salah | Kurir tekan **Gagal** + alasan → admin memutuskan (antar ulang atau refund) |
| Delivery dimatikan admin saat ada pesanan berjalan | Pesanan berjalan tetap diproses; hanya pesanan baru yang ditolak |
| WA gagal terkirim | Tidak menggagalkan alur; antaran tetap terlihat di layar Antaran & admin |

## 8. Pengujian

- **Unit backend:** rumus ongkir (Rp 49.999 → Rp 5.000; Rp 50.000 → gratis; dihitung sesudah voucher),
  haversine & radius, jam + batas waktu (WIB, tepat di batas), tanpa kurir bertugas → ditolak,
  `createOrder` delivery (alamat orang lain ditolak, ongkir dari app diabaikan, poin dari `items_net`),
  `dispatch` idempoten, `claim` bersamaan hanya satu menang, status hanya maju & hanya oleh kurir yang ditugaskan,
  refund delivery (saldo + tarik poin, tidak dobel).
- **Widget Flutter:** kartu delivery aktif/nonaktif + alasan, baris ongkir & "Rp X lagi untuk gratis ongkir",
  di luar radius menonaktifkan tombol bayar, layar Antaran (tombol sesuai status).
- **Uji coba langsung:** akun dummy pelanggan + akun kurir uji, satu pesanan nyata dalam radius,
  sebelum `delivery_enabled` dinyalakan untuk umum.

## 9. Urutan Rilis

1. Migrasi 022 + backend (delivery mati secara default) → deploy.
2. App: Pengaturan Toko & Kurir → admin isi koordinat, jam, tetapkan kurir.
3. App: alamat, checkout delivery, layar Antaran, lacak pesanan → deploy.
4. Uji coba internal → nyalakan `delivery_enabled`.
5. Fase 2: lokasi kurir langsung, voucher gratis ongkir, laporan delivery, pencarian alamat, estimasi waktu tiba.
