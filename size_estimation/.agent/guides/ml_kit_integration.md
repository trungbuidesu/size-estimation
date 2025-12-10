# Google ML Kit Object Detection Integration

## Advantages over TensorFlow Lite
- ✅ No native code required
- ✅ Automatic model management
- ✅ Optimized for mobile
- ✅ Easy Flutter integration
- ✅ Works on both Android & iOS

## Step 1: Add Dependencies

### pubspec.yaml:
```yaml
dependencies:
  google_ml_kit: ^0.16.3
```

## Step 2: Platform Configuration

### Android (android/app/build.gradle):
```gradle
android {
    defaultConfig {
        minSdkVersion 21  // ML Kit requires API 21+
    }
}

dependencies {
    // ML Kit will be added automatically by the plugin
}
```

### iOS (ios/Podfile):
```ruby
platform :ios, '12.0'  # ML Kit requires iOS 12+
```

## Step 3: Permissions

### Android (android/app/src/main/AndroidManifest.xml):
```xml
<!-- Already have camera permission -->
```

### iOS (ios/Runner/Info.plist):
```xml
<!-- Already have camera permission -->
```

## Step 4: Implementation

See `lib/services/ml_kit_object_detection_service.dart`

## Usage

```dart
final service = MLKitObjectDetectionService();
final boxes = await service.detectObjects(capturedImages);
```

## Performance
- **Speed**: 50-150ms per image
- **Accuracy**: Good for common objects
- **Model**: On-device, no internet required
- **Size**: ~10MB download on first use

## Limitations
- Limited to common objects (not as many as COCO)
- Less control over model
- Slightly larger app size

## Migration Path
If needed later, can switch to custom TFLite model using the guide in `tensorflow_lite_integration.md`
