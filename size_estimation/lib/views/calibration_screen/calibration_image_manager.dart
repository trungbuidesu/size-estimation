import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:size_estimation/theme/app_theme.dart';

class CalibrationImageManager extends StatefulWidget {
  final List<File> initialImages;

  const CalibrationImageManager({super.key, this.initialImages = const []});

  @override
  State<CalibrationImageManager> createState() =>
      _CalibrationImageManagerState();
}

class _CalibrationImageManagerState extends State<CalibrationImageManager> {
  final ImagePicker _picker = ImagePicker();
  late List<File> _capturedImages;
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _capturedImages = List.from(widget.initialImages);
    // Automatically open picker if list is empty? Optional.
    if (_capturedImages.isEmpty) {
      // Defer to after build
      Future.delayed(Duration.zero, _pickImages);
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _capturedImages.addAll(images.map((x) => File(x.path)));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e')),
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

  void _deleteSelected() {
    if (_selectedIndices.isEmpty) return;

    setState(() {
      final indicesToRemove = _selectedIndices.toList()
        ..sort((a, b) => b.compareTo(a));
      for (final index in indicesToRemove) {
        _capturedImages.removeAt(index);
      }
      _selectedIndices.clear();
    });
  }

  void _confirmSelection() {
    Navigator.pop(context, _capturedImages);
  }

  @override
  Widget build(BuildContext context) {
    // Ensure we use the dark theme for consistency or inherit depending on app state.
    // Assuming dark theme preference for "Atlassian" feel in this context.
    final theme = AppTheme.darkTheme;

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Quản lý ảnh (${_capturedImages.length})'),
          actions: [
            if (_selectedIndices.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _deleteSelected,
              ),
            IconButton(
              icon: const Icon(Icons.add_photo_alternate),
              onPressed: _pickImages,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _capturedImages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library_outlined,
                              size: 64, color: theme.colorScheme.secondary),
                          const SizedBox(height: 16),
                          const Text('Chưa có ảnh nào'),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _pickImages,
                            icon: const Icon(Icons.add),
                            label: const Text('Chọn ảnh từ thư viện'),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(4),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
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
                                  color: theme.colorScheme.primary
                                      .withOpacity(0.5),
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
                                        : theme.colorScheme.surface
                                            .withOpacity(0.7),
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        _capturedImages.isEmpty ? null : _confirmSelection,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(
                          0xFF22A06B), // Keep success green as requested
                    ),
                    child: const Text('Xong / Lưu'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
