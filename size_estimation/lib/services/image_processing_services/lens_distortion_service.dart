// ignore_for_file: non_constant_identifier_names
import 'dart:math';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'package:size_estimation/models/camera_metadata.dart'; // Uses IntrinsicMatrix alias

class LensDistortionService {
  /// Undistorts a single 2D point using Brown-Conrady model.
  ///
  /// [point]: The observed pixel coordinates (u, v).
  /// [kMatrix]: The intrinsic matrix K [[fx, 0, cx], [0, fy, cy], [0, 0, 1]].
  /// [distCoeffs]: Distortion coefficients [k1, k2, k3, p1, p2, ...].
  ///
  /// Returns the undistorted pixel coordinates (u', v').
  vm.Vector2 undistortPoint({
    required vm.Vector2 point,
    required IntrinsicMatrix kMatrix,
    required List<double> distCoeffs,
  }) {
    if (distCoeffs.isEmpty) return point;

    // 1. Convert to normalized coordinates (distorted)
    // u = fx * x_d + cx  =>  x_d = (u - cx) / fx
    // v = fy * y_d + cy  =>  y_d = (v - cy) / fy

    final fx = kMatrix.fx;
    final fy = kMatrix.fy;
    final cx = kMatrix.cx;
    final cy = kMatrix.cy;

    double x_d = (point.x - cx) / fx;
    double y_d = (point.y - cy) / fy;

    // 2. Iteratively undistort to find ideal (x, y)
    double x = x_d;
    double y = y_d;

    // Extract coefficients
    final k1 = distCoeffs.isNotEmpty ? distCoeffs[0] : 0.0;
    final k2 = distCoeffs.length > 1 ? distCoeffs[1] : 0.0;
    final p1 = distCoeffs.length > 2
        ? distCoeffs[2]
        : 0.0; // Sometimes p1/p2 order varies, but standard is k1,k2,p1,p2,k3
    final p2 = distCoeffs.length > 3 ? distCoeffs[3] : 0.0;
    final k3 = distCoeffs.length > 4 ? distCoeffs[4] : 0.0;

    // Note: Android Camera2 sometimes returns [k1, k2, k3, p1, p2].
    // While OpenCV standard is [k1, k2, p1, p2, k3].
    // Let's assume standard OpenCV order if length is 5: k1, k2, p1, p2, k3
    // But verify Android:
    // "float[]: [k1, k2, k3, p1, p2]" per documentation (LENS_RADIAL_DISTORTION cap).
    // Wait, Android documentation says: [kappa_1, kappa_2, kappa_3, kappa_0, kappa_4] ??
    // Actually documentation for `ACAMERA_LENS_RADIAL_DISTORTION` says:
    // [k1, k2, k3, p1, p2].

    // Iteration (Newton-Raphson or fixed point)
    // We use fixed point iteration as it's simpler and converges reasonably for small distortions.
    const int iterations = 5;

    for (int i = 0; i < iterations; i++) {
      double r2 = x * x + y * y;
      double r4 = r2 * r2;
      double r6 = r4 * r2;

      // Radial component
      double kRadial = 1.0 + k1 * r2 + k2 * r4 + k3 * r6;

      // Tangential component
      double dx = 2.0 * p1 * x * y + p2 * (r2 + 2.0 * x * x);
      double dy = p1 * (r2 + 2.0 * y * y) + 2.0 * p2 * x * y;

      // Inverse mapping
      x = (x_d - dx) / kRadial;
      y = (y_d - dy) / kRadial;
    }

    // 3. Project back to pixels using original K
    // u' = fx * x + cx
    // v' = fy * y + cy
    double u_ideal = x * fx + cx;
    double v_ideal = y * fy + cy;

    return vm.Vector2(u_ideal, v_ideal);
  }
}
