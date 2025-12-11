import 'dart:math';
import 'package:flutter/material.dart';

class CalibrationDescDialog extends StatelessWidget {
  final VoidCallback? onConfirm;

  const CalibrationDescDialog({super.key, this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.grid_on, color: Colors.blue),
          SizedBox(width: 8),
          Text('Hiệu chỉnh nâng cao', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            height: 180,
            width: double.maxFinite,
            child: CalibrationAnimation(),
          ),
          const SizedBox(height: 16),
          const Text(
            'Quy trình Custom Calibration (Dành cho Researcher):',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          _buildStep(
              Icons.looks_one, 'Sử dụng bảng Calibrate (Chessboard/Charuco).'),
          _buildStep(
              Icons.adb, 'Hệ thống tự động chạy thuật toán calibrateCamera.'),
          _buildStep(Icons.camera_alt,
              'Chụp 20-40 ảnh ở nhiều góc độ và khoảng cách khác nhau.'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onConfirm?.call();
          },
          child: const Text('Đã hiểu'),
        ),
      ],
    );
  }

  Widget _buildStep(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

class CalibrationAnimation extends StatefulWidget {
  const CalibrationAnimation({super.key});

  @override
  State<CalibrationAnimation> createState() => _CalibrationAnimationState();
}

class _CalibrationAnimationState extends State<CalibrationAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _OrbitPainter(_controller.value),
          child: Container(),
        );
      },
    );
  }
}

class _OrbitPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0

  _OrbitPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 3;

    // Draw Chessboard (Grid)
    final gridPaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw skewed grid to simulate 3D perspective occasionally?
    // Just a simple flat grid for clarity
    double gridSize = 40;
    double halfGrid = gridSize / 2;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    // Rotating board slightly
    canvas.rotate(sin(progress * 2 * pi) * 0.1);

    // Draw 4x4 squares
    for (int i = -2; i <= 2; i++) {
      canvas.drawLine(
          Offset(i * 10.0 - 20, -20), Offset(i * 10.0 - 20, 20), gridPaint);
      canvas.drawLine(
          Offset(-20, i * 10.0 - 20), Offset(20, i * 10.0 - 20), gridPaint);
    }

    // Fill checkerboard pattern (simplified)
    final fillPaint = Paint()..color = Colors.black87;
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 4; col++) {
        if ((row + col) % 2 == 0) {
          canvas.drawRect(
              Rect.fromLTWH((col - 2) * 10.0, (row - 2) * 10.0, 10, 10),
              fillPaint);
        }
      }
    }

    canvas.restore();

    // Draw Orbit Path
    final orbitPaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, orbitPaint);

    // Camera Position (Orbiting)
    double angle = progress * 2 * pi;
    // Add vertical bobbing to simulate "various angles"
    double bob = sin(progress * 4 * pi) * 10;

    double camX = center.dx + cos(angle) * radius;
    double camY =
        center.dy + sin(angle) * (radius * 0.4) + bob; // Elliptical orbit + bob

    // Draw Camera Icon
    final camPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(camX, camY), 8, camPaint);

    // Draw Flash
    // Flash every 0.25 progress (4 times per loop)
    if ((progress * 10).toInt() % 2 == 0) {
      // Simple flash logic
      final flashPaint = Paint()
        ..color = Colors.white.withOpacity(0.6)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(camX, camY), 12, flashPaint);
    }

    // Draw 'Field of View' cone pointing to center
    final fovPaint = Paint()
      ..color = Colors.blue.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    Path fovPath = Path();
    fovPath.moveTo(camX, camY);
    fovPath.lineTo(center.dx - 15, center.dy - 15);
    fovPath.lineTo(center.dx + 15, center.dy + 15);
    fovPath.close();
    canvas.drawPath(fovPath, fovPaint);

    // Count Text (Mock)
    // "20-40"
    int shotCount = (progress * 40).toInt();
    if (shotCount > 40) shotCount = 40;

    TextSpan span = TextSpan(
        style: const TextStyle(
            color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold),
        text: "$shotCount/40");
    TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, Offset(camX - 5, camY - 25));
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
