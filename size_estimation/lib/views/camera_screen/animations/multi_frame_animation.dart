import 'package:flutter/material.dart';

class MultiFrameAnimation extends StatefulWidget {
  const MultiFrameAnimation({super.key});

  @override
  State<MultiFrameAnimation> createState() => _MultiFrameAnimationState();
}

class _MultiFrameAnimationState extends State<MultiFrameAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FrameStackPainter(_controller),
      size: const Size(200, 120),
    );
  }
}

class _FrameStackPainter extends CustomPainter {
  final Animation<double> animation;

  _FrameStackPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    // We visualize 3 frames merging into 1
    final center = Offset(size.width / 2, size.height / 2);
    final t = animation.value;

    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.blueAccent.withOpacity(0.8);

    final Paint fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.blueAccent.withOpacity(0.1);

    // Frame 1 (Left) - Approaches center
    _drawFrame(
        canvas, center + Offset(-60 * (1 - t), 0), borderPaint, fillPaint);

    // Frame 2 (Right) - Approaches center
    _drawFrame(
        canvas, center + Offset(60 * (1 - t), 0), borderPaint, fillPaint);

    // Frame 3 (Center) - The base
    _drawFrame(canvas, center, borderPaint, fillPaint);

    // Merged Result (Pulse effect at end)
    if (t > 0.8) {
      final pulse = (t - 0.8) * 5; // 0 to 1
      final Paint resultPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 + pulse * 2
        ..color = Colors.greenAccent.withOpacity(1.0 - pulse);

      canvas.drawRect(
        Rect.fromCenter(center: center, width: 40, height: 30),
        resultPaint,
      );
    }
  }

  void _drawFrame(Canvas canvas, Offset pos, Paint border, Paint fill) {
    final rect = Rect.fromCenter(center: pos, width: 40, height: 30);
    __drawDashedRect(
        canvas, rect, border); // Simple solid for now or dashed custom
    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, border);
  }

  void __drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    // Just drawing solid for specific style
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
