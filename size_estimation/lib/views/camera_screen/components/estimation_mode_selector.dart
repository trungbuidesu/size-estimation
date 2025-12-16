import 'package:flutter/material.dart';
import 'package:size_estimation/models/estimation_mode.dart';
import 'package:size_estimation/views/camera_screen/components/mode_explanation_dialog.dart';

class EstimationModeSelector extends StatefulWidget {
  final Offset center;
  final Offset currentDragPosition;
  final bool isVisible;
  final List<EstimationMode> modes;
  final ValueChanged<EstimationMode> onModeSelected;
  final VoidCallback? onDwellStarted;

  const EstimationModeSelector({
    super.key,
    required this.center,
    required this.currentDragPosition,
    required this.isVisible,
    required this.modes,
    required this.onModeSelected,
    this.onDwellStarted,
  });

  @override
  State<EstimationModeSelector> createState() => _EstimationModeSelectorState();
}

class _EstimationModeSelectorState extends State<EstimationModeSelector> {
  int? _lastSelectedIndex;
  bool _dialogShown = false;
  static const double _itemHeight = 84.0; // Must match Painter

  @override
  void dispose() {
    super.dispose();
  }

  void _showModeExplanation(EstimationMode mode) async {
    // Show dialog and wait for user response
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true, // Allow dismissing by tapping outside
      builder: (context) => ModeExplanationDialog(mode: mode),
    );

    // Only trigger mode selection if user confirmed (pressed "Đã hiểu")
    if (confirmed == true) {
      widget.onModeSelected(mode);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      _lastSelectedIndex = null;
      _dialogShown = false;
      return const SizedBox.shrink();
    }

    // Calculate selection based on drag
    // Linear Mapping: DY -> Index
    final dx = widget.currentDragPosition.dx - widget.center.dx;
    final dy = widget.currentDragPosition.dy - widget.center.dy;

    // Map DY to Index (List Logic)
    // 0 aligns with Center.
    double rawIndex = (dy / _itemHeight);

    // Clamp selection to valid indices
    int selectedIndex = rawIndex.round().clamp(0, widget.modes.length - 1);

    // Visual scroll follows finger
    double scrollProgress = rawIndex.clamp(-0.5, widget.modes.length - 0.5);

    // Reset Info Trigger if selection changes
    if (selectedIndex != _lastSelectedIndex) {
      _lastSelectedIndex = selectedIndex;
      _dialogShown = false;
    }

    // Swipe Right Logic for Info
    // Trigger if DX > Threshold (e.g. 100px)
    if (dx > 100 && !_dialogShown) {
      _dialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showModeExplanation(widget.modes[selectedIndex]);
      });
    }

    return Stack(
      children: [
        CustomPaint(
          painter: _StaggeredListMenuPainter(
            center: widget.center,
            modes: widget.modes,
            selectedIndex: selectedIndex,
            scrollProgress: scrollProgress,
            dwellIndex: null, // Removed dwell visual
            theme: Theme.of(context),
          ),
          size: Size.infinite,
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
  final int? dwellIndex;
  final ThemeData theme;

  _StaggeredListMenuPainter({
    required this.center,
    required this.modes,
    required this.selectedIndex,
    required this.scrollProgress,
    this.dwellIndex,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final colorScheme = theme.colorScheme;

    // 1. Draw "Wheel" at center
    final Paint wheelPaint = Paint()
      ..color = colorScheme.onSurface.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Outer ring
    canvas.drawCircle(center, 38.0, wheelPaint);
    // Inner ring
    wheelPaint.color = colorScheme.onSurface.withOpacity(0.6);
    canvas.drawCircle(center, 30.0, wheelPaint);

    // 2. Draw Staggered List
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.start,
    );

    const double itemHeight = 84.0;
    const double baseXOffset = 20.0;
    const double selectedXOffset = 30.0;

    for (int i = 0; i < modes.length; i++) {
      final double indexDiff = i - scrollProgress;
      final double yOffset = indexDiff * itemHeight;

      final double dist = indexDiff.abs();
      final double highlight = (1.0 - (dist / 1.5).clamp(0.0, 1.0));

      final double opacity = 0.4 + (0.6 * highlight);
      final double scale = 0.85 + (0.15 * highlight);

      final double xShift = baseXOffset + (selectedXOffset * highlight);

      final double cx = center.dx + xShift;
      final double cy = center.dy + yOffset;

      final bool isDwelling = (dwellIndex != null && i == dwellIndex);

      final double widthBase = 260.0;
      final double widthExpand = 40.0;
      final double boxWidth = widthBase + (widthExpand * highlight);
      final double boxHeight = 76.0;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(scale);

      final Rect drawRect =
          Rect.fromLTWH(0, -boxHeight / 2, boxWidth, boxHeight);
      final RRect rrect =
          RRect.fromRectAndRadius(drawRect, const Radius.circular(12));

      final bool isTargeted = (i == selectedIndex);

      // Shadow
      if (highlight > 0.5 || isDwelling) {
        canvas.drawShadow(Path()..addRRect(rrect), Colors.black,
            isDwelling ? 8.0 : 4.0 * highlight, true);
      }

      final Paint paint = Paint()..style = PaintingStyle.fill;

      // Card Background
      if (isTargeted) {
        paint.color = colorScheme.primary.withOpacity(0.95);
      } else {
        paint.color = theme.cardColor.withOpacity(0.9 * opacity);
      }
      canvas.drawRRect(rrect, paint);

      // Border
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = isDwelling ? 2.5 : (isTargeted ? 1.5 : 0.5);

      if (isDwelling) {
        paint.color = colorScheme.secondary;
      } else if (isTargeted) {
        paint.color = colorScheme.onPrimary.withOpacity(0.5);
      } else {
        paint.color = colorScheme.outline.withOpacity(0.2);
      }
      canvas.drawRRect(rrect, paint);

      // Content
      _drawContent(canvas, textPainter, modes[i], boxWidth, boxHeight,
          isTargeted, isDwelling, colorScheme);

      canvas.restore();
    }
  }

  void _drawContent(
      Canvas canvas,
      TextPainter textPainter,
      EstimationMode mode,
      double width,
      double height,
      bool isSelected,
      bool isDwelling,
      ColorScheme colors) {
    const double padding = 16.0;

    final Color primaryColor = isSelected ? colors.onPrimary : colors.onSurface;
    final Color secondaryColor = isSelected
        ? colors.onPrimary.withOpacity(0.8)
        : colors.onSurfaceVariant;

    // Icon
    final iconSpan = TextSpan(
      text: String.fromCharCode(mode.icon.codePoint),
      style: TextStyle(
        fontSize: 32,
        fontFamily: mode.icon.fontFamily,
        package: mode.icon.fontPackage,
        color: secondaryColor,
      ),
    );
    textPainter.text = iconSpan;
    textPainter.layout();
    final double iconH = textPainter.height;
    textPainter.paint(canvas, Offset(padding, -iconH / 2));

    // Text Column
    final double textLeft = padding + textPainter.width + 16;
    final double maxTextWidth = width - textLeft - padding;

    // Title
    final labelSpan = TextSpan(
      text: mode.label,
      style: TextStyle(
        color: primaryColor,
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
        color: secondaryColor,
        fontSize: 11,
        height: 1.2,
      ),
    );

    final descPainter = TextPainter(
      text: descSpan,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '...',
    );
    descPainter.layout(maxWidth: maxTextWidth);

    final double totalTextH = labelH + descPainter.height + 4;
    final double startY = -totalTextH / 2;

    textPainter.paint(canvas, Offset(textLeft, startY));
    descPainter.paint(canvas, Offset(textLeft, startY + labelH + 4));
  }

  @override
  bool shouldRepaint(covariant _StaggeredListMenuPainter oldDelegate) {
    return oldDelegate.scrollProgress != scrollProgress ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.dwellIndex != dwellIndex ||
        oldDelegate.center != center ||
        oldDelegate.theme != theme;
  }
}
