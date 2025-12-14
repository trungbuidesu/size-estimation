import 'package:flutter/material.dart';
import 'package:size_estimation/services/imu_service.dart';
import 'dart:math' as math;

class IMUOverlay extends StatelessWidget {
  final IMUOrientation? orientation;
  final VoidCallback onClose;

  const IMUOverlay({
    super.key,
    this.orientation,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = orientation != null;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.5), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.explore, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'IMU Orientation',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasData) ...[
            // Euler Angles
            _buildEulerAngles(),
            const SizedBox(height: 16),
            // 3D Orientation Visualizer
            _buildOrientationVisualizer(),
            const SizedBox(height: 16),
            // Rotation Matrix
            _buildRotationMatrix(),
            const SizedBox(height: 16),
            // Gravity Vector
            _buildGravityVector(),
            const SizedBox(height: 12),
            // Level Indicator
            _buildLevelIndicator(),
          ] else
            const Text(
              'No IMU data available',
              style:
                  TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }

  Widget _buildEulerAngles() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Euler Angles (ZYX)',
            style: TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          _buildAngleRow('Roll (X)', orientation!.rollDegrees, Colors.red),
          const SizedBox(height: 4),
          _buildAngleRow('Pitch (Y)', orientation!.pitchDegrees, Colors.green),
          const SizedBox(height: 4),
          _buildAngleRow('Yaw (Z)', orientation!.yawDegrees, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildAngleRow(String label, double degrees, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ((degrees + 180) / 360).clamp(0.0, 1.0),
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation(color.withOpacity(0.7)),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: Text(
                  '${degrees.toStringAsFixed(1)}°',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'Courier',
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrientationVisualizer() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: CustomPaint(
        painter: _OrientationPainter(orientation!),
        child: Container(),
      ),
    );
  }

  Widget _buildRotationMatrix() {
    final matrix = orientation!.getRotationMatrixAsList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'R =',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontFamily: 'Courier',
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMatrixRow(matrix[0]),
                _buildMatrixRow(matrix[1]),
                _buildMatrixRow(matrix[2]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixRow(List<double> row) {
    return Row(
      children: [
        const Text('[  ',
            style: TextStyle(color: Colors.white70, fontFamily: 'Courier')),
        ...row.map((val) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                width: 60,
                child: Text(
                  val.toStringAsFixed(3),
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontFamily: 'Courier',
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            )),
        const Text('  ]',
            style: TextStyle(color: Colors.white70, fontFamily: 'Courier')),
      ],
    );
  }

  Widget _buildGravityVector() {
    final g = orientation!.gravity;
    final magnitude = math.sqrt(g.x * g.x + g.y * g.y + g.z * g.z);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gravity Vector:',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '[${g.x.toStringAsFixed(2)}, ${g.y.toStringAsFixed(2)}, ${g.z.toStringAsFixed(2)}] m/s²',
          style: const TextStyle(
            color: Colors.purpleAccent,
            fontSize: 11,
            fontFamily: 'Courier',
          ),
        ),
        Text(
          'Magnitude: ${magnitude.toStringAsFixed(2)} m/s²',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildLevelIndicator() {
    final isLevel = orientation!.rollDegrees.abs() < 5 &&
        orientation!.pitchDegrees.abs() < 5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (isLevel ? Colors.green : Colors.orange).withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLevel ? Icons.check_circle : Icons.warning,
            size: 16,
            color: isLevel ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Text(
            isLevel ? 'Device is Level' : 'Device is Tilted',
            style: TextStyle(
              color: isLevel ? Colors.green : Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrientationPainter extends CustomPainter {
  final IMUOrientation orientation;

  _OrientationPainter(this.orientation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 3;

    // Draw horizon line (pitch indicator)
    final pitchOffset = orientation.pitchDegrees * 0.5;
    final horizonPaint = Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(center.dx - radius, center.dy + pitchOffset),
      Offset(center.dx + radius, center.dy + pitchOffset),
      horizonPaint,
    );

    // Draw roll indicator (rotating line)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(orientation.roll);

    final rollPaint = Paint()
      ..color = Colors.red.withOpacity(0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, -radius * 0.8),
      Offset(0, -radius * 0.5),
      rollPaint,
    );

    canvas.restore();

    // Draw center circle
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 4, centerPaint);

    // Draw outer circle
    final outerPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, outerPaint);

    // Draw yaw arrow
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(orientation.yaw);

    final yawPaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final arrowPath = Path()
      ..moveTo(0, -radius * 1.2)
      ..lineTo(-8, -radius * 1.1)
      ..moveTo(0, -radius * 1.2)
      ..lineTo(8, -radius * 1.1);

    canvas.drawLine(Offset(0, 0), Offset(0, -radius * 1.2), yawPaint);
    canvas.drawPath(arrowPath, yawPaint);

    canvas.restore();

    // Draw labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // North label
    textPainter.text = const TextSpan(
      text: 'N',
      style: TextStyle(color: Colors.white70, fontSize: 12),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - radius - 20),
    );
  }

  @override
  bool shouldRepaint(_OrientationPainter oldDelegate) {
    return oldDelegate.orientation != orientation;
  }
}
