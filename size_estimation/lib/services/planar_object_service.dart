import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vm;
import 'package:size_estimation/models/camera_metadata.dart';
import 'package:size_estimation/constants/index.dart';

/// Result of planar object measurement
class PlanarObjectMeasurement {
  final double widthCm;
  final double heightCm;
  final double areaCm2;
  final List<vm.Vector2> corners; // 4 corners in image coordinates
  final List<vm.Vector2> rectifiedCorners; // 4 corners after rectification
  final double aspectRatio;
  final double estimatedError; // Estimated error in cm

  const PlanarObjectMeasurement({
    required this.widthCm,
    required this.heightCm,
    required this.areaCm2,
    required this.corners,
    required this.rectifiedCorners,
    required this.aspectRatio,
    required this.estimatedError,
  });

  @override
  String toString() {
    return 'PlanarObjectMeasurement(\n'
        '  Width: ${widthCm.toStringAsFixed(1)} cm\n'
        '  Height: ${heightCm.toStringAsFixed(1)} cm\n'
        '  Area: ${areaCm2.toStringAsFixed(1)} cm²\n'
        '  Aspect Ratio: ${aspectRatio.toStringAsFixed(2)}\n'
        '  Error: ± ${estimatedError.toStringAsFixed(1)} cm\n'
        ')';
  }
}

/// Service for planar object measurements using homography
class PlanarObjectService {
  /// Measure planar object dimensions
  ///
  /// Parameters:
  /// - corners: 4 corners of the planar object (top-left, top-right, bottom-right, bottom-left)
  /// - kOut: Camera intrinsic matrix
  /// - referenceWidthCm: Known width for scale (optional, if null uses pixel-to-cm estimation)
  /// - referenceHeightCm: Known height for scale (optional)
  Future<PlanarObjectMeasurement> measureObject({
    required List<vm.Vector2> corners,
    required IntrinsicMatrix kOut,
    double? referenceWidthCm,
    double? referenceHeightCm,
  }) async {
    if (corners.length != 4) {
      throw ArgumentError('Exactly 4 corners required');
    }

    // Build homography to rectify the plane
    final H = _computeRectificationHomography(corners);

    // Apply homography to corners
    final rectifiedCorners =
        corners.map((c) => _applyHomography(H, c)).toList();

    // Calculate dimensions in rectified space
    final width = (rectifiedCorners[1] - rectifiedCorners[0]).length;
    final height = (rectifiedCorners[3] - rectifiedCorners[0]).length;

    // Convert to cm
    double widthCm;
    double heightCm;

    if (referenceWidthCm != null) {
      // Use reference width for scale
      final scale = referenceWidthCm / width;
      widthCm = referenceWidthCm;
      heightCm = height * scale;
    } else if (referenceHeightCm != null) {
      // Use reference height for scale
      final scale = referenceHeightCm / height;
      heightCm = referenceHeightCm;
      widthCm = width * scale;
    } else {
      // Estimate scale from focal length (rough approximation)
      // Assumes object is ~50cm from camera
      final avgFocal = (kOut.fx + kOut.fy) / 2;
      final estimatedDistance =
          PlanarObjectConfig.estimatedDistanceMeters; // meters
      final pixelToCm = (estimatedDistance * 100) / avgFocal;

      widthCm = width * pixelToCm;
      heightCm = height * pixelToCm;
    }

    final areaCm2 = widthCm * heightCm;
    final aspectRatio = widthCm / heightCm;

    // Estimate error
    final error = _estimateError(
      corners: corners,
      widthPixels: width,
      heightPixels: height,
      hasReference: referenceWidthCm != null || referenceHeightCm != null,
    );

    return PlanarObjectMeasurement(
      widthCm: widthCm,
      heightCm: heightCm,
      areaCm2: areaCm2,
      corners: corners,
      rectifiedCorners: rectifiedCorners,
      aspectRatio: aspectRatio,
      estimatedError: error,
    );
  }

  /// Compute homography for plane rectification
  /// Maps quadrilateral to rectangle
  vm.Matrix3 _computeRectificationHomography(List<vm.Vector2> corners) {
    // Source points (quadrilateral in image)
    final src = corners;

    // Destination points (rectangle)
    // Compute bounding box
    final minX = corners.map((c) => c.x).reduce(math.min);
    final maxX = corners.map((c) => c.x).reduce(math.max);
    final minY = corners.map((c) => c.y).reduce(math.min);
    final maxY = corners.map((c) => c.y).reduce(math.max);

    final dst = [
      vm.Vector2(minX, minY), // Top-left
      vm.Vector2(maxX, minY), // Top-right
      vm.Vector2(maxX, maxY), // Bottom-right
      vm.Vector2(minX, maxY), // Bottom-left
    ];

    // Compute homography using DLT (Direct Linear Transform)
    return _computeHomographyDLT(src, dst);
  }

  /// Compute homography using Direct Linear Transform
  vm.Matrix3 _computeHomographyDLT(List<vm.Vector2> src, List<vm.Vector2> dst) {
    // Build matrix A for homography computation
    // For each point correspondence, we get 2 equations
    final A = List.generate(8, (_) => List.filled(9, 0.0));

    for (int i = 0; i < 4; i++) {
      final x = src[i].x;
      final y = src[i].y;
      final u = dst[i].x;
      final v = dst[i].y;

      // First equation
      A[i * 2][0] = -x;
      A[i * 2][1] = -y;
      A[i * 2][2] = -1;
      A[i * 2][6] = x * u;
      A[i * 2][7] = y * u;
      A[i * 2][8] = u;

      // Second equation
      A[i * 2 + 1][3] = -x;
      A[i * 2 + 1][4] = -y;
      A[i * 2 + 1][5] = -1;
      A[i * 2 + 1][6] = x * v;
      A[i * 2 + 1][7] = y * v;
      A[i * 2 + 1][8] = v;
    }

    // Solve using SVD (simplified - using least squares approximation)
    // For production, use proper SVD library
    // Here we use a simplified direct solution

    // Simplified homography (identity for now - should use proper SVD)
    return vm.Matrix3.identity();
  }

  /// Apply homography to a point
  vm.Vector2 _applyHomography(vm.Matrix3 H, vm.Vector2 point) {
    final p = vm.Vector3(point.x, point.y, 1.0);
    final p_prime = H * p;

    final w = p_prime.z;
    if (w.abs() < PlanarObjectConfig.zeroEpsilon) {
      return vm.Vector2(point.x, point.y); // Return original if singular
    }

    return vm.Vector2(p_prime.x / w, p_prime.y / w);
  }

  /// Estimate measurement error
  double _estimateError({
    required List<vm.Vector2> corners,
    required double widthPixels,
    required double heightPixels,
    required bool hasReference,
  }) {
    // Base error from corner detection (±3 pixels per corner)
    const cornerUncertainty = PlanarObjectConfig.cornerUncertainty;
    final avgDimension = (widthPixels + heightPixels) / 2;
    final baseErrorRatio = (cornerUncertainty * 4) / avgDimension;

    // Error is lower if we have a reference measurement
    final referenceBonus = hasReference
        ? PlanarObjectConfig.referenceBonusFactor
        : PlanarObjectConfig.noReferencePenaltyFactor;

    // Perspective distortion error
    final perspectiveError = _estimatePerspectiveDistortion(corners);

    // Combined error (percentage)
    final totalErrorRatio =
        baseErrorRatio * referenceBonus * (1 + perspectiveError);

    // Convert to cm (assume average dimension ~20cm for objects)
    final estimatedDimension = PlanarObjectConfig.estimatedDimensionCm; // cm
    return (totalErrorRatio * estimatedDimension).clamp(
        PlanarObjectConfig.minErrorClampCm, PlanarObjectConfig.maxErrorClampCm);
  }

  /// Estimate perspective distortion from corner angles
  double _estimatePerspectiveDistortion(List<vm.Vector2> corners) {
    // Calculate angles at each corner
    final angles = <double>[];

    for (int i = 0; i < 4; i++) {
      final prev = corners[(i - 1 + 4) % 4];
      final curr = corners[i];
      final next = corners[(i + 1) % 4];

      final v1 = prev - curr;
      final v2 = next - curr;

      final angle = math.acos(
          v1.dot(v2) / (v1.length * v2.length).clamp(1e-10, double.infinity));

      angles.add(angle);
    }

    // Ideal angle is 90 degrees (π/2)
    final avgDeviation = angles
            .map((a) => (a - PlanarObjectConfig.idealAngleRad).abs())
            .reduce((a, b) => a + b) /
        4;

    // Normalize to 0-1 range
    return (avgDeviation / PlanarObjectConfig.angleNormalizationFactor)
        .clamp(0.0, 1.0);
  }

  /// Detect if corners form a valid quadrilateral
  bool isValidQuadrilateral(List<vm.Vector2> corners) {
    if (corners.length != 4) return false;

    // Check if corners are in order (convex quadrilateral)
    // Calculate cross products to check winding order
    for (int i = 0; i < 4; i++) {
      final p1 = corners[i];
      final p2 = corners[(i + 1) % 4];
      final p3 = corners[(i + 2) % 4];

      final v1 = p2 - p1;
      final v2 = p3 - p2;

      // Cross product in 2D
      final cross = v1.x * v2.y - v1.y * v2.x;

      // All cross products should have the same sign for convex quad
      if (i > 0 && cross * _lastCross < 0) {
        return false; // Not convex
      }
      _lastCross = cross;
    }

    return true;
  }

  double _lastCross = 0;

  /// Get common reference sizes
  static Map<String, Map<String, double>> getReferenceSizes() {
    return PlanarObjectConfig.referenceSizes;
  }
}
