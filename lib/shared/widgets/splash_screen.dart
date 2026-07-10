import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Layar pembuka: "REHAT Coffeehouse Logo Reveal".
///
/// Badge memantul masuk, huruf REHAT muncul satu per satu, disusul teks
/// COFFEEHOUSE + ®, dengan efek burst (cincin & garis memancar). Diadaptasi
/// dari desain Canvas (durasi ± 2,2 dtk, latar kuning brand).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _bg = Color(0xFFFBC400);
  static const _ink = Color(0xFF0E0E0E);
  static const _total = 2200.0; // ms

  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // Progres tersegmen [0..1] untuk jendela waktu [startMs, endMs].
  double _seg(double ms, double start, double end) =>
      ((ms - start) / (end - start)).clamp(0.0, 1.0);

  // Interpolasi keyframe.
  double _kf(double t, List<double> stops, List<double> vals) {
    if (t <= stops.first) return vals.first;
    if (t >= stops.last) return vals.last;
    for (var i = 0; i < stops.length - 1; i++) {
      if (t <= stops[i + 1]) {
        final local = (t - stops[i]) / (stops[i + 1] - stops[i]);
        return vals[i] + (vals[i + 1] - vals[i]) * local;
      }
    }
    return vals.last;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: SizedBox(
              width: 760,
              height: 560,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final ms = _c.value * _total;
                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      _burst(ms),
                      Transform.rotate(
                        angle: -7 * math.pi / 180,
                        child: _badge(ms),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Burst: cincin + 12 garis memancar ─────────────────────────────────
  Widget _burst(double ms) {
    // Cincin: 430–1070ms.
    final rp = Curves.easeOutCubic.transform(_seg(ms, 430, 1070));
    final ringScale = 0.5 + (1.5 - 0.5) * rp;
    final ringOpacity = _kf(rp, [0, .15, 1], [0, .85, 0]).clamp(0.0, 1.0);

    // Garis: 445–1005ms.
    const dp = 445.0, dq = 1005.0;

    return SizedBox(
      width: 760,
      height: 560,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Opacity(
            opacity: ringOpacity,
            child: Transform.scale(
              scale: ringScale,
              child: Container(
                width: 440,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: _ink, width: 6),
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
          for (var i = 0; i < 12; i++) _dash(ms, i, dp, dq),
        ],
      ),
    );
  }

  Widget _dash(double ms, int i, double start, double end) {
    final p = Curves.easeOutCubic.transform(_seg(ms, start, end));
    final y = 70 + (155 - 70) * p; // bergerak keluar
    final scaleY = 0.4 + (1 - 0.4) * p;
    final opacity = _kf(p, [0, .2, 1], [0, 1, 0]).clamp(0.0, 1.0);
    return Transform.rotate(
      angle: i * 30 * math.pi / 180,
      child: Transform.translate(
        offset: Offset(0, -y),
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scaleY: scaleY,
            child: Container(
              width: 10,
              height: 38,
              decoration: BoxDecoration(
                color: _ink,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Badge: bayangan ekstrusi + kartu putih + teks ─────────────────────
  Widget _badge(double ms) {
    // Badge pop: 0–700ms.
    final bp = const Cubic(.2, .7, .2, 1).transform(_seg(ms, 0, 700));
    final badgeScale = _kf(bp, [0, .55, .74, 1], [0, 1.08, .97, 1]);
    final badgeOpacity = _seg(ms, 0, 120);

    // Ekstrusi (bayangan hitam): muncul 430–780ms.
    final ep = const Cubic(.2, 1.5, .3, 1).transform(_seg(ms, 430, 780));

    return Transform.scale(
      scale: badgeScale,
      child: Opacity(
        opacity: badgeOpacity.clamp(0.0, 1.0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Bayangan ekstrusi di belakang.
            Positioned.fill(
              child: Opacity(
                opacity: ep.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(-11 * ep, 21 * ep),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _ink,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
            // Kartu putih.
            Container(
              padding: const EdgeInsets.fromLTRB(38, 24, 38, 28),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _ink, width: 10),
                borderRadius: BorderRadius.circular(13),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x2E000000),
                    blurRadius: 50,
                    offset: Offset(0, 22),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < 5; i++) _letter(ms, 'REHAT'[i], i),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [_coffee(ms), _reg(ms)],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _letter(double ms, String ch, int i) {
    final start = 440 + i * 70.0;
    final p = const Cubic(.2, .8, .2, 1.2).transform(_seg(ms, start, start + 380));
    final scale = _kf(p, [0, .6, 1], [0, 1.18, 1]);
    final ty = -12 + 12 * p;
    return Opacity(
      opacity: _seg(ms, start, start + 120).clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, ty),
        child: Transform.scale(
          scale: scale,
          child: Text(
            ch,
            style: GoogleFonts.archivoBlack(
              fontSize: 118,
              height: 0.9,
              letterSpacing: -4,
              color: _ink,
            ),
          ),
        ),
      ),
    );
  }

  Widget _coffee(double ms) {
    final p = const Cubic(.2, .8, .2, 1).transform(_seg(ms, 920, 1350));
    final ty = 18 - 18 * p;
    return Opacity(
      opacity: p.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, ty),
        child: Text(
          'COFFEEHOUSE',
          style: GoogleFonts.anton(
            fontSize: 50,
            letterSpacing: 2,
            color: _ink,
          ),
        ),
      ),
    );
  }

  Widget _reg(double ms) {
    final p = const Cubic(.2, .8, .2, 1.3).transform(_seg(ms, 1200, 1580));
    final scale = _kf(p, [0, .7, 1], [0, 1.3, 1]);
    final rot = (-40 + 40 * p) * math.pi / 180;
    return Opacity(
      opacity: _seg(ms, 1200, 1320).clamp(0.0, 1.0),
      child: Transform.translate(
        offset: const Offset(6, 6),
        child: Transform.rotate(
          angle: rot,
          child: Transform.scale(
            scale: scale,
            child: Text(
              '®',
              style: GoogleFonts.archivo(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
