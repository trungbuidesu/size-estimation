import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:size_estimation/constants/estimation_mode.dart';
import 'package:size_estimation/models/estimation_mode.dart';

class InformationScreen extends StatelessWidget {
  const InformationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'Hướng dẫn & Thông tin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    "Phương pháp đo lường",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tabbed Component
                  const MethodGuideTabs(),

                  // Placeholder for future content
                  const SizedBox(height: 32),
                  const Text(
                    "Thông tin thêm",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Center(
                      child: Text(
                        "Nội dung khác sẽ hiển thị ở đây...",
                        style: TextStyle(color: Colors.white38),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MethodGuideTabs extends StatefulWidget {
  const MethodGuideTabs({super.key});

  @override
  State<MethodGuideTabs> createState() => _MethodGuideTabsState();
}

class _MethodGuideTabsState extends State<MethodGuideTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: kEstimationModes.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Custom Tab Bar
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(20),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent,
            indicator: BoxDecoration(
              color: const Color(0xFF2196F3),
              borderRadius: BorderRadius.circular(20),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            padding: EdgeInsets.zero,
            tabs:
                kEstimationModes.map((mode) => Tab(text: mode.label)).toList(),
          ),
        ),

        const SizedBox(height: 24),

        // Tab View Content
        SizedBox(
          height: 380, // Increased height for animations
          child: TabBarView(
            controller: _tabController,
            children: kEstimationModes.map((mode) {
              return _buildTabContent(mode);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent(EstimationMode mode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(mode.icon, color: const Color(0xFF2196F3), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  mode.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            mode.description,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const Spacer(),
          // Mode Illustration
          ModeIllustration(type: mode.type),
        ],
      ),
    );
  }
}

// --- Illustration Widgets ---

class ModeIllustration extends StatefulWidget {
  final EstimationModeType type;
  const ModeIllustration({super.key, required this.type});

  @override
  State<ModeIllustration> createState() => _ModeIllustrationState();
}

class _ModeIllustrationState extends State<ModeIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
          ]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          painter:
              _IllustrationPainter(type: widget.type, animation: _controller),
        ),
      ),
    );
  }
}

class _IllustrationPainter extends CustomPainter {
  final EstimationModeType type;
  final Animation<double> animation;

  _IllustrationPainter({required this.type, required this.animation})
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final double t = animation.value;
    final Offset center = Offset(size.width / 2, size.height / 2);

    // Background Grid for techy feel (subtle)
    _drawBackgroundGrid(canvas, size);

    switch (type) {
      case EstimationModeType.groundPlane:
        _drawGroundPlane(canvas, size, center, t);
        break;
      case EstimationModeType.planarObject:
        _drawPlanarObject(canvas, size, center, t);
        break;
      case EstimationModeType.singleView:
        _drawSingleView(canvas, size, center, t);
        break;
      case EstimationModeType.multiFrame:
        _drawMultiFrame(canvas, size, center, t);
        break;
    }
  }

  void _drawBackgroundGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    const double step = 30;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawGroundPlane(Canvas canvas, Size size, Offset center, double t) {
    final paint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Logic: Draw a perspective grid that implies typical "Ground" view.
    // Animate a scanning line moving forward/backward.

    // Horizon Y
    final double horizonY = size.height * 0.3;
    final double bottomY = size.height * 0.9;

    // Vanishing Point
    final Offset vp = Offset(center.dx, horizonY);

    // Draw Perspective Lines
    paint.color = Colors.blueAccent.withOpacity(0.5);
    // Fan out lines
    for (int i = -4; i <= 4; i++) {
      double xBase = center.dx + (i * 40);
      canvas.drawLine(vp, Offset(xBase, bottomY), paint);
    }

    // Draw Horizontal Lines (closer lines are further apart)
    for (int i = 0; i < 5; i++) {
      double progress = i / 4;
      double y = horizonY + (bottomY - horizonY) * progress;
      double widthAtY =
          100 + (200 * progress); // simplified perspective width width
      canvas.drawLine(Offset(center.dx - widthAtY / 2, y),
          Offset(center.dx + widthAtY / 2, y), paint);
    }

    // Animated Scanning Box
    double scanT = (math.sin(t * 2 * math.pi) + 1) / 2; // 0..1 oscillate
    double scanY = horizonY + (bottomY - horizonY) * scanT;
    double scanWidth = 100 + (200 * scanT);
    double scanHeight = 20 * scanT;

    final Rect targetRect = Rect.fromCenter(
        center: Offset(center.dx, scanY),
        width: scanWidth * 0.4,
        height: scanHeight);

    // Target Highlight
    paint
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(targetRect, paint);

    // Crosshair
    canvas.drawLine(targetRect.topCenter, targetRect.bottomCenter, paint);
    canvas.drawLine(targetRect.centerLeft, targetRect.centerRight, paint);
  }

  void _drawPlanarObject(Canvas canvas, Size size, Offset center, double t) {
    // Logic: Morph a trapezoid (skewed object) into a rectangle (rectified).
    // t oscillates 0..1

    double easeT =
        0.5 - 0.5 * math.cos(t * 2 * math.pi); // Smooth Bell curve 0->1->0

    // Source: Trapezoid
    final Offset p1 = Offset(center.dx - 60, center.dy - 50);
    final Offset p2 =
        Offset(center.dx + 40, center.dy - 60); // Skewed top right
    final Offset p3 =
        Offset(center.dx + 70, center.dy + 40); // Skewed bot right
    final Offset p4 = Offset(center.dx - 50, center.dy + 70); // Skewed bot left

    // Target: Rectangle (Card)
    final Offset r1 = Offset(center.dx - 50, center.dy - 60);
    final Offset r2 = Offset(center.dx + 50, center.dy - 60);
    final Offset r3 = Offset(center.dx + 50, center.dy + 60);
    final Offset r4 = Offset(center.dx - 50, center.dy + 60);

    // Lerp
    Offset c1 = Offset.lerp(p1, r1, easeT)!;
    Offset c2 = Offset.lerp(p2, r2, easeT)!;
    Offset c3 = Offset.lerp(p3, r3, easeT)!;
    Offset c4 = Offset.lerp(p4, r4, easeT)!;

    final path = Path()
      ..moveTo(c1.dx, c1.dy)
      ..lineTo(c2.dx, c2.dy)
      ..lineTo(c3.dx, c3.dy)
      ..lineTo(c4.dx, c4.dy)
      ..close();

    // Draw Object
    final paint = Paint()
      ..color = Color.lerp(Colors.orangeAccent, Colors.blueAccent, easeT)!
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint..color = paint.color.withOpacity(0.3));

    canvas.drawPath(
        path,
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white);

    // Draw Corner Points
    paint.style = PaintingStyle.fill;
    paint.color = Colors.greenAccent;
    for (var p in [c1, c2, c3, c4]) {
      canvas.drawCircle(p, 4, paint);
    }
  }

  void _drawSingleView(Canvas canvas, Size size, Offset center, double t) {
    // Logic: Measure height of a building (box) relative to reference.

    final paint = Paint()..strokeWidth = 2;

    // Ground Line
    paint.color = Colors.white54;
    canvas.drawLine(Offset(center.dx - 80, center.dy + 60),
        Offset(center.dx + 80, center.dy + 60), paint);

    // The Object (Building)
    final Rect building =
        Rect.fromLTWH(center.dx - 20, center.dy - 40, 40, 100);
    paint.style = PaintingStyle.fill;
    paint.color = Colors.grey.shade800;
    canvas.drawRect(building, paint);
    paint.style = PaintingStyle.stroke;
    paint.color = Colors.white;
    canvas.drawRect(building, paint);

    // Reference Line (Static Stickman)
    paint.color = Colors.yellow;
    canvas.drawLine(Offset(center.dx - 50, center.dy + 60),
        Offset(center.dx - 50, center.dy + 10), paint); // Body
    canvas.drawCircle(Offset(center.dx - 50, center.dy + 5), 5,
        paint..style = PaintingStyle.stroke); // Head

    // Measurement Animation
    // Line growing up parallel to building
    double growT = (math.sin(t * 2 * math.pi - math.pi / 2) + 1) / 2; // 0..1
    double currentHeight = 100 * growT;

    paint.color = Colors.blueAccent;
    paint.strokeWidth = 4;
    double rulerX = center.dx + 40;
    Offset start = Offset(rulerX, center.dy + 60);
    Offset end = Offset(rulerX, center.dy + 60 - currentHeight);

    canvas.drawLine(start, end, paint);

    // Top and Bottom dashes
    paint.strokeWidth = 1;
    paint.color = Colors.blueAccent.withOpacity(0.5);
    canvas.drawLine(
        Offset(center.dx, center.dy + 60), start, paint); // Bottom projection
    canvas.drawLine(Offset(center.dx, center.dy + 60 - currentHeight), end,
        paint); // Top projection

    // Text bubble (Simulated)
    if (growT > 0.1) {
      final textP = TextPainter(
          text: TextSpan(
              text: "${(growT * 3).toStringAsFixed(1)}m",
              style: const TextStyle(
                  color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr);
      textP.layout();
      textP.paint(canvas, Offset(rulerX + 10, end.dy));
    }
  }

  void _drawMultiFrame(Canvas canvas, Size size, Offset center, double t) {
    // Logic: Object in center, cameras orbiting it.

    // Central Object (Cube-ish)
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white
      ..strokeWidth = 2;
    Rect box = Rect.fromCenter(center: center, width: 40, height: 40);
    canvas.drawRect(box, paint);
    canvas.drawLine(box.topLeft, box.bottomRight, paint);
    canvas.drawLine(box.topRight, box.bottomLeft, paint);

    // Orbiting Cameras
    double r = 60;
    int camCount = 3;
    for (int i = 0; i < camCount; i++) {
      double angle = (t * 2 * math.pi) + (i * (2 * math.pi / camCount));

      double cx = center.dx + r * math.cos(angle);
      double cy = center.dy +
          r * math.sin(angle) * 0.4; // Elliptical orbit (perspective)

      // Draw Camera Icon
      paint.color = Colors.greenAccent;
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), 8, paint);

      // Frustum lines to center
      paint.strokeWidth = 1;
      paint.color = Colors.greenAccent.withOpacity(0.3);
      canvas.drawLine(Offset(cx, cy), center, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _IllustrationPainter oldDelegate) {
    return true; // Repaint on every tick
  }
}
