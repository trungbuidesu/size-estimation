import 'dart:math';
import 'package:flutter/material.dart';
import 'package:size_estimation/models/estimation_mode.dart';

class EstimationModeSelector extends StatelessWidget {
  final Offset center;
  final Offset currentDragPosition;
  final bool isVisible;
  final List<EstimationMode> modes;
  final ValueChanged<EstimationMode> onModeSelected;

  const EstimationModeSelector({
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

    // Calculate selection based on drag
    final dx = currentDragPosition.dx - center.dx;
    final dy = currentDragPosition.dy - center.dy;
    final distance = sqrt(dx * dx + dy * dy);
    final angle = atan2(dy, dx);

    // Fan Logic for Selection Index mapping to Scroll Progress
    // We want the list to scroll naturally as the user fans up/down (right side).
    // Using 180 degrees (Semicircle) for balanced sensitivity.
    const double totalSweep = 180 * (pi / 180);
    const double startAngle = -totalSweep / 2;
    final double segmentAngle = totalSweep / modes.length;

    int selectedIndex = -1;
    double scrollProgress = 0.0;

    if (distance > 20) {
      // Normalize angle relative to start
      double relative = angle - startAngle;

      // Calculate raw scroll progress
      // (relative / segmentAngle) can be negative or > length
      double rawProgress = (relative / segmentAngle);

      // Determine the logical selection (hard clamp for Logic)
      if (angle >= startAngle && angle <= startAngle + totalSweep) {
        selectedIndex = rawProgress.floor().clamp(0, modes.length - 1);
      } else {
        // If outside angular bounds, we might still want to select the closest one logic-wise?
        // Current CameraScreen logic only selects if inside bounds. We'll stick to that visually for 'selected' state.
        selectedIndex = -1;
      }

      // Visual Scroll Progress with Rubber Banding / Soft Limits
      // Instead of hard clamp, we dampen the overflow.
      if (rawProgress < 0) {
        // Overshoot top
        // f(x) = x * 0.3 for x < 0
        scrollProgress = rawProgress * 0.3;
      } else if (rawProgress > modes.length) {
        // Overshoot bottom
        double excess = rawProgress - modes.length;
        scrollProgress = modes.length + (excess * 0.3);
      } else {
        // Within bounds
        scrollProgress = rawProgress;
      }

      // Still apply a visual maximum limit so it doesn't fly off screen completely if user circles around
      // But keep it responsive.
      scrollProgress = scrollProgress.clamp(-1.0, modes.length + 1.0);
    }

    return Stack(
      children: [
        CustomPaint(
          painter: _StaggeredListMenuPainter(
            center: center,
            modes: modes,
            selectedIndex: selectedIndex,
            scrollProgress: scrollProgress,
          ),
          size: Size.infinite,
        ),

        // Center Anchor Indicator (optional, minimal)
        Positioned(
          left: center.dx - 10,
          top: center.dy - 10,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _StaggeredListMenuPainter extends CustomPainter {
  final Offset center;
  final List<EstimationMode> modes;
  final int selectedIndex;
  final double scrollProgress;

  _StaggeredListMenuPainter({
    required this.center,
    required this.modes,
    required this.selectedIndex,
    required this.scrollProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw "Wheel" at center (2 concentric circles, no fill)
    final Paint wheelPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Outer ring
    canvas.drawCircle(center, 38.0, wheelPaint);
    // Inner ring
    canvas.drawCircle(center, 30.0, wheelPaint);

    // 2. Draw Staggered List
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.start,
    );

    const double itemHeight = 80.0;
    // Shift list further right to avoid overlap.
    // Since wheel radius is ~40, let's start list at x + 60 minimum.
    const double baseXOffset = 70.0;
    const double selectedXOffset = 30.0;

    for (int i = 0; i < modes.length; i++) {
      final double indexDiff = i - scrollProgress;
      final double yOffset = indexDiff * itemHeight;

      final double dist = indexDiff.abs();
      final double highlight = (1.0 - (dist / 1.5).clamp(0.0, 1.0));

      final double opacity = 0.4 + (0.6 * highlight);
      final double scale = 0.85 + (0.15 * highlight);

      // Thò thụt: Selected moves right
      final double xShift = baseXOffset + (selectedXOffset * highlight);

      final double cx = center.dx + xShift;
      final double cy = center.dy + yOffset;

      // Dimensions
      final double widthBase = 260.0;
      final double widthExpand = 40.0;
      final double boxWidth = widthBase + (widthExpand * highlight);
      final double boxHeight = 70.0;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(scale);

      // Draw Card (Anchor Left Edge)
      // Shift drawing so (0,0) is the Left-Center of the box
      // This ensures the box grows to the right and doesn't overlap the wheel/left side
      final Rect drawRect =
          Rect.fromLTWH(0, -boxHeight / 2, boxWidth, boxHeight);
      final RRect rrect =
          RRect.fromRectAndRadius(drawRect, const Radius.circular(12));

      final bool isTargeted = (i == selectedIndex);

      if (highlight > 0.5) {
        canvas.drawShadow(
            Path()..addRRect(rrect), Colors.black, 4.0 * highlight, true);
      }

      final Paint paint = Paint()
        ..style = PaintingStyle.fill
        ..color = isTargeted
            ? const Color(0xFF2196F3).withOpacity(0.95)
            : const Color(0xFF1E1E1E).withOpacity(0.85 * opacity);

      canvas.drawRRect(rrect, paint);

      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = isTargeted ? 2.0 : 1.0
        ..color = Colors.white.withOpacity(isTargeted ? 1.0 : 0.3);

      canvas.drawRRect(rrect, paint);

      // Draw Content
      _drawContent(
          canvas, textPainter, modes[i], boxWidth, boxHeight, isTargeted);

      canvas.restore();
    }
  }

  void _drawContent(Canvas canvas, TextPainter textPainter, EstimationMode mode,
      double width, double height, bool isSelected) {
    const double padding = 16.0;

    // Content is drawn relative to (0,0) which is now Left-Center of box
    // So x starts at 0 + padding

    // Icon
    final iconSpan = TextSpan(
      text: String.fromCharCode(mode.icon.codePoint),
      style: TextStyle(
        fontSize: 32,
        fontFamily: mode.icon.fontFamily,
        package: mode.icon.fontPackage,
        color: isSelected ? Colors.white : Colors.white54,
      ),
    );
    textPainter.text = iconSpan;
    textPainter.layout();

    final double iconH = textPainter.height;
    // Vertically center icon, align left
    textPainter.paint(canvas, Offset(padding, -iconH / 2));

    // Text Column
    final double textLeft = padding + textPainter.width + 12;
    // Width available = Total Width - LeftUsed - PaddingRight
    final double maxTextWidth = width - textLeft - padding;

    // Title
    final labelSpan = TextSpan(
      text: mode.label,
      style: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );

    textPainter.text = labelSpan;
    textPainter.layout(maxWidth: maxTextWidth);
    final double labelH = textPainter.height;

    // Description
    final descSpan = TextSpan(
      text: mode.description,
      style: TextStyle(
        color: isSelected ? Colors.blue.shade100 : Colors.white38,
        fontWeight: FontWeight.normal,
        fontSize: 10,
        height: 1.1,
      ),
    );

    final descPainter = TextPainter(
      text: descSpan,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '...',
    );
    descPainter.layout(maxWidth: maxTextWidth);

    // V-Center text block
    final double totalTextH = labelH + descPainter.height + 2;
    final double startY = -totalTextH / 2;

    textPainter.paint(canvas, Offset(textLeft, startY));
    descPainter.paint(canvas, Offset(textLeft, startY + labelH + 2));
  }

  @override
  bool shouldRepaint(covariant _StaggeredListMenuPainter oldDelegate) {
    return oldDelegate.scrollProgress != scrollProgress ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.center != center;
  }
}
