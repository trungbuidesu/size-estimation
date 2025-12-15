import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'package:size_estimation/services/vertical_object_service.dart';

/// Widget for selecting Bottom and Top points for Height Measurement
class VerticalObjectSelector extends StatefulWidget {
  final Size imageSize;
  final Function(vm.Vector2, vm.Vector2)? onPointsSelected;
  final VerticalObjectMeasurement? measurement;
  final VoidCallback? onClear;

  const VerticalObjectSelector({
    super.key,
    required this.imageSize,
    this.onPointsSelected,
    this.measurement,
    this.onClear,
  });

  @override
  State<VerticalObjectSelector> createState() => _VerticalObjectSelectorState();
}

class _VerticalObjectSelectorState extends State<VerticalObjectSelector> {
  vm.Vector2? _topPoint;
  vm.Vector2? _bottomPoint;
  bool _selectingBottom = true; // Start by selecting bottom (base)

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Touch area
        Positioned.fill(
          child: GestureDetector(
            onTapDown: (details) {
              final pos = vm.Vector2(
                  details.localPosition.dx, details.localPosition.dy);

              setState(() {
                if (_bottomPoint == null) {
                  _bottomPoint = pos;
                  _selectingBottom = false; // Next select top
                } else if (_topPoint == null) {
                  _topPoint = pos;
                  _selectingBottom = true; // Reset sequence or done

                  // Trigger measurement
                  if (_bottomPoint != null) {
                    widget.onPointsSelected?.call(_topPoint!, _bottomPoint!);
                  }
                }
              });
            },
            child: Container(color: Colors.transparent),
          ),
        ),

        // Painting
        if (_topPoint != null || _bottomPoint != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _VerticalPainter(
                  top: _topPoint,
                  bottom: _bottomPoint,
                ),
              ),
            ),
          ),

        // Instructions
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
                  _getInstruction(),
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

        // Results
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
                  border: Border.all(color: Colors.yellowAccent, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Object Height',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.measurement!.heightCm.toStringAsFixed(1)} cm',
                      style: const TextStyle(
                        color: Colors.yellowAccent,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '± ${widget.measurement!.estimatedError.toStringAsFixed(1)} cm',
                      style:
                          const TextStyle(color: Colors.orange, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Distance: ${widget.measurement!.distanceToBottomMeters.toStringAsFixed(2)} m',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Clear button
        if (_bottomPoint != null)
          Positioned(
            top: 20,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.red,
              onPressed: () {
                setState(() {
                  _bottomPoint = null;
                  _topPoint = null;
                  _selectingBottom = true;
                });
                widget.onClear?.call();
              },
              child: const Icon(Icons.clear, color: Colors.white),
            ),
          ),
      ],
    );
  }

  String _getInstruction() {
    if (widget.measurement != null) return 'Measurement Complete';
    if (_bottomPoint == null) return '1. Tap BOTTOM (Base at ground)';
    if (_topPoint == null) return '2. Tap TOP of object';
    return 'Processing...';
  }
}

class _VerticalPainter extends CustomPainter {
  final vm.Vector2? top;
  final vm.Vector2? bottom;

  _VerticalPainter({this.top, this.bottom});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.yellowAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    if (bottom != null) {
      // Draw Bottom Point
      canvas.drawCircle(
          Offset(bottom!.x, bottom!.y), 8, dotPaint..color = Colors.blue);
      canvas.drawCircle(Offset(bottom!.x, bottom!.y), 8, borderPaint);

      _drawLabel(canvas, bottom!, 'Bottom', Colors.blue);
    }

    if (top != null) {
      // Draw Top Point
      canvas.drawCircle(
          Offset(top!.x, top!.y), 8, dotPaint..color = Colors.red);
      canvas.drawCircle(Offset(top!.x, top!.y), 8, borderPaint);

      _drawLabel(canvas, top!, 'Top', Colors.red);
    }

    if (top != null && bottom != null) {
      // Draw Line
      canvas.drawLine(
          Offset(bottom!.x, bottom!.y), Offset(top!.x, top!.y), linePaint);
    }
  }

  void _drawLabel(Canvas canvas, vm.Vector2 pos, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          shadows: const [Shadow(blurRadius: 2, color: Colors.black)],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(pos.x + 12, pos.y - tp.height / 2));
  }

  @override
  bool shouldRepaint(_VerticalPainter oldDelegate) {
    return oldDelegate.top != top || oldDelegate.bottom != bottom;
  }
}
