import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:size_estimation/constants/index.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen(); // Gọi hàm chuyển hướng
  }

  void _navigateToNextScreen() async {
    // ⏳ Chờ 3 giây để người dùng xem Splash Screen
    await Future.delayed(const Duration(seconds: 3));

    // Get the list of required permissions based on platform
    final requiredPermissions = await getRequiredPermissions();

    bool allGranted = true;
    for (var item in requiredPermissions) {
      if (!await item.permission.isGranted) {
        allGranted = false;
        break;
      }
    }

    // ➡️ Chuyển hướng đến màn hình chính hoặc màn hình quyền
    if (mounted) {
      if (allGranted) {
        context.go('/${RouteNames.methods}');
      } else {
        context.go('/${RouteNames.permissions}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🎨 UI của Splash Screen (vẫn giữ nguyên)
    return const Scaffold(
      backgroundColor: Color(0xFF0D47A1),
      body: Center(
        child: Image(
          image: AssetImage('assets/images/app_icon.png'),
          width: 140,
          height: 140,
        ),
      ),
    );
  }
}
