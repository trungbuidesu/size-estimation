import 'package:flutter/material.dart';
import 'package:size_estimation/models/estimation_mode.dart';

class ModeExplanationDialog extends StatefulWidget {
  final EstimationMode mode;

  const ModeExplanationDialog({
    super.key,
    required this.mode,
  });

  @override
  State<ModeExplanationDialog> createState() => _ModeExplanationDialogState();
}

class _ModeExplanationDialogState extends State<ModeExplanationDialog>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late AnimationController _loopController;

  @override
  void initState() {
    super.initState();
    // Entrance animations
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));

    _entranceController.forward();

    // Looping animation for illustrations
    _loopController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _loopController.dispose();
    super.dispose();
  }

  Widget _buildIllustration() {
    return AnimatedBuilder(
      animation: _loopController,
      builder: (context, child) {
        switch (widget.mode.type) {
          case EstimationModeType.groundPlane:
            return CustomPaint(
              size: const Size(200, 150),
              painter: _GroundPlanePainter(progress: _loopController.value),
            );
          case EstimationModeType.planarObject:
            return CustomPaint(
              size: const Size(200, 150),
              painter: _PlanarObjectPainter(progress: _loopController.value),
            );
          case EstimationModeType.singleView:
            return CustomPaint(
              size: const Size(200, 150),
              painter: _VerticalObjectPainter(progress: _loopController.value),
            );
        }
      },
    );
  }

  String _getDetailedExplanation() {
    switch (widget.mode.type) {
      case EstimationModeType.groundPlane:
        return 'Đo khoảng cách giữa 2 điểm trên mặt phẳng ngang (sàn nhà, mặt bàn).\n\n'
            '📍 Chọn 2 điểm trên mặt phẳng\n'
            '📏 Hệ thống tính khoảng cách thực tế\n'
            '⚙️ Cần: Chiều cao camera';
      case EstimationModeType.planarObject:
        return 'Đo kích thước vật phẳng (giấy A4, màn hình, hộp).\n\n'
            '📐 Chọn 4 góc của vật\n'
            '📏 Tính chiều dài, chiều rộng\n'
            '🎯 Cần: Vật tham chiếu (tùy chọn)';
      case EstimationModeType.singleView:
        return 'Đo chiều cao vật thẳng đứng (cột, tường, cây).\n\n'
            '⬆️ Chọn điểm đỉnh\n'
            '⬇️ Chọn điểm chân\n'
            '📏 Tính chiều cao thực tế\n'
            '⚙️ Cần: Chiều cao camera';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Reuse structure similar to CommonAlertDialog but with custom content
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Dialog(
          // Theme properties are automatically picked up by Dialog if configured in AppTheme
          // but we can be explicit to match exactly what CommonAlertDialog does if needed.
          // AppTheme defines dialogTheme, so standard Dialog is good.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title with Icon corresponding to the mode
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        widget.mode.icon,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.mode.label,
                            style: theme.dialogTheme.titleTextStyle ??
                                theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.mode.description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Illustration
              Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.all(24),
                child: _buildIllustration(),
              ),

              // Detailed explanation
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Text(
                  _getDetailedExplanation(),
                  style: theme.dialogTheme.contentTextStyle ??
                      theme.textTheme.bodyMedium,
                ),
              ),

              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Cancel button
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Hủy'),
                    ),
                    const SizedBox(width: 12),
                    // Confirm button
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Đã hiểu'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom painters for illustrations
class _GroundPlanePainter extends CustomPainter {
  final double progress;

  _GroundPlanePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Use a cycle for smooth looping if desired, or simpler linear loop
    // For visual breathing, maybe use a curve on the progress
    // But passing raw progress is fine, we can manipulate it here.

    // Ground plane
    paint.color = Colors.white.withOpacity(0.3);
    canvas.drawLine(
      Offset(0, size.height * 0.7),
      Offset(size.width, size.height * 0.7),
      paint,
    );

    // Points
    final pointA = Offset(size.width * 0.3, size.height * 0.7);
    final pointB = Offset(size.width * 0.7, size.height * 0.7);

    paint.color = const Color(
        0xFF579DFF); // Match primary color from theme roughly or use context if passed
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(pointA, 6, paint);
    canvas.drawCircle(pointB, 6, paint);

    // Distance line animation
    // Loop: 0..0.5 draw line, 0.5..0.8 hold, 0.8..1.0 fade/reset
    double lineProgress = 0.0;
    if (progress < 0.5) {
      lineProgress = progress / 0.5;
    } else {
      lineProgress = 1.0;
    }

    if (lineProgress > 0) {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 3;
      // Slight fade out at the end
      if (progress > 0.8) {
        paint.color = paint.color.withOpacity(1.0 - (progress - 0.8) * 5);
      }

      canvas.drawLine(
        pointA,
        Offset.lerp(pointA, pointB, lineProgress)!,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GroundPlanePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _PlanarObjectPainter extends CustomPainter {
  final double progress;

  _PlanarObjectPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF579DFF);

    // Rectangle (perspective)
    final corners = [
      Offset(size.width * 0.2, size.height * 0.3),
      Offset(size.width * 0.8, size.height * 0.2),
      Offset(size.width * 0.85, size.height * 0.7),
      Offset(size.width * 0.15, size.height * 0.8),
    ];

    // Draw rectangle with progress
    // Loop: Draw segments sequentially
    final path = Path();
    path.moveTo(corners[0].dx, corners[0].dy);

    // 0.0 to 0.8 draws the box. 0.8 to 1.0 fades/pauses.
    double drawProgress = (progress / 0.8).clamp(0.0, 1.0);

    // If we're in the fade out phase
    if (progress > 0.8) {
      paint.color = paint.color.withOpacity(1.0 - (progress - 0.8) * 5);
    }

    for (int i = 1; i <= 4; i++) {
      // 4 segments.
      // 0.0 - 0.25 : seg 1
      // 0.25 - 0.5 : seg 2, etc.
      double startP = (i - 1) * 0.25;

      if (drawProgress >= startP) {
        // Calculate how much of this segment to draw
        double localProgress = (drawProgress - startP) / 0.25;
        if (localProgress > 1.0) localProgress = 1.0;

        final start = corners[i - 1];
        final end = corners[i % 4];
        final current = Offset.lerp(start, end, localProgress)!;
        path.lineTo(current.dx, current.dy);
      }
    }
    canvas.drawPath(path, paint);

    // Corner points
    paint.style = PaintingStyle.fill;
    for (var corner in corners) {
      // Optional: animate points appearing
      canvas.drawCircle(corner, 5, paint);
    }
  }

  @override
  bool shouldRepaint(_PlanarObjectPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _VerticalObjectPainter extends CustomPainter {
  final double progress;

  _VerticalObjectPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Ground
    paint.color = Colors.white.withOpacity(0.3);
    canvas.drawLine(
      Offset(0, size.height * 0.8),
      Offset(size.width, size.height * 0.8),
      paint,
    );

    // Vertical object
    final bottom = Offset(size.width * 0.5, size.height * 0.8);
    final top = Offset(size.width * 0.5, size.height * 0.2);

    paint.color = Colors.white.withOpacity(0.5);
    paint.strokeWidth = 20;
    canvas.drawLine(bottom, top, paint);

    // Measurement line
    // Loop: 0..0.6 animate up, 0.6..1.0 hold/reset

    double lineProgress = (progress / 0.6).clamp(0.0, 1.0);

    paint.color = const Color(0xFF579DFF); // Primary blue
    if (progress > 0.8) {
      paint.color = paint.color.withOpacity(1.0 - (progress - 0.8) * 5);
    }
    paint.strokeWidth = 3;

    if (lineProgress > 0) {
      canvas.drawLine(
        bottom,
        Offset.lerp(bottom, top, lineProgress)!,
        paint,
      );
    }

    // Points
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(bottom, 6, paint);
    canvas.drawCircle(top, 6, paint);
  }

  @override
  bool shouldRepaint(_VerticalObjectPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
