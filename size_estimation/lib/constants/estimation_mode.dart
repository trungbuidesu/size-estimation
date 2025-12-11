import 'package:flutter/material.dart';
import '../models/estimation_mode.dart';

const List<EstimationMode> kEstimationModes = [
  EstimationMode(
    type: EstimationModeType.groundPlane,
    label: 'Mặt đất',
    description: 'Ground-plane Homography',
    icon: Icons.grid_on,
  ),
  EstimationMode(
    type: EstimationModeType.planarObject,
    label: 'Vật phẳng',
    description: 'Planar Object + Rectification + Pinhole',
    icon: Icons.crop_square,
  ),
  EstimationMode(
    type: EstimationModeType.singleView,
    label: 'Vật cao',
    description: 'Single-view Metrology (vật cao / tường / tòa nhà)',
    icon: Icons.apartment,
  ),
  EstimationMode(
    type: EstimationModeType.multiFrame,
    label: 'Đa khung',
    description: 'Multi-frame Refinement (tùy chọn nâng cao)',
    icon: Icons.burst_mode,
  ),
];
