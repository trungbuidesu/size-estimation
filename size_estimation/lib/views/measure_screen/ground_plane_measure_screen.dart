import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'package:size_estimation/services/ground_plane_service.dart';
import 'package:size_estimation/services/imu_service.dart';
import 'package:size_estimation/models/camera_metadata.dart';

class GroundPlaneMeasureScreen extends StatefulWidget {
  final File imageFile;
  final IntrinsicMatrix kOut;
  final IMUOrientation orientation;
  final double cameraHeightMeters;
  final Size originalImageSize; // e.g. 1920x1080

  // Optional: Points selected on live preview (to be scaled to image coordinates)
  final vm.Vector2? initialPointA;
  final vm.Vector2? initialPointB;
  final Size? previewSize; // UI Size for UI coordinate scaling
  final Size? kOutBaseSize; // Buffer Size for K matrix scaling

  const GroundPlaneMeasureScreen({
    super.key,
    required this.imageFile,
    required this.kOut,
    required this.orientation,
    required this.cameraHeightMeters,
    required this.originalImageSize,
    this.initialPointA,
    this.initialPointB,
    this.previewSize,
    this.kOutBaseSize,
  });

  @override
  State<GroundPlaneMeasureScreen> createState() =>
      _GroundPlaneMeasureScreenState();
}

class _GroundPlaneMeasureScreenState extends State<GroundPlaneMeasureScreen> {
  final List<Offset> _points = [];
  final List<GroundPlaneMeasurement> _measurements = [];
  final GroundPlaneService _service = GroundPlaneService();

  // Layout state for hit testing
  Rect? _imageRect;

  // Store scaled image coordinates from preview (if provided)
  vm.Vector2? _scaledPointA;
  vm.Vector2? _scaledPointB;
  bool _initialPointsCalculated = false;

  @override
  void initState() {
    super.initState();

    // Calculate scaled image coordinates (but don't add to _points yet)
    if (widget.initialPointA != null &&
        widget.initialPointB != null &&
        widget.previewSize != null) {
      // Scale factor from preview to captured image
      final scaleX = widget.originalImageSize.width / widget.previewSize!.width;
      final scaleY =
          widget.originalImageSize.height / widget.previewSize!.height;

      // Store scaled IMAGE coordinates
      _scaledPointA = vm.Vector2(
        widget.initialPointA!.x * scaleX,
        widget.initialPointA!.y * scaleY,
      );
      _scaledPointB = vm.Vector2(
        widget.initialPointB!.x * scaleX,
        widget.initialPointB!.y * scaleY,
      );

      // Calculate measurement from scaled points immediately
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted && !_initialPointsCalculated) {
          _initialPointsCalculated = true;

          // Wait for layout to be ready (so _scale and _offset are calculated)
          await Future.delayed(const Duration(milliseconds: 100));

          if (!mounted) return;

          // Convert image coordinates to UI coordinates
          final uiPointA = Offset(
            _scaledPointA!.x * _scale + _offset.dx,
            _scaledPointA!.y * _scale + _offset.dy,
          );
          final uiPointB = Offset(
            _scaledPointB!.x * _scale + _offset.dx,
            _scaledPointB!.y * _scale + _offset.dy,
          );

          // Add to UI points
          setState(() {
            _points.add(uiPointA);
            _points.add(uiPointB);
          });

          // Calculate measurement
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

            final m = await _service.measureDistance(
              imagePointA: _scaledPointA!,
              imagePointB: _scaledPointB!,
              kOut: usedK,
              orientation: widget.orientation,
              cameraHeightMeters: widget.cameraHeightMeters,
              imageWidth: widget.originalImageSize.width.toInt(),
              imageHeight: widget.originalImageSize.height.toInt(),
            );
            if (mounted) {
              setState(() {
                _measurements.add(m);
              });
            }
          } catch (e) {
            debugPrint("Initial measurement error: $e");
          }
        }
      });
    }
  }

  void _addPoint(Offset localPosition) {
    // Validate point is within actual image bounds
    if (_imageRect != null && !_imageRect!.contains(localPosition)) {
      return;
    }

    setState(() {
      _points.add(localPosition);
      _calculateMeasurements();
    });
  }

  void _undo() {
    if (_points.isNotEmpty) {
      setState(() {
        _points.removeLast();
        _calculateMeasurements();
      });
    }
  }

  void _clear() {
    setState(() {
      _points.clear();
      _measurements.clear();
    });
  }

  // Layout parameters for coordinate mapping
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  Size _layoutSize = Size.zero;

  Future<void> _calculateMeasurements() async {
    _measurements.clear();
    if (_points.length < 2) return;

    // We need to map UI points back to Image coordinates (pixels)
    // Formula: ImageX = (UiX - OffsetX) / Scale

    for (int i = 0; i < _points.length - 1; i++) {
      final uiP1 = _points[i];
      final uiP2 = _points[i + 1];

      final imgP1 = _mapToImageCoordinates(uiP1);
      final imgP2 = _mapToImageCoordinates(uiP2);

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

        final m = await _service.measureDistance(
          imagePointA: vm.Vector2(imgP1.dx, imgP1.dy),
          imagePointB: vm.Vector2(imgP2.dx, imgP2.dy),
          kOut: usedK,
          orientation: widget.orientation,
          cameraHeightMeters: widget.cameraHeightMeters,
          imageWidth: widget.originalImageSize.width.toInt(),
          imageHeight: widget.originalImageSize.height.toInt(),
        );
        _measurements.add(m);
      } catch (e) {
        debugPrint("Measurement error: $e");
      }
    }
    setState(() {}); // specific update for measurements if async delay
  }

  Offset _mapToImageCoordinates(Offset uiPoint) {
    // Assuming BoxFit.contain centered:
    // image is drawn at _offset with size (original.width * scale, original.height * scale)
    // relative point = (uiPoint - _offset)
    // original point = relative / scale
    return (uiPoint - _offset) / _scale;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // Use Column to respect vertical space of toolbars
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back,
                        color: theme.colorScheme.onSurface),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Đo khoảng cách (Mặt phẳng)",
                    style: theme.textTheme.titleMedium,
                  )
                ],
              ),
            ),

            // 2. Image Area (Expanded to fill remaining space)
            Expanded(
              child: Container(
                color: Colors.black, // Dark background for letterboxing
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate the display rectangle for BoxFit.contain
                    final double aspectParams = widget.originalImageSize.width /
                        widget.originalImageSize.height;
                    final double aspectConstraints =
                        constraints.maxWidth / constraints.maxHeight;

                    double displayWidth, displayHeight;
                    double offsetX, offsetY;

                    if (aspectParams > aspectConstraints) {
                      // Constrained by width
                      displayWidth = constraints.maxWidth;
                      displayHeight = displayWidth / aspectParams;
                      offsetX = 0;
                      offsetY = (constraints.maxHeight - displayHeight) / 2;
                    } else {
                      // Constrained by height
                      displayHeight = constraints.maxHeight;
                      displayWidth = displayHeight * aspectParams;
                      offsetX = (constraints.maxWidth - displayWidth) / 2;
                      offsetY = 0;
                    }

                    // Store layout parameters for pointer mapping
                    _scale = displayWidth / widget.originalImageSize.width;
                    _offset = Offset(offsetX, offsetY);
                    _imageRect = Rect.fromLTWH(
                        offsetX, offsetY, displayWidth, displayHeight);

                    return GestureDetector(
                      onTapUp: (details) => _addPoint(details.localPosition),
                      child: Stack(
                        children: [
                          // Centered Image
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
                          // Overlay Painting (Full Space)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _MeasurePainter(
                                points: _points,
                                measurements: _measurements,
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

            // 3. Bottom Control Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              color: theme.colorScheme.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.undo),
                      label: const Text("Hoàn tác"),
                      onPressed: _points.isEmpty ? null : _undo,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: const Text("Xóa hết"),
                      onPressed: _points.isEmpty ? null : _clear,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
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

class _MeasurePainter extends CustomPainter {
  final List<Offset> points;
  final List<GroundPlaneMeasurement> measurements;

  _MeasurePainter({required this.points, required this.measurements});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final pointFillPaint = Paint()..style = PaintingStyle.fill;

    final pointBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Draw Lines
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      canvas.drawLine(p1, p2, linePaint);
    }

    // Draw Points with Labels
    for (int i = 0; i < points.length; i++) {
      final p = points[i];

      // Style: Cycle colors
      _setPointColor(pointFillPaint, i);

      // Draw Circle
      canvas.drawCircle(p, 12, pointFillPaint);
      canvas.drawCircle(p, 12, pointBorderPaint);

      // Draw Label (A, B, C...)
      // Standard ASCII: 'A' is 65
      String label = String.fromCharCode(65 + (i % 26));
      if (i >= 26) label += "${i ~/ 26}"; // A1, B1 support

      _drawLabel(canvas, p, label);
    }

    // Draw Measurement Labels (Distances)
    for (int i = 0; i < measurements.length; i++) {
      if (i >= points.length - 1) break;
      final p1 = points[i];
      final p2 = points[i + 1];
      final mid = (p1 + p2) / 2;

      final m = measurements[i];
      _drawDistanceTag(canvas, mid, "${m.distanceCm.toStringAsFixed(1)} cm");
    }
  }

  void _setPointColor(Paint paint, int index) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];
    paint.color = colors[index % colors.length];
  }

  void _drawLabel(Canvas canvas, Offset center, String text) {
    final textSpan = TextSpan(
      text: text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
    final tp = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawDistanceTag(Canvas canvas, Offset center, String text) {
    final textSpan = TextSpan(
      text: text,
      style: const TextStyle(
        color: Colors.greenAccent, // Match result text style
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
    final tp = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    tp.layout();

    // Background Pill
    final bgRect = Rect.fromCenter(
        center: center, width: tp.width + 16, height: tp.height + 8);
    final bgPaint = Paint()
      ..color = Colors.black.withOpacity(0.8)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.green // Match border style
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rrect = RRect.fromRectAndRadius(bgRect, const Radius.circular(8));
    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(rrect, borderPaint);

    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _MeasurePainter oldDelegate) {
    return oldDelegate.points.length != points.length ||
        oldDelegate.measurements.length != measurements.length;
  }
}
