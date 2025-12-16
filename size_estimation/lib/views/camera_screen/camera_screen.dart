import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:size_estimation/models/camera_intrinsics.dart';
import 'package:size_estimation/models/captured_image.dart';
import 'package:size_estimation/models/estimation_mode.dart';
import 'package:size_estimation/services/photogrammetry_service.dart';
import 'package:size_estimation/services/sensor_service.dart';
import 'package:size_estimation/views/camera_screen/components/index.dart';
import 'package:size_estimation/views/camera_screen/components/image_detail_modal.dart';
import 'package:size_estimation/views/shared_components/index.dart';

import 'package:size_estimation/constants/index.dart';
import 'package:size_estimation/views/camera_screen/components/information.dart';
import 'package:size_estimation/models/researcher_config.dart';
import 'package:size_estimation/models/calibration_profile.dart';
import 'package:size_estimation/services/calibration_service.dart';
import 'package:size_estimation/services/dynamic_intrinsics_service.dart';
import 'package:size_estimation/services/imu_service.dart';
import 'package:size_estimation/models/camera_metadata.dart';
import 'package:size_estimation/views/camera_screen/components/grid_overlay.dart';
import 'package:size_estimation/services/lens_distortion_service.dart';
import 'package:size_estimation/services/edge_snapping_service.dart';
import 'package:size_estimation/services/result_averaging_service.dart';
import 'package:size_estimation/services/feature_tracking_service.dart'; // Added
import 'package:size_estimation/services/vanishing_point_service.dart'; // Added
import 'package:size_estimation/views/camera_screen/components/k_matrix_overlay.dart';
import 'package:size_estimation/views/camera_screen/components/imu_overlay.dart';
import 'package:size_estimation/views/camera_screen/components/math_details_overlay.dart'; // Added
import 'package:size_estimation/views/camera_screen/components/estimation_mode_selector.dart'; // Changed from mode_selector_overlay.dart
import 'package:size_estimation/views/camera_screen/components/ground_plane_selector.dart';
import 'package:size_estimation/views/camera_screen/components/planar_object_selector.dart';
import 'package:size_estimation/views/camera_screen/components/vertical_object_selector.dart';
import 'package:size_estimation/views/camera_screen/components/mode_explanation_dialog.dart';
import 'package:size_estimation/services/ground_plane_service.dart';
import 'package:size_estimation/services/planar_object_service.dart';
import 'package:size_estimation/services/vertical_object_service.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

// ... (IsolateData and _isolateEntry helper classes remain the same) ...

// Helper class for isolate data
class IsolateData {
  final List<String> imagePaths;
  final double baseline;
  final Map<String, dynamic> intrinsicsMap;
  final bool applyUndistortion;

  IsolateData({
    required this.imagePaths,
    required this.baseline,
    required this.intrinsicsMap,
    this.applyUndistortion = true,
  });
}

// Top-level function for isolate computation
Future<double> _isolateEntry(IsolateData data) async {
  final service = PhotogrammetryService();
  final intrinsics = CameraIntrinsics.fromMap(data.intrinsicsMap);
  final imageFiles = data.imagePaths.map((path) => File(path)).toList();
  return await service.estimateHeightFromBaseline(
    images: imageFiles,
    knownBaselineCm: data.baseline,
    intrinsics: intrinsics,
    applyUndistortion: data.applyUndistortion,
  );
}

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
  bool _showMathDetails = false; // Added

  // Mode Selector State
  bool _isModeSelectorVisible = false;
  Offset _dragStartPosition = Offset.zero;
  Offset _currentDragPosition = Offset.zero;
  final List<EstimationMode> _selectorModes = [
    const EstimationMode(
      type: EstimationModeType.groundPlane,
      icon: Icons.landscape,
      label: AppStrings.modeGroundPlane,
      description: AppStrings.modeGroundPlaneDesc,
    ),
    const EstimationMode(
      type: EstimationModeType.planarObject,
      icon: Icons.crop_square,
      label: AppStrings.modePlanarObject,
      description: AppStrings.modePlanarObjectDesc,
    ),
    const EstimationMode(
      type: EstimationModeType.singleView,
      icon: Icons.height,
      label: AppStrings.modeVerticalObject,
      description: AppStrings.modeVerticalObjectDesc,
    ),
    const EstimationMode(
      type: EstimationModeType.multiFrame,
      icon: Icons.video_camera_back,
      label: AppStrings.modeMultiFrame,
      description: AppStrings.modeMultiFrameDesc,
    ),
  ];

  EstimationModeType? _selectedModeType; // Track selected mode

  // Hover detection for mode explanation
  Timer? _modeHoverTimer;
  int? _hoveredModeIndex;
  bool _showingModeExplanation = false;

  StreamSubscription? _imuSubscription;
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
  bool _isPlanarResultVisible = true;

  // Vertical Object Measurement
  bool _verticalObjectMode = false;
  VerticalObjectMeasurement? _currentVerticalMeasurement;

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
  Timer? _warningTimer;
  bool _hasShownAutoWarning = false;
  DateTime? _lastCaptureTime;

  // Frozen State for Ground Plane Mode
  bool _isFrozen = false;
  File? _frozenImageFile; // Use File for captured frozen image
  vm.Vector2? _frozenPointA; // Temp storage for points in frozen mode
  vm.Vector2? _frozenPointB;

  // Photogrammetry State
  final List<CapturedImage> _capturedImages = [];
  final int _requiredImages = 1;
  bool _isProcessing = false; // Calculating height
  bool _isCapturing = false; // Taking photo
  // final PhotogrammetryService _service = PhotogrammetryService();
  // final PhotogrammetryService _service = PhotogrammetryService();

  // Settings State
  int _timerDuration = 0;
  int _aspectRatioIndex = 0;
  // Countdown State
  int _countdownSeconds = 0;
  bool _isCountingDown = false;
  List<int> _timerPresets = [3, 5, 10]; // Presets

  StabilityMetrics? _latestStabilityMetrics; // Real-time metrics
  StreamSubscription<StabilityMetrics>? _stabilitySub;

  late AnimationController _settingsAnimationController;
  late Animation<double> _settingsAnimation;
  final GlobalKey _settingsButtonKey = GlobalKey();

  final SensorService _sensorService = SensorService(); // Added SensorService
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
    _sensorService.startListening(); // Added Sensor Listen

    _stabilitySub = _sensorService.stabilityStream.listen((metrics) {
      if (mounted) {
        // Only update if needed to avoid excessive rebuilds,
        // but here we just store it. We don't setState() because
        // StabilityIndicator listens to stream too.
        _latestStabilityMetrics = metrics;
      }
    });

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
          _aspectRatioIndex = prefs.getInt('default_aspect_ratio') ?? 0;
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

  Future<void> _saveAspectRatio(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('default_aspect_ratio', index);
  }

  @override
  void dispose() {
    _sensorService.dispose(); // Added Sensor Dispose
    _imuService.dispose(); // Dispose IMU service
    _dynamicIntrinsicsService.dispose(); // Dispose dynamic intrinsics
    _warningTimer?.cancel();
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
        ResolutionPreset.high,
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

  void _resetSession() {
    setState(() {
      _capturedImages.clear();
      _hasShownAutoWarning = false;
      // Reset zoom lock
      // Restore original zoom range
      _controller?.getMaxZoomLevel().then((max) {
        _controller?.getMinZoomLevel().then((min) {
          if (mounted) {
            setState(() {
              _minZoom = min;
              _maxZoom = max;
            });
          }
        });
      });
    });
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
      /*
      // User requested to NOT show the selector automatically
      setState(() {
        _isModeSelectorVisible = true;
        // ...
      });
      */
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(AppStrings.selectModeRequired),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ));
      return;
    }

    // New: Check if measurement points are selected for the active mode
    // We assume capture is "Start Recording" or "Capture Evidence".
    // If the user wants to capture the measurement result, they must have measured first.
    bool measurementReady = true;
    String missingPointsMsg = "";

    if (_selectedModeType == EstimationModeType.groundPlane) {
      if (_groundPointA == null || _groundPointB == null) {
        measurementReady = false;
        missingPointsMsg = AppStrings.selectPointsGround;
      }
    } else if (_selectedModeType == EstimationModeType.planarObject) {
      if (_currentPlanarMeasurement == null) {
        measurementReady = false;
        missingPointsMsg = AppStrings.selectPointsPlanar;
      }
    }
    // Multi-frame might behave differently (capture to measure?), but usually
    // user captures frames THEN processing happens.
    // However, the request implies standard static measurement modes.

    if (!measurementReady) {
      // Special case for Ground Plane Freeze Mode:
      // If prompt says "Capture to freeze", we allow capture even if points are null
      if (_selectedModeType == EstimationModeType.groundPlane && !_isFrozen) {
        // ALLOW capture to enter freeze mode
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(missingPointsMsg),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ));
        return;
      }
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

    setState(() => _isCapturing = true);

    try {
      final xFile = await _controller!.takePicture();
      final file = File(xFile.path);

      if (_groundPlaneMode && !_isFrozen) {
        setState(() {
          _isFrozen = true;
          _frozenImageFile = file;
          _isCapturing = false;
        });
        await _controller!.pausePreview();
        return;
      }

      // Simplified validation to avoid errors
      List<String> warnings = [];

      setState(() {
        _capturedImages.add(CapturedImage(file: file, warnings: warnings));
        _lastCaptureTime = DateTime.now();

        if (_capturedImages.length == 1) {
          _minZoom = _currentZoom;
          _maxZoom = _currentZoom;
        }
      });

      if (_capturedImages.length >= _requiredImages) {
        // If the last image has warnings, user requested to see the warning dialog FIRST,
        // then the completion sheet only after closing it (OK).
        // If it was already auto-shown above (via _hasShownAutoWarning), we might just wait for it?
        // But _hasShownAutoWarning is async inside Future.delayed.
        // Simplified Logic: If last image has warnings, FORCE show/wait for warning dialog.

        if (warnings.isNotEmpty) {
          await _showWarningDetails(warnings);
        }

        if (mounted) {
          // Temporarily show the image detail directly
          showDialog(
            context: context,
            builder: (context) => ImageDetailModal(
              image: _capturedImages.last,
              index: 0,
            ),
          );
        }
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

  Future<void> _showWarningDetails(List<String> warnings) {
    return CommonAlertDialog.show(
      context: context,
      title: AppStrings.qualityWarningTitle,
      icon: Icons.warning_amber,
      iconColor: Colors.orange,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: warnings
            .map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text("• $w",
                    style: const TextStyle(color: Colors.white70))))
            .toList(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.understood))
      ],
    );
  }

  void _resetFlow() {
    setState(() {
      _capturedImages.clear();
      _isProcessing = false;
    });
    Navigator.of(context).pop();
  }

  Future<void> _showProcessDialog() async {
    // Skip object detection and go straight to baseline input
    if (!mounted) return;
    _showBaselineDialog(null);
  }

  Future<void> _showBaselineDialog(List<dynamic>? _) async {
    // Note: Parameter kept to match signature if needed, or better remove it
    // but simplifying to just void if possible. Let's do a clean void.
    // Actually, I'll update the signature below.
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return CaptureCompletion(
          images: _capturedImages,
          onRetakeAll: () {
            setState(() {
              _capturedImages.clear();
              _hasShownAutoWarning = false;
            });
            Navigator.pop(ctx);
          },
          onSubmit: (baseline) {
            Navigator.pop(ctx);
            _runPhotogrammetry(baseline);
          },
        );
      },
    );
  }

  Future<void> _runPhotogrammetry(double baseline) async {
    setState(() => _isProcessing = true);

    // Give UI a moment to render the loading state
    await Future.delayed(const Duration(milliseconds: 100));

    // Prepare Intrinsics
    double width = _controller!.value.previewSize?.width ?? 1080;
    double height = _controller!.value.previewSize?.height ?? 1920;
    if (width > height) {
      double t = width;
      width = height;
      height = t;
    }

    // Rough approximation: f ~= width (approx 53 deg FOV)
    final intrinsics = CameraIntrinsics(
      focalLength: width * 1.2,
      cx: width / 2,
      cy: height / 2,
      sensorWidth: 6.4, // typical 1/2" sensor mm
      sensorHeight: 4.8,
      distortionCoefficients: List.filled(
          5, 0.0), // Zero distortion assumption for now (or minimal)
    );

    try {
      // Run heavy computation in a background isolate
      // We need to pass serializable data. File paths are serializable.
      final imagePaths = _capturedImages.map((e) => e.file.path).toList();

      final result = await compute(
        _isolateEntry,
        IsolateData(
          imagePaths: imagePaths,
          baseline: baseline,
          intrinsicsMap: intrinsics.toMap(),
          applyUndistortion: _researcherConfig.applyUndistortion,
        ),
      );

      if (!mounted) return;
      _showResultDialog(result);
    } catch (e) {
      if (!mounted) return;
      _showErrorDetails(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showResultDialog(double height) {
    CommonAlertDialog.show(
      context: context,
      title: AppStrings.resultTitle,
      icon: Icons.check_circle,
      iconColor: Colors.green,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 64),
          const SizedBox(height: 16),
          Text(
            '${height.toStringAsFixed(2)} cm',
            style: const TextStyle(
                fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(AppStrings.estimatedHeight,
              style: TextStyle(color: Colors.white70)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            setState(() {
              _capturedImages.clear();
            });
          },
          child: const Text(AppStrings.refresh),
        ),
      ],
    );
  }

  void _showErrorDetails(String error) {
    CommonAlertDialog.show(
      context: context,
      title: AppStrings.errorTitle,
      icon: Icons.error_outline,
      iconColor: Colors.red,
      contentText: error,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            // Do NOT clear images on error, allow user to delete/retry
          },
          child: const Text(AppStrings.close),
        ),
      ],
    );
  }

  // --- Gallery & Review Logic ---

  void _openGallery() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              minChildSize: 0.5,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Text(
                            AppStrings.galleryTitle,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              _confirmReset(context);
                            },
                            icon: const Icon(Icons.restart_alt,
                                color: Colors.redAccent),
                            label: const Text(
                              'Chụp lại từ đầu',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white24),
                    // Grid
                    Expanded(
                      child: _capturedImages.isEmpty
                          ? const Center(
                              child: Text(
                                'Chưa có ảnh nào',
                                style: TextStyle(color: Colors.white54),
                              ),
                            )
                          : GridView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: _capturedImages.length,
                              itemBuilder: (context, index) {
                                final capturedImage = _capturedImages[index];
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    GestureDetector(
                                      onLongPress: () {
                                        if (capturedImage.hasWarnings) {
                                          _showWarningDetails(
                                              capturedImage.warnings);
                                        }
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          capturedImage.file,
                                          fit: BoxFit.cover,
                                          color: capturedImage.hasWarnings
                                              ? Colors.black38
                                              : null,
                                          colorBlendMode:
                                              capturedImage.hasWarnings
                                                  ? BlendMode.darken
                                                  : null,
                                        ),
                                      ),
                                    ),
                                    if (capturedImage.hasWarnings)
                                      Positioned(
                                        top: 4,
                                        left: 4,
                                        child: GestureDetector(
                                          onTap: () => _showWarningDetails(
                                              capturedImage.warnings),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.orange,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.priority_high,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () {
                                          setSheetState(() {
                                            _deleteImage(index);
                                          });
                                          // Update parent state as well to reflect in UI
                                          this.setState(() {});
                                          if (_capturedImages.isEmpty) {
                                            Navigator.pop(ctx);
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 4,
                                      left: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '#${index + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _deleteImage(int index) {
    if (index >= 0 && index < _capturedImages.length) {
      setState(() {
        _capturedImages.removeAt(index);
      });
    }
  }

  void _confirmReset(BuildContext dialogContext) {
    showDialog(
      context: dialogContext,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text(
            'Bạn có chắc chắn muốn xóa tất cả ảnh và chụp lại không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close alert
              Navigator.pop(dialogContext); // Close bottom sheet
              setState(() {
                _capturedImages.clear();
                _hasShownAutoWarning = false;
              });
            },
            child: const Text('Đồng ý', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
        setState(() {
          _selectedModeType = type; // Set selected mode
          _groundPlaneMode = false;
          _planarObjectMode = true;
          _verticalObjectMode = false;
          _currentPlanarMeasurement = null;
        });
        break;

      case EstimationModeType.singleView:
        setState(() {
          _selectedModeType = type; // Set selected mode
          _groundPlaneMode = false;
          _planarObjectMode = false;
          _verticalObjectMode = true;
          _currentVerticalMeasurement = null;
        });
        break;

      case EstimationModeType.multiFrame:
        // Multi-frame mode can be combined with other modes
        setState(() {
          _selectedModeType = type; // Set selected mode
          _groundPlaneMode = false;
          _planarObjectMode = false;
          _verticalObjectMode =
              true; // Use vertical mode UI for now? Or separate?
          _currentVerticalMeasurement = null;
        });
        break;
    }
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

  Future<void> _performGroundPlaneMeasurement(
      vm.Vector2 pointA, vm.Vector2 pointB) async {
    // Check if we have all required data
    if (_currentKOut == null) {
      _showError('Camera intrinsics not available');
      return;
    }

    if (_currentOrientation == null) {
      _showError('IMU orientation not available');
      return;
    }

    // Check if device is level enough
    final service = GroundPlaneService();
    if (!service.isOrientationSuitable(_currentOrientation!)) {
      _showError('Device is too tilted. Please hold device more level.');
      return;
    }

    // Advanced Processing
    final p1 = _undistortPoint(_snapPoint(pointA));
    final p2 = _undistortPoint(_snapPoint(pointB));

    Future<GroundPlaneMeasurement?> measure() async {
      try {
        return await service.measureDistance(
          imagePointA: p1,
          imagePointB: p2,
          kOut: _currentKOut!,
          orientation: _currentOrientation!,
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
              kOut: _currentKOut!,
              orientation: _currentOrientation!,
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
    // Check if we have required data
    if (_currentKOut == null) {
      _showError('Camera intrinsics not available');
      return;
    }

    // Advanced Processing (Snap/Undistort)
    final refinedCorners =
        corners.map((c) => _undistortPoint(_snapPoint(c))).toList();

    // Validate corners
    final service = PlanarObjectService();
    if (!service.isValidQuadrilateral(refinedCorners)) {
      _showError('Invalid quadrilateral. Please select corners in order.');
      return;
    }

    try {
      double? refWidth;
      double? refHeight;
      if (_referenceObject != null) {
        final refs = PlanarObjectService.getReferenceSizes();
        if (refs.containsKey(_referenceObject)) {
          refWidth = refs[_referenceObject]!['width'];
          refHeight = refs[_referenceObject]!['height'];
        }
      }

      Future<PlanarObjectMeasurement?> measure() async {
        try {
          return await service.measureObject(
            corners: refinedCorners,
            kOut: _currentKOut!,
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
    // Check requirements
    if (_currentKOut == null) {
      _showError('Camera intrinsics not available');
      return;
    }
    if (_currentOrientation == null) {
      _showError('IMU orientation not available');
      return;
    }

    final p1 = _undistortPoint(_snapPoint(top));
    final p2 = _undistortPoint(_snapPoint(bottom));
    final service = VerticalObjectService();

    // Vanishing Point Refinement (Advanced Module C)
    if (_latestImage != null) {
      final vp =
          _vanishingPointService.estimateVerticalVanishingPoint(_latestImage!);
      if (vp != null) {
        // We found a Vertical VP. In a perfect world, for portrait,
        // VP(x) approx cx, and VP(y) relates to pitch.
        // This implies we could refine _currentOrientation.
        // For now, we just log it as "Refined Orientation available".
        debugPrint("Vertical VP found at $vp. Could refine pitch.");
      }
    }

    Future<VerticalObjectMeasurement?> measure() async {
      try {
        return await service.measureHeight(
          topPixel: p1,
          bottomPixel: p2,
          kOut: _currentKOut!,
          orientation: _currentOrientation!,
          cameraHeightMeters: _cameraHeightMeters,
        );
      } catch (e) {
        return null;
      }
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
                kOut: _currentKOut!,
                orientation: _currentOrientation!,
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
      _showError('Measurement failed: $e');
      debugPrint('Vertical object measurement error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final double aspectRatio = CameraAspectRatios.getRatio(_aspectRatioIndex);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 0. Header for Ground Plane Mode (Custom Requirement)
          if (_groundPlaneMode)
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "📐 ĐO TRÊN MẶT SÀN",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          StreamBuilder<IMUOrientation>(
                            stream: _imuService.orientationStream,
                            builder: (context, snapshot) {
                              final pitch = snapshot.data?.pitchDegrees
                                      .toStringAsFixed(0) ??
                                  "--";
                              // Check if within reasonable range (e.g., -90 to 0)
                              // Just showing raw value as requested
                              return Text(
                                "Pitch: $pitch° ✅", // TODO: Add logic for checkmark
                                style: const TextStyle(
                                    color: Colors.greenAccent, fontSize: 13),
                              );
                            },
                          ),
                          Text(
                            "h: ${_cameraHeightMeters.toStringAsFixed(1)}m",
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),

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
                    if (_isInitialized)
                      Positioned.fill(
                        child: OverlapGuide(
                          images: List.of(_capturedImages),
                          requiredImages: _requiredImages,
                          aspectRatio: aspectRatio,
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
          // 9. Ground Plane Selector (Measurement Mode) (Moved)
          if (_groundPlaneMode &&
              (_isFrozen || (_isInitialized && _controller != null)))
            Positioned.fill(
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
              child: PlanarObjectSelector(
                imageSize: Size(
                  _controller!.value.previewSize?.width.toDouble() ?? 1920,
                  _controller!.value.previewSize?.height.toDouble() ?? 1080,
                ),
                measurement: _currentPlanarMeasurement,
                referenceObject: _referenceObject,
                showResult: _isPlanarResultVisible,
                onCloseResult: () =>
                    setState(() => _isPlanarResultVisible = false),
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

          // 11. Vertical Object Selector (Measurement Mode) (Moved)
          if (_verticalObjectMode &&
              _controller != null &&
              _controller!.value.isInitialized)
            Positioned.fill(
              child: VerticalObjectSelector(
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

          // Mode Selector Gesture Zone (Left Edge)
          Positioned(
            left: 0,
            top: 100, // Avoid Top Bar
            bottom: 150, // Avoid Bottom Bar
            width: 40, // Trigger Zone Width
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (details) {
                setState(() {
                  _isModeSelectorVisible = true;
                  _dragStartPosition = details.globalPosition;
                  _currentDragPosition = details.globalPosition;
                });
                HapticFeedback.lightImpact();
              },
              onPanUpdate: (details) {
                setState(() {
                  _currentDragPosition = details.globalPosition;
                });
              },
              onPanEnd: (details) {
                _handleModeSelection();
                setState(() {
                  _isModeSelectorVisible = false;
                });
              },
              child: Container(color: Colors.transparent),
            ),
          ),

          // Mode Selector Overlay display
          if (_isModeSelectorVisible)
            Positioned.fill(
              child: EstimationModeSelector(
                center: _dragStartPosition,
                currentDragPosition: _currentDragPosition,
                isVisible: true,
                modes: _selectorModes,
                onModeSelected:
                    (mode) {}, // Logic handled in onPanEnd via _handleModeSelection
              ),
            ),

          // 3. Top Bar
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          if (_researcherConfig
                              .showImuInfo) // Controlled by Researcher Mode
                            StreamBuilder<StabilityMetrics>(
                                stream: _sensorService.stabilityStream,
                                initialData: StabilityMetrics(
                                    stabilityScore: 1.0,
                                    isLevel: true,
                                    rollDegrees: 0,
                                    isStable: true),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData)
                                    return const SizedBox(
                                        height: 6, width: 100);
                                  return SizedBox(
                                      width: 120,
                                      child: StabilityIndicator(
                                          metrics: snapshot.data!));
                                }),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_groundPlaneMode &&
                            _currentMeasurement != null &&
                            !_isGroundPlaneResultVisible)
                          IconButton(
                            icon: const Icon(Icons.analytics_outlined,
                                color: Colors.white),
                            onPressed: () => setState(
                                () => _isGroundPlaneResultVisible = true),
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
                          icon: const Icon(Icons.info_outline,
                              color: Colors.white),
                          onPressed: _showInformationScreen,
                          tooltip: "Thông tin",
                        ),
                        IconButton(
                          icon: const Icon(Icons.restart_alt,
                              color: Colors.white),
                          onPressed: _resetSession,
                          tooltip: "Chụp lại từ đầu",
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
          ),

          // 5. Bottom Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Capture Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Gallery / Review Button
                      if (!_isFrozen)
                        GestureDetector(
                          onTap:
                              _capturedImages.isNotEmpty ? _openGallery : null,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3)),
                            ),
                            child: _capturedImages.isNotEmpty
                                ? Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Stack effect
                                      if (_capturedImages.length > 1)
                                        Transform.rotate(
                                          angle: 0.2,
                                          child: Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              image: DecorationImage(
                                                image: FileImage(
                                                    _capturedImages[
                                                            _capturedImages
                                                                    .length -
                                                                2]
                                                        .file),
                                                fit: BoxFit.cover,
                                                opacity: 0.6,
                                              ),
                                            ),
                                          ),
                                        ),
                                      // Top Image
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: _capturedImages
                                                      .last.hasWarnings
                                                  ? Colors.orange
                                                  : Colors.white,
                                              width: _capturedImages
                                                      .last.hasWarnings
                                                  ? 2.5
                                                  : 1.5),
                                          image: DecorationImage(
                                            image: FileImage(
                                                _capturedImages.last.file),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Icon(Icons.photo_library_outlined,
                                    color: Colors.white.withOpacity(0.5)),
                          ),
                        ),

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
                                onPressed: () {
                                  // Save currently selected points as result
                                  // Or just capture this as evidence?
                                  // For now, assume "Done" means save to list
                                  setState(() {
                                    _isFrozen = false;
                                    // Add to captured images list properly
                                    // But wait, the file is _frozenImageFile
                                    if (_frozenImageFile != null) {
                                      _capturedImages.add(CapturedImage(
                                          file: _frozenImageFile!));
                                    }
                                    _frozenImageFile = null;
                                  });
                                  _controller!.resumePreview();
                                },
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

                        return GestureDetector(
                          onTap:
                              _captureImage, // Logic inside handles the check
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
                        );
                      }),

                      // Complete Button (Right Side)
                      if (_capturedImages.length >= _requiredImages)
                        GestureDetector(
                          onTap: _showProcessDialog,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).primaryColor,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.check,
                                color: Colors.white, size: 32),
                          ),
                        )
                      else
                        const SizedBox(width: 56),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // 6. Settings Overlay (Moved to ensure On Top Z-index)
          CameraSettingsOverlay(
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
            aspectRatioIndex: _aspectRatioIndex,
            onAspectRatioChanged: (val) {
              _saveAspectRatio(val);
              setState(() => _aspectRatioIndex = val);
            },
            currentZoom: _currentZoom,
            minZoom: _minZoom,
            maxZoom: _maxZoom,
            onZoomChanged: _setZoom,
            isDebugVisible: _isDebugUiVisible,
            onToggleDebug: () {
              setState(() {
                _isDebugUiVisible = !_isDebugUiVisible;
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
            onCalibrationPlayground: () {
              context.push('/calibration-playground');
            },
            applyUndistortion: _applyUndistortion,
            onUndistortionChanged: (value) =>
                setState(() => _applyUndistortion = value),
            edgeSnapping: _edgeSnapping,
            onEdgeSnappingChanged: (value) =>
                setState(() => _edgeSnapping = value),
            multiFrameMode: _multiFrameMode,
            onMultiFrameModeChanged: (value) =>
                setState(() => _multiFrameMode = value),
            onShowMathDetails: () {
              setState(() => _showMathDetails = !_showMathDetails);
            },
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

          // 8. IMU Overlay (Researcher Mode)
          if (_showIMU)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: IMUOverlay(
                orientation: _currentOrientation,
                onClose: () => setState(() => _showIMU = false),
              ),
            ),

          // 8.1 Math Details Overlay (Researcher Mode)
          if (_showMathDetails)
            MathDetailsOverlay(
              mode: _groundPlaneMode
                  ? 'ground'
                  : _planarObjectMode
                      ? 'planar'
                      : 'vertical', // Assuming one mode is active at a time
              onClose: () => setState(() => _showMathDetails = false),
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

  void _showModeExplanation(int index) async {
    if (index < 0 || index >= _selectorModes.length) return;

    setState(() {
      _showingModeExplanation = true;
      _isModeSelectorVisible = false;
    });

    HapticFeedback.mediumImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ModeExplanationDialog(
        mode: _selectorModes[index],
      ),
    );

    setState(() {
      _showingModeExplanation = false;
    });

    // If user confirmed (pressed "Đã hiểu"), activate the mode
    if (confirmed == true) {
      final selectedMode = _selectorModes[index];
      await _switchModeByType(selectedMode.type);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Đã kích hoạt: ${selectedMode.label}'),
        duration: const Duration(milliseconds: 800),
      ));
    }
  }

  void _handleModeSelection() {
    final dx = _currentDragPosition.dx - _dragStartPosition.dx;
    final dy = _currentDragPosition.dy - _dragStartPosition.dy;
    final distance = sqrt(dx * dx + dy * dy);

    if (distance > 30) {
      double angle = atan2(dy, dx);
      // Fan Logic: Right Facing (Center 0)
      // Span 180 deg -> -90 to +90 deg
      const double totalSweep = 180 * (pi / 180);
      const double startAngle = -totalSweep / 2;
      final double segmentAngle = totalSweep / _selectorModes.length;

      if (angle >= startAngle && angle <= startAngle + totalSweep) {
        double relative = angle - startAngle;
        int index = (relative / segmentAngle).floor();
        if (index >= 0 && index < _selectorModes.length) {
          final selectedMode = _selectorModes[index];
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Đã chọn: ${selectedMode.label}'),
              duration: const Duration(milliseconds: 500)));
          // Actually switch to the selected mode
          _switchModeByType(selectedMode.type);
        }
      }
    }
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
