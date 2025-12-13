import 'package:flutter/services.dart';
import 'package:size_estimation/models/bounding_box.dart';
import 'package:size_estimation/models/captured_image.dart';

class YoloObjectDetectionService {
  static const MethodChannel _channel =
      MethodChannel('com.example.size_estimation/arcore');

  Future<void> initialize() async {
    // No initialization needed for MethodChannel, native side inits.
    // However, we could add a check or warm-up call if desired.
  }

  Future<List<BoundingBox>> detectObjects(List<CapturedImage> images) async {
    final allBoxes = <BoundingBox>[];

    for (int i = 0; i < images.length; i++) {
      try {
        final imagePath = images[i].file.path;
        // Call native method
        final List<dynamic>? results = await _channel.invokeMethod(
          'detectObjects',
          {'imagePath': imagePath},
        );

        if (results != null) {
          for (final result in results) {
            final Map<dynamic, dynamic> map = result;
            final Map<dynamic, dynamic> rect = map['rect'];
            final double confidence = map['confidence'] as double;
            final String label = map['label'] as String;

            // Native returns normalized coords (0-1)
            final double x1 = (rect['left'] as num).toDouble();
            final double y1 = (rect['top'] as num).toDouble();
            // width/height from native are normalized widths/heights
            final double w = (rect['width'] as num).toDouble();
            final double h = (rect['height'] as num).toDouble();

            allBoxes.add(BoundingBox(
              x: x1,
              y: y1,
              width: w,
              height: h,
              label: label,
              confidence: confidence,
              imageIndex: i, // We are processing the i-th image
            ));
          }
        }
      } catch (e) {
        print('Error detecting objects in image $i: $e');
      }
    }
    return allBoxes;
  }

  Future<void> dispose() async {
    // Nothing to dispose on Dart side
  }
}
