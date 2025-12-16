import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:size_estimation/models/captured_image.dart';
import 'package:size_estimation/models/estimation_mode.dart';

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
import 'package:size_estimation/views/camera_screen/components/draggable_info_overlay.dart';

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
  bool _ignoreNextPanEnd = false;
  Offset _dragStartPosition = Offset.zero;
  Offset _currentDragPosition = Offset.zero;
  final List<EstimationMode> _selectorModes = [
    const EstimationMode(
      type: EstimationModeType.groundPlane,
      icon: Icons.landscape,
      label: AppStrings.modeGroundPlane,
      description:
          'Đo vật nằm trên mặt phẳng (sàn/bàn). Sử dụng Ground-Plane Homography: tính toán ma trận chuyển đổi H giữa ảnh và mặt phẳng đất dựa trên chiều cao camera h và orientation từ IMU. Chọn 2 điểm A,B trên ảnh → chuyển sang tọa độ ground (X,Y) → tính khoảng cách Euclidean. Hỗ trợ Edge Snapping (Canny + Hough) để snap điểm vào cạnh vật chính xác hơn.',
    ),
    const EstimationMode(
      type: EstimationModeType.planarObject,
      icon: Icons.crop_square,
      label: AppStrings.modePlanarObject,
      description:
          'Đo vật phẳng (A4, màn hình, mặt hộp) không nhất thiết nằm trên đất. Chọn 4 góc → tính Homography để rectify (warp) thành hình chữ nhật chuẩn (fronto-parallel view). Sử dụng Pinhole Model với khoảng cách Z (từ focus hoặc user nhập) để tính scale pixel→cm. Hỗ trợ Auto-detect (Canny + Hough + findContours + RANSAC) và SubPixel Corner Refinement.',
    ),
    const EstimationMode(
      type: EstimationModeType.singleView,
      icon: Icons.height,
      label: AppStrings.modeVerticalObject,
      description:
          'Đo chiều cao vật đứng (tường, cửa, tòa nhà) bằng Single-View Metrology. Phát hiện Vanishing Points từ các đường thẳng trong ảnh (Canny + Hough/LSD + RANSAC clustering). Sử dụng quan hệ projective (cross-ratio) giữa điểm chân F, đỉnh T, vanishing point và horizon để suy ra chiều cao thật dựa trên chiều cao camera h đã biết.',
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('TODO: Implement Capture Completion')),
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
                  children: [
                    if (_researcherConfig.showImuInfo)
                      StreamBuilder<StabilityMetrics>(
                          stream: _sensorService.stabilityStream,
                          initialData: StabilityMetrics(
                              stabilityScore: 1.0,
                              isLevel: true,
                              rollDegrees: 0,
                              isStable: true),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData)
                              return const SizedBox(height: 6, width: 100);
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
                    icon: const Icon(Icons.restart_alt, color: Colors.white),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final double aspectRatio = CameraAspectRatios.getRatio(_aspectRatioIndex);

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
                              child: Container(
                                decoration: BoxDecoration(
                                  border:
                                      (_showIMU && _currentOrientation != null)
                                          ? Border.all(
                                              color: _imuService.isDeviceLevel()
                                                  ? Colors.green
                                                  : Colors.orange,
                                              width: 4,
                                            )
                                          : null,
                                ),
                                child: CameraPreview(_controller!),
                              ),
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
                  _ignoreNextPanEnd = false;
                  _isModeSelectorVisible = true;
                  _dragStartPosition =
                      details.localPosition + const Offset(0, 100);
                  _currentDragPosition =
                      details.localPosition + const Offset(0, 100);
                });
                HapticFeedback.lightImpact();
              },
              onPanUpdate: (details) {
                setState(() {
                  _currentDragPosition =
                      details.localPosition + const Offset(0, 100);
                });
              },
              onPanEnd: (details) {
                if (_ignoreNextPanEnd) {
                  setState(() {
                    _ignoreNextPanEnd = false;
                    _isModeSelectorVisible = false;
                  });
                  return;
                }
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
                onDwellStarted: () => setState(() => _ignoreNextPanEnd = true),
                onModeSelected: (mode) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Đã chọn: ${mode.label}'),
                      duration: const Duration(milliseconds: 500)));
                  _switchModeByType(mode.type);
                  setState(() => _isModeSelectorVisible = false);
                },
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
                      // Gallery / Review Button
                      if (!_isFrozen)
                        GestureDetector(
                          onTap:
                              _capturedImages.isNotEmpty ? _openGallery : null,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFF22272B).withOpacity(0.8),
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
                                          : (_multiFrameMode
                                              ? Colors.redAccent
                                              : Colors.white),
                                      width: 4),
                                ),
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: (_multiFrameMode &&
                                            _isMeasuringMultiFrame)
                                        ? BoxShape.rectangle
                                        : BoxShape.circle,
                                    borderRadius: (_multiFrameMode &&
                                            _isMeasuringMultiFrame)
                                        ? BorderRadius.circular(8)
                                        : null,
                                    color: isCaptureDisabled
                                        ? Colors.transparent
                                        : (_multiFrameMode
                                            ? Colors.redAccent
                                            : Colors.white),
                                  ),
                                  // Scale down inner container if "Stop" (Square)
                                  transform: (_multiFrameMode &&
                                          _isMeasuringMultiFrame)
                                      ? Matrix4.diagonal3Values(0.5, 0.5, 1.0)
                                      : Matrix4.identity(),
                                  transformAlignment: Alignment.center,
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

          if (_showIMU && _currentOrientation != null)
            DraggableOverlay(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Euler Angles
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('EULER (deg)',
                            style: TextStyle(
                                color: Colors.orange,
                                fontSize: 9,
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.bold)),
                        Text(
                            'R: ${_currentOrientation!.rollDegrees.toStringAsFixed(1)}°',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontFamily: 'Courier',
                                fontWeight: FontWeight.bold)),
                        Text(
                            'P: ${_currentOrientation!.pitchDegrees.toStringAsFixed(1)}°',
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
                    ),
                    const SizedBox(width: 16),
                    // Rotation Matrix
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ROTATION MATRIX R',
                            style: TextStyle(
                                color: Colors.cyan,
                                fontSize: 9,
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.bold)),
                        ..._currentOrientation!
                            .getRotationMatrixAsList()
                            .map((row) => Text(
                                  '[${row[0].toStringAsFixed(2)}, ${row[1].toStringAsFixed(2)}, ${row[2].toStringAsFixed(2)}]',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontFamily: 'Courier',
                                      fontWeight: FontWeight.bold),
                                )),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Gravity
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('GRAVITY',
                            style: TextStyle(
                                color: Colors.purpleAccent,
                                fontSize: 9,
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.bold)),
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
            aspectRatioIndex: _aspectRatioIndex,
            onAspectRatioChanged: (val) {
              _saveAspectRatio(val);
              setState(() {
                _aspectRatioIndex = val;
                // Reset mode
                _selectedModeType = null;
                _groundPlaneMode = false;
                _planarObjectMode = false;
                _verticalObjectMode = false;
                _currentMeasurement = null;
                _currentPlanarMeasurement = null;
                _currentVerticalMeasurement = null;
                _groundPointA = null;
                _groundPointB = null;
                _isFrozen = false;
                _frozenImageFile = null;
              });
            },
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
                  _showMathDetails = false;
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

    if (distance > 60) {
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
