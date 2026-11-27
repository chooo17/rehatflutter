# Acceptance Criteria: Identitas brand di halaman auth

**Spec:** `docs/superpowers/specs/2026-11-27-login-brand-identity-design.md`
**Date:** 2026-11-27
**Status:** Draft

---

## Criteria

| ID | Description | Test Type | Preconditions | Expected Result |
|----|-------------|-----------|---------------|-----------------|
| AC-001 | Layar lebar menampilkan panel brand baru | Logic | Widget test: `AuthSplitLayout(child: Text('FORM'))` dalam `MaterialApp`, ukuran layar 1200×800 | `find.byType(AuthBrandPanel)` = 1 widget; `find.byType(AuthBrandHeader)` = 0 widget; `find.text('FORM')` = 1 widget |
| AC-002 | Panel desktop memuat logo stiker, kura-kura, dan kedua baris tagline | Logic | Sama dengan AC-001 | Ada `Image` dengan `AssetImage('assets/brand/logo-stiker.png')` dan `AssetImage('assets/brand/kura-kura.webp')`; `find.text('You deserve a rest.')` = 1 dan `find.text('Let God work in mysterious ways.')` = 1 |
| AC-003 | Panel lama dihapus | Logic | Sama dengan AC-001 | `find.text('Kopi favoritmu, sekali ketuk.')`, `find.text('9 stamp = 1 kopi gratis')`, dan `find.text('Kumpulkan poin di setiap pesanan')` masing-masing = 0 widget |
| AC-004 | Layar sempit menampilkan header brand | Logic | Widget test: `AuthSplitLayout(child: Text('FORM'))`, ukuran 400×800, `viewInsets.bottom = 0` | `find.byType(AuthBrandHeader)` = 1; ada `Image` dengan `AssetImage('assets/brand/lockup-horizontal.webp')`; kedua baris tagline masing-masing = 1; `find.byType(AuthBrandPanel)` = 0; `find.text('FORM')` = 1 |
| AC-005 | Header HP disembunyikan saat keyboard terbuka | Logic | Seperti AC-004, tetapi `MediaQuery.viewInsets.bottom = 300`; `pumpAndSettle` | `find.image(AssetImage('assets/brand/lockup-horizontal.webp'))` = 0 dan `find.text('You deserve a rest.')` = 0; `find.text('FORM')` = 1 |
| AC-006 | Header HP disembunyikan di layar pendek | Logic | Ukuran 400×500, `viewInsets.bottom = 0`; `pumpAndSettle` | `find.image(AssetImage('assets/brand/lockup-horizontal.webp'))` = 0 dan `find.text('You deserve a rest.')` = 0; `find.text('FORM')` = 1 |
| AC-007 | Logo terbaca pembaca layar; ilustrasi dekoratif tidak | Logic | Sama dengan AC-001, `SemanticsHandle` aktif | `find.bySemanticsLabel('Rehat Coffeehouse')` ≥ 1; tidak ada node semantics berlabel yang mengandung "kura" atau "lockup" |
| AC-008 | Aset brand terdaftar dan tersedia | Logic | Repo setelah implementasi | `pubspec.yaml` memuat `- assets/brand/` di bawah `flutter: assets:`; ketiga file `assets/brand/logo-stiker.png`, `assets/brand/kura-kura.webp`, `assets/brand/lockup-horizontal.webp` ada; `lockup-horizontal.webp` lebar ≤ 1080px; `kura-kura.webp` tidak lagi memuat sisa huruf di pojok kanan atas (dicek visual pada file) |
| AC-009 | Ikon cangkir generik di form Login dihapus | Logic | `lib/features/auth/presentation/login_screen.dart` setelah implementasi | File tidak lagi memuat `Icons.coffee_rounded`; `flutter analyze --fatal-infos` di CI lulus |
| AC-010 | Seluruh gerbang CI lulus lalu deploy | API | Commit implementasi di-push ke `main` | Run "Deploy Web (Vercel)" untuk commit itu: job `test` = success, lalu job `deploy` = success |
| AC-011 | Desktop live: panel brand tampil di `/preorder` | UI interaction | Setelah AC-010; Chrome 1280×800, buka `https://www.rehat-coffeehouse.my.id/preorder` | Screenshot menunjukkan panel krem kiri berisi logo stiker REHAT COFFEEHOUSE, teks "You deserve a rest." dan "Let God work in mysterious ways.", serta kura-kura menghadap kanan (tulisan *rht* di topi tidak terbalik); form login di kanan |
| AC-012 | HP live: header brand tampil di atas form | UI interaction | Setelah AC-010; viewport 390×844, `/preorder` | Screenshot menunjukkan header krem dengan lockup (kura-kura + logo) dan kedua baris tagline di atas "Selamat datang kembali"; tombol "Masuk" dan "Lihat Menu Tanpa Login" tetap terlihat tanpa scroll |
| AC-013 | Panel/header tetap krem di tema gelap | UI interaction | Setelah AC-010; tema gelap aktif di app (1280×800 dan 390×844) | Latar panel/header berwarna krem (bukan latar gelap app); tidak ada kotak berwarna beda di sekitar gambar kura-kura atau lockup |
| AC-014 | Halaman auth lain ikut memakai brand | UI interaction | Setelah AC-010; viewport 390×844; dari Login klik "Daftar" | Halaman Daftar menampilkan header brand yang sama (lockup + tagline) di bawah AppBar |
| AC-015 | Alur tamu tidak rusak | UI interaction | Setelah AC-010; viewport 390×844, `rehatflutter.vercel.app` | Klik "Lihat Menu Tanpa Login" → URL `#/guest-menu` dan tetap di sana setelah 10 detik |
