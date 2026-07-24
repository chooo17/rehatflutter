# Template Broadcast Promo — Rehat Coffeehouse

Template siap pakai untuk fitur **broadcast** admin (`POST /admin/broadcast`) & segmen RFM
(`/admin/customers/segments`). Tinggal salin, sesuaikan angka/tanggal, kirim.

> Nada: ramah, ringkas, satu ajakan jelas. Hindari huruf kapital berlebih & spam emoji.
> Placeholder `{nama}` = nama depan pelanggan (jaga privasi).

---

## 1. Promo jam sepi (drive traffic siang hari)
**Target:** semua pelanggan aktif · **Waktu kirim:** 13.00–14.30

> ☕ Sore yang tenang di Rehat, {nama}?
> Mampir jam **14.00–16.00** hari ini — tunjukkan pesan ini untuk **diskon 15%** semua kopi.
> Sampai jumpa di kedai! 🙌

## 2. Reminder stamp hampir penuh (dorong repeat)
**Target:** segmen dengan stamp 7–8 (hampir 9) · **Waktu:** pagi

> {nama}, tinggal **{sisa} stamp lagi** menuju **kopi gratis**! 🎯
> Satu pesanan lagi dan kopi berikutnya ditraktir Rehat. Ditunggu ya ☕

## 3. Win-back pelanggan lapsed (RFM: at-risk / hibernating)
**Target:** tidak memesan 30–60 hari · **Waktu:** akhir pekan

> Kangen kopi Rehat, {nama}? 🥺
> Sudah lama nih. Balik minggu ini dan nikmati **diskon 20%** sebagai tanda kangen kami.
> Berlaku sampai {tanggal}. Sampai ketemu lagi! ☕

## 4. Saldo menganggur (aktifkan dompet)
**Target:** punya saldo > Rp0 tapi tak transaksi 21 hari

> {nama}, saldomu di Rehat masih ada dan siap dipakai! 💳
> Tinggal pilih menu, bayar pakai **Saldo Rehat** — cepat tanpa antre kasir.

## 5. Referral nudge (viral loop)
**Target:** pelanggan puas (RFM: champions / loyal) · **Waktu:** setelah pesanan selesai

> Suka ngopi di Rehat, {nama}? Ajak temanmu! 🤝
> Mereka dapat **diskon 15%** pesanan pertama, kamu dapat voucher juga.
> Bagikan kode referralmu dari menu **Referral** di aplikasi.

---

### Catatan operasional
- **Kuota Fonnte** (paket Free ~950 pesan/bln) dipakai bersama OTP + notifikasi pesanan.
  Jangan broadcast massal di hari ramai — bisa menghabiskan kuota & memblokir OTP register.
  Pantau pemakaian di dashboard Fonnte; alarm di >70% sebelum tanggal 20.
- Kirim bertahap (mis. per segmen), bukan sekaligus ke semua nomor.
- Ukur: bandingkan repeat-order 30 hari segmen yang dikirimi vs tidak.
