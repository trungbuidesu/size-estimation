import 'dart:math';
import 'package:camera/camera.dart';
import 'package:vector_math/vector_math_64.dart';

class FeatureTrackingService {
  static const int _windowSize = 15;
  static const int _iterations = 10;
  static const double _accuracy = 0.03;

  /// Tracks a list of points from [prev] image to [curr] image using Optical Flow (Lucas-Kanade).
  ///
  /// This implementation uses a simplified single-level Lucas-Kanade algorithm
  /// on the Luminance plane (Y) of the YUV420 image.
  ///
  /// Returns a list of tracked points corresponding to the input [points].
  /// If tracking fails for a point, the original point is returned (zero motion assumed).
  List<Vector2> trackPoints({
    required CameraImage prev,
    required CameraImage curr,
    required List<Vector2> points,
  }) {
    final List<Vector2> newPoints = [];

    // Ensure we have data
    if (prev.planes.isEmpty || curr.planes.isEmpty) return points;

    final stride = prev.planes[0].bytesPerRow;
    final bytesPrev = prev.planes[0].bytes;
    final bytesCurr = curr.planes[0].bytes;
    final w = prev.width;
    final h = prev.height;

    for (var pt in points) {
      double u = pt.x;
      double v = pt.y;

      // Safety margin for window
      if (u < _windowSize ||
          u >= w - _windowSize ||
          v < _windowSize ||
          v >= h - _windowSize) {
        newPoints.add(pt);
        continue;
      }

      // Initial estimate for next position (start at current position, assuming small motion)
      double nu = u;
      double nv = v;

      // Newton-Raphson Iterations
      for (int iter = 0; iter < _iterations; iter++) {
        double Gxx = 0, Gxy = 0, Gyy = 0;
        double bx = 0, by = 0;

        // Iterate over window
        for (int wy = -_windowSize ~/ 2; wy <= _windowSize ~/ 2; wy++) {
          for (int wx = -_windowSize ~/ 2; wx <= _windowSize ~/ 2; wx++) {
            // Pixel in Previous Image (integer coords)
            int ix = (u + wx).round();
            int iy = (v + wy).round();

            // Bounds check inside window loop
            if (ix < 1 || ix >= w - 1 || iy < 1 || iy >= h - 1) continue;

            // Compute Gradient at Previous Image (Spatial Derivatives Ix, Iy)
            // Central Difference
            int cIdx = iy * stride + ix;
            int valPrev = bytesPrev[cIdx];
            // Assuming buffer is valid for +1/-1 due to window margin
            int valRight = bytesPrev[cIdx + 1];
            int valLeft = bytesPrev[cIdx - 1]; // We really need margin > 1
            int valDown = bytesPrev[cIdx + stride];
            int valUp = bytesPrev[cIdx - stride];

            double Ix = (valRight - valLeft) * 0.5;
            double Iy = (valDown - valUp) * 0.5;

            // Compute Temporal Derivative It
            // It = I_curr(x+d) - I_prev(x)
            // We interpolate I_curr at (nu + wx, nv + wy)

            double targetX = nu + wx;
            double targetY = nv + wy;

            // Bilinear Interpolation
            int x0 = targetX.floor();
            int y0 = targetY.floor();
            double dx = targetX - x0;
            double dy = targetY - y0;

            if (x0 < 0 || x0 >= w - 1 || y0 < 0 || y0 >= h - 1) continue;

            int idx00 = y0 * stride + x0;
            // Assuming stride is correct for next row
            int c00 = bytesCurr[idx00];
            int c10 = bytesCurr[idx00 + 1];
            int c01 = bytesCurr[idx00 + stride];
            int c11 = bytesCurr[idx00 + stride + 1];

            double valCurr = (1 - dx) * (1 - dy) * c00 +
                dx * (1 - dy) * c10 +
                (1 - dx) * dy * c01 +
                dx * dy * c11;

            double It = valCurr - valPrev;

            // Accumulate G matrix and b vector components
            Gxx += Ix * Ix;
            Gxy += Ix * Iy;
            Gyy += Iy * Iy;
            bx += Ix * It;
            by += Iy * It;
          }
        }

        // Solve G * d = -b
        // [Gxx Gxy] [dx] = [-bx]
        // [Gxy Gyy] [dy] = [-by]

        double det = Gxx * Gyy - Gxy * Gxy;
        if (det.abs() < 0.0001)
          break; // Singular matrix, typically in flat regions

        double invDet = 1.0 / det;
        // Inverse of 2x2 matrix:
        // [ Gyy -Gxy]
        // [-Gxy  Gxx] * invDet

        // d = - inv(G) * b
        // d = - [ (Gyy*bx - Gxy*by), (-Gxy*bx + Gxx*by) ] * invDet
        // Actually d = inv(G) * (-b)
        // dx = (Gyy*(-bx) - Gxy*(-by)) * invDet = (-Gyy*bx + Gxy*by) * invDet

        double dx = (Gxy * by - Gyy * bx) * invDet;
        double dy = (Gxy * bx - Gxx * by) * invDet;

        nu += dx;
        nv += dy;

        if (dx.abs() < _accuracy && dy.abs() < _accuracy) break;
      }

      newPoints.add(Vector2(nu, nv));
    }

    return newPoints;
  }
}
