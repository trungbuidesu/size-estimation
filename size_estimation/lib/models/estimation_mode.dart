import 'package:flutter/material.dart';

enum EstimationModeType {
  groundPlane,
  planarObject,
  singleView,
}

class EstimationMode {
  final EstimationModeType type;
  final String label;
  final List<String> steps; // Changed from description to steps
  final IconData icon;

  const EstimationMode({
    required this.type,
    required this.label,
    required this.steps,
    required this.icon,
  });
}
