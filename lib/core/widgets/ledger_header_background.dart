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
          child: IgnorePointer(
            child: Image.asset(
              'assets/illustrations/entry_header_leaves.png',
              width: 90,
              height: 42,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
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
