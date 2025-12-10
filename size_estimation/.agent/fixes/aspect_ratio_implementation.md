# Aspect Ratio Implementation - Details

## Requirements Implemented
1. **Camera Viewfinder**:
   - Masked to selected aspect ratio (1:1, 4:3, 16:9)
   - Covered areas outside mask are black
   - Uses `AspectRatio` widget for precise scaling

2. **Overlap Guide**:
   - Thumbnails now respect the same aspect ratio
   - Dimensions calculated dynamically: `width = height * aspectRatio`
   - Ensures visual consistency between viewfinder and captured history

## Aspect Ratios Mapping
Since most mobile usage is portrait:
- **Index 0 (1:1)**: Ratio `1.0`
- **Index 1 (4:3)**: Portrait Ratio `3:4` (0.75)
- **Index 2 (16:9)**: Portrait Ratio `9:16` (0.5625)

## Files Modified
- `lib/views/camera_screen/camera_screen.dart`
- `lib/views/camera_screen/components/overlap_guide.dart`

## Note on "Crop"
Currently, this implementation handles the **Visual Presentation**.
The actual captured image file (`File`) from camera plugin is still the full sensor resolution (usually 4:3).
- **Pro**: We keep maximum data for photogrammetry processing.
- **Con**: Opening the file in external gallery shows uncropped image.
- **Solution**: If strict file cropping is needed, we would need to post-process the image using `image` package to crop pixels. For now, visual consistency is achieved.
