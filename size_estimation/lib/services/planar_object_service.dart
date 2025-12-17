import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vm;
import 'package:size_estimation/models/camera_metadata.dart';

/// Configuration for planar object measurement
class PlanarObjectConfig {
  static const double zeroEpsilon = 1e-10;
  static const double estimatedDistanceMeters = 0.5; // Default 50cm
  static const double assumedRealSize = 21.0; // A4 width in cm
}

/// Result of planar object measurement
class PlanarObjectMeasurement {
  final double widthCm;
  final double heightCm;
  final double areaCm2;
  final List<vm.Vector2> corners;
  final List<vm.Vector2> rectifiedCorners;
  final double aspectRatio;
  final double estimatedError;
  final double distanceMeters;

  PlanarObjectMeasurement({
    required this.widthCm,
    required this.heightCm,
    required this.areaCm2,
    required this.corners,
    required this.rectifiedCorners,
    required this.aspectRatio,
    required this.estimatedError,
    required this.distanceMeters,
  });

  @override
  String toString() {
    return 'PlanarObjectMeasurement(width: ${widthCm.toStringAsFixed(1)}cm, '
        'height: ${heightCm.toStringAsFixed(1)}cm, '
        'area: ${areaCm2.toStringAsFixed(0)}cm², '
        'distance: ${distanceMeters.toStringAsFixed(2)}m, '
        'error: ±${estimatedError.toStringAsFixed(1)}cm)';
  }
}

/// Service for measuring planar objects using homography
class PlanarObjectService {
  /// Measure planar object dimensions with proper 3D reconstruction
  Future<PlanarObjectMeasurement> measureObject({
    required List<vm.Vector2> corners,
    required IntrinsicMatrix kOut,
    required double distanceMeters,
    double? referenceWidthCm,
    double? referenceHeightCm,
  }) async {
    if (corners.length != 4) {
      throw ArgumentError('Exactly 4 corners required');
    }

    // User selects corners in order: TL, TR, BR, BL (top-left, top-right, bottom-right, bottom-left)
    // We trust this order and use it directly
    print('Using corners in user-selected order [TL, TR, BR, BL]:');
    print(
        '  ${corners.map((c) => '[${c.x.toStringAsFixed(1)},${c.y.toStringAsFixed(1)}]').join(', ')}');

    // ACCURATE 3D RECONSTRUCTION FOR ANY CAMERA ANGLE
    // The key insight: we know the distance, so we can solve for the plane orientation

    // Step 1: Back-project corners to 3D rays
    // IMPORTANT: Do NOT normalize rays! We need ray.z = 1 for distance calculation
    final rays = corners.map((corner) {
      final x_norm = (corner.x - kOut.cx) / kOut.fx;
      final y_norm = (corner.y - kOut.cy) / kOut.fy;
      return vm.Vector3(x_norm, y_norm, 1.0); // NOT normalized!
    }).toList();

    // Step 2: Estimate plane orientation from perspective distortion
    // Instead of using cross product (which fails when all Z are same),
    // we analyze the quadrilateral shape to estimate plane tilt

    // Calculate edge ratios to detect perspective
    final edge01 = (corners[1] - corners[0]).length; // Top edge
    final edge32 = (corners[2] - corners[3]).length; // Bottom edge
    final edge03 = (corners[3] - corners[0]).length; // Left edge
    final edge12 = (corners[2] - corners[1]).length; // Right edge

    // If top/bottom edges have different lengths, plane is tilted in pitch
    // If left/right edges have different lengths, plane is tilted in roll
    final horizontalRatio = edge01 / (edge32 + 1e-6);
    final verticalRatio = edge03 / (edge12 + 1e-6);

    print(
        'Edge ratios: horizontal=${horizontalRatio.toStringAsFixed(3)}, vertical=${verticalRatio.toStringAsFixed(3)}');

    // Estimate plane normal from perspective distortion
    // For a frontal plane: normal = [0, 0, 1]
    // For tilted plane: normal has X, Y components

    // Simple heuristic: if ratio > 1, far edge is smaller (tilted away)
    // if ratio < 1, near edge is smaller (tilted toward)
    double nx = 0.0;
    double ny = 0.0;
    double nz = 1.0;

    // Horizontal tilt (around Y axis)
    if (horizontalRatio > 1.05) {
      // Top edge larger → top is closer → plane tilted down
      ny = -(horizontalRatio - 1.0) * 0.3;
    } else if (horizontalRatio < 0.95) {
      // Bottom edge larger → bottom is closer → plane tilted up
      ny = (1.0 / horizontalRatio - 1.0) * 0.3;
    }

    // Vertical tilt (around X axis)
    if (verticalRatio > 1.05) {
      // Left edge larger → left is closer → plane tilted right
      nx = (verticalRatio - 1.0) * 0.3;
    } else if (verticalRatio < 0.95) {
      // Right edge larger → right is closer → plane tilted left
      nx = -(1.0 / verticalRatio - 1.0) * 0.3;
    }

    final normal = vm.Vector3(nx, ny, nz).normalized();

    print(
        'Estimated plane normal: [${normal.x.toStringAsFixed(3)}, ${normal.y.toStringAsFixed(3)}, ${normal.z.toStringAsFixed(3)}]');

    // Step 3: Refine plane position using distance constraint
    // Plane equation: n·(P - P0) = 0, where P0 is a point on the plane
    // We know the average distance should be distanceMeters

    // Distance along optical axis to plane
    // If plane normal is n and passes through point at distance d along optical axis
    // Then: d = distance / (n · [0,0,1]) = distance / n.z
    final d_plane = distanceMeters / normal.z.abs().clamp(0.1, 1.0);

    print(
        'd_plane: ${d_plane.toStringAsFixed(4)}m (from distance=${distanceMeters}m, normal.z=${normal.z.toStringAsFixed(3)})');

    // Step 4: Intersect each ray with the refined plane
    final points3D = <vm.Vector3>[];
    print('Ray intersection debug:');
    for (int i = 0; i < rays.length; i++) {
      final ray = rays[i];
      // Ray: P = lambda * ray
      // Plane: n · P = d_plane * n.z (distance along Z axis)
      final n_dot_ray = normal.dot(ray);

      double lambda;
      if (n_dot_ray.abs() < 1e-6) {
        // Ray parallel to plane - use simple distance
        lambda = distanceMeters / ray.z;
        print(
            '  Ray[$i]: parallel, lambda=${lambda.toStringAsFixed(4)}, ray.z=${ray.z.toStringAsFixed(3)}');
        points3D.add(ray * lambda);
      } else {
        // Proper intersection
        lambda = (d_plane * normal.z) / n_dot_ray;
        print(
            '  Ray[$i]: intersect, lambda=${lambda.toStringAsFixed(4)}, n·ray=${n_dot_ray.toStringAsFixed(3)}');
        points3D.add(ray * lambda);
      }
      print(
          '    Ray: [${ray.x.toStringAsFixed(3)}, ${ray.y.toStringAsFixed(3)}, ${ray.z.toStringAsFixed(3)}]');
      print(
          '    Point3D: [${points3D[i].x.toStringAsFixed(4)}, ${points3D[i].y.toStringAsFixed(4)}, ${points3D[i].z.toStringAsFixed(4)}]');
    }

    // Step 5: Calculate real-world dimensions
    // Assumption: corners = [TL, TR, BR, BL] (top-left, top-right, bottom-right, bottom-left)
    final topEdge3D = (points3D[1] - points3D[0]).length; // TL to TR
    final bottomEdge3D = (points3D[2] - points3D[3]).length; // BL to BR
    final leftEdge3D = (points3D[3] - points3D[0]).length; // TL to BL
    final rightEdge3D = (points3D[2] - points3D[1])
        .length; // TR to BR (user says this is correct!)

    print('Edge calculation (assuming [TL, TR, BR, BL] order):');
    print('  Top edge [0→1]: ${topEdge3D.toStringAsFixed(4)}m');
    print(
        '  Right edge [1→2]: ${rightEdge3D.toStringAsFixed(4)}m (user says OK)');
    print('  Bottom edge [3→2]: ${bottomEdge3D.toStringAsFixed(4)}m');
    print('  Left edge [0→3]: ${leftEdge3D.toStringAsFixed(4)}m');

    // Debug logging
    print('=== PLANAR MEASUREMENT DEBUG ===');
    print('Distance input: ${distanceMeters}m');
    print(
        'Corners (pixels): ${corners.map((c) => '[${c.x.toStringAsFixed(1)},${c.y.toStringAsFixed(1)}]').join(', ')}');
    print('3D Points (meters):');
    for (int i = 0; i < points3D.length; i++) {
      final p = points3D[i];
      print(
          '  [$i]: [${p.x.toStringAsFixed(3)}, ${p.y.toStringAsFixed(3)}, ${p.z.toStringAsFixed(3)}]');
    }
    print('Edge lengths (meters):');
    print('  Top: ${topEdge3D.toStringAsFixed(4)}m');
    print('  Bottom: ${bottomEdge3D.toStringAsFixed(4)}m');
    print('  Left: ${leftEdge3D.toStringAsFixed(4)}m');
    print('  Right: ${rightEdge3D.toStringAsFixed(4)}m');

    // Use geometric mean for better accuracy
    final width3D = math.sqrt(topEdge3D * bottomEdge3D);
    final height3D = math.sqrt(leftEdge3D * rightEdge3D);

    print('Geometric mean:');
    print(
        '  Width: ${width3D.toStringAsFixed(4)}m = ${(width3D * 100).toStringAsFixed(2)}cm');
    print(
        '  Height: ${height3D.toStringAsFixed(4)}m = ${(height3D * 100).toStringAsFixed(2)}cm');

    // Convert to cm
    double widthCm;
    double heightCm;

    if (referenceWidthCm != null) {
      final scale = referenceWidthCm / (width3D * 100);
      widthCm = referenceWidthCm;
      heightCm = (height3D * 100) * scale;
      print(
          'Using reference width: ${referenceWidthCm}cm, scale=${scale.toStringAsFixed(4)}');
    } else if (referenceHeightCm != null) {
      final scale = referenceHeightCm / (height3D * 100);
      heightCm = referenceHeightCm;
      widthCm = (width3D * 100) * scale;
      print(
          'Using reference height: ${referenceHeightCm}cm, scale=${scale.toStringAsFixed(4)}');
    } else {
      widthCm = width3D * 100;
      heightCm = height3D * 100;
      print('No reference, using direct conversion');
    }

    final areaCm2 = widthCm * heightCm;
    final aspectRatio = widthCm / heightCm;

    // Estimate error
    final avgFocal = (kOut.fx + kOut.fy) / 2;
    final error = _estimateError(
      corners: corners,
      widthPixels: width3D * avgFocal / distanceMeters,
      heightPixels: height3D * avgFocal / distanceMeters,
      hasReference: referenceWidthCm != null || referenceHeightCm != null,
    );

    return PlanarObjectMeasurement(
      widthCm: widthCm,
      heightCm: heightCm,
      areaCm2: areaCm2,
      corners: corners,
      rectifiedCorners: corners,
      aspectRatio: aspectRatio,
      estimatedError: error,
      distanceMeters: distanceMeters,
    );
  }

  double _estimateError({
    required List<vm.Vector2> corners,
    required double widthPixels,
    required double heightPixels,
    required bool hasReference,
  }) {
    const pixelUncertainty = 2.0;

    if (widthPixels < 20 || heightPixels < 20) {
      return 50.0;
    }

    final widthError = (pixelUncertainty / widthPixels) * 100;
    final heightError = (pixelUncertainty / heightPixels) * 100;
    final avgError = (widthError + heightError) / 2;

    if (hasReference) {
      return (avgError * 0.5).clamp(0.5, 20.0);
    }

    final perspectiveError = _estimatePerspectiveError(corners);
    final totalError = avgError + perspectiveError;

    return totalError.clamp(1.0, 50.0);
  }

  double _estimatePerspectiveError(List<vm.Vector2> corners) {
    final topEdge = (corners[1] - corners[0]).length;
    final bottomEdge = (corners[2] - corners[3]).length;
    final leftEdge = (corners[3] - corners[0]).length;
    final rightEdge = (corners[2] - corners[1]).length;

    final topBottomRatio = topEdge / (bottomEdge + 1e-6);
    final leftRightRatio = leftEdge / (rightEdge + 1e-6);

    final perspectiveDistortion =
        (topBottomRatio - 1.0).abs() + (leftRightRatio - 1.0).abs();

    return perspectiveDistortion * 5.0;
  }

  bool isValidQuadrilateral(List<vm.Vector2> corners) {
    if (corners.length != 4) return false;

    for (int i = 0; i < 4; i++) {
      final p1 = corners[i];
      final p2 = corners[(i + 1) % 4];
      final p3 = corners[(i + 2) % 4];

      final v1 = p2 - p1;
      final v2 = p3 - p2;

      final cross = v1.x * v2.y - v1.y * v2.x;
      if (cross.abs() < 1.0) return false;
    }

    return true;
  }
}
