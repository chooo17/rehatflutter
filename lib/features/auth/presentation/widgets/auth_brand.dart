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
///
/// Disusun sebagai kolom, BUKAN Stack: logo + tagline mendapat ruang dulu
/// (diperkecil proporsional bila jendela sangat pendek), kura-kura hanya
/// mengisi SISA ruang di bawahnya (maks [_kuraMax], disembunyikan bila sisa
/// < [_kuraMin]). Dengan begitu kura-kura tak pernah menimpa tagline — dulu
/// (Positioned) ia menimpa baris judul di jendela pendek seperti 900x600.
class AuthBrandPanel extends StatelessWidget {
  const AuthBrandPanel({super.key});

  static const _top = 48.0;
  static const _gap = 16.0;
  static const _kuraMax = 340.0;
  static const _kuraMin = 140.0;

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
        final brand = Column(
          mainAxisSize: MainAxisSize.min,
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
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(48, _top, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: math.max(0, c.maxHeight - _top - _gap),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topLeft,
                  child: brand,
                ),
              ),
              const SizedBox(height: _gap),
              Expanded(
                child: LayoutBuilder(builder: (context, k) {
                  if (k.maxHeight < _kuraMin) return const SizedBox.shrink();
                  return Align(
                    alignment: Alignment.bottomRight,
                    child: SizedBox(
                      height: math.min(k.maxHeight, _kuraMax),
                      child: Image.asset(
                        AuthBrandAssets.kuraKura,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
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
///
/// Keyboard dibaca dari [View] (bukan `MediaQuery`): header berada di body
/// `Scaffold`, dan `Scaffold` (resizeToAvoidBottomInset) MENGHAPUS
/// `viewInsets.bottom` dari MediaQuery body-nya — via MediaQuery header tak
/// pernah tahu keyboard terbuka. Perubahan dipantau lewat didChangeMetrics.
/// Di browser HP keyboard biasanya mengecilkan viewport (bukan viewInsets);
/// itu tertangkap aturan tinggi < 560 (iframe /preorder ikut visualViewport).
class AuthBrandHeader extends StatefulWidget {
  const AuthBrandHeader({super.key});

  @override
  State<AuthBrandHeader> createState() => _AuthBrandHeaderState();
}

class _AuthBrandHeaderState extends State<AuthBrandHeader>
    with WidgetsBindingObserver {
  static const _minHeight = 560.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = View.of(context).viewInsets.bottom > 0 ||
        MediaQuery.viewInsetsOf(context).bottom > 0;
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
