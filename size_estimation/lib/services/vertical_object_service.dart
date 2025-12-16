// ignore_for_file: non_constant_identifier_names
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vm;
import 'package:size_estimation/models/camera_metadata.dart';
import 'package:size_estimation/services/imu_service.dart';

/// Result of vertical object measurement
class VerticalObjectMeasurement {
  final double heightCm;
  final double distanceToBottomMeters;
  final double estimatedError; // Estimated error in cm
  final vm.Vector2 bottomPoint; // Ground coordinates of base
  final double
      objectElevation; // Elevation of top point (should be same as heightCm/100)

  const VerticalObjectMeasurement({
    required this.heightCm,
    required this.distanceToBottomMeters,
    required this.estimatedError,
    required this.bottomPoint,
    required this.objectElevation,
  });

  @override
  String toString() {
    return 'VerticalObjectMeasurement(\n'
        '  Height: ${heightCm.toStringAsFixed(1)} cm\n'
        '  Distance: ${distanceToBottomMeters.toStringAsFixed(2)} m\n'
        '  Error: ± ${estimatedError.toStringAsFixed(1)} cm\n'
        ')';
  }
}

/// Service for vertical object measurements
/// Assumes:
/// 1. Object base is on the flat ground plane (Z=0)
/// 2. Object is vertical (perpendicular to ground)
class VerticalObjectService {
  /// Measure height of vertical object
  Future<VerticalObjectMeasurement> measureHeight({
    required vm.Vector2 topPixel,
    required vm.Vector2 bottomPixel,
    required IntrinsicMatrix kOut,
    required IMUOrientation orientation,
    required double cameraHeightMeters,
  }) async {
    // 1. Get Ray directions in World Frame
    final rayBottomWorld =
        _getRayInWorld(bottomPixel, kOut, orientation.rotationMatrix);
    final rayTopWorld =
        _getRayInWorld(topPixel, kOut, orientation.rotationMatrix);

    // 2. Camera Center in World Frame (User defined height)
    // We assume Camera is at (0, 0, h) in World Frame for convenience
    // Ground plane is Z = 0
    final cameraCenter = vm.Vector3(0, 0, cameraHeightMeters);

    // 3. Intersect Bottom Ray with Ground Plane (Z=0)
    // Ray: P = C + lambda * d
    // Z = 0 => C.z + lambda * d.z = 0 => lambda = -C.z / d.z
    if (rayBottomWorld.z.abs() < 1e-6) {
      throw Exception('Bottom ray is parallel to ground (horizon)');
    }

    final lambdaBottom = -cameraCenter.z / rayBottomWorld.z;
    if (lambdaBottom < 0) {
      throw Exception('Bottom point is behind camera or above horizon');
    }

    final pBottom = cameraCenter + rayBottomWorld * lambdaBottom;

    // 4. Calculate Height using Top Ray
    // We assume Top Point has same (X, Y) as Bottom Point
    // We construct a vertical line at (pBottom.x, pBottom.y)
    // Example: P_top = (pBottom.x, pBottom.y, Z_top)
    // This P_top must likely lie on the Top Ray (or closest to it)

    // Geometric approach:
    // Planar distance to object (radius in XY plane)
    final planarDistance =
        math.sqrt(pBottom.x * pBottom.x + pBottom.y * pBottom.y);

    // Planar properties of Top Ray
    final topRayPlanarProjection = math
        .sqrt(rayTopWorld.x * rayTopWorld.x + rayTopWorld.y * rayTopWorld.y);

    if (topRayPlanarProjection < 1e-6) {
      // Top ray is looking straight up/down
      throw Exception('Top ray is vertical singularity');
    }

    // Find lambda for top ray such that planar distance matches
    // lambda * topRayPlanarProjection = planarDistance
    final lambdaTop = planarDistance / topRayPlanarProjection;

    final pTop = cameraCenter + rayTopWorld * lambdaTop;

    // Object Height is the Z coordinate of pTop
    // (Since ground is Z=0)
    final heightMeters = pTop.z;
    final heightCm = heightMeters * 100;

    // 5. Error Estimation
    final error = _estimateError(
      heightCm: heightCm,
      distanceMeters: planarDistance,
      pixelsHeight: (topPixel - bottomPixel).length,
    );

    return VerticalObjectMeasurement(
      heightCm: heightCm,
      distanceToBottomMeters: planarDistance,
      estimatedError: error,
      bottomPoint: vm.Vector2(pBottom.x, pBottom.y),
      objectElevation: heightMeters,
    );
  }

  /// Get Normalized Ray direction in World Frame from Pixel
  vm.Vector3 _getRayInWorld(
      vm.Vector2 pixel,
      IntrinsicMatrix K,
      vm.Matrix3
          R_device_to_world // Actually this is usually R_world_to_camera or vice versa.
      // In IMUService we typically have R that transforms vectors?
      // Let's clarify: IMUService gives Rotation Matrix R.
      // Usually R * v_world = v_camera (World -> Camera).
      // So v_world = R^T * v_camera.
      ) {
    // 1. Pixel to Normalized Camera Coordinates
    // x = (u - cx) / fx, y = (v - cy) / fy, z = 1
    final x_cam = (pixel.x - K.cx) / K.fx;
    final y_cam = (pixel.y - K.cy) / K.fy;
    final v_camera = vm.Vector3(x_cam, y_cam, 1.0).normalized();

    // 2. Camera to World
    // If orientation.rotationMatrix is derived from sensors (IMU), it typically represents absolute orientation.
    // In Android sensors: R transforms from Geomagnetic/Gravity frame to Device frame.
    // So v_device = R * v_world  => v_world = R^T * v_device.
    // However, our standard Camera frame in Computer Vision is:
    // X right, Y down, Z forward.
    // Sensor frame is usually: X right, Y up, Z back (or similar depending on platform).
    // Let's assume the R provided by IMUService has already adjusted for CV frame or we treat it as standard rotation.
    // Assuming IMUService.rotationMatrix is R s.t. v_cam = R * v_world.
    // Then v_world = R.transposed() * v_cam.

    final v_world = R_device_to_world.transposed() * v_camera;
    return v_world.normalized();
  }

  double _estimateError({
    required double heightCm,
    required double distanceMeters,
    required double pixelsHeight,
  }) {
    // Basic error model
    // Uncertainty increases with distance and decreases with pixel resolution of the object
    const pixelUncertainty = 3.0; // +/- pixels selection error

    if (pixelsHeight < 10) return 50.0; // Too small to measure accurately

    final ratio = pixelUncertainty / pixelsHeight;
    final baseError = heightCm * ratio;

    // Distance penalty
    final distanceFactor = 1.0 + (distanceMeters / 5.0);

    return (baseError * distanceFactor).clamp(1.0, 100.0);
  }
}
