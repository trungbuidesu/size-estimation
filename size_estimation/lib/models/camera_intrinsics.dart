class CameraIntrinsics {
  final double focalLength; // In pixels (often (fx + fy) / 2)
  final double cx; // Principal point x
  final double cy; // Principal point y
  final double sensorWidth; // In mm, optional/helper
  final double sensorHeight; // In mm, optional/helper
  final List<double> distortionCoefficients; // [k1, k2, p1, p2, k3]

  CameraIntrinsics({
    required this.focalLength,
    required this.cx,
    required this.cy,
    this.sensorWidth = 0.0,
    this.sensorHeight = 0.0,
    this.distortionCoefficients = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'focalLength': focalLength,
      'cx': cx,
      'cy': cy,
      'sensorWidth': sensorWidth,
      'sensorHeight': sensorHeight,
      'distortionCoefficients': distortionCoefficients,
    };
  }

  factory CameraIntrinsics.fromMap(Map<String, dynamic> map) {
    return CameraIntrinsics(
      focalLength: (map['focalLength'] as num).toDouble(),
      cx: (map['cx'] as num).toDouble(),
      cy: (map['cy'] as num).toDouble(),
      sensorWidth: (map['sensorWidth'] as num).toDouble(),
      sensorHeight: (map['sensorHeight'] as num).toDouble(),
      distortionCoefficients: List<double>.from(map['distortionCoefficients']),
    );
  }
}
