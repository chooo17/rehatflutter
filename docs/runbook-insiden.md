# Runbook Insiden — Rehat Coffeehouse

Panduan cepat saat sistem bermasalah, terutama **saat jam sibuk**. Bagian A untuk
**kasir/barista** (tanpa akses teknis). Bagian B untuk **developer/owner**.

Kontak eskalasi: **owner/dev** (WA), device Fonnte `087777601617`.

---

## A. Untuk kasir/barista (di kedai)

### A1. Pelanggan bilang "sudah bayar QRIS tapi status belum berubah"
1. Tunggu ~1–2 menit — konfirmasi DOKU kadang telat lewat webhook.
2. Minta pelanggan **tarik-segarkan** layar pesanan / tutup-buka app.
3. Masih pending > 3 menit? Minta bukti bayar (screenshot sukses DOKU), lalu
   **proses pesanan secara manual** & catat. Jangan minta bayar dua kali.
4. Laporkan ke dev (sertakan no. antrian / nama).

### A2. Aplikasi kasir tak bisa konek / "gagal memuat"
1. Cek internet kedai (WiFi/hotspot). Coba buka `rehatflutter.vercel.app` di HP.
2. Kalau internet OK tapi app tetap gagal → kemungkinan backend down.
   **Beralih ke mode manual:** catat pesanan di kertas + terima **tunai/QRIS statis**.
3. Kabari dev segera. Input ke sistem menyusul saat pulih.

### A3. Printer struk tak jalan
- Bukan darurat. Matikan-nyalakan printer & Bluetooth HP. Struk bisa dicetak ulang
  dari **Detail Pesanan** setelah tersambung. Kalau tetap gagal, tulis antrian manual.

### A4. Pelanggan tak menerima WhatsApp (OTP daftar / notifikasi)
- Kemungkinan kuota WA (Fonnte) habis atau device WA logout.
- Untuk **pesanan**: WA hanya notifikasi — pesanan tetap masuk. Beri no. antrian lisan.
- Untuk **daftar akun baru gagal OTP**: tawarkan **pesan sebagai tamu** dulu; kabari dev.

### A5. Tombol "Refund (Tunai)" error
- Coba sekali lagi. Kalau muncul "fitur refund belum aktif" → kabari dev
  (butuh migrasi DB). Sementara, kembalikan uang fisik & catat manual.

---

## B. Untuk developer / owner

### B1. Backend (Railway) down
- Cek https://rehat-backend-production.up.railway.app/v1 → harus balas (401/JSON).
- Railway dashboard → service `rehat-backend` → Logs & Metrics. Restart bila crash-loop.
- Redeploy: `railway up --service rehat-backend --detach` (dari folder backend).

### B2. Supabase (DB) down / lambat
- Cek Supabase dashboard → project → Database health.
- Semua alur (order, saldo, laporan) bergantung DB → kalau down, kasir ke mode manual (A2).
- Jangan jalankan migrasi/DDL saat insiden.

### B3. DOKU (pembayaran) bermasalah
- Cek status DOKU. Webhook masuk ke `POST /payments/doku/notify`.
- Fallback app: QRIS statis + ACC manual admin (sudah didukung saat DOKU `configured=false`).
- Top-up saldo yang sudah terbayar tapi belum masuk → cek log webhook `TOPUP-*`.

### B4. Fonnte (WhatsApp) habis kuota / device logout
- Cek dashboard Fonnte (kuota bulan berjalan). Paket Free ~950/bln, dipakai bersama OTP.
- **Ganti device/nomor:** update `FONNTE_TOKEN` di Railway env → redeploy. (Idealnya ada
  nomor cadangan idle yang sudah terdaftar — lihat backlog Ops.)
- Verifikasi: kirim OTP uji / cek WhatsApp device pengirim.

### B5. Web (Vercel) menampilkan versi lama
- Header no-cache sudah diatur di `web/vercel.json`. Hard-refresh untuk memastikan.
- Cek `curl -sI https://rehatflutter.vercel.app/main.dart.js | grep -i cache-control`.
- Redeploy: `bash scripts/deploy_web.sh` (lihat aturan urutan deploy di CLAUDE.md §3).

### B6. Refund gagal 500 / "REFUND_SCHEMA_MISSING"
- Migrasi 012 belum jalan di DB itu. Jalankan `012_add_order_refund.sql` di Supabase,
  verifikasi `node src/db/verify-012.js`.

> Setelah insiden apa pun: catat singkat (apa, kapan, dampak, akar masalah, perbaikan)
> agar runbook ini tumbuh dari kejadian nyata.
