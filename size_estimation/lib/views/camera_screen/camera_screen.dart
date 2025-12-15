import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:size_estimation/models/camera_intrinsics.dart';
import 'package:size_estimation/models/captured_image.dart';
import 'package:size_estimation/models/bounding_box.dart';
import 'package:size_estimation/models/estimation_mode.dart';
import 'package:size_estimation/services/photogrammetry_service.dart';
import 'package:size_estimation/services/mock_object_detection_service.dart';
import 'package:size_estimation/services/sensor_service.dart';
import 'package:size_estimation/views/camera_screen/components/index.dart';
import 'package:size_estimation/utils/index.dart';
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
      label: "Ground Plane",
      description: "Đo khoảng cách trên mặt phẳng ngang",
    ),
    const EstimationMode(
      type: EstimationModeType.planarObject,
      icon: Icons.crop_square,
      label: "Planar Object",
      description: "Đo kích thước vật phẳng với tham chiếu",
    ),
    const EstimationMode(
      type: EstimationModeType.singleView,
      icon: Icons.height,
      label: "Vertical Object",
      description: "Đo chiều cao vật thẳng đứng",
    ),
    const EstimationMode(
      type: EstimationModeType.multiFrame,
      icon: Icons.video_camera_back,
      label: "Multi-frame",
      description: "Đo từ nhiều frame để tăng độ chính xác",
    ),
  ];

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

  // Planar Object Measurement
  bool _planarObjectMode = false; // Planar object measurement mode
  String? _referenceObject; // Reference object for scale (e.g., "A4 Paper")
  PlanarObjectMeasurement? _currentPlanarMeasurement;

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

  // Photogrammetry State
  final List<CapturedImage> _capturedImages = [];
  final int _requiredImages = PhotogrammetryThresholds.minImages;
  bool _isProcessing = false; // Calculating height
  bool _isCapturing = false; // Taking photo
  // final PhotogrammetryService _service = PhotogrammetryService();
  // final YoloObjectDetectionService _objectDetectionService =
  //     YoloObjectDetectionService();
  final MockObjectDetectionService _objectDetectionService =
      MockObjectDetectionService();

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
        if (mounted) _showError('Không tìm thấy camera');
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
      if (mounted) _showError('Lỗi khởi tạo camera: $e');
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
        content:
            Text('Đã đủ số lượng ảnh. Vui lòng xóa bớt hoặc nhấn Hoàn tất.'),
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

    setState(() => _isCapturing = true);

    try {
      final xFile = await _controller!.takePicture();
      final file = File(xFile.path);

      // Validate Stability before capturing
      if (_latestStabilityMetrics != null) {
        bool isStable = _latestStabilityMetrics!.stabilityScore >=
            ImageQualityThresholds.minStabilityScore;
        bool isLevel = _latestStabilityMetrics!.rollDegrees.abs() <=
            ImageQualityThresholds.maxRollDeviation;

        if (!isStable) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Thiết bị đang rung. Vui lòng giữ chắc tay.'),
            duration: Duration(milliseconds: 1000),
            backgroundColor: Colors.orange,
          ));
          setState(() => _isCapturing = false);
          return;
        }

        if (!isLevel) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Thiết bị bị nghiêng. Vui lòng giữ cân bằng.'),
            duration: Duration(milliseconds: 1000),
            backgroundColor: Colors.orange,
          ));
          setState(() => _isCapturing = false);
          return;
        }
      }

      final warnings = _validateImageQuality();

      // Auto-warning dialog logic removed as requested
      // We only store warnings for later review if needed

      setState(() {
        _capturedImages.add(CapturedImage(file: file, warnings: warnings));
        _lastCaptureTime = DateTime.now();

        // Lock zoom after first image
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
          _showProcessDialog();
        }
      }
    } catch (e) {
      _showError('Lỗi chụp ảnh: $e');
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
          'Cảnh báo: Mức zoom hiện tại quá cao (${_currentZoom.toStringAsFixed(1)}x). '
          'Ảnh có thể bị mờ, giảm độ chính xác SfM.');
    }

    // 4. Lighting (Heuristic)
    // If getting brightness is impossible without heavy processing, rely on user observation.
    // Logic: warn if it's very dark? Impossible on pure logic without sensor reading.
    // Just REMOVED the fake "ISO > 400" warning as it was misleading.

    return warnings;
  }

  Future<void> _showWarningDetails(List<String> warnings) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber, color: Colors.orange),
          SizedBox(width: 8),
          Text("Chất lượng ảnh kém")
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: warnings
              .map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text("• $w")))
              .toList(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Đã hiểu"))
        ],
      ),
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
    // Step 1: Detect objects
    setState(() => _isProcessing = true);

    // List<BoundingBox>? detectedBoxes; // Removed top-level declaration
    List<BoundingBox>? selectedBoxes;

    try {
      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang phát hiện vật thể...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Detect objects
      final detectedBoxes =
          await _objectDetectionService.detectObjects(_capturedImages);

      // Close loading dialog
      if (!mounted) return;
      Navigator.pop(context);

      // Check if any objects detected
      if (detectedBoxes.isEmpty) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('Không tìm thấy vật thể'),
              ],
            ),
            content: const Text(
              'Không phát hiện được vật thể nào trong ảnh. '
              'Vui lòng chụp lại với vật thể rõ ràng hơn hoặc tiếp tục mà không chọn vật thể.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _capturedImages.clear();
                    _hasShownAutoWarning = false;
                  });
                },
                child: const Text('Chụp lại'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  // Continue without object selection
                  _showBaselineDialog(null);
                },
                child: const Text('Tiếp tục'),
              ),
            ],
          ),
        );
        return;
      }

      // Step 2: Show object selection dialog
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ObjectSelectionDialog(
          images: _capturedImages,
          detectedBoxes: detectedBoxes,
          enableEdgeSnapping: _researcherConfig.edgeBasedSnapping,
          onConfirm: (boxes) {
            selectedBoxes = boxes;
          },
        ),
      );

      // Check if user selected objects
      if (selectedBoxes == null || selectedBoxes!.isEmpty) {
        // User cancelled or didn't select anything
        if (!mounted) return;
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Chưa chọn vật thể'),
            content: const Text(
              'Bạn chưa chọn vật thể nào. Tiếp tục mà không chọn vật thể có thể giảm độ chính xác.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Quay lại'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Tiếp tục'),
              ),
            ],
          ),
        );

        if (shouldContinue != true) {
          setState(() => _isProcessing = false);
          return;
        }
      }

      // Step 3: Show baseline input dialog
      if (!mounted) return;
      _showBaselineDialog(selectedBoxes);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi phát hiện vật thể: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showBaselineDialog(List<BoundingBox>? selectedBoxes) async {
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
            _runPhotogrammetry(baseline, selectedBoxes);
          },
        );
      },
    );
  }

  Future<void> _runPhotogrammetry(
      double baseline, List<BoundingBox>? selectedBoxes) async {
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kết quả'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(
              '${height.toStringAsFixed(2)} cm',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const Text('Chiều cao ước lượng'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _capturedImages.clear();
              });
            },
            child: const Text('Làm mới'),
          ),
        ],
      ),
    );
  }

  void _showErrorDetails(String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lỗi'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Do NOT clear images on error, allow user to delete/retry
            },
            child: const Text('Đóng'),
          ),
        ],
      ),
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
                            'Ảnh đã chụp',
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
            _cameraHeightMeters = height;
            _groundPlaneMode = true;
            _planarObjectMode = false;
            _verticalObjectMode = false;
            _currentMeasurement = null;
          });
        }
        break;

      case EstimationModeType.planarObject:
        setState(() {
          _groundPlaneMode = false;
          _planarObjectMode = true;
          _verticalObjectMode = false;
          _currentPlanarMeasurement = null;
        });
        break;

      case EstimationModeType.singleView:
        setState(() {
          _groundPlaneMode = false;
          _planarObjectMode = false;
          _verticalObjectMode = true;
          _currentVerticalMeasurement = null;
        });
        break;

      case EstimationModeType.multiFrame:
        // Multi-frame mode can be combined with other modes
        // For now, treat it as vertical object mode
        setState(() {
          _groundPlaneMode = false;
          _planarObjectMode = false;
          _verticalObjectMode = true;
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
          // 1. Camera Preview
          IgnorePointer(
            // Disable long-press gesture when in measurement mode
            ignoring:
                _groundPlaneMode || _planarObjectMode || _verticalObjectMode,
            child: GestureDetector(
              onLongPressStart: (details) {
                // Trigger only near left edge (approx 50px)
                if (details.globalPosition.dx < 60) {
                  setState(() {
                    _dragStartPosition = details.globalPosition;
                    _currentDragPosition = details.globalPosition;
                    _isModeSelectorVisible = true;
                  });
                  HapticFeedback.mediumImpact();
                }
              },
              onLongPressMoveUpdate: (details) {
                if (_isModeSelectorVisible && !_showingModeExplanation) {
                  setState(() {
                    _currentDragPosition = details.globalPosition;
                  });

                  // Detect which mode is being hovered
                  final dx = details.globalPosition.dx - _dragStartPosition.dx;
                  final dy = details.globalPosition.dy - _dragStartPosition.dy;
                  final distance = sqrt(dx * dx + dy * dy);

                  if (distance > 30) {
                    double angle = atan2(dy, dx);
                    const double totalSweep = 180 * (pi / 180);
                    const double startAngle = -totalSweep / 2;
                    final double segmentAngle =
                        totalSweep / _selectorModes.length;

                    if (angle >= startAngle &&
                        angle <= startAngle + totalSweep) {
                      double relative = angle - startAngle;
                      int index = (relative / segmentAngle).floor();
                      if (index >= 0 && index < _selectorModes.length) {
                        // Check if hovering on same mode
                        if (_hoveredModeIndex != index) {
                          // Cancel previous timer
                          _modeHoverTimer?.cancel();
                          _hoveredModeIndex = index;

                          // Start new timer for explanation
                          _modeHoverTimer =
                              Timer(const Duration(milliseconds: 800), () {
                            if (_hoveredModeIndex == index &&
                                _isModeSelectorVisible) {
                              _showModeExplanation(index);
                            }
                          });
                        }
                      }
                    }
                  }
                }
              },
              onLongPressEnd: (details) {
                _modeHoverTimer?.cancel();
                _hoveredModeIndex = null;

                if (_isModeSelectorVisible && !_showingModeExplanation) {
                  _handleModeSelection();
                  setState(() {
                    _isModeSelectorVisible = false;
                  });
                }
              },
              child: Align(
                alignment: Alignment.center,
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_capturedImages.length >= _requiredImages)
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
                          child:
                              GridOverlay(visible: _researcherConfig.showGrid),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Segmented Progress Indicator
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Column(
                children: [
                  Text(
                    _capturedImages.isEmpty
                        ? 'Bắt đầu chụp ảnh'
                        : _capturedImages.length == _requiredImages
                            ? 'Hoàn tất!'
                            : '${_capturedImages.length}/$_requiredImages',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(color: Colors.black45, blurRadius: 2),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Top Bar
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: IgnorePointer(
              // Ignore pointer when in measurement mode to allow selector to receive touches
              ignoring:
                  _groundPlaneMode || _planarObjectMode || _verticalObjectMode,
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
          ),

          // 5. Bottom Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              // Ignore pointer when in measurement mode to allow selector to receive touches
              ignoring:
                  _groundPlaneMode || _planarObjectMode || _verticalObjectMode,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
                        GestureDetector(
                          onTap: _captureImage,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 4),
                                ),
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
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
                                border:
                                    Border.all(color: Colors.white, width: 2),
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
                    const Text(
                      'Chụp 6 ảnh, di chuyển đều nhau',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
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
            groundPlaneMode: _groundPlaneMode,
            onGroundPlaneModeChanged: (value) {
              setState(() {
                _groundPlaneMode = value;
                if (value) {
                  _planarObjectMode = false;
                  _verticalObjectMode = false;
                  _currentMeasurement = null;
                }
              });
            },
            cameraHeightMeters: _cameraHeightMeters,
            onCameraHeightChanged: (value) {
              setState(() => _cameraHeightMeters = value);
            },
            planarObjectMode: _planarObjectMode,
            onPlanarObjectModeChanged: (value) {
              setState(() {
                _planarObjectMode = value;
                if (value) {
                  _groundPlaneMode = false;
                  _verticalObjectMode = false;
                  _currentPlanarMeasurement = null;
                }
              });
            },
            referenceObject: _referenceObject,
            onReferenceObjectChanged: (value) {
              setState(() => _referenceObject = value);
            },
            verticalObjectMode: _verticalObjectMode,
            onVerticalObjectModeChanged: (value) {
              setState(() {
                _verticalObjectMode = value;
                if (value) {
                  _groundPlaneMode = false;
                  _planarObjectMode = false;
                  _currentVerticalMeasurement = null;
                }
              });
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

          // 8.3 Mode Selector Overlay
          if (_isModeSelectorVisible)
            EstimationModeSelector(
              center: _dragStartPosition,
              currentDragPosition: _currentDragPosition,
              isVisible: true,
              modes: _selectorModes,
              onModeSelected: (mode) {}, // Handled by gesture end
            ),

          // 8.2 Math Toggle Button
          Positioned(
            top: 50,
            right: 120, // Next to Settings/K-matrix toggle usually?
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () =>
                    setState(() => _showMathDetails = !_showMathDetails),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30, width: 1.5),
                  ),
                  child: const Icon(Icons.functions,
                      color: Colors.white, size: 24),
                ),
              ),
            ),
          ),

          // 9. Ground Plane Selector (Measurement Mode)
          if (_groundPlaneMode &&
              _controller != null &&
              _controller!.value.isInitialized)
            Positioned.fill(
              child: GroundPlaneSelector(
                imageSize: Size(
                  _controller!.value.previewSize?.width.toDouble() ?? 1920,
                  _controller!.value.previewSize?.height.toDouble() ?? 1080,
                ),
                measurement: _currentMeasurement,
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

          // 10. Planar Object Selector (Measurement Mode)
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

          // 11. Vertical Object Selector (Measurement Mode)
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
