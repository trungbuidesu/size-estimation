import 'package:flutter/material.dart';

class GridOverlay extends StatelessWidget {
  final bool visible;

  const GridOverlay({super.key, required this.visible});

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return IgnorePointer(
      child: CustomPaint(
        painter: _GridPainter(),
        child: Container(),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1.0;

    // Draw vertical lines (thirds)
    final double thirdWidth = size.width / 3;
    canvas.drawLine(
        Offset(thirdWidth, 0), Offset(thirdWidth, size.height), paint);
    canvas.drawLine(
        Offset(thirdWidth * 2, 0), Offset(thirdWidth * 2, size.height), paint);

    // Draw horizontal lines (thirds)
    final double thirdHeight = size.height / 3;
    canvas.drawLine(
        Offset(0, thirdHeight), Offset(size.width, thirdHeight), paint);
    canvas.drawLine(
        Offset(0, thirdHeight * 2), Offset(size.width, thirdHeight * 2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
