/// Defines the strict thresholds required for accurate Structure from Motion (SfM)
/// based height estimation.
class PhotogrammetryThresholds {
  // Input Requirements
  static const int minImages = 6;
  static const double minOverlap = 0.70; // 70%
  static const double maxOverlap = 0.80; // 80%

  // Camera Settings (Ideal guidelines)
  static const double minShutterSpeed = 1 / 250; // seconds
  static const double minAperture = 5.6; // f-stop
  static const double maxAperture = 11.0; // f-stop
  static const int minIso = 100;
  static const int maxIso = 400;

  // Geometry
  static const double minBaselineAngleDegrees = 10.0;
  static const double maxBaselineAngleDegrees = 30.0;

  // Post-processing / Quality Checks
  static const int minInliersAfterRansac = 500;
  static const int idealInliersAfterRansac = 1000;

  // Bundle Adjustment Quality
  static const double maxReprojectionErrorPixels = 1.0;
}
