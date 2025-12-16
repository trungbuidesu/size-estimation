import 'package:flutter/material.dart';

class DraggableOverlay extends StatefulWidget {
  final Widget child;
  final Offset initialOffset;

  const DraggableOverlay({
    Key? key,
    required this.child,
    this.initialOffset = const Offset(10, 50),
  }) : super(key: key);

  @override
  _DraggableOverlayState createState() => _DraggableOverlayState();
}

class _DraggableOverlayState extends State<DraggableOverlay> {
  late Offset position;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    position = widget.initialOffset;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              position += details.delta;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
              border: _isHovering
                  ? Border.all(color: Colors.blueAccent, width: 1.5)
                  : Border.all(color: Colors.white12, width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isHovering)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.open_with,
                            color: Colors.blueAccent, size: 14),
                        SizedBox(width: 4),
                        Text("Move",
                            style: TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                widget.child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
