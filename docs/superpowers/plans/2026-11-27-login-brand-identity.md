# Identitas Brand di Halaman Auth — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. It will decide whether each batch should run in parallel or serial subagent mode and will pass only task-local context to each subagent. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ganti panel brand generik di halaman auth dengan logo stiker, maskot kura-kura *rht*, dan tagline "You deserve a rest. / Let God work in mysterious ways." — panel di layar lebar, header di HP.

**Architecture:** Satu berkas widget baru (`auth_brand.dart`) memuat aset, warna tetap, tagline, `AuthBrandPanel` (≥900px) dan `AuthBrandHeader` (<900px, sembunyi saat keyboard terbuka / layar pendek). `AuthSplitLayout` yang sudah dipakai keenam layar auth memasangnya, jadi layar-layar itu tidak perlu diubah (kecuali Login: hapus ikon cangkir).

**Tech Stack:** Flutter (CI 3.44.4), Riverpod, flutter_test. Olah aset: Python + Pillow.

**Spec:** `docs/superpowers/specs/2026-11-27-login-brand-identity-design.md` · **AC:** `docs/superpowers/acceptance/2026-11-27-login-brand-identity.md`

**Catatan lingkungan (penting):**
- Repo: `C:\Users\USER\projects\rehatflutter`, branch `main`. Push ke `main` = deploy produksi lewat CI (`test` dulu, lalu `deploy`). **Jangan push sebelum Task 4.**
- Flutter lokal: `/c/Users/USER/flutter/bin/flutter` (3.32.1) — lebih tua dari CI. 5 berkas test lama (`admin_dashboard_range_filter_test`, `admin_expense_dialog_test`, `ingredients_screen_test`, `recipe_screen_test`, `responsive_layout_test`) memang gagal dimuat di 3.32 — bukan regresi. Gerbang sebenarnya = CI.
- Repo ini tidak ter-`dart format`; jangan format berkas utuh selain berkas baru.
- Aset sumber (dari design system "Rehat Coffeehouse", sudah diunduh): `C:/Users/USER/AppData/Local/Temp/claude/dec85c7706014572/bb8f53c6-78bc-4c53-be2c-2abc9d27176e/scratchpad/artifact-files/c5cbae57-2489-40e0-ba3b-5b098ab0d189/` — `5eb5948c92e10335b6a4a4a1daff764c.png` (logo stiker transparan 627×432), `498e373949956758ab7091b66eea77d9.png` (karakter utama 324×510), `692547eee567ea136ea9a8755dfbd868.png` (lockup horizontal 2400×1000). Pillow terpasang di `.../scratchpad/pylib`.

## File Structure

| Berkas | Tanggung jawab |
| --- | --- |
| `assets/brand/logo-stiker.png` (baru) | Logo stiker, latar transparan |
| `assets/brand/kura-kura.webp` (baru) | Kura-kura berjalan, latar krem, sisa huruf di kanan atas dipotong |
| `assets/brand/lockup-horizontal.webp` (baru) | Lockup kura-kura + logo, lebar 1080 |
| `pubspec.yaml` | Daftarkan `assets/brand/` |
| `lib/features/auth/presentation/widgets/auth_brand.dart` (baru) | `AuthBrandAssets`, `kRehatTagline`, `AuthBrandPanel`, `AuthBrandHeader` |
| `lib/features/auth/presentation/widgets/auth_split_layout.dart` | Pasang panel (lebar) / header (sempit); hapus `_BrandPanel` lama |
| `lib/features/auth/presentation/login_screen.dart` | Hapus kotak ikon cangkir |
| `test/auth_brand_test.dart` (baru) | AC-001 … AC-007 |

---

### Task 1: Aset brand

**AC:** AC-008 · **Files:** Create `assets/brand/*` (3), Modify `pubspec.yaml:106-107`

- [ ] **Step 1: Buat ketiga berkas aset**

Jalankan dari Git Bash:

```bash
S=/c/Users/USER/AppData/Local/Temp/claude/dec85c7706014572/bb8f53c6-78bc-4c53-be2c-2abc9d27176e/scratchpad
A=$S/artifact-files/c5cbae57-2489-40e0-ba3b-5b098ab0d189
D=/c/Users/USER/projects/rehatflutter/assets/brand
mkdir -p "$D"
PYTHONPATH=$S/pylib python - "$A" "$D" <<'EOF'
import sys
from PIL import Image
A, D = sys.argv[1], sys.argv[2]
# Logo stiker: apa adanya (PNG transparan).
Image.open(f"{A}/5eb5948c92e10335b6a4a4a1daff764c.png").save(f"{D}/logo-stiker.png", optimize=True)
# Kura-kura: karakter berakhir di x=304; sisa huruf di x>=317 (y 129-154). Potong lebar ke 306.
kura = Image.open(f"{A}/498e373949956758ab7091b66eea77d9.png").convert("RGB").crop((0, 0, 306, 510))
kura.save(f"{D}/kura-kura.webp", "WEBP", quality=90, method=6)
# Lockup horizontal: 2400x1000 -> 1080x450 (cukup utk HP 360pt x DPR 3).
lock = Image.open(f"{A}/692547eee567ea136ea9a8755dfbd868.png").convert("RGB")
lock.resize((1080, 450), Image.LANCZOS).save(f"{D}/lockup-horizontal.webp", "WEBP", quality=88, method=6)
for n in ("logo-stiker.png", "kura-kura.webp", "lockup-horizontal.webp"):
    im = Image.open(f"{D}/{n}"); print(n, im.size)
EOF
ls -la "$D"
```

Expected: `logo-stiker.png (627, 432)`, `kura-kura.webp (306, 510)`, `lockup-horizontal.webp (1080, 450)`; ketiga berkas < 200 KB.

- [ ] **Step 2: Periksa visual `kura-kura.webp`**

Buka `assets/brand/kura-kura.webp` (Read tool). Expected: kura-kura utuh (topi, kacamata, cup *rht*), **tanpa** potongan huruf di tepi kanan atas, menghadap kanan.

- [ ] **Step 3: Daftarkan di `pubspec.yaml`**

Ganti:

```yaml
  assets:
    - assets/qris/
```

menjadi:

```yaml
  assets:
    - assets/qris/
    # Logo, maskot & lockup dari design system "Rehat Coffeehouse" (layar auth).
    - assets/brand/
```

- [ ] **Step 4: Commit**

```bash
cd /c/Users/USER/projects/rehatflutter
git add assets/brand pubspec.yaml
git commit -m "feat(brand): aset logo stiker, kura-kura & lockup untuk layar auth

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Widget brand + pasang di `AuthSplitLayout`

**AC:** AC-001 … AC-007 · **Files:** Create `lib/features/auth/presentation/widgets/auth_brand.dart`, `test/auth_brand_test.dart`; Modify `lib/features/auth/presentation/widgets/auth_split_layout.dart` (seluruh isi)

- [ ] **Step 1: Tulis test yang gagal** — `test/auth_brand_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/features/auth/presentation/widgets/auth_brand.dart';
import 'package:rehat_app/features/auth/presentation/widgets/auth_split_layout.dart';

const _logo = AssetImage(AuthBrandAssets.logoStiker);
const _kura = AssetImage(AuthBrandAssets.kuraKura);
const _lockup = AssetImage(AuthBrandAssets.lockupHorizontal);

void _view(WidgetTester tester, Size size, {double keyboard = 0}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(
    home: Scaffold(body: AuthSplitLayout(child: Text('FORM'))),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('layar lebar (>= 900)', () {
    testWidgets('AC-001/002: panel brand dgn logo, kura-kura & tagline; tanpa header',
        (tester) async {
      _view(tester, const Size(1200, 800));
      await _pump(tester);

      expect(find.byType(AuthBrandPanel), findsOneWidget);
      expect(find.byType(AuthBrandHeader), findsNothing);
      expect(find.text('FORM'), findsOneWidget);
      expect(find.image(_logo), findsOneWidget);
      expect(find.image(_kura), findsOneWidget);
      expect(find.text('You deserve a rest.'), findsOneWidget);
      expect(find.text('Let God work in mysterious ways.'), findsOneWidget);
    });

    testWidgets('AC-003: isi panel lama sudah hilang', (tester) async {
      _view(tester, const Size(1200, 800));
      await _pump(tester);

      expect(find.text('Kopi favoritmu, sekali ketuk.'), findsNothing);
      expect(find.text('9 stamp = 1 kopi gratis'), findsNothing);
      expect(find.text('Kumpulkan poin di setiap pesanan'), findsNothing);
    });

    testWidgets('AC-007: logo berlabel utk pembaca layar, ilustrasi dekoratif',
        (tester) async {
      final semantics = tester.ensureSemantics();
      _view(tester, const Size(1200, 800));
      await _pump(tester);

      expect(find.bySemanticsLabel('Rehat Coffeehouse'), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('kura|lockup', caseSensitive: false)),
          findsNothing);
      semantics.dispose();
    });
  });

  group('layar sempit (< 900)', () {
    testWidgets('AC-004: header brand dgn lockup & tagline; tanpa panel',
        (tester) async {
      _view(tester, const Size(400, 800));
      await _pump(tester);

      expect(find.byType(AuthBrandHeader), findsOneWidget);
      expect(find.byType(AuthBrandPanel), findsNothing);
      expect(find.image(_lockup), findsOneWidget);
      expect(find.text('You deserve a rest.'), findsOneWidget);
      expect(find.text('Let God work in mysterious ways.'), findsOneWidget);
      expect(find.text('FORM'), findsOneWidget);
    });

    testWidgets('AC-005: header sembunyi saat keyboard terbuka', (tester) async {
      _view(tester, const Size(400, 800), keyboard: 300);
      await _pump(tester);

      expect(find.image(_lockup), findsNothing);
      expect(find.text('You deserve a rest.'), findsNothing);
      expect(find.text('FORM'), findsOneWidget);
    });

    testWidgets('AC-006: header sembunyi di layar pendek (< 560)', (tester) async {
      _view(tester, const Size(400, 500));
      await _pump(tester);

      expect(find.image(_lockup), findsNothing);
      expect(find.text('You deserve a rest.'), findsNothing);
      expect(find.text('FORM'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `cd /c/Users/USER/projects/rehatflutter && /c/Users/USER/flutter/bin/flutter test test/auth_brand_test.dart`
Expected: FAIL — compile error `auth_brand.dart` tidak ditemukan / `AuthBrandAssets` tidak terdefinisi.

- [ ] **Step 3: Buat `lib/features/auth/presentation/widgets/auth_brand.dart`**

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_fonts.dart';

/// Aset & warna brand untuk layar auth — dari design system
/// "Rehat Coffeehouse" (claude.ai artifact RRdWptcMs39DvyQL4xrZkL).
///
/// Warna di sini SENGAJA tetap (bukan token tema): ilustrasi kura-kura berlatar
/// krem, dan aturan design system melarang menaruhnya langsung di latar gelap.
/// Jadi panel/header tetap krem di tema gelap.
class AuthBrandAssets {
  AuthBrandAssets._();

  static const logoStiker = 'assets/brand/logo-stiker.png';
  static const kuraKura = 'assets/brand/kura-kura.webp';
  static const lockupHorizontal = 'assets/brand/lockup-horizontal.webp';

  /// Krem kertas (token `krem`) = warna latar PNG ilustrasi (disampel ±1).
  static const krem = Color(0xFFF7F3E7);
  static const tinta = Color(0xFF000000);
  static const teksLembut = Color(0xFF57503F);
}

/// Tagline resmi Rehat (pemilik, Nov 2026): baris judul & baris pendukung.
const kRehatTagline = (
  'You deserve a rest.',
  'Let God work in mysterious ways.',
);

/// Panel brand kiri di layar lebar (>= 900px): logo stiker, tagline, dan
/// kura-kura berjalan menghadap form (aset sudah menghadap kanan — jangan
/// dicerminkan, tulisan *rht* ikut terbalik).
class AuthBrandPanel extends StatelessWidget {
  const AuthBrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AuthBrandAssets.krem,
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final kuraHeight = (c.maxHeight * 0.45).clamp(200.0, 340.0);
        return Stack(
          children: [
            Positioned(
              right: 24,
              bottom: 0,
              height: kuraHeight,
              child: Image.asset(
                AuthBrandAssets.kuraKura,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    label: 'Rehat Coffeehouse',
                    image: true,
                    child: Transform.rotate(
                      angle: -2 * math.pi / 180,
                      child: Image.asset(
                        AuthBrandAssets.logoStiker,
                        width: 200,
                        excludeFromSemantics: true,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox(width: 200, height: 138),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: c.maxWidth * 0.6),
                    child: const _Tagline(titleSize: 34, subtitleSize: 19),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// Header brand di atas form pada layar sempit (< 900px): lockup resmi
/// (kura-kura + logo stiker) dan tagline.
///
/// Disembunyikan saat keyboard terbuka atau tinggi layar < 560 agar form
/// (nomor, sandi, OTP) tetap muat tanpa terdorong.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key});

  static const _minHeight = 560.0;

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final tooShort = MediaQuery.sizeOf(context).height < _minHeight;
    final show = !keyboardOpen && !tooShort;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: !show
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              decoration: const BoxDecoration(
                color: AuthBrandAssets.krem,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    label: 'Rehat Coffeehouse',
                    image: true,
                    child: Image.asset(
                      AuthBrandAssets.lockupHorizontal,
                      height: 120,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                      errorBuilder: (_, __, ___) =>
                          const SizedBox(height: 120),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const _Tagline(
                    titleSize: 17,
                    subtitleSize: 12.5,
                    align: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}

class _Tagline extends StatelessWidget {
  const _Tagline({
    required this.titleSize,
    required this.subtitleSize,
    this.align = TextAlign.start,
  });

  final double titleSize;
  final double subtitleSize;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: align == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          kRehatTagline.$1,
          textAlign: align,
          style: TextStyle(
            fontFamily: AppFonts.body,
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
            height: 1.1,
            letterSpacing: -0.02 * titleSize,
            color: AuthBrandAssets.tinta,
          ),
        ),
        SizedBox(height: titleSize * 0.25),
        Text(
          kRehatTagline.$2,
          textAlign: align,
          style: TextStyle(
            fontFamily: AppFonts.body,
            fontSize: subtitleSize,
            fontWeight: FontWeight.w500,
            height: 1.35,
            color: AuthBrandAssets.teksLembut,
          ),
        ),
      ],
    );
  }
}
```

Catatan AC-007: `Semantics(label: 'Rehat Coffeehouse')` membungkus gambar ber-`excludeFromSemantics: true`, jadi label hanya datang dari pembungkus; kura-kura tidak berlabel sama sekali.

- [ ] **Step 4: Ganti seluruh isi `lib/features/auth/presentation/widgets/auth_split_layout.dart`**

```dart
import 'package:flutter/material.dart';

import 'auth_brand.dart';

/// Tata letak layar auth (dipakai keenam layar: Login, Daftar, OTP, Lupa/
/// Reset sandi, Lengkapi profil).
///
/// Layar lebar (>= 900): split-screen — [AuthBrandPanel] di kiri, form di
/// kanan. Layar sempit: [AuthBrandHeader] di atas form (header menyembunyikan
/// dirinya saat keyboard terbuka / layar pendek).
class AuthSplitLayout extends StatelessWidget {
  const AuthSplitLayout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 900) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthBrandHeader(),
            Expanded(child: child),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Expanded(child: AuthBrandPanel()),
          Expanded(child: child),
        ],
      );
    });
  }
}
```

- [ ] **Step 5: Jalankan test, pastikan lulus**

Run: `cd /c/Users/USER/projects/rehatflutter && /c/Users/USER/flutter/bin/flutter test test/auth_brand_test.dart`
Expected: `All tests passed!` (6 test).

Jika AC-007 gagal karena `find.bySemanticsLabel` dgn `RegExp` tidak didukung di SDK lokal, ganti pemeriksaan kedua dengan:
`expect(find.bySemanticsLabel('kura-kura'), findsNothing);` — jangan longgarkan pemeriksaan pertama.

- [ ] **Step 6: Analyze berkas yang diubah**

Run: `/c/Users/USER/flutter/bin/flutter analyze --fatal-infos lib/features/auth test/auth_brand_test.dart`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/features/auth/presentation/widgets/auth_brand.dart lib/features/auth/presentation/widgets/auth_split_layout.dart test/auth_brand_test.dart
git commit -m "feat(auth): panel & header brand Rehat (logo, kura-kura, tagline)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Hapus ikon cangkir generik di Login

**AC:** AC-009 · **Files:** Modify `lib/features/auth/presentation/login_screen.dart:80-90`

- [ ] **Step 1: Hapus blok ini** (tepat di awal `children:` kolom form):

```dart
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.espresso,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.coffee_rounded,
                      color: AppColors.amber, size: 30),
                ),
                const SizedBox(height: 28),
```

sehingga kolom langsung dimulai dengan `Text('Selamat datang kembali', ...)`.

- [ ] **Step 2: Verifikasi**

Run:
```bash
cd /c/Users/USER/projects/rehatflutter
grep -c "Icons.coffee_rounded" lib/features/auth/presentation/login_screen.dart
/c/Users/USER/flutter/bin/flutter analyze --fatal-infos lib/features/auth
```
Expected: `0`, lalu `No issues found!` (jika `AppColors` kini tak terpakai di berkas itu, analyzer melapor `unused_import` → hapus import `app_colors.dart`).

- [ ] **Step 3: Jalankan seluruh test** — `/c/Users/USER/flutter/bin/flutter test`
Expected: hanya 5 berkas lama (lihat Catatan lingkungan) yang gagal dimuat; tidak ada kegagalan baru.

- [ ] **Step 4: Commit**

```bash
git add lib/features/auth/presentation/login_screen.dart
git commit -m "feat(auth): hapus ikon cangkir generik di Login (brand di panel/header)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Push, CI, verifikasi live

**AC:** AC-010 … AC-015

- [ ] **Step 1: Pastikan tidak ada commit baru di remote**, lalu push

```bash
cd /c/Users/USER/projects/rehatflutter
git fetch -q origin && git status -sb | head -1   # Expected: ahead N, tidak "behind"
git push origin main
```

- [ ] **Step 2: Tunggu CI (AC-010)**

```bash
ID=$(gh run list -R chooo17/rehatflutter -w "Deploy Web (Vercel)" -L 1 --json databaseId --jq '.[0].databaseId')
gh run watch $ID -R chooo17/rehatflutter --exit-status --interval 15 >/dev/null 2>&1; echo exit=$?
gh run view $ID -R chooo17/rehatflutter --json jobs --jq '.jobs[] | "\(.name): \(.conclusion)"'
```
Expected: `test / test: success`, `deploy: success`. Jika `test` gagal: baca log (`gh run view $ID --log-failed`), perbaiki, ulangi dari Task terkait.

- [ ] **Step 3: Screenshot live (AC-011 … AC-014)** — skrip Playwright di `.../scratchpad/pw/` (playwright-core sudah terpasang, Chrome sistem). Ambil:
  - `https://www.rehat-coffeehouse.my.id/preorder` 1280×800, tema gelap & terang (`page.emulateMedia({colorScheme})`) → panel krem, logo, kedua baris tagline, kura-kura menghadap kanan (*rht* terbaca normal), form di kanan.
  - `/preorder` 390×844 → header lockup + tagline di atas "Selamat datang kembali"; tombol "Masuk" & "Lihat Menu Tanpa Login" terlihat tanpa scroll.
  - Klik "Daftar" (390×844) → halaman Daftar menampilkan header yang sama di bawah AppBar.
  Baca setiap screenshot (Read tool) dan cocokkan dengan Expected Result AC.

- [ ] **Step 4: Alur tamu (AC-015)** — `node repro.js` di `.../scratchpad/pw/` → `FINAL URL ...#/guest-menu`.

- [ ] **Step 5: Laporkan ke pemilik** dengan screenshot & hasil tiap AC.
