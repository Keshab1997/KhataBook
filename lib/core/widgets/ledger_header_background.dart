// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The green and gold wave used by the All Transactions banner.
class LedgerHeaderBackground extends StatelessWidget {
  const LedgerHeaderBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(
      children: <Widget>[
        const Positioned.fill(child: CustomPaint(painter: _WavePainter())),
        Positioned(
          right: 0,
          bottom: 0,
          child: IgnorePointer(child: HeaderCornerLeaves()),
        ),
        child,
      ],
    ),
  );
}

class _WavePainter extends CustomPainter {
  const _WavePainter();
  Path _wave(Size size, double inset) {
    final double bottom = size.height - inset;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, bottom - 16)
      ..cubicTo(
        size.width * .72,
        bottom + 10,
        size.width * .34,
        bottom - 30,
        0,
        bottom - 6,
      )
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(_wave(size, 0), Paint()..color = AppColors.golden);
    canvas.drawPath(
      _wave(size, 4),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.primaryGreen, AppColors.headerGreen],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Transparent decoration anchored to the banner's right-hand corner. Unlike
/// the old cropped bitmap it contains no baked-in background or gold stripe.
class HeaderCornerLeaves extends StatelessWidget {
  const HeaderCornerLeaves({super.key, this.width = 64, this.height = 32});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: width,
      height: height,
      child: const CustomPaint(painter: _CornerLeavesPainter()),
    ),
  );
}

class _CornerLeavesPainter extends CustomPainter {
  const _CornerLeavesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 32);
    final Paint stem = Paint()
      ..color = AppColors.secondaryGreen
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final Path branch = Path()
      ..moveTo(64, 31)
      ..quadraticBezierTo(46, 21, 28, 18);
    canvas.drawPath(branch, stem);
    void leaf(double x, double y, double angle, Color color) {
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      final Path shape = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(-9, -7, -17, -1)
        ..quadraticBezierTo(-9, 5, 0, 0);
      canvas.drawPath(shape, Paint()..color = color);
      canvas.restore();
    }

    leaf(58, 27, 0.6, AppColors.accentGreen);
    leaf(54, 25, -0.65, AppColors.secondaryGreen);
    leaf(45, 22, 0.45, AppColors.secondaryGreen);
    leaf(40, 20, -0.6, AppColors.accentGreen);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
