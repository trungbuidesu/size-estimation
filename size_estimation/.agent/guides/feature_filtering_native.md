# Phase 4: Feature Filtering - Native C++ Implementation Guide

## Overview
This guide shows how to implement feature filtering in the native C++ photogrammetry code to use bounding boxes for improved SfM accuracy.

## Files to Modify

### 1. Update Function Signature

**File**: `android/app/src/main/cpp/photogrammetry_native.cpp` (or equivalent iOS file)

```cpp
// Update function signature to accept bounding boxes JSON
extern "C" JNIEXPORT jdouble JNICALL
Java_com_example_size_1estimation_PhotogrammetryBindings_EstimateHeightFromBaseline(
    JNIEnv* env,
    jobject /* this */,
    jobjectArray imagePaths,
    jint numImages,
    jdouble knownBaselineCm,
    jdouble focalLength,
    jdouble cx,
    jdouble cy,
    jdouble sensorWidth,
    jdouble sensorHeight,
    jdoubleArray distortionCoeffs,
    jint numDistortionCoeffs,
    jstring boundingBoxesJson  // NEW PARAMETER
) {
    // Implementation below
}
```

### 2. Parse Bounding Boxes JSON

```cpp
#include <nlohmann/json.hpp>  // Add JSON library

using json = nlohmann::json;

struct BoundingBox {
    double x, y, width, height;
    std::string label;
    double confidence;
    int imageIndex;
};

std::vector<BoundingBox> parseBoundingBoxes(JNIEnv* env, jstring jsonStr) {
    std::vector<BoundingBox> boxes;
    
    if (jsonStr == nullptr) {
        return boxes;  // No boxes provided
    }
    
    const char* jsonCStr = env->GetStringUTFChars(jsonStr, nullptr);
    std::string jsonString(jsonCStr);
    env->ReleaseStringUTFChars(jsonStr, jsonCStr);
    
    try {
        json j = json::parse(jsonString);
        
        for (const auto& item : j) {
            BoundingBox box;
            box.x = item["x"];
            box.y = item["y"];
            box.width = item["width"];
            box.height = item["height"];
            box.label = item["label"];
            box.confidence = item["confidence"];
            box.imageIndex = item["imageIndex"];
            boxes.push_back(box);
        }
    } catch (const std::exception& e) {
        // Log error but continue without filtering
        __android_log_print(ANDROID_LOG_ERROR, "Photogrammetry", 
                          "Failed to parse bounding boxes: %s", e.what());
    }
    
    return boxes;
}
```

### 3. Filter Keypoints by Bounding Box

```cpp
std::vector<cv::KeyPoint> filterKeypointsByBoundingBox(
    const std::vector<cv::KeyPoint>& keypoints,
    const std::vector<BoundingBox>& boxes,
    int imageIndex,
    const cv::Size& imageSize
) {
    std::vector<cv::KeyPoint> filtered;
    
    // If no boxes for this image, return all keypoints
    std::vector<BoundingBox> imageBoxes;
    for (const auto& box : boxes) {
        if (box.imageIndex == imageIndex) {
            imageBoxes.push_back(box);
        }
    }
    
    if (imageBoxes.empty()) {
        return keypoints;  // No filtering
    }
    
    // Filter keypoints that fall within any bounding box
    for (const auto& kp : keypoints) {
        bool insideBox = false;
        
        for (const auto& box : imageBoxes) {
            // Convert normalized box to pixel coordinates
            double x1 = box.x * imageSize.width;
            double y1 = box.y * imageSize.height;
            double x2 = (box.x + box.width) * imageSize.width;
            double y2 = (box.y + box.height) * imageSize.height;
            
            // Check if keypoint is inside this box
            if (kp.pt.x >= x1 && kp.pt.x <= x2 &&
                kp.pt.y >= y1 && kp.pt.y <= y2) {
                insideBox = true;
                break;
            }
        }
        
        if (insideBox) {
            filtered.push_back(kp);
        }
    }
    
    return filtered;
}
```

### 4. Integrate into Main Photogrammetry Function

```cpp
double EstimateHeightFromBaseline(..., jstring boundingBoxesJson) {
    // Parse bounding boxes
    std::vector<BoundingBox> boxes = parseBoundingBoxes(env, boundingBoxesJson);
    
    __android_log_print(ANDROID_LOG_INFO, "Photogrammetry", 
                       "Using %zu bounding boxes for feature filtering", boxes.size());
    
    // ... existing code for loading images ...
    
    // Feature detection and filtering
    std::vector<std::vector<cv::KeyPoint>> allKeypoints(numImages);
    std::vector<cv::Mat> allDescriptors(numImages);
    
    cv::Ptr<cv::Feature2D> detector = cv::SIFT::create(
        0,      // nfeatures (0 = unlimited)
        3,      // nOctaveLayers
        0.04,   // contrastThreshold
        10,     // edgeThreshold
        1.6     // sigma
    );
    
    for (int i = 0; i < numImages; i++) {
        std::vector<cv::KeyPoint> keypoints;
        cv::Mat descriptors;
        
        // Detect features
        detector->detectAndCompute(images[i], cv::noArray(), keypoints, descriptors);
        
        __android_log_print(ANDROID_LOG_INFO, "Photogrammetry", 
                           "Image %d: Detected %zu keypoints", i, keypoints.size());
        
        // Filter by bounding boxes if provided
        if (!boxes.empty()) {
            std::vector<cv::KeyPoint> filteredKeypoints = 
                filterKeypointsByBoundingBox(keypoints, boxes, i, images[i].size());
            
            __android_log_print(ANDROID_LOG_INFO, "Photogrammetry", 
                               "Image %d: Filtered to %zu keypoints (%.1f%% kept)", 
                               i, filteredKeypoints.size(), 
                               100.0 * filteredKeypoints.size() / keypoints.size());
            
            // Recompute descriptors for filtered keypoints
            if (!filteredKeypoints.empty()) {
                detector->compute(images[i], filteredKeypoints, descriptors);
                keypoints = filteredKeypoints;
            } else {
                // No keypoints in bounding boxes, use all (fallback)
                __android_log_print(ANDROID_LOG_WARN, "Photogrammetry", 
                                   "Image %d: No keypoints in bounding boxes, using all", i);
            }
        }
        
        allKeypoints[i] = keypoints;
        allDescriptors[i] = descriptors;
    }
    
    // ... continue with feature matching, RANSAC, etc. ...
}
```

### 5. Add JSON Library Dependency

**File**: `android/app/src/main/cpp/CMakeLists.txt`

```cmake
# Add nlohmann/json (header-only library)
include(FetchContent)

FetchContent_Declare(
    json
    GIT_REPOSITORY https://github.com/nlohmann/json.git
    GIT_TAG v3.11.2
)

FetchContent_MakeAvailable(json)

# Link to your library
target_link_libraries(photogrammetry
    ${OpenCV_LIBS}
    nlohmann_json::nlohmann_json
)
```

**Alternative**: Download `json.hpp` manually:
```bash
cd android/app/src/main/cpp/
wget https://github.com/nlohmann/json/releases/download/v3.11.2/json.hpp
```

## Expected Improvements

### Before Feature Filtering:
- Inlier count: ~300-400
- Error rate: High (-1.0 errors common)
- Accuracy: Moderate (background noise)

### After Feature Filtering:
- ✅ Inlier count: ~500-800 (target: ≥500)
- ✅ Error rate: Lower (fewer -1.0 errors)
- ✅ Accuracy: Better (focused on target object)
- ✅ Speed: Potentially faster (fewer features to match)

## Testing

### 1. Test without Bounding Boxes (Baseline)
```dart
final height = await service.estimateHeightFromBaseline(
  images: images,
  knownBaselineCm: 10.0,
  intrinsics: intrinsics,
  selectedBoxes: null,  // No filtering
);
```

### 2. Test with Bounding Boxes
```dart
final height = await service.estimateHeightFromBaseline(
  images: images,
  knownBaselineCm: 10.0,
  intrinsics: intrinsics,
  selectedBoxes: detectedBoxes,  // With filtering
);
```

### 3. Compare Results
- Log inlier counts
- Compare accuracy
- Measure processing time

## Debugging

### Enable Verbose Logging:
```cpp
#define VERBOSE_LOGGING 1

#if VERBOSE_LOGGING
    __android_log_print(ANDROID_LOG_DEBUG, "Photogrammetry", 
                       "Box %d: (%.2f, %.2f, %.2f, %.2f) label=%s conf=%.2f", 
                       i, box.x, box.y, box.width, box.height, 
                       box.label.c_str(), box.confidence);
#endif
```

### Visualize Filtered Features:
```cpp
// Draw keypoints on image for debugging
cv::Mat debugImage = images[i].clone();
cv::drawKeypoints(debugImage, filteredKeypoints, debugImage, 
                  cv::Scalar(0, 255, 0), cv::DrawMatchesFlags::DRAW_RICH_KEYPOINTS);
cv::imwrite("/sdcard/debug_keypoints_" + std::to_string(i) + ".jpg", debugImage);
```

## Fallback Strategy

If filtering reduces features too much:

```cpp
const int MIN_KEYPOINTS = 100;

if (filteredKeypoints.size() < MIN_KEYPOINTS) {
    __android_log_print(ANDROID_LOG_WARN, "Photogrammetry", 
                       "Too few filtered keypoints (%zu), using all %zu", 
                       filteredKeypoints.size(), keypoints.size());
    // Use all keypoints instead
} else {
    keypoints = filteredKeypoints;
}
```

## Performance Considerations

1. **Feature Detection**: Still detect all features first, then filter
2. **Descriptor Computation**: Recompute only for filtered keypoints
3. **Matching**: Fewer features = faster matching
4. **RANSAC**: More focused features = better inliers

## Summary

Feature filtering by bounding boxes:
- ✅ Reduces background noise
- ✅ Improves feature matching quality
- ✅ Increases inlier count
- ✅ Better SfM accuracy
- ⚠️ Requires careful implementation
- ⚠️ Need fallback for edge cases

**Status**: Dart/Flutter side complete, native C++ implementation pending.
