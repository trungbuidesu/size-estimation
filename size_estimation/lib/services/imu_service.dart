import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

/// IMU orientation data with rotation matrix
class IMUOrientation {
  final double roll; // Rotation around X-axis (radians)
  final double pitch; // Rotation around Y-axis (radians)
  final double yaw; // Rotation around Z-axis (radians)
  final vm.Matrix3 rotationMatrix; // 3x3 rotation matrix R
  final vm.Vector3 gravity; // Gravity vector

  const IMUOrientation({
    required this.roll,
    required this.pitch,
    required this.yaw,
    required this.rotationMatrix,
    required this.gravity,
  });

  /// Get rotation matrix as 3x3 list
  List<List<double>> getRotationMatrixAsList() {
    return [
      [rotationMatrix[0], rotationMatrix[1], rotationMatrix[2]],
      [rotationMatrix[3], rotationMatrix[4], rotationMatrix[5]],
      [rotationMatrix[6], rotationMatrix[7], rotationMatrix[8]],
    ];
  }

  /// Convert to degrees for display
  double get rollDegrees => roll * 180 / pi;
  double get pitchDegrees => pitch * 180 / pi;
  double get yawDegrees => yaw * 180 / pi;

  @override
  String toString() {
    return 'IMUOrientation(\n'
        '  Roll: ${rollDegrees.toStringAsFixed(2)}°\n'
        '  Pitch: ${pitchDegrees.toStringAsFixed(2)}°\n'
        '  Yaw: ${yawDegrees.toStringAsFixed(2)}°\n'
        '  Gravity: ${gravity.toString()}\n'
        ')';
  }
}

/// Service to get IMU data with complementary filter
class IMUService {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  final _orientationController = StreamController<IMUOrientation>.broadcast();
  Stream<IMUOrientation> get orientationStream => _orientationController.stream;

  IMUOrientation? _currentOrientation;
  IMUOrientation? get currentOrientation => _currentOrientation;

  // Complementary filter parameters
  static const double alpha =
      0.98; // Weight for gyroscope (0.98 = 98% gyro, 2% accel)
  static const double dt = 0.02; // Assumed update rate ~50Hz

  // Current state (radians)
  double _roll = 0.0;
  double _pitch = 0.0;
  double _yaw = 0.0;

  // Gravity vector (from accelerometer)
  vm.Vector3 _gravity = vm.Vector3(0, 0, 9.81);

  // Gyroscope integration
  DateTime? _lastGyroTime;

  void startListening() {
    // Listen to accelerometer for gravity and tilt
    _accelSub = accelerometerEventStream().listen((event) {
      _updateFromAccelerometer(event);
    });

    // Listen to gyroscope for rotation rate
    _gyroSub = gyroscopeEventStream().listen((event) {
      _updateFromGyroscope(event);
    });

    // Optional: Magnetometer for yaw correction
    _magSub = magnetometerEventStream().listen((event) {
      _updateFromMagnetometer(event);
    });
  }

  void _updateFromAccelerometer(AccelerometerEvent event) {
    // Update gravity vector
    _gravity = vm.Vector3(event.x, event.y, event.z);

    // Calculate roll and pitch from accelerometer
    // Roll (rotation around X-axis)
    final rollAccel = atan2(event.y, event.z);

    // Pitch (rotation around Y-axis)
    final pitchAccel =
        atan2(-event.x, sqrt(event.y * event.y + event.z * event.z));

    // Apply complementary filter (low-pass for accel)
    _roll = alpha * _roll + (1 - alpha) * rollAccel;
    _pitch = alpha * _pitch + (1 - alpha) * pitchAccel;

    _emitOrientation();
  }

  void _updateFromGyroscope(GyroscopeEvent event) {
    final now = DateTime.now();

    if (_lastGyroTime != null) {
      final dt = now.difference(_lastGyroTime!).inMicroseconds / 1000000.0;

      // Integrate gyroscope data (high-pass filter)
      _roll += event.x * dt;
      _pitch += event.y * dt;
      _yaw += event.z * dt;

      // Normalize angles to -π to π
      _roll = _normalizeAngle(_roll);
      _pitch = _normalizeAngle(_pitch);
      _yaw = _normalizeAngle(_yaw);
    }

    _lastGyroTime = now;
  }

  void _updateFromMagnetometer(MagnetometerEvent event) {
    // Optional: Use magnetometer to correct yaw drift
    // For now, we'll keep it simple and just use gyro for yaw
    // In production, you'd want to fuse magnetometer data here
  }

  double _normalizeAngle(double angle) {
    while (angle > pi) angle -= 2 * pi;
    while (angle < -pi) angle += 2 * pi;
    return angle;
  }

  void _emitOrientation() {
    // Compute rotation matrix from roll, pitch, yaw (ZYX Euler angles)
    final rotationMatrix = _computeRotationMatrix(_roll, _pitch, _yaw);

    _currentOrientation = IMUOrientation(
      roll: _roll,
      pitch: _pitch,
      yaw: _yaw,
      rotationMatrix: rotationMatrix,
      gravity: _gravity,
    );

    _orientationController.add(_currentOrientation!);
  }

  /// Compute rotation matrix from Euler angles (ZYX convention)
  /// R = Rz(yaw) * Ry(pitch) * Rx(roll)
  vm.Matrix3 _computeRotationMatrix(double roll, double pitch, double yaw) {
    final cr = cos(roll);
    final sr = sin(roll);
    final cp = cos(pitch);
    final sp = sin(pitch);
    final cy = cos(yaw);
    final sy = sin(yaw);

    // Rotation matrix (ZYX Euler)
    return vm.Matrix3(
      cy * cp,
      cy * sp * sr - sy * cr,
      cy * sp * cr + sy * sr,
      sy * cp,
      sy * sp * sr + cy * cr,
      sy * sp * cr - cy * sr,
      -sp,
      cp * sr,
      cp * cr,
    );
  }

  /// Get rotation matrix for camera (world to camera transform)
  /// This is the R matrix used in camera projection: p = K[R|t]P
  vm.Matrix3 getCameraRotationMatrix() {
    if (_currentOrientation == null) {
      return vm.Matrix3.identity();
    }
    return _currentOrientation!.rotationMatrix;
  }

  /// Check if device is approximately level (for ground plane measurements)
  bool isDeviceLevel({double toleranceDegrees = 5.0}) {
    if (_currentOrientation == null) return false;

    final rollDeg = _currentOrientation!.rollDegrees.abs();
    final pitchDeg = _currentOrientation!.pitchDegrees.abs();

    return rollDeg < toleranceDegrees && pitchDeg < toleranceDegrees;
  }

  void stopListening() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _magSub?.cancel();
  }

  void dispose() {
    stopListening();
    _orientationController.close();
  }
}
