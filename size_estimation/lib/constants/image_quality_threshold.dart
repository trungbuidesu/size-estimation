class ImageQualityThresholds {
  // Stability Check
  static const double maxRollDeviation = 15.0; // degrees
  static const double minStabilityScore = 0.3; // 0.0 to 1.0
  static const double maxMotionMagnitude = 2.0; // m/s^2

  // Photogrammetry / Feature Matching (Relaxed for Smartphone)
  static const int minImages = 6; // Minimum valid pairs needed
  static const int minInliers = 30; // RANSAC inliers
  static const double maxReprojectionError = 5.0; // pixels
  static const int minFeatures = 50; // SIFT keypoints
  static const int minMatches = 10; // Good matches after filtering

  // Overlap & Geometry
  static const double minOverlap = 0.30; // 30% overlap sufficient
  static const double maxOverlap = 0.95;
  static const double minBaselineAngle = 2.0; // degrees
}
