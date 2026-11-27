# Identitas brand di halaman auth — desain

Tanggal: 2026-11-27 · Status: disetujui

## Tujuan

Halaman auth (Login, Daftar, OTP, Lupa sandi, Reset sandi, Lengkapi profil) belum memakai identitas brand Rehat sama sekali: panel desktop hanya ikon cangkir generik di atas gradasi coklat, dan di HP tidak ada brand sama sekali. Padahal mayoritas pemesan masuk lewat iframe `/preorder` di HP. Ganti dengan logo stiker, maskot kura-kura *rht*, dan tagline resmi.

## Sumber brand

Design system artifact **"Rehat Coffeehouse"** (`https://claude.ai/artifact/RRdWptcMs39DvyQL4xrZkL`), bukan "Rehat Coffeehouse Design System" (redesign website tanpa ilustrasi). Aturan yang dipakai dari sana:

- Ilustrasi karakter selalu di atas `krem` (atau panel `kunyit`) — **tidak pernah langsung di latar gelap**, juga di tema gelap.
- Karakter menghadap konten/aksi. `karakter-utama` sudah menghadap kanan → tidak dicerminkan (mencerminkan membalik tulisan *rht*).
- Gabungan karakter + logo hanya lewat lockup resmi (`lockup-horizontal` untuk header).
- Logo tidak diketik ulang, tidak diubah warna, tidak diberi efek.

**Tagline** (dari pemilik, menggantikan "Kopi favoritmu, sekali ketuk."):

> **You deserve a rest.**
> Let God work in mysterious ways.

Font: **Inter** (sudah dibundel). Baris 1 weight 800, letter-spacing −0.02em, warna tinta. Baris 2 weight 500, warna `teks-lembut` (#57503F). Pemilik menolak font tulisan tangan (Caveat Brush) — "terlalu playful".

## Tampilan

### Layar lebar (≥ 900px) — `AuthBrandPanel`

Panel kiri (menggantikan `_BrandPanel` lama), margin 16, radius 20, warna = latar PNG karakter (krem, disampel dari aset):

- Kiri atas: logo stiker transparan, lebar ±200, miring −2°.
- Di bawahnya: tagline 2 baris, lebar maks ±60% panel.
- Kanan bawah: kura-kura berjalan (`karakter-utama`), tinggi ±45% panel (min 200, maks 340), menempel tepi bawah.
- Daftar 3 keunggulan lama (pesan tanpa antre, poin, stamp) **dihapus**.
- Panel tetap krem di tema gelap.

### Layar sempit (< 900px) — `AuthBrandHeader`

Di atas form, di dalam area `SafeArea`/di bawah `AppBar` layar itu:

- Latar krem (sama dengan latar PNG lockup), sudut bawah radius 20.
- `lockup-horizontal` selebar konten (maks 360), lalu tagline 2 baris rata tengah (baris 1 ±17px, baris 2 ±12px).
- **Disembunyikan** (animasi tinggi, 200ms) saat keyboard terbuka (`MediaQuery.viewInsetsOf(context).bottom > 0`) atau tinggi layar < 560px — form tetap muat.
- Berlaku di keenam halaman auth.

### Form

Tidak berubah, kecuali Login: ikon cangkir generik (kotak espresso 60×60) di atas "Selamat datang kembali" dihapus — brand sudah tampil di panel/header.

## Aset

Disalin dari design system ke `assets/brand/` (didaftarkan di `pubspec.yaml`):

| File app | Sumber | Olah |
| --- | --- | --- |
| `logo-stiker.png` | `Logo/logo-stiker-transparan.png` (627×432) | apa adanya |
| `kura-kura.webp` | `Karakter/karakter-utama.png` (324×510) | potong sisa huruf di pojok kanan atas, WebP |
| `lockup-horizontal.webp` | `Lockup/lockup-horizontal.png` (2400×1000) | perkecil ke lebar 1080, WebP |

Warna latar panel/header disampel dari piksel latar aset dan disimpan sebagai konstanta (bukan token tema; tetap di kedua tema).

## Struktur kode

- **Baru** `lib/features/auth/presentation/widgets/auth_brand.dart`: `AuthBrandAssets` (path aset + warna latar), `kRehatTagline` (dua baris), `AuthBrandPanel`, `AuthBrandHeader`.
- **Ubah** `auth_split_layout.dart`: lebar → `Row(AuthBrandPanel, child)`; sempit → `Column(AuthBrandHeader, Expanded(child))`. `_BrandPanel` lama dihapus.
- **Ubah** `login_screen.dart`: hapus kotak ikon cangkir.
- **Ubah** `pubspec.yaml`: `assets/brand/`.

Semantics: logo `Semantics(label: 'Rehat Coffeehouse', image: true)`; kura-kura dan lockup dekoratif (`excludeFromSemantics`), tagline tetap terbaca sebagai teks.
Gambar memakai `errorBuilder` → ruang kosong (bukan crash) bila aset gagal.

## Pengujian

Widget test `test/auth_brand_test.dart` (bungkus `AuthSplitLayout` dengan child sederhana, atur `MediaQuery`):

1. Lebar 1200×800: panel tampil (logo, kura-kura, kedua baris tagline), header tidak.
2. Lebar 400×800: header tampil (lockup + tagline), panel tidak.
3. Lebar 400×800 dengan `viewInsets.bottom = 300`: header tersembunyi.
4. Lebar 400×500: header tersembunyi.
5. Child tetap dirender di semua kasus.

Verifikasi akhir setelah deploy (CI: test → deploy): screenshot `/preorder` live di 1280×800 dan 390×844, tema gelap & terang.

## Di luar cakupan

Tema/warna form, font app secara umum, website `rehat-coffeehouse.my.id`, splash screen.
