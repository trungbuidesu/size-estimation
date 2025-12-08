import 'package:flutter/material.dart';
import 'package:size_estimation/views/permissions_screen/components/index.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenStateWrapper();
}

class _PermissionsScreenStateWrapper extends State<PermissionsScreen> {
  // 💡 Tạo ValueNotifier để truyền trạng thái giữa các Components
  final ValueNotifier<bool> _allGrantedNotifier = ValueNotifier(false);

  @override
  void dispose() {
    _allGrantedNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Quyền Truy cập'),
        centerTitle: true,
      ),
      body: PermissionCheckerList(
        allGrantedNotifier: _allGrantedNotifier,
      ),
      // 💡 Đặt nút Tiếp tục vào BottomNavigationBar/Align để nó nổi lên
      bottomNavigationBar: SafeArea(
          child: // Ví dụ trong widget cha
              ContinueButton(
        // Ví dụ: _allPermissionsGrantedNotifier là ValueNotifier<bool> của bạn
        isEnabledNotifier: _allGrantedNotifier,
        nextRoute: '/onboarding-done',
        enabledLabel: 'TIẾP TỤC SỬ DỤNG', // Text khi đã cấp quyền
        disabledLabel: 'VUI LÒNG CẤP ĐỦ QUYỀN', // Text khi chưa cấp quyền
      )),
    );
  }
}
