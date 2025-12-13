import 'package:size_estimation/constants/image_quality_threshold.dart';

/// Legacy class, redirecting to ImageQualityThresholds
class PhotogrammetryThresholds {
  static const int minImages = ImageQualityThresholds.minImages;
  static const double minOverlap = ImageQualityThresholds.minOverlap;
  static const double maxOverlap = ImageQualityThresholds.maxOverlap;

  static const int minInliersAfterRansac = ImageQualityThresholds.minInliers;
  static const double maxReprojectionErrorPixels =
      ImageQualityThresholds.maxReprojectionError;
}
