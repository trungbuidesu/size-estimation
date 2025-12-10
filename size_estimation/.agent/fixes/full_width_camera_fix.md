# Full Width Camera Implementation

## User Request
- Extend the camera frame to fit the full width of the screen ("bao vùng ảnh của camera luôn").
- Maintain aspect ratio resizing (resize both frame and image content).
- Ensure Settings menu is always on top.

## Solution Implemented
1. **Removed Global `SafeArea`**:
   - The root `Stack` is no longer wrapped in `SafeArea`.
   - This allows the `CameraPreview` to extend behind the status bar and notch area, maximizing available screen real estate.
   - Local `SafeArea` widgets were added to specific UI controls (Top Bar, Progress Indicator) to prevent them from being obscured by system UI.

2. **Full Width Layout**:
   - Used `MeasureQuery.of(context).size.width` to force the `CameraPreview` container to always match the screen width.
   - Wrapped `CameraPreview` in `Align(Alignment.center)` + `AspectRatio`.
   - Used `FittedBox(BoxFit.cover)` + `OverflowBox` to ensure the camera texture fills the aspect ratio frame completely without gaps (no black bars on sides).

3. **Restored Helper Methods**:
   - Restored accidentally deleted helper methods (`_confirmReset`, `_toggleSettings`, `_toggleFlash`, etc.) ensuring full functionality.

4. **Z-Index Fix**:
   - Moved `CameraSettingsOverlay` to the end of the `Stack` children list to ensure it renders on top of all other elements, including `OverlapGuide` and `Bottom Controls`.

## Visual Result
- **Portrait 1:1**: Full width square centered on screen.
- **Portrait 4:3**: Full width rectangular frame (taller).
- **Portrait 16:9**: Full width tall frame (almost full screen on many phones).
- **All Modes**: Image fills the frame completely (zoomed/cropped as needed) with no side borders.
