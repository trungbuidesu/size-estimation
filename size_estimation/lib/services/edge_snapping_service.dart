import 'dart:math';
import 'package:camera/camera.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

class EdgeSnappingService {
  /// Simple edge snapping using gradient magnitude on Y plane.
  ///
  /// [image]: The camera image (YUV420). We use plane 0 (Luminance).
  /// [center]: The approximate point in image coordinates.
  /// [radius]: Search radius in pixels (e.g. 20).
  ///
  /// Returns the point with maximum gradient magnitude within the radius.
  vm.Vector2 snapToEdge({
    required CameraImage image,
    required vm.Vector2 center,
    int radius = 20,
  }) {
    if (image.planes.isEmpty) return center;

    final plane = image.planes[0];
    final bytes = plane.bytes;
    final stride = plane.bytesPerRow;
    final width = image.width;
    final height = image.height;

    int cx = center.x.round();
    int cy = center.y.round();

    // Bounds check
    int startX = max(1, cx - radius);
    int endX = min(width - 2, cx + radius);
    int startY = max(1, cy - radius);
    int endY = min(height - 2, cy + radius);

    double maxGrad = -1.0;
    int bestX = cx;
    int bestY = cy;

    for (int y = startY; y <= endY; y++) {
      for (int x = startX; x <= endX; x++) {
        // Compute gradient magnitude using Sobel-like or simple difference
        // Simple difference: |I(x+1) - I(x-1)| + |I(y+1) - I(y-1)|

        int idx = y * stride + x;
        int idxLeft = y * stride + (x - 1);
        int idxRight = y * stride + (x + 1);
        int idxUp = (y - 1) * stride + x;
        int idxDown = (y + 1) * stride + x;

        // Safety check indices (though loops are safe by bounds, stride padding might vary)
        // Usually bytesPerRow >= width.
        // We assume valid bytes.

        int valLeft = bytes[idxLeft];
        int valRight = bytes[idxRight];
        int valUp = bytes[idxUp];
        int valDown = bytes[idxDown];

        double gradX = (valRight - valLeft).abs().toDouble();
        double gradY = (valDown - valUp).abs().toDouble();
        double grad = gradX + gradY; // L1 norm approximation

        // Weight by distance to center to prefer closer edges?
        // Let's just find strongest edge.
        if (grad > maxGrad) {
          maxGrad = grad;
          bestX = x;
          bestY = y;
        }
      }
    }

    // Threshold? If gradient is too weak, stick to center.
    if (maxGrad < 20) {
      // Threshold 20/255 is fairly low
      return center;
    }

    return vm.Vector2(bestX.toDouble(), bestY.toDouble());
  }
}
