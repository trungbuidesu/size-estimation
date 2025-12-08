import 'package:flutter/material.dart';

import 'router/app_router.dart'; // Import GoRouter đã tạo

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GoRouter Demo',
      // Dùng routerConfig thay vì home/routes/onGenerateRoute
      routerConfig: appRouter, 
    );
  }
}