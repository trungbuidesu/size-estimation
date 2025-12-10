import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:size_estimation/models/bounding_box.dart';
import 'package:size_estimation/models/captured_image.dart';

/// Real Object Detection Service using Google ML Kit
/// This replaces MockObjectDetectionService with actual ML-based detection
class MLKitObjectDetectionService {
  ObjectDetector? _detector;
  bool _isInitialized = false;

  /// Initialize the ML Kit object detector
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Use default model (on-device, no custom model needed)
      final options = ObjectDetectorOptions(
        mode: DetectionMode.single, // Process single images
        classifyObjects: true, // Get object labels
        multipleObjects: true, // Detect multiple objects per image
      );

      _detector = ObjectDetector(options: options);
      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize ML Kit Object Detector: $e');
    }
  }

  /// Detect objects in captured images
  Future<List<BoundingBox>> detectObjects(List<CapturedImage> images) async {
    print('[ObjectDetection] Starting detection for ${images.length} images');

    if (!_isInitialized) {
      print('[ObjectDetection] Initializing detector...');
      await initialize();
    }

    if (_detector == null) {
      throw Exception('Object detector not initialized');
    }

    final List<BoundingBox> allBoxes = [];

    for (int i = 0; i < images.length; i++) {
      try {
        print('[ObjectDetection] Processing image $i: ${images[i].file.path}');

        // Create InputImage from file
        final inputImage = InputImage.fromFilePath(images[i].file.path);

        print(
            '[ObjectDetection] Image $i metadata: ${inputImage.metadata?.size}');

        // Detect objects
        final List<DetectedObject> objects =
            await _detector!.processImage(inputImage);

        print('[ObjectDetection] Image $i: Found ${objects.length} objects');

        // Convert to BoundingBox
        for (final obj in objects) {
          // Get the most confident label
          String label = 'unknown';
          double confidence = 0.0;

          if (obj.labels.isNotEmpty) {
            // Sort by confidence and take the best
            final sortedLabels = obj.labels.toList()
              ..sort((a, b) => b.confidence.compareTo(a.confidence));

            label = sortedLabels.first.text;
            confidence = sortedLabels.first.confidence;

            print(
                '[ObjectDetection] Image $i: Detected "$label" with confidence ${(confidence * 100).toStringAsFixed(1)}%');
          }

          // Lower confidence threshold for testing
          if (confidence < 0.3) {
            print(
                '[ObjectDetection] Skipping low confidence detection: $label (${(confidence * 100).toStringAsFixed(1)}%)');
            continue;
          }

          // Get image dimensions
          double imageWidth;
          double imageHeight;

          if (inputImage.metadata?.size != null) {
            imageWidth = inputImage.metadata!.size.width;
            imageHeight = inputImage.metadata!.size.height;
          } else {
            // Fallback: use common mobile camera resolution
            print(
                '[ObjectDetection] Warning: No metadata, using default 1080x1920');
            imageWidth = 1080.0;
            imageHeight = 1920.0;
          }

          // Convert bounding box to normalized coordinates
          final box = BoundingBox(
            x: obj.boundingBox.left / imageWidth,
            y: obj.boundingBox.top / imageHeight,
            width: obj.boundingBox.width / imageWidth,
            height: obj.boundingBox.height / imageHeight,
            label: label,
            confidence: confidence,
            imageIndex: i,
          );

          print(
              '[ObjectDetection] Added box: $label at (${(box.x * 100).toStringAsFixed(1)}%, ${(box.y * 100).toStringAsFixed(1)}%)');
          allBoxes.add(box);
        }
      } catch (e, stackTrace) {
        // Log error but continue with other images
        print('[ObjectDetection] Error detecting objects in image $i: $e');
        print('[ObjectDetection] Stack trace: $stackTrace');
      }
    }

    print('[ObjectDetection] Total boxes detected: ${allBoxes.length}');
    return allBoxes;
  }

  /// Clean up resources
  Future<void> dispose() async {
    if (_detector != null) {
      await _detector!.close();
      _detector = null;
      _isInitialized = false;
    }
  }
}
