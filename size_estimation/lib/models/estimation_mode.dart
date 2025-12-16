import 'package:flutter/material.dart';

enum EstimationModeType {
  groundPlane,
  planarObject,
  singleView,
}

class EstimationMode {
  final EstimationModeType type;
  final String label;
  final String description;
  final IconData icon;

  const EstimationMode({
    required this.type,
    required this.label,
    required this.description,
    required this.icon,
  });
}
