# Edit Pesanan Tersimpan (Tambah/Hapus Item) — Desain

**Tanggal:** 2026-07-25
**Status:** Disetujui, siap implementasi

## Masalah

"Simpan (Bayar Nanti)" membuat pesanan `pending` yang belum dibayar. Saat ini kasir
hanya bisa membukanya untuk **Tampilkan QRIS** / **Lunas (Tunai)** / **Batalkan** — item
tak bisa diubah. Kebutuhan: kasir bisa **menambah / menghapus / mengubah jumlah** item
pada pesanan tersimpan sebelum dibayar (pelanggan sering menambah pesanan).

## Keputusan desain (disepakati)

- **Editor langsung di layar detail** (bottom sheet), bukan recall ke keranjang POS.
- **Tambah item**: pilih menu + jumlah saja (tanpa opsi ukuran/gula/suhu — opsi tak
  memengaruhi harga: `unit_price = menu.price`).
- Berlaku untuk pesanan **tunai maupun QRIS**, selama `status = pending`.
- QRIS: pesanan "Simpan" belum men-generate QR sama sekali (`payment_token` null) → edit
  aman. Sebagai jaring pengaman untuk kasus "sudah pernah Tampilkan QRIS lalu diedit",
  `payment_token` dikosongkan saat edit agar QR di-generate ulang di nominal baru.

## Backend

### Refactor: `priceItems(items)`
Ekstrak dari `createGuestOrder` (langkah validasi + hitung subtotal): untuk tiap item cek
menu ada & `is_available`, set `unitPrice = menu.price`, `itemSubtotal = price * qty`,
kembalikan `{ enrichedItems, subtotal }`. Dipakai `createGuestOrder` **dan** `updateOrderItems`.

### `updateOrderItems(orderId, items)`
- Muat order (`id, status, payment_method`). Tak ada → 404.
- **Guard**: `status !== 'pending_payment'` → `ORDER_NOT_EDITABLE` 409
  "Hanya pesanan belum bayar yang bisa diubah".
- Wajib `items.length >= 1` → else `EMPTY_ORDER` 400 (mengosongkan = pakai "Batalkan").
- `priceItems(items)` → subtotal/total (diskon tetap 0 untuk pesanan kasir/tamu).
- Tulis ulang item: insert baris baru (`order_id, menu_item_id, quantity, unit_price,
  customization, subtotal`) → hapus baris lama order itu. Update `orders.subtotal`, `total`,
  dan **set `payment_token = null`**.
- Kembalikan `getOrderDetailAdmin(orderId)` (detail terbaru).

### Rute
`PATCH /admin/orders/:id/items` (`adminAccess`), body `{ items: [{menu_item_id, quantity,
customization?}] }` → `updateOrderItems`. Balas detail terbaru.

## Frontend

### Data
- `api_constants.dart`: `adminOrderItems(id) => '/admin/orders/$id/items'`.
- `order_repository.dart`: `updateOrderItems(orderId, List<EditOrderItem>) → OrderModel`
  (kirim `{items:[...]}`, unwrap detail). `EditOrderItem { menuItemId, quantity, customization }`.

### Editor (bottom sheet) — `order/presentation/widgets/edit_order_sheet.dart`
- State kerja lokal: `List<_EditableItem>` diseed dari `order.items`
  (`menuItemId, name, customizationSummary, quantity, unitPrice`).
- Baris item: nama + ringkasan opsi + harga; tombol **−/+** jumlah; **hapus** (qty 0 atau ikon
  hapus). Preview **total** terhitung lokal.
- **"Tambah item"**: buka sheet pemilih menu (`menuCatalogProvider`, dengan pencarian) →
  ketuk item → tambah qty 1 (customization `{}`). Item sama ditambah → naikkan qty.
- **"Simpan perubahan"**: panggil `updateOrderItems`; sukses → tutup sheet, `invalidate`
  `pendingOrdersProvider` + provider detail order, snackbar sukses. Gagal → snackbar error.
- Guard UI: tombol simpan nonaktif bila daftar kosong.

### Titik masuk
`order_detail_screen.dart`: pada blok `status == pending` (admin), tambah tombol
**"Edit item"** (Outlined) yang membuka `showEditOrderSheet(context, order)`. Setelah sheet
tertutup dengan perubahan → detail di-refresh.

## Testing

- **Backend** (skrip verifikasi / unit bila ada infra): `updateOrderItems` menghitung total
  benar; guard menolak order non-pending (`ORDER_NOT_EDITABLE`); `items` kosong ditolak;
  `payment_token` jadi null.
- **Frontend**: notifier/util editor — tambah item baru, tambah item duplikat (qty naik),
  kurangi ke 0 (terhapus), hapus, hitung total. Di-unit-test tanpa jaringan.

## Di luar cakupan

- Opsi ukuran/gula/suhu untuk item baru.
- Edit pesanan yang sudah lunas/selesai; diskon/voucher pada pesanan kasir.
- Regenerasi QR proaktif (hanya dikosongkan; dibuat ulang saat "Tampilkan QRIS").
