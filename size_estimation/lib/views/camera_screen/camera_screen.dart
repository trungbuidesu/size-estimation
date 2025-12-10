import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:size_estimation/views/camera_screen/components/index.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isSettingsOpen = false;
  bool _isFlashOn = false;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _baseScale = 1.0;
  double _currentScale = 1.0;
  Offset? _focusPoint;
  bool _isFocusing = false;

  // Settings State
  int _timerDuration = 0; // 0 = Off, 3 = 3s, 10 = 10s
  int _aspectRatioIndex = 0; // 0 = Full (16:9), 1 = 4:3

  late AnimationController _settingsAnimationController;
  late Animation<double> _settingsAnimation;
  final GlobalKey _settingsButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _settingsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _settingsAnimation = CurvedAnimation(
      parent: _settingsAnimationController,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) {
          _showError('Không tìm thấy camera');
        }
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
      if (mounted) {
        _showError('Lỗi khởi tạo camera: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _toggleSettings() {
    if (_isSettingsOpen) {
      _settingsAnimationController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _isSettingsOpen = false;
          });
        }
      });
    } else {
      setState(() {
        _isSettingsOpen = true;
      });
      _settingsAnimationController.forward();
    }
  }

  void _toggleFlash() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
    _controller!.setFlashMode(
      _isFlashOn ? FlashMode.torch : FlashMode.off,
    );
  }

  void _setZoom(double zoom) {
    if (_controller == null || !_isInitialized) return;
    final clampedZoom = zoom.clamp(_minZoom, _maxZoom);
    setState(() {
      _currentZoom = clampedZoom;
    });
    _controller!.setZoomLevel(clampedZoom);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseScale = _currentZoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final newScale = _baseScale * details.scale;
    _setZoom(newScale);
  }

  Future<void> _onTapToFocus(
      TapDownDetails details, BoxConstraints constraints) async {
    if (_controller == null || !_isInitialized || _isFocusing) return;

    final offset = details.localPosition;
    final x = offset.dx / constraints.maxWidth;
    final y = offset.dy / constraints.maxHeight;

    setState(() {
      _focusPoint = offset;
      _isFocusing = true;
    });

    try {
      await _controller!.setFocusPoint(Offset(x, y));
      await _controller!.setExposurePoint(Offset(x, y));
    } catch (e) {
      // Some cameras don't support focus point
    }

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isFocusing = false;
          _focusPoint = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _settingsAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera Preview
            if (_isInitialized && _controller != null)
              LayoutBuilder(
                builder: (context, constraints) {
                  final size = MediaQuery.of(context).size;
                  final aspectRatio = _controller!.value.aspectRatio;
                  final screenAspectRatio = size.height / size.width;

                  // Calculate proper dimensions to avoid distortion
                  double previewWidth;
                  double previewHeight;

                  if (aspectRatio > screenAspectRatio) {
                    // Camera is taller than screen
                    previewHeight = size.height;
                    previewWidth = size.height / aspectRatio;
                  } else {
                    // Camera is wider than screen
                    previewWidth = size.width;
                    previewHeight = size.width * aspectRatio;
                  }

                  return GestureDetector(
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: _onScaleUpdate,
                    onTapDown: (details) {
                      _onTapToFocus(details, constraints);
                    },
                    child: Center(
                      child: SizedBox(
                        width: previewWidth,
                        height: previewHeight,
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.center,
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: previewWidth,
                                height: previewHeight,
                                child: CameraPreview(_controller!),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              )
            else
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),

            // Focus indicator
            if (_focusPoint != null && _isFocusing)
              Positioned(
                left: _focusPoint!.dx - 40,
                top: _focusPoint!.dy - 40,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

            // Top controls
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                    // Settings button
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
                ),
              ),
            ),

            // Settings panel (slides from right - Google Camera style)
            // Placed after top controls to ensure it's on top when open
            // Settings panel (slides from top - Google Camera style)
            // Placed after top controls to ensure it's on top when open
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
              aspectRatioIndex: _aspectRatioIndex,
              onAspectRatioChanged: (val) {
                setState(() => _aspectRatioIndex = val);
                // TODO: Implement actual camera re-initialization for aspect ratio if needed
              },
            ),

            // Bottom controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Zoom slider
                    if (_isInitialized && _maxZoom > _minZoom)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.zoom_out,
                              color: Colors.white.withOpacity(0.7),
                              size: 20,
                            ),
                            Expanded(
                              child: Slider(
                                value: _currentZoom,
                                min: _minZoom,
                                max: _maxZoom,
                                activeColor: Colors.white,
                                inactiveColor: Colors.white.withOpacity(0.3),
                                onChanged: _setZoom,
                              ),
                            ),
                            Icon(
                              Icons.zoom_in,
                              color: Colors.white.withOpacity(0.7),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    // Capture button placeholder (for future use)
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                        color: Colors.transparent,
                      ),
                      child: Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
