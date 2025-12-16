import 'package:flutter/material.dart';
import '../models/estimation_mode.dart';

const List<EstimationMode> kEstimationModes = [
  EstimationMode(
    type: EstimationModeType.groundPlane,
    label: 'Đo trên mặt sàn',
    steps: [
      'Đặt điện thoại ở độ cao cố định (ví dụ: 1.2m)',
      'Giữ điện thoại level (viền xanh lá)',
      'Chạm 2 điểm trên mặt sàn cần đo',
      'Khoảng cách sẽ được tính bằng Ground-plane Homography',
    ],
    icon: Icons.landscape,
  ),
  EstimationMode(
    type: EstimationModeType.planarObject,
    label: 'Đo vật phẳng',
    steps: [
      'Chụp ảnh vật phẳng (bìa hộp, tờ giấy, bảng...)',
      'Chọn 4 góc của vật phẳng',
      'Hệ thống sẽ rectify và tính kích thước',
      'Kết quả: chiều dài, chiều rộng, diện tích',
    ],
    icon: Icons.crop_square,
  ),
  EstimationMode(
    type: EstimationModeType.singleView,
    label: 'Đo chiều cao',
    steps: [
      'Chụp ảnh vật cao (tường, cột, tòa nhà...)',
      'Chọn điểm đáy và điểm đỉnh',
      'Cung cấp chiều cao tham chiếu (nếu có)',
      'Chiều cao được tính bằng Single-view Metrology',
    ],
    icon: Icons.height,
  ),
];
