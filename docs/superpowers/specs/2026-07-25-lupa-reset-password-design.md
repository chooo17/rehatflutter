# Lupa & Reset Password (OTP WhatsApp) — Desain

**Tanggal:** 2026-07-25
**Status:** Disetujui, siap implementasi

## Masalah

App memakai login berbasis password (register → set password → OTP WhatsApp verify →
login pakai password). Namun **tak ada alur reset** bila pelanggan lupa password. Tombol
"Lupa kata sandi?" di layar login hanya menampilkan snackbar "belum tersedia. Hubungi admin".

## Keputusan desain (disepakati)

- **Mekanisme**: OTP WhatsApp — memakai ulang infrastruktur OTP yang ada (KV store,
  JWT `otpToken` dengan field `purpose`, `sendOtp`, `resendOtp`).
- **Nomor tak terdaftar**: beri pesan **jelas** "Nomor tidak terdaftar" (bukan generik).
- Reset via email & auto-login setelah reset → **di luar cakupan**.

## Alur pengguna

1. Login → "Lupa kata sandi?" → **ForgotPasswordScreen**.
2. Masukkan No. HP → `POST /auth/forgot-password`. Nomor tak terdaftar → snackbar
   "Nomor tidak terdaftar". Terdaftar → OTP dikirim, lanjut ke reset.
3. **ResetPasswordScreen**: kode OTP + password baru + konfirmasi. Countdown + "Kirim ulang"
   (pakai `/auth/resend-otp` yang ada). Submit → `POST /auth/reset-password`.
4. Sukses → kembali ke Login + snackbar "Password berhasil diperbarui, silakan masuk".

## Backend (`src/services/authService.js` + `src/routes/index.js`)

### Refactor: `consumeOtp(otpToken, otpCode)`
Ekstrak blok validasi OTP dari `verifyOtp` (verify JWT → baca `otp:{purpose}:{identifier}` →
cek expired/attempts/cocok → `del` bila cocok). Kembalikan `decoded` ({identifier,
identifierType, purpose}). Dipakai `verifyOtp` **dan** `resetPassword`.

### `requestPasswordReset(identifier, identifierType)`
- Cari user (`users` kolom phone/email). **Tak ada → `USER_NOT_FOUND` 404**
  "Nomor tidak terdaftar".
- Generate OTP, simpan `otp:reset:{identifier}` = `{ identifier, identifierType, otp,
  attempts: 0 }` (tanpa passwordHash), TTL 300.
- `sendOtp(identifier, identifierType, otp)` (tak fatal — sama seperti register).
- Return `{ otpToken: jwt({identifier, identifierType, purpose:'reset'}), expiresIn: 300,
  otpSent, otpChannel }`.

### `resetPassword(otpToken, otpCode, newPassword)`
- `decoded = consumeOtp(otpToken, otpCode)`; bila `decoded.purpose !== 'reset'` →
  `INVALID_OTP_TOKEN`.
- Validasi `newPassword` panjang ≥ 8 → else `WEAK_PASSWORD` 400.
- `bcrypt.hash(newPassword, 10)` → update `users.password_hash` where
  `{phone|email} = identifier`. Gagal → `RESET_FAILED` 500.
- Return `{ ok: true }`.

### `verifyOtp` (dirapikan)
Pakai `consumeOtp` untuk bagian validasi; cabang `purpose==='register'` tetap. `purpose`
lain (mis. reset dipanggil salah ke verify) tetap `UNKNOWN_PURPOSE` — reset punya endpoint
sendiri.

### Rute
- `POST /auth/forgot-password` → `requestPasswordReset(body.identifier, body.identifier_type||'phone')`.
- `POST /auth/reset-password` → `resetPassword(body.otp_token, body.otp_code, body.new_password)`.
- Resend: `/auth/resend-otp` (sudah ada, generik per-purpose) — tak perlu rute baru.

## Frontend

### Ekstrak widget
`_OtpBoxes` di `otp_screen.dart` → `lib/shared/widgets/otp_boxes.dart` (publik `OtpBoxes`).
`otp_screen.dart` memakainya; layar reset juga.

### Konstanta & rute
- `api_constants.dart`: `forgotPassword = '/auth/forgot-password'`,
  `resetPassword = '/auth/reset-password'`.
- `route_names.dart`: `forgotPassword`/`forgotPasswordPath = '/forgot-password'`,
  `resetPassword`/`resetPasswordPath = '/reset-password'`.
- `app_router.dart`: dua GoRoute publik (sejajar login/register/otp).

### Data & controller
- `auth_repository.dart`:
  - `requestPasswordReset({required String phone}) → RegisterResult` (reuse: otpToken +
    otpSent + expiresIn).
  - `resetPassword({required String otpToken, required String otpCode,
    required String newPassword}) → void`.
- `auth_controller.dart`: `requestPasswordReset(phone)` (kembalikan RegisterResult? / null) &
  `resetPassword(...)` (kembalikan bool), memakai pola `isSubmitting`/`errorMessage` yang ada.

### Layar
- **ForgotPasswordScreen**: field No. HP → submit → sukses `pushNamed(resetPassword, extra:
  {otpToken, phone, otpSent})`; `USER_NOT_FOUND` → snackbar "Nomor tidak terdaftar".
- **ResetPasswordScreen**: `OtpBoxes` + password baru + konfirmasi (validasi ≥8 & cocok) +
  countdown/resend (pakai `resendOtp`). Sukses → `goNamed(login)` + snackbar sukses.
- **login_screen.dart**: ganti snackbar placeholder → `pushNamed(forgotPassword)`.

## Testing

- **Backend** (skrip node sekali-pakai atau test bila ada infra): `resetPassword` mengubah
  hash; OTP salah menambah attempts; expired; purpose mismatch ditolak; `requestPasswordReset`
  nomor asing → `USER_NOT_FOUND`.
- **Frontend**: controller `requestPasswordReset` & `resetPassword` — sukses set state benar,
  `ApiException` mengisi `errorMessage`. Fake repo (pola `free_drink_controller_test`).

## Di luar cakupan
- Auto-login pasca-reset (login manual).
- Invalidasi refresh-token lama pasca-reset.
- Reset via email/SMS (hanya HP).
