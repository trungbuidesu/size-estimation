import 'package:flutter/material.dart';
import 'package:size_estimation/services/sensor_service.dart';

class StabilityIndicator extends StatelessWidget {
  final StabilityMetrics metrics;

  const StabilityIndicator({
    super.key,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    Color barColor;
    if (!metrics.isStable) {
      barColor = Colors.redAccent;
    } else if (!metrics.isLevel) {
      barColor = Colors.orangeAccent;
    } else {
      barColor = Colors.greenAccent;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Level Warning (Keep but compact)
        if (!metrics.isLevel)
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
                color: Colors.black45, borderRadius: BorderRadius.circular(2)),
            child: Text(
              "${metrics.rollDegrees.toStringAsFixed(1)}°",
              style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),

        // Stability Bar (Simplified)
        Container(
          width: 120, // Smaller width
          height: 6,
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(3),
          ),
          child: AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 150),
            widthFactor: metrics.stabilityScore,
            alignment: Alignment.center,
            child: Container(
              decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(color: barColor.withOpacity(0.5), blurRadius: 4)
                  ]),
            ),
          ),
        ),
      ],
    );
  }
}
