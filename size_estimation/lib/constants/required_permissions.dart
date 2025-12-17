import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:size_estimation/models/index.dart';
import 'package:device_info_plus/device_info_plus.dart';

// Base permissions required on all platforms
const List<PermissionItem> _basePermissions = [
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
    description:
        'Cho phép truy cập thư viện ảnh và video để tải lên hoặc lưu hình ảnh.',
  ),
];

// Storage permission (only for Android < 13)
const PermissionItem _storagePermission = PermissionItem(
  permission: Permission.storage,
  title: 'Lưu trữ (Storage)',
  icon: Icons.sd_storage,
  description:
      'Cho phép lưu ảnh hiệu chỉnh vào thư mục Pictures. (Chỉ Android < 13)',
);

/// Get required permissions based on platform and Android version
Future<List<PermissionItem>> getRequiredPermissions() async {
  final permissions = List<PermissionItem>.from(_basePermissions);

  // Only add storage permission on Android < 13 (API < 33)
  if (Platform.isAndroid) {
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;

    // Android 13 = API 33
    if (androidInfo.version.sdkInt < 33) {
      permissions.add(_storagePermission);
    }
  }

  return permissions;
}
