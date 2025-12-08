import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionItem {
  final Permission permission;
  final String title;
  final IconData icon;
  final String description;

  const PermissionItem({
    required this.permission,
    required this.title,
    required this.icon,
    required this.description,
  });
}