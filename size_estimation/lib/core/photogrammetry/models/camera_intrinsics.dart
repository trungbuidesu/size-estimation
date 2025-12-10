class CameraIntrinsics {
  final double focalLength; // In pixels (often (fx + fy) / 2)
  final double cx; // Principal point x
  final double cy; // Principal point y
  final double sensorWidth; // In mm, optional/helper
  final double sensorHeight; // In mm, optional/helper

  CameraIntrinsics({
    required this.focalLength,
    required this.cx,
    required this.cy,
    this.sensorWidth = 0.0,
    this.sensorHeight = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'focalLength': focalLength,
      'cx': cx,
      'cy': cy,
      'sensorWidth': sensorWidth,
      'sensorHeight': sensorHeight,
    };
  }
}
