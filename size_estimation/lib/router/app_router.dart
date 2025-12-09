import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:size_estimation/constants/index.dart';
import 'package:size_estimation/views/permissions_screen/index.dart';
import 'package:size_estimation/views/splash_screen/index.dart';
import 'package:size_estimation/views/methods_screen/index.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      name: RouteNames.splash,
      builder: (BuildContext context, GoRouterState state) {
        return const SplashScreen(); // Đây là Widget SplashScreen của bạn
      },
    ),
    GoRoute(
      path: '/${RouteNames.permissions}',
      name: RouteNames.permissions,
      builder: (BuildContext context, GoRouterState state) {
        return const PermissionsScreen();
      },
    ),
    GoRoute(
      path: '/${RouteNames.methods}',
      name: RouteNames.methods,
      builder: (BuildContext context, GoRouterState state) {
        return const MethodsScreen();
      },
    ),
    // GoRoute(
    //   path: '/',
    //   name: AppRouteNames.home,
    //   builder: (BuildContext context, GoRouterState state) {
    //     return const HomePage();
    //   },
    //   // Thêm sub-routes nếu cần (Nested Routing)
    //   routes: <RouteBase>[
    //     // Đường dẫn /settings
    //     GoRoute(
    //       path: 'settings', // LƯU Ý: Không dùng dấu '/' ở đầu cho sub-route
    //       name: AppRouteNames.settings,
    //       builder: (BuildContext context, GoRouterState state) {
    //         return const SettingsPage();
    //       },
    //     ),
    //   ],
    // ),
  ],
  // Tùy chọn: Xử lý khi không tìm thấy đường dẫn (404)
  errorBuilder: (context, state) => const ErrorScreen(), 
);

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('404 - Page not found!'),
      ),
    );
  }
}