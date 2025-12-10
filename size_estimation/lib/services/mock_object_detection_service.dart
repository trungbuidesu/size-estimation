import 'dart:math' as math;
import 'package:size_estimation/models/bounding_box.dart';
import 'package:size_estimation/models/captured_image.dart';

/// Mock Object Detection Service for testing UI flow
/// This simulates ML-based object detection without actual TensorFlow Lite
/// Will be replaced with real implementation later
class MockObjectDetectionService {
  final math.Random _random = math.Random();

  /// Simulate object detection on captured images
  /// Returns realistic bounding boxes as if detected by ML model
  Future<List<BoundingBox>> detectObjects(List<CapturedImage> images) async {
    // Simulate processing delay (realistic for ML inference)
    await Future.delayed(Duration(milliseconds: 500 + _random.nextInt(500)));

    final List<BoundingBox> allBoxes = [];

    // Simulate detecting a consistent object across most images
    // This mimics a real scenario where user is photographing a specific object
    final targetLabel = _getRandomTargetObject();

    for (int i = 0; i < images.length; i++) {
      // 90% chance the target object appears in each image
      if (_random.nextDouble() < 0.9) {
        // Add target object with slight position variation
        allBoxes.add(_generateBox(
          imageIndex: i,
          label: targetLabel,
          confidence: 0.85 + _random.nextDouble() * 0.1,
          centerX: 0.45 + _random.nextDouble() * 0.1,
          centerY: 0.4 + _random.nextDouble() * 0.2,
        ));
      }

      // Add 1-2 random background objects
      final numBgObjects = _random.nextInt(2) + 1;
      for (int j = 0; j < numBgObjects; j++) {
        if (_random.nextDouble() < 0.6) {
          allBoxes.add(_generateBox(
            imageIndex: i,
            label: _getRandomBackgroundObject(),
            confidence: 0.6 + _random.nextDouble() * 0.2,
            centerX: _random.nextDouble(),
            centerY: _random.nextDouble(),
          ));
        }
      }
    }

    return allBoxes;
  }

  /// Generate a bounding box with realistic parameters
  BoundingBox _generateBox({
    required int imageIndex,
    required String label,
    required double confidence,
    required double centerX,
    required double centerY,
  }) {
    // Realistic object sizes (normalized)
    final width = 0.15 + _random.nextDouble() * 0.15; // 15-30%
    final height = 0.2 + _random.nextDouble() * 0.3; // 20-50%

    // Calculate top-left from center
    final x = (centerX - width / 2).clamp(0.0, 1.0 - width);
    final y = (centerY - height / 2).clamp(0.0, 1.0 - height);

    return BoundingBox(
      x: x,
      y: y,
      width: width,
      height: height,
      label: label,
      confidence: confidence,
      imageIndex: imageIndex,
    );
  }

  String _getRandomTargetObject() {
    final objects = [
      'bottle',
      'cup',
      'laptop',
      'book',
      'phone',
      'keyboard',
      'mouse',
      'vase',
      'clock',
      'potted plant',
    ];
    return objects[_random.nextInt(objects.length)];
  }

  String _getRandomBackgroundObject() {
    final objects = [
      'person',
      'chair',
      'table',
      'monitor',
      'backpack',
      'handbag',
    ];
    return objects[_random.nextInt(objects.length)];
  }

  /// Simulate detection with predefined scenario (for consistent testing)
  Future<List<BoundingBox>> detectObjectsWithScenario(
    List<CapturedImage> images,
    String targetObject,
  ) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final List<BoundingBox> allBoxes = [];

    for (int i = 0; i < images.length; i++) {
      // Target object appears in all images with slight variation
      allBoxes.add(BoundingBox(
        x: 0.35 + (i * 0.02), // Slight horizontal shift
        y: 0.25 + (i * 0.01), // Slight vertical shift
        width: 0.18,
        height: 0.42,
        label: targetObject,
        confidence: 0.88 + (i * 0.01),
        imageIndex: i,
      ));

      // Add some background objects occasionally
      if (i % 2 == 0) {
        allBoxes.add(BoundingBox(
          x: 0.7,
          y: 0.1,
          width: 0.2,
          height: 0.5,
          label: 'person',
          confidence: 0.75,
          imageIndex: i,
        ));
      }
    }

    return allBoxes;
  }
}
