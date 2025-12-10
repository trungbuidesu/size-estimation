import 'dart:io';
import 'package:size_estimation/core/photogrammetry/models/camera_intrinsics.dart';
import 'package:size_estimation/core/photogrammetry/native/photogrammetry_bindings.dart';

class PhotogrammetryService {
  /// Estimates the absolute height of an object from a list of images using a known baseline.
  ///
  /// [images]: List of 6 images (JPEG/PNG).
  /// [knownBaselineCm]: The distance the camera moved between shots (e.g. 10.0 cm).
  /// [intrinsics]: Camera intrinsics (Focal length, Cx, Cy).
  ///
  /// Returns the estimated height in cm.
  /// Throws [Exception] if estimation fails or inputs are invalid.
  Future<double> estimateHeightFromBaseline({
    required List<File> images,
    required double knownBaselineCm,
    required CameraIntrinsics intrinsics,
  }) async {
    if (images.length < 2) {
      throw Exception('Need at least 2 images for photogrammetry.');
    }

    // Prepare paths
    final imagePaths = images.map((f) => f.path).toList();

    // Call native binding in a compute isolate if needed,
    // but for now we'll call directly (blocking main thread is bad, but FFI is synchronous).
    // In a real app, use compute() or a separate isolate.

    try {
      // Note: This is a synchronous call. For heavy processing,
      // move the inner logic of `PhotogrammetryBindings.estimateHeight` to an isolate.
      final height = PhotogrammetryBindings.estimateHeight(
        imagePaths: imagePaths,
        knownBaselineCm: knownBaselineCm,
        focalLength: intrinsics.focalLength,
        cx: intrinsics.cx,
        cy: intrinsics.cy,
      );

      if (height < 0) {
        _handleErrorCode(height);
      }

      return height;
    } catch (e) {
      throw Exception('Photogrammetry failed: $e');
    }
  }

  void _handleErrorCode(double code) {
    if (code == -1.0)
      throw Exception('Not enough features found (<500 matches).');
    if (code == -2.0)
      throw Exception('Structure from Motion initialization failed.');
    if (code == -3.0) throw Exception('Triangulation failed.');
    if (code == -4.0) throw Exception('Bundle Adjustment failed.');
    throw Exception('Unknown native error code: $code');
  }
}
