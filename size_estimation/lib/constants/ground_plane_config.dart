class GroundPlaneConfig {
  /// Maximum tilt degrees allowed for orientation suitability check
  static const double maxTiltDegrees = 10.0;

  /// Pixel uncertainty for base error estimation
  static const double pixelUncertainty = 2.0;

  /// Factor for distance error scaling
  static const double distanceErrorDivider = 10.0;

  /// Factor for pitch error scaling
  static const double pitchErrorDivider = 45.0;

  /// Minimum error clamp value in cm
  static const double minErrorClampCm = 0.5;

  /// Maximum error clamp value in cm
  static const double maxErrorClampCm = 50.0;

  /// Point at infinity vector value
  static const double infinityPointValue = 1000.0;

  /// Epsilon for zero division check
  static const double zeroEpsilon = 1e-10;
}
