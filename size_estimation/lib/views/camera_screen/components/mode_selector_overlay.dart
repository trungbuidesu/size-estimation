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
    const double innerRadius = 30; // Button radius approx
    const double outerRadius = 140;
    const double startAngle = pi; // 180 degrees (Left)
    const double sweepAngle = pi; // 180 degrees span (Total semi-circle)

    // Calculate selection
    final dx = currentDragPosition.dx - center.dx;
    final dy = currentDragPosition.dy - center.dy;
    final distance = sqrt(dx * dx + dy * dy);
    double angle = atan2(dy, dx);
    // Normalize angle to 0..2pi
    if (angle < 0) angle += 2 * pi;

    int? selectedIndex;
    if (distance > innerRadius) {
      // Check which segment
      // Our span is from pi (180) to 2pi (360) / 0.
      // Actually standard Air Command is often a full circle or fan.
      // User said "Swipe Up". So likely the fan is ABOVE the button.
      // So angles are between pi (180) and 2pi (0).
      // Let's map 4 items to the upper semicircle (180 to 0 degrees).
      // 180 -> 225 (Item 1)
      // 225 -> 270 (Item 2)
      // 270 -> 315 (Item 3)
      // 315 -> 360/0 (Item 4)

      // Angle in Cartesian:
      // Right is 0. Down is pi/2. Left is pi. Up is -pi/2 (or 3pi/2).
      // We are swiping UP. So interesting range is around -pi/2.

      // Let's define the fan spread.
      // Maybe 180 degrees fan centered at UP (-pi/2)?
      // Start: -pi (Left) to 0 (Right).

      double normalizedAngle = angle;
      // atan2 returns -pi to pi.
      // Up is -pi/2. Left is pi/-pi. Right is 0.

      // Let's use range [pi, 2pi] (which is effectively negative y).
      // Wait, standard coordinates: +y is down. -y is up.
      // So UP swipe has negative dy.
      // atan2(negative, anything) -> -pi to 0.

      // We want to divide the upper semi-circle (-pi to 0) into 4 segments.
      // Segment 1: -pi to -3pi/4 (-180 to -135)
      // Segment 2: -3pi/4 to -pi/2 (-135 to -90)
      // Segment 3: -pi/2 to -pi/4 (-90 to -45)
      // Segment 4: -pi/4 to 0 (-45 to 0)

      if (dy < 0) {
        // Only checking upper half
        if (angle >= -pi && angle < -3 * pi / 4)
          selectedIndex = 0;
        else if (angle >= -3 * pi / 4 && angle < -pi / 2)
          selectedIndex = 1;
        else if (angle >= -pi / 2 && angle < -pi / 4)
          selectedIndex = 2;
        else if (angle >= -pi / 4 && angle <= 0) selectedIndex = 3;
        // Handle borderline pi case? atan2 can return pi.
        // If atan2 returns positive pi (180), that's left horizontal.
        // Close enough to -pi.
        if (angle.abs() > pi - 0.1) selectedIndex = 0;
      }
    }

    final segmentAngle = pi / 4; // 4 segments in 180 degrees

    for (int i = 0; i < 4; i++) {
      final isSelected = (i == selectedIndex);
      paint.color = isSelected
          ? Colors.blue.withOpacity(0.9)
          : Colors.black.withOpacity(0.6);

      // Draw arc segment
      // Start angle: -pi + i * segmentAngle
      double start = -pi + (i * segmentAngle);

      // Draw segment
      // We simulate an arc with lines or use drawArc.
      // For distinct "wings" with gaps, we can reduce sweep slightly.

      Path path = Path();
      path.arcTo(
          Rect.fromCircle(center: center, radius: outerRadius),
          start + 0.05, // gap
          segmentAngle - 0.1, // gap
          false);
      path.arcTo(
          Rect.fromCircle(
              center: center,
              radius: innerRadius + 10), // variable inner radius
          start + segmentAngle - 0.1 - 0.05,
          -(segmentAngle - 0.1),
          false);
      path.close();

      canvas.drawPath(path, paint);

      // Draw Icon and Text
      final midAngle = start + segmentAngle / 2;
      final iconRadius = (innerRadius + outerRadius) / 2;
      final iconX = center.dx + iconRadius * cos(midAngle);
      final iconY = center.dy + iconRadius * sin(midAngle);

      final iconPainter = TextPainter(
        text: TextSpan(
            text: String.fromCharCode(modes[i].icon.codePoint),
            style: TextStyle(
              fontSize: 24,
              fontFamily: modes[i].icon.fontFamily,
              color: Colors.white,
            )),
        textDirection: TextDirection.ltr,
      );
      iconPainter.layout();
      iconPainter.paint(
          canvas,
          Offset(iconX - iconPainter.width / 2,
              iconY - iconPainter.height / 2 - 10));

      final textPainter = TextPainter(
          text: TextSpan(
              text: modes[i].label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(iconX - textPainter.width / 2, iconY + 10));
    }

    // Draw center line or connector?
    // Draw drag line
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Optionally draw line from center to cursor
    // canvas.drawLine(center, currentDragPosition, linePaint);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) {
    return oldDelegate.currentDragPosition != currentDragPosition ||
        oldDelegate.center != center;
  }
}
