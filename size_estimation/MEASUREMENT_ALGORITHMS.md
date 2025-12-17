# Measurement Algorithms - Technical Documentation

## Overview
This document explains the mathematical foundations and implementation details of the three measurement modes in the Size Estimation app.

---

## 1. Ground Plane Measurement

### Purpose
Measure the distance between two points on a flat ground plane (Z=0).

### Requirements
- Camera height from ground (user input)
- IMU orientation (pitch, roll, yaw)
- Camera intrinsics (K matrix)
- Two points selected on the ground

### Algorithm

#### Step 1: Ray Casting
For each pixel point, compute the ray direction in world coordinates:
```
v_camera = K^(-1) * [u, v, 1]^T
v_world = R^T * v_camera
```

#### Step 2: Ground Plane Intersection
Find where each ray intersects the ground plane (Z=0):
```
P = C + λ * d
Z = 0 => λ = -C_z / d_z
P_ground = C + λ * d
```

#### Step 3: Distance Calculation
Compute Euclidean distance between the two ground points:
```
distance = ||P_A - P_B||
```

### Accuracy Factors
- ✅ **Accurate** when ground is truly flat
- ✅ **Accurate** when camera height is correct
- ⚠️ **Sensitive** to IMU calibration errors
- ⚠️ **Sensitive** to camera tilt estimation

---

## 2. Planar Object Measurement

### Purpose
Measure width, height, and area of a planar rectangular object (e.g., poster, paper, screen).

### Requirements
- Distance to the planar object (user input)
- Camera intrinsics (K matrix)
- Four corners of the object (TL, TR, BR, BL)

### Algorithm

#### Step 1: Edge Measurement
Calculate pixel lengths of all 4 edges:
```
topEdge = ||corner[1] - corner[0]||      // TL to TR
rightEdge = ||corner[2] - corner[1]||    // TR to BR
bottomEdge = ||corner[2] - corner[3]||   // BR to BL
leftEdge = ||corner[3] - corner[0]||     // BL to TL
```

#### Step 2: Perspective Averaging
Average opposite edges to account for perspective distortion:
```
width_pixels = (topEdge + bottomEdge) / 2
height_pixels = (leftEdge + rightEdge) / 2
```

#### Step 3: Perspective Correction
Analyze perspective distortion from edge ratios:
```
topBottomRatio = topEdge / bottomEdge
leftRightRatio = leftEdge / rightEdge
perspectiveDistortion = |topBottomRatio - 1| + |leftRightRatio - 1|
perspectiveFactor = 1.0 + perspectiveDistortion × 0.15
```

#### Step 4: Scale Conversion
Convert pixel dimensions to real-world centimeters:
```
avgFocal = (fx + fy) / 2
pixelToCm = (distance_meters × 100 × perspectiveFactor) / avgFocal
widthCm = width_pixels × pixelToCm
heightCm = height_pixels × pixelToCm
```

### Accuracy Factors
- ✅ **Accurate** when distance is correctly measured
- ✅ **Accurate** when object is roughly frontal (< 45° angle)
- ⚠️ **Less accurate** for highly tilted planes
- ⚠️ **Sensitive** to distance estimation errors
- 💡 **Best practice**: Use reference object (A4 paper, credit card) for scale

### Known Limitations
- Current implementation uses simplified perspective correction
- Full homography decomposition would provide better accuracy for tilted planes
- Assumes rectangular object (not arbitrary quadrilaterals)

---

## 3. Vertical Object Measurement

### Purpose
Measure the height of a vertical object standing on the ground.

### Requirements
- Camera height from ground (user input)
- IMU orientation (pitch, roll, yaw)
- Camera intrinsics (K matrix)
- Two points: bottom (on ground) and top of object

### Algorithm

#### Step 1: Bottom Point - Ground Intersection
Cast ray from bottom pixel and find ground intersection:
```
rayBottom = getRayInWorld(bottomPixel, K, R)
λ_bottom = -camera_height / rayBottom_z
P_bottom = cameraCenter + λ_bottom × rayBottom
```

#### Step 2: Planar Distance Calculation
Compute horizontal distance to object:
```
planarDistance = √(P_bottom_x² + P_bottom_y²)
```

#### Step 3: Top Point Height Calculation
Assuming object is vertical (top has same X,Y as bottom):
```
rayTop = getRayInWorld(topPixel, K, R)
topRayPlanarProjection = √(rayTop_x² + rayTop_y²)
λ_top = planarDistance / topRayPlanarProjection
P_top = cameraCenter + λ_top × rayTop
```

#### Step 4: Height Extraction
Object height is the Z-coordinate of top point:
```
height_meters = P_top_z
height_cm = height_meters × 100
```

### Accuracy Factors
- ✅ **Accurate** when object is truly vertical
- ✅ **Accurate** when bottom is on ground plane
- ⚠️ **Sensitive** to IMU calibration
- ⚠️ **Fails** for leaning objects
- ⚠️ **Sensitive** to camera height accuracy

### Assumptions
- Object is perfectly vertical (perpendicular to ground)
- Object base is on the ground plane (Z=0)
- Ground is flat

---

## Coordinate Systems

### Camera Coordinate System
- **X**: Right
- **Y**: Down  
- **Z**: Forward (optical axis)
- **Origin**: Camera center

### World Coordinate System
- **X**: East (or arbitrary horizontal)
- **Y**: North (or arbitrary horizontal)
- **Z**: Up (gravity direction)
- **Origin**: Ground plane at camera's horizontal position

### Transformations
```
Pixel → Camera: v_cam = K^(-1) × [u, v, 1]^T
Camera → World: v_world = R^T × v_cam
```

Where:
- `K`: Intrinsic matrix (focal length, principal point)
- `R`: Rotation matrix from IMU (world to camera)

---

## Error Sources and Mitigation

### 1. Intrinsic Calibration Errors
- **Impact**: Affects all measurements
- **Mitigation**: Use calibrated camera profiles
- **Typical error**: 2-5% for uncalibrated, <1% for calibrated

### 2. IMU Orientation Errors
- **Impact**: Critical for ground plane and vertical modes
- **Mitigation**: Sensor fusion, calibration
- **Typical error**: 1-3° for consumer devices

### 3. Distance Estimation Errors
- **Impact**: Critical for planar mode
- **Mitigation**: Use reference objects, measure carefully
- **Typical error**: 5-10% for estimated distance

### 4. User Selection Errors
- **Impact**: All modes
- **Mitigation**: Edge snapping, zoom interface
- **Typical error**: 2-5 pixels

### 5. Perspective Distortion
- **Impact**: Planar mode
- **Mitigation**: Perspective correction factors
- **Typical error**: 5-15% for tilted planes

---

## Best Practices

### Ground Plane Mode
1. Ensure ground is truly flat
2. Measure camera height accurately
3. Keep camera level (minimize pitch/roll)
4. Select points that are clearly on the ground

### Planar Mode
1. Measure distance to object accurately
2. Keep object as frontal as possible
3. Use reference objects when available
4. Select corners precisely

### Vertical Mode
1. Ensure object is truly vertical
2. Measure camera height accurately
3. Select bottom point at ground level
4. Select top point at object's peak

---

## Future Improvements

### Planar Mode
- [ ] Implement full homography decomposition (SVD)
- [ ] Support for arbitrary quadrilaterals
- [ ] Automatic plane normal estimation
- [ ] Multi-view refinement

### Vertical Mode
- [ ] Support for leaning objects
- [ ] Automatic verticality detection
- [ ] Multi-point height profiling

### All Modes
- [ ] Uncertainty quantification
- [ ] Automatic reference object detection
- [ ] Machine learning-based correction
- [ ] Multi-frame averaging for stability

---

## References

1. Hartley, R., & Zisserman, A. (2003). Multiple View Geometry in Computer Vision.
2. Zhang, Z. (2000). A flexible new technique for camera calibration.
3. Faugeras, O. (1993). Three-dimensional computer vision: a geometric viewpoint.
