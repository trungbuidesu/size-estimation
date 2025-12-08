import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:size_estimation/models/index.dart';

const List<PermissionItem> requiredPermissions = [
  PermissionItem(
    permission: Permission.camera,
    title: 'Máy ảnh',
    icon: Icons.camera_alt,
    description: 'Cần thiết để chụp ảnh và quay video trong ứng dụng.',
  ),
  PermissionItem(
    permission: Permission.photos,
    title: 'Ảnh & Media (Thư viện)',
    icon: Icons.photo_library,
    description: 'Cho phép truy cập thư viện ảnh và video để tải lên hoặc lưu hình ảnh.',
  ),
];