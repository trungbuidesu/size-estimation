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
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildIllustration() {
    switch (widget.mode.type) {
      case EstimationModeType.groundPlane:
        return _buildGroundPlaneIllustration();
      case EstimationModeType.planarObject:
        return _buildPlanarObjectIllustration();
      case EstimationModeType.singleView:
        return _buildVerticalObjectIllustration();
      case EstimationModeType.multiFrame:
        return _buildMultiFrameIllustration();
    }
  }

  Widget _buildGroundPlaneIllustration() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1200),
      builder: (context, value, child) {
        return CustomPaint(
          size: const Size(200, 150),
          painter: _GroundPlanePainter(progress: value),
        );
      },
    );
  }

  Widget _buildPlanarObjectIllustration() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1200),
      builder: (context, value, child) {
        return CustomPaint(
          size: const Size(200, 150),
          painter: _PlanarObjectPainter(progress: value),
        );
      },
    );
  }

  Widget _buildVerticalObjectIllustration() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1200),
      builder: (context, value, child) {
        return CustomPaint(
          size: const Size(200, 150),
          painter: _VerticalObjectPainter(progress: value),
        );
      },
    );
  }

  Widget _buildMultiFrameIllustration() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1500),
      builder: (context, value, child) {
        return CustomPaint(
          size: const Size(200, 150),
          painter: _MultiFramePainter(progress: value),
        );
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
      case EstimationModeType.multiFrame:
        return 'Đo từ nhiều frame liên tiếp để tăng độ chính xác.\n\n'
            '🎥 Giữ điểm đo trong 2-3 giây\n'
            '📊 Hệ thống lấy trung bình\n'
            '✨ Giảm nhiễu, tăng độ chính xác';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1E1E1E),
                  const Color(0xFF2D2D2D),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF2196F3).withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          widget.mode.icon,
                          color: const Color(0xFF2196F3),
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.mode.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.mode.description,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Illustration
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildIllustration(),
                ),

                // Detailed explanation
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Text(
                    _getDetailedExplanation(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),

                // Close button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Đã hiểu',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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

    paint.color = const Color(0xFF2196F3);
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(pointA, 6, paint);
    canvas.drawCircle(pointB, 6, paint);

    // Distance line
    if (progress > 0.3) {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 3;
      final lineProgress = ((progress - 0.3) / 0.7).clamp(0.0, 1.0);
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
      ..color = const Color(0xFF2196F3);

    // Rectangle (perspective)
    final corners = [
      Offset(size.width * 0.2, size.height * 0.3),
      Offset(size.width * 0.8, size.height * 0.2),
      Offset(size.width * 0.85, size.height * 0.7),
      Offset(size.width * 0.15, size.height * 0.8),
    ];

    // Draw rectangle with progress
    final path = Path();
    path.moveTo(corners[0].dx, corners[0].dy);
    for (int i = 1; i <= 4; i++) {
      final segmentProgress = ((progress - i * 0.2) / 0.2).clamp(0.0, 1.0);
      if (segmentProgress > 0) {
        final start = corners[i - 1];
        final end = corners[i % 4];
        final current = Offset.lerp(start, end, segmentProgress)!;
        path.lineTo(current.dx, current.dy);
      }
    }
    canvas.drawPath(path, paint);

    // Corner points
    paint.style = PaintingStyle.fill;
    for (var corner in corners) {
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
    if (progress > 0.2) {
      paint.color = const Color(0xFF2196F3);
      paint.strokeWidth = 3;
      final lineProgress = ((progress - 0.2) / 0.8).clamp(0.0, 1.0);
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

class _MultiFramePainter extends CustomPainter {
  final double progress;

  _MultiFramePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw multiple frames
    for (int i = 0; i < 3; i++) {
      final frameProgress = ((progress - i * 0.2) / 0.6).clamp(0.0, 1.0);
      if (frameProgress > 0) {
        paint.color = Color(0xFF2196F3).withOpacity(0.3 + frameProgress * 0.7);
        final offset = i * 15.0;
        final rect = Rect.fromLTWH(
          size.width * 0.2 + offset,
          size.height * 0.2 + offset,
          size.width * 0.5,
          size.height * 0.5,
        );
        canvas.drawRect(rect, paint);
      }
    }

    // Averaging indicator
    if (progress > 0.8) {
      paint.style = PaintingStyle.fill;
      paint.color = const Color(0xFF4CAF50);
      canvas.drawCircle(
        Offset(size.width * 0.8, size.height * 0.3),
        8,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MultiFramePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
