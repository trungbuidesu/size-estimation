import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class StabilityMetrics {
  final double stabilityScore; // 0.0 to 1.0 (1.0 = stable)
  final bool isLevel; // True if roll is within tolerance
  final double rollDegrees;
  final bool isStable; // True if score > threshold

  StabilityMetrics({
    required this.stabilityScore,
    required this.isLevel,
    required this.rollDegrees,
    required this.isStable,
  });
}

class SensorService {
  StreamSubscription<UserAccelerometerEvent>? _userAccelSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  final _controller = StreamController<StabilityMetrics>.broadcast();
  Stream<StabilityMetrics> get stabilityStream => _controller.stream;

  // Thresholds
  static const double maxUserAccel = 0.3; // m/s^2 threshold for "moving"
  static const double maxRollDegrees = 5.0; // degrees

  // Current state
  double _currentStability = 1.0;

  void startListening() {
    _userAccelSub = userAccelerometerEventStream().listen((event) {
      // Calculate magnitude of movement (ignoring gravity)
      double magnitude =
          sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

      // Normalize to 0.0 - 1.0 score
      // If magnitude 0 -> score 1.
      // If magnitude > maxUserAccel -> score drops.
      double rawScore = 1.0 - (magnitude / maxUserAccel).clamp(0.0, 1.0);

      // Smooth the score
      _currentStability = _currentStability * 0.8 + rawScore * 0.2;
    });

    _accelSub = accelerometerEventStream().listen((event) {
      // Calculate Roll (Tilt Left/Right)
      // Assuming Portrait Mode: Gravity is mostly on Y axis. Breakdown on X indicates roll.
      // roll = atan2(x, y)
      // conversion to degrees
      double rollRadians = atan2(event.x, event.y);
      double rollDegrees = rollRadians * 180 / pi;

      // Adjust for typical holding:
      // If upright, x=0, y=9.8. atan2(0, 9.8) = 0.
      // If tilted right, x<0.
      // Actually standard: y is up on screen?
      // Let's use simple abs(x) check for "levelness" relative to gravity.
      // If phone is flat (z=9.8), x and y are 0.
      // If phone is upright (y=9.8), x and z are 0.
      // In any "photo taking" pose, X should be minimal (horizontal level).

      // Re-calculating roll strictly from X gravity component
      // sin(angle) = x / g.  angle = asin(x/g).
      // g approx 9.8.
      double xNorm = (event.x / 9.81).clamp(-1.0, 1.0);
      double currentRoll = asin(xNorm) * 180 / pi; // -90 to 90

      // Only emit if we have user accel data processed too (merged in controller add)
      // For simplicity, we emit on every accel event using latest stability
      _emit(currentRoll);
    });
  }

  void _emit(double currentRoll) {
    bool isLevel = currentRoll.abs() <= maxRollDegrees;
    bool isStable = _currentStability > 0.7; // Strict threshold

    _controller.add(StabilityMetrics(
      stabilityScore: _currentStability,
      isLevel: isLevel,
      rollDegrees: currentRoll,
      isStable: isStable,
    ));
  }

  void stopListening() {
    _userAccelSub?.cancel();
    _accelSub?.cancel();
  }

  void dispose() {
    stopListening();
    _controller.close();
  }
}
