import 'package:flutter/material.dart';
import 'package:size_estimation/models/bounding_box.dart';
import 'package:size_estimation/models/captured_image.dart';

/// Dialog for selecting target objects from detected bounding boxes
class ObjectSelectionDialog extends StatefulWidget {
  final List<CapturedImage> images;
  final List<BoundingBox> detectedBoxes;
  final Function(List<BoundingBox>) onConfirm;

  const ObjectSelectionDialog({
    super.key,
    required this.images,
    required this.detectedBoxes,
    required this.onConfirm,
  });

  @override
  State<ObjectSelectionDialog> createState() => _ObjectSelectionDialogState();
}

class _ObjectSelectionDialogState extends State<ObjectSelectionDialog> {
  final Set<String> _selectedBoxIds = {};
  int _currentImageIndex = 0;
  String? _targetObjectLabel;

  @override
  void initState() {
    super.initState();
    // Auto-select most common high-confidence object
    _autoSelectCommonObject();
  }

  void _autoSelectCommonObject() {
    if (widget.detectedBoxes.isEmpty) return;

    // Count object labels across all images
    final labelCounts = <String, int>{};
    for (var box in widget.detectedBoxes) {
      if (box.confidence > 0.6) {
        labelCounts[box.label] = (labelCounts[box.label] ?? 0) + 1;
      }
    }

    if (labelCounts.isEmpty) return;

    // Find most common label
    final mostCommon =
        labelCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    setState(() {
      _targetObjectLabel = mostCommon;
      // Select all boxes with this label
      for (var box in widget.detectedBoxes) {
        if (box.label == mostCommon && box.confidence > 0.6) {
          _selectedBoxIds.add(_getBoxId(box));
        }
      }
    });
  }

  String _getBoxId(BoundingBox box) {
    return '${box.imageIndex}_${box.label}_${box.x}_${box.y}';
  }

  List<BoundingBox> _getBoxesForCurrentImage() {
    return widget.detectedBoxes
        .where((box) => box.imageIndex == _currentImageIndex)
        .toList();
  }

  List<BoundingBox> _getSelectedBoxes() {
    return widget.detectedBoxes
        .where((box) => _selectedBoxIds.contains(_getBoxId(box)))
        .toList();
  }

  void _toggleBoxSelection(BoundingBox box) {
    setState(() {
      final boxId = _getBoxId(box);
      if (_selectedBoxIds.contains(boxId)) {
        _selectedBoxIds.remove(boxId);
        // If no boxes selected, clear target label
        if (_selectedBoxIds.isEmpty) {
          _targetObjectLabel = null;
        }
      } else {
        _selectedBoxIds.add(boxId);
        _targetObjectLabel = box.label;
      }
    });
  }

  void _confirmSelection() {
    final selectedBoxes = _getSelectedBoxes();

    if (selectedBoxes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất một vật thể để đo'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if object appears in enough images (at least 3)
    final imageIndices = selectedBoxes.map((b) => b.imageIndex).toSet();
    if (imageIndices.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Vật thể chỉ xuất hiện trong ${imageIndices.length} ảnh. '
            'Cần ít nhất 3 ảnh để đo chính xác.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    widget.onConfirm(selectedBoxes);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final currentBoxes = _getBoxesForCurrentImage();
    final selectedCount = _getSelectedBoxes().length;
    final imagesCovered =
        _getSelectedBoxes().map((b) => b.imageIndex).toSet().length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.center_focus_strong, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Chọn vật thể cần đo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _targetObjectLabel != null
                              ? 'Đang chọn: $_targetObjectLabel'
                              : 'Nhấn vào vật thể trong ảnh',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Image viewer with bounding boxes
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                child: Stack(
                  children: [
                    // Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        widget.images[_currentImageIndex].file,
                        fit: BoxFit.contain,
                      ),
                    ),

                    // Bounding boxes overlay
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return CustomPaint(
                          size:
                              Size(constraints.maxWidth, constraints.maxHeight),
                          painter: BoundingBoxPainter(
                            boxes: currentBoxes,
                            selectedIds: _selectedBoxIds,
                            getBoxId: _getBoxId,
                            onBoxTap: _toggleBoxSelection,
                          ),
                        );
                      },
                    ),

                    // Image counter
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_currentImageIndex + 1} / ${widget.images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Image navigation
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: _currentImageIndex > 0
                        ? () => setState(() => _currentImageIndex--)
                        : null,
                  ),
                  const SizedBox(width: 20),
                  ...List.generate(widget.images.length, (index) {
                    final hasBoxes = widget.detectedBoxes
                        .any((box) => box.imageIndex == index);
                    final hasSelected = _getSelectedBoxes()
                        .any((box) => box.imageIndex == index);

                    return GestureDetector(
                      onTap: () => setState(() => _currentImageIndex = index),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _currentImageIndex == index
                              ? Colors.blue
                              : (hasSelected
                                  ? Colors.green
                                  : (hasBoxes
                                      ? Colors.white24
                                      : Colors.white12)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: _currentImageIndex == index || hasSelected
                                  ? Colors.white
                                  : Colors.white54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 20),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios,
                        color: Colors.white),
                    onPressed: _currentImageIndex < widget.images.length - 1
                        ? () => setState(() => _currentImageIndex++)
                        : null,
                  ),
                ],
              ),
            ),

            // Detected objects list
            if (currentBoxes.isNotEmpty)
              Container(
                height: 100,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: currentBoxes.length,
                  itemBuilder: (context, index) {
                    final box = currentBoxes[index];
                    final boxId = _getBoxId(box);
                    final isSelected = _selectedBoxIds.contains(boxId);

                    return GestureDetector(
                      onTap: () => _toggleBoxSelection(box),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.blue
                              : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.blue
                                : Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getIconForLabel(box.label),
                              color: Colors.white,
                              size: 32,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              box.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${(box.confidence * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Bottom action bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  // Selection info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Đã chọn: $selectedCount vật thể',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Xuất hiện trong: $imagesCovered/${widget.images.length} ảnh',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Confirm button
                  ElevatedButton.icon(
                    onPressed: _confirmSelection,
                    icon: const Icon(Icons.check),
                    label: const Text('Xác nhận'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForLabel(String label) {
    switch (label.toLowerCase()) {
      case 'person':
        return Icons.person;
      case 'bottle':
        return Icons.local_drink;
      case 'cup':
        return Icons.coffee;
      case 'chair':
        return Icons.chair;
      case 'laptop':
        return Icons.laptop;
      case 'phone':
      case 'cell phone':
        return Icons.phone_android;
      case 'book':
        return Icons.book;
      case 'vase':
        return Icons.local_florist;
      case 'clock':
        return Icons.access_time;
      case 'keyboard':
        return Icons.keyboard;
      case 'mouse':
        return Icons.mouse;
      case 'tv':
      case 'monitor':
        return Icons.tv;
      case 'potted plant':
        return Icons.local_florist;
      case 'backpack':
        return Icons.backpack;
      default:
        return Icons.category;
    }
  }
}

/// Custom painter for drawing bounding boxes on images
class BoundingBoxPainter extends CustomPainter {
  final List<BoundingBox> boxes;
  final Set<String> selectedIds;
  final String Function(BoundingBox) getBoxId;
  final Function(BoundingBox) onBoxTap;

  BoundingBoxPainter({
    required this.boxes,
    required this.selectedIds,
    required this.getBoxId,
    required this.onBoxTap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var box in boxes) {
      final isSelected = selectedIds.contains(getBoxId(box));
      final rect = box.toPixelRect(size);

      // Draw box
      final boxPaint = Paint()
        ..color = isSelected ? Colors.blue : Colors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 4 : 2;

      canvas.drawRect(rect, boxPaint);

      // Draw filled background for selected
      if (isSelected) {
        final fillPaint = Paint()
          ..color = Colors.blue.withOpacity(0.2)
          ..style = PaintingStyle.fill;
        canvas.drawRect(rect, fillPaint);
      }

      // Draw label background
      final labelBgPaint = Paint()
        ..color = isSelected ? Colors.blue : Colors.green
        ..style = PaintingStyle.fill;

      final labelText = '${box.label} ${(box.confidence * 100).toInt()}%';
      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      final labelRect = Rect.fromLTWH(
        rect.left,
        rect.top - 24,
        textPainter.width + 8,
        20,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(4)),
        labelBgPaint,
      );

      textPainter.paint(canvas, Offset(rect.left + 4, rect.top - 22));

      // Draw selection indicator
      if (isSelected) {
        final checkPaint = Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.fill;

        canvas.drawCircle(
          Offset(rect.right - 12, rect.top + 12),
          12,
          checkPaint,
        );

        final checkIcon = TextPainter(
          text: const TextSpan(
            text: '✓',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );

        checkIcon.layout();
        checkIcon.paint(
          canvas,
          Offset(rect.right - 18, rect.top + 4),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    return boxes != oldDelegate.boxes || selectedIds != oldDelegate.selectedIds;
  }

  @override
  bool hitTest(Offset position) => true;
}
