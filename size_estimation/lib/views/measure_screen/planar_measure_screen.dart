import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'package:size_estimation/services/planar_object_service.dart';
import 'package:size_estimation/models/camera_metadata.dart';
import 'package:size_estimation/services/imu_service.dart';

class PlanarMeasureScreen extends StatefulWidget {
  final File imageFile;
  final IntrinsicMatrix kOut;
  final Size? kOutBaseSize; // Buffer Size for K matrix scaling
  final Size originalImageSize; // e.g. 1920x1080

  // Optional: Points selected on live preview (to be scaled to image coordinates)
  final List<vm.Vector2>? initialCorners;
  final Size? previewSize; // UI Size for UI coordinate scaling
  final String? referenceObject;
  final double planarDistanceMeters; // Distance to planar object

  const PlanarMeasureScreen({
    super.key,
    required this.imageFile,
    required this.kOut,
    required this.originalImageSize,
    required this.planarDistanceMeters,
    this.kOutBaseSize,
    this.initialCorners,
    this.previewSize,
    this.referenceObject,
  });

  @override
  State<PlanarMeasureScreen> createState() => _PlanarMeasureScreenState();
}

class _PlanarMeasureScreenState extends State<PlanarMeasureScreen> {
  final List<Offset> _corners = [];
  PlanarObjectMeasurement? _measurement;
  final PlanarObjectService _service = PlanarObjectService();

  // Layout state for hit testing
  Rect? _imageRect;
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  bool _initialPointsCalculated = false;

  @override
  void initState() {
    super.initState();

    // Calculate scaled image coordinates
    if (widget.initialCorners != null &&
        widget.initialCorners!.length == 4 &&
        widget.previewSize != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted && !_initialPointsCalculated) {
          // Wait for layout to be ready (so _scale and _offset are calculated)
          await Future.delayed(const Duration(milliseconds: 100));
          if (!mounted) return;

          _initialPointsCalculated = true;

          final scaleX =
              widget.originalImageSize.width / widget.previewSize!.width;
          final scaleY =
              widget.originalImageSize.height / widget.previewSize!.height;

          // Convert UI coordinates from Preview -> UI coordinates in Measure Screen
          // Preview UI -> Original Image -> Measure Screen UI

          final localCorners = <Offset>[];

          for (final corner in widget.initialCorners!) {
            // 1. To Image Coordinates
            final imgX = corner.x * scaleX;
            final imgY = corner.y * scaleY;

            // 2. To Measure Screen UI Coordinates
            final uiX = imgX * _scale + _offset.dx;
            final uiY = imgY * _scale + _offset.dy;

            localCorners.add(Offset(uiX, uiY));
          }

          setState(() {
            _corners.addAll(localCorners);
          });

          _calculateMeasurement();
        }
      });
    }
  }

  void _addPoint(Offset localPosition) {
    if (_imageRect != null && !_imageRect!.contains(localPosition)) {
      return;
    }

    setState(() {
      if (_corners.length < 4) {
        _corners.add(localPosition);
        if (_corners.length == 4) {
          _calculateMeasurement();
        }
      } else {
        // Simple logic: replace nearest corner?
        // Or just clear and restart?
        // For now, let's say "Clear" explicitly if they want to redo.
        // Or drag logic (complicated to implement quickly).
        // Let's implement nearest replacement for better UX
        int nearestIndex = -1;
        double minDist = double.infinity;
        for (int i = 0; i < _corners.length; i++) {
          final d = (localPosition - _corners[i]).distance;
          if (d < minDist) {
            minDist = d;
            nearestIndex = i;
          }
        }
        if (nearestIndex != -1 && minDist < 50) {
          // Threshold
          _corners[nearestIndex] = localPosition;
          _calculateMeasurement();
        }
      }
    });
  }

  void _clear() {
    setState(() {
      _corners.clear();
      _measurement = null;
    });
  }

  Future<void> _calculateMeasurement() async {
    if (_corners.length != 4) {
      _measurement = null;
      return;
    }

    final imgCorners = _corners.map((c) => _mapToImageCoordinates(c)).toList();
    final vectorCorners =
        imgCorners.map((c) => vm.Vector2(c.dx, c.dy)).toList();

    try {
      // SCALING K Matrix
      IntrinsicMatrix usedK = widget.kOut;
      if (widget.kOutBaseSize != null) {
        final kScaleX =
            widget.originalImageSize.width / widget.kOutBaseSize!.width;
        final kScaleY =
            widget.originalImageSize.height / widget.kOutBaseSize!.height;
        usedK = widget.kOut.copyWith(
          fx: widget.kOut.fx * kScaleX,
          fy: widget.kOut.fy * kScaleY,
          cx: widget.kOut.cx * kScaleX,
          cy: widget.kOut.cy * kScaleY,
        );
      }

      final m = await _service.measureObject(
        corners: vectorCorners,
        kOut: usedK,
        distanceMeters: widget.planarDistanceMeters,
        // Passing reference size logic if we had it, currently simplified
      );

      if (mounted) {
        setState(() {
          _measurement = m;
        });
      }
    } catch (e) {
      debugPrint("Measurement error: $e");
    }
  }

  Offset _mapToImageCoordinates(Offset uiPoint) {
    return (uiPoint - _offset) / _scale;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Đo vật thể mặt phẳng",
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: Colors.white),
                  )
                ],
              ),
            ),

            // Image Area
            Expanded(
              child: Container(
                color: Colors.black,
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double aspectParams = widget.originalImageSize.width /
                        widget.originalImageSize.height;
                    final double aspectConstraints =
                        constraints.maxWidth / constraints.maxHeight;

                    double displayWidth, displayHeight;
                    double offsetX, offsetY;

                    if (aspectParams > aspectConstraints) {
                      displayWidth = constraints.maxWidth;
                      displayHeight = displayWidth / aspectParams;
                      offsetX = 0;
                      offsetY = (constraints.maxHeight - displayHeight) / 2;
                    } else {
                      displayHeight = constraints.maxHeight;
                      displayWidth = displayHeight * aspectParams;
                      offsetX = (constraints.maxWidth - displayWidth) / 2;
                      offsetY = 0;
                    }

                    _scale = displayWidth / widget.originalImageSize.width;
                    _offset = Offset(offsetX, offsetY);
                    _imageRect = Rect.fromLTWH(
                        offsetX, offsetY, displayWidth, displayHeight);

                    return GestureDetector(
                      onTapUp: (details) => _addPoint(details.localPosition),
                      // Drag implementation could be added here
                      onPanUpdate: (details) {
                        // Simple drag logic for nearest point
                        _addPoint(details.localPosition);
                      },
                      child: Stack(
                        children: [
                          Positioned(
                            left: offsetX,
                            top: offsetY,
                            width: displayWidth,
                            height: displayHeight,
                            child: Image.file(
                              widget.imageFile,
                              fit: BoxFit.contain,
                            ),
                          ),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _PlanarPainter(
                                corners: _corners,
                                measurement: _measurement,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // Bottom Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              color: Colors.black,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: const Text("Xóa / Chọn lại"),
                      onPressed: _corners.isEmpty ? null : _clear,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanarPainter extends CustomPainter {
  final List<Offset> corners;
  final PlanarObjectMeasurement? measurement;

  _PlanarPainter({required this.corners, this.measurement});

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = Colors.purpleAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()..style = PaintingStyle.fill;

    // Draw Polygon
    if (corners.length > 1) {
      final path = Path();
      path.moveTo(corners[0].dx, corners[0].dy);
      for (int i = 1; i < corners.length; i++) {
        path.lineTo(corners[i].dx, corners[i].dy);
      }
      if (corners.length == 4) path.close();
      canvas.drawPath(path, edgePaint);
    }

    // Draw Corners
    final colors = [Colors.red, Colors.blue, Colors.green, Colors.orange];
    for (int i = 0; i < corners.length; i++) {
      pointPaint.color = colors[i % 4];
      canvas.drawCircle(corners[i], 12, pointPaint);
      canvas.drawCircle(
          corners[i],
          12,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = Colors.white
            ..strokeWidth = 2);
    }

    // Draw Measurement
    if (measurement != null && corners.length == 4) {
      // Draw Dimensions on Edges
      // Top (0-1), Right (1-2), Bottom (2-3), Left (3-0)

      final p0 = corners[0];
      final p1 = corners[1];
      final p2 = corners[2];
      final p3 = corners[3];

      // Top (0-1) - Width
      _drawLabel(canvas, (p0 + p1) / 2,
          "${measurement!.widthCm.toStringAsFixed(1)} cm", Colors.blue);

      // Right (1-2) - Height
      _drawLabel(canvas, (p1 + p2) / 2,
          "${measurement!.heightCm.toStringAsFixed(1)} cm", Colors.green);

      // Bottom (2-3) - Width
      _drawLabel(canvas, (p2 + p3) / 2,
          "${measurement!.widthCm.toStringAsFixed(1)} cm", Colors.blue);

      // Left (3-0) - Height
      _drawLabel(canvas, (p3 + p0) / 2,
          "${measurement!.heightCm.toStringAsFixed(1)} cm", Colors.green);

      // Center Text (Area + Distance)
      final center = (p0 + p2) / 2; // Approx
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
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, position - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _PlanarPainter oldDelegate) {
    return oldDelegate.corners.length != corners.length ||
        oldDelegate.measurement != measurement;
  }
}
