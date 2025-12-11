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
import 'package:size_estimation/services/photogrammetry_service.dart';
import 'package:size_estimation/services/ml_kit_object_detection_service.dart';
import 'package:size_estimation/views/camera_screen/components/index.dart';
import 'package:size_estimation/utils/index.dart';
import 'package:size_estimation/services/sensor_service.dart';
import 'package:size_estimation/constants/index.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

// Helper class for isolate data
class IsolateData {
  final List<String> imagePaths;
  final double baseline;
  final Map<String, dynamic> intrinsicsMap;

  IsolateData({
    required this.imagePaths,
    required this.baseline,
    required this.intrinsicsMap,
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
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double? _lockedZoomLevel; // Locked zoom after first capture

  // Warning State
  Timer? _warningTimer;
  bool _hasShownAutoWarning = false;
  DateTime? _lastCaptureTime;

  // Photogrammetry State
  final List<CapturedImage> _capturedImages = [];
  final int _requiredImages = PhotogrammetryThresholds.minImages;
  bool _isProcessing = false; // Calculating height
  bool _isCapturing = false; // Taking photo
  final PhotogrammetryService _service = PhotogrammetryService();
  final MLKitObjectDetectionService _objectDetectionService =
      MLKitObjectDetectionService();

  // Settings State
  int _timerDuration = 0;
  int _aspectRatioIndex = 0;
  // Countdown State
  int _countdownSeconds = 0;
  bool _isCountingDown = false;
  List<int> _timerPresets = [3, 5, 10]; // Presets

  late AnimationController _settingsAnimationController;
  late Animation<double> _settingsAnimation;
  final GlobalKey _settingsButtonKey = GlobalKey();

  final SensorService _sensorService = SensorService(); // Added SensorService

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initializeCamera();
    _sensorService.startListening(); // Added Sensor Listen

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

  Future<void> _saveAspectRatio(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('default_aspect_ratio', index);
  }

  @override
  void dispose() {
    _sensorService.dispose(); // Added Sensor Dispose
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

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      if (mounted) _showError('Lỗi khởi tạo camera: $e');
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
      _lockedZoomLevel = null;
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

      // Validate Image Quality
      final warnings = _validateImageQuality();

      // Update warning state
      if (warnings.isNotEmpty) {
        if (!_hasShownAutoWarning) {
          _hasShownAutoWarning = true;
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _showWarningDetails(warnings);
          });
        }
      }

      setState(() {
        _capturedImages.add(CapturedImage(file: file, warnings: warnings));
        _lastCaptureTime = DateTime.now();

        // Lock zoom after first image
        if (_capturedImages.length == 1) {
          _lockedZoomLevel = _currentZoom;
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
    // If photos are taken too rapidly, user might be moving too fast or shaking.
    if (_lastCaptureTime != null) {
      final difference = now.difference(_lastCaptureTime!);
      // < 2 seconds implies very fast movement for "moving camera" photogrammetry
      if (difference.inMilliseconds < 2000) {
        warnings.add('Chụp quá nhanh. Hãy di chuyển từ từ và giữ máy ổn định.');
      }
    }

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

    List<BoundingBox>? detectedBoxes;
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
      detectedBoxes =
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
          detectedBoxes: detectedBoxes!,
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
  }

  @override
  Widget build(BuildContext context) {
    final double aspectRatio = CameraAspectRatios.getRatio(_aspectRatioIndex);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Preview
          Align(
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
                        child: CircularProgressIndicator(color: Colors.white)),
                  if (_isInitialized)
                    Positioned.fill(
                      child: OverlapGuide(
                        images: List.of(_capturedImages),
                        requiredImages: _requiredImages,
                        aspectRatio: aspectRatio,
                      ),
                    ),
                ],
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
                      GestureDetector(
                        onTap: _capturedImages.isNotEmpty ? _openGallery : null,
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
                                              image: FileImage(_capturedImages[
                                                      _capturedImages.length -
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
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color:
                                                _capturedImages.last.hasWarnings
                                                    ? Colors.orange
                                                    : Colors.white,
                                            width:
                                                _capturedImages.last.hasWarnings
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
                  const Text(
                    'Chụp 6 ảnh, di chuyển đều nhau',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
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
          ),

          // 7. Loading Overlay
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
}
