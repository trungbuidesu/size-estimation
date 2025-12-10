import 'package:flutter/material.dart';
import 'package:size_estimation/models/captured_image.dart';
import 'package:size_estimation/views/camera_screen/components/image_detail_modal.dart';

class OverlapGuide extends StatefulWidget {
  final List<CapturedImage> images;
  final int requiredImages;
  final double aspectRatio; // NEW

  const OverlapGuide({
    super.key,
    required this.images,
    required this.requiredImages,
    this.aspectRatio = 9.0 / 16.0, // Default to 16:9 portrait
  });

  @override
  State<OverlapGuide> createState() => _OverlapGuideState();
}

class _OverlapGuideState extends State<OverlapGuide>
    with SingleTickerProviderStateMixin {
  late double _viewIndex; // The index currently centered
  late AnimationController _snapController;
  late Animation<double> _snapAnimation;

  @override
  void initState() {
    super.initState();
    _viewIndex = widget.images.length.toDouble();
    _snapController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void didUpdateWidget(OverlapGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.images.length != oldWidget.images.length) {
      // New image captured
      double targetIndex;
      if (widget.images.length >= widget.requiredImages) {
        // If completed, stay on the last image (don't show empty frame)
        targetIndex = (widget.images.length - 1).toDouble();
      } else {
        // Auto-scroll to the new target (next empty slot)
        targetIndex = widget.images.length.toDouble();
      }
      _animateTo(targetIndex);
    }
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _snapAnimation = Tween<double>(begin: _viewIndex, end: target).animate(
        CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic))
      ..addListener(() {
        setState(() {
          _viewIndex = _snapAnimation.value;
        });
      });
    _snapController.forward(from: 0);
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      // Drag Right (Delta +) -> Move content Right -> See Left Items (Lower Index)
      // _viewIndex -= delta * sensitivity
      // Sensitivity: 0.005
      _viewIndex -= details.primaryDelta! * 0.005;

      _viewIndex =
          _viewIndex.clamp(0.0, (widget.requiredImages - 1).toDouble());
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    double target = _viewIndex.roundToDouble();

    // Velocity snap
    if (details.primaryVelocity! < -500) {
      target = (_viewIndex + 1).floorToDouble(); // Swipe Left -> Next
    } else if (details.primaryVelocity! > 500) {
      target = (_viewIndex - 1).ceilToDouble(); // Swipe Right -> Prev
    }

    target = target.clamp(0.0, (widget.requiredImages - 1).toDouble());
    _animateTo(target);
  }

  void _showImageDetail(int index) {
    if (index >= widget.images.length) return; // No image to show

    showDialog(
      context: context,
      builder: (ctx) =>
          ImageDetailModal(image: widget.images[index], index: index),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Horizontal Linear Layout (Equidistant)
    // "dạng cách đều ngang hàng nhau"

    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;

          // Frame matches the full size of the container (which is already AspectRatio constrained)
          double itemWidth = screenWidth;
          double itemHeight = screenHeight;

          final double spacing = itemWidth + 20; // Width + Gap

          final double centerX = screenWidth / 2;

          // Prepare frame positions
          // We can just loop and Position them based on _viewIndex
          return Stack(
            alignment: Alignment.center,
            children: [
              for (int i = 0; i < widget.requiredImages; i++)
                _buildFrameItem(i, itemWidth, itemHeight, centerX, spacing),

              // Crosshair (Only visible if near "Current Target" and target matches capture count)
              if ((_viewIndex - widget.images.length).abs() < 0.1)
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: itemWidth,
                      height: itemHeight,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white12, width: 1),
                      ),
                      child: const Center(
                          child:
                              Icon(Icons.add, color: Colors.white24, size: 40)),
                    ),
                  ),
                )
            ],
          );
        },
      ),
    );
  }

  Widget _buildFrameItem(
      int index, double width, double height, double centerX, double spacing) {
    double delta = index - _viewIndex;

    // Optimization: Skip rendering items far off screen
    if (delta.abs() > 3) return const SizedBox.shrink();

    double left = centerX + delta * spacing - width / 2;

    // "Carousel" effect? Or just flat list?
    // User said "cách đều ngang hàng nhau" -> Equidistant.
    // Also "cuộn lại" was previous request, now "cách đều".
    // We stick to flat scrolling.

    // Opacity for distance?
    double opacity = (1.0 - delta.abs() * 0.3).clamp(0.2, 1.0);
    if (index == widget.images.length && delta.abs() < 0.5)
      opacity = 1.0; // Keep target bright

    return Positioned(
      left: left,
      top: 0,
      width: width,
      height: height,
      child: Opacity(
        opacity: opacity,
        child: _buildFrameContent(index, widget.images.length),
      ),
    );
  }

  Widget _buildFrameContent(int index, int currentIndex) {
    bool isCaptured = index < currentIndex;
    bool isCurrentTarget = index == currentIndex;

    // Color Logic
    Color borderColor = Colors.white12;
    if (isCaptured) {
      bool hasWarnings = widget.images[index].hasWarnings;
      borderColor = hasWarnings ? Colors.orangeAccent : Colors.greenAccent;
    } else if (isCurrentTarget) {
      // "mặc định khi chưa chụp sẽ là màu xanh da trời"
      borderColor = Colors.lightBlueAccent;
    }

    // Border Width
    double borderWidth = isCurrentTarget ? 4 : 2;

    return GestureDetector(
      onTap: () {
        if (isCaptured) {
          _showImageDetail(index);
        } else if (isCurrentTarget) {
          // Focus?
        } else {
          _animateTo(index.toDouble());
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
          // Rectangular
        ),
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Content Layer
              if (isCaptured)
                Image.file(
                  widget.images[index].file,
                  fit: BoxFit.cover, // Match camera preview behavior
                  color: Colors.black.withOpacity(0.2),
                  colorBlendMode: BlendMode.darken,
                )
              else if (!isCurrentTarget)
                const Center(
                    child: Text("Waiting...",
                        style: TextStyle(color: Colors.white24))),

              // Overlay Layer (Warnings, Arrows, Text)

              // 1. Index Label (Persistent)
              Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      color: Colors.black54,
                      child: Text(
                          "${index + 1}", // "hiện luôn trên các khung chụp" -> Just the number? Or "Ảnh X"? User said "index". Let's show "Ảnh X" or just "X".
                          style: TextStyle(
                              color: isCaptured ? Colors.white : borderColor,
                              fontWeight: FontWeight.bold)))),

              // 2. Warnings (Captured)
              if (isCaptured && widget.images[index].hasWarnings)
                const Positioned(
                    top: 40,
                    right: 10,
                    child: Icon(Icons.warning_amber_rounded,
                        color: Colors.orangeAccent, size: 28)),

              // 3. Alignment Arrow (Current Target)
              if (isCurrentTarget && index > 0)
                Positioned(
                    left: 10,
                    top: 0,
                    bottom: 0,
                    child: Center(
                        child: Icon(
                      Icons.arrow_back,
                      color: borderColor,
                      size: 32,
                    ))),
            ],
          ),
        ),
      ),
    );
  }
}
