# Satu Halaman "Pesanan" (Menyatukan Pesanan Masuk & Riwayat) — Desain

**Tanggal:** 2026-07-25
**Status:** Disetujui, siap implementasi

## Masalah

Di halaman profil, admin melihat **dua** baris menuju daftar pesanan:
- **"Pesanan Masuk (Admin)"** → `AdminOrdersScreen` (`adminOrdersProvider`): pesanan
  aktif + selesai (paid/preparing/completed), ada tombol *Tandai Selesai*.
- **"Riwayat pesanan"** → `OrderHistoryScreen` mode admin (`adminOrderHistoryProvider`):
  hanya selesai/batal/refund, read-only.

Keduanya menarik dari `fetchAllOrders` (semua sumber: app pelanggan **dan** kasir/walk-in).
Jadi yang memisah hanyalah **status**, bukan sumber. Admin harus berpindah antar dua layar
untuk melihat hal yang pada dasarnya satu daftar → kurang efisien.

## Tujuan

Semua riwayat pesanan (dari pelanggan app maupun kasir/admin) tampil dalam **satu halaman**.
Admin: dari 2 layar → 1. Profil admin: dari 2 baris → 1.

## Keputusan desain (disepakati)

- **Satu layar admin terpadu** dengan **dua seksi dalam satu scroll**: "Perlu tindakan"
  (aktif, actionable) + "Riwayat" (selesai/batal/refund, read-only).
- Profil: admin satu baris **"Pesanan"**; pelanggan baris dinamai ulang **"Pesanan"**.
- Tanpa backend/migrasi baru — murni frontend.

## Perubahan

### 1. Provider (`order_repository.dart`)
- Tambah `adminAllOrdersProvider` (FutureProvider) → `fetchAllOrders(limit: 100)`, diurut
  terbaru dulu (createdAt desc). Mengembalikan **semua** pesanan apa pun statusnya.
- `adminOrdersProvider` (aktif) tetap ada bila masih dipakai; `adminOrderHistoryProvider`
  dihapus bila tak ada konsumen lain (dicek saat implementasi).

### 2. `AdminOrdersScreen` → layar "Pesanan" terpadu
- Judul AppBar: **"Pesanan"**.
- Sumber: `adminAllOrdersProvider`.
- Pisahkan client-side jadi dua grup:
  - **Aktif** = `kActiveOrderStatuses` (pending/paid/preparing/ready) — pakai kartu dengan
    `CompleteOrderButton`.
  - **Riwayat** = selesai/batal/refund — kartu read-only.
- Render: label seksi "Perlu tindakan" (bila ada) lalu daftar aktif; label "Riwayat" lalu
  daftar selesai. Satu `RefreshIndicator` untuk semuanya.
- Empty-state: bila dua-duanya kosong → "Belum ada pesanan".
- Tetap tap kartu → `orderDetail`.

### 3. Profil (`profile_screen.dart`)
- Pelanggan (non-admin): baris `Riwayat pesanan` → label **"Pesanan"**, tetap ke
  `RouteNames.orderHistory`.
- Admin: hapus baris `Pesanan Masuk (Admin)`; ganti tujuan baris "Pesanan" ke
  `RouteNames.adminOrders` (layar terpadu). Hasil akhir: **satu** baris "Pesanan" untuk admin
  (ditempatkan di grup umum, bukan di blok admin, agar tak dobel).

### 4. Pintasan ikon struk app bar Menu (admin)
- `menu_screen.dart`: ikon struk admin sudah menuju `RouteNames.adminOrders` → otomatis ke
  layar terpadu. Tak ada perubahan tujuan; hanya memastikan konsisten.

### 5. Bersih-bersih `OrderHistoryScreen`
- Admin tak lagi memakai layar ini → hapus cabang `isAdmin` (judul, provider admin, mode
  `admin` di `_OrderCard`, empty-state admin). Layar menjadi khusus pelanggan.
- Hapus `adminOrderHistoryProvider` bila sudah tak ada yang memakai.

## Testing

- Widget/unit sederhana untuk pemisahan grup: daftar campuran → grup aktif berisi status aktif,
  grup riwayat berisi selesai/batal/refund; urutan terbaru dulu.
- `flutter analyze --fatal-infos` + `flutter test` hijau (gate CI).

## Di luar cakupan

- Perubahan tampilan kartu pesanan (tetap seperti sekarang).
- Paginasi/lazy-load (masih ambil 100 teratas seperti perilaku sekarang).
- Sisi pelanggan selain rename label.
