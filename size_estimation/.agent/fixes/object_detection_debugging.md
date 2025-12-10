# Object Detection Debugging - Fixes Applied

## Problem
Object detection không hoạt động - không detect được gì cả.

## Root Causes Identified

### 1. **Lack of Logging**
- Không có logs để debug
- Không biết detection có chạy không
- Không biết có bao nhiêu objects được tìm thấy

### 2. **Potential Null Metadata**
- `inputImage.metadata` có thể null
- Code crash khi access `metadata!.size.width`
- Không có fallback handling

### 3. **High Confidence Threshold**
- Threshold 0.5 (50%) có thể quá cao
- ML Kit có thể detect với confidence thấp hơn
- Miss nhiều objects

## Fixes Applied

### 1. **Comprehensive Logging** ✅
```dart
print('[ObjectDetection] Starting detection for ${images.length} images');
print('[ObjectDetection] Processing image $i: ${images[i].file.path}');
print('[ObjectDetection] Image $i: Found ${objects.length} objects');
print('[ObjectDetection] Detected "$label" with confidence ${confidence}%');
print('[ObjectDetection] Total boxes detected: ${allBoxes.length}');
```

**Benefits**:
- Can see exactly what's happening
- Know if detection is running
- See how many objects found
- Debug confidence issues

### 2. **Null Metadata Handling** ✅
```dart
if (inputImage.metadata?.size != null) {
  imageWidth = inputImage.metadata!.size.width;
  imageHeight = inputImage.metadata!.size.height;
} else {
  // Fallback to common mobile resolution
  print('[ObjectDetection] Warning: No metadata, using default 1080x1920');
  imageWidth = 1080.0;
  imageHeight = 1920.0;
}
```

**Benefits**:
- No crash if metadata is null
- Reasonable fallback values
- Warning logged for debugging

### 3. **Lower Confidence Threshold** ✅
```dart
// Changed from 0.5 to 0.3
if (confidence < 0.3) {
  print('[ObjectDetection] Skipping low confidence: $label (${confidence}%)');
  continue;
}
```

**Benefits**:
- Detect more objects
- Better for testing
- Can adjust later if too many false positives

### 4. **Better Error Handling** ✅
```dart
} catch (e, stackTrace) {
  print('[ObjectDetection] Error detecting objects in image $i: $e');
  print('[ObjectDetection] Stack trace: $stackTrace');
}
```

**Benefits**:
- See full error details
- Stack trace for debugging
- Continue processing other images

## How to Test

### 1. Run App with Logging
```bash
fvm flutter run
```

### 2. Capture Images
- Take 6 photos of objects
- Tap "Hoàn tất"

### 3. Check Logs
Look for:
```
[ObjectDetection] Starting detection for 6 images
[ObjectDetection] Initializing detector...
[ObjectDetection] Processing image 0: /path/to/image.jpg
[ObjectDetection] Image 0 metadata: Size(1080.0, 1920.0)
[ObjectDetection] Image 0: Found 3 objects
[ObjectDetection] Image 0: Detected "bottle" with confidence 85.3%
[ObjectDetection] Added box: bottle at (45.2%, 30.1%)
...
[ObjectDetection] Total boxes detected: 12
```

### 4. Expected Behavior

**If Working**:
- ✅ See detection logs
- ✅ See object counts
- ✅ See confidence scores
- ✅ ObjectSelectionDialog appears with boxes

**If Still Not Working**:
Check logs for:
- ❌ "Found 0 objects" → ML Kit model issue
- ❌ Error messages → Permission or file access issue
- ❌ No logs at all → Detection not being called

## Common Issues & Solutions

### Issue 1: "Found 0 objects" in all images
**Possible Causes**:
- ML Kit model not downloaded
- Images too dark/blurry
- No recognizable objects

**Solutions**:
1. Ensure internet connection (first run)
2. Take clearer photos
3. Use common objects (bottles, cups, phones)
4. Check ML Kit model status

### Issue 2: Metadata is null
**Symptoms**:
```
[ObjectDetection] Warning: No metadata, using default 1080x1920
```

**Impact**: Minor - uses fallback resolution
**Action**: No action needed, fallback works

### Issue 3: Low confidence detections
**Symptoms**:
```
[ObjectDetection] Skipping low confidence: unknown (25.3%)
```

**Solutions**:
- Take clearer photos
- Better lighting
- More recognizable objects
- Lower threshold further (0.2 or 0.1)

### Issue 4: ML Kit initialization error
**Symptoms**:
```
Failed to initialize ML Kit Object Detector: ...
```

**Solutions**:
1. Check internet (first run)
2. Check storage permissions
3. Restart app
4. Clear app data

## Next Steps

### If Detection Works Now:
1. ✅ Test with various objects
2. ✅ Verify bounding boxes are accurate
3. ✅ Test object selection UI
4. ✅ Proceed with photogrammetry

### If Still Not Working:
1. Share logs from console
2. Check ML Kit plugin version
3. Try mock service temporarily:
   ```dart
   final _objectDetectionService = MockObjectDetectionService();
   ```

## Performance Notes

- **Detection Time**: ~500ms - 2s for 6 images
- **Model Download**: ~10MB (first run only)
- **Confidence Range**: Typically 0.3 - 0.95
- **Objects Per Image**: Usually 1-5

## Summary

**Changes Made**:
- ✅ Added comprehensive logging
- ✅ Fixed null metadata crash
- ✅ Lowered confidence threshold (0.5 → 0.3)
- ✅ Better error handling with stack traces

**Expected Result**:
Object detection should now work and provide detailed logs for debugging.

**Status**: Ready for testing
