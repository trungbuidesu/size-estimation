# Native TensorFlow Lite Integration Guide

## Overview
This guide covers the complete integration of TensorFlow Lite for object detection in the Flutter app.

## Prerequisites
- TensorFlow Lite model: MobileNet SSD v2 (COCO)
- Model file: `ssd_mobilenet_v2_coco.tflite` (~4MB)
- Labels file: `coco_labels.txt` (80 classes)

## Step 1: Download Model Files

### Download Links:
```bash
# MobileNet SSD v2 (quantized)
wget https://storage.googleapis.com/download.tensorflow.org/models/tflite/coco_ssd_mobilenet_v1_1.0_quant_2018_06_29.zip

# Or use MobileNet SSD v2 (float)
wget https://storage.googleapis.com/download.tensorflow.org/models/tflite/gpu/mobile_ssd_v2_float_coco.tflite
```

### COCO Labels (coco_labels.txt):
```
person
bicycle
car
motorcycle
airplane
bus
train
truck
boat
traffic light
fire hydrant
stop sign
parking meter
bench
bird
cat
dog
horse
sheep
cow
elephant
bear
zebra
giraffe
backpack
umbrella
handbag
tie
suitcase
frisbee
skis
snowboard
sports ball
kite
baseball bat
baseball glove
skateboard
surfboard
tennis racket
bottle
wine glass
cup
fork
knife
spoon
bowl
banana
apple
sandwich
orange
broccoli
carrot
hot dog
pizza
donut
cake
chair
couch
potted plant
bed
dining table
toilet
tv
laptop
mouse
remote
keyboard
cell phone
microwave
oven
toaster
sink
refrigerator
book
clock
vase
scissors
teddy bear
hair drier
toothbrush
```

## Step 2: Add Model to Assets

### Android:
```
android/app/src/main/assets/
├── ssd_mobilenet_v2.tflite
└── coco_labels.txt
```

### iOS:
```
ios/Runner/
├── Models/
│   ├── ssd_mobilenet_v2.tflite
│   └── coco_labels.txt
```

Update `ios/Runner/Info.plist`:
```xml
<key>UIFileSharingEnabled</key>
<true/>
```

## Step 3: Add Dependencies

### Android (android/app/build.gradle):
```gradle
android {
    // ... existing config
    
    aaptOptions {
        noCompress "tflite"
    }
}

dependencies {
    // ... existing dependencies
    
    // TensorFlow Lite
    implementation 'org.tensorflow:tensorflow-lite:2.14.0'
    implementation 'org.tensorflow:tensorflow-lite-support:0.4.4'
    implementation 'org.tensorflow:tensorflow-lite-gpu:2.14.0'
    
    // Optional: GPU delegate for better performance
    implementation 'org.tensorflow:tensorflow-lite-gpu-delegate-plugin:0.4.4'
}
```

### iOS (ios/Podfile):
```ruby
target 'Runner' do
  # ... existing pods
  
  # TensorFlow Lite
  pod 'TensorFlowLiteSwift', '~> 2.14.0'
  pod 'TensorFlowLiteC', '~> 2.14.0'
end
```

### pubspec.yaml (Flutter assets):
```yaml
flutter:
  assets:
    - assets/models/ssd_mobilenet_v2.tflite
    - assets/models/coco_labels.txt
```

## Step 4: Native C++ Implementation

### File: `android/app/src/main/cpp/object_detector.h`
```cpp
#ifndef OBJECT_DETECTOR_H
#define OBJECT_DETECTOR_H

#include <string>
#include <vector>
#include <memory>

struct DetectedObject {
    float x;          // Normalized 0-1
    float y;          // Normalized 0-1
    float width;      // Normalized 0-1
    float height;     // Normalized 0-1
    std::string label;
    float confidence;
    int imageIndex;
};

class ObjectDetector {
public:
    ObjectDetector();
    ~ObjectDetector();
    
    bool initialize(const std::string& modelPath, const std::string& labelsPath);
    std::vector<DetectedObject> detectObjects(const std::vector<std::string>& imagePaths);
    
private:
    class Impl;
    std::unique_ptr<Impl> pImpl;
};

#endif // OBJECT_DETECTOR_H
```

### File: `android/app/src/main/cpp/object_detector.cpp`
```cpp
#include "object_detector.h"
#include <opencv2/opencv.hpp>
#include <fstream>
#include <sstream>

// TFLite includes
#include "tensorflow/lite/interpreter.h"
#include "tensorflow/lite/kernels/register.h"
#include "tensorflow/lite/model.h"
#include "tensorflow/lite/optional_debug_tools.h"

class ObjectDetector::Impl {
public:
    std::unique_ptr<tflite::FlatBufferModel> model;
    std::unique_ptr<tflite::Interpreter> interpreter;
    std::vector<std::string> labels;
    
    bool loadLabels(const std::string& labelsPath) {
        std::ifstream file(labelsPath);
        if (!file.is_open()) return false;
        
        std::string line;
        while (std::getline(file, line)) {
            labels.push_back(line);
        }
        return !labels.empty();
    }
    
    cv::Mat preprocessImage(const cv::Mat& image) {
        cv::Mat resized, normalized;
        
        // Resize to model input size (typically 300x300 for SSD)
        cv::resize(image, resized, cv::Size(300, 300));
        
        // Convert BGR to RGB
        cv::cvtColor(resized, normalized, cv::COLOR_BGR2RGB);
        
        // Normalize to [0, 1] if using float model
        // Or keep uint8 if using quantized model
        normalized.convertTo(normalized, CV_32FC3, 1.0 / 255.0);
        
        return normalized;
    }
    
    std::vector<DetectedObject> runInference(const cv::Mat& image, int imageIndex) {
        std::vector<DetectedObject> results;
        
        // Preprocess
        cv::Mat input = preprocessImage(image);
        
        // Get input tensor
        int input_idx = interpreter->inputs()[0];
        TfLiteTensor* input_tensor = interpreter->tensor(input_idx);
        
        // Copy image data to input tensor
        float* input_data = interpreter->typed_input_tensor<float>(0);
        memcpy(input_data, input.data, input.total() * input.elemSize());
        
        // Run inference
        if (interpreter->Invoke() != kTfLiteOk) {
            return results;
        }
        
        // Parse outputs
        // SSD MobileNet outputs:
        // [0] locations (boxes): [1, num_detections, 4]
        // [1] classes: [1, num_detections]
        // [2] scores: [1, num_detections]
        // [3] num_detections: [1]
        
        const float* detection_boxes = interpreter->typed_output_tensor<float>(0);
        const float* detection_classes = interpreter->typed_output_tensor<float>(1);
        const float* detection_scores = interpreter->typed_output_tensor<float>(2);
        const float* num_detections = interpreter->typed_output_tensor<float>(3);
        
        int num = static_cast<int>(*num_detections);
        
        for (int i = 0; i < num && i < 10; i++) {  // Limit to top 10
            float score = detection_scores[i];
            
            if (score < 0.5f) continue;  // Confidence threshold
            
            int class_id = static_cast<int>(detection_classes[i]);
            if (class_id >= labels.size()) continue;
            
            // Boxes are in format [ymin, xmin, ymax, xmax]
            float ymin = detection_boxes[i * 4 + 0];
            float xmin = detection_boxes[i * 4 + 1];
            float ymax = detection_boxes[i * 4 + 2];
            float xmax = detection_boxes[i * 4 + 3];
            
            DetectedObject obj;
            obj.x = xmin;
            obj.y = ymin;
            obj.width = xmax - xmin;
            obj.height = ymax - ymin;
            obj.label = labels[class_id];
            obj.confidence = score;
            obj.imageIndex = imageIndex;
            
            results.push_back(obj);
        }
        
        return results;
    }
};

ObjectDetector::ObjectDetector() : pImpl(std::make_unique<Impl>()) {}

ObjectDetector::~ObjectDetector() = default;

bool ObjectDetector::initialize(const std::string& modelPath, const std::string& labelsPath) {
    // Load labels
    if (!pImpl->loadLabels(labelsPath)) {
        return false;
    }
    
    // Load model
    pImpl->model = tflite::FlatBufferModel::BuildFromFile(modelPath.c_str());
    if (!pImpl->model) {
        return false;
    }
    
    // Build interpreter
    tflite::ops::builtin::BuiltinOpResolver resolver;
    tflite::InterpreterBuilder builder(*pImpl->model, resolver);
    builder(&pImpl->interpreter);
    
    if (!pImpl->interpreter) {
        return false;
    }
    
    // Allocate tensors
    if (pImpl->interpreter->AllocateTensors() != kTfLiteOk) {
        return false;
    }
    
    return true;
}

std::vector<DetectedObject> ObjectDetector::detectObjects(
    const std::vector<std::string>& imagePaths) {
    
    std::vector<DetectedObject> allResults;
    
    for (size_t i = 0; i < imagePaths.size(); i++) {
        cv::Mat image = cv::imread(imagePaths[i]);
        if (image.empty()) continue;
        
        auto results = pImpl->runInference(image, i);
        allResults.insert(allResults.end(), results.begin(), results.end());
    }
    
    return allResults;
}
```

### File: `android/app/src/main/cpp/photogrammetry_native.cpp` (Update)
```cpp
#include "object_detector.h"
#include <nlohmann/json.hpp>

using json = nlohmann::json;

// Global detector instance
static std::unique_ptr<ObjectDetector> g_detector;

extern "C" {

JNIEXPORT jstring JNICALL
Java_com_example_size_1estimation_MainActivity_detectObjects(
    JNIEnv* env,
    jobject /* this */,
    jobjectArray imagePaths) {
    
    // Initialize detector if needed
    if (!g_detector) {
        g_detector = std::make_unique<ObjectDetector>();
        
        // Get model path from assets
        std::string modelPath = "/data/data/com.example.size_estimation/app_flutter/ssd_mobilenet_v2.tflite";
        std::string labelsPath = "/data/data/com.example.size_estimation/app_flutter/coco_labels.txt";
        
        if (!g_detector->initialize(modelPath, labelsPath)) {
            return env->NewStringUTF("{\"error\": \"Failed to initialize detector\"}");
        }
    }
    
    // Convert Java string array to C++ vector
    int count = env->GetArrayLength(imagePaths);
    std::vector<std::string> paths;
    
    for (int i = 0; i < count; i++) {
        jstring jpath = (jstring)env->GetObjectArrayElement(imagePaths, i);
        const char* cpath = env->GetStringUTFChars(jpath, nullptr);
        paths.push_back(cpath);
        env->ReleaseStringUTFChars(jpath, cpath);
    }
    
    // Detect objects
    auto results = g_detector->detectObjects(paths);
    
    // Convert to JSON
    json j = json::array();
    for (const auto& obj : results) {
        j.push_back({
            {"x", obj.x},
            {"y", obj.y},
            {"width", obj.width},
            {"height", obj.height},
            {"label", obj.label},
            {"confidence", obj.confidence},
            {"imageIndex", obj.imageIndex}
        });
    }
    
    std::string jsonStr = j.dump();
    return env->NewStringUTF(jsonStr.c_str());
}

} // extern "C"
```

## Step 5: Update CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.10)
project(size_estimation)

# ... existing config

# TensorFlow Lite
set(TFLITE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party/tensorflow-lite")
include_directories(${TFLITE_DIR}/include)
link_directories(${TFLITE_DIR}/lib)

# Add object detector
add_library(object_detector STATIC
    object_detector.cpp
)

target_link_libraries(object_detector
    tensorflow-lite
    ${OpenCV_LIBS}
)

# Link to main library
target_link_libraries(size_estimation
    object_detector
    # ... other libs
)
```

## Step 6: Dart FFI Bindings

Already created in previous steps. Just need to update PhotogrammetryService to call native instead of mock.

## Step 7: Testing

```bash
# Android
cd android
./gradlew assembleDebug

# iOS
cd ios
pod install
```

## Notes

- **Model Size**: ~4MB (acceptable for mobile)
- **Inference Time**: ~100-300ms per image on mid-range devices
- **Accuracy**: COCO dataset, 80 classes
- **Alternative**: Google ML Kit (easier but less control)

## Troubleshooting

### Common Issues:
1. **Model not found**: Check asset paths
2. **Slow inference**: Use GPU delegate
3. **Out of memory**: Use quantized model
4. **Wrong detections**: Adjust confidence threshold

### Performance Optimization:
- Use quantized INT8 model
- Enable GPU delegate
- Batch processing
- Cache model in memory
