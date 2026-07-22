# Spec: Fitur Refund (Tunai) di Kasir/Admin

Tanggal: 2026-07-22

## Tujuan
Memungkinkan admin/kasir mengembalikan (refund) pesanan yang dibayar **tunai** secara
penuh, dengan alasan wajib dan jejak audit, serta mengeluarkannya dari laporan penjualan.

## Keputusan (disepakati)
- **Hanya tunai** (`payment_method === 'cash'`). Order tunai = pesanan kasir (walk-in,
  tamu, `source='cashier'`, `points_earned=0`) → tidak ada poin/stamp/saldo yang dibalik.
- **Seluruh pesanan** (tanpa refund sebagian).
- **Status baru `refunded`** (terpisah dari `cancelled`).
- **Alasan wajib** diisi kasir.
- Hanya admin/kasir; pelanggan tidak melihat aksi ini.

## Non-tujuan (di luar ruang lingkup)
- Refund QRIS/DOKU (tak ada API refund) & refund Saldo.
- Refund sebagian / per-item.
- Pembalikan loyalti (tak berlaku untuk order tunai/kasir).

## Database — migrasi `012_add_order_refund.sql` (manual di Supabase SQL Editor)
- Tambah kolom nullable di `orders`: `refunded_at timestamptz`, `refunded_by uuid`
  (FK `users.id`), `refund_reason text`.
- Izinkan nilai `'refunded'` pada `orders.status`: bila ada CHECK constraint pada
  kolom status, drop & buat ulang mencakup `refunded`; bila tak ada constraint,
  tidak melakukan apa-apa (status free-text sudah menerima nilai baru).

## Backend
- `orderService.refundOrder(orderId, adminUserId, reason)`:
  - Guard: order ada · `payment_method==='cash'` · status ∈ {paid, processing,
    completed} · reason tidak kosong. Tolak bila sudah refunded/cancelled/pending.
  - Set `status='refunded'`, `refunded_at`, `refunded_by`, `refund_reason`.
  - Notifikasi in-app ke admin. Tanpa WA (konsisten aturan kasir tanpa WA).
- Route `POST /admin/orders/:id/refund` (adminAccess), body `{ reason }` (zod min 3).
  Error: `REFUND_CASH_ONLY`, `REFUND_NOT_ALLOWED`, 404, 400.
- Laporan: `SOLD_STATUSES` tidak memuat `refunded` → order refund otomatis keluar
  dari omzet/laba/tutup kasir/analitik. Tanpa perubahan kode laporan.

## Frontend
- `OrderStatus`: tambah `refunded('Dikembalikan', merah)` + `fromString('refunded')`.
  Tidak masuk `flow`.
- Repo `order_repository.dart`: `refundOrder(id, reason)` → POST; invalidate
  `adminOrdersProvider` + `ordersTrackingProvider`.
- UI `order_detail_screen.dart` (blok aksi admin): tombol **"Refund (Tunai)"** bila
  `isAdmin && paymentMethod=='cash' && status ∈ {paid,preparing,completed}`.
  Dialog alasan wajib → konfirmasi → panggil refund → snackbar. Badge `Dikembalikan`.

## Verifikasi
- Backend: skrip sekali-pakai — buat order tunai dummy → refund → assert
  `status=refunded` + kolom audit terisi + hilang dari laporan penjualan → hapus.
- Frontend: `flutter analyze`.
- Deploy backend (Railway) + web (Vercel). Build **admin APK** di akhir.
