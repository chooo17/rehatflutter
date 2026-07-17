import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../shared/models/spin_model.dart';

/// Roda putar yang menggambar [prizes] sebagai segmen-segmen berwarna.
///
/// [rotation] dalam radian — dikendalikan oleh animasi di layar.
class SpinWheel extends StatelessWidget {
  const SpinWheel({super.key, required this.prizes, required this.rotation});

  final List<SpinPrize> prizes;
  final double rotation;

  // Warna bergantian antar segmen (getter agar ikut tema aktif).
  static List<Color> get _segmentColors => [
        AppColors.amber,
        AppColors.espresso,
        AppColors.amberDark,
        const Color(0xFF7A4E22),
      ];

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: rotation,
            child: CustomPaint(
              size: Size.infinite,
              painter: _WheelPainter(prizes: prizes, colors: _segmentColors),
            ),
          ),
          // Poros tengah.
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.crema,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.espresso, width: 3),
            ),
            child: Icon(Icons.coffee_rounded,
                color: AppColors.espresso, size: 22),
          ),
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.prizes, required this.colors});

  final List<SpinPrize> prizes;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final n = prizes.length;
    final seg = 2 * pi / n;
    // Mulai dari atas (pointer di -pi/2), searah jarum jam.
    // Segmen 0 berpusat di atas, jadi tepinya mundur setengah segmen.
    final startAngle = -pi / 2 - seg / 2;

    final rect = Rect.fromCircle(center: center, radius: radius);

    for (var i = 0; i < n; i++) {
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = colors[i % colors.length];
      final a0 = startAngle + i * seg;
      canvas.drawArc(rect, a0, seg, true, paint);

      // Garis pemisah.
      final divider = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.crema.withValues(alpha: 0.35);
      canvas.drawArc(rect, a0, seg, true, divider);

      _drawLabel(canvas, center, radius, a0 + seg / 2, prizes[i], colors[i % colors.length]);
    }

    // Bingkai luar.
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = AppColors.crema;
    canvas.drawCircle(center, radius - 4, border);
  }

  void _drawLabel(Canvas canvas, Offset center, double radius, double angle,
      SpinPrize prize, Color segColor) {
    // Warna teks kontras terhadap segmen.
    final isLight = segColor == AppColors.amber;
    final textColor = isLight ? AppColors.espresso : AppColors.crema;

    final tp = TextPainter(
      text: TextSpan(
        text: prize.label,
        style: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 13,
          height: 1.05,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: radius * 0.7);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    // Posisikan teks di sepanjang jari-jari.
    final dx = radius * 0.58;
    canvas.translate(dx, 0);
    // Putar agar teks terbaca dari luar ke dalam.
    canvas.rotate(pi / 2);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.prizes != prizes;
}

/// Penunjuk segitiga di atas roda.
class WheelPointer extends StatelessWidget {
  const WheelPointer({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 32,
      child: CustomPaint(painter: _PointerPainter()),
    );
  }
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.crema;
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawShadow(path, Colors.black54, 3, false);
    canvas.drawPath(path, paint);
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppColors.amberDark;
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
