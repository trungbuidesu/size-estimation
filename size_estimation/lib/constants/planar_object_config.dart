import 'dart:math' as math;

class PlanarObjectConfig {
  /// Estimated distance from camera in meters (used when no reference size provided)
  static const double estimatedDistanceMeters = 0.5;

  /// Epsilon for zero division check
  static const double zeroEpsilon = 1e-10;

  /// Uncertainty in corner detection in pixels
  static const double cornerUncertainty = 3.0;

  /// Estimated dimension of the object in cm, for error scaling
  static const double estimatedDimensionCm = 20.0;

  /// Base adjustment factor if a reference size is provided (reduces error)
  static const double referenceBonusFactor = 0.5;

  /// Base adjustment factor if NO reference size is provided (full error)
  static const double noReferencePenaltyFactor = 1.0;

  /// Minimum error clamp value in cm
  static const double minErrorClampCm = 0.5;

  /// Maximum error clamp value in cm
  static const double maxErrorClampCm = 10.0;

  /// Common reference object sizes in centimeters
  static const Map<String, Map<String, double>> referenceSizes = {
    'A4 Paper': {'width': 21.0, 'height': 29.7},
    'A5 Paper': {'width': 14.8, 'height': 21.0},
    'Letter Paper': {'width': 21.6, 'height': 27.9},
    'Credit Card': {'width': 8.56, 'height': 5.398},
    'iPhone 14': {'width': 7.15, 'height': 14.67},
    'iPad': {'width': 17.78, 'height': 25.05},
  };

  /// Ideal angle for perspective distortion calculation (90 degrees in radians)
  static const double idealAngleRad = math.pi / 2;

  /// Normalization factor for angle deviation (45 degrees in radians)
  static const double angleNormalizationFactor = math.pi / 4;
}
