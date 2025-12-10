---
description: Tích hợp Object Detection vào Photogrammetry Pipeline
---

# Object Detection Integration - Task List

## ✅ Completed
- [x] BoundingBox model created
- [x] ObjectSelectionDialog UI created
- [x] Demo removed

## 🔄 In Progress

### Phase 1: Mock Object Detection Service (Để test UI flow)
- [ ] Create `MockObjectDetectionService` 
  - Simulate ML detection với hardcoded bounding boxes
  - Return realistic data structure
  - Add delay để simulate processing time

### Phase 2: Integrate vào CameraScreen
- [ ] Update `PhotogrammetryService` 
  - Add `detectObjects()` method signature
  - Add `selectedBoxes` parameter to `estimateHeightFromBaseline()`
- [ ] Update `CameraScreen._showProcessDialog()`
  - Call object detection sau khi chụp đủ ảnh
  - Show `ObjectSelectionDialog` với detected boxes
  - Pass selected boxes to photogrammetry
- [ ] Handle edge cases
  - No objects detected
  - User cancels selection
  - Object không xuất hiện đủ ảnh

### Phase 3: Native Integration (TensorFlow Lite)
- [ ] Add TFLite dependencies
  - Android: build.gradle
  - iOS: Podfile
- [ ] Download và add model
  - MobileNet SSD v2 (~4MB)
  - COCO labels file
- [ ] Create Native ObjectDetector class
  - C++ implementation
  - OpenCV integration
  - TFLite inference
- [ ] Update FFI bindings
  - Add `detect_objects` function
  - JSON serialization/deserialization
- [ ] Test native detection

### Phase 4: Feature Filtering in Native Code
- [ ] Update `photogrammetry_native.cpp`
  - Accept bounding boxes parameter
  - Filter keypoints by bounding box
  - Recompute descriptors for filtered keypoints
- [ ] Test filtered feature matching
  - Verify inlier count increases
  - Measure accuracy improvement

### Phase 5: Testing & Optimization
- [ ] Unit tests for BoundingBox model
- [ ] Integration tests for object selection flow
- [ ] Performance testing
  - Detection speed
  - Memory usage
  - Battery impact
- [ ] UI/UX refinements
- [ ] Error handling improvements

## 📝 Notes
- Start with Mock service để test UI flow trước
- Native integration là bước cuối cùng (phức tạp nhất)
- Có thể dùng Google ML Kit thay vì TFLite (dễ hơn)

## 🎯 Current Focus
**Phase 1: Mock Object Detection Service**
- Tạo service giả để test toàn bộ UI flow
- Verify user experience trước khi làm native code
