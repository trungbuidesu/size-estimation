import 'package:flutter/material.dart';
import 'package:size_estimation/models/estimation_mode.dart';

class ModeAnimationWidget extends StatefulWidget {
  final EstimationModeType modeType;

  const ModeAnimationWidget({
    super.key,
    required this.modeType,
  });

  @override
  State<ModeAnimationWidget> createState() => _ModeAnimationWidgetState();
}

class _ModeAnimationWidgetState extends State<ModeAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.modeType) {
      case EstimationModeType.groundPlane:
        return _buildGroundPlaneAnimation();
      case EstimationModeType.planarObject:
        return _buildPlanarObjectAnimation();
      case EstimationModeType.singleView:
        return _buildSingleViewAnimation();
    }
  }

  Widget _buildGroundPlaneAnimation() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _GroundPlanePainter(_animation.value),
          size: const Size(double.infinity, 150),
        );
      },
    );
  }

  Widget _buildPlanarObjectAnimation() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _PlanarObjectPainter(_animation.value),
          size: const Size(double.infinity, 150),
        );
      },
    );
  }

  Widget _buildSingleViewAnimation() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _SingleViewPainter(_animation.value),
          size: const Size(double.infinity, 150),
        );
      },
    );
  }
}

// Ground Plane Animation Painter
class _GroundPlanePainter extends CustomPainter {
  final double progress;

  _GroundPlanePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    // Draw ground plane grid
    final gridSize = 6;
    final cellWidth = size.width / gridSize;
    final cellHeight = size.height / gridSize;

    for (int i = 0; i <= gridSize; i++) {
      canvas.drawLine(
        Offset(i * cellWidth, 0),
        Offset(i * cellWidth, size.height),
        paint..color = Colors.grey.withOpacity(0.3),
      );
      canvas.drawLine(
        Offset(0, i * cellHeight),
        Offset(size.width, i * cellHeight),
        paint..color = Colors.grey.withOpacity(0.3),
      );
    }

    // Animated points
    final point1 = Offset(size.width * 0.3, size.height * 0.5);
    final point2 = Offset(
      size.width * 0.3 + (size.width * 0.4 * progress),
      size.height * 0.5,
    );

    // Draw line between points
    canvas.drawLine(
        point1,
        point2,
        paint
          ..color = Colors.greenAccent
          ..strokeWidth = 3);

    // Draw points
    canvas.drawCircle(point1, 6, fillPaint..color = Colors.greenAccent);
    canvas.drawCircle(point2, 6, fillPaint..color = Colors.greenAccent);
  }

  @override
  bool shouldRepaint(_GroundPlanePainter oldDelegate) => true;
}

// Planar Object Animation Painter
class _PlanarObjectPainter extends CustomPainter {
  final double progress;

  _PlanarObjectPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Rectangle corners
    final rect = Rect.fromLTWH(
      size.width * 0.2,
      size.height * 0.2,
      size.width * 0.6,
      size.height * 0.6,
    );

    // Animated corner selection
    final corners = [
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
    ];

    final selectedIndex = (progress * 4).floor().clamp(0, 3);

    // Draw rectangle
    canvas.drawRect(rect, paint);

    // Draw corners
    for (int i = 0; i < corners.length; i++) {
      final isSelected = i <= selectedIndex;
      canvas.drawCircle(
        corners[i],
        8,
        Paint()
          ..color = isSelected ? Colors.orange : Colors.grey
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_PlanarObjectPainter oldDelegate) => true;
}

// Single View Animation Painter
class _SingleViewPainter extends CustomPainter {
  final double progress;

  _SingleViewPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.purple
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Draw building/wall
    final wallRect = Rect.fromLTWH(
      size.width * 0.3,
      size.height * 0.1,
      size.width * 0.4,
      size.height * 0.8,
    );

    canvas.drawRect(wallRect, paint);

    // Animated height measurement
    final bottomPoint = Offset(size.width * 0.2, wallRect.bottom);
    final topPoint = Offset(
      size.width * 0.2,
      wallRect.bottom - (wallRect.height * progress),
    );

    // Draw measurement line
    canvas.drawLine(bottomPoint, topPoint, paint..color = Colors.purpleAccent);

    // Draw arrow heads
    canvas.drawCircle(
        bottomPoint,
        6,
        Paint()
          ..color = Colors.purpleAccent
          ..style = PaintingStyle.fill);
    canvas.drawCircle(
        topPoint,
        6,
        Paint()
          ..color = Colors.purpleAccent
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_SingleViewPainter oldDelegate) => true;
}
