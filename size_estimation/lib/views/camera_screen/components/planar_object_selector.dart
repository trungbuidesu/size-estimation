import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'package:size_estimation/services/planar_object_service.dart';

/// Widget for selecting 4 corners of a planar object
class PlanarObjectSelector extends StatefulWidget {
  final Size imageSize;
  final Function(List<vm.Vector2>)? onCornersSelected;
  final PlanarObjectMeasurement? measurement;
  final VoidCallback? onClear;
  final String? referenceObject; // e.g., "A4 Paper"

  const PlanarObjectSelector({
    super.key,
    required this.imageSize,
    this.onCornersSelected,
    this.measurement,
    this.onClear,
    this.referenceObject,
    // Removed showResult and onCloseResult as per requirement
  });

  @override
  State<PlanarObjectSelector> createState() => _PlanarObjectSelectorState();
}

class _PlanarObjectSelectorState extends State<PlanarObjectSelector> {
  final List<vm.Vector2> _corners = [];

  @override
  Widget build(BuildContext context) {
    // If measurement points are passed from parent (e.g. from state), sync them if local is empty
    // But typically this widget drives the selection.

    return Stack(
      children: [
        // Touch area for corner selection
        Positioned.fill(
          child: GestureDetector(
            onTapDown: (details) {
              if (_corners.length < 4) {
                setState(() {
                  _corners.add(vm.Vector2(
                    details.localPosition.dx,
                    details.localPosition.dy,
                  ));
                });

                // Notify when all 4 corners selected
                if (_corners.length == 4) {
                  widget.onCornersSelected?.call(_corners);
                }
              }
            },
            child: Container(color: Colors.transparent),
          ),
        ),

        // Draw corners and edges
        if (_corners.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CornersPainter(
                    corners: _corners, measurement: widget.measurement),
              ),
            ),
          ),

        // Instruction text
        if (_corners.length < 4)
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
                  child: Text(
                    _getInstructionText(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Reference object hint
        if (widget.referenceObject != null && _corners.isEmpty)
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Reference: ${widget.referenceObject}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Removed the Floating Result Overlay here.

        // Clear button
        if (_corners.isNotEmpty)
          Positioned(
            top: 20,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.red,
              onPressed: () {
                setState(() {
                  _corners.clear();
                });
                widget.onClear?.call();
              },
              child: const Icon(Icons.clear, color: Colors.white),
            ),
          ),
      ],
    );
  }

  String _getInstructionText() {
    switch (_corners.length) {
      case 0:
        return 'Tap top-left corner';
      case 1:
        return 'Tap top-right corner';
      case 2:
        return 'Tap bottom-right corner';
      case 3:
        return 'Tap bottom-left corner';
      case 4:
        return 'Done. Dimensions shown on edges.';
      default:
        return 'Processing...';
    }
  }
}

class _CornersPainter extends CustomPainter {
  final List<vm.Vector2> corners;
  final PlanarObjectMeasurement? measurement;

  _CornersPainter({required this.corners, this.measurement});

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = Colors.purpleAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = Colors.purple.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final pointPaint = Paint()..style = PaintingStyle.fill;

    final circlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw edges
    if (corners.length >= 2) {
      final path = Path();
      path.moveTo(corners[0].x, corners[0].y);
      for (int i = 1; i < corners.length; i++) {
        path.lineTo(corners[i].x, corners[i].y);
      }
      if (corners.length == 4) {
        path.close();
        canvas.drawPath(path, fillPaint);
      }
      canvas.drawPath(path, edgePaint);
    }

    // Draw corners
    final colors = [Colors.red, Colors.blue, Colors.green, Colors.orange];
    final labels = ['TL', 'TR', 'BR', 'BL'];

    for (int i = 0; i < corners.length; i++) {
      final corner = corners[i];

      // Draw filled circle
      pointPaint.color = colors[i];
      canvas.drawCircle(
        Offset(corner.x, corner.y),
        14,
        pointPaint,
      );

      // Draw white border
      canvas.drawCircle(
        Offset(corner.x, corner.y),
        14,
        circlePaint,
      );

      // Draw label
      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          corner.x - textPainter.width / 2,
          corner.y - textPainter.height / 2,
        ),
      );
    }

    // Draw Measurement Text on Edges/Services (New Logic)
    if (measurement != null && corners.length == 4) {
      final p0 = Offset(corners[0].x, corners[0].y);
      final p1 = Offset(corners[1].x, corners[1].y);
      final p2 = Offset(corners[2].x, corners[2].y);
      final p3 = Offset(corners[3].x, corners[3].y);

      // Top (0-1)
      _drawLabel(canvas, (p0 + p1) / 2,
          "${measurement!.widthCm.toStringAsFixed(1)} cm", Colors.blue);

      // Bottom (2-3)
      _drawLabel(canvas, (p2 + p3) / 2,
          "${measurement!.widthCm.toStringAsFixed(1)} cm", Colors.blue);

      // Right (1-2)
      _drawLabel(canvas, (p1 + p2) / 2,
          "${measurement!.heightCm.toStringAsFixed(1)} cm", Colors.green);

      // Left (3-0)
      _drawLabel(canvas, (p3 + p0) / 2,
          "${measurement!.heightCm.toStringAsFixed(1)} cm", Colors.green);

      // Area + Distance (Center)
      // Approximate center
      final center = (p0 + p2) / 2;
      _drawLabel(
          canvas,
          center,
          "Area: ${measurement!.areaCm2.toStringAsFixed(0)} cm²\nDistance: ${measurement!.distanceMeters.toStringAsFixed(2)} m\n± ${measurement!.estimatedError.toStringAsFixed(1)} cm",
          Colors.orange,
          fontSize: 16);
    }
  }

  void _drawLabel(Canvas canvas, Offset position, String text, Color color,
      {double fontSize = 14}) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black45),
    );
    final tp = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center);
    tp.layout();
    tp.paint(canvas, position - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_CornersPainter oldDelegate) {
    return oldDelegate.corners.length != corners.length ||
        oldDelegate.measurement != measurement;
  }
}
