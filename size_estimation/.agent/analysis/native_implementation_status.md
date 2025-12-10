# Native Photogrammetry Implementation - Complete Plan

## Current Situation

**Discovery**: The native photogrammetry library (`libphotogrammetry.so`) does NOT exist yet.

The Dart code expects it:
```dart
_lib = DynamicLibrary.open('libphotogrammetry.so');
```

But there is no C++ implementation in:
- `android/app/src/main/cpp/` (directory doesn't exist)
- No CMakeLists.txt
- No native code at all

## What This Means

The app currently:
- ✅ Compiles and runs
- ✅ Can capture images
- ✅ Can detect objects (ML Kit)
- ✅ Can select objects
- ❌ **Cannot actually estimate height** (native library missing)

The `PhotogrammetryService.estimateHeightFromBaseline()` will fail when called because the native library doesn't exist.

## Full Implementation Required

To make photogrammetry work, we need to implement:

### 1. **Basic Photogrammetry (Without Object Detection)**
   - Feature detection (SIFT/ORB)
   - Feature matching
   - RANSAC for outlier rejection
   - Essential matrix calculation
   - Camera pose estimation
   - Triangulation
   - Bundle adjustment
   - Height calculation
   
   **Estimated effort**: 40-60 hours
   **Complexity**: Very High
   **Dependencies**: OpenCV, Eigen, Ceres Solver

### 2. **Object Detection Filtering (Addition)**
   - JSON parsing
   - Keypoint filtering by bounding boxes
   - Descriptor recomputation
   
   **Estimated effort**: 4-6 hours (on top of #1)
   **Complexity**: Medium
   **Dependencies**: nlohmann/json

## Options Forward

### Option A: Implement Full Native Photogrammetry
**Pros**:
- Complete control
- Can optimize for mobile
- Can add object detection filtering

**Cons**:
- Very time-consuming (40-60 hours)
- Complex mathematics (SfM, bundle adjustment)
- Requires deep computer vision knowledge
- Need to setup build system (CMake, NDK)
- Need to integrate OpenCV, Eigen, Ceres

**Recommendation**: Only if you have:
- Strong C++ skills
- Computer vision background
- 1-2 weeks of dedicated time

### Option B: Use Existing Library/Service
**Options**:
1. **Google ARCore** (Android only)
   - Built-in depth estimation
   - No custom code needed
   - Limited to ARCore-supported devices

2. **Cloud-based SfM** (e.g., Pix4D API, Agisoft API)
   - Upload images to cloud
   - Get 3D reconstruction
   - Requires internet
   - May have costs

3. **Flutter Plugins** (if any exist)
   - Search pub.dev for photogrammetry
   - Unlikely to find complete solution

**Recommendation**: ARCore for Android, or cloud service for cross-platform

### Option C: Simplified Implementation
**Approach**:
- Use simpler algorithms (not full SfM)
- Estimate height using simpler geometry
- Less accurate but faster to implement

**Example**: Two-view geometry
- Use only 2 images
- Estimate relative pose
- Calculate height using triangulation
- Skip bundle adjustment

**Estimated effort**: 10-15 hours
**Accuracy**: Lower than full SfM

### Option D: Mock Implementation (Current State)
**Keep current state**:
- Object detection works
- UI is complete
- Return mock height values for testing
- Focus on other features

**Recommendation**: Good for UI/UX development

## Recommended Path

Given the scope, I recommend:

### Phase 1: Verify Requirements
1. Do you actually need photogrammetry?
2. Is ARCore an option (Android only)?
3. Can you use a cloud service?
4. What accuracy is required?

### Phase 2: Choose Approach
Based on answers above:
- **If ARCore works**: Use ARCore (easiest)
- **If cloud is OK**: Use cloud service (most accurate)
- **If must be on-device**: Implement native (most work)

### Phase 3: Implementation
If native implementation is chosen:

**Week 1**: Setup & Basic SfM
- Setup CMake build system
- Integrate OpenCV
- Implement feature detection/matching
- Basic two-view geometry

**Week 2**: Advanced SfM
- Multi-view geometry
- Bundle adjustment
- Height calculation
- Testing & refinement

**Week 3**: Object Detection Integration
- Add JSON parsing
- Implement filtering
- Test improvements
- Optimization

## Immediate Next Steps

### If Proceeding with Native Implementation:

1. **Setup Build System**
   ```bash
   cd android/app/src/main
   mkdir cpp
   cd cpp
   # Create CMakeLists.txt
   # Create photogrammetry_native.cpp
   ```

2. **Add Dependencies**
   - OpenCV 4.x (for Android)
   - Eigen (linear algebra)
   - Ceres Solver (bundle adjustment)
   - nlohmann/json (JSON parsing)

3. **Update build.gradle**
   ```gradle
   android {
       externalNativeBuild {
           cmake {
               path "src/main/cpp/CMakeLists.txt"
           }
       }
   }
   ```

4. **Implement Core Functions**
   - Feature detection
   - Feature matching
   - Essential matrix estimation
   - Triangulation
   - Height calculation

5. **Add Object Detection Filtering**
   - Parse bounding boxes JSON
   - Filter keypoints
   - Recompute descriptors

## Alternative: Simplified Demo

If you want a working demo quickly:

### Mock Native Implementation
Create a simple native function that:
1. Accepts all parameters
2. Does minimal processing
3. Returns a calculated height based on baseline

```cpp
// Simple mock that returns height based on baseline
double EstimateHeightFromBaseline(...) {
    // Mock: assume object is roughly same size as baseline
    return knownBaselineCm * 1.5; // Just an example
}
```

This allows:
- ✅ App to work end-to-end
- ✅ UI testing
- ✅ Object detection testing
- ❌ Not accurate
- ❌ Not real photogrammetry

## Resources

### If Implementing Native SfM:
- [OpenCV SfM Module](https://docs.opencv.org/4.x/d8/d8c/group__sfm.html)
- [Multiple View Geometry Book](http://www.robots.ox.ac.uk/~vgg/hzbook/)
- [Ceres Solver Tutorial](http://ceres-solver.org/tutorial.html)
- [Android NDK Guide](https://developer.android.com/ndk/guides)

### Existing Implementations:
- [COLMAP](https://colmap.github.io/) - Full SfM pipeline (C++)
- [OpenMVG](https://github.com/openMVG/openMVG) - Multiple View Geometry
- [TheiaSfM](http://www.theia-sfm.org/) - SfM library

## Decision Required

**Question**: How do you want to proceed?

1. **Full native implementation** (40-60 hours)
2. **Use ARCore** (if Android-only is OK)
3. **Cloud service** (if internet is OK)
4. **Simplified implementation** (10-15 hours, less accurate)
5. **Mock implementation** (1 hour, for testing only)

Please decide based on:
- Available time
- Required accuracy
- Platform requirements (Android only vs cross-platform)
- Internet availability
- Budget (for cloud services)

---

**Current Status**: Native library missing, needs full implementation
**Blocker**: No native photogrammetry code exists
**Recommendation**: Clarify requirements before proceeding
