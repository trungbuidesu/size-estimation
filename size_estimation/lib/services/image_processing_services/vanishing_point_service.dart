import 'dart:math';
import 'package:camera/camera.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'package:vector_math/vector_math_64.dart'; // Export Vector3 etc directly? No, cleaner to alias or use implicit.

class VanishingPointService {
  /// Estimates the vertical vanishing point from the camera image.
  vm.Vector2? estimateVerticalVanishingPoint(CameraImage image) {
    if (image.planes.isEmpty) return null;

    final stride = image.planes[0].bytesPerRow;
    final bytes = image.planes[0].bytes;
    final w = image.width;
    final h = image.height;

    final List<Vector3> lines = [];

    // 1. Detection Step (Subsampled)
    const step = 8; // Process every 8th pixel
    const minGradient = 40.0;

    for (int y = step; y < h - step; y += step) {
      for (int x = step; x < w - step; x += step) {
        int idx = y * stride + x;

        // Simple Gradient
        double gx = (bytes[idx + 1] - bytes[idx - 1]).toDouble();
        double gy = (bytes[idx + stride] - bytes[idx - stride]).toDouble();

        double mag = sqrt(gx * gx + gy * gy);

        if (mag > minGradient) {
          if (gx.abs() > gy.abs() * 1.5) {
            double C = x * gx + y * gy;
            lines.add(Vector3(gx, gy, -C));
          }
        }
      }
    }

    if (lines.length < 10) return null;

    // 2. RANSAC Intersect
    int bestScore = 0;
    vm.Vector2? bestVP;

    const ransacIterations = 30;
    final rand = Random();

    for (int i = 0; i < ransacIterations; i++) {
      final l1 = lines[rand.nextInt(lines.length)];
      final l2 = lines[rand.nextInt(lines.length)];

      Vector3 intersection = l1.cross(l2);

      if (intersection.z.abs() < 1e-4) continue;

      double vx = intersection.x / intersection.z;
      double vy = intersection.y / intersection.z;

      int score = 0;
      int checkCount = lines.length > 100 ? 100 : lines.length;

      for (int k = 0; k < checkCount; k++) {
        var l = lines[k];
        double mag = sqrt(l.x * l.x + l.y * l.y);
        double dist = (l.x * vx + l.y * vy + l.z).abs() / mag;

        if (dist < 5.0) score++;
      }

      if (score > bestScore) {
        bestScore = score;
        bestVP = vm.Vector2(vx, vy);
      }
    }

    return bestVP;
  }
}
