import 'dart:math';
import 'package:flutter/material.dart';

class ModeSelectorOverlay extends StatelessWidget {
  final Offset center;
  final Offset currentDragPosition;
  final bool isVisible;
  final List<ModeItem> modes;
  final Function(int) onModeSelected;

  const ModeSelectorOverlay({
    super.key,
    required this.center,
    required this.currentDragPosition,
    required this.isVisible,
    required this.modes,
    required this.onModeSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return CustomPaint(
      painter: _WheelPainter(
        center: center,
        currentDragPosition: currentDragPosition,
        modes: modes,
      ),
      child: Container(),
    );
  }
}

class ModeItem {
  final IconData icon;
  final String label;

  const ModeItem({required this.icon, required this.label});
}

class _WheelPainter extends CustomPainter {
  final Offset center;
  final Offset currentDragPosition;
  final List<ModeItem> modes;

  _WheelPainter({
    required this.center,
    required this.currentDragPosition,
    required this.modes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Configuration
    const double innerRadius = 40;
    const double outerRadius = 150;

    // We assume a swipe UP, so we map the Upper Semicircle (180 deg).
    // Angle range: -pi (-180, Left) to 0 (Right).
    const double totalSweep = pi;
    const double startAngle = -pi;

    final int count = modes.length;
    if (count == 0) return;

    final double segmentAngle = totalSweep / count;

    // Calculate selection
    final dx = currentDragPosition.dx - center.dx;
    final dy = currentDragPosition.dy - center.dy;
    final distance = sqrt(dx * dx + dy * dy);
    double angle = atan2(dy, dx);

    // Determine selected index
    int? selectedIndex;
    if (distance > innerRadius) {
      // Only consider valid up-swipe (dy < 0 generally, or within angular bounds)
      // We allow slightly loose bounds (e.g. slight "down" drift at horizontal edges)
      // by clamping, since atan2 wraps at pi/-pi.

      // Normalize angle logic relative to startAngle (-pi)
      double relativeAngle = angle - startAngle;

      // Handle wrap-around case: atan2 returns pi for exact left, -pi for slightly down-left?
      // atan2 range is -pi to pi.
      // -pi is Left. 0 is Right.
      // We expect angle in [-pi, 0].

      if (angle > 0) {
        // User dragged Down.
        // If closer to Left (pi), treat as first item.
        // If closer to Right (0), treat as last item.
        if (angle > pi / 2)
          relativeAngle = 0; // Close to -pi
        else
          relativeAngle = totalSweep; // Close to 0
      }

      int idx = (relativeAngle / segmentAngle).floor();
      // Clamp
      if (idx < 0) idx = 0;
      if (idx >= count) idx = count - 1;

      selectedIndex = idx;
    }

    // Draw Segments
    for (int i = 0; i < count; i++) {
      final isSelected = (i == selectedIndex);
      paint.color = isSelected
          ? Colors.blue.withOpacity(0.9)
          : Colors.black.withOpacity(0.6);

      double segStart = startAngle + (i * segmentAngle);

      Path path = Path();
      // Outer arc
      path.arcTo(Rect.fromCircle(center: center, radius: outerRadius),
          segStart + 0.02, segmentAngle - 0.04, false);
      // Inner arc (reverse)
      path.arcTo(Rect.fromCircle(center: center, radius: innerRadius + 10),
          segStart + segmentAngle - 0.02, -(segmentAngle - 0.04), false);
      path.close();

      canvas.drawPath(path, paint);

      // Draw Icon and Text
      final midAngle = segStart + segmentAngle / 2;
      final iconRadius = (innerRadius + outerRadius) / 2;
      final iconX = center.dx + iconRadius * cos(midAngle);
      final iconY = center.dy + iconRadius * sin(midAngle);

      // Icon
      final iconPainter = TextPainter(
        text: TextSpan(
            text: String.fromCharCode(modes[i].icon.codePoint),
            style: TextStyle(
              fontSize: 28,
              fontFamily: modes[i].icon.fontFamily,
              package: modes[i].icon.fontPackage,
              color: Colors.white,
            )),
        textDirection: TextDirection.ltr,
      );
      iconPainter.layout();
      iconPainter.paint(
          canvas,
          Offset(iconX - iconPainter.width / 2,
              iconY - iconPainter.height / 2 - 8));

      // Label
      final textPainter = TextPainter(
          text: TextSpan(
              text: modes[i].label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(iconX - textPainter.width / 2, iconY + 12));
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) {
    return oldDelegate.currentDragPosition != currentDragPosition ||
        oldDelegate.center != center ||
        oldDelegate.modes != modes;
  }
}
