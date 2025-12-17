import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class MultiCaptureCameraScreen extends StatefulWidget {
  const MultiCaptureCameraScreen({super.key});

  @override
  State<MultiCaptureCameraScreen> createState() =>
      _MultiCaptureCameraScreenState();
}

class _MultiCaptureCameraScreenState extends State<MultiCaptureCameraScreen> {
  CameraController? _controller;
  final List<File> _capturedImages = [];
  Set<int> _selectedIndices = {};
  bool _isInitialized = false;
  bool _showAlbum = false;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No camera found')),
          );
        }
        return;
      }

      _controller = CameraController(
        cameras.first,
        ResolutionPreset.high, // MUST MATCH CameraScreen for valid calibration
        enableAudio: false,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  Future<void> _captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      final image = await _controller!.takePicture();

      // Save to temp directory
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = path.join(directory.path, 'calibration_$timestamp.jpg');
      final savedImage = await File(image.path).copy(filePath);

      setState(() {
        _capturedImages.add(savedImage);
        _isCapturing = false;
      });
    } catch (e) {
      setState(() {
        _isCapturing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e')),
        );
      }
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

  void _selectAll() {
    setState(() {
      _selectedIndices =
          Set.from(List.generate(_capturedImages.length, (i) => i));
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedIndices.clear();
    });
  }

  void _deleteSelected() {
    if (_selectedIndices.isEmpty) return;

    setState(() {
      final indicesToRemove = _selectedIndices.toList()
        ..sort((a, b) => b.compareTo(a));
      for (final index in indicesToRemove) {
        _capturedImages[index].deleteSync();
        _capturedImages.removeAt(index);
      }
      _selectedIndices.clear();
    });
  }

  void _confirmSelection() {
    final selectedImages =
        _selectedIndices.map((index) => _capturedImages[index]).toList();
    Navigator.pop(context, selectedImages);
  }

  void _onTapFocus(TapDownDetails details, BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localPoint = box.globalToLocal(details.globalPosition);
    final Size size = box.size;

    final double x = localPoint.dx / size.width;
    final double y = localPoint.dy / size.height;

    try {
      _controller!.setFocusPoint(Offset(x, y));
      _controller!.setFocusMode(FocusMode.auto);
    } catch (e) {
      // Ignore focus errors
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: _showAlbum ? _buildAlbumView() : _buildCameraView(),
      ),
    );
  }

  Widget _buildCameraView() {
    if (!_isInitialized || _controller == null) {
      return Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera Preview - Full screen
        Positioned.fill(
          child: GestureDetector(
            onTapDown: (details) {
              _onTapFocus(details, context);
            },
            child: CameraPreview(_controller!),
          ),
        ),

        // Top Bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
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
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  '${_capturedImages.length} ảnh',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.photo_library,
                      color: Colors.white, size: 28),
                  onPressed: _capturedImages.isEmpty
                      ? null
                      : () => setState(() => _showAlbum = true),
                ),
              ],
            ),
          ),
        ),

        // Bottom Controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Thumbnail of last captured
                SizedBox(
                  width: 60,
                  height: 60,
                  child: _capturedImages.isEmpty
                      ? Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        )
                      : GestureDetector(
                          onTap: () => setState(() => _showAlbum = true),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white, width: 2),
                              image: DecorationImage(
                                image: FileImage(_capturedImages.last),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                ),

                // Capture Button
                GestureDetector(
                  onTap: _isCapturing ? null : _captureImage,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isCapturing ? Colors.grey : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                // Done Button
                SizedBox(
                  width: 60,
                  height: 60,
                  child: _capturedImages.isEmpty
                      ? const SizedBox()
                      : ElevatedButton(
                          onPressed: () {
                            // Select all and confirm
                            _selectAll();
                            _confirmSelection();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF22A06B), // Success color
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 28),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumView() {
    final theme = Theme.of(context);
    return Column(
      children: [
        // Album Header
        Container(
          padding: const EdgeInsets.all(16),
          color: theme.colorScheme.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon:
                    Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
                onPressed: () => setState(() => _showAlbum = false),
              ),
              Text(
                '${_selectedIndices.length}/${_capturedImages.length} đã chọn',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  if (_selectedIndices.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.delete, color: theme.colorScheme.error),
                      onPressed: _deleteSelected,
                    ),
                  IconButton(
                    icon: Icon(
                      _selectedIndices.length == _capturedImages.length
                          ? Icons.deselect
                          : Icons.select_all,
                      color: theme.colorScheme.onSurface,
                    ),
                    onPressed: _selectedIndices.length == _capturedImages.length
                        ? _deselectAll
                        : _selectAll,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Grid View
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: _capturedImages.length,
            itemBuilder: (context, index) {
              final isSelected = _selectedIndices.contains(index);
              return GestureDetector(
                onTap: () => _toggleSelection(index),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      _capturedImages[index],
                      fit: BoxFit.cover,
                    ),
                    if (isSelected)
                      Container(
                        color: theme.colorScheme.primary.withOpacity(0.5),
                        child: const Center(
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surface.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
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
                  ],
                ),
              );
            },
          ),
        ),

        // Bottom Action Bar
        Container(
          padding: const EdgeInsets.all(16),
          color: theme.colorScheme.surface,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _showAlbum = false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface,
                    side: BorderSide(color: theme.colorScheme.onSurface),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Chụp thêm'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      _selectedIndices.isEmpty ? null : _confirmSelection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22A06B), // Success color
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Xong (${_selectedIndices.length})',
                    style: TextStyle(color: theme.colorScheme.onPrimary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
