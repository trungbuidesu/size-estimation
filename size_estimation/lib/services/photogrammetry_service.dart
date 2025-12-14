import 'dart:io';
import 'dart:convert';
import 'package:size_estimation/models/camera_intrinsics.dart';
import 'package:size_estimation/models/bounding_box.dart';
import 'package:size_estimation/bindings/index.dart';

class PhotogrammetryService {
  /// Estimates the absolute height of an object from a list of images using a known baseline.
  ///
  /// [images]: List of 6 images (JPEG/PNG).
  /// [knownBaselineCm]: The distance the camera moved between shots (e.g. 10.0 cm).
  /// [intrinsics]: Camera intrinsics (Focal length, Cx, Cy).
  /// [selectedBoxes]: Optional bounding boxes to constrain feature matching to specific objects.
  ///
  /// Returns the estimated height in cm.
  /// Throws [Exception] if estimation fails or inputs are invalid.
  Future<double> estimateHeightFromBaseline({
    required List<File> images,
    required double knownBaselineCm,
    required CameraIntrinsics intrinsics,
    List<BoundingBox>? selectedBoxes,
    bool applyUndistortion = true,
  }) async {
    if (images.length < 2) {
      throw Exception('Need at least 2 images for photogrammetry.');
    }

    // Prepare paths
    final imagePaths = images.map((f) => f.path).toList();

    // Serialize bounding boxes to JSON if provided
    String? boundingBoxesJson;
    if (selectedBoxes != null && selectedBoxes.isNotEmpty) {
      final boxesData = selectedBoxes.map((box) => box.toJson()).toList();
      boundingBoxesJson = jsonEncode(boxesData);
    }

    // Call native binding in a compute isolate if needed,
    // but for now we'll call directly (blocking main thread is bad, but FFI is synchronous).
    // In a real app, use compute() or a separate isolate.

    try {
      // 3. Quy trình Xử lý (Native):
      // - 3.1. Undistort images using intrinsics.
      // - 3.2. Feature Matching (SIFT/ORB) & RANSAC.
      //        NEW: Filter features by bounding boxes if provided
      // - 3.3. Essential Matrix Calculation.
      // - 3.4. Decompose E -> T_relative, R.
      // - 3.5. Scale T_relative -> T_absolute using knownBaselineCm.
      // - 3.6. Triangulation & Bundle Adjustment.
      // - 3.7. Calculate Height (Max Z - Min Z).

      final height = PhotogrammetryBindings.estimateHeight(
        imagePaths: imagePaths,
        knownBaselineCm: knownBaselineCm,
        focalLength: intrinsics.focalLength,
        cx: intrinsics.cx,
        cy: intrinsics.cy,
        sensorWidth: intrinsics.sensorWidth,
        sensorHeight: intrinsics.sensorHeight,
        distortionCoefficients:
            applyUndistortion ? intrinsics.distortionCoefficients : [],
        boundingBoxesJson: boundingBoxesJson, // NEW: Pass bounding boxes
      );

      if (height < 0) {
        _handleErrorCode(height);
      }

      return height;
    } catch (e) {
      throw Exception('Photogrammetry estimation failed: $e');
    }
  }

  void _handleErrorCode(double code) {
    if (code == -1.0)
      throw Exception('Not enough features found (<30 matches).');
    if (code == -2.0)
      throw Exception('Structure from Motion initialization failed.');
    if (code == -3.0) throw Exception('Triangulation failed.');
    if (code == -4.0) throw Exception('Bundle Adjustment failed.');
    if (code == -5.0)
      throw Exception(
          'Sai số tối ưu hóa quá cao (>5.0px). Ảnh có thể bị sai lệch hoặc thông số camera chưa chính xác.');
    throw Exception('Unknown native error code: $code');
  }
}
