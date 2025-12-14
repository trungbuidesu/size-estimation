/// Model for camera intrinsics and metadata

/// Model for camera intrinsics matrix
class IntrinsicMatrix {
  final double fx;
  final double fy;
  final double cx;
  final double cy;
  final double s; // skew parameter (usually 0)

  const IntrinsicMatrix({
    required this.fx,
    required this.fy,
    required this.cx,
    required this.cy,
    this.s = 0.0,
  });

  /// Create 3x3 matrix representation
  List<List<double>> toMatrix() {
    return [
      [fx, s, cx],
      [0, fy, cy],
      [0, 0, 1],
    ];
  }

  @override
  String toString() {
    return 'K = [\n'
        '  [$fx, $s, $cx]\n'
        '  [0, $fy, $cy]\n'
        '  [0, 0, 1]\n'
        ']';
  }

  IntrinsicMatrix copyWith({
    double? fx,
    double? fy,
    double? cx,
    double? cy,
    double? s,
  }) {
    return IntrinsicMatrix(
      fx: fx ?? this.fx,
      fy: fy ?? this.fy,
      cx: cx ?? this.cx,
      cy: cy ?? this.cy,
      s: s ?? this.s,
    );
  }
}

/// Model for crop region from SCALER_CROP_REGION
class CropRegion {
  final int x0;
  final int y0;
  final int width;
  final int height;

  const CropRegion({
    required this.x0,
    required this.y0,
    required this.width,
    required this.height,
  });

  factory CropRegion.fromList(List<dynamic> rect) {
    if (rect.length != 4) {
      throw ArgumentError(
          'CropRegion requires 4 values: [left, top, right, bottom]');
    }
    final left = rect[0] as int;
    final top = rect[1] as int;
    final right = rect[2] as int;
    final bottom = rect[3] as int;

    return CropRegion(
      x0: left,
      y0: top,
      width: right - left,
      height: bottom - top,
    );
  }

  @override
  String toString() {
    return 'CropRegion(x0: $x0, y0: $y0, w: $width, h: $height)';
  }
}

/// Model for active array size
class ActiveArraySize {
  final int width;
  final int height;

  const ActiveArraySize({
    required this.width,
    required this.height,
  });

  factory ActiveArraySize.fromMap(Map<dynamic, dynamic> map) {
    return ActiveArraySize(
      width: (map['right'] as int) - (map['left'] as int),
      height: (map['bottom'] as int) - (map['top'] as int),
    );
  }

  @override
  String toString() {
    return 'ActiveArray(${width}x$height)';
  }
}

/// Complete camera metadata for computing dynamic intrinsics
class CameraMetadata {
  final IntrinsicMatrix
      sensorIntrinsics; // fx_s, fy_s, cx_s, cy_s on active array
  final ActiveArraySize activeArraySize; // W_s, H_s
  final CropRegion? cropRegion; // from SCALER_CROP_REGION (can be null)
  final int outputWidth; // W_out
  final int outputHeight; // H_out
  final List<double>? distortionCoefficients; // [k1, k2, p1, p2, k3]

  const CameraMetadata({
    required this.sensorIntrinsics,
    required this.activeArraySize,
    this.cropRegion,
    required this.outputWidth,
    required this.outputHeight,
    this.distortionCoefficients,
  });

  /// Compute output intrinsics K_out from sensor intrinsics and crop/scale
  IntrinsicMatrix computeOutputIntrinsics() {
    // If no crop region, assume full sensor is used
    final crop = cropRegion ??
        CropRegion(
          x0: 0,
          y0: 0,
          width: activeArraySize.width,
          height: activeArraySize.height,
        );

    // Step 1: Adjust principal point for crop
    final cx_c = sensorIntrinsics.cx - crop.x0;
    final cy_c = sensorIntrinsics.cy - crop.y0;

    // Step 2: Compute scale factors from crop to output
    final scaleX = outputWidth / crop.width;
    final scaleY = outputHeight / crop.height;

    // Step 3: Scale focal lengths and principal point
    final fx_out = sensorIntrinsics.fx * scaleX;
    final fy_out = sensorIntrinsics.fy * scaleY;
    final cx_out = cx_c * scaleX;
    final cy_out = cy_c * scaleY;

    return IntrinsicMatrix(
      fx: fx_out,
      fy: fy_out,
      cx: cx_out,
      cy: cy_out,
      s: sensorIntrinsics.s,
    );
  }

  @override
  String toString() {
    return 'CameraMetadata(\n'
        '  Sensor K: $sensorIntrinsics\n'
        '  Active Array: $activeArraySize\n'
        '  Crop: $cropRegion\n'
        '  Output: ${outputWidth}x$outputHeight\n'
        '  Distortion: ${distortionCoefficients ?? "None"}\n'
        ')';
  }
}
