import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:size_estimation/constants/index.dart'; // Import go_router

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

    // ➡️ Chuyển hướng đến màn hình chính hoặc đăng nhập
    // Sử dụng context.go() để thay thế toàn bộ stack route
    if (mounted) {
      // Giả sử màn hình tiếp theo là /home
      context.go('/${RouteNames.permissions}'); 
      // Hoặc context.go('/login'); tùy thuộc vào logic của bạn
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