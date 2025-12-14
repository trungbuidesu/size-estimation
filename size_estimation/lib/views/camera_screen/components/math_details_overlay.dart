import 'package:flutter/material.dart';

class MathDetailsOverlay extends StatelessWidget {
  final String mode; // 'ground', 'planar', 'vertical'
  final VoidCallback onClose;

  const MathDetailsOverlay({
    Key? key,
    required this.mode,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 100,
      right: 20,
      left: 20,
      child: Material(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Math Details",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              _buildContent(mode),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(String mode) {
    switch (mode) {
      case 'ground':
        return _buildGroundPlaneMath();
      case 'planar':
        return _buildPlanarMath();
      case 'vertical':
        return _buildVerticalMath();
      default:
        return const Text("Select a measurement mode.",
            style: TextStyle(color: Colors.white70));
    }
  }

  Widget _buildGroundPlaneMath() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          "Model: Ground Plane (Pinhole + IMU)",
          style:
              TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(
          "Distance d is derived from camera height h and pitch angle \u03B8:",
          style: TextStyle(color: Colors.white70),
        ),
        SizedBox(height: 8),
        Text(
          "d = h / tan(\u03B8 + \u03B1)",
          style: TextStyle(
            color: Colors.yellowAccent,
            fontFamily: 'Courier',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Text(
            "- h: Camera height (Device)\n- \u03B8: Device Pitch (IMU)\n- \u03B1: Angular offset of pixel (y - cy)/fy",
            style: TextStyle(color: Colors.white60)),
      ],
    );
  }

  Widget _buildPlanarMath() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          "Model: Planar Object (Homography)",
          style:
              TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(
          "Rectifies the object plane to a fronto-parallel view using 4 corners.",
          style: TextStyle(color: Colors.white70),
        ),
        SizedBox(height: 8),
        Text(
          "x' = H \u00B7 x",
          style: TextStyle(
            color: Colors.yellowAccent,
            fontFamily: 'Courier',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Text("Dimension L = ||p1' - p2'|| \u00B7 s",
            style: TextStyle(
                color: Colors.yellowAccent,
                fontFamily: 'Courier',
                fontSize: 16)),
        SizedBox(height: 8),
        Text(
            "- H: Homography Matrix\n- s: Scale factor (Z / f)\n- Z: Distance to object",
            style: TextStyle(color: Colors.white60)),
      ],
    );
  }

  Widget _buildVerticalMath() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          "Model: Single View Metrology",
          style:
              TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(
          "Height H is computed from distance d and pixel coordinates:",
          style: TextStyle(color: Colors.white70),
        ),
        SizedBox(height: 8),
        Text(
          "H = d \u00B7 (y_top - y_bottom) / f_y",
          style: TextStyle(
            color: Colors.yellowAccent,
            fontFamily: 'Courier',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Text(
            "- d: Distance to object base (via Ground Plane)\n- f_y: Focal length (Vertical)\n- y: Normalized pixel coordinate",
            style: TextStyle(color: Colors.white60)),
      ],
    );
  }
}
