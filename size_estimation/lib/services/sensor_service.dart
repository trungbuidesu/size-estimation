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
  static const double maxUserAccel =
      2.0; // m/s^2 threshold for "moving" (Increased from 0.3)
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
      // Calculate Roll (Tilt Left/Right) relative to gravity
      // atan2(x, y) gives angle of device vector in plane perpendicular to screen (roughly)
      // if device is flat, this is noisy/undefined, but we care when user holds it up.

      double angle = atan2(event.x, event.y) * 180 / pi;

      // We want deviation from the nearest 90-degree step (Portrait, Landscape Left/Right, Upside Down)
      // angle is -180 to 180.
      // Modulo 90 logic:

      // Calculate deviation from nearest vertical/horizontal axis
      // 0 = Upright, 90 = Landscape Left, -90 = Landscape Right, 180 = Upside down

      double currentRoll = 0;

      // Normalize to -45 to 45 range
      // First, get it to 0-90 range essentially
      // But we need signed deviation

      if (angle > 135) {
        currentRoll = angle - 180;
      } else if (angle < -135) {
        currentRoll = angle + 180;
      } else if (angle > 45) {
        currentRoll = angle - 90;
      } else if (angle < -45) {
        currentRoll = angle + 90;
      } else {
        currentRoll = angle; // -45 to 45
      }

      // Invert for intuitive "tilt left/right"
      // currentRoll = -currentRoll;

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
