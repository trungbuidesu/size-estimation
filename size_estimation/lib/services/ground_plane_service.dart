import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vm;
import 'package:size_estimation/models/camera_metadata.dart';
import 'package:size_estimation/services/imu_service.dart';
import 'package:size_estimation/constants/index.dart';

/// Result of ground plane measurement
class GroundPlaneMeasurement {
  final double distanceMeters;
  final double distanceCm;
  final vm.Vector2 pointA; // Ground coordinates (X, Y)
  final vm.Vector2 pointB; // Ground coordinates (X, Y)
  final double cameraHeightMeters;
  final double estimatedError; // Estimated error in cm

  const GroundPlaneMeasurement({
    required this.distanceMeters,
    required this.distanceCm,
    required this.pointA,
    required this.pointB,
    required this.cameraHeightMeters,
    required this.estimatedError,
  });

  @override
  String toString() {
    return 'GroundPlaneMeasurement(\n'
        '  Distance: ${distanceCm.toStringAsFixed(1)} cm (± ${estimatedError.toStringAsFixed(1)} cm)\n'
        '  Point A: (${pointA.x.toStringAsFixed(2)}, ${pointA.y.toStringAsFixed(2)}) m\n'
        '  Point B: (${pointB.x.toStringAsFixed(2)}, ${pointB.y.toStringAsFixed(2)}) m\n'
        '  Camera Height: ${cameraHeightMeters.toStringAsFixed(2)} m\n'
        ')';
  }
}

/// Service for ground plane measurements using homography
class GroundPlaneService {
  /// Measure distance between two points on ground plane
  ///
  /// Parameters:
  /// - imagePointA, imagePointB: Points in image coordinates (u, v)
  /// - kOut: Camera intrinsic matrix for output image
  /// - orientation: IMU orientation (rotation matrix R)
  /// - cameraHeightMeters: Height of camera above ground plane
  /// - imageWidth, imageHeight: Image dimensions
  Future<GroundPlaneMeasurement> measureDistance({
    required vm.Vector2 imagePointA,
    required vm.Vector2 imagePointB,
    required IntrinsicMatrix kOut,
    required IMUOrientation orientation,
    required double cameraHeightMeters,
    required int imageWidth,
    required int imageHeight,
  }) async {
    print('--- Start Measurement ---');
    print(
        'IMU Orientation: Roll=${orientation.rollDegrees.toStringAsFixed(2)}°, Pitch=${orientation.pitchDegrees.toStringAsFixed(2)}°, Yaw=${orientation.yawDegrees.toStringAsFixed(2)}°');

    // Build homography from image to ground plane
    final H_inv = _computeImageToGroundHomography(
      kOut: kOut,
      rotation: orientation.rotationMatrix,
      cameraHeight: cameraHeightMeters,
    );

    // Map image points to ground coordinates
    print('Mapping Point A:');
    final groundA = _applyHomography(H_inv, imagePointA);
    print('Mapping Point B:');
    final groundB = _applyHomography(H_inv, imagePointB);

    // Calculate distance
    final distance = (groundA - groundB).length;
    print('Calculated Distance: $distance meters');

    // Estimate error
    final error = _estimateError(
      pixelDistance: (imagePointA - imagePointB).length,
      groundDistance: distance,
      cameraHeight: cameraHeightMeters,
      pitch: orientation.pitch,
    );

    return GroundPlaneMeasurement(
      distanceMeters: distance,
      distanceCm: distance * 100,
      pointA: groundA,
      pointB: groundB,
      cameraHeightMeters: cameraHeightMeters,
      estimatedError: error,
    );
  }

  /// Compute homography from image to ground plane
  /// H^-1 maps image coordinates (u, v) to ground coordinates (X, Y)
  ///
  /// Ground plane: Z = 0, normal n = (0, 0, 1)
  /// Camera at height h, with rotation R
  ///
  /// Homography: H = K [r1 r2 t]
  /// where r1, r2 are first two columns of R
  /// and t = [0, 0, h]^T in camera coordinates
  /// Compute homography from image to ground plane
  /// H^-1 maps image coordinates (u, v) to ground coordinates (X, Y)
  ///
  /// Ground plane: Z = 0, normal n = (0, 0, 1)
  /// Camera at height h, with rotation R
  ///
  /// Homography: H = K [r1 r2 t]
  /// where r1, r2 are first two columns of R
  /// and t = [0, 0, h]^T
  vm.Matrix3 _computeImageToGroundHomography({
    required IntrinsicMatrix kOut,
    required vm.Matrix3 rotation,
    required double cameraHeight,
  }) {
    print('--- Ground Plane Calculation Debug ---');
    print('Camera Height (h): $cameraHeight m');

    // Build K matrix
    // Note: Matrix3 constructor uses column-major order
    // K = | fx  s  cx |
    //     |  0 fy  cy |
    //     |  0  0   1 |
    // Column-major: [fx, 0, 0, s, fy, 0, cx, cy, 1]
    final K = vm.Matrix3(
      kOut.fx, // col0_row0
      0, // col0_row1
      0, // col0_row2
      kOut.s, // col1_row0
      kOut.fy, // col1_row1
      0, // col1_row2
      kOut.cx, // col2_row0
      kOut.cy, // col2_row1
      1, // col2_row2
    );
    print('K_out:\n$K');

    // Extract r1 and r2
    // Note: The incoming 'rotation' matrix is effectively R^T due to
    // row-major/col-major mismatch in IMU service construction.
    // Thus, extracting Row 0 and Row 1 of 'rotation' actually gives us
    // Column 0 and Column 1 of the true Rotation Matrix R, which corresponds to r1 and r2.
    final r1 = vm.Vector3(rotation[0], rotation[3], rotation[6]);
    final r2 = vm.Vector3(rotation[1], rotation[4], rotation[7]);

    print('Rotation Matrix (IMU Raw):\n$rotation');
    print('Extracted r1 (Col 0 of R): $r1');
    print('Extracted r2 (Col 1 of R): $r2');

    // Translation vector t
    // User requirement: t = (0, 0, h)^T
    // Note: This assumes h is in meters.
    final t = vm.Vector3(0, 0, cameraHeight);
    print('Translation Vector t: $t');

    // Build homography H = K [r1 r2 t]
    // Matrix3 uses column-major order, so we arrange [r1, r2, t] as columns:
    // H = | r1.x  r2.x  t.x |
    //     | r1.y  r2.y  t.y |
    //     | r1.z  r2.z  t.z |
    // Column-major: [r1.x, r1.y, r1.z, r2.x, r2.y, r2.z, t.x, t.y, t.z]
    final H = vm.Matrix3(
      r1.x, r1.y, r1.z, // Column 0 (r1)
      r2.x, r2.y, r2.z, // Column 1 (r2)
      t.x, t.y, t.z, // Column 2 (t)
    );

    print('Homography Matrix (before K):\n$H');

    final H_full = K * H;
    print('Full Homography Matrix H (P_img = H * P_g):\n$H_full');

    // Return inverse for image -> ground mapping
    final H_inv = vm.Matrix3.copy(H_full);
    H_inv.invert();

    print('Inverse Homography H^-1 (P_g = H^-1 * P_img):\n$H_inv');

    return H_inv;
  }

  /// Apply homography to image point to get ground coordinates
  vm.Vector2 _applyHomography(vm.Matrix3 H, vm.Vector2 imagePoint) {
    // Homogeneous coordinates
    final p = vm.Vector3(imagePoint.x, imagePoint.y, 1.0);

    // Apply homography
    final p_prime = H * p;

    // Normalize by w
    final w = p_prime.z;

    // Log the point transformation
    print(
        'Mapping point (${imagePoint.x}, ${imagePoint.y}) -> Ground Homogeneous: $p_prime');

    if (w.abs() < GroundPlaneConfig.zeroEpsilon) {
      print('Point at infinity (w ~= 0)');
      // Point at infinity, return far point
      return vm.Vector2(GroundPlaneConfig.infinityPointValue,
          GroundPlaneConfig.infinityPointValue);
    }

    final groundPoint = vm.Vector2(p_prime.x / w, p_prime.y / w);
    print('Ground Coordinate: (${groundPoint.x}, ${groundPoint.y})');

    return groundPoint;
  }

  /// Estimate measurement error based on various factors
  double _estimateError({
    required double pixelDistance,
    required double groundDistance,
    required double cameraHeight,
    required double pitch,
  }) {
    // Base error from pixel uncertainty (assume ±2 pixels)
    const pixelUncertainty = GroundPlaneConfig.pixelUncertainty;
    final pixelErrorRatio =
        pixelUncertainty / pixelDistance.clamp(1, double.infinity);
    final baseError = groundDistance * pixelErrorRatio;

    // Error increases with distance from camera
    final distanceErrorFactor =
        1.0 + (groundDistance / GroundPlaneConfig.distanceErrorDivider);

    // Error increases with camera tilt (pitch)
    final pitchDegrees = pitch.abs() * 180 / math.pi;
    final pitchErrorFactor =
        1.0 + (pitchDegrees / GroundPlaneConfig.pitchErrorDivider);

    // Combined error in meters
    final totalError = baseError * distanceErrorFactor * pitchErrorFactor;

    // Convert to cm and clamp to reasonable range
    return (totalError * 100).clamp(
        GroundPlaneConfig.minErrorClampCm, GroundPlaneConfig.maxErrorClampCm);
  }

  /// Check if device orientation is suitable for ground plane measurement
  bool isOrientationSuitable(IMUOrientation orientation,
      {double maxTiltDegrees = GroundPlaneConfig.maxTiltDegrees}) {
    final rollDeg = orientation.rollDegrees.abs();
    final pitchDeg = orientation.pitchDegrees.abs();

    // Device should be relatively level
    return rollDeg < maxTiltDegrees && pitchDeg < maxTiltDegrees;
  }

  /// Get recommended camera height based on typical use cases
  static double getRecommendedCameraHeight(String useCase) {
    switch (useCase.toLowerCase()) {
      case 'handheld':
        return 1.5; // Average eye level
      case 'table':
        return 0.4; // Camera on table
      case 'floor':
        return 0.1; // Camera near floor
      default:
        return 1.5;
    }
  }
}
