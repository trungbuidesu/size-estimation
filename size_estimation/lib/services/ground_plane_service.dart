import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vm;
import 'package:size_estimation/models/camera_metadata.dart';
import 'package:size_estimation/services/imu_service.dart';

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
    // Build homography from image to ground plane
    final H_inv = _computeImageToGroundHomography(
      kOut: kOut,
      rotation: orientation.rotationMatrix,
      cameraHeight: cameraHeightMeters,
    );

    // Map image points to ground coordinates
    final groundA = _applyHomography(H_inv, imagePointA);
    final groundB = _applyHomography(H_inv, imagePointB);

    // Calculate distance
    final distance = (groundA - groundB).length;

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
  vm.Matrix3 _computeImageToGroundHomography({
    required IntrinsicMatrix kOut,
    required vm.Matrix3 rotation,
    required double cameraHeight,
  }) {
    // Build K matrix
    final K = vm.Matrix3(
      kOut.fx,
      kOut.s,
      kOut.cx,
      0,
      kOut.fy,
      kOut.cy,
      0,
      0,
      1,
    );

    // Extract r1 and r2 (first two columns of R)
    final r1 = vm.Vector3(rotation[0], rotation[3], rotation[6]);
    final r2 = vm.Vector3(rotation[1], rotation[4], rotation[7]);

    // Translation vector (camera position in world)
    // For ground plane at Z=0, camera is at (0, 0, h)
    // In camera coordinates, this becomes R^T * [0, 0, h]
    final t_world = vm.Vector3(0, 0, cameraHeight);
    final t_camera = rotation.transposed() * t_world;

    // Build homography H = K [r1 r2 t]
    final H = vm.Matrix3(
      r1.x,
      r2.x,
      t_camera.x,
      r1.y,
      r2.y,
      t_camera.y,
      r1.z,
      r2.z,
      t_camera.z,
    );

    final H_full = K * H;

    // Return inverse for image -> ground mapping
    final H_inv = vm.Matrix3.copy(H_full);
    H_inv.invert();

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
    if (w.abs() < 1e-10) {
      // Point at infinity, return far point
      return vm.Vector2(1000, 1000);
    }

    return vm.Vector2(p_prime.x / w, p_prime.y / w);
  }

  /// Estimate measurement error based on various factors
  double _estimateError({
    required double pixelDistance,
    required double groundDistance,
    required double cameraHeight,
    required double pitch,
  }) {
    // Base error from pixel uncertainty (assume ±2 pixels)
    const pixelUncertainty = 2.0;
    final pixelErrorRatio =
        pixelUncertainty / pixelDistance.clamp(1, double.infinity);
    final baseError = groundDistance * pixelErrorRatio;

    // Error increases with distance from camera
    final distanceErrorFactor = 1.0 + (groundDistance / 10.0);

    // Error increases with camera tilt (pitch)
    final pitchDegrees = pitch.abs() * 180 / math.pi;
    final pitchErrorFactor = 1.0 + (pitchDegrees / 45.0);

    // Combined error in meters
    final totalError = baseError * distanceErrorFactor * pitchErrorFactor;

    // Convert to cm and clamp to reasonable range
    return (totalError * 100).clamp(0.5, 50.0);
  }

  /// Check if device orientation is suitable for ground plane measurement
  bool isOrientationSuitable(IMUOrientation orientation,
      {double maxTiltDegrees = 10.0}) {
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
