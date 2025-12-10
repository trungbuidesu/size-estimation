# Object Detection Integration for SfM Enhancement - Implementation Plan

## Overview
Integrate object detection to improve SfM accuracy by constraining feature matching to user-confirmed target objects.

## Phase 1: Native Layer - Object Detection API

### 1.1 Add TensorFlow Lite Dependencies

**Android (android/app/build.gradle):**
```gradle
dependencies {
    implementation 'org.tensorflow:tensorflow-lite:2.14.0'
    implementation 'org.tensorflow:tensorflow-lite-support:0.4.4'
    implementation 'org.tensorflow:tensorflow-lite-gpu:2.14.0'
}
```

**iOS (ios/Podfile):**
```ruby
pod 'TensorFlowLiteSwift', '~> 2.14.0'
```

### 1.2 Add Object Detection Model

**Download Model:**
- Use MobileNet SSD v2 (COCO dataset) - lightweight, ~4MB
- Place in: `android/app/src/main/assets/ssd_mobilenet_v2.tflite`
- Place in: `ios/Runner/Models/ssd_mobilenet_v2.tflite`

**Labels file:**
- `coco_labels.txt` with 80 common object classes

### 1.3 Create Native Object Detection Function

**File: `android/app/src/main/cpp/object_detector.h`**
```cpp
#ifndef OBJECT_DETECTOR_H
#define OBJECT_DETECTOR_H

#include <string>
#include <vector>

struct BoundingBox {
    float x;      // Top-left x (normalized 0-1)
    float y;      // Top-left y (normalized 0-1)
    float width;  // Width (normalized 0-1)
    float height; // Height (normalized 0-1)
    std::string label;
    float confidence;
    int imageIndex; // Which image (0-5)
};

class ObjectDetector {
public:
    ObjectDetector();
    ~ObjectDetector();
    
    bool initialize(const std::string& modelPath);
    std::vector<BoundingBox> detectObjects(const std::vector<std::string>& imagePaths);
    
private:
    // TFLite interpreter instance
    void* interpreter; // Use void* to avoid exposing TFLite headers
};

#endif // OBJECT_DETECTOR_H
```

**File: `android/app/src/main/cpp/object_detector.cpp`**
```cpp
#include "object_detector.h"
#include <tensorflow/lite/interpreter.h>
#include <tensorflow/lite/kernels/register.h>
#include <tensorflow/lite/model.h>
#include <opencv2/opencv.hpp>

ObjectDetector::ObjectDetector() : interpreter(nullptr) {}

ObjectDetector::~ObjectDetector() {
    // Cleanup TFLite resources
}

bool ObjectDetector::initialize(const std::string& modelPath) {
    // Load TFLite model
    // Create interpreter
    // Allocate tensors
    // Return success/failure
    return true;
}

std::vector<BoundingBox> ObjectDetector::detectObjects(
    const std::vector<std::string>& imagePaths) {
    
    std::vector<BoundingBox> allBoxes;
    
    for (size_t i = 0; i < imagePaths.size(); i++) {
        // Load image with OpenCV
        cv::Mat image = cv::imread(imagePaths[i]);
        if (image.empty()) continue;
        
        // Preprocess: resize to 300x300, normalize
        cv::Mat resized;
        cv::resize(image, resized, cv::Size(300, 300));
        
        // Convert to RGB float tensor
        // Run inference
        // Parse output tensors (boxes, classes, scores)
        
        // Filter by confidence > 0.5
        // Convert to BoundingBox structs
        
        // Example output (mock):
        BoundingBox box;
        box.x = 0.2f;
        box.y = 0.3f;
        box.width = 0.4f;
        box.height = 0.5f;
        box.label = "person";
        box.confidence = 0.85f;
        box.imageIndex = i;
        
        allBoxes.push_back(box);
    }
    
    return allBoxes;
}
```

### 1.4 Update FFI Bindings

**File: `lib/services/photogrammetry_bindings.dart`**

Add new FFI function:
```dart
// Detect objects in images
typedef DetectObjectsNative = Pointer<Utf8> Function(
  Pointer<Pointer<Utf8>> imagePaths,
  Int32 imageCount
);

typedef DetectObjectsDart = Pointer<Utf8> Function(
  Pointer<Pointer<Utf8>> imagePaths,
  int imageCount
);

// In PhotogrammetryBindings class:
late final DetectObjectsDart detectObjects;

// In constructor:
detectObjects = _dylib
    .lookup<NativeFunction<DetectObjectsNative>>('detect_objects')
    .asFunction();
```

**Native C++ Export:**
```cpp
// In photogrammetry_native.cpp
extern "C" {
    const char* detect_objects(const char** image_paths, int image_count) {
        ObjectDetector detector;
        detector.initialize("/path/to/model.tflite");
        
        std::vector<std::string> paths;
        for (int i = 0; i < image_count; i++) {
            paths.push_back(image_paths[i]);
        }
        
        auto boxes = detector.detectObjects(paths);
        
        // Serialize to JSON
        std::string json = serializeBoxesToJson(boxes);
        return strdup(json.c_str());
    }
}
```

## Phase 2: Dart Models

**File: `lib/models/bounding_box.dart`**
```dart
class BoundingBox {
  final double x;      // Normalized 0-1
  final double y;
  final double width;
  final double height;
  final String label;
  final double confidence;
  final int imageIndex;

  BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.label,
    required this.confidence,
    required this.imageIndex,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      x: json['x'],
      y: json['y'],
      width: json['width'],
      height: json['height'],
      label: json['label'],
      confidence: json['confidence'],
      imageIndex: json['imageIndex'],
    );
  }

  // Convert to pixel coordinates
  Rect toPixelRect(Size imageSize) {
    return Rect.fromLTWH(
      x * imageSize.width,
      y * imageSize.height,
      width * imageSize.width,
      height * imageSize.height,
    );
  }
}
```

## Phase 3: Service Layer Updates

**File: `lib/services/photogrammetry_service.dart`**

Add object detection method:
```dart
class PhotogrammetryService {
  final PhotogrammetryBindings _bindings = PhotogrammetryBindings();

  Future<List<BoundingBox>> detectObjects(List<File> images) async {
    return compute(_detectObjectsIsolate, images.map((f) => f.path).toList());
  }

  static Future<List<BoundingBox>> _detectObjectsIsolate(List<String> imagePaths) async {
    final bindings = PhotogrammetryBindings();
    
    // Convert paths to native pointer array
    final pathsPointer = // ... FFI conversion
    
    final resultJson = bindings.detectObjects(pathsPointer, imagePaths.length);
    final jsonString = resultJson.toDartString();
    
    // Parse JSON
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((j) => BoundingBox.fromJson(j)).toList();
  }

  // Update existing method signature
  Future<double> estimateHeightFromBaseline({
    required List<File> images,
    required double knownBaselineCm,
    required CameraIntrinsics intrinsics,
    List<BoundingBox>? selectedBoxes, // NEW PARAMETER
  }) async {
    // ... existing code
    
    // Pass selectedBoxes to native if provided
    // Modify FFI call to include bounding box data
  }
}
```

## Phase 4: UI Components

### 4.1 Object Selection Widget

**File: `lib/views/camera_screen/components/object_selection_dialog.dart`**
```dart
class ObjectSelectionDialog extends StatefulWidget {
  final List<CapturedImage> images;
  final List<BoundingBox> detectedBoxes;
  final Function(List<BoundingBox>) onConfirm;

  const ObjectSelectionDialog({
    required this.images,
    required this.detectedBoxes,
    required this.onConfirm,
  });

  @override
  State<ObjectSelectionDialog> createState() => _ObjectSelectionDialogState();
}

class _ObjectSelectionDialogState extends State<ObjectSelectionDialog> {
  Set<int> selectedBoxIndices = {};
  int currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            AppBar(
              title: Text('Chọn vật thể cần đo'),
              actions: [
                TextButton(
                  onPressed: _confirmSelection,
                  child: Text('Xác nhận'),
                )
              ],
            ),
            
            // Image viewer with bounding boxes
            Expanded(
              child: Stack(
                children: [
                  // Image
                  Image.file(
                    widget.images[currentImageIndex].file,
                    fit: BoxFit.contain,
                  ),
                  
                  // Bounding boxes overlay
                  CustomPaint(
                    painter: BoundingBoxPainter(
                      boxes: _getBoxesForCurrentImage(),
                      selectedIndices: selectedBoxIndices,
                      onBoxTap: _toggleBoxSelection,
                    ),
                  ),
                ],
              ),
            ),
            
            // Image navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: currentImageIndex > 0 
                    ? () => setState(() => currentImageIndex--)
                    : null,
                ),
                Text('${currentImageIndex + 1} / ${widget.images.length}'),
                IconButton(
                  icon: Icon(Icons.arrow_forward),
                  onPressed: currentImageIndex < widget.images.length - 1
                    ? () => setState(() => currentImageIndex++)
                    : null,
                ),
              ],
            ),
            
            // Detected objects list
            Container(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _getBoxesForCurrentImage().length,
                itemBuilder: (context, index) {
                  final box = _getBoxesForCurrentImage()[index];
                  final isSelected = selectedBoxIndices.contains(box.hashCode);
                  
                  return GestureDetector(
                    onTap: () => _toggleBoxSelection(box),
                    child: Container(
                      margin: EdgeInsets.all(8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue : Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _getIconForLabel(box.label),
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                          Text(
                            box.label,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                            ),
                          ),
                          Text(
                            '${(box.confidence * 100).toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<BoundingBox> _getBoxesForCurrentImage() {
    return widget.detectedBoxes
        .where((box) => box.imageIndex == currentImageIndex)
        .toList();
  }

  void _toggleBoxSelection(BoundingBox box) {
    setState(() {
      if (selectedBoxIndices.contains(box.hashCode)) {
        selectedBoxIndices.remove(box.hashCode);
      } else {
        selectedBoxIndices.add(box.hashCode);
      }
    });
  }

  void _confirmSelection() {
    final selectedBoxes = widget.detectedBoxes
        .where((box) => selectedBoxIndices.contains(box.hashCode))
        .toList();
    
    if (selectedBoxes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng chọn ít nhất một vật thể')),
      );
      return;
    }
    
    widget.onConfirm(selectedBoxes);
    Navigator.pop(context);
  }

  IconData _getIconForLabel(String label) {
    // Map common labels to icons
    switch (label.toLowerCase()) {
      case 'person': return Icons.person;
      case 'bottle': return Icons.local_drink;
      case 'cup': return Icons.coffee;
      case 'chair': return Icons.chair;
      default: return Icons.category;
    }
  }
}

class BoundingBoxPainter extends CustomPainter {
  final List<BoundingBox> boxes;
  final Set<int> selectedIndices;
  final Function(BoundingBox) onBoxTap;

  BoundingBoxPainter({
    required this.boxes,
    required this.selectedIndices,
    required this.onBoxTap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var box in boxes) {
      final isSelected = selectedIndices.contains(box.hashCode);
      final rect = box.toPixelRect(size);
      
      final paint = Paint()
        ..color = isSelected ? Colors.blue : Colors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 4 : 2;
      
      canvas.drawRect(rect, paint);
      
      // Draw label
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${box.label} ${(box.confidence * 100).toInt()}%',
          style: TextStyle(
            color: Colors.white,
            backgroundColor: isSelected ? Colors.blue : Colors.green,
            fontSize: 14,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      textPainter.paint(canvas, Offset(rect.left, rect.top - 20));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
```

### 4.2 Update CameraScreen

**File: `lib/views/camera_screen/camera_screen.dart`**

Update `_showProcessDialog`:
```dart
Future<void> _showProcessDialog() async {
  // Step 1: Detect objects
  setState(() => _isProcessing = true);
  
  try {
    final detectedBoxes = await _service.detectObjects(_capturedImages.map((img) => img.file).toList());
    
    if (detectedBoxes.isEmpty) {
      _showError('Không tìm thấy vật thể nào. Vui lòng chụp lại.');
      return;
    }
    
    // Step 2: Show object selection dialog
    List<BoundingBox>? selectedBoxes;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ObjectSelectionDialog(
        images: _capturedImages,
        detectedBoxes: detectedBoxes,
        onConfirm: (boxes) {
          selectedBoxes = boxes;
        },
      ),
    );
    
    if (selectedBoxes == null || selectedBoxes!.isEmpty) {
      _showError('Vui lòng chọn vật thể muốn đo hoặc chụp lại.');
      return;
    }
    
    // Step 3: Show baseline input dialog
    await showDialog(
      context: context,
      builder: (ctx) => CaptureCompletion(
        images: _capturedImages,
        selectedBoxes: selectedBoxes!,
        onProcess: (baseline) => _runPhotogrammetry(baseline, selectedBoxes!),
      ),
    );
    
  } catch (e) {
    _showError('Lỗi phát hiện vật thể: $e');
  } finally {
    setState(() => _isProcessing = false);
  }
}

Future<void> _runPhotogrammetry(double baseline, List<BoundingBox> selectedBoxes) async {
  // ... existing code
  
  final height = await _service.estimateHeightFromBaseline(
    images: _capturedImages.map((img) => img.file).toList(),
    knownBaselineCm: baseline,
    intrinsics: intrinsics,
    selectedBoxes: selectedBoxes, // Pass selected boxes
  );
  
  // ... rest of code
}
```

## Phase 5: Native Feature Filtering

**Update: `android/app/src/main/cpp/photogrammetry_native.cpp`**

```cpp
// In estimateHeight function, after feature detection:

std::vector<cv::KeyPoint> filterKeypoints(
    const std::vector<cv::KeyPoint>& keypoints,
    const BoundingBox& box,
    const cv::Size& imageSize) {
    
    std::vector<cv::KeyPoint> filtered;
    
    // Convert normalized box to pixel coordinates
    cv::Rect pixelBox(
        box.x * imageSize.width,
        box.y * imageSize.height,
        box.width * imageSize.width,
        box.height * imageSize.height
    );
    
    for (const auto& kp : keypoints) {
        if (pixelBox.contains(kp.pt)) {
            filtered.push_back(kp);
        }
    }
    
    return filtered;
}

// In main estimation loop:
for (size_t i = 0; i < images.size(); i++) {
    // Detect features
    detector->detectAndCompute(images[i], cv::noArray(), keypoints[i], descriptors[i]);
    
    // Filter by bounding box if provided
    if (!selectedBoxes.empty() && i < selectedBoxes.size()) {
        keypoints[i] = filterKeypoints(keypoints[i], selectedBoxes[i], images[i].size());
        // Recompute descriptors for filtered keypoints
        detector->compute(images[i], keypoints[i], descriptors[i]);
    }
}
```

## Phase 6: Testing & Validation

### Test Cases:
1. **No objects detected**: Should show error message
2. **Single object across all images**: Should allow selection
3. **Multiple objects**: User can select target object
4. **Object not in all images**: Should warn user
5. **High confidence objects**: Should be pre-selected

### Validation Metrics:
- Inlier count should increase (target: ≥500)
- Error rate (-1.0) should decrease
- Height estimation accuracy should improve

## Estimated Timeline:
- Phase 1-2 (Native + Models): 3-4 days
- Phase 3 (Service Layer): 1 day
- Phase 4 (UI): 2-3 days
- Phase 5 (Feature Filtering): 1-2 days
- Phase 6 (Testing): 2-3 days

**Total: ~10-14 days**

## Notes:
- Consider using Google ML Kit as an alternative (easier integration)
- May need to handle cases where object appears in some but not all images
- Performance: Object detection adds ~500ms per image on mid-range devices
- Model size: ~4MB for MobileNet SSD (acceptable for mobile)
