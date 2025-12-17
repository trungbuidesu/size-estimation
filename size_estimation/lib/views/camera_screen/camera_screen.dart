import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:size_estimation/models/captured_image.dart';
import 'package:size_estimation/models/estimation_mode.dart';

import 'package:size_estimation/views/camera_screen/components/index.dart';

import 'package:size_estimation/constants/index.dart';
import 'package:size_estimation/models/researcher_config.dart';
import 'package:size_estimation/models/calibration_profile.dart';
import 'package:size_estimation/services/index.dart';
import 'package:size_estimation/models/camera_metadata.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'package:size_estimation/views/measure_screen/ground_plane_measure_screen.dart';
import 'package:size_estimation/views/measure_screen/planar_measure_screen.dart';
import 'package:size_estimation/views/measure_screen/vertical_measure_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

// ... (IsolateData and _isolateEntry helper classes remain the same) ...

// Helper class for isolate data

class _CameraScreenState extends State<CameraScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  // Controls State
  bool _isSettingsOpen = false;
  bool _isFlashOn = false;
  bool _isDebugUiVisible = false; // Debug UI State
  ResearcherConfig _researcherConfig = ResearcherConfig(); // Config state
  bool _showKMatrix = false; // K Matrix overlay state
  bool _showIMU = false; // Restored
  bool _isLocked = false;

  // Mode Selector State
  final List<EstimationMode> _selectorModes = kEstimationModes;

  EstimationModeType? _selectedModeType; // Track selected mode

  // Hover detection for mode explanation

  CalibrationProfile? _activeProfile; // Active calibration profile
  CameraMetadata? _currentMetadata;

  // Ground Plane Measurement
  bool _groundPlaneMode = false; // Ground plane measurement mode
  double _cameraHeightMeters = 1.5; // Default eye level
  GroundPlaneMeasurement? _currentMeasurement;
  vm.Vector2? _groundPointA;
  vm.Vector2? _groundPointB;
  bool _isGroundPlaneResultVisible = true;

  // Planar Object Measurement
  bool _planarObjectMode = false; // Planar object measurement mode
  String? _referenceObject; // Reference object for scale (e.g., "A4 Paper")
  PlanarObjectMeasurement? _currentPlanarMeasurement;
  List<vm.Vector2>? _planarCorners; // UI corners before scaling
  bool _isPlanarResultVisible = true;
  double _planarDistanceMeters =
      0.5; // Distance to planar object (default 50cm)

  // Vertical Object Measurement
  bool _verticalObjectMode = false;
  VerticalObjectMeasurement? _currentVerticalMeasurement;
  vm.Vector2? _verticalTopPoint; // UI coordinates
  vm.Vector2? _verticalBottomPoint; // UI coordinates
  // Token to force reset selector on error
  int _verticalSelectorResetToken = 0;

  // Advanced Processing
  bool _applyUndistortion = false;
  bool _edgeSnapping = false;
  bool _multiFrameMode = false;
  bool _isMeasuringMultiFrame = false;
  Timer? _multiFrameTimer;

  final LensDistortionService _distortionService = LensDistortionService();
  final EdgeSnappingService _snappingService = EdgeSnappingService();
  final ResultAveragingService _averagingService = ResultAveragingService();
  final FeatureTrackingService _trackingService =
      FeatureTrackingService(); // Added
  final VanishingPointService _vanishingPointService =
      VanishingPointService(); // Added
  CameraImage? _latestImage;

  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;

  // Warning State

  // Frozen State for Ground Plane Mode
  bool _isFrozen = false;
  File? _frozenImageFile; // Use File for captured frozen image
  vm.Vector2? _frozenPointA; // Temp storage for points in frozen mode
  vm.Vector2? _frozenPointB;
  IMUOrientation? _frozenOrientation;
  IntrinsicMatrix? _frozenKOut;

  // Photogrammetry State
  final List<CapturedImage> _capturedImages = [];
  final int _requiredImages = 1;
  bool _isProcessing = false; // Calculating height
  bool _isCapturing = false; // Taking photo
  // final PhotogrammetryService _service = PhotogrammetryService();
  // final PhotogrammetryService _service = PhotogrammetryService();

  // Settings State
  int _timerDuration = 0;
  // Aspect ratio locked to 16:9

  // Countdown State
  int _countdownSeconds = 0;
  bool _isCountingDown = false;
  List<int> _timerPresets = [3, 5, 10]; // Presets

  late AnimationController _settingsAnimationController;
  late Animation<double> _settingsAnimation;
  final GlobalKey _settingsButtonKey = GlobalKey();

  final CalibrationService _calibrationService = CalibrationService();
  final DynamicIntrinsicsService _dynamicIntrinsicsService =
      DynamicIntrinsicsService();
  final IMUService _imuService = IMUService(); // IMU for orientation

  IntrinsicMatrix? _currentKOut; // Current output intrinsics
  IMUOrientation? _currentOrientation; // Current device orientation

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadActiveProfile();
    _initializeCamera();

    // Listen to IMU orientation updates
    _imuService.startListening();
    _imuService.orientationStream.listen((orientation) {
      if (mounted) {
        setState(() {
          _currentOrientation = orientation;
        });
      }
    });

    _settingsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _settingsAnimation = CurvedAnimation(
      parent: _settingsAnimationController,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          final List<String>? presets = prefs.getStringList('timer_presets');
          if (presets != null && presets.length == 3) {
            _timerPresets = presets.map((e) => int.tryParse(e) ?? 10).toList();
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading camera settings: $e');
    }
  }

  Future<void> _loadActiveProfile() async {
    try {
      final profile = await _calibrationService.getActiveProfile();
      if (profile != null && mounted) {
        setState(() {
          _activeProfile = profile;
        });
      }
    } catch (e) {
      debugPrint('Error loading active profile: $e');
    }
  }

  @override
  void dispose() {
    _imuService.dispose(); // Dispose IMU service
    _dynamicIntrinsicsService.dispose(); // Dispose dynamic intrinsics

    _controller?.dispose();
    _settingsAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) _showError(AppStrings.cameraNotFound);
        return;
      }

      _controller = CameraController(
        _cameras![0],
        ResolutionPreset.max, // Locked to 4:3
        enableAudio: false,
      );

      await _controller!.initialize();

      if (!mounted) return;

      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = await _controller!.getMaxZoomLevel();
      _currentZoom = _minZoom;

      // Start Image Stream for Advanced Features (Snapping, Tracking)
      await _controller!.startImageStream((image) {
        _latestImage = image;
      });

      // Initialize dynamic intrinsics service
      await _initializeDynamicIntrinsics();

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      if (mounted) _showError('${AppStrings.initCameraError}$e');
    }
  }

  Future<void> _initializeDynamicIntrinsics() async {
    if (_controller == null) return;

    try {
      final value = _controller!.value;
      await _dynamicIntrinsicsService.initialize(
        outputWidth: value.previewSize?.width.toInt() ?? 1920,
        outputHeight: value.previewSize?.height.toInt() ?? 1080,
        customProfile: _activeProfile,
        cameraId: '0',
      );

      // Listen to intrinsics updates
      _dynamicIntrinsicsService.intrinsicsStream.listen((kOut) {
        if (mounted) {
          setState(() {
            _currentKOut = kOut;
          });
        }
      });

      // Listen to metadata updates
      _dynamicIntrinsicsService.metadataStream.listen((metadata) {
        if (mounted) {
          setState(() {
            _currentMetadata = metadata;
          });
        }
      });

      // Update with initial zoom
      _dynamicIntrinsicsService.updateZoom(_currentZoom);
    } catch (e) {
      debugPrint('Error initializing dynamic intrinsics: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _captureImage() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isProcessing ||
        _isCapturing ||
        _isCountingDown) return;

    // Check if full
    if (_capturedImages.length >= _requiredImages) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(AppStrings.maxImagesReached),
        duration: Duration(seconds: 2),
      ));
      return;
    }

    // Enforce Mode Selection before first capture
    if (_capturedImages.isEmpty && _selectedModeType == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(AppStrings.selectModeRequired),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ));
      return;
    }

    // Countdown Logic
    if (_timerDuration > 0) {
      setState(() {
        _isCountingDown = true;
        _countdownSeconds = _timerDuration;
      });

      while (_countdownSeconds > 0) {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        setState(() => _countdownSeconds--);
      }

      setState(() => _isCountingDown = false);
    }

    // Freeze Frame Logic (Pause Preview)
    try {
      await _controller!.pausePreview();
      setState(() {
        _isFrozen = true;
        _frozenOrientation = _currentOrientation; // Snapshot orientation
        _frozenKOut = _currentKOut; // Snapshot intrinsics
      });
    } catch (e) {
      _showError('Error freezing preview: $e');
    }
  }

  Future<void> _onSaveFrozenImage() async {
    setState(() => _isCapturing = true);

    try {
      // Capture the high-res image
      final xFile = await _controller!.takePicture();
      final file = File(xFile.path);

      // 1. Ground Plane Mode
      if (_groundPlaneMode) {
        if (_currentKOut != null &&
            _currentOrientation != null &&
            _controller!.value.previewSize != null) {
          final image = await decodeImageFromList(await file.readAsBytes());
          final capturedImageSize = Size(
            image.width.toDouble(),
            image.height.toDouble(),
          );

          if (!mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GroundPlaneMeasureScreen(
                imageFile: file,
                kOut: _currentKOut!,
                orientation: _currentOrientation!,
                cameraHeightMeters: _cameraHeightMeters,
                originalImageSize: capturedImageSize,
                initialPointA: _groundPointA,
                initialPointB: _groundPointB,
                previewSize: Size(
                  MediaQuery.of(context).size.width,
                  MediaQuery.of(context).size.width * 4.0 / 3.0,
                ),
                kOutBaseSize: _controller!.value.previewSize,
              ),
            ),
          );
        } else {
          _showError("Missing calibration data (K/IMU)");
        }
      }
      // 2. Planar Object Mode
      else if (_planarObjectMode) {
        if (_currentKOut != null && _controller!.value.previewSize != null) {
          final image = await decodeImageFromList(await file.readAsBytes());
          final capturedImageSize = Size(
            image.width.toDouble(),
            image.height.toDouble(),
          );

          if (!mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlanarMeasureScreen(
                imageFile: file,
                kOut: _currentKOut!,
                originalImageSize: capturedImageSize,
                planarDistanceMeters: _planarDistanceMeters,
                initialCorners: _planarCorners,
                previewSize: _controller!.value.previewSize,
                kOutBaseSize: _controller!.value.previewSize,
              ),
            ),
          );
        } else {
          _showError("Missing calibration data (K)");
        }
      }
      // 3. Vertical Object Mode
      else if (_verticalObjectMode) {
        if (_currentKOut != null &&
            _currentOrientation != null &&
            _controller!.value.previewSize != null) {
          final image = await decodeImageFromList(await file.readAsBytes());
          final capturedImageSize = Size(
            image.width.toDouble(),
            image.height.toDouble(),
          );

          if (!mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VerticalMeasureScreen(
                imageFile: file,
                kOut: _currentKOut!,
                orientation: _currentOrientation!,
                cameraHeightMeters: _cameraHeightMeters,
                originalImageSize: capturedImageSize,
                initialTopPoint: _verticalTopPoint,
                initialBottomPoint: _verticalBottomPoint,
                previewSize: _controller!.value.previewSize,
                kOutBaseSize: _controller!.value.previewSize,
              ),
            ),
          );
        } else {
          _showError("Missing calibration data (K/IMU)");
        }
      }
      // 4. Batch/Generic Mode
      else {
        List<String> warnings = [];
        setState(() {
          _capturedImages.add(CapturedImage(file: file, warnings: warnings));
          if (_capturedImages.length == 1) {
            _minZoom = _currentZoom;
            _maxZoom = _currentZoom;
          }
        });
      }

      // Reset Frozen State (if we didn't navigate away, or when we come back)
      if (mounted) {
        setState(() {
          _isFrozen = false;
        });
        await _controller!.resumePreview();
      }
    } catch (e) {
      _showError('${AppStrings.captureError}$e');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  List<String> _validateImageQuality() {
    final warnings = <String>[];
    final now = DateTime.now();

    // 1. Check Focus Mode (Consistency)
    if (_controller != null &&
        _controller!.value.focusMode != FocusMode.locked) {
      // "Not rigid": Advisory only
      // warnings.add('Nên khóa lấy nét (AF-L) để ảnh đồng nhất.');
    }

    // 2. Stability / Speed Check (Proxy for Blur)
    // Removed "Capture too fast" warning as requested.

    // 3. Digital Zoom Warning
    // High digital zoom can reduce image quality and SfM accuracy
    if (_currentZoom > 2.0) {
      warnings.add(
          '${AppStrings.zoomWarning} (${_currentZoom.toStringAsFixed(1)}x)');
    }

    // 4. Lighting (Heuristic)
    // If getting brightness is impossible without heavy processing, rely on user observation.
    // Logic: warn if it's very dark? Impossible on pure logic without sensor reading.
    // Just REMOVED the fake "ISO > 400" warning as it was misleading.

    return warnings;
  }

  // --- Controls & Toggles ---

  void _toggleSettings() {
    if (_isSettingsOpen) {
      _settingsAnimationController.reverse().then((_) {
        if (mounted) setState(() => _isSettingsOpen = false);
      });
    } else {
      setState(() => _isSettingsOpen = true);
      _settingsAnimationController.forward();
    }
  }

  void _toggleFlash() {
    if (_controller == null || !_isInitialized) return;
    setState(() => _isFlashOn = !_isFlashOn);
    _controller!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
  }

  void _setZoom(double zoom) {
    if (_controller == null || !_isInitialized) return;
    final clampedZoom = zoom.clamp(_minZoom, _maxZoom);
    setState(() => _currentZoom = clampedZoom);
    _controller!.setZoomLevel(clampedZoom);

    // Update dynamic intrinsics based on new zoom
    _dynamicIntrinsicsService.updateZoom(clampedZoom);
  }

  // --- Advanced Processing Helpers ---

  vm.Vector2 _snapPoint(vm.Vector2 point) {
    if (!_edgeSnapping || _latestImage == null) return point;
    // Integration of Edge Snapping
    // To be precise, we need a coordinate transform: Widget -> Image Buffer.
    // Enabling best-effort snapping on raw coordinates.
    return _snappingService.snapToEdge(
      image: _latestImage!,
      center: point,
      radius: 30,
    );
  }

  Future<void> _switchModeByType(EstimationModeType type) async {
    switch (type) {
      case EstimationModeType.groundPlane:
        // Ground Plane Mode - need camera height
        final height = await _showCameraHeightDialog();
        if (height != null) {
          setState(() {
            _selectedModeType = type; // Set selected mode
            _cameraHeightMeters = height;
            _groundPlaneMode = true;
            _planarObjectMode = false;
            _verticalObjectMode = false;
            _currentMeasurement = null;
            // Keep existing points if switching back? Or clear?
            // Usually clearing is safer for new mode activation
            _groundPointA = null;
            _groundPointB = null;
          });
        }
        break;

      case EstimationModeType.planarObject:
        // Planar Object Mode - need distance to plane
        final distance = await _showPlanarDistanceDialog();
        if (distance != null) {
          setState(() {
            _selectedModeType = type; // Set selected mode
            _planarDistanceMeters = distance;
            _groundPlaneMode = false;
            _planarObjectMode = true;
            _verticalObjectMode = false;
            _currentPlanarMeasurement = null;
            _planarCorners = null;
          });
        }
        break;

      case EstimationModeType.singleView:
        // Vertical Object Mode - need camera height
        final height = await _showCameraHeightDialog();
        if (height != null) {
          setState(() {
            _selectedModeType = type; // Set selected mode
            _cameraHeightMeters = height;
            _groundPlaneMode = false;
            _planarObjectMode = false;
            _verticalObjectMode = true;
            _currentVerticalMeasurement = null;
            _verticalTopPoint = null;
            _verticalBottomPoint = null;
          });
        }
        break;
    }
  }

  IconData _getModeIcon() {
    if (_selectedModeType == null) return Icons.category_outlined;

    switch (_selectedModeType!) {
      case EstimationModeType.groundPlane:
        return Icons.landscape;
      case EstimationModeType.planarObject:
        return Icons.crop_square;
      case EstimationModeType.singleView:
        return Icons.height;
    }
  }

  void _showModeConfirmationDialog(EstimationMode mode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(mode.icon, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mode.label,
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Animated visualization
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                  ),
                ),
                child: ModeAnimationWidget(modeType: mode.type),
              ),
              const SizedBox(height: 20),
              const Text(
                'Các bước thực hiện:',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              // Step-by-step instructions
              ...mode.steps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          step,
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Reset state - không chọn mode nào
              setState(() {
                _selectedModeType = null;
                _groundPlaneMode = false;
                _planarObjectMode = false;
                _verticalObjectMode = false;
                _currentMeasurement = null;
                _currentPlanarMeasurement = null;
                _currentVerticalMeasurement = null;
                _groundPointA = null;
                _groundPointB = null;
              });
            },
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _switchModeByType(mode.type);
            },
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  Future<double?> _showCameraHeightDialog() async {
    double tempHeight = _cameraHeightMeters;
    return showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Camera Height'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Set the height of the camera from the ground:'),
              const SizedBox(height: 16),
              Slider(
                value: tempHeight,
                min: 0.1,
                max: 3.0,
                divisions: 29,
                label: '${tempHeight.toStringAsFixed(1)}m',
                onChanged: (value) {
                  setDialogState(() {
                    tempHeight = value;
                  });
                },
              ),
              Text(
                '${tempHeight.toStringAsFixed(1)} meters',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, tempHeight),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  Future<double?> _showPlanarDistanceDialog() async {
    double tempDistance = _planarDistanceMeters;
    return showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Khoảng cách đến mặt phẳng'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Nhập khoảng cách từ camera đến mặt phẳng chứa vật:'),
              const SizedBox(height: 16),
              Slider(
                value: tempDistance,
                min: 0.1,
                max: 5.0,
                divisions: 49,
                label: '${tempDistance.toStringAsFixed(1)}m',
                onChanged: (value) {
                  setDialogState(() {
                    tempDistance = value;
                  });
                },
              ),
              Text(
                '${tempDistance.toStringAsFixed(1)} meters',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, tempDistance),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  vm.Vector2 _undistortPoint(vm.Vector2 point) {
    if (!_applyUndistortion ||
        _currentKOut == null ||
        _currentMetadata?.distortionCoefficients == null) {
      return point;
    }
    return _distortionService.undistortPoint(
      point: point,
      kMatrix: _currentKOut!,
      distCoeffs: _currentMetadata!.distortionCoefficients!,
    );
  }

  /// Compute rotation matrix from Euler angles (ZYX convention)
  /// R = Rz(yaw) * Ry(pitch) * Rx(roll)
  vm.Matrix3 _computeRotationMatrix(double roll, double pitch, double yaw) {
    final cr = math.cos(roll);
    final sr = math.sin(roll);
    final cp = math.cos(pitch);
    final sp = math.sin(pitch);
    final cy = math.cos(yaw);
    final sy = math.sin(yaw);

    // Rotation matrix (ZYX Euler)
    return vm.Matrix3(
      cy * cp,
      cy * sp * sr - sy * cr,
      cy * sp * cr + sy * sr,
      sy * cp,
      sy * sp * sr + cy * cr,
      sy * sp * cr - cy * sr,
      -sp,
      cp * sr,
      cp * cr,
    );
  }

  Future<void> _performGroundPlaneMeasurement(
      vm.Vector2 pointA, vm.Vector2 pointB) async {
    // Use Frozen State if waiting for capture
    final effectiveKOut = _isFrozen ? _frozenKOut : _currentKOut;
    final effectiveOrientation =
        _isFrozen ? _frozenOrientation : _currentOrientation;

    // Check if we have all required data
    if (effectiveKOut == null) {
      _showError('Camera intrinsics not available');
      return;
    }

    if (effectiveOrientation == null) {
      _showError('IMU orientation not available');
      return;
    }

    // Check if device is level enough
    final service = GroundPlaneService();
    if (!service.isOrientationSuitable(effectiveOrientation)) {
      _showError('Device is too tilted. Please hold device more level.');
      return;
    }

    // SCALING: UI Coordinates -> Buffer Coordinates
    // The UI uses a fixed 3:4 aspect ratio container based on screen width
    final uiWidth = MediaQuery.of(context).size.width;
    final uiHeight = uiWidth * 4.0 / 3.0;

    // Buffer size (the resolution of _latestImage and K matrix)
    final bufferWidth =
        _controller!.value.previewSize?.width.toDouble() ?? 1920.0;
    final bufferHeight =
        _controller!.value.previewSize?.height.toDouble() ?? 1080.0;

    // Dynamic Scaling Logic for Rotation Support
    final isUiPortrait = uiWidth < uiHeight;
    final isSensorLandscape = bufferWidth > bufferHeight;
    final needsSwap = isUiPortrait && isSensorLandscape;

    double scale;
    double yOffset;
    double xOffset = 0;

    if (needsSwap) {
      // Portrait UI, Landscape Sensor (Rotated 90)
      scale = bufferHeight / uiWidth;
      final renderedHeight = uiWidth * (bufferWidth / bufferHeight);
      yOffset = (renderedHeight - uiHeight) / 2;
    } else {
      // Landscape/Aligned
      if ((bufferWidth / bufferHeight) > (uiWidth / uiHeight)) {
        // Sensor Wider: Fits Height, Crops Width
        scale = bufferHeight / uiHeight;
        final renderedWidth = uiHeight * (bufferWidth / bufferHeight);
        xOffset = (renderedWidth - uiWidth) / 2;
        yOffset = 0;
      } else {
        scale = bufferWidth / uiWidth;
        final renderedHeight = uiWidth / (bufferWidth / bufferHeight);
        yOffset = (renderedHeight - uiHeight) / 2;
      }
    }

    vm.Vector2 scalePoint(vm.Vector2 p) {
      if (needsSwap) {
        // SWAP X/Y for Portrait Mode
        final x_sensor = (p.y + yOffset) * scale;
        final y_sensor = p.x * scale;
        return vm.Vector2(x_sensor, y_sensor);
      } else {
        // Normal Map for Landscape
        final x_sensor = (p.x + xOffset) * scale;
        final y_sensor = (p.y + yOffset) * scale;
        return vm.Vector2(x_sensor, y_sensor);
      }
    }

    // Advanced Processing (on Buffer Coordinates)
    final p1 = _undistortPoint(_snapPoint(scalePoint(pointA)));
    final p2 = _undistortPoint(_snapPoint(scalePoint(pointB)));

    // Debug scaling
    debugPrint(
        "Ground Plane Scaling (Dynamic): Scale=${scale.toStringAsFixed(3)}, Offset=${yOffset.toStringAsFixed(1)}, Swap=$needsSwap");

    Future<GroundPlaneMeasurement?> measure() async {
      try {
        return await service.measureDistance(
          imagePointA: p1,
          imagePointB: p2,
          kOut: effectiveKOut,
          orientation: effectiveOrientation,
          cameraHeightMeters: _cameraHeightMeters,
          imageWidth: _controller!.value.previewSize?.width.toInt() ?? 1920,
          imageHeight: _controller!.value.previewSize?.height.toInt() ?? 1080,
        );
      } catch (e) {
        return null;
      }
    }

    if (_multiFrameMode) {
      setState(() {
        _isMeasuringMultiFrame = true;
        _currentMeasurement = null;
      });
      _averagingService.clear();

      // Tracking variables
      CameraImage? prevImage = _latestImage;
      vm.Vector2 currentP1 = p1;
      vm.Vector2 currentP2 = p2;

      int count = 0;
      _multiFrameTimer =
          Timer.periodic(const Duration(milliseconds: 100), (timer) async {
        count++;

        // Optical Flow Tracking
        if (prevImage != null &&
            _latestImage != null &&
            _latestImage != prevImage) {
          try {
            final newPoints = _trackingService.trackPoints(
                prev: prevImage!,
                curr: _latestImage!,
                points: [currentP1, currentP2]);
            if (newPoints.length == 2) {
              currentP1 = newPoints[0];
              currentP2 = newPoints[1];
            }
            prevImage = _latestImage;
          } catch (e) {
            // Tracking failed, keep previous points
          }
        } else {
          prevImage = _latestImage;
        }

        // Measure using tracked points
        Future<GroundPlaneMeasurement?> measureTracked() async {
          try {
            return await service.measureDistance(
              imagePointA: currentP1,
              imagePointB: currentP2,
              kOut: effectiveKOut!,
              orientation: effectiveOrientation!,
              cameraHeightMeters: _cameraHeightMeters,
              imageWidth: _controller!.value.previewSize?.width.toInt() ?? 1920,
              imageHeight:
                  _controller!.value.previewSize?.height.toInt() ?? 1080,
            );
          } catch (e) {
            return null;
          }
        }

        final m = await measureTracked();
        if (m != null) _averagingService.addSample(m.distanceCm);

        if (count >= 20 || !mounted) {
          timer.cancel();
          final stats = _averagingService.statistics;
          if (stats.mean > 0) {
            final avgMeasurement = GroundPlaneMeasurement(
              distanceMeters: stats.mean / 100,
              distanceCm: stats.mean,
              pointA: currentP1,
              pointB: currentP2,
              cameraHeightMeters: _cameraHeightMeters,
              estimatedError: stats.stdDev,
            );
            if (mounted)
              setState(() {
                _currentMeasurement = avgMeasurement;
                _isMeasuringMultiFrame = false;
              });
          } else {
            if (mounted) setState(() => _isMeasuringMultiFrame = false);
            _showError("Multi-frame measurement failed");
          }
        }
      });
    } else {
      try {
        final measurement = await measure();
        if (measurement != null) {
          setState(() {
            _currentMeasurement = measurement;
            _isGroundPlaneResultVisible = true;
          });
          debugPrint(
              'Ground Plane Measurement: ${measurement.distanceCm.toStringAsFixed(1)} cm');
        }
      } catch (e) {
        _showError('Measurement failed: $e');
        debugPrint('Ground plane measurement error: $e');
      }
    }
  }

  Future<void> _performPlanarObjectMeasurement(List<vm.Vector2> corners) async {
    // Save UI corners for later use
    _planarCorners = List.from(corners);

    // Use Frozen State if waiting for capture
    final effectiveKOut = _isFrozen ? _frozenKOut : _currentKOut;

    // Check if we have required data
    if (effectiveKOut == null) {
      _showError('Camera intrinsics not available');
      return;
    }

    // SCALING: UI Coordinates -> Buffer Coordinates (Matches Ground Plane Logic)
    final uiWidth = MediaQuery.of(context).size.width;
    final uiHeight = uiWidth * 4.0 / 3.0; // Aspect Ratio 3:4

    final bufferWidth =
        _controller!.value.previewSize?.width.toDouble() ?? 1920.0;
    final bufferHeight =
        _controller!.value.previewSize?.height.toDouble() ?? 1080.0;

    // Dynamic Scaling Logic for Rotation Support
    final isUiPortrait = uiWidth < uiHeight;
    final isSensorLandscape = bufferWidth > bufferHeight;
    final needsSwap = isUiPortrait && isSensorLandscape;

    double scale;
    double yOffset;
    double xOffset = 0;

    if (needsSwap) {
      // Portrait UI, Landscape Sensor (Rotated 90)
      scale = bufferHeight / uiWidth;
      final renderedHeight = uiWidth * (bufferWidth / bufferHeight);
      yOffset = (renderedHeight - uiHeight) / 2;
    } else {
      // Landscape/Aligned
      // If UI is 4:3 and Sensor 16:9.
      // 16/9 = 1.77. 4/3 = 1.33.
      // Video is wider. Fits height, crops width?
      // Or if Cover: Fits Height (matches), Width overflows.
      // Let's assume Cover behavior is consistent: fill smallest dimension.
      if ((bufferWidth / bufferHeight) > (uiWidth / uiHeight)) {
        // Sensor is wider than Screen. Fits Height. Crops Width.
        scale = bufferHeight / uiHeight;
        final renderedWidth = uiHeight * (bufferWidth / bufferHeight);
        xOffset = (renderedWidth - uiWidth) / 2;
        yOffset = 0;
      } else {
        // Sensor is taller/boxier? Unlikely for 16:9 sensor.
        // Standard case: Matches Width.
        scale = bufferWidth / uiWidth;
        final renderedHeight = uiWidth / (bufferWidth / bufferHeight);
        yOffset = (renderedHeight - uiHeight) / 2;
      }
    }

    // Scale corners using Dynamic Logic
    final scaledCorners = corners.map((c) {
      if (needsSwap) {
        // Swap X/Y
        final x_sensor = (c.y + yOffset) * scale;
        final y_sensor = c.x * scale;
        return vm.Vector2(x_sensor, y_sensor);
      } else {
        // Standard Map
        final x_sensor = (c.x + xOffset) * scale;
        final y_sensor = (c.y + yOffset) * scale;
        return vm.Vector2(x_sensor, y_sensor);
      }
    }).toList();

    // Advanced Processing (Snap/Undistort) on Buffer Coordinates
    final refinedCorners =
        scaledCorners.map((c) => _undistortPoint(_snapPoint(c))).toList();

    // Validate corners with refined points
    final service = PlanarObjectService();
    if (!service.isValidQuadrilateral(refinedCorners)) {
      _showError('Invalid quadrilateral. Please select corners in order.');
      return;
    }

    try {
      // Reference objects are no longer needed since we use actual distance
      double? refWidth;
      double? refHeight;

      // Debug camera intrinsics
      debugPrint('=== CAMERA INTRINSICS ===');
      debugPrint(
          'K matrix: fx=${effectiveKOut.fx}, fy=${effectiveKOut.fy}, cx=${effectiveKOut.cx}, cy=${effectiveKOut.cy}');
      debugPrint(
          'Refined corners: ${refinedCorners.map((c) => '[${c.x.toStringAsFixed(1)},${c.y.toStringAsFixed(1)}]').join(', ')}');
      debugPrint('Distance: ${_planarDistanceMeters}m');
      debugPrint(
          'Scale (Uniform): ${scale.toStringAsFixed(3)}, Y-Offset: ${yOffset.toStringAsFixed(1)}');

      Future<PlanarObjectMeasurement?> measure() async {
        try {
          return await service.measureObject(
            corners: refinedCorners,
            kOut: effectiveKOut, // Use original K matrix matching buffer
            distanceMeters: _planarDistanceMeters,
            referenceWidthCm: refWidth,
            referenceHeightCm: refHeight,
          );
        } catch (e) {
          return null;
        }
      }

      if (_multiFrameMode) {
        setState(() {
          _isMeasuringMultiFrame = true;
          _currentPlanarMeasurement = null;
        });

        final widthBuffer = ResultAveragingService();
        final heightBuffer = ResultAveragingService();
        int count = 0;

        _multiFrameTimer =
            Timer.periodic(const Duration(milliseconds: 100), (timer) async {
          count++;
          final m = await measure();
          if (m != null) {
            widthBuffer.addSample(m.widthCm);
            heightBuffer.addSample(m.heightCm);
          }

          if (count >= 20 || !mounted) {
            timer.cancel();
            final wStats = widthBuffer.statistics;
            final hStats = heightBuffer.statistics;

            if (wStats.mean > 0 && hStats.mean > 0) {
              final area = wStats.mean * hStats.mean;
              final last = await measure();
              final avgMeasurement = PlanarObjectMeasurement(
                widthCm: wStats.mean,
                heightCm: hStats.mean,
                areaCm2: area,
                corners: last?.corners ?? refinedCorners,
                rectifiedCorners: last?.rectifiedCorners ?? refinedCorners,
                aspectRatio: wStats.mean / hStats.mean,
                estimatedError: hStats.stdDev,
                distanceMeters: last?.distanceMeters ?? 0.5,
              );
              if (mounted)
                setState(() {
                  _currentPlanarMeasurement = avgMeasurement;
                  _isMeasuringMultiFrame = false;
                });
            } else {
              if (mounted) setState(() => _isMeasuringMultiFrame = false);
              _showError("Multi-frame measurement failed");
            }
          }
        });
      } else {
        final measurement = await measure();
        if (measurement != null) {
          setState(() {
            _currentPlanarMeasurement = measurement;
            _isPlanarResultVisible = true;
            _isProcessing = false;
          });
          debugPrint(
              'Planar Object: ${measurement.widthCm.toStringAsFixed(1)} × ${measurement.heightCm.toStringAsFixed(1)} cm');
        }
      }
    } catch (e) {
      _showError('Measurement failed: $e');
      debugPrint('Planar object measurement error: $e');
    }
  }

  Future<void> _performVerticalObjectMeasurement(
      vm.Vector2 top, vm.Vector2 bottom) async {
    // Save UI points for later use
    _verticalTopPoint = top;
    _verticalBottomPoint = bottom;

    // Use Frozen State if waiting for capture
    final effectiveKOut = _isFrozen ? _frozenKOut : _currentKOut;
    final effectiveOrientation =
        _isFrozen ? _frozenOrientation : _currentOrientation;

    // Check requirements
    if (effectiveKOut == null) {
      _showError('Camera intrinsics not available');
      return;
    }
    if (effectiveOrientation == null) {
      _showError('IMU orientation not available');
      return;
    }

    // SCALING: UI Coordinates -> Buffer Coordinates (Uniform Scaling)
    final uiWidth = MediaQuery.of(context).size.width;
    final uiHeight = uiWidth * 4.0 / 3.0; // Aspect Ratio 3:4

    final bufferWidth =
        _controller!.value.previewSize?.width.toDouble() ?? 1920.0;
    final bufferHeight =
        _controller!.value.previewSize?.height.toDouble() ?? 1080.0;

    // Dynamic Scaling Logic for Rotation Support
    // Check orientation match
    final isUiPortrait = uiWidth < uiHeight;
    final isSensorLandscape = bufferWidth > bufferHeight;
    final needsSwap = isUiPortrait && isSensorLandscape;

    double scale;
    double yOffset;
    double xOffset = 0;

    if (needsSwap) {
      // Portrait UI, Landscape Sensor (Rotated 90)
      scale = bufferHeight / uiWidth;
      final renderedHeight = uiWidth * (bufferWidth / bufferHeight);
      yOffset = (renderedHeight - uiHeight) / 2;
    } else {
      // Landscape/Aligned
      if ((bufferWidth / bufferHeight) > (uiWidth / uiHeight)) {
        // Sensor Wider: Fits Height, Crops Width
        scale = bufferHeight / uiHeight;
        final renderedWidth = uiHeight * (bufferWidth / bufferHeight);
        xOffset = (renderedWidth - uiWidth) / 2;
        yOffset = 0;
      } else {
        scale = bufferWidth / uiWidth;
        final renderedHeight = uiWidth / (bufferWidth / bufferHeight);
        yOffset = (renderedHeight - uiHeight) / 2;
      }
    }

    vm.Vector2 scalePoint(vm.Vector2 p) {
      if (needsSwap) {
        // SWAP X/Y for Portrait Mode
        final x_sensor = (p.y + yOffset) * scale;
        final y_sensor = p.x * scale;
        return vm.Vector2(x_sensor, y_sensor);
      } else {
        // Normal Map for Landscape
        final x_sensor = (p.x + xOffset) * scale;
        final y_sensor = (p.y + yOffset) * scale;
        return vm.Vector2(x_sensor, y_sensor);
      }
    }

    // Apply scaling BEFORE snapping/undistorting
    final p1 = _undistortPoint(_snapPoint(scalePoint(top)));
    final p2 = _undistortPoint(_snapPoint(scalePoint(bottom)));

    // Debug scaling
    debugPrint(
        "Vertical Meas Scaling (Swapped): Scale=${scale.toStringAsFixed(3)}, Offset=${yOffset.toStringAsFixed(1)}");
    debugPrint("  Top UI: $top -> Buffer(Landscape): $p1");
    debugPrint("  Bottom UI: $bottom -> Buffer(Landscape): $p2");

    final service = VerticalObjectService();

    // Vanishing Point Refinement (Advanced Module C)
    IMUOrientation refinedOrientation = effectiveOrientation;

    if (_latestImage != null) {
      final vp =
          _vanishingPointService.estimateVerticalVanishingPoint(_latestImage!);
      if (vp != null && _currentKOut != null) {
        // Vanishing point detected! Use it to refine pitch angle
        // For vertical lines, VP should be at infinity in the vertical direction
        // VP position in image tells us about camera pitch

        // Convert VP to normalized coordinates
        final vp_norm_x = (vp.x - _currentKOut!.cx) / _currentKOut!.fx;
        final vp_norm_y = (vp.y - _currentKOut!.cy) / _currentKOut!.fy;

        // For a perfectly level camera looking at vertical lines:
        // VP should be at (0, ±∞) in normalized coords
        // The Y position of VP relates to pitch angle

        // Estimate pitch from VP
        // If VP is above center (vp_norm_y < 0), camera is tilted down
        // If VP is below center (vp_norm_y > 0), camera is tilted up
        final pitchFromVP = math.atan2(vp_norm_y, 1.0);

        // Blend VP-based pitch with IMU pitch
        // VP is more accurate for vertical lines, but can be noisy
        // Use weighted average: 70% IMU, 30% VP
        final imuPitch = _currentOrientation!.pitch;
        final blendedPitch = imuPitch * 0.7 + pitchFromVP * 0.3;

        // Create refined orientation
        refinedOrientation = IMUOrientation(
          rotationMatrix: _computeRotationMatrix(
            blendedPitch,
            _currentOrientation!.roll,
            _currentOrientation!.yaw,
          ),
          pitch: blendedPitch,
          roll: _currentOrientation!.roll,
          yaw: _currentOrientation!.yaw,
          gravity: _currentOrientation!.gravity,
        );

        debugPrint("VP Refinement: IMU pitch=${imuPitch.toStringAsFixed(3)}, "
            "VP pitch=${pitchFromVP.toStringAsFixed(3)}, "
            "Blended=${blendedPitch.toStringAsFixed(3)}");
      }
    }

    Future<VerticalObjectMeasurement?> measure() async {
      debugPrint("Measuring vertical object: top=$p1, bottom=$p2");
      final result = await service.measureHeight(
        topPixel: p1,
        bottomPixel: p2,
        kOut: effectiveKOut!,
        orientation: refinedOrientation, // Use refined orientation!
        cameraHeightMeters: _cameraHeightMeters,
      );
      debugPrint("Measurement result: ${result.heightCm} cm");
      return result;
    }

    try {
      if (_multiFrameMode) {
        setState(() {
          _isMeasuringMultiFrame = true;
          _currentVerticalMeasurement = null;
        });
        _averagingService.clear();

        // Tracking
        CameraImage? prevImage = _latestImage;
        vm.Vector2 currentP1 = p1;
        vm.Vector2 currentP2 = p2;

        int count = 0;
        _multiFrameTimer =
            Timer.periodic(const Duration(milliseconds: 100), (timer) async {
          count++;

          // Tracking
          if (prevImage != null &&
              _latestImage != null &&
              _latestImage != prevImage) {
            try {
              final newPoints = _trackingService.trackPoints(
                  prev: prevImage!,
                  curr: _latestImage!,
                  points: [currentP1, currentP2]);
              if (newPoints.length == 2) {
                currentP1 = newPoints[0];
                currentP2 = newPoints[1];
              }
              prevImage = _latestImage;
            } catch (e) {}
          } else {
            prevImage = _latestImage;
          }

          Future<VerticalObjectMeasurement?> measureTracked() async {
            try {
              return await service.measureHeight(
                topPixel: currentP1,
                bottomPixel: currentP2,
                kOut: effectiveKOut!,
                orientation: effectiveOrientation!,
                cameraHeightMeters: _cameraHeightMeters,
              );
            } catch (e) {
              return null;
            }
          }

          final m = await measureTracked();
          if (m != null) _averagingService.addSample(m.heightCm);

          if (count >= 20 || !mounted) {
            timer.cancel();
            final stats = _averagingService.statistics;
            if (stats.mean > 0) {
              final avgMeasurement = VerticalObjectMeasurement(
                heightCm: stats.mean,
                distanceToBottomMeters: 0, // Simplified
                estimatedError: stats.stdDev,
                bottomPoint: currentP2,
                objectElevation: stats.mean / 100.0,
              );
              if (mounted)
                setState(() {
                  _currentVerticalMeasurement = avgMeasurement;
                  _isMeasuringMultiFrame = false;
                });
            } else {
              if (mounted) setState(() => _isMeasuringMultiFrame = false);
              _showError("Multi-frame measurement failed");
            }
          }
        });
      } else {
        final measurement = await measure();
        if (measurement != null) {
          setState(() {
            _currentVerticalMeasurement = measurement;
          });
          debugPrint(
              'Vertical Object: ${measurement.heightCm.toStringAsFixed(1)} cm');
        }
      }
    } catch (e) {
      if (e.toString().contains("does not intersect")) {
        _showError('Điểm đáy không chạm mặt đất. Hãy chọn điểm thấp hơn.');
      } else {
        _showError('Đo thất bại: ${e.toString().split("\n").first}');
      }
      debugPrint('Vertical object measurement error: $e');
      // Reset Selector to clear "Processing..." state
      setState(() {
        _verticalSelectorResetToken++;
      });
    }
  }

  Widget _buildTopControlBar(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => context.pop(),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mode Selector Button
                  IconButton(
                    icon: Icon(
                      _getModeIcon(),
                      color: _selectedModeType == null
                          ? Colors.white70
                          : Colors.orange,
                    ),
                    onPressed: _showModeSelector,
                    tooltip: "Chọn chế độ đo",
                  ),
                  // Camera Height Button (Ground Plane Mode)
                  if (_groundPlaneMode)
                    IconButton(
                      icon:
                          const Icon(Icons.straighten, color: Colors.lightBlue),
                      onPressed: () async {
                        final height = await _showCameraHeightDialog();
                        if (height != null) {
                          setState(() {
                            _cameraHeightMeters = height;
                            // Reset measurements when height changes
                            _currentMeasurement = null;
                            _groundPointA = null;
                            _groundPointB = null;
                          });
                        }
                      },
                      tooltip:
                          "Đặt chiều cao camera: ${_cameraHeightMeters.toStringAsFixed(1)}m",
                    ),
                  // Distance Button (Planar Mode)
                  if (_planarObjectMode)
                    IconButton(
                      icon: const Icon(Icons.social_distance,
                          color: Colors.purple),
                      onPressed: () async {
                        final distance = await _showPlanarDistanceDialog();
                        if (distance != null) {
                          setState(() {
                            _planarDistanceMeters = distance;
                            // Reset measurements when distance changes
                            _currentPlanarMeasurement = null;
                            _planarCorners = null;
                          });
                        }
                      },
                      tooltip:
                          "Đặt khoảng cách: ${_planarDistanceMeters.toStringAsFixed(1)}m",
                    ),
                  // Camera Height Button (Vertical Mode)
                  if (_verticalObjectMode)
                    IconButton(
                      icon: const Icon(Icons.height, color: Colors.orange),
                      onPressed: () async {
                        final height = await _showCameraHeightDialog();
                        if (height != null) {
                          setState(() {
                            _cameraHeightMeters = height;
                            // Reset measurements when height changes
                            _currentVerticalMeasurement = null;
                            _verticalTopPoint = null;
                            _verticalBottomPoint = null;
                          });
                        }
                      },
                      tooltip:
                          "Đặt chiều cao camera: ${_cameraHeightMeters.toStringAsFixed(1)}m",
                    ),
                  if (_groundPlaneMode &&
                      _currentMeasurement != null &&
                      !_isGroundPlaneResultVisible)
                    IconButton(
                      icon: const Icon(Icons.analytics_outlined,
                          color: Colors.white),
                      onPressed: () =>
                          setState(() => _isGroundPlaneResultVisible = true),
                      tooltip: "Hiện kết quả đo",
                    ),
                  if (_planarObjectMode &&
                      _currentPlanarMeasurement != null &&
                      !_isPlanarResultVisible)
                    IconButton(
                      icon: const Icon(Icons.analytics_outlined,
                          color: Colors.white),
                      onPressed: () =>
                          setState(() => _isPlanarResultVisible = true),
                      tooltip: "Hiện kết quả đo",
                    ),
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.white),
                    onPressed: _showInformationScreen,
                    tooltip: "Thông tin",
                  ),
                  IconButton(
                    key: _settingsButtonKey,
                    icon: Icon(
                      _isSettingsOpen
                          ? Icons.settings
                          : Icons.settings_outlined,
                      color: Colors.white,
                    ),
                    onPressed: _toggleSettings,
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Locked to 4:3 (3:4 in portrait)
    const double aspectRatio = 3.0 / 4.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Preview OR Frozen Image
          IgnorePointer(
            // Disable touches on camera preview if measuring (so points can be selected)
            // But if frozen, we need touches? No, GroundPlaneSelector handles touches.
            ignoring:
                _groundPlaneMode || _planarObjectMode || _verticalObjectMode,

            child: Align(
              alignment: Alignment.center,
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_isFrozen && _frozenImageFile != null)
                      Image.file(
                        _frozenImageFile!,
                        fit: BoxFit.cover,
                      )
                    else if (_capturedImages.length >= _requiredImages)
                      Container(color: Colors.black)
                    else if (_isInitialized && _controller != null)
                      ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width,
                              height: MediaQuery.of(context).size.width *
                                  _controller!.value.aspectRatio,
                              child: CameraPreview(_controller!),
                            ),
                          ),
                        ),
                      )
                    else
                      const Center(
                          child:
                              CircularProgressIndicator(color: Colors.white)),
                    if (_isInitialized && _currentOrientation != null)
                      Positioned.fill(
                        child: DeviceLevelIndicator(
                          isLevel: _imuService.isDeviceLevel(),
                          rollDegrees: _currentOrientation!.rollDegrees,
                        ),
                      ),
                    if (_isInitialized)
                      Positioned.fill(
                        child: GridOverlay(visible: _researcherConfig.showGrid),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // 9. Ground Plane Selector (Measurement Mode) (Moved)
          if (_groundPlaneMode &&
              (_isFrozen || (_isInitialized && _controller != null)))
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: GroundPlaneSelector(
                    imageSize: Size(
                      _controller?.value.previewSize?.width.toDouble() ?? 1920,
                      _controller?.value.previewSize?.height.toDouble() ?? 1080,
                    ),
                    measurement: _currentMeasurement,
                    showResult: _isGroundPlaneResultVisible,
                    onCloseResult: () =>
                        setState(() => _isGroundPlaneResultVisible = false),
                    pointA: _groundPointA,
                    pointB: _groundPointB,
                    onStateChanged: (p1, p2) {
                      setState(() {
                        _groundPointA = p1;
                        _groundPointB = p2;
                        if (p1 == null || p2 == null) {
                          _currentMeasurement = null;
                        }
                      });
                    },
                    onPointsSelected: (pointA, pointB) {
                      _performGroundPlaneMeasurement(pointA, pointB);
                    },
                    onClear: () {
                      setState(() {
                        _currentMeasurement = null;
                      });
                    },
                  ),
                ),
              ),
            ),

          // Instruction (Bottom)
          if (_groundPlaneMode)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    _isFrozen
                        ? "Chế độ ảnh tĩnh: Điều chỉnh điểm đo"
                        : "Hướng dẫn: Chạm 2 điểm cần đo",
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),

          // 10. Planar Object Selector (Measurement Mode) (Moved)
          if (_planarObjectMode &&
              _controller != null &&
              _controller!.value.isInitialized)
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: PlanarObjectSelector(
                    imageSize: Size(
                      _controller!.value.previewSize?.width.toDouble() ?? 1920,
                      _controller!.value.previewSize?.height.toDouble() ?? 1080,
                    ),
                    measurement: _currentPlanarMeasurement,
                    referenceObject: _referenceObject,
                    onCornersSelected: (corners) {
                      _performPlanarObjectMeasurement(corners);
                    },
                    onClear: () {
                      setState(() {
                        _currentPlanarMeasurement = null;
                      });
                    },
                  ),
                ),
              ),
            ),

          // 11. Vertical Object Selector (Measurement Mode) (Moved)
          if (_verticalObjectMode &&
              _controller != null &&
              _controller!.value.isInitialized)
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: VerticalObjectSelector(
                    key: ValueKey(_verticalSelectorResetToken),
                    imageSize: Size(
                      _controller!.value.previewSize?.width.toDouble() ?? 1920,
                      _controller!.value.previewSize?.height.toDouble() ?? 1080,
                    ),
                    measurement: _currentVerticalMeasurement,
                    onPointsSelected: (top, bottom) {
                      _performVerticalObjectMeasurement(top, bottom);
                    },
                    onClear: () {
                      setState(() {
                        _currentVerticalMeasurement = null;
                      });
                    },
                  ),
                ),
              ),
            ),

          // 5. Bottom Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0xFF1D2125).withOpacity(0.95),
                    Colors.transparent
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Capture Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Spacer (Left side)
                      const SizedBox(width: 56),

                      // Capture Button
                      Builder(builder: (context) {
                        // Special frozen UI
                        if (_isFrozen) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FilledButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _isFrozen = false;
                                    _frozenImageFile = null;
                                  });
                                  _controller!.resumePreview();
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text("Chụp lại"),
                                style: FilledButton.styleFrom(
                                    backgroundColor: Colors.grey),
                              ),
                              const SizedBox(width: 16),
                              FilledButton.icon(
                                onPressed: _onSaveFrozenImage,
                                icon: const Icon(Icons.check),
                                label: const Text("Lưu"),
                              ),
                            ],
                          );
                        }

                        // Check if mode is selected
                        bool modeMissing = _capturedImages.isEmpty &&
                            _selectedModeType == null;

                        // Check if points are selected (Measurement done)
                        bool measurementMissing = false;
                        if (_selectedModeType ==
                            EstimationModeType.groundPlane) {
                          // If ground plane, we allows capture even if missing points (to enter freeze)
                          measurementMissing = false;
                        } else if (_selectedModeType ==
                            EstimationModeType.planarObject) {
                          measurementMissing =
                              _currentPlanarMeasurement == null;
                        } else if (_selectedModeType ==
                            EstimationModeType.singleView) {
                          measurementMissing =
                              _currentVerticalMeasurement == null;
                        }

                        final isCaptureDisabled =
                            modeMissing || measurementMissing;

                        return IgnorePointer(
                          ignoring: isCaptureDisabled,
                          child: GestureDetector(
                            onTap: () {
                              if (_multiFrameMode && _isMeasuringMultiFrame) {
                                _multiFrameTimer?.cancel();
                                setState(() => _isMeasuringMultiFrame = false);
                              } else {
                                _captureImage(); // Handles both single and multi-frame start
                              }
                            },
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: isCaptureDisabled
                                            ? Colors.grey
                                            : Colors.white,
                                        width: 4),
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isCaptureDisabled
                                          ? Colors.transparent
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                                if (isCaptureDisabled)
                                  const Icon(Icons.block,
                                      color: Colors.grey, size: 40),
                                if (_isCapturing)
                                  const SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: CircularProgressIndicator(
                                      color: Colors.redAccent,
                                      strokeWidth: 4,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),

                      // Complete Button (Right Side) REMOVED
                      const SizedBox(width: 56),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Right Edge Swipe Detector for Settings
          Positioned(
            right: 0,
            top: 100,
            bottom: 100,
            width: 20,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity! < -500) {
                  // Swipe Left
                  if (_settingsAnimationController.status ==
                      AnimationStatus.dismissed) {
                    _toggleSettings();
                  }
                }
              },
              child: Container(color: Colors.transparent),
            ),
          ),

          // IMU Overlay - Fixed at top-left
          if (_showIMU && _currentOrientation != null)
            Positioned(
              top: 80, // Below top bar
              left: 8,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Euler Angles
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('EULER (deg)',
                              style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 9,
                                  letterSpacing: 0.5,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          // Swap roll and pitch when device is rotated ~90°
                          Builder(builder: (context) {
                            final absRoll =
                                _currentOrientation!.rollDegrees.abs();
                            final isRotated = absRoll > 75 && absRoll < 105;

                            final rollValue = _currentOrientation!.rollDegrees;
                            final pitchValue =
                                _currentOrientation!.pitchDegrees;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // First line - R or P depending on rotation
                                Text(
                                    isRotated
                                        ? 'P: ${pitchValue.toStringAsFixed(1)}°'
                                        : 'R: ${rollValue.toStringAsFixed(1)}°',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontFamily: 'Courier',
                                        fontWeight: FontWeight.bold)),
                                // Second line - P or R depending on rotation
                                Text(
                                    isRotated
                                        ? 'R: ${rollValue.toStringAsFixed(1)}°'
                                        : 'P: ${pitchValue.toStringAsFixed(1)}°',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontFamily: 'Courier',
                                        fontWeight: FontWeight.bold)),
                                Text(
                                    'Y: ${_currentOrientation!.yawDegrees.toStringAsFixed(1)}°',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontFamily: 'Courier',
                                        fontWeight: FontWeight.bold)),
                              ],
                            );
                          }),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Rotation Matrix
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('ROTATION MATRIX R',
                              style: TextStyle(
                                  color: Colors.cyan,
                                  fontSize: 9,
                                  letterSpacing: 0.5,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          ..._currentOrientation!
                              .getRotationMatrixAsList()
                              .map((row) => Text(
                                    '[${row[0].toStringAsFixed(2)}, ${row[1].toStringAsFixed(2)}, ${row[2].toStringAsFixed(2)}]',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontFamily: 'Courier',
                                        fontWeight: FontWeight.bold),
                                  )),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Gravity
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('GRAVITY',
                              style: TextStyle(
                                  color: Colors.purpleAccent,
                                  fontSize: 9,
                                  letterSpacing: 0.5,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                              'x: ${_currentOrientation!.gravity.x.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontFamily: 'Courier',
                                  fontWeight: FontWeight.bold)),
                          Text(
                              'y: ${_currentOrientation!.gravity.y.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontFamily: 'Courier',
                                  fontWeight: FontWeight.bold)),
                          Text(
                              'z: ${_currentOrientation!.gravity.z.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontFamily: 'Courier',
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 6. Settings Overlay (Moved to ensure On Top Z-index)
          // Top Control Bar (Overlay)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopControlBar(context),
          ),
          CameraSettingsSidebar(
            animation: _settingsAnimation,
            isFlashOn: _isFlashOn,
            isInitialized: _isInitialized,
            controller: _controller,
            onToggleFlash: _toggleFlash,
            onClose: _toggleSettings,
            settingsButtonKey: _settingsButtonKey,
            timerDuration: _timerDuration,
            onTimerChanged: (val) => setState(() => _timerDuration = val),
            timerPresets: _timerPresets,
            currentZoom: _currentZoom,
            minZoom: _minZoom,
            maxZoom: _maxZoom,
            onZoomChanged: _setZoom,
            isDebugVisible: _isDebugUiVisible,
            onToggleDebug: () {
              setState(() {
                _isDebugUiVisible = !_isDebugUiVisible;
                if (!_isDebugUiVisible) {
                  // Reset all advanced configs
                  _showKMatrix = false;
                  _showIMU = false;
                  _applyUndistortion = false;
                  _edgeSnapping = false;
                  _multiFrameMode = false;
                  // _researcherConfig is guaranteed non-null in this scope per linter
                  _researcherConfig.showGrid = false;
                  _researcherConfig.applyUndistortion = false;
                  _researcherConfig.edgeBasedSnapping = false;
                }
              });
            },
            researcherConfig: _researcherConfig,
            onConfigChanged: (config) {
              // Trigger rebuild since config object is mutable and referenced
              setState(() => _researcherConfig = config);
            },
            onShowKMatrix: () {
              setState(() => _showKMatrix = !_showKMatrix);
            },
            onShowIMU: () {
              setState(() => _showIMU = !_showIMU);
            },
            applyUndistortion: _applyUndistortion,
            onUndistortionChanged: (value) =>
                setState(() => _applyUndistortion = value),
            edgeSnapping: _edgeSnapping,
            onEdgeSnappingChanged: (value) =>
                setState(() => _edgeSnapping = value),
          ),

          // 7. K Matrix Overlay (Researcher Mode)
          if (_showKMatrix)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: KMatrixOverlay(
                profile: _activeProfile,
                kOut: _currentKOut, // Dynamic K_out
                onClose: () => setState(() => _showKMatrix = false),
              ),
            ),

          // 12. Loading Overlay
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                        "Đang xử lý Photogrammetry...\nViệc này có thể mất vài giây.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),

          // 8. Countdown Overlay
          if (_isCountingDown)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: Center(
                  child: Text(
                    '$_countdownSeconds',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 120,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                            color: Colors.black54,
                            blurRadius: 10,
                            offset: Offset(0, 4)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      // FAB Removed as per request
    );
  }

  void _showModeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Chọn chế độ đo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ..._selectorModes.map((mode) => ListTile(
                    leading: Icon(
                      mode.icon,
                      color: _selectedModeType == mode.type
                          ? Theme.of(context).primaryColor
                          : null,
                    ),
                    title: Text(
                      mode.label,
                      style: TextStyle(
                        fontWeight: _selectedModeType == mode.type
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _selectedModeType == mode.type
                            ? Theme.of(context).primaryColor
                            : null,
                      ),
                    ),
                    subtitle: Text(
                      mode.steps.isNotEmpty ? mode.steps.first : '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: _selectedModeType == mode.type
                        ? Icon(Icons.check_circle,
                            color: Theme.of(context).primaryColor)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      _showModeConfirmationDialog(mode);
                    },
                  )),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showInformationScreen() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => const InformationScreen(),
      ),
    );
  }
}
