import 'dart:ui';

/// Represents a detected object's bounding box in an image
class BoundingBox {
  /// Normalized x coordinate (0-1) of top-left corner
  final double x;

  /// Normalized y coordinate (0-1) of top-left corner
  final double y;

  /// Normalized width (0-1)
  final double width;

  /// Normalized height (0-1)
  final double height;

  /// Object class label (e.g., "person", "bottle", "chair")
  final String label;

  /// Detection confidence score (0-1)
  final double confidence;

  /// Index of the image this box belongs to (0-5)
  final int imageIndex;

  const BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.label,
    required this.confidence,
    required this.imageIndex,
  });

  /// Create from JSON (for FFI deserialization)
  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      label: json['label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      imageIndex: json['imageIndex'] as int,
    );
  }

  /// Convert to JSON (for FFI serialization)
  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'label': label,
      'confidence': confidence,
      'imageIndex': imageIndex,
    };
  }

  /// Convert normalized coordinates to pixel coordinates
  Rect toPixelRect(Size imageSize) {
    return Rect.fromLTWH(
      x * imageSize.width,
      y * imageSize.height,
      width * imageSize.width,
      height * imageSize.height,
    );
  }

  /// Get center point in normalized coordinates
  Offset get center => Offset(x + width / 2, y + height / 2);

  /// Calculate IoU (Intersection over Union) with another box
  double iou(BoundingBox other) {
    final x1 = x.clamp(0.0, 1.0);
    final y1 = y.clamp(0.0, 1.0);
    final x2 = (x + width).clamp(0.0, 1.0);
    final y2 = (y + height).clamp(0.0, 1.0);

    final ox1 = other.x.clamp(0.0, 1.0);
    final oy1 = other.y.clamp(0.0, 1.0);
    final ox2 = (other.x + other.width).clamp(0.0, 1.0);
    final oy2 = (other.y + other.height).clamp(0.0, 1.0);

    final intersectX1 = x1 > ox1 ? x1 : ox1;
    final intersectY1 = y1 > oy1 ? y1 : oy1;
    final intersectX2 = x2 < ox2 ? x2 : ox2;
    final intersectY2 = y2 < oy2 ? y2 : oy2;

    if (intersectX1 >= intersectX2 || intersectY1 >= intersectY2) {
      return 0.0;
    }

    final intersectArea =
        (intersectX2 - intersectX1) * (intersectY2 - intersectY1);
    final area1 = (x2 - x1) * (y2 - y1);
    final area2 = (ox2 - ox1) * (oy2 - oy1);
    final unionArea = area1 + area2 - intersectArea;

    return unionArea > 0 ? intersectArea / unionArea : 0.0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoundingBox &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          width == other.width &&
          height == other.height &&
          label == other.label &&
          imageIndex == other.imageIndex;

  @override
  int get hashCode =>
      x.hashCode ^
      y.hashCode ^
      width.hashCode ^
      height.hashCode ^
      label.hashCode ^
      imageIndex.hashCode;

  @override
  String toString() {
    return 'BoundingBox(label: $label, conf: ${(confidence * 100).toStringAsFixed(1)}%, '
        'img: $imageIndex, rect: ($x, $y, $width, $height))';
  }
}
