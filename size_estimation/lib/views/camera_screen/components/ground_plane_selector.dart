import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'package:size_estimation/services/ground_plane_service.dart';

/// Widget for selecting two points on ground plane and measuring distance
class GroundPlaneSelector extends StatefulWidget {
  final Size imageSize;
  final Function(vm.Vector2, vm.Vector2)? onPointsSelected;
  final GroundPlaneMeasurement? measurement;
  final VoidCallback? onClear;

  const GroundPlaneSelector({
    super.key,
    required this.imageSize,
    this.onPointsSelected,
    this.measurement,
    this.onClear,
  });

  @override
  State<GroundPlaneSelector> createState() => _GroundPlaneSelectorState();
}

class _GroundPlaneSelectorState extends State<GroundPlaneSelector> {
  vm.Vector2? _pointA;
  vm.Vector2? _pointB;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Touch area for point selection
        Positioned.fill(
          child: GestureDetector(
            onTapDown: (details) {
              final localPosition = details.localPosition;

              if (_pointA == null) {
                setState(() {
                  _pointA = vm.Vector2(localPosition.dx, localPosition.dy);
                });
              } else if (_pointB == null) {
                setState(() {
                  _pointB = vm.Vector2(localPosition.dx, localPosition.dy);
                });

                // Notify parent
                if (_pointA != null && _pointB != null) {
                  widget.onPointsSelected?.call(_pointA!, _pointB!);
                }
              }
            },
            child: Container(color: Colors.transparent),
          ),
        ),

        // Draw points and line
        if (_pointA != null || _pointB != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _PointsPainter(
                  pointA: _pointA,
                  pointB: _pointB,
                ),
              ),
            ),
          ),

        // Instruction text
        if (_pointA == null)
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Tap to select first point (A)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),

        if (_pointA != null && _pointB == null)
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Tap to select second point (B)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Measurement result
        if (widget.measurement != null)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Ground Plane Distance',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.measurement!.distanceCm.toStringAsFixed(1)} cm',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '± ${widget.measurement!.estimatedError.toStringAsFixed(1)} cm',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildInfoChip(
                          'Height',
                          '${widget.measurement!.cameraHeightMeters.toStringAsFixed(2)} m',
                        ),
                        _buildInfoChip(
                          'Distance',
                          '${widget.measurement!.distanceMeters.toStringAsFixed(2)} m',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Clear button
        if (_pointA != null || _pointB != null)
          Positioned(
            top: 20,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.red,
              onPressed: () {
                setState(() {
                  _pointA = null;
                  _pointB = null;
                });
                widget.onClear?.call();
              },
              child: const Icon(Icons.clear, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _PointsPainter extends CustomPainter {
  final vm.Vector2? pointA;
  final vm.Vector2? pointB;

  _PointsPainter({this.pointA, this.pointB});

  @override
  void paint(Canvas canvas, Size size) {
    final pointPaint = Paint()..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final circlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw line between points
    if (pointA != null && pointB != null) {
      canvas.drawLine(
        Offset(pointA!.x, pointA!.y),
        Offset(pointB!.x, pointB!.y),
        linePaint,
      );
    }

    // Draw point A
    if (pointA != null) {
      pointPaint.color = Colors.red;
      canvas.drawCircle(
        Offset(pointA!.x, pointA!.y),
        12,
        pointPaint,
      );
      canvas.drawCircle(
        Offset(pointA!.x, pointA!.y),
        12,
        circlePaint,
      );

      // Label A
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'A',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(pointA!.x - textPainter.width / 2,
            pointA!.y - textPainter.height / 2),
      );
    }

    // Draw point B
    if (pointB != null) {
      pointPaint.color = Colors.blue;
      canvas.drawCircle(
        Offset(pointB!.x, pointB!.y),
        12,
        pointPaint,
      );
      canvas.drawCircle(
        Offset(pointB!.x, pointB!.y),
        12,
        circlePaint,
      );

      // Label B
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'B',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(pointB!.x - textPainter.width / 2,
            pointB!.y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_PointsPainter oldDelegate) {
    return oldDelegate.pointA != pointA || oldDelegate.pointB != pointB;
  }
}
