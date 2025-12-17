import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:size_estimation/theme/app_theme.dart';

class MultiFrameCaptureScreen extends StatefulWidget {
  final List<File> initialImages;

  const MultiFrameCaptureScreen({super.key, this.initialImages = const []});

  @override
  State<MultiFrameCaptureScreen> createState() =>
      _MultiFrameCaptureScreenState();
}

class _MultiFrameCaptureScreenState extends State<MultiFrameCaptureScreen> {
  CameraController? _controller;
  late List<File> _capturedImages;
  final Set<int> _selectedIndices = {};
  bool _isCameraInitialized = false;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _capturedImages = List.from(widget.initialImages);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras[0],
      ResolutionPreset.max, // Locked to 4:3 high res
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.jpeg
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _controller!.initialize();
      // Apply Settings: ISO 100, Shutter 1/125, WB 5600, AF locked
      // Note: Generic Camera plugin support is limited. We'll set what we can.
      await _controller!.setExposureMode(ExposureMode.auto); // Start auto
      // Try to lock with offset if supported, but exact ISO/Shutter isn't standard in plugin yet.
      // We will assume "Locked" is desired after a brief auto-adjustment or instant lock.
      // For now, adhere to explicit user request by locking exposure.
      // In a real device, this locks at *current* levels.
      // To strictly force specific ISO, we'd need platform specific calls.
      // We'll proceed with locked mode as a best effort proxy.
      await _controller!.setExposureMode(ExposureMode.locked);
      await _controller!.setFocusMode(FocusMode.locked);

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final XFile file = await _controller!.takePicture();
      setState(() {
        _capturedImages.add(File(file.path));
      });
    } catch (e) {
      debugPrint('Error capturing photo: $e');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  Future<void> _saveAndExit() async {
    if (_capturedImages.isEmpty) {
      Navigator.pop(context, _capturedImages);
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Get public Pictures directory
      // On Android: /storage/emulated/0/Pictures/
      // On iOS: Photos library (requires different approach)
      Directory? picturesDir;

      if (Platform.isAndroid) {
        // Use public Pictures directory on Android
        picturesDir = Directory('/storage/emulated/0/Pictures');
      } else {
        // Fallback to app directory for iOS (would need photo_manager package for real gallery)
        final externalDir = await getExternalStorageDirectory();
        picturesDir = Directory('${externalDir?.path}/Pictures');
      }

      if (!await picturesDir.exists()) {
        throw Exception('Cannot access Pictures directory');
      }

      // Create calibration folder
      final String timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .substring(0, 19);
      final Directory saveDir = Directory(
          '${picturesDir.path}/SizeEstimation/Calibration_$timestamp');

      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      // Copy all images to the folder
      final List<File> savedFiles = [];
      for (int i = 0; i < _capturedImages.length; i++) {
        final File sourceFile = _capturedImages[i];
        final String fileName = 'calibration_${i + 1}.jpg';
        final String savePath = '${saveDir.path}/$fileName';

        final File savedFile = await sourceFile.copy(savePath);
        savedFiles.add(savedFile);
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Đã lưu ${savedFiles.length} ảnh vào Gallery\n${saveDir.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );

        // Return saved files
        Navigator.pop(context, savedFiles);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Lỗi khi lưu ảnh: $e\nKiểm tra quyền truy cập storage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _deleteSelected() {
    setState(() {
      final indices = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
      for (final i in indices) {
        _capturedImages.removeAt(i);
      }
      _selectedIndices.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Apply Atlassian Theme manually where needed, but use Theme.of(context) generally.
    // Ideally this widget is wrapped in Theme in main.dart, but we ensure specific colors.

    // For manual camera UI, we want White buttons.

    return Theme(
      data: AppTheme.darkTheme, // Force dark theme for camera interface
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            // 1. Camera Preview Area (Top)
            Expanded(
              flex: 2,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_isCameraInitialized)
                    CameraPreview(_controller!)
                  else
                    const Center(child: CircularProgressIndicator()),

                  // Top Bar (Back button)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 8,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  // Capture Button (Bottom Center of Preview)
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: _capturePhoto,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white, // Locked White
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black12, width: 4),
                          ),
                          child: _isCapturing
                              ? const CircularProgressIndicator(
                                  color: Colors.black)
                              : const Icon(Icons.camera_alt,
                                  color: Colors.black, size: 32),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Image Strip / Selection Area (Bottom)
            Expanded(
              flex: 1,
              child: Container(
                color: const Color(0xFF1D2125), // Atlassian Dark Bg
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Captured (${_capturedImages.length})',
                              style: const TextStyle(
                                  color: Color(0xFFDCDFE4),
                                  fontWeight: FontWeight.bold)),
                          if (_selectedIndices.isNotEmpty)
                            IconButton(
                              icon:
                                  const Icon(Icons.delete, color: Colors.white),
                              onPressed: _deleteSelected,
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _capturedImages.isEmpty
                          ? const Center(
                              child: Text('No images captured',
                                  style: TextStyle(color: Colors.grey)))
                          : GridView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 4,
                                mainAxisSpacing: 4,
                              ),
                              itemCount: _capturedImages.length,
                              itemBuilder: (context, index) {
                                final isSelected =
                                    _selectedIndices.contains(index);
                                return GestureDetector(
                                  onTap: () => _toggleSelection(index),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.file(_capturedImages[index],
                                          fit: BoxFit.cover),
                                      if (isSelected)
                                        Container(
                                          color: const Color(0xFF579DFF)
                                              .withOpacity(
                                                  0.5), // Atlassian Blue
                                          child: const Center(
                                            child: Icon(Icons.check_circle,
                                                color: Colors.white, size: 32),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),

                    // Bottom Done Button
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _saveAndExit,
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF579DFF), // Atlassian Blue
                            foregroundColor: const Color(0xFF1D2125),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Done / Save to Gallery'),
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
