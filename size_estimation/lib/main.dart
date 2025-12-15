import 'package:flutter/material.dart';

import 'package:size_estimation/theme/index.dart';
import 'router/app_router.dart'; // Import GoRouter đã tạo

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Size Estimation',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light, // Force light mode as requested
      // Dùng routerConfig thay vì home/routes/onGenerateRoute
      routerConfig: appRouter,
    );
  }
}
