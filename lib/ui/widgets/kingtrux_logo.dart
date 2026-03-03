import 'package:flutter/material.dart';

class KingtruxLogo extends StatelessWidget {
  const KingtruxLogo({super.key, this.size = 140});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LogoPainter(),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Draw shield
    Path shieldPath = Path();
    shieldPath.moveTo(w * 0.5, 0);
    shieldPath.lineTo(w * 0.95, h * 0.25);
    shieldPath.lineTo(w * 0.95, h * 0.65);
    shieldPath.lineTo(w * 0.5, h);
    shieldPath.lineTo(w * 0.05, h * 0.65);
    shieldPath.lineTo(w * 0.05, h * 0.25);
    shieldPath.close();

    Paint shieldPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0D47A1), Color(0xFF00C853)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    canvas.drawPath(shieldPath, shieldPaint);

    // Draw white "K"
    Paint kPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    Path kPath = Path();
    kPath.moveTo(w * 0.35, h * 0.2);
    kPath.lineTo(w * 0.35, h * 0.8);
    kPath.lineTo(w * 0.45, h * 0.8);
    kPath.lineTo(w * 0.45, h * 0.55);
    kPath.lineTo(w * 0.65, h * 0.8);
    kPath.lineTo(w * 0.75, h * 0.7);
    kPath.lineTo(w * 0.55, h * 0.5);
    kPath.lineTo(w * 0.75, h * 0.3);
    kPath.lineTo(w * 0.65, h * 0.2);
    kPath.lineTo(w * 0.45, h * 0.45);
    kPath.lineTo(w * 0.45, h * 0.2);
    kPath.close();

    canvas.drawPath(kPath, kPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
