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
  });

  @override
  State<PlanarObjectSelector> createState() => _PlanarObjectSelectorState();
}

class _PlanarObjectSelectorState extends State<PlanarObjectSelector> {
  final List<vm.Vector2> _corners = [];

  @override
  Widget build(BuildContext context) {
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
                painter: _CornersPainter(corners: _corners),
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
                  border: Border.all(color: Colors.purple, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Planar Object Dimensions',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildDimensionChip(
                          'Width',
                          '${widget.measurement!.widthCm.toStringAsFixed(1)} cm',
                          Colors.blue,
                        ),
                        _buildDimensionChip(
                          'Height',
                          '${widget.measurement!.heightCm.toStringAsFixed(1)} cm',
                          Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildDimensionChip(
                          'Area',
                          '${widget.measurement!.areaCm2.toStringAsFixed(1)} cm²',
                          Colors.orange,
                        ),
                        _buildDimensionChip(
                          'Ratio',
                          widget.measurement!.aspectRatio.toStringAsFixed(2),
                          Colors.purple,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '± ${widget.measurement!.estimatedError.toStringAsFixed(1)} cm',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

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
      default:
        return 'Processing...';
    }
  }

  Widget _buildDimensionChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _CornersPainter extends CustomPainter {
  final List<vm.Vector2> corners;

  _CornersPainter({required this.corners});

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
  }

  @override
  bool shouldRepaint(_CornersPainter oldDelegate) {
    return oldDelegate.corners.length != corners.length;
  }
}
