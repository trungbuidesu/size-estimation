import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'package:size_estimation/services/vertical_object_service.dart';
import 'package:size_estimation/services/imu_service.dart';
import 'package:size_estimation/models/camera_metadata.dart';

class VerticalMeasureScreen extends StatefulWidget {
  final File imageFile;
  final IntrinsicMatrix kOut;
  final IMUOrientation orientation;
  final double cameraHeightMeters;
  final Size originalImageSize; // e.g. 1920x1080

  // Optional: Points selected on live preview (to be scaled to image coordinates)
  final vm.Vector2? initialTopPoint;
  final vm.Vector2? initialBottomPoint;
  final Size? previewSize; // Buffer Size for coordinate scaling
  final Size? kOutBaseSize; // Buffer Size for K matrix scaling

  const VerticalMeasureScreen({
    super.key,
    required this.imageFile,
    required this.kOut,
    required this.orientation,
    required this.cameraHeightMeters,
    required this.originalImageSize,
    this.initialTopPoint,
    this.initialBottomPoint,
    this.previewSize,
    this.kOutBaseSize,
  });

  @override
  State<VerticalMeasureScreen> createState() => _VerticalMeasureScreenState();
}

class _VerticalMeasureScreenState extends State<VerticalMeasureScreen> {
  final List<Offset> _points = [];
  VerticalObjectMeasurement? _measurement;
  final VerticalObjectService _service = VerticalObjectService();

  // Layout state for hit testing
  Rect? _imageRect;
  double _scale = 1.0;
  Offset _offset = Offset.zero;

  // Store scaled image coordinates from preview (if provided)
  vm.Vector2? _scaledTopPoint;
  vm.Vector2? _scaledBottomPoint;
  bool _initialPointsCalculated = false;

  @override
  void initState() {
    super.initState();

    // Calculate scaled image coordinates (but don't add to _points yet)
    if (widget.initialTopPoint != null &&
        widget.initialBottomPoint != null &&
        widget.previewSize != null) {
      // Scale factor from preview to captured image
      final scaleX = widget.originalImageSize.width / widget.previewSize!.width;
      final scaleY =
          widget.originalImageSize.height / widget.previewSize!.height;

      // Store scaled IMAGE coordinates
      _scaledTopPoint = vm.Vector2(
        widget.initialTopPoint!.x * scaleX,
        widget.initialTopPoint!.y * scaleY,
      );
      _scaledBottomPoint = vm.Vector2(
        widget.initialBottomPoint!.x * scaleX,
        widget.initialBottomPoint!.y * scaleY,
      );

      // Calculate measurement from scaled points immediately
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted && !_initialPointsCalculated) {
          _initialPointsCalculated = true;

          // Wait for layout to be ready (so _scale and _offset are calculated)
          await Future.delayed(const Duration(milliseconds: 100));

          if (!mounted) return;

          // Convert image coordinates to UI coordinates
          final uiTopPoint = Offset(
            _scaledTopPoint!.x * _scale + _offset.dx,
            _scaledTopPoint!.y * _scale + _offset.dy,
          );
          final uiBottomPoint = Offset(
            _scaledBottomPoint!.x * _scale + _offset.dx,
            _scaledBottomPoint!.y * _scale + _offset.dy,
          );

          // Add to UI points
          setState(() {
            _points.add(uiBottomPoint); // Bottom first
            _points.add(uiTopPoint); // Then top
          });

          // Calculate measurement
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
      if (_points.length < 2) {
        _points.add(localPosition);
        if (_points.length == 2) {
          _calculateMeasurement();
        }
      } else {
        // Replace nearest point
        int nearestIndex = -1;
        double minDist = double.infinity;
        for (int i = 0; i < _points.length; i++) {
          final d = (localPosition - _points[i]).distance;
          if (d < minDist) {
            minDist = d;
            nearestIndex = i;
          }
        }
        if (nearestIndex != -1 && minDist < 50) {
          _points[nearestIndex] = localPosition;
          _calculateMeasurement();
        }
      }
    });
  }

  void _clear() {
    setState(() {
      _points.clear();
      _measurement = null;
    });
  }

  Future<void> _calculateMeasurement() async {
    if (_points.length != 2) {
      _measurement = null;
      return;
    }

    // Map UI points to image coordinates
    final imgBottom = _mapToImageCoordinates(_points[0]);
    final imgTop = _mapToImageCoordinates(_points[1]);

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

      final m = await _service.measureHeight(
        topPixel: vm.Vector2(imgTop.dx, imgTop.dy),
        bottomPixel: vm.Vector2(imgBottom.dx, imgBottom.dy),
        kOut: usedK,
        orientation: widget.orientation,
        cameraHeightMeters: widget.cameraHeightMeters,
      );

      if (mounted) {
        setState(() {
          _measurement = m;
        });
      }
    } catch (e) {
      debugPrint("Measurement error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Measurement error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                    "Đo chiều cao vật thể",
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
                      onPanUpdate: (details) {
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
                              painter: _VerticalPainter(
                                points: _points,
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
                      onPressed: _points.isEmpty ? null : _clear,
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

class _VerticalPainter extends CustomPainter {
  final List<Offset> points;
  final VerticalObjectMeasurement? measurement;

  _VerticalPainter({required this.points, this.measurement});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.yellowAccent
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()..style = PaintingStyle.fill;

    // Draw Line
    if (points.length == 2) {
      canvas.drawLine(points[0], points[1], linePaint);
    }

    // Draw Points
    final colors = [Colors.blue, Colors.red]; // Bottom, Top
    final labels = ['Bottom', 'Top'];

    for (int i = 0; i < points.length; i++) {
      pointPaint.color = colors[i % 2];
      canvas.drawCircle(points[i], 12, pointPaint);
      canvas.drawCircle(
          points[i],
          12,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = Colors.white
            ..strokeWidth = 2);

      // Draw label
      _drawLabel(canvas, points[i], labels[i], colors[i % 2]);
    }

    // Draw Measurement
    if (measurement != null && points.length == 2) {
      // Draw height label at midpoint
      final midpoint = (points[0] + points[1]) / 2;
      _drawLabel(
        canvas,
        midpoint,
        "${measurement!.heightCm.toStringAsFixed(1)} cm\n± ${measurement!.estimatedError.toStringAsFixed(1)} cm",
        Colors.yellowAccent,
        fontSize: 16,
      );
    }
  }

  void _drawLabel(Canvas canvas, Offset position, String text, Color color,
      {double fontSize = 12}) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        backgroundColor: Colors.black45,
      ),
    );
    final tp = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    tp.layout();
    tp.paint(canvas, position - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _VerticalPainter oldDelegate) {
    return oldDelegate.points.length != points.length ||
        oldDelegate.measurement != measurement;
  }
}
