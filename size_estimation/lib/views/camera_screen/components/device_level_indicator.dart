import 'package:flutter/material.dart';

class DeviceLevelIndicator extends StatelessWidget {
  final bool isLevel;
  final double rollDegrees;

  const DeviceLevelIndicator({
    super.key,
    required this.isLevel,
    this.rollDegrees = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Determine border color based on orientation
    Color borderColor;

    // Check if device is sideways (roll near ±90°)
    final absRoll = rollDegrees.abs();
    if (absRoll > 75 && absRoll < 105) {
      // Device is sideways - RED warning
      borderColor = Colors.redAccent;
    } else if (isLevel) {
      // Device is level - GREEN
      borderColor = Colors.greenAccent;
    } else {
      // Device is tilted - ORANGE
      borderColor = Colors.orangeAccent;
    }

    double borderWidth = 4;

    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
        ),
      ),
    );
  }
}
